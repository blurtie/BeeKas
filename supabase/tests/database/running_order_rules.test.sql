begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- S seller; B buyer; C another approved member. L stock 1, M stock 2.
\set s '''87878787-0000-4000-8000-000000000001'''
\set b '''87878787-0000-4000-8000-000000000002'''
\set c '''87878787-0000-4000-8000-000000000003'''
\set l '''87878787-1111-4000-8000-000000000001'''
\set m '''87878787-1111-4000-8000-000000000002'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('87878787-0000-4000-8000-00000000000' || n)::uuid, 't87-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T87 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 3) n;
update public.profiles set phone = '+62812870000' || right(id::text, 2), status = 'pending'
  where id::text like '87878787-%';
update public.profiles set status = 'approved' where id::text like '87878787-%';

insert into public.listings (id, seller_id, title, description, category, condition, price, stock, campus, expires_at)
values
  (:l, :s, 'Kalkulator', 'Bagus', 'other', 'like_new', 50000, 1, 'bandung', now() + interval '30 days'),
  (:m, :s, 'Lampu', 'Terang', 'other', 'like_new', 30000, 2, 'bandung', now() + interval '30 days');

-- Chat after booking the last unit ------------------------------------------------------

select pg_temp.act_as(:b);
select lives_ok(format('select public.place_order(%L, ''booking'', ''bandung'', ''Lobi'')', :l), 'B books the last unit');
reset role;
select is((select stock_left from public.listings where id = :l), 0, 'stock left is 0');
select pg_temp.act_as(:b);
select lives_ok(format('select public.send_message(''Halo'', p_listing => %L)', :l),
  'the buyer with a running order still starts a chat');
select is((select listing_title from public.my_conversations()), 'Kalkulator', 'the item card stays while the order runs');
reset role;

select pg_temp.act_as(:c);
select throws_ok(format('select public.send_message(''Halo'', p_listing => %L)', :l),
  '23514', 'listing_unavailable', 'someone without an order cannot start one');
reset role;

-- withdraw_listing ------------------------------------------------------------------------

select pg_temp.act_as(:s);
select is(public.conversation_for_order((select id from public.orders where listing_id = :l)),
  (select id from public.conversations where buyer_id = :b), 'the seller finds the chat from the order');
select lives_ok(format('select public.send_message(''Bisa'', (select id from public.conversations where buyer_id = %L), %L)', :b, :l),
  'the seller replies with the sold-out listing while the order runs');
select throws_ok(format('select public.withdraw_listing(%L)', :l),
  '23514', 'listing_has_orders', 'refused while Menunggu');
select lives_ok(format('select public.accept_order(id, now() + interval ''1 day'') from public.orders where listing_id = %L', :l), 'S accepts');
select throws_ok(format('select public.withdraw_listing(%L)', :l),
  '23514', 'listing_has_orders', 'refused while Diproses');
reset role;
select pg_temp.act_as(:b);
select lives_ok(format('select public.complete_order(id) from public.orders where listing_id = %L', :l), 'B completes');
reset role;
select pg_temp.act_as(:s);
reset role;
select pg_temp.act_as(:b);
select lives_ok(format('select public.send_message(''Makasih'', (select id from public.conversations where buyer_id = %L), %L)', :b, :l),
  'the buyer follows up after the order completed');
select throws_ok(format('select public.send_message(''x'', p_listing => %L)', :l),
  '23514', 'listing_unavailable', 'a new chat still needs a live listing or a running order');
reset role;
select pg_temp.act_as(:c);
select throws_ok(format('select public.send_message(''Halo'', p_listing => %L)', :l),
  '23514', 'listing_unavailable', 'an outsider still cannot start a chat');
reset role;
select pg_temp.act_as(:s);
select lives_ok(format('select public.withdraw_listing(%L)', :l), 'allowed once completed');
reset role;

select pg_temp.act_as(:b);
select lives_ok(format('select public.place_order(%L, ''booking'', ''bandung'', ''Lobi'')', :m), 'B books M');
select lives_ok(format('select public.cancel_order(id, ''changed_mind'', null) from public.orders where listing_id = %L', :m), 'B cancels');
reset role;

select pg_temp.act_as(:s);
select lives_ok(format('select public.withdraw_listing(%L)', :m), 'allowed once cancelled');
reset role;

select * from finish();
rollback;
