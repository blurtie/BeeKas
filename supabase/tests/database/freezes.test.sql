begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- Sellers: A approved, P pending, R rejected, F frozen, Q only proposed for freezing.
-- Admins X and Y; member M browses. Each seller has one active listing with a photo.
\set a '''76767676-0000-4000-8000-000000000001'''
\set p '''76767676-0000-4000-8000-000000000002'''
\set r '''76767676-0000-4000-8000-000000000003'''
\set f '''76767676-0000-4000-8000-000000000004'''
\set q '''76767676-0000-4000-8000-000000000005'''
\set x '''76767676-0000-4000-8000-000000000006'''
\set y '''76767676-0000-4000-8000-000000000007'''
\set m '''76767676-0000-4000-8000-000000000008'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('76767676-0000-4000-8000-00000000000' || n)::uuid, 't76-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T76 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 8) n;
update public.profiles set phone = '+62812760000' || right(id::text, 2)
  where id::text like '76767676-%';
update public.profiles set status = 'pending' where id::text like '76767676-%';
update public.profiles set status = 'approved' where id in (:a, :f, :q, :x, :y, :m);
update public.profiles set status = 'rejected' where id = :r;
update public.profiles set role = 'admin' where id in (:x, :y);

insert into public.listings (id, seller_id, title, description, category, condition, price, campus)
select ('76767676-0000-4000-8000-0000000000a' || n)::uuid, ('76767676-0000-4000-8000-00000000000' || n)::uuid,
  'T76 ' || n, 'desc', 'other', 'like_new', 50000, 'bandung'
from generate_series(1, 5) n;
insert into public.listing_photos (listing_id, position, path)
select id, 1, 't76/' || id || '.jpg' from public.listings where title like 'T76 %';

insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());
insert into public.freezes (member_id, reason, proposed_by) values (:q, 'spam', :x);

-- Rules ------------------------------------------------------------------------

select throws_ok($$ insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
  values ('76767676-0000-4000-8000-000000000001', 'x', '76767676-0000-4000-8000-000000000006',
    '76767676-0000-4000-8000-000000000006', now()) $$,
  '23514', null, 'the proposer cannot approve their own proposal');
select throws_ok($$ insert into public.freezes (member_id, reason, proposed_by)
  values ('76767676-0000-4000-8000-000000000006', 'x', '76767676-0000-4000-8000-000000000006') $$,
  '23514', null, 'an admin cannot propose freezing themselves');
select throws_ok($$ insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
  values ('76767676-0000-4000-8000-000000000007', 'x', '76767676-0000-4000-8000-000000000006',
    '76767676-0000-4000-8000-000000000007', now()) $$,
  '23514', null, 'an admin cannot approve freezing themselves');

select throws_ok($$ insert into public.freezes (member_id, reason, proposed_by)
  values ('76767676-0000-4000-8000-000000000004', 'x', '76767676-0000-4000-8000-000000000007') $$,
  '23505', null, 'one open freeze per member');

select ok(public.is_frozen(:f), 'an approved freeze freezes');
select ok(not public.is_frozen(:q), 'a bare proposal does not freeze');
select ok(not public.is_frozen(:a), 'no freeze, not frozen');

-- Guests and members see only A's listing ---------------------------------------

set local role anon;
select is(array(select seller_id from public.listings where title like 'T76 %' order by seller_id), array[:a::uuid, :q::uuid],
  'guest reads listings of approved, unfrozen sellers only; a proposal hides nothing');
select is((select count(*)::int from public.listing_photos where path like 't76/%'), 2,
  'guest reads photos of those listings only');
select is(array(select title from public.catalog_listings() where title like 'T76 %' order by title), array['T76 1', 'T76 5'],
  'catalog shows guests approved, unfrozen sellers only');
select throws_ok($$ select * from public.freezes $$, '42501', null, 'guest cannot read freezes');
select throws_ok($$ select public.is_frozen('76767676-0000-4000-8000-000000000004') $$, '42501', null,
  'guest cannot ask is_frozen');
reset role;

select pg_temp.act_as(:m);
select is(array(select seller_id from public.listings where title like 'T76 %' order by seller_id), array[:a::uuid, :q::uuid],
  'member reads listings of approved, unfrozen sellers only');
select is((select count(*)::int from public.listing_photos where path like 't76/%'), 2,
  'member reads photos of those listings only');
select is(array(select title from public.catalog_listings() where title like 'T76 %' order by title), array['T76 1', 'T76 5'],
  'catalog shows members approved, unfrozen sellers only');
select throws_ok($$ select * from public.freezes $$, '42501', null, 'member cannot read freezes');
select throws_ok($$ select public.is_frozen('76767676-0000-4000-8000-000000000004') $$, '42501', null,
  'member cannot ask is_frozen');
select throws_ok($$ insert into public.freezes (member_id, reason, proposed_by)
  values ('76767676-0000-4000-8000-000000000001', 'x', '76767676-0000-4000-8000-000000000008') $$,
  '42501', null, 'member cannot propose a freeze');
reset role;

-- The frozen seller cannot see their own listing in the catalog either.
select pg_temp.act_as(:f);
select is((select count(*)::int from public.catalog_listings() where title = 'T76 4'), 0,
  'frozen seller''s listing is hidden from themselves too');
reset role;

-- Approving the proposal hides Q; lifting F's freeze shows F again.
update public.freezes set approved_by = :y, approved_at = now() where member_id = :q;
update public.freezes set lifted_at = now() where member_id = :f;
set local role anon;
select is(array(select title from public.catalog_listings() where title like 'T76 %' order by title),
  array['T76 1', 'T76 4'], 'approval hides Q; lifting shows F again');
select is((select count(*)::int from public.listings where title like 'T76 %'), 2,
  'listings table agrees after approval and lifting');
select is((select count(*)::int from public.listing_photos where path like 't76/%'), 2,
  'listing photos agree after approval and lifting');
reset role;

select * from finish();
rollback;
