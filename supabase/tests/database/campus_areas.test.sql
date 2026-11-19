begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- S seller (Alam Sutera); K Kemanggisan; B Bandung; O BINUS Online.
\set s '''47474747-0000-4000-8000-000000000001'''
\set k '''47474747-0000-4000-8000-000000000002'''
\set b '''47474747-0000-4000-8000-000000000003'''
\set o '''47474747-0000-4000-8000-000000000004'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('47474747-0000-4000-8000-00000000000' || n)::uuid, 't47-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T47 ' || n, 'campus',
    (array['alam_sutera', 'kemanggisan', 'bandung', 'online'])[n]),
  'authenticated', 'authenticated'
from generate_series(1, 4) n;
update public.profiles set phone = '+62812470000' || right(id::text, 2)
  where id::text like '47474747-%';
update public.profiles set status = 'pending' where id::text like '47474747-%';
update public.profiles set status = 'approved' where id::text like '47474747-%';
update public.quota_balances set balance = 10 where member_id::text like '47474747-%';

-- Areas ------------------------------------------------------------------------------------

select is(public.campus_area('alam_sutera'), 'jabodetabek', 'Alam Sutera is Jabodetabek');
select is(public.campus_area('bekasi'), 'jabodetabek', 'Bekasi is Jabodetabek');
select is(public.campus_area('bandung'), 'bandung', 'Bandung is its own area');
select is(public.campus_area('online'), null, 'BINUS Online has no area');

-- Listings: AS sale and AD donation at Alam Sutera, BS sale at Bandung.
create function pg_temp.listing(p_n int, p_campus text, p_donation boolean) returns void
language sql as $$
  insert into public.listings (id, seller_id, title, description, category, condition, price,
    stock, campus, is_donation, expires_at)
  values (('47474747-1111-4000-8000-00000000000' || p_n)::uuid,
    '47474747-0000-4000-8000-000000000001', 'T47 ' || p_n, 'desc', 'other', 'like_new',
    case when p_donation then 0 else 50000 end, 3, p_campus::public.campus, p_donation,
    now() + interval '60 days');
$$;
select pg_temp.listing(1, 'alam_sutera', false);
select pg_temp.listing(2, 'alam_sutera', true);
select pg_temp.listing(3, 'bandung', false);
\set las '''47474747-1111-4000-8000-000000000001'''
\set lad '''47474747-1111-4000-8000-000000000002'''
\set lbs '''47474747-1111-4000-8000-000000000003'''

select throws_ok($$ select pg_temp.listing(4, 'online', false) $$, '23514', null,
  'a listing cannot be located at BINUS Online');
select throws_ok(format('update public.listings set campus = ''online'' where id = %L', :las), '23514', null,
  'nor moved there by an edit');

-- Ordering ------------------------------------------------------------------------------------

create function pg_temp.place(p_listing uuid) returns timestamptz
language sql as $$ select public.place_order(p_listing, 'booking',
  (select campus from public.listings where id = p_listing), null) $$;
create function pg_temp.bid(p_listing uuid) returns timestamptz
language sql as $$ select public.place_bid(p_listing, 1,
  (select campus from public.listings where id = p_listing), null) $$;

select pg_temp.act_as(:b);
select throws_ok(format('select pg_temp.place(%L)', :las), '23514', 'out_of_area',
  'Bandung cannot order at Alam Sutera');
select throws_ok(format('select pg_temp.bid(%L)', :lad), '23514', 'out_of_area',
  'Bandung cannot bid at Alam Sutera');
select lives_ok(format('select pg_temp.place(%L)', :lbs), 'Bandung orders in Bandung');
select is((select count(*)::int from public.catalog_listings() where id::text like '47474747-%'), 3,
  'listings out of the area stay visible');
reset role;

select pg_temp.act_as(:k);
select lives_ok(format('select pg_temp.place(%L)', :las), 'Kemanggisan orders at Alam Sutera');
select lives_ok(format('select pg_temp.bid(%L)', :lad), 'Kemanggisan bids at Alam Sutera');
select throws_ok(format('select pg_temp.place(%L)', :lbs), '23514', 'out_of_area',
  'Kemanggisan cannot order in Bandung');
reset role;

select pg_temp.act_as(:o);
select lives_ok(format('select pg_temp.place(%L)', :las), 'BINUS Online orders in Jabodetabek');
select lives_ok(format('select pg_temp.place(%L)', :lbs), 'BINUS Online orders in Bandung');
select lives_ok(format('select pg_temp.bid(%L)', :lad), 'BINUS Online bids in Jabodetabek');
reset role;

-- Location filter -------------------------------------------------------------------------

select is((select array_agg(id::text order by id) from public.catalog_listings(p_campuses => array['alam_sutera']::public.campus[])
    where id::text like '47474747-%'),
  array['47474747-1111-4000-8000-000000000001', '47474747-1111-4000-8000-000000000002'],
  'the filter keeps one campus');
select is((select count(*)::int from public.catalog_listings(p_campuses => array['bandung', 'semarang']::public.campus[])
    where id::text like '47474747-%'), 1, 'or several');
select is((select count(*)::int from public.catalog_listings(p_campuses => null) where id::text like '47474747-%'), 3,
  'null means every location');

select * from finish();
rollback;
