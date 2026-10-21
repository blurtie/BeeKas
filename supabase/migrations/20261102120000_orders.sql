-- Orders (#85, D-28, D-30, D-36, PRD-katalog 5.4-5.7 and 7.3): Booking 24 Jam and Beli
-- Sekarang, paid by COD on campus. Members read the orders they are party to; every
-- write goes through the functions below, which keep listings.stock_left in step in the
-- same transaction.

create type public.order_kind as enum ('booking', 'buy');
-- D-30: Menunggu konfirmasi penjual -> Diproses -> Selesai / Dibatalkan.
create type public.order_status as enum ('waiting', 'processing', 'completed', 'cancelled');
-- K-18.
create type public.cancel_reason as enum (
  'changed_mind', 'not_as_described', 'cannot_meet', 'sold_elsewhere', 'other'
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  -- Restrict: an order keeps its listing (title, photo) for both parties.
  listing_id uuid not null references public.listings on delete restrict,
  buyer_id uuid not null references public.profiles on delete cascade,
  seller_id uuid not null references public.profiles on delete cascade,
  kind public.order_kind not null,
  -- The listing price when ordered (D-30); 0 for donations.
  price integer not null check (price >= 0),
  is_donation boolean not null,
  status public.order_status not null default 'waiting',
  -- Waiting orders are cancelled at this time (K-12, K-15).
  hold_until timestamptz,
  extension_requested boolean not null default false,
  extended boolean not null default false,
  -- Lokasi COD: campus plus free text (D-30), set by the buyer.
  cod_campus public.campus not null,
  cod_place text check (btrim(cod_place) <> '' and char_length(cod_place) <= 200),
  -- Set by the seller on Terima (K-17).
  cod_at timestamptz,
  -- Null reason and canceller: cancelled by the timers.
  cancel_reason public.cancel_reason,
  cancel_note text check (btrim(cancel_note) <> '' and char_length(cancel_note) <= 500),
  cancelled_by uuid references public.profiles on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  constraint orders_not_own check (buyer_id <> seller_id),
  constraint orders_hold check (status <> 'waiting' or hold_until is not null),
  constraint orders_cod_at check (status not in ('processing', 'completed') or cod_at is not null),
  constraint orders_extension check (kind = 'booking' or not (extension_requested or extended)),
  constraint orders_cancelled check ((status = 'cancelled') = (cancelled_at is not null)),
  constraint orders_completed check ((status = 'completed') = (completed_at is not null)),
  constraint orders_note check (cancel_reason is distinct from 'other' or cancel_note is not null)
);

-- One running order per buyer and listing (5.4).
create unique index orders_one_running on public.orders (buyer_id, listing_id)
  where status in ('waiting', 'processing');
create index orders_buyer on public.orders (buyer_id, created_at desc);
create index orders_seller on public.orders (seller_id, created_at desc);
create index orders_waiting on public.orders (hold_until) where status = 'waiting';
create index orders_processing on public.orders (cod_at) where status = 'processing';

alter table public.orders enable row level security;
revoke all on public.orders from anon, authenticated;
grant select on public.orders to authenticated;

create policy "orders: parties read their own"
  on public.orders for select to authenticated
  using ((select auth.uid()) in (buyer_id, seller_id));

-- Booking 24 Jam or Beli Sekarang: one unit, held 24 hours for the seller (K-15).
-- Answers the hold's end, which K10 counts down to.
create function public.place_order(
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
  v_until timestamptz;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  -- Locks the listing: a second buyer of the last unit waits here, then reads 0 left.
  select * into v_listing from public.listings where id = p_listing for update;
  if not found or not v_listing.is_active or not public.is_listed_seller(v_listing.seller_id)
      or v_listing.expires_at <= now() then
    raise exception 'listing_unavailable' using errcode = 'check_violation';
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
  if v_listing.is_donation then
    -- Two donation orders of one buyer on different listings would both pass the count.
    perform pg_advisory_xact_lock(hashtextextended('donations:' || auth.uid()::text, 0));
    if (select count(*) from public.orders where buyer_id = auth.uid() and is_donation
        and status in ('waiting', 'processing')) >= 2 then
      raise exception 'donation_limit' using errcode = 'check_violation';
    end if;
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

-- The order, locked, when the caller is an approved, unfrozen party to it in [p_role]
-- ('buyer', 'seller' or null for either).
create function public.order_for_party(p_id uuid, p_role text)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  select * into v_order from public.orders where id = p_id for update;
  if not found
      or (p_role = 'buyer' and v_order.buyer_id <> auth.uid())
      or (p_role = 'seller' and v_order.seller_id <> auth.uid())
      or (p_role is null and auth.uid() not in (v_order.buyer_id, v_order.seller_id)) then
    raise exception 'not_party' using errcode = 'insufficient_privilege';
  end if;
  return v_order;
end;
$$;

create function public.order_transition() returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'order_transition' using errcode = 'check_violation';
end;
$$;

-- A waiting order whose hold has run out is the timers' to cancel, even before they run.
create function public.order_hold_over(p_order public.orders) returns boolean
language sql
stable
set search_path = ''
as $$
  select p_order.status = 'waiting' and p_order.hold_until <= now();
$$;

-- K-17: a COD time is agreed for the future.
create function public.check_cod_time(p_cod_at timestamptz) returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_cod_at is null then
    raise exception 'cod_time_missing' using errcode = 'check_violation';
  end if;
  if p_cod_at < now() then
    raise exception 'cod_time_past' using errcode = 'check_violation';
  end if;
end;
$$;

-- Terima: the seller sets the COD time agreed in chat (K-17).
create function public.accept_order(p_id uuid, p_cod_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders := public.order_for_party(p_id, 'seller');
begin
  if v_order.status <> 'waiting' or public.order_hold_over(v_order) then
    perform public.order_transition();
  end if;
  perform public.check_cod_time(p_cod_at);
  update public.orders set status = 'processing', cod_at = p_cod_at, accepted_at = now()
    where id = p_id;
end;
$$;

-- Batalkan / Tolak, by either party while running (D-30: a reason, no penalty).
create function public.cancel_order(p_id uuid, p_reason public.cancel_reason, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders := public.order_for_party(p_id, null);
begin
  if v_order.status not in ('waiting', 'processing') then
    perform public.order_transition();
  end if;
  if p_reason is null then
    raise exception 'reason_missing' using errcode = 'check_violation';
  end if;
  if p_reason = 'other' and coalesce(btrim(p_note), '') = '' then
    raise exception 'note_missing' using errcode = 'check_violation';
  end if;
  update public.orders set status = 'cancelled', cancel_reason = p_reason,
      cancel_note = nullif(btrim(p_note), ''), cancelled_by = auth.uid(), cancelled_at = now()
    where id = p_id;
  update public.listings set stock_left = stock_left + 1 where id = v_order.listing_id;
end;
$$;

-- Sudah diterima.
create function public.complete_order(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders := public.order_for_party(p_id, 'buyer');
begin
  if v_order.status <> 'processing' then
    perform public.order_transition();
  end if;
  update public.orders set status = 'completed', completed_at = now() where id = p_id;
end;
$$;

-- Minta perpanjangan: bookings only, once (D-30).
create function public.request_extension(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders := public.order_for_party(p_id, 'buyer');
begin
  if v_order.status <> 'waiting' or v_order.kind <> 'booking'
      or v_order.extension_requested or v_order.extended or public.order_hold_over(v_order) then
    perform public.order_transition();
  end if;
  update public.orders set extension_requested = true where id = p_id;
end;
$$;

-- Setujui perpanjangan: +24 hours (K-13).
create function public.approve_extension(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders := public.order_for_party(p_id, 'seller');
begin
  if v_order.status <> 'waiting' or not v_order.extension_requested or v_order.extended
      or public.order_hold_over(v_order) then
    perform public.order_transition();
  end if;
  update public.orders set extended = true, hold_until = hold_until + interval '24 hours'
    where id = p_id;
end;
$$;

-- Lokasi COD until Selesai; the COD time only while Diproses (K-17). Either party.
create function public.update_cod(
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
  -- An unchanged time may already be past (moving only the place after the COD).
  if v_order.status = 'processing' and p_cod_at is distinct from v_order.cod_at then
    perform public.check_cod_time(p_cod_at);
  end if;
  update public.orders set cod_campus = p_cod_campus,
      cod_place = nullif(btrim(p_cod_place), ''), cod_at = p_cod_at
    where id = p_id;
end;
$$;

-- Pesanan Saya (K12): the caller's orders, newest first, with what the list shows. The
-- listing may no longer be visible in the catalog, so its title and photo come from here.
create function public.my_orders()
returns table (
  id uuid, listing_id uuid, kind public.order_kind, status public.order_status,
  price integer, is_donation boolean, hold_until timestamptz,
  extension_requested boolean, extended boolean, cod_campus public.campus, cod_place text,
  cod_at timestamptz, cancel_reason public.cancel_reason, cancel_note text,
  created_at timestamptz, title text, photo text, is_buyer boolean, other_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id, o.listing_id, o.kind, o.status, o.price, o.is_donation, o.hold_until,
    o.extension_requested, o.extended, o.cod_campus, o.cod_place, o.cod_at,
    o.cancel_reason, o.cancel_note, o.created_at, l.title,
    (select ph.path from public.listing_photos ph where ph.listing_id = l.id
      order by ph.position limit 1),
    o.buyer_id = auth.uid(), p.full_name
  from public.orders o
  join public.listings l on l.id = o.listing_id
  join public.profiles p on p.id = case when o.buyer_id = auth.uid() then o.seller_id else o.buyer_id end
  where auth.uid() in (o.buyer_id, o.seller_id)
  order by o.created_at desc, o.id;
$$;

-- pg_cron: waiting orders past their hold are cancelled and their units return; Diproses
-- orders complete 3 days after the COD time (D-30). [p_now] lets tests move the clock.
create function public.run_order_timers(p_now timestamptz default now())
returns void
language sql
security definer
set search_path = ''
as $$
  with cancelled as (
    update public.orders set status = 'cancelled', cancelled_at = p_now
    where status = 'waiting' and hold_until <= p_now
    returning listing_id
  )
  update public.listings l set stock_left = l.stock_left + c.n
  from (select listing_id, count(*)::int n from cancelled group by listing_id) c
  where l.id = c.listing_id;

  update public.orders set status = 'completed', completed_at = p_now
  where status = 'processing' and cod_at + interval '3 days' <= p_now;
$$;

revoke execute on function public.order_for_party(uuid, text), public.order_transition(),
  public.order_hold_over(public.orders), public.check_cod_time(timestamptz),
  public.run_order_timers(timestamptz)
  from public, anon, authenticated;
revoke execute on function
  public.place_order(uuid, public.order_kind, public.campus, text),
  public.accept_order(uuid, timestamptz),
  public.cancel_order(uuid, public.cancel_reason, text),
  public.complete_order(uuid),
  public.request_extension(uuid),
  public.approve_extension(uuid),
  public.update_cod(uuid, public.campus, text, timestamptz),
  public.my_orders()
  from public, anon;
grant execute on function
  public.place_order(uuid, public.order_kind, public.campus, text),
  public.accept_order(uuid, timestamptz),
  public.cancel_order(uuid, public.cancel_reason, text),
  public.complete_order(uuid),
  public.request_extension(uuid),
  public.approve_extension(uuid),
  public.update_cod(uuid, public.campus, text, timestamptz),
  public.my_orders()
  to authenticated;

select cron.schedule('order-timers', '*/10 * * * *', 'select public.run_order_timers()');
