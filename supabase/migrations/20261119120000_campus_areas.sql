-- D-47 (arahan dosen, 19 November 2026): BINUS campuses are far apart, so members only
-- order or bid within their own area. Jabodetabek = Kemanggisan, Senayan, Alam Sutera,
-- BASE, Bekasi; Bandung, Malang and Semarang are each their own area. BINUS Online has
-- no campus: its members reach every area, and no listing is located there.
-- Listings outside the area stay visible (catalog, detail); only ordering is refused.
-- The catalog gains a location filter.

-- The area of a campus; null for BINUS Online.
create function public.campus_area(p_campus public.campus)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_campus in ('kemanggisan', 'senayan', 'alam_sutera', 'base', 'bekasi') then 'jabodetabek'
    when p_campus = 'online' then null
    else p_campus::text
  end;
$$;

-- Whether [p_member] may order or bid on a listing at [p_campus]: same area, or the
-- member has no area (BINUS Online; seeded admins without a campus).
create function public.can_reach(p_member uuid, p_campus public.campus)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select public.campus_area(m.campus) is null
        or public.campus_area(m.campus) = public.campus_area(p_campus)
      from public.profiles m where m.id = p_member),
    true);
$$;

revoke execute on function public.campus_area(public.campus) from public;
grant execute on function public.campus_area(public.campus) to anon, authenticated;
revoke execute on function public.can_reach(uuid, public.campus) from public, anon, authenticated;

-- A listing is met at a physical campus. Not validated on old rows; new and edited
-- listings are checked.
alter table public.listings add constraint listings_campus_physical
  check (campus <> 'online') not valid;

