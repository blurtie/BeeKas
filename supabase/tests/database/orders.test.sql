begin;
create extension if not exists pgtap with schema extensions;
select plan(85);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- S seller; B, C buyers; P pending; F approved and frozen; X, Y admins.
\set s '''85858585-0000-4000-8000-000000000001'''
\set b '''85858585-0000-4000-8000-000000000002'''
\set c '''85858585-0000-4000-8000-000000000003'''
\set p '''85858585-0000-4000-8000-000000000004'''
\set f '''85858585-0000-4000-8000-000000000005'''
\set x '''85858585-0000-4000-8000-000000000006'''
\set y '''85858585-0000-4000-8000-000000000007'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('85858585-0000-4000-8000-00000000000' || n)::uuid, 't85-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T85 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 7) n;
update public.profiles set phone = '+62812850000' || right(id::text, 2)
  where id::text like '85858585-%';
update public.profiles set status = 'pending' where id::text like '85858585-%';
update public.profiles set status = 'approved' where id in (:s, :b, :c, :f, :x, :y);
update public.profiles set role = 'admin' where id in (:x, :y);
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());

-- Listings of S: L1 stock 1, L2 stock 2, D1-D3 donations, I withdrawn, E expired.
create function pg_temp.listing(p_n int, p_stock int, p_donation boolean,
  p_active boolean default true, p_expires timestamptz default now() + interval '60 days')
returns void language sql as $$
  insert into public.listings (id, seller_id, title, description, category, condition, price,
    stock, campus, is_donation, withdrawn_at, expires_at)
  values (('85858585-1111-4000-8000-00000000000' || p_n)::uuid,
    '85858585-0000-4000-8000-000000000001', 'T85 ' || p_n, 'desc', 'other', 'like_new',
    case when p_donation then 0 else 50000 end, p_stock, 'bandung', p_donation,
    case when p_active then null else now() end, p_expires);
$$;
select pg_temp.listing(1, 1, false);
select pg_temp.listing(2, 2, false);
select pg_temp.listing(3, 1, true);
select pg_temp.listing(4, 1, true);
select pg_temp.listing(5, 1, true);
select pg_temp.listing(6, 1, false, false);
select pg_temp.listing(7, 1, false, true, now() - interval '1 day');
select pg_temp.listing(8, 1, false);
\set l1 '''85858585-1111-4000-8000-000000000001'''
\set l2 '''85858585-1111-4000-8000-000000000002'''
\set d1 '''85858585-1111-4000-8000-000000000003'''
\set d2 '''85858585-1111-4000-8000-000000000004'''
\set d3 '''85858585-1111-4000-8000-000000000005'''
\set li '''85858585-1111-4000-8000-000000000006'''
\set le '''85858585-1111-4000-8000-000000000007'''

create function pg_temp.place(p_listing uuid, p_kind text default 'booking') returns timestamptz
language sql as $$
  select public.place_order(p_listing, p_kind::public.order_kind, 'bandung', 'Lobi');
$$;
create function pg_temp.stock(p_listing uuid) returns int
language sql as $$ select stock_left from public.listings where id = p_listing $$;

-- Who may order ------------------------------------------------------------------------

set local role anon;
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000001') $$,
  '42501', null, 'guests cannot order');
reset role;
select pg_temp.act_as(:p);
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000001') $$,
  '42501', 'not_allowed', 'pending accounts cannot order');
reset role;
select pg_temp.act_as(:f);
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000001') $$,
  '42501', 'not_allowed', 'frozen accounts cannot order');
reset role;
select pg_temp.act_as(:s);
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000001') $$,
  '23514', 'own_listing', 'sellers cannot order their own listing');
reset role;
select pg_temp.act_as(:b);
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000006') $$,
  '23514', 'listing_unavailable', 'withdrawn listings cannot be ordered');
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000007') $$,
  '23514', 'listing_unavailable', 'expired listings cannot be ordered');
select throws_ok($$ select pg_temp.place('85858585-0000-4000-8000-000000000099') $$,
  '23514', 'listing_unavailable', 'unknown listings cannot be ordered');
select throws_ok($$ select public.place_order('85858585-1111-4000-8000-000000000001', 'booking', 'bandung', repeat('a', 201)) $$,
  '23514', null, 'Lokasi COD text is at most 200 characters');
reset role;

-- place_order ----------------------------------------------------------------------------

select pg_temp.act_as(:b);
select lives_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000002', 'buy') $$,
  'approved buyer places Beli Sekarang');
reset role;
select is((select row(kind, status, price, is_donation, seller_id = :s, cod_campus, cod_place)::text
  from public.orders where buyer_id = :b and listing_id = :l2),
  '(buy,waiting,50000,f,t,bandung,Lobi)', 'waiting, at the listing price, with the Lokasi COD');
select is((select hold_until - created_at from public.orders where buyer_id = :b and listing_id = :l2),
  interval '24 hours', 'held 24 hours (K-15)');
select pg_temp.act_as(:c);
select is(pg_temp.place('85858585-1111-4000-8000-000000000002', 'buy') - now(), interval '24 hours',
  'place_order answers the hold the server set');
select lives_ok(format('select public.cancel_order(id, ''changed_mind'', null) from public.orders where listing_id = %L and buyer_id = auth.uid()', :l2),
  'C cancels it again');
reset role;
select is(pg_temp.stock(:l2), 1, 'stock_left drops by 1');

select pg_temp.act_as(:b);
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000002') $$,
  '23514', 'already_ordered', 'no second running order on the same listing');
reset role;
select throws_ok($$ insert into public.orders (listing_id, buyer_id, seller_id, kind, price,
    is_donation, cod_campus, hold_until)
  values ('85858585-1111-4000-8000-000000000002', '85858585-0000-4000-8000-000000000002',
    '85858585-0000-4000-8000-000000000001', 'booking', 50000, false, 'bandung', now()) $$,
  '23505', null, 'the unique index backs it');

-- The last unit: B takes L1, then C finds it gone. place_order locks the listing row
-- (select ... for update), so a racing C waits for B and then reads stock_left = 0.
select pg_temp.act_as(:b);
select lives_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000001') $$,
  'B books the last unit');
reset role;
select pg_temp.act_as(:c);
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000001') $$,
  '23514', 'sold_out', 'C cannot take the unit B holds');
reset role;
select is(pg_temp.stock(:l1), 0, 'stock_left stays at 0');
select throws_ok($$ update public.listings set stock_left = -1 where id = '85858585-1111-4000-8000-000000000001' $$,
  '23514', null, 'stock_left can never go negative');

-- Reading -----------------------------------------------------------------------------

select pg_temp.act_as(:b);
select is((select count(*)::int from public.orders), 2, 'buyers read their orders');
select is((select count(*)::int from public.my_orders()), 2, 'my_orders lists them');
select is((select row(title, is_buyer, other_name)::text from public.my_orders() where listing_id = :l1),
  '("T85 1",t,"T85 1")', 'with the title and the seller''s name');
select throws_ok($$ insert into public.orders (listing_id, buyer_id, seller_id, kind, price,
    is_donation, cod_campus, hold_until)
  values ('85858585-1111-4000-8000-000000000001', auth.uid(),
    '85858585-0000-4000-8000-000000000001', 'booking', 0, false, 'bandung', now()) $$,
  '42501', null, 'members cannot write orders directly');
reset role;
select pg_temp.act_as(:s);
select is((select count(*)::int from public.orders), 3, 'sellers read orders on their listings');
select is((select bool_and(not is_buyer) from public.my_orders()), true, 'as the seller');
reset role;
select pg_temp.act_as(:c);
select is((select count(*)::int from public.orders where buyer_id <> auth.uid()), 0, 'other members read none');
reset role;
set local role anon;
select throws_ok($$ select count(*) from public.orders $$, '42501', null, 'guests read none');
reset role;

select id as o1 from public.orders where listing_id = :l1 \gset
select id as o2 from public.orders where listing_id = :l2 and buyer_id = :b \gset

-- Extension (booking only, once) ----------------------------------------------------------

select pg_temp.act_as(:b);
select throws_ok(format('select public.request_extension(%L)', :'o2'),
  '23514', 'order_transition', 'Beli Sekarang has no extension');
select lives_ok(format('select public.request_extension(%L)', :'o1'), 'buyer asks for an extension');
select throws_ok(format('select public.request_extension(%L)', :'o1'),
  '23514', 'order_transition', 'asking twice fails');
select throws_ok(format('select public.approve_extension(%L)', :'o1'),
  '42501', 'not_party', 'buyers cannot approve');
reset role;
select pg_temp.act_as(:s);
select lives_ok(format('select public.approve_extension(%L)', :'o1'), 'seller approves');
reset role;
select is((select hold_until - created_at from public.orders where id = :'o1'),
  interval '48 hours', 'the hold grows by 24 hours (K-13)');
select pg_temp.act_as(:s);
select throws_ok(format('select public.approve_extension(%L)', :'o1'),
  '23514', 'order_transition', 'approving twice fails');
reset role;
select pg_temp.act_as(:b);
select throws_ok(format('select public.request_extension(%L)', :'o1'),
  '23514', 'order_transition', 'no second extension');
reset role;

-- accept_order -----------------------------------------------------------------------------

select pg_temp.act_as(:b);
select throws_ok(format('select public.accept_order(%L, now())', :'o1'),
  '42501', 'not_party', 'buyers cannot accept');
reset role;
select pg_temp.act_as(:c);
select throws_ok(format('select public.accept_order(%L, now())', :'o1'),
  '42501', 'not_party', 'strangers cannot accept');
reset role;
select pg_temp.act_as(:s);
select throws_ok(format('select public.accept_order(%L, now() - interval ''1 minute'')', :'o1'),
  '23514', 'cod_time_past', 'the COD time cannot be in the past');
select throws_ok(format('select public.accept_order(%L, null)', :'o1'),
  '23514', 'cod_time_missing', 'Terima needs the COD time (K-17)');
select lives_ok(format('select public.accept_order(%L, now() + interval ''1 day'')', :'o1'), 'seller accepts');
select throws_ok(format('select public.accept_order(%L, now())', :'o1'),
  '23514', 'order_transition', 'accepting twice fails');
select throws_ok(format('select public.approve_extension(%L)', :'o1'),
  '23514', 'order_transition', 'no extension once Diproses');
reset role;
select is((select row(status, cod_at is not null)::text from public.orders where id = :'o1'),
  '(processing,t)', 'Diproses with the COD time');
select throws_ok($$ update public.orders set cod_at = null where listing_id = '85858585-1111-4000-8000-000000000001' $$,
  '23514', null, 'Diproses always has a COD time');

-- update_cod ------------------------------------------------------------------------------

select pg_temp.act_as(:b);
select lives_ok(format('select public.update_cod(%L, ''bandung'', ''Kantin'', now() + interval ''2 days'')', :'o1'),
  'buyer moves the COD while Diproses');
select throws_ok(format('select public.update_cod(%L, ''bandung'', ''Kantin'', now() - interval ''1 minute'')', :'o1'),
  '23514', 'cod_time_past', 'nor moved into the past');
select throws_ok(format('select public.update_cod(%L, ''bandung'', ''Kantin'', null)', :'o1'),
  '23514', 'cod_time_missing', 'the COD time stays set while Diproses');
select throws_ok(format('select public.update_cod(%L, ''bandung'', ''Kantin'', now())', :'o2'),
  '23514', 'order_transition', 'no COD time while Menunggu');
select lives_ok(format('select public.update_cod(%L, ''bandung'', ''Gerbang'', null)', :'o2'),
  'the Lokasi COD changes while Menunggu');
reset role;
select is((select cod_place from public.orders where id = :'o1'), 'Kantin', 'stored');
select pg_temp.act_as(:c);
select throws_ok(format('select public.update_cod(%L, ''bandung'', ''X'', now())', :'o1'),
  '42501', 'not_party', 'strangers cannot change it');
reset role;

-- complete_order ---------------------------------------------------------------------------

select pg_temp.act_as(:s);
select throws_ok(format('select public.complete_order(%L)', :'o1'),
  '42501', 'not_party', 'sellers cannot mark Sudah diterima');
reset role;
select pg_temp.act_as(:b);
select throws_ok(format('select public.complete_order(%L)', :'o2'),
  '23514', 'order_transition', 'a waiting order cannot complete');
select lives_ok(format('select public.complete_order(%L)', :'o1'), 'buyer confirms receipt');
select throws_ok(format('select public.cancel_order(%L, ''changed_mind'', null)', :'o1'),
  '23514', 'order_transition', 'a completed order cannot be cancelled');
reset role;
select is((select status::text from public.orders where id = :'o1'), 'completed', 'Selesai');
select is(pg_temp.stock(:l1), 0, 'a completed order keeps the unit');

-- cancel_order ----------------------------------------------------------------------------

select pg_temp.act_as(:b);
select throws_ok(format('select public.cancel_order(%L, null, null)', :'o2'),
  '23514', 'reason_missing', 'a reason is required');
select throws_ok(format('select public.cancel_order(%L, ''other'', '' '')', :'o2'),
  '23514', 'note_missing', 'Lainnya needs a note (K-18)');
reset role;
select pg_temp.act_as(:c);
select throws_ok(format('select public.cancel_order(%L, ''changed_mind'', null)', :'o2'),
  '42501', 'not_party', 'strangers cannot cancel');
reset role;
select pg_temp.act_as(:s);
select lives_ok(format('select public.cancel_order(%L, ''other'', ''Tidak dibalas'')', :'o2'),
  'seller rejects with a reason');
reset role;
select is((select row(status, cancel_reason, cancel_note, cancelled_by = :s)::text from public.orders where id = :'o2'),
  '(cancelled,other,"Tidak dibalas",t)', 'Dibatalkan with the reason and who');
select is(pg_temp.stock(:l2), 2, 'cancelling returns the unit');
select pg_temp.act_as(:b);
select lives_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000002') $$,
  'a cancelled order frees the buyer to order again');
reset role;

-- Donations: at most 2 running (D-30) -------------------------------------------------------

select pg_temp.act_as(:c);
select lives_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000003') $$, 'first donation');
select lives_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000004', 'buy') $$, 'second donation');
select throws_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000005') $$,
  '23514', 'donation_limit', 'the third running donation is refused');
reset role;
select is((select bool_and(is_donation and price = 0)::text from public.orders where buyer_id = :c and listing_id <> :l2),
  'true', 'donation orders are free');
select pg_temp.act_as(:c);
select lives_ok(format('select public.cancel_order(id, ''changed_mind'', null) from public.orders where listing_id = %L', :d1),
  'buyer cancels a donation');
select lives_ok($$ select pg_temp.place('85858585-1111-4000-8000-000000000005') $$,
  'a cancelled donation no longer counts');
reset role;

-- A hold that has run out (before the timers catch it) ---------------------------------------

select pg_temp.act_as(:b);
select pg_temp.place('85858585-1111-4000-8000-000000000008');
reset role;
select id as o4 from public.orders where listing_id = '85858585-1111-4000-8000-000000000008' and status = 'waiting' \gset
update public.orders set hold_until = now() where id = :'o4';
select pg_temp.act_as(:b);
select throws_ok(format('select public.request_extension(%L)', :'o4'),
  '23514', 'order_transition', 'no extension once the hold ran out');
reset role;
update public.orders set extension_requested = true where id = :'o4';
select pg_temp.act_as(:s);
select throws_ok(format('select public.approve_extension(%L)', :'o4'),
  '23514', 'order_transition', 'no approval once the hold ran out');
select throws_ok(format('select public.accept_order(%L, now() + interval ''1 day'')', :'o4'),
  '23514', 'order_transition', 'no Terima once the hold ran out');
select lives_ok(format('select public.cancel_order(%L, ''changed_mind'', null)', :'o4'), 'seller clears it');
reset role;

-- Listings with orders stay -------------------------------------------------------------------

select throws_ok($$ delete from public.listings where id = '85858585-1111-4000-8000-000000000001' $$,
  '23503', null, 'a listing with orders cannot be deleted');

-- Timers (pg_cron) -------------------------------------------------------------------------

select is((select count(*)::int from cron.job where jobname = 'order-timers'), 1,
  'the timers run on pg_cron');
select pg_temp.act_as(:c);
select throws_ok($$ select public.run_order_timers() $$, '42501', null, 'members cannot run the timers');
reset role;

-- Now: B waits on L2 (booking), C on D2 (buy) and D3. Nothing is due yet.
select public.run_order_timers(now() + interval '23 hours');
select is((select count(*)::int from public.orders where status = 'waiting' and listing_id::text like '85858585-%'), 3,
  'before 24 hours nothing is cancelled');
select public.run_order_timers(now() + interval '24 hours');
select is((select count(*)::int from public.orders where status = 'waiting' and listing_id::text like '85858585-%'), 0,
  'after 24 hours waiting orders are cancelled');
select is((select bool_and(cancelled_by is null and cancel_reason is null and cancelled_at is not null)
  from public.orders where status = 'cancelled' and cancelled_by is null and listing_id::text like '85858585-%'), true,
  'cancelled by the system, without a reason');
select is(pg_temp.stock(:l2) + pg_temp.stock(:d2) + pg_temp.stock(:d3), 4, 'their units return');

-- A Diproses order completes 3 days after its COD time.
select pg_temp.act_as(:b);
select pg_temp.place('85858585-1111-4000-8000-000000000002');
reset role;
select id as o3 from public.orders where listing_id = :l2 and status = 'waiting' \gset
select pg_temp.act_as(:s);
select public.accept_order(:'o3', now() + interval '1 day');
reset role;
select public.run_order_timers(now() + interval '3 days 23 hours');
select is((select status::text from public.orders where id = :'o3'), 'processing',
  'not before 3 days after the COD time');
select public.run_order_timers(now() + interval '4 days');
select is((select row(status, completed_at is not null)::text from public.orders
  where listing_id = :l2 and buyer_id = :b and cancelled_at is null),
  '(completed,t)', 'Selesai 3 days after the COD time');
select is(pg_temp.stock(:l2), 1, 'a completed order keeps its unit');

select * from finish();
rollback;
