-- 0003_credit_ledger.sql
-- Credit ledger (PRD F3.8, F9.5, D-10, D-17.4). Append-only: clients can only
-- read their own rows; every write goes through a security definer function.
-- Paste into the Supabase SQL Editor after 0002. Re-running is safe.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------
create table if not exists public.credit_ledger (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  delta       integer not null,
  reason      text not null,
  note        text,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),

  constraint credit_ledger_delta_check check (delta <> 0),
  -- Must match CREDIT_REASONS in src/lib/domain/credits.ts (parity test).
  constraint credit_ledger_reason_check check (reason in (
    -- BEGIN CREDIT_REASONS
    'purchase',
    'listing_publish',
    'signup_bonus',
    'admin_adjustment'
    -- END CREDIT_REASONS
  )),
  constraint credit_ledger_note_check check (
    reason <> 'admin_adjustment' or length(btrim(coalesce(note, ''))) between 1 and 200
  )
);

create index if not exists credit_ledger_user_id_idx on public.credit_ledger (user_id, created_at desc);

alter table public.credit_ledger enable row level security;

revoke all on table public.credit_ledger from public, anon, authenticated;
grant select on table public.credit_ledger to authenticated;

drop policy if exists credit_ledger_select_own on public.credit_ledger;
create policy credit_ledger_select_own on public.credit_ledger
  for select to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------------
create or replace function public.beekas_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;
revoke all on function public.beekas_is_admin() from public, anon, authenticated;

-- Serializes every credit change for one user (publish, adjustment) so two
-- concurrent calls cannot both pass the "enough credits" check.
create or replace function public.beekas_lock_credits(target uuid)
returns void
language sql
volatile
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('credits:' || target::text, 0));
$$;
revoke all on function public.beekas_lock_credits(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Current Member's credits = sum of their entries.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_credits()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(l.delta), 0)::integer from public.credit_ledger l where l.user_id = auth.uid();
$$;
revoke all on function public.get_my_credits() from public, anon;
grant execute on function public.get_my_credits() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Credit adjustment by an admin (reason required, never below zero).
-- ---------------------------------------------------------------------------
create or replace function public.admin_adjust_credits(target uuid, delta integer, note text)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_credits integer;
begin
  if not public.beekas_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  if delta is null or delta = 0 then
    raise exception 'invalid_delta' using errcode = '22023';
  end if;
  if length(btrim(coalesce(note, ''))) not between 1 and 200 then
    raise exception 'note_required' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles p where p.id = target) then
    raise exception 'member_not_found' using errcode = 'P0002';
  end if;

  perform public.beekas_lock_credits(target);
  select coalesce(sum(l.delta), 0) into current_credits from public.credit_ledger l where l.user_id = target;
  if current_credits + delta < 0 then
    raise exception 'credits_below_zero' using errcode = '23514';
  end if;

  insert into public.credit_ledger (user_id, delta, reason, note, created_by)
  values (target, delta, 'admin_adjustment', btrim(note), auth.uid());

  return current_credits + delta;
end;
$$;
revoke all on function public.admin_adjust_credits(uuid, integer, text) from public, anon;
grant execute on function public.admin_adjust_credits(uuid, integer, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Admin lookup of Members by email or nickname, with their credits.
-- ---------------------------------------------------------------------------
create or replace function public.admin_find_members(search text)
returns table (id uuid, email text, nickname text, credits integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pattern text;
begin
  if not public.beekas_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  if length(btrim(coalesce(search, ''))) < 2 then
    return;
  end if;
  pattern := '%' || replace(replace(replace(btrim(search), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return query
    select p.id, p.email, p.nickname,
           coalesce((select sum(l.delta) from public.credit_ledger l where l.user_id = p.id), 0)::integer
      from public.profiles p
     where p.email ilike pattern or p.nickname ilike pattern
     order by p.email
     limit 20;
end;
$$;
revoke all on function public.admin_find_members(text) from public, anon;
grant execute on function public.admin_find_members(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Lets scripts/rls-check.mjs (service_role, server-only) flag a test admin.
-- ---------------------------------------------------------------------------
grant select (id), update (is_admin) on public.profiles to service_role;
