-- Rejection with a reason, L15 (D-08, rule 9, D-25). Every rejection is kept, tied to the
-- attempt it judged, and outlives the photos (D-07, #41). Reasons are codes so L12 shows
-- them in the member's language; 'other' needs the note.
create table public.verification_rejections (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles on delete cascade,
  -- The <attempt> folder judged (D-19); null if no complete attempt was found.
  attempt text,
  reasons text[] not null
    check (cardinality(reasons) > 0 and reasons <@ array['card', 'selfie', 'data', 'other']),
  note text,
  rejected_by uuid references public.profiles on delete set null,
  rejected_at timestamptz not null default now()
);
create index on public.verification_rejections (profile_id, rejected_at desc);

-- Members read their own; admins read all. Rows are written only by reject_verification.
alter table public.verification_rejections enable row level security;
revoke all on public.verification_rejections from anon, authenticated;
grant select on public.verification_rejections to authenticated;
create policy "rejections: read own, admin reads all"
  on public.verification_rejections for select to authenticated
  using (profile_id = (select auth.uid()) or (select public.is_admin()));

-- The newest folder holding both card and selfie; earlier ones may be partial uploads.
create function public.latest_attempt(p_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select (storage.foldername(o.name))[2]
  from storage.objects o
  where o.bucket_id = 'verification'
    and (storage.foldername(o.name))[1] = p_id::text
    and o.owner_id = p_id::text
  group by 1
  having count(distinct split_part(storage.filename(o.name), '.', 1)) = 2
  order by max(o.created_at) desc
  limit 1;
$$;
revoke execute on function public.latest_attempt(uuid) from public, anon, authenticated;

-- L14-L15 now also carry the account's earlier rejections, newest first.
drop function public.pending_verifications();
create function public.pending_verifications()
returns table (
  id uuid, full_name text, email text, phone text, account_type public.account_type,
  campus public.campus, submitted_at timestamptz, card_path text, selfie_path text,
  rejections jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  return query
    select p.id, p.full_name, p.email, p.phone, p.account_type, p.campus, p.submitted_at,
      (select o.name from storage.objects o where o.bucket_id = 'verification'
         and o.name like p.id::text || '/' || a.attempt || '/card.%' limit 1),
      (select o.name from storage.objects o where o.bucket_id = 'verification'
         and o.name like p.id::text || '/' || a.attempt || '/selfie.%' limit 1),
      coalesce(
        (select jsonb_agg(jsonb_build_object('reasons', r.reasons, 'note', r.note,
           'rejected_at', r.rejected_at) order by r.rejected_at desc, r.id desc)
         from public.verification_rejections r where r.profile_id = p.id),
        '[]')
    from public.profiles p
    cross join lateral (select public.latest_attempt(p.id) as attempt) a
    where p.status = 'pending'
    order by p.submitted_at, p.id;
end;
$$;
revoke execute on function public.pending_verifications() from public, anon;
grant execute on function public.pending_verifications() to authenticated;

create function public.reject_verification(p_id uuid, p_reasons text[], p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  note text := nullif(btrim(p_note), '');
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  -- Rule 9: at least one reason; 'other' says what in the note.
  if coalesce(cardinality(p_reasons), 0) = 0 or ('other' = any(p_reasons) and note is null) then
    raise exception 'reason_missing' using errcode = 'check_violation';
  end if;
  update public.profiles set status = 'rejected' where id = p_id and status = 'pending';
  if not found then
    raise exception 'not_pending' using errcode = 'check_violation';
  end if;
  insert into public.verification_rejections (profile_id, attempt, reasons, note, rejected_by)
  values (p_id, public.latest_attempt(p_id), p_reasons, note, auth.uid());
end;
$$;

revoke execute on function public.reject_verification(uuid, text[], text) from public, anon;
grant execute on function public.reject_verification(uuid, text[], text) to authenticated;

-- Every status change now goes through a function (PR #52). Releasing a phone (#40) gets
-- its own function too.
revoke update on public.profiles from authenticated;
drop policy "profiles: admin updates" on public.profiles;
