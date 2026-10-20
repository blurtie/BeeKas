-- #65 (D-07, D-19): attempt folders that never reached review (card only, or both photos
-- without Kirim going through) are deleted no later than 30 days after their last upload.
-- Same function, cron and secret as #41; photo_deletions now says why.

alter table public.photo_deletions
  add column reason text not null default 'decided'
    check (reason in ('decided', 'never_submitted'));
alter table public.photo_deletions alter column reason drop default;

-- Due attempts, one row per folder:
--   decided          decided more than 29 days ago (#41, unchanged).
--   never_submitted  no decision covers it, it is not the attempt under review, and its
--                    last file was uploaded more than 29 days ago.
-- 29 days so a daily run always deletes by day 30.
drop function public.expired_verification_photos();
create function public.expired_verification_photos()
returns table (profile_id uuid, attempt text, names text[], reason text)
language sql
stable
security definer
set search_path = ''
as $$
  select profile_id, attempt, names, reason from (
    select p.id as profile_id, f.attempt, array_agg(o.name order by o.name) as names,
      coalesce(
        (select min(r.rejected_at) from public.verification_rejections r
         where r.profile_id = p.id and r.attempt = f.attempt),
        case when p.status = 'approved' then p.approved_at end
      ) as decided_at,
      max(o.created_at) as uploaded_at,
      p.status = 'pending' and f.attempt is not distinct from public.latest_attempt(p.id)
        as under_review
    from storage.objects o
    cross join lateral (select (storage.foldername(o.name))[1] as owner,
                               (storage.foldername(o.name))[2] as attempt) f
    join public.profiles p on p.id::text = f.owner
    where o.bucket_id = 'verification'
      and f.attempt is not null
    group by p.id, f.attempt
  ) a
  cross join lateral (select case
    when decided_at < now() - interval '29 days' then 'decided'
    when decided_at is null and not under_review
      and uploaded_at < now() - interval '29 days' then 'never_submitted'
  end as reason) w
  where reason is not null
  order by profile_id, attempt;
$$;

drop function public.record_photo_deletion(uuid, text, int);
create function public.record_photo_deletion(
  p_profile uuid, p_attempt text, p_objects int, p_reason text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.photo_deletions (profile_id, attempt, objects, reason)
  values (p_profile, p_attempt, p_objects, p_reason);
$$;

revoke execute on function public.expired_verification_photos(),
  public.record_photo_deletion(uuid, text, int, text)
  from public, anon, authenticated;
grant execute on function public.expired_verification_photos(),
  public.record_photo_deletion(uuid, text, int, text)
  to service_role;
