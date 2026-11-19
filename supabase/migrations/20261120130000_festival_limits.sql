-- Small fixes before BINUS Festival (25 November 2026).
-- - D-51: at most 3 active donation listings per member, since donations are free to
--   list (D-46). Active = live (is_live, PRD-katalog 7.1): not removed, not withdrawn,
--   not expired, stock left. A donation whose units were all given away no longer
--   counts. Enforced in create_listing and relist_listing.
-- - D-47: the Lokasi COD is a physical campus (not BINUS Online) in the buyer's area.
--   Enforced in place_order, place_bid and update_cod (the same column, set later).

-- D-51. The lock keeps two concurrent listings of one member from both passing.
create function public.check_donation_limit(p_member uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('donation-listings:' || p_member::text, 0));
  if (select count(*) from public.listings l
      where l.seller_id = p_member and l.is_donation and public.is_live(l)) >= 3 then
    raise exception 'donation_listing_limit' using errcode = 'check_violation';
  end if;
end;
$$;

-- D-47 for the Lokasi COD of [p_member]'s order or bid.
create function public.check_cod_campus(p_member uuid, p_campus public.campus)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_campus is null or p_campus = 'online' then
    raise exception 'cod_campus_online' using errcode = 'check_violation';
  end if;
  if not public.can_reach(p_member, p_campus) then
    raise exception 'cod_out_of_area' using errcode = 'check_violation';
  end if;
end;
$$;

revoke execute on function public.check_donation_limit(uuid),
  public.check_cod_campus(uuid, public.campus) from public, anon, authenticated;

-- As in 20261118120100, also checking D-51 for donations.
create or replace function public.create_listing(
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
  p_photos text[],
  p_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_seller uuid;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_id::text, 0));
  select seller_id into v_seller from public.listings where id = v_id;
  if found then
    if v_seller = auth.uid() then
      return v_id;
    end if;
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(cardinality(p_photos), 0) < 1 then
    raise exception 'no_photos' using errcode = 'check_violation';
  end if;
  if exists (select 1 from unnest(p_photos) path where path is null or path not like auth.uid()::text || '/%' or path like '%..%') then
    raise exception 'not_own_photo' using errcode = 'insufficient_privilege';
  end if;

  if coalesce(p_is_donation, false) then
    perform public.check_donation_limit(auth.uid());
  else
    update public.quota_balances set balance = balance - 1
      where member_id = auth.uid() and balance >= 1;
    if not found then
      raise exception 'no_quota' using errcode = 'check_violation';
    end if;
  end if;

  insert into public.listings (id, seller_id, title, description, category, condition,
    price, stock, campus, warranty, specs, is_donation, expires_at)
  values (v_id, auth.uid(), p_title, p_description, p_category, p_condition, p_price,
    p_stock, p_campus, p_warranty, p_specs, p_is_donation, now() + interval '60 days');

  insert into public.listing_photos (listing_id, position, path)
  select v_id, ord, path from unnest(p_photos) with ordinality as t(path, ord);

  if not coalesce(p_is_donation, false) then
    insert into public.quota_ledger (member_id, delta, reason, listing_id)
    values (auth.uid(), -1, 'listing', v_id);
  end if;
  return v_id;
end;
$$;

-- As in 20261104120000, also checking D-51 for donations.
create or replace function public.relist_listing(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if exists (select 1 from public.listings where id = p_id and seller_id = auth.uid() and is_donation) then
    perform public.check_donation_limit(auth.uid());
  end if;
  update public.listings set expires_at = now() + interval '60 days', withdrawn_at = null
    where id = p_id and seller_id = auth.uid() and removed_at is null
      and (withdrawn_at is not null or expires_at <= now());
  if not found then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
end;
$$;

-- As in 20261119120000, also checking the Lokasi COD.
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
  perform public.check_cod_campus(auth.uid(), p_cod_campus);
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

-- As in 20261119120000, also checking the Lokasi COD.
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
  perform public.check_cod_campus(auth.uid(), p_cod_campus);
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

-- As in 20261105120000; a changed Lokasi COD is checked against the buyer's area.
create or replace function public.update_cod(
  p_id uuid,
  p_cod_campus public.campus,
  p_cod_place text,
  p_cod_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders := public.order_for_party(p_id, null);
begin
  if v_order.status not in ('waiting', 'processing')
      or (v_order.status = 'waiting' and p_cod_at is not null) then
    perform public.order_transition();
  end if;
  if p_cod_campus is distinct from v_order.cod_campus then
    perform public.check_cod_campus(v_order.buyer_id, p_cod_campus);
  end if;
  -- An unchanged time may already be past (moving only the place after the COD).
  if v_order.status = 'processing' and p_cod_at is distinct from v_order.cod_at then
    perform public.check_cod_time(p_cod_at);
  end if;
  update public.orders set cod_campus = p_cod_campus,
      cod_place = nullif(btrim(p_cod_place), ''), cod_at = p_cod_at
    where id = p_id;
end;
$$;
