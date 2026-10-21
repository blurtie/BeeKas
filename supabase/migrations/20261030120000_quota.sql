-- Listing quota (#81, D-29, K-08). Members read their own balance; only functions
-- here write it. Every change lands in quota_ledger so the balance can be audited.

create table public.quota_balances (
  member_id uuid primary key references public.profiles on delete cascade,
  balance integer not null check (balance >= 0)
);

create type public.quota_reason as enum ('starting', 'purchase', 'listing', 'correction');

-- The PRD-katalog 7.2 amounts: +1 starting (K-08), +3 package, -1 listing, +1 admin
-- correction with the admin and a note.
create table public.quota_ledger (
  id bigint generated always as identity primary key,
  member_id uuid not null references public.profiles on delete cascade,
  delta integer not null,
  reason public.quota_reason not null,
  listing_id uuid references public.listings on delete set null,
  -- No set null: a correction must keep its admin, so such an admin cannot be deleted.
  admin_id uuid references public.profiles,
  note text check (btrim(note) <> ''),
  created_at timestamptz not null default now(),
  constraint quota_ledger_amount check (case reason
    when 'starting' then delta = 1
    when 'purchase' then delta = 3
    when 'listing' then delta = -1
    when 'correction' then delta = 1 and admin_id is not null and note is not null
  end)
);

create index quota_ledger_member on public.quota_ledger (member_id);

alter table public.quota_balances enable row level security;
alter table public.quota_ledger enable row level security;
revoke all on public.quota_balances, public.quota_ledger from anon, authenticated;
grant select on public.quota_balances to authenticated;

create policy "quota balances: members read their own"
  on public.quota_balances for select to authenticated
  using (member_id = auth.uid());

-- K-08: the starting balance comes once, the first time an account is approved. The
-- balance row only ever appears here or later, so its existence marks the grant.
create function public.grant_starting_quota()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.quota_balances (member_id, balance) values (new.id, 1)
    on conflict (member_id) do nothing;
  if found then
    insert into public.quota_ledger (member_id, delta, reason) values (new.id, 1, 'starting');
  end if;
  return null;
end;
$$;

revoke execute on function public.grant_starting_quota() from public, anon, authenticated;

create trigger profiles_starting_quota
  after update of status on public.profiles
  for each row when (new.status = 'approved' and old.status is distinct from 'approved')
  execute function public.grant_starting_quota();

-- Null for listings made before quotas; expired-listing filtering comes later (K-07).
alter table public.listings add column expires_at timestamptz;

-- K5-K6 "Pasang" (PRD-katalog 7.1): one quota buys a listing that runs for 60 days.
create function public.create_listing(
  p_title text,
  p_description text,
  p_category public.listing_category,
  p_condition public.listing_condition,
  p_price integer,
  p_stock integer,
  p_campus public.campus,
  p_warranty text,
  p_specs text[],
  p_is_donation boolean,
  p_photos text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  -- D-28: 1-5 photos. listing_photos caps the positions at 5.
  if coalesce(cardinality(p_photos), 0) < 1 then
    raise exception 'no_photos' using errcode = 'check_violation';
  end if;
  -- PRD-katalog 7.1: sellers upload only into their own folder.
  if exists (select 1 from unnest(p_photos) path where path is null or path not like auth.uid()::text || '/%' or path like '%..%') then
    raise exception 'not_own_photo' using errcode = 'insufficient_privilege';
  end if;

  update public.quota_balances set balance = balance - 1
    where member_id = auth.uid() and balance >= 1;
  if not found then
    raise exception 'no_quota' using errcode = 'check_violation';
  end if;

  insert into public.listings (seller_id, title, description, category, condition, price,
    stock, campus, warranty, specs, is_donation, expires_at)
  values (auth.uid(), p_title, p_description, p_category, p_condition, p_price,
    p_stock, p_campus, p_warranty, p_specs, p_is_donation, now() + interval '60 days')
  returning id into v_id;

  insert into public.listing_photos (listing_id, position, path)
  select v_id, ord, path from unnest(p_photos) with ordinality as t(path, ord);

  insert into public.quota_ledger (member_id, delta, reason, listing_id)
  values (auth.uid(), -1, 'listing', v_id);
  return v_id;
end;
$$;

revoke execute on function public.create_listing(text, text, public.listing_category,
  public.listing_condition, integer, integer, public.campus, text, text[], boolean, text[])
  from public, anon;
grant execute on function public.create_listing(text, text, public.listing_category,
  public.listing_condition, integer, integer, public.campus, text, text[], boolean, text[])
  to authenticated;
