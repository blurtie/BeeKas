-- Photo retention, #41 (D-07). Card and selfie photos of an attempt (D-19) are deleted no
-- later than 30 days after that attempt was decided: approved_at for an approved account,
-- or the attempt's own rejected_at (D-25). Undecided attempts are never touched. Status,
-- approved_by/approved_at, rejections and consent stay; only the files go.
--
-- Files must be deleted through the Storage API: a SQL DELETE on storage.objects leaves the
-- file orphaned in the bucket (supabase.com/docs/guides/storage/management/delete-objects).
-- So pg_cron calls the Edge Function delete-expired-photos daily, which asks this schema what
-- is due, deletes it through the Storage API and records it here.

-- Proof the 30-day promise ran: which attempt, how many files, when. No photo content.
create table public.photo_deletions (
  id bigint generated always as identity primary key,
  profile_id uuid references public.profiles on delete set null,
  attempt text not null,
  objects int not null check (objects > 0),
  deleted_at timestamptz not null default now()
);
create index on public.photo_deletions (profile_id);

-- Server-only: no client role can read or write it.
alter table public.photo_deletions enable row level security;
revoke all on public.photo_deletions from anon, authenticated;

-- Attempts due for deletion, one row per attempt folder. Decided more than 29 days ago, so
-- a daily run always deletes by day 30. An approved account's folders without a rejection
-- (its approved attempt and any partial uploads) count from approved_at.
create function public.expired_verification_photos()
returns table (profile_id uuid, attempt text, names text[])
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, f.attempt, array_agg(o.name order by o.name)
  from storage.objects o
  cross join lateral (select (storage.foldername(o.name))[1] as owner,
                             (storage.foldername(o.name))[2] as attempt) f
  join public.profiles p on p.id::text = f.owner
  where o.bucket_id = 'verification'
    and f.attempt is not null
    and coalesce(
      (select min(r.rejected_at) from public.verification_rejections r
       where r.profile_id = p.id and r.attempt = f.attempt),
      case when p.status = 'approved' then p.approved_at end
    ) < now() - interval '29 days'
  group by p.id, f.attempt
  order by p.id, f.attempt;
$$;

create function public.record_photo_deletion(p_profile uuid, p_attempt text, p_objects int)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.photo_deletions (profile_id, attempt, objects)
  values (p_profile, p_attempt, p_objects);
$$;

-- Same shared-secret lock as send-decision-emails (#33), with its own Vault value.
create function public.photo_retention_cron_secret()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'photo_retention_cron_secret';
$$;

revoke execute on function public.expired_verification_photos(),
  public.record_photo_deletion(uuid, text, int), public.photo_retention_cron_secret()
  from public, anon, authenticated;
grant execute on function public.expired_verification_photos(),
  public.record_photo_deletion(uuid, text, int), public.photo_retention_cron_secret()
  to service_role;

-- L15: say the photos were deleted (D-07) instead of "no photo".
drop function public.pending_verifications();
create function public.pending_verifications()
returns table (
  id uuid, full_name text, email text, phone text, account_type public.account_type,
  campus public.campus, submitted_at timestamptz, card_path text, selfie_path text,
  rejections jsonb, photos_deleted boolean
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
        '[]'),
      exists (select 1 from public.photo_deletions d where d.profile_id = p.id)
    from public.profiles p
    cross join lateral (select public.latest_attempt(p.id) as attempt) a
    where p.status = 'pending'
    order by p.submitted_at, p.id;
end;
$$;
revoke execute on function public.pending_verifications() from public, anon;
grant execute on function public.pending_verifications() to authenticated;

-- Daily at 03:00 UTC (10:00 WIB). URL and secret live in Vault per environment; without
-- them nothing is called and photos wait.
select cron.schedule('delete-expired-photos', '0 3 * * *', $$
  select net.http_post(
    url := u.decrypted_secret,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', s.decrypted_secret))
  from vault.decrypted_secrets u, vault.decrypted_secrets s
  where u.name = 'photo_retention_url' and s.name = 'photo_retention_cron_secret'
$$);
