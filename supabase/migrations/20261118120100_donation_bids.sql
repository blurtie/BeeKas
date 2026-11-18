-- D-46 (arahan dosen, 18 November 2026): donations are free to list and are given by
-- token bids. A token is one unit of the listing quota balance (quota_balances).
-- - create_listing takes no token for a donation.
-- - Donations are no longer ordered with Booking 24 Jam or Beli Sekarang. Approved
--   members bid tokens instead; the first bid opens a 24-hour window; when it closes the
--   highest bids win, one unit each (ties: whoever reached the amount first).
-- - A bid holds its tokens at once. Winners spend them; the rest get them back.
-- - A winner gets a Beli Sekarang order at Rp0, which then runs like any order (the donor
--   accepts with a COD time, Selesai, or Dibatalkan). If the donor or the timers cancel
--   it, the winner's tokens come back; if the winner cancels, they do not.
-- - D-30's limit of 2 running donations no longer applies: tokens ration donations.

-- Ledger: a bid holds tokens (negative), a refund returns them (positive).
alter table public.quota_ledger drop constraint quota_ledger_amount;
alter table public.quota_ledger add constraint quota_ledger_amount check (case reason
  when 'starting' then delta = 1
  when 'migration_start' then delta = 1
  when 'purchase' then delta = 3
  when 'listing' then delta = -1
  when 'correction' then delta = 1 and admin_id is not null and note is not null
  when 'bid' then delta < 0 and listing_id is not null
  when 'bid_refund' then delta > 0 and listing_id is not null
end);

-- Null until the first bid; back to null when the window has been settled.
alter table public.listings add column bid_ends_at timestamptz;

create type public.bid_status as enum ('active', 'won', 'lost', 'refunded');

create table public.donation_bids (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings on delete restrict,
  bidder_id uuid not null references public.profiles on delete cascade,
  amount integer not null check (amount >= 1),
  status public.bid_status not null default 'active',
  -- Copied into the order when the bid wins (Lokasi COD, D-30).
  cod_campus public.campus not null,
  cod_place text check (btrim(cod_place) <> '' and char_length(cod_place) <= 200),
  order_id uuid unique references public.orders on delete set null,
  -- Clock time, not transaction time: it orders ties.
  created_at timestamptz not null default clock_timestamp(),
  -- When the amount was last raised: the earlier one wins a tie.
  raised_at timestamptz not null default clock_timestamp(),
  closed_at timestamptz,
  constraint donation_bids_won check (status <> 'won' or order_id is not null),
  constraint donation_bids_closed check ((status = 'active') = (closed_at is null))
);

create unique index donation_bids_one_active on public.donation_bids (listing_id, bidder_id)
  where status = 'active';
create index donation_bids_rank on public.donation_bids (listing_id, amount desc, raised_at)
  where status = 'active';
create index listings_bid_ends on public.listings (bid_ends_at) where bid_ends_at is not null;

-- Who bid what stays private: members see only the summary from listing_bids.
alter table public.donation_bids enable row level security;
revoke all on public.donation_bids from anon, authenticated;

-- As in 20261031120000, except a donation takes no token.
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

  if not coalesce(p_is_donation, false) then
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

-- As in 20261105120000, except donations are bid on (place_bid), never ordered here.
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

