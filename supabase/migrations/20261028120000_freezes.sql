-- Catalog shows only sellers who are approved and not frozen (#76). Freezing is kept
-- apart from account_status (D-33): one admin proposes, a different admin approves.
-- The admin screens and RPCs come in T10; members get no direct access here.

create table public.freezes (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles on delete cascade,
  reason text not null check (btrim(reason) <> ''),
  proposed_by uuid not null references public.profiles,
  proposed_at timestamptz not null default now(),
  approved_by uuid references public.profiles,
  approved_at timestamptz,
  lifted_at timestamptz,
  constraint freeze_two_admins check (approved_by <> proposed_by),
  constraint freeze_not_self check (member_id <> proposed_by and member_id <> approved_by),
  constraint freeze_approval check ((approved_by is null) = (approved_at is null)),
  constraint freeze_lift_after_approval check (lifted_at is null or approved_at is not null)
);

-- At most one open freeze (proposed or approved, not lifted) per member; also the
-- lookup is_frozen runs on every catalog row.
create unique index freezes_one_open on public.freezes (member_id) where lifted_at is null;

alter table public.freezes enable row level security;
revoke all on public.freezes from anon, authenticated;

-- True only while an approved freeze has not been lifted; a bare proposal hides nothing.
create function public.is_frozen(p_member uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.freezes f
    where f.member_id = p_member and f.approved_at is not null and f.lifted_at is null
  );
$$;

-- profiles RLS hides other members' status, so the catalog asks through this.
create function public.is_listed_seller(p_seller uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles p where p.id = p_seller and p.status = 'approved')
    and not public.is_frozen(p_seller);
$$;

-- RLS needs is_listed_seller; is_frozen stays server-side. Hiding listings already
-- tells a viewer the seller is no longer listed, so is_listed_seller leaks nothing new.
revoke execute on function public.is_frozen(uuid), public.is_listed_seller(uuid) from public, anon, authenticated;
grant execute on function public.is_listed_seller(uuid) to anon, authenticated;

drop policy "listings: everyone reads active" on public.listings;
create policy "listings: everyone reads active from listed sellers"
  on public.listings for select to anon, authenticated
  using (is_active and public.is_listed_seller(seller_id));

drop policy "listing photos: everyone reads active listings' photos" on public.listing_photos;
create policy "listing photos: everyone reads listed listings' photos"
  on public.listing_photos for select to anon, authenticated
  -- The listings policy above filters this subquery.
  using (exists (select 1 from public.listings l where l.id = listing_id));

create or replace function public.catalog_listings()
returns table (
  id uuid,
  title text,
  description text,
  category public.listing_category,
  condition public.listing_condition,
  price integer,
  previous_price integer,
  stock integer,
  campus public.campus,
  warranty text,
  specs text[],
  is_donation boolean,
  created_at timestamptz,
  photos text[],
  seller_name text,
  seller_campus public.campus,
  seller_verified boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.title, l.description, l.category, l.condition, l.price, l.previous_price,
    l.stock, l.campus, l.warranty, l.specs, l.is_donation, l.created_at,
    coalesce(
      (select array_agg(ph.path order by ph.position) from public.listing_photos ph
        where ph.listing_id = l.id),
      '{}'
    ),
    p.full_name, p.campus, true
  from public.listings l
  join public.profiles p on p.id = l.seller_id
  where l.is_active and public.is_listed_seller(l.seller_id)
  order by l.created_at desc, l.id;
$$;