-- As in 20261118120100, also refusing listings outside the buyer's area.
create or replace function public.place_order(
  p_listing uuid,
  p_kind public.order_kind,
  p_cod_campus public.campus,
  p_cod_place text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.listings;
  v_live public.listings;
  v_until timestamptz;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  select * into v_listing from public.listings where id = p_listing for update;
  v_live := v_listing;
  v_live.stock_left := greatest(v_live.stock_left, 1);
  if not found or not public.is_live(v_live) then
    raise exception 'listing_unavailable' using errcode = 'check_violation';
  end if;
  if v_listing.is_donation then
    raise exception 'donation_bid_only' using errcode = 'check_violation';
  end if;
  if v_listing.seller_id = auth.uid() then
    raise exception 'own_listing' using errcode = 'check_violation';
  end if;
  if not public.can_reach(auth.uid(), v_listing.campus) then
    raise exception 'out_of_area' using errcode = 'check_violation';
  end if;
  if exists (select 1 from public.orders where buyer_id = auth.uid() and listing_id = p_listing
      and status in ('waiting', 'processing')) then
    raise exception 'already_ordered' using errcode = 'check_violation';
  end if;
  if v_listing.stock_left < 1 then
    raise exception 'sold_out' using errcode = 'check_violation';
  end if;

  update public.listings set stock_left = stock_left - 1 where id = p_listing;
  insert into public.orders (listing_id, buyer_id, seller_id, kind, price, is_donation,
    hold_until, cod_campus, cod_place)
  values (p_listing, auth.uid(), v_listing.seller_id, p_kind, v_listing.price,
    v_listing.is_donation, now() + interval '24 hours', p_cod_campus, nullif(btrim(p_cod_place), ''))
  returning hold_until into v_until;
  return v_until;
end;
$$;

-- As in 20261118120100, also refusing listings outside the bidder's area.
create or replace function public.place_bid(
  p_listing uuid,
  p_amount integer,
  p_cod_campus public.campus,
  p_cod_place text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.listings;
  v_bid public.donation_bids;
  v_delta integer;
  v_ends timestamptz;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  -- Locks the listing, so close_donation_bids never settles half a raise.
  select * into v_listing from public.listings where id = p_listing for update;
  if not found or not public.is_live(v_listing) then
    raise exception 'listing_unavailable' using errcode = 'check_violation';
  end if;
  if not v_listing.is_donation then
    raise exception 'not_donation' using errcode = 'check_violation';
  end if;
  if v_listing.seller_id = auth.uid() then
    raise exception 'own_listing' using errcode = 'check_violation';
  end if;
  if not public.can_reach(auth.uid(), v_listing.campus) then
    raise exception 'out_of_area' using errcode = 'check_violation';
  end if;
  if v_listing.bid_ends_at is not null and v_listing.bid_ends_at <= now() then
    raise exception 'bidding_closed' using errcode = 'check_violation';
  end if;
  if public.has_running_order(p_listing, auth.uid()) then
    raise exception 'already_ordered' using errcode = 'check_violation';
  end if;

  select * into v_bid from public.donation_bids
    where listing_id = p_listing and bidder_id = auth.uid() and status = 'active';
  v_delta := coalesce(p_amount, 0) - coalesce(v_bid.amount, 0);
  if coalesce(p_amount, 0) < 1 or v_delta < 1 then
    raise exception 'bid_too_low' using errcode = 'check_violation';
  end if;

  update public.quota_balances set balance = balance - v_delta
    where member_id = auth.uid() and balance >= v_delta;
  if not found then
    raise exception 'not_enough_tokens' using errcode = 'check_violation';
  end if;
  insert into public.quota_ledger (member_id, delta, reason, listing_id)
  values (auth.uid(), -v_delta, 'bid', p_listing);

  if v_bid.id is null then
    insert into public.donation_bids (listing_id, bidder_id, amount, cod_campus, cod_place)
    values (p_listing, auth.uid(), p_amount, p_cod_campus, nullif(btrim(p_cod_place), ''));
  else
    update public.donation_bids set amount = p_amount, raised_at = clock_timestamp(),
        cod_campus = p_cod_campus, cod_place = nullif(btrim(p_cod_place), '')
      where id = v_bid.id;
  end if;

  v_ends := coalesce(v_listing.bid_ends_at, now() + interval '24 hours');
  update public.listings set bid_ends_at = v_ends where id = p_listing;
  return v_ends;
end;
$$;

-- As in 20261106120000, with a location filter [p_campuses] (null = all).
drop function public.catalog_listings(text, public.listing_category[], integer, timestamptz, uuid, public.listing_category[]);

create function public.catalog_listings(
  p_query text default null,
  p_categories public.listing_category[] default null,
  p_limit integer default 20,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null,
  p_query_categories public.listing_category[] default null,
  p_campuses public.campus[] default null
)
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
  seller_verified boolean,
  is_mine boolean
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
    p.full_name, p.campus, true, (l.seller_id = auth.uid()) is true
  from public.listings l
  join public.profiles p on p.id = l.seller_id
  -- The removed_at/withdrawn_at tests repeat is_live inline so the planner can use
  -- listings_live_page, whose predicate is exactly these two.
  where l.removed_at is null and l.withdrawn_at is null and public.is_live(l)
    -- strpos, not ilike: % and _ in the query stay plain text.
    and (coalesce(btrim(p_query), '') = ''
      or strpos(lower(l.title), lower(btrim(p_query))) > 0
      or strpos(lower(p.full_name), lower(btrim(p_query))) > 0
      or l.category = any (p_query_categories))
    and (p_categories is null or l.category = any (p_categories))
    and (p_campuses is null or l.campus = any (p_campuses))
    and (p_after_created_at is null
      or l.created_at < p_after_created_at
      or (l.created_at = p_after_created_at and l.id > p_after_id))
  order by l.created_at desc, l.id
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

revoke execute on function public.catalog_listings(text, public.listing_category[], integer, timestamptz, uuid, public.listing_category[], public.campus[]) from public;
grant execute on function public.catalog_listings(text, public.listing_category[], integer, timestamptz, uuid, public.listing_category[], public.campus[]) to anon, authenticated;
