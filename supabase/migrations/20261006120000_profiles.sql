-- Account schema for onboarding, registration, and sign-in (docs/PRD.md).

create type public.account_type as enum ('student', 'lecturer', 'staff');
create type public.account_status as enum ('incomplete', 'pending', 'approved', 'rejected');
create type public.user_role as enum ('member', 'admin');
-- D-12
create type public.campus as enum (
  'kemanggisan', 'senayan', 'alam_sutera', 'base', 'bekasi', 'bandung', 'malang', 'semarang', 'online'
);

create table public.profiles (
  -- Deferrable so the local seed can insert the admin profile before its auth user.
  id uuid primary key references auth.users on delete cascade deferrable initially immediate,
  full_name text not null check (btrim(full_name) <> ''),
  email text not null unique check (email = lower(btrim(email))),
  -- Rule 2: Indonesian mobile, 10-13 digits counting the leading 08, stored as +628 then 8-11 digits.
  -- Null after an admin releases it (D-04).
  phone text unique check (phone ~ '^\+628[0-9]{8,11}$'),
  account_type public.account_type,
  campus public.campus,
  status public.account_status not null default 'incomplete',
  role public.user_role not null default 'member',
  created_at timestamptz not null default now(),
  -- Set by guard_status_transition; photos must be newer than this to resubmit (D-08).
  last_rejected_at timestamptz,
  -- Rule 1 and D-15: members have a BINUS email whose domain fixes the account type.
  -- The seeded admin (D-09) is exempt.
  constraint member_identity check (
    role = 'admin'
    or (
      campus is not null
      and (
        (email ~ '^[^@[:space:]]+@binus\.ac\.id$' and account_type = 'student')
        or (email ~ '^[^@[:space:]]+@binus\.edu$' and account_type in ('lecturer', 'staff'))
      )
    )
  )
);

-- Rule 7: only legal status transitions.
create function public.guard_status_transition()
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
  if new.status = 'rejected' and old.status is distinct from 'rejected' then
    new.last_rejected_at := now();
  end if;
  return new;
end;
$$;

create trigger profiles_status_transition
  before update of status on public.profiles
  for each row execute function public.guard_status_transition();

-- Creates the profile from sign-up metadata. Role and status always take their defaults;
-- account type comes from the email domain, metadata may only pick lecturer/staff for binus.edu.
create function public.handle_new_user()
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

  if nullif(btrim(meta ->> 'phone'), '') is null then
    raise exception 'phone_required' using errcode = 'not_null_violation';
  end if;

  insert into public.profiles (id, full_name, email, phone, account_type, campus)
  values (
    new.id,
    btrim(meta ->> 'full_name'),
    v_email,
    btrim(meta ->> 'phone'),
    v_type,
    (meta ->> 'campus')::public.campus
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- RLS: members read only their own profile and never write it directly (changes go through
-- the functions below). Admins read all and may update status and phone.
alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (status, phone) on public.profiles to authenticated;

create policy "profiles: read own, admin reads all"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

create policy "profiles: admin updates"
  on public.profiles for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- Member actions on their own profile (auth.uid(), never a profile id argument).

create function public.submit_for_review()
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

-- Fills a new number after an admin released the old one (L14-L15). Format and uniqueness
-- come from the table constraints.
create function public.set_phone(p_phone text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'insufficient_privilege';
  end if;
  update public.profiles set phone = btrim(p_phone)
    where id = auth.uid() and phone is null;
  if not found then
    raise exception 'phone_not_released' using errcode = 'check_violation';
  end if;
end;
$$;

-- Name and campus stay editable until the files are submitted, and again after a rejection.
create function public.update_identity(p_full_name text, p_campus public.campus)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'insufficient_privilege';
  end if;
  update public.profiles set full_name = btrim(p_full_name), campus = p_campus
    where id = auth.uid() and status in ('incomplete', 'rejected');
  if not found then
    raise exception 'identity_locked' using errcode = 'check_violation';
  end if;
end;
$$;

revoke execute on function
  public.handle_new_user(), public.is_admin(), public.submit_for_review(),
  public.set_phone(text), public.update_identity(text, public.campus)
  from public, anon;
grant execute on function
  public.is_admin(), public.submit_for_review(), public.set_phone(text),
  public.update_identity(text, public.campus)
  to authenticated;

-- Private bucket for ID card photos and selfies (D-07). Each attempt gets its own folder,
-- <user id>/<attempt>/card.jpg and selfie.jpg, because members cannot overwrite: Storage
-- needs read access for that and only admins read (D-07).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('verification', 'verification', false, 5242880, array['image/jpeg', 'image/png']);

create policy "verification: member uploads own photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'verification'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 2
    and storage.filename(name) ~ '^(card|selfie)\.(jpg|png)$'
    and exists (
      select 1 from public.profiles
      where id = (select auth.uid()) and status in ('incomplete', 'rejected')
    )
  );

create policy "verification: admin reads photos"
  on storage.objects for select to authenticated
  using (bucket_id = 'verification' and (select public.is_admin()));
