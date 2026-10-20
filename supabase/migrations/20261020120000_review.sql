-- Admin review, L14-L15 (D-09). Who approved and when stays after the photos are deleted
-- (D-07). The status trigger stamps it, so admins' direct status UPDATE records it too.
alter table public.profiles
  -- When the files were last sent; L14 lists the longest waiting first.
  add column submitted_at timestamptz,
  add column approved_by uuid references public.profiles on delete set null,
  add column approved_at timestamptz;

update public.profiles p set submitted_at = coalesce(
  (select max(o.created_at) from storage.objects o
   where o.bucket_id = 'verification' and (storage.foldername(o.name))[1] = p.id::text),
  p.created_at)
where p.status = 'pending';

create or replace function public.guard_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
    and old.status::text || '>' || new.status::text not in (
      'incomplete>pending', 'pending>approved', 'pending>rejected', 'rejected>pending'
    )
  then
    raise exception 'illegal_status_transition: % -> %', old.status, new.status
      using errcode = 'check_violation';
  end if;
  if new.status is distinct from old.status then
    case new.status
      when 'rejected' then new.last_rejected_at := now();
      when 'pending' then new.submitted_at := now();
      when 'approved' then
        new.approved_by := auth.uid();
        new.approved_at := now();
      else
    end case;
  end if;
  return new;
end;
$$;

-- L14: pending accounts with their latest complete attempt, longest waiting first.
create function public.pending_verifications()
returns table (
  id uuid, full_name text, email text, phone text, account_type public.account_type,
  campus public.campus, submitted_at timestamptz, card_path text, selfie_path text
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
         and o.name like p.id::text || '/' || a.attempt || '/selfie.%' limit 1)
    from public.profiles p
    left join lateral (
      -- Earlier attempts may be partial uploads; the newest folder holding both counts.
      select (storage.foldername(o.name))[2] as attempt
      from storage.objects o
      where o.bucket_id = 'verification'
        and (storage.foldername(o.name))[1] = p.id::text
        and o.owner_id = p.id::text
      group by 1
      having count(distinct split_part(storage.filename(o.name), '.', 1)) = 2
      order by max(o.created_at) desc
      limit 1
    ) a on true
    where p.status = 'pending'
    order by p.submitted_at, p.id;
end;
$$;

create function public.approve_verification(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  update public.profiles set status = 'approved' where id = p_id and status = 'pending';
  if not found then
    raise exception 'not_pending' using errcode = 'check_violation';
  end if;
end;
$$;

revoke execute on function public.pending_verifications(), public.approve_verification(uuid)
  from public, anon;
grant execute on function public.pending_verifications(), public.approve_verification(uuid)
  to authenticated;
