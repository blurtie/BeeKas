-- Since phone_after_otp a profile can exist without a phone, and admins must check the
-- number during review (D-04). Submitting without one is refused.

create or replace function public.submit_for_review()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = 'insufficient_privilege';
  end if;
  if (select phone from public.profiles where id = uid) is null then
    raise exception 'phone_missing' using errcode = 'check_violation';
  end if;
  -- Both photos must be uploaded by this member after the last rejection.
  if (
    select count(distinct storage.filename(o.name))
    from storage.objects o, public.profiles p
    where p.id = uid
      and o.bucket_id = 'verification'
      and o.owner_id = uid::text
      and (storage.foldername(o.name))[1] = uid::text
      and storage.filename(o.name) ~ '^(card|selfie)\.'
      and o.created_at > coalesce(p.last_rejected_at, '-infinity')
  ) < 2 then
    raise exception 'photos_missing' using errcode = 'check_violation';
  end if;
  update public.profiles set status = 'pending'
    where id = uid and status in ('incomplete', 'rejected');
  if not found then
    raise exception 'illegal_status_transition' using errcode = 'check_violation';
  end if;
end;
$$;
