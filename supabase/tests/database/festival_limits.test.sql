begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- S donor/seller (Kemanggisan); B buyer (Kemanggisan).
\set s '''51515151-0000-4000-8000-000000000001'''
\set b '''51515151-0000-4000-8000-000000000002'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('51515151-0000-4000-8000-00000000000' || n)::uuid, 't51-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T51 ' || n, 'campus', 'kemanggisan'), 'authenticated', 'authenticated'
from generate_series(1, 2) n;
update public.profiles set phone = '+62812510000' || right(id::text, 2) where id::text like '51515151-%';
update public.profiles set status = 'pending' where id::text like '51515151-%';
update public.profiles set status = 'approved' where id::text like '51515151-%';
update public.quota_balances set balance = 10 where member_id in (:s, :b);

create function pg_temp.list(p_donation boolean) returns uuid
language sql as $$
  select public.create_listing(p_title => 'T51 item', p_description => 'desc',
    p_category => 'other', p_condition => 'like_new',
    p_price => case when p_donation then 0 else 50000 end, p_stock => 1,
    p_campus => 'kemanggisan', p_warranty => null, p_specs => null, p_is_donation => p_donation,
    p_photos => array[auth.uid()::text || '/' || gen_random_uuid()::text || '.jpg']);
$$;

-- D-51 -------------------------------------------------------------------------------------

select pg_temp.act_as(:s);
select set_config('t.d1', pg_temp.list(true)::text, true);
select set_config('t.d2', pg_temp.list(true)::text, true);
select set_config('t.d3', pg_temp.list(true)::text, true);
select throws_ok('select pg_temp.list(true)', '23514', 'donation_listing_limit',
  'a fourth active donation is refused');
select lives_ok('select pg_temp.list(false)', 'sales are not limited');
select lives_ok(format('select public.withdraw_listing(%L)', current_setting('t.d1')),
  'the donor withdraws one donation');
select lives_ok('select pg_temp.list(true)', 'a withdrawn donation frees a slot');
select throws_ok(format('select public.relist_listing(%L)', current_setting('t.d1')), '23514',
  'donation_listing_limit', 'relisting a donation past the limit is refused');
reset role;
update public.listings set expires_at = now() - interval '1 day' where id = current_setting('t.d2')::uuid;
select pg_temp.act_as(:s);
select lives_ok(format('select public.relist_listing(%L)', current_setting('t.d1')),
  'an expired donation frees a slot for a relist');
reset role;

-- D-47 Lokasi COD ----------------------------------------------------------------------------

select pg_temp.act_as(:s);
select set_config('t.l1', pg_temp.list(false)::text, true);
reset role;
select current_setting('t.l1') as l1, current_setting('t.d3') as d3 \gset

select pg_temp.act_as(:b);
select throws_ok(format('select public.place_order(%L, ''buy'', ''online'', null)', :'l1'), '23514',
  'cod_campus_online', 'an order cannot meet at BINUS Online');
select throws_ok(format('select public.place_order(%L, ''buy'', ''bandung'', null)', :'l1'), '23514',
  'cod_out_of_area', 'an order cannot meet outside the buyer''s area');
select lives_ok(format('select public.place_order(%L, ''buy'', ''senayan'', null)', :'l1'),
  'an order meets at a campus in the buyer''s area');
select throws_ok(format('select public.place_bid(%L, 1, ''online'', null)', :'d3'), '23514',
  'cod_campus_online', 'a bid cannot meet at BINUS Online');
select throws_ok(format('select public.place_bid(%L, 1, ''malang'', null)', :'d3'), '23514',
  'cod_out_of_area', 'a bid cannot meet outside the bidder''s area');
select lives_ok(format('select public.place_bid(%L, 1, ''kemanggisan'', null)', :'d3'),
  'a bid meets at a campus in the bidder''s area');
reset role;
select set_config('t.o1', (select id::text from public.orders where listing_id = :'l1'), true);
select pg_temp.act_as(:s);
select throws_ok(format('select public.update_cod(%L, ''semarang'', null, null)', current_setting('t.o1')),
  '23514', 'cod_out_of_area', 'the seller cannot move the COD outside the buyer''s area');
select lives_ok(format('select public.update_cod(%L, ''alam_sutera'', null, null)', current_setting('t.o1')),
  'moving it within the area works');
reset role;

select * from finish();
rollback;
