-- 0001_profiles.sql
-- BeeKas profiles table, campus-email gate on sign-up, RLS and grants.
-- Paste into the Supabase SQL Editor. Re-running is safe for functions,
-- triggers, policies and grants; the table is created only if missing.
--
-- Project settings assumed: "automatically expose new tables" OFF and
-- "automatic RLS" ON, so every grant and policy below is explicit.

-- ---------------------------------------------------------------------------
-- 1. Domain rules (single SQL source of truth)
-- ---------------------------------------------------------------------------
-- Must match ALLOWED_EMAIL_DOMAINS in src/lib/domain/campus-email.ts.
-- A Vitest parity test parses the block between the BEGIN/END markers.
-- Format, one domain per line, nothing else inside the block:
--       when '<domain>' then '<user_type>'
-- (lowercase domain, single quotes, one space between tokens.)
--
-- Matching mirrors userTypeFromEmail(): trim + lowercase, take the part after
-- the LAST '@' (at least one character must precede it), exact match only.
-- Subdomains and look-alikes (evilbinus.ac.id, binus.ac.id.evil.com) fail.
create or replace function public.beekas_user_type_from_email(email text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case pg_catalog.substring(pg_catalog.lower(pg_catalog.btrim(email)), '^.+@([^@]+)$')
    -- BEGIN ALLOWED_EMAIL_DOMAINS
    when 'binus.ac.id' then 'student'
    when 'binus.edu' then 'staff'
    -- END ALLOWED_EMAIL_DOMAINS
    else null
  end;
$$;

-- Pure helper; harmless, but nobody outside the database needs it.
revoke all on function public.beekas_user_type_from_email(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. profiles table
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  nickname    text,
  email       text not null,
  user_type   text not null,
  major       text,
  binusian    text,
  whatsapp    text,
  campus      text,
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now(),

  constraint profiles_nickname_check
    check (nickname is null or char_length(btrim(nickname)) between 2 and 30),
  constraint profiles_major_check
    check (major is null or char_length(btrim(major)) between 1 and 100),
  -- Must match CAMPUSES in src/lib/domain/profile.ts (verify with team).
  -- A Vitest parity test parses the quoted codes between the BEGIN/END markers.
  constraint profiles_campus_check
    check (campus is null or campus in (
      -- BEGIN CAMPUSES
      'anggrek', 'syahdan', 'kijang', 'jwc', 'fx', 'alam_sutera',
      'base', 'bekasi', 'bandung', 'malang', 'semarang'
      -- END CAMPUSES
    )),
  -- TODO(PRD F2.3): major is required for students. It is temporarily optional
  -- (students may set binusian without major) until the official major list
  -- exists. Once MAJOR_GROUPS is filled, add a student check here, e.g.
  --   check (user_type <> 'student' or ((major is null) = (binusian is null)))
  -- plus a value-list check on major.
  constraint profiles_user_type_check
    check (user_type in ('student', 'staff')),
  constraint profiles_binusian_check
    check (binusian is null or binusian in ('B27', 'B28', 'B29', 'B30')),
  constraint profiles_whatsapp_check
    check (whatsapp is null or whatsapp ~ '^628[0-9]{8,11}$'),
  -- Staff have no major or binusian year. Completeness is not enforced here
  -- because the row is created empty at sign-up.
  constraint profiles_staff_fields_check
    check (user_type <> 'staff' or (major is null and binusian is null))
);

alter table public.profiles enable row level security;

-- ---------------------------------------------------------------------------
-- 3. Grants: clients may read their row and edit only the editable columns.
--    email, user_type, is_admin, id, created_at are never client-writable.
-- ---------------------------------------------------------------------------
revoke all on table public.profiles from public, anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (nickname, major, binusian, whatsapp, campus)
  on table public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RLS: own row only. No insert/delete policies (rows come from the trigger,
--    deletion cascades from auth.users).
-- ---------------------------------------------------------------------------
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 5. Sign-up gate on auth.users
-- ---------------------------------------------------------------------------
-- BEFORE INSERT: reject any email outside the allowed domains
-- (also covers null email, e.g. phone sign-ups).
create or replace function public.beekas_enforce_campus_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.beekas_user_type_from_email(new.email) is null then
    raise exception 'not_campus_domain'
      using errcode = 'check_violation',
            hint = 'Sign up with a binus.ac.id or binus.edu email.';
  end if;
  return new;
end;
$$;

revoke all on function public.beekas_enforce_campus_email() from public, anon, authenticated;

drop trigger if exists beekas_enforce_campus_email on auth.users;
create trigger beekas_enforce_campus_email
  before insert on auth.users
  for each row execute function public.beekas_enforce_campus_email();

-- AFTER INSERT: create the profile. email and user_type come from auth.users,
-- never from user-supplied metadata.
create or replace function public.beekas_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, user_type)
  values (
    new.id,
    pg_catalog.lower(pg_catalog.btrim(new.email)),
    public.beekas_user_type_from_email(new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.beekas_handle_new_user() from public, anon, authenticated;

drop trigger if exists beekas_on_auth_user_created on auth.users;
create trigger beekas_on_auth_user_created
  after insert on auth.users
  for each row execute function public.beekas_handle_new_user();

-- Email changes are not allowed (user decision). Blocking them in the DB keeps
-- profiles.email and user_type permanently consistent with auth.users.
-- Drop the earlier sync trigger/function if a previous draft was applied.
drop trigger if exists beekas_on_auth_user_email_changed on auth.users;
drop function if exists public.beekas_sync_user_email();

create or replace function public.beekas_block_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is distinct from old.email then
    raise exception 'email_change_not_allowed'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

revoke all on function public.beekas_block_email_change() from public, anon, authenticated;

drop trigger if exists beekas_block_email_change on auth.users;
create trigger beekas_block_email_change
  before update of email on auth.users
  for each row execute function public.beekas_block_email_change();

-- ---------------------------------------------------------------------------
-- 6. Public profile view (PRD F2.6): never email, whatsapp or is_admin.
-- ---------------------------------------------------------------------------
create or replace function public.get_public_profile(profile_id uuid)
returns table (
  id        uuid,
  nickname  text,
  user_type text,
  major     text,
  binusian  text,
  campus    text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.nickname, p.user_type, p.major, p.binusian, p.campus
    from public.profiles p
   where p.id = profile_id;
$$;

-- Signed-in users only: anonymous visitors must not read seller identity.
-- Whether anon catalog cards may show campus is an open Fase 2 decision.
revoke all on function public.get_public_profile(uuid) from public, anon;
grant execute on function public.get_public_profile(uuid) to authenticated;
