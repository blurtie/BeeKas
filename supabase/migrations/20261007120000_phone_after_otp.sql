-- The phone is no longer taken from sign-up metadata. GoTrue hides every trigger error
-- behind a generic 500 for current clients, so a taken number could not be reported. The
-- app now calls set_phone after the OTP is verified, where 23505 reaches the client.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_email text := lower(btrim(new.email));
  v_type public.account_type;
begin
  -- Only DB operators can pre-create a profile (the local admin seed).
  if exists (select 1 from public.profiles where id = new.id) then
    return new;
  end if;

  if v_email ~ '@binus\.ac\.id$' then
    if meta ? 'account_type' then
      raise exception 'account_type_not_allowed' using errcode = 'check_violation';
    end if;
    v_type := 'student';
  elsif v_email ~ '@binus\.edu$' then
    if coalesce(meta ->> 'account_type', '') not in ('lecturer', 'staff') then
      raise exception 'account_type_required' using errcode = 'check_violation';
    end if;
    v_type := (meta ->> 'account_type')::public.account_type;
  else
    raise exception 'invalid_email_domain' using errcode = 'check_violation';
  end if;

  if nullif(btrim(meta ->> 'full_name'), '') is null then
    raise exception 'full_name_required' using errcode = 'not_null_violation';
  end if;
  -- Checked here because a failed enum cast reaches the app only as a generic auth error.
  if coalesce(meta ->> 'campus', '') not in (select unnest(enum_range(null::public.campus))::text) then
    raise exception 'invalid_campus' using errcode = 'check_violation';
  end if;

  -- Phone stays null until set_phone; any phone in the metadata is ignored.
  insert into public.profiles (id, full_name, email, account_type, campus)
  values (
    new.id,
    btrim(meta ->> 'full_name'),
    v_email,
    v_type,
    (meta ->> 'campus')::public.campus
  );
  return new;
end;
$$;

-- set_phone (unchanged) now also fills the first number: it only writes while phone is null.
comment on function public.set_phone(text) is
  'Sets the phone while it is null: after sign-up (L5) or after an admin released it (D-04).';