-- Ajukan / naikkan tawaran. [p_amount] is the new total; raising takes only the
-- difference. Answers when the window closes.
create function public.place_bid(
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

-- Returns [p_amount] tokens to [p_member] for [p_listing].
create function public.refund_bid_tokens(p_member uuid, p_amount integer, p_listing uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.quota_balances (member_id, balance) values (p_member, p_amount)
    on conflict (member_id) do update set balance = public.quota_balances.balance + p_amount;
  insert into public.quota_ledger (member_id, delta, reason, listing_id)
  values (p_member, p_amount, 'bid_refund', p_listing);
$$;

-- pg_cron: settles every window that has closed. [p_now] lets tests move the clock.
-- A listing that was taken down (by its donor or an admin) or whose donor is no longer
-- listed refunds every bid. A bidder who is no longer listed cannot win.
create function public.close_donation_bids(p_now timestamptz default now())
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.listings;
  v_bid public.donation_bids;
  v_left integer;
  v_open boolean;
  v_order uuid;
begin
  for v_listing in
    select * from public.listings where bid_ends_at <= p_now order by bid_ends_at for update
  loop
    v_left := v_listing.stock_left;
    v_open := v_listing.removed_at is null and v_listing.withdrawn_at is null
      and public.is_listed_seller(v_listing.seller_id);
    for v_bid in
      select * from public.donation_bids
      where listing_id = v_listing.id and status = 'active'
      order by amount desc, raised_at, created_at, id
    loop
      if v_open and v_left > 0 and public.is_listed_seller(v_bid.bidder_id) then
        insert into public.orders (listing_id, buyer_id, seller_id, kind, price, is_donation,
          hold_until, cod_campus, cod_place)
        values (v_listing.id, v_bid.bidder_id, v_listing.seller_id, 'buy', 0, true,
          p_now + interval '24 hours', v_bid.cod_campus, v_bid.cod_place)
        returning id into v_order;
        update public.donation_bids set status = 'won', order_id = v_order, closed_at = p_now
          where id = v_bid.id;
        v_left := v_left - 1;
      else
        perform public.refund_bid_tokens(v_bid.bidder_id, v_bid.amount, v_listing.id);
        update public.donation_bids set status = 'lost', closed_at = p_now where id = v_bid.id;
      end if;
    end loop;
    update public.listings set stock_left = v_left, bid_ends_at = null where id = v_listing.id;
  end loop;
end;
$$;

-- A won donation cancelled by its donor or the timers gives the winner's tokens back.
create function public.refund_cancelled_donation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bid public.donation_bids;
begin
  if new.cancelled_by is null or new.cancelled_by = new.seller_id then
    update public.donation_bids set status = 'refunded'
      where order_id = new.id and status = 'won'
      returning * into v_bid;
    if found then
      perform public.refund_bid_tokens(v_bid.bidder_id, v_bid.amount, v_bid.listing_id);
    end if;
  end if;
  return null;
end;
$$;

create trigger orders_refund_donation
  after update of status on public.orders
  for each row when (new.status = 'cancelled' and old.status is distinct from 'cancelled' and new.is_donation)
  execute function public.refund_cancelled_donation();

-- As in 20261107120000, also refusing while the donation has bids (their tokens are held).
create or replace function public.withdraw_listing(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.listings
    where id = p_id and seller_id = auth.uid() and removed_at is null and withdrawn_at is null
    for update;
  if not found then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if exists (select 1 from public.orders
      where listing_id = p_id and status in ('waiting', 'processing')) then
    raise exception 'listing_has_orders' using errcode = 'check_violation';
  end if;
  if exists (select 1 from public.donation_bids where listing_id = p_id and status = 'active') then
    raise exception 'listing_has_bids' using errcode = 'check_violation';
  end if;
  update public.listings set withdrawn_at = now() where id = p_id;
end;
$$;

-- Detail barang donasi: the window, how many bid, the top amounts (no names), and the
-- caller's own bid and rank. For live donations, or the donor's own.
create function public.listing_bids(p_listing uuid)
returns table (
  ends_at timestamptz, bidders integer, top_amounts integer[], my_amount integer,
  my_rank integer, stock_left integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with active as (
    select b.bidder_id, b.amount,
      row_number() over (order by b.amount desc, b.raised_at, b.created_at, b.id)::int as rank
    from public.donation_bids b
    where b.listing_id = p_listing and b.status = 'active'
  )
  select l.bid_ends_at,
    (select count(*)::int from active),
    coalesce((select array_agg(a.amount order by a.rank) from active a where a.rank <= 5), '{}'),
    (select a.amount from active a where a.bidder_id = auth.uid()),
    (select a.rank from active a where a.bidder_id = auth.uid()),
    l.stock_left
  from public.listings l
  where l.id = p_listing and l.is_donation
    and (public.is_live(l) or l.seller_id = auth.uid());
$$;

revoke execute on function public.refund_bid_tokens(uuid, integer, uuid),
  public.close_donation_bids(timestamptz), public.refund_cancelled_donation()
  from public, anon, authenticated;
revoke execute on function public.place_bid(uuid, integer, public.campus, text)
  from public, anon;
grant execute on function public.place_bid(uuid, integer, public.campus, text) to authenticated;
revoke execute on function public.listing_bids(uuid) from public;
grant execute on function public.listing_bids(uuid) to anon, authenticated;

select cron.schedule('donation-bids', '* * * * *', 'select public.close_donation_bids()');
