begin;
create extension if not exists pgtap with schema extensions;
select plan(41);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- update_listing with every editable field; only the id, price and stock vary.
create function pg_temp.edit(p_id uuid, p_price integer, p_stock integer) returns void
language sql as $$
  select public.update_listing(p_id => p_id, p_description => 'new desc',
    p_condition => 'used_good', p_price => p_price, p_stock => p_stock,
    p_campus => 'senayan', p_warranty => '1 month', p_specs => array['8GB']);
$$;

-- Seller S owns: live, expired, removed (admin), withdrawn, sold out. Seller F is
-- frozen with one live listing. Member M browses. Admins X and Y froze F.
\set s '''83838383-0000-4000-8000-000000000001'''
\set m '''83838383-0000-4000-8000-000000000002'''
\set f '''83838383-0000-4000-8000-000000000003'''
\set x '''83838383-0000-4000-8000-000000000004'''
\set y '''83838383-0000-4000-8000-000000000005'''
\set live '''83838383-0000-4000-8000-0000000000a1'''
\set expired '''83838383-0000-4000-8000-0000000000a2'''
\set removed '''83838383-0000-4000-8000-0000000000a3'''
\set withdrawn '''83838383-0000-4000-8000-0000000000a4'''
\set soldout '''83838383-0000-4000-8000-0000000000a5'''
\set frozen '''83838383-0000-4000-8000-0000000000a6'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('83838383-0000-4000-8000-00000000000' || n)::uuid, 't83-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T83 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 5) n;
update public.profiles set phone = '+62812830000' || right(id::text, 2)
  where id::text like '83838383-%';
update public.profiles set status = 'pending' where id::text like '83838383-%';
update public.profiles set status = 'approved' where id::text like '83838383-%';
update public.profiles set role = 'admin' where id in (:x, :y);

insert into public.listings (id, seller_id, title, description, category, condition, price, stock, campus)
select ('83838383-0000-4000-8000-0000000000a' || n)::uuid,
  case when n = 6 then :f::uuid else :s::uuid end,
  'T83 ' || n, 'desc', 'other', 'like_new', 50000, 2, 'bandung'
from generate_series(1, 6) n;
insert into public.listing_photos (listing_id, position, path)
select id, 1, 't83/' || id || '.jpg' from public.listings where title like 'T83 %';

update public.listings set expires_at = now() - interval '1 second' where id = :expired;
update public.listings set removed_at = now(), removed_by = :x, removal_reason = 'penipuan'
  where id = :removed;
update public.listings set withdrawn_at = now() where id = :withdrawn;
update public.listings set stock_left = 0 where id = :soldout;
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());

-- New listings run 60 days -----------------------------------------------------

select ok((select bool_and(expires_at between now() + interval '60 days' - interval '1 minute'
    and now() + interval '60 days') from public.listings where id = :live),
  'a listing runs 60 days by default');
select throws_ok($$ update public.listings set removed_at = now()
  where id = '83838383-0000-4000-8000-0000000000a1' $$,
  '23514', null, 'admin removal needs the admin and a reason');

-- Catalog hides what is not live ------------------------------------------------

set local role anon;
select is(array(select title from public.catalog_listings('T83')), array['T83 1'],
  'catalog shows only the live listing');
select is(array(select title from public.listings where title like 'T83 %'), array['T83 1'],
  'guests read only the live listing');
select is((select count(*)::int from public.listing_photos where path like 't83/%'), 1,
  'guests read only the live listing''s photo');
reset role;

select pg_temp.act_as(:m);
select is(array(select title from public.listings where title like 'T83 %'), array['T83 1'],
  'other members read only the live listing');
reset role;

-- Owners read all their own listings ------------------------------------------

select pg_temp.act_as(:s);
select is((select count(*)::int from public.listings where seller_id = :s), 5,
  'the owner reads every own listing, live or not');
select is((select count(*)::int from public.listing_photos where path like 't83/%'), 5,
  'the owner reads the photos of every own listing');
select is((select count(*)::int from public.listings where seller_id = :f), 0,
  'the owner does not read other sellers'' hidden listings');
reset role;

select pg_temp.act_as(:f);
select is((select count(*)::int from public.listings where seller_id = :f), 1,
  'a frozen seller still reads their own hidden listing');
select is((select count(*)::int from public.listing_photos where listing_id = :frozen), 1,
  'and its photo');
reset role;

-- update_listing ----------------------------------------------------------------

select pg_temp.act_as(:m);
select throws_ok($$ select pg_temp.edit('83838383-0000-4000-8000-0000000000a1', 40000, 2) $$,
  '42501', 'not_allowed', 'a non-owner cannot edit');
reset role;
set local role anon;
select throws_ok($$ select pg_temp.edit('83838383-0000-4000-8000-0000000000a1', 40000, 2) $$,
  '42501', null, 'a guest cannot edit');
reset role;

select pg_temp.act_as(:s);
select lives_ok($$ select pg_temp.edit('83838383-0000-4000-8000-0000000000a1', 40000, 3) $$,
  'the owner edits');
select throws_ok($$ select public.update_listing(p_id => '83838383-0000-4000-8000-0000000000a1',
    p_description => repeat('x', 501), p_condition => 'used_good', p_price => 40000,
    p_stock => 3, p_campus => 'senayan', p_warranty => null, p_specs => null) $$,
  '23514', null, 'a changed description over 500 characters is refused (K-04)');
reset role;
select is((select (description, condition::text, price, previous_price, stock, stock_left,
    campus::text, warranty, specs)::text from public.listings where id = :live),
  '("new desc",used_good,40000,50000,3,3,senayan,"1 month",{8GB})',
  'the edit lands; the price drop is struck through; added stock is left');

select pg_temp.act_as(:s);
select lives_ok($$ select public.update_listing(p_id => '83838383-0000-4000-8000-0000000000a1',
    p_description => 'new desc', p_condition => 'used_good', p_price => 40000,
    p_stock => 3, p_campus => 'senayan', p_warranty => '1 month', p_specs => array['8GB']) $$,
  'saving with the description unchanged passes');
select throws_ok($$ select public.update_listing(p_id => '83838383-0000-4000-8000-0000000000a1',
    p_title => 'Other item', p_description => 'd', p_condition => 'used_good', p_price => 1000,
    p_stock => 1, p_campus => 'bandung', p_warranty => null, p_specs => null) $$,
  '42883', null, 'the name cannot be changed (K-06)');
select throws_ok($$ select public.update_listing(p_id => '83838383-0000-4000-8000-0000000000a1',
    p_category => 'books_stationery', p_description => 'd', p_condition => 'used_good', p_price => 1000,
    p_stock => 1, p_campus => 'bandung', p_warranty => null, p_specs => null) $$,
  '42883', null, 'the category cannot be changed (K-06)');
select throws_ok($$ select public.update_listing(p_id => '83838383-0000-4000-8000-0000000000a1',
    p_is_donation => true, p_description => 'd', p_condition => 'used_good', p_price => 0,
    p_stock => 1, p_campus => 'bandung', p_warranty => null, p_specs => null) $$,
  '42883', null, 'sale or donation cannot be changed (K-06)');
select throws_ok($$ select public.update_listing(p_id => '83838383-0000-4000-8000-0000000000a1',
    p_photos => array['x.jpg'], p_description => 'd', p_condition => 'used_good', p_price => 1000,
    p_stock => 1, p_campus => 'bandung', p_warranty => null, p_specs => null) $$,
  '42883', null, 'photos cannot be changed (D-28)');
select throws_ok($$ update public.listings set title = 'x' where id = '83838383-0000-4000-8000-0000000000a1' $$,
  '42501', null, 'the owner cannot update the table directly');
select throws_ok($$ select pg_temp.edit('83838383-0000-4000-8000-0000000000a5', 50000, 1) $$,
  '23514', null, 'stock cannot drop below the units already taken');
select throws_ok($$ select pg_temp.edit('83838383-0000-4000-8000-0000000000a3', 50000, 2) $$,
  '42501', 'not_allowed', 'a listing removed by an admin cannot be edited');
select throws_ok($$ select pg_temp.edit('83838383-0000-4000-8000-0000000000a4', 50000, 2) $$,
  '42501', 'not_allowed', 'a withdrawn listing cannot be edited');
reset role;

select pg_temp.act_as(:f);
select throws_ok($$ select pg_temp.edit('83838383-0000-4000-8000-0000000000a6', 40000, 2) $$,
  '42501', 'not_allowed', 'a frozen seller cannot edit (K-26)');
reset role;

-- withdraw_listing ----------------------------------------------------------------

select pg_temp.act_as(:m);
select throws_ok($$ select public.withdraw_listing('83838383-0000-4000-8000-0000000000a1') $$,
  '42501', 'not_allowed', 'a non-owner cannot withdraw');
reset role;

select pg_temp.act_as(:s);
select lives_ok($$ select public.withdraw_listing('83838383-0000-4000-8000-0000000000a5') $$,
  'the owner withdraws');
select throws_ok($$ select public.withdraw_listing('83838383-0000-4000-8000-0000000000a5') $$,
  '42501', 'not_allowed', 'a withdrawn listing cannot be withdrawn again');
select is((select balance from public.quota_balances where member_id = :s), 1,
  'withdrawing gives no quota back (D-29)');
reset role;

-- relist_listing ------------------------------------------------------------------

select pg_temp.act_as(:m);
select throws_ok($$ select public.relist_listing('83838383-0000-4000-8000-0000000000a2') $$,
  '42501', 'not_allowed', 'a non-owner cannot relist');
reset role;

select pg_temp.act_as(:s);
select throws_ok($$ select public.relist_listing('83838383-0000-4000-8000-0000000000a1') $$,
  '42501', 'not_allowed', 'a live listing cannot be relisted');
select throws_ok($$ select public.relist_listing('83838383-0000-4000-8000-0000000000a3') $$,
  '42501', 'not_allowed', 'a listing removed by an admin cannot be relisted');
select lives_ok($$ select public.relist_listing('83838383-0000-4000-8000-0000000000a4') $$,
  'the owner relists a withdrawn listing (D-45)');
reset role;
select ok((select withdrawn_at is null and expires_at between now() + interval '60 days'
    - interval '1 minute' and now() + interval '60 days' from public.listings where id = :withdrawn),
  'a relisted withdrawn listing is back for 60 days');
set local role anon;
select is((select count(*)::int from public.catalog_listings('T83 4')), 1,
  'with stock left it shows in the catalog again');
reset role;
select pg_temp.act_as(:m);
select throws_ok($$ select public.relist_listing('83838383-0000-4000-8000-0000000000a5') $$,
  '42501', 'not_allowed', 'a non-owner cannot relist a withdrawn listing');
reset role;
select pg_temp.act_as(:f);
select throws_ok($$ select public.relist_listing('83838383-0000-4000-8000-0000000000a6') $$,
  '42501', 'not_allowed', 'a frozen seller cannot relist');
reset role;
select pg_temp.act_as(:s);
select lives_ok($$ select public.relist_listing('83838383-0000-4000-8000-0000000000a2') $$,
  'the owner relists an expired listing');
reset role;
select ok((select expires_at between now() + interval '60 days' - interval '1 minute'
    and now() + interval '60 days' from public.listings where id = :expired),
  'relisting runs another 60 days (K-07)');
select is((select balance from public.quota_balances where member_id = :s), 1,
  'relisting takes no quota (K-07)');

select * from finish();
rollback;
