-- 0005_listings.sql
-- Listings and publishing (PRD F3.9, F4, D-10, D-17). Paste into the Supabase
-- SQL Editor after 0004. Re-running is safe.
--
-- Listings are publicly readable, except seller_id and meetup_note, which only
-- signed-in Members may read (D-17.1, D-17.6). Nobody inserts directly:
-- publish_listing creates the listing and its -1 ledger entry in one transaction.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------
-- Each list must match its constant in src/lib/domain/listing.ts (parity test);
-- LISTING_CAMPUSES must match CAMPUSES in src/lib/domain/profile.ts.
create table if not exists public.listings (
  id           uuid primary key default gen_random_uuid(),
  seller_id    uuid not null references public.profiles (id) on delete cascade,
  type         text not null,
  title        text not null,
  category     text not null,
  condition    text not null,
  description  text not null,
  price        integer,
  image_path   text not null unique,
  campus       text not null,
  meetup_note  text,
  status       text not null default 'available',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint listings_type_check check (type in (
    -- BEGIN LISTING_TYPES
    'sale', 'donation'
    -- END LISTING_TYPES
  )),
  constraint listings_category_check check (category in (
    -- BEGIN LISTING_CATEGORIES
    'books', 'lab', 'electronics', 'dorm', 'other'
    -- END LISTING_CATEGORIES
  )),
  constraint listings_condition_check check (condition in (
    -- BEGIN LISTING_CONDITIONS
    'like_new', 'good', 'used'
    -- END LISTING_CONDITIONS
  )),
  constraint listings_campus_check check (campus in (
    -- BEGIN LISTING_CAMPUSES
    'kemanggisan', 'senayan', 'alam_sutera', 'base', 'bekasi',
    'bandung', 'malang', 'semarang', 'online'
    -- END LISTING_CAMPUSES
  )),
  constraint listings_status_check check (status in ('available', 'booked', 'sold')),
  -- PRICE_MIN / PRICE_MAX in src/lib/domain/listing.ts (parity test).
  constraint listings_price_check check (
    (type = 'sale' and price between 1000 and 100000000)
    or (type = 'donation' and price is null)
  ),
  -- TITLE_MIN/TITLE_MAX, DESCRIPTION_MAX, MEETUP_NOTE_MAX in listing.ts.
  constraint listings_title_check check (char_length(title) between 3 and 80),
  constraint listings_description_check check (char_length(description) between 1 and 1000),
  constraint listings_meetup_note_check check (meetup_note is null or char_length(meetup_note) between 1 and 100),
  -- The photo must come from the seller's own folder (0004).
  constraint listings_image_path_check check (image_path like seller_id::text || '/%')
);

create index if not exists listings_created_at_idx on public.listings (created_at desc);
create index if not exists listings_seller_id_idx on public.listings (seller_id);

alter table public.listings enable row level security;

revoke all on table public.listings from public, anon, authenticated;
grant select (id, type, title, category, condition, description, price, image_path, campus, status, created_at, updated_at)
  on public.listings to anon, authenticated;
grant select (seller_id, meetup_note) on public.listings to authenticated;

drop policy if exists listings_select_all on public.listings;
create policy listings_select_all on public.listings
  for select to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- 2. Link ledger entries to the listing they paid for.
-- ---------------------------------------------------------------------------
alter table public.credit_ledger
  add column if not exists listing_id uuid references public.listings (id) on delete set null;

-- ---------------------------------------------------------------------------
-- 3. Publish: listing + -1 credit in one transaction (F3.9).
-- ---------------------------------------------------------------------------
create or replace function public.publish_listing(
  p_type text,
  p_title text,
  p_category text,
  p_condition text,
  p_description text,
  p_price integer,
  p_campus text,
  p_meetup_note text,
  p_image_path text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  seller public.profiles%rowtype;
  current_credits integer;
  new_id uuid;
begin
  if uid is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;

  select * into seller from public.profiles p where p.id = uid;
  if seller.id is null or seller.whatsapp is null or seller.nickname is null or seller.campus is null then
    raise exception 'profile_incomplete' using errcode = '22023';
  end if;

  if not exists (
    select 1 from storage.objects o where o.bucket_id = 'listing-photos' and o.name = p_image_path
  ) then
    raise exception 'photo_missing' using errcode = '22023';
  end if;

  perform public.beekas_lock_credits(uid);
  select coalesce(sum(l.delta), 0) into current_credits from public.credit_ledger l where l.user_id = uid;
  if current_credits < 1 then
    raise exception 'no_credits' using errcode = '23514';
  end if;

  insert into public.listings (seller_id, type, title, category, condition, description, price, image_path, campus, meetup_note)
  values (
    uid, p_type, btrim(p_title), p_category, p_condition, btrim(p_description),
    case when p_type = 'donation' then null else p_price end,
    p_image_path, p_campus, nullif(btrim(coalesce(p_meetup_note, '')), '')
  )
  returning id into new_id;

  insert into public.credit_ledger (user_id, delta, reason, listing_id, created_by)
  values (uid, -1, 'listing_publish', new_id, uid);

  return new_id;
end;
$$;
revoke all on function public.publish_listing(text, text, text, text, text, integer, text, text, text) from public, anon;
grant execute on function public.publish_listing(text, text, text, text, text, integer, text, text, text) to authenticated;
