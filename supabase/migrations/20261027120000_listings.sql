-- Catalog, read side (#74). Anyone, guests included, reads active listings (D-06).
-- Writing listings comes later: no insert/update/delete for anon or members yet.

create type public.listing_category as enum (
  'laptop_computer', 'phone_gadget', 'accessories', 'clothing', 'shoes', 'bags',
  'books_stationery', 'campus_supplies', 'other'
);
create type public.listing_condition as enum ('like_new', 'used_good', 'used_flawed');

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles on delete cascade,
  title text not null check (btrim(title) <> '' and char_length(title) <= 100),
  description text not null check (btrim(description) <> '' and char_length(description) <= 2000),
  category public.listing_category not null,
  condition public.listing_condition not null,
  -- Rupiah. Donations are free; sales cost Rp1.000-Rp50.000.000.
  price integer not null,
  -- The struck-through price, set by listings_previous_price when the price drops.
  previous_price integer,
  stock integer not null default 1 check (stock >= 1),
  campus public.campus not null,
  warranty text check (btrim(warranty) <> ''),
  specs text[] check (cardinality(specs) between 1 and 10),
  is_donation boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint listing_price check (
    case when is_donation then price = 0 else price between 1000 and 50000000 end
  ),
  constraint listing_previous_price check (previous_price > price)
);

create index listings_active_newest on public.listings (created_at desc) where is_active;

create function public.set_previous_price()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.previous_price := case when new.price < old.price then old.price end;
  return new;
end;
$$;

create trigger listings_previous_price
  before update of price on public.listings
  for each row when (new.price is distinct from old.price)
  execute function public.set_previous_price();

-- 1-5 photos per listing, in order. Paths point into the listing-photos bucket.
create table public.listing_photos (
  listing_id uuid not null references public.listings on delete cascade,
  position smallint not null check (position between 1 and 5),
  path text not null check (btrim(path) <> ''),
  primary key (listing_id, position)
);

alter table public.listings enable row level security;
alter table public.listing_photos enable row level security;
revoke all on public.listings, public.listing_photos from anon, authenticated;
grant select on public.listings, public.listing_photos to anon, authenticated;

create policy "listings: everyone reads active"
  on public.listings for select to anon, authenticated
  using (is_active);

create policy "listing photos: everyone reads active listings' photos"
  on public.listing_photos for select to anon, authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id and l.is_active));

-- Active listings, newest first, with the seller's public data only: name, campus and
-- verified. Never email or phone (D-26); profiles RLS stays closed to other members.
create function public.catalog_listings()
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
    p.full_name, p.campus, p.status = 'approved'
  from public.listings l
  join public.profiles p on p.id = l.seller_id
  where l.is_active
  order by l.created_at desc, l.id;
$$;

revoke execute on function public.catalog_listings(), public.set_previous_price() from public;
grant execute on function public.catalog_listings() to anon, authenticated;

-- Public bucket: product photos are meant to be seen by everyone. No upload policy yet.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-photos', 'listing-photos', true, 5242880, array['image/jpeg', 'image/png']);
