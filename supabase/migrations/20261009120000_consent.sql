-- Proof of the L7 consent (D-07, D-20): when the member agreed and to which text version.
-- Members read it with their profile but write it only through record_consent (only status
-- and phone are granted for UPDATE).
alter table public.profiles
  add column consent_at timestamptz,
  add column consent_version text;

create function public.record_consent(p_version text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'insufficient_privilege';
  end if;
  if nullif(btrim(p_version), '') is null then
    raise exception 'consent_version_required' using errcode = 'check_violation';
  end if;
  update public.profiles set consent_at = now(), consent_version = btrim(p_version)
    where id = auth.uid() and status in ('incomplete', 'rejected');
  if not found then
    raise exception 'consent_locked' using errcode = 'check_violation';
  end if;
end;
$$;

revoke execute on function public.record_consent(text) from public, anon;
grant execute on function public.record_consent(text) to authenticated;

-- No photo before consent.
drop policy "verification: member uploads own photos" on storage.objects;
create policy "verification: member uploads own photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'verification'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 2
    and storage.filename(name) ~ '^(card|selfie)\.(jpg|png)$'
    and exists (
      select 1 from public.profiles
      where id = (select auth.uid())
        and status in ('incomplete', 'rejected')
        and consent_at is not null
    )
  );
