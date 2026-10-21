begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- create_listing with fixed fields; only the photos vary.
create function pg_temp.list(p_photos text[]) returns uuid
language sql as $$
  select public.create_listing(p_title => 'T81 item', p_description => 'desc',
    p_category => 'other', p_condition => 'like_new', p_price => 50000, p_stock => 1,
    p_campus => 'bandung', p_warranty => null, p_specs => null, p_is_donation => false,
    p_photos => p_photos);
$$;

-- A approved; P pending; R rejected then approved; F approved and frozen;
-- V pending, approved by admin X through the RPC; Y second admin.
\set a '''81818181-0000-4000-8000-000000000001'''
\set p '''81818181-0000-4000-8000-000000000002'''
\set r '''81818181-0000-4000-8000-000000000003'''
\set f '''81818181-0000-4000-8000-000000000004'''
\set v '''81818181-0000-4000-8000-000000000005'''
\set x '''81818181-0000-4000-8000-000000000006'''
\set y '''81818181-0000-4000-8000-000000000007'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('81818181-0000-4000-8000-00000000000' || n)::uuid, 't81-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T81 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 7) n;
update public.profiles set phone = '+62812810000' || right(id::text, 2)
  where id::text like '81818181-%';
update public.profiles set status = 'pending' where id::text like '81818181-%';
update public.profiles set status = 'approved' where id in (:a, :f, :x, :y);
update public.profiles set status = 'rejected' where id = :r;
update public.profiles set status = 'pending' where id = :r;
update public.profiles set status = 'approved' where id = :r;
update public.profiles set role = 'admin' where id in (:x, :y);
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());

-- Starting balance (K-08) ---------------------------------------------------------

select is((select balance from public.quota_balances where member_id = :a), 1,
  'approval grants a starting balance of 1');
select is((select count(*)::int from public.quota_ledger where member_id = :r and reason = 'starting'), 1,
  'rejected, resubmitted, then approved: one starting grant');
select is((select count(*)::int from public.quota_balances where member_id = :p), 0,
  'pending accounts get no balance');

select pg_temp.act_as(:x);
select lives_ok($$ select public.approve_verification('81818181-0000-4000-8000-000000000005') $$,
  'admin approves V');
select throws_ok($$ select public.approve_verification('81818181-0000-4000-8000-000000000005') $$,
  '23514', 'not_pending', 'approving twice fails');
reset role;
select is((select balance from public.quota_balances where member_id = :v), 1,
  'approval through the RPC grants 1, once');
select is((select count(*)::int from public.quota_ledger where member_id = :v), 1,
  'one ledger row for V');

-- Balance is never negative and members cannot write it ----------------------------

select throws_ok($$ update public.quota_balances set balance = -1
  where member_id = '81818181-0000-4000-8000-000000000001' $$,
  '23514', null, 'balance cannot go negative');

select pg_temp.act_as(:a);
select is(array(select member_id from public.quota_balances), array[:a::uuid],
  'member reads only their own balance');
select throws_ok($$ update public.quota_balances set balance = 99 $$, '42501', null,
  'member cannot change their balance');
select throws_ok($$ insert into public.quota_ledger (member_id, delta, reason)
  values ('81818181-0000-4000-8000-000000000001', 3, 'purchase') $$, '42501', null,
  'member cannot write the ledger');

-- create_listing --------------------------------------------------------------------

select throws_ok($$ select pg_temp.list(array[]::text[]) $$, '23514', null,
  'a listing needs at least one photo');
select throws_ok($$ select pg_temp.list(array['81818181-0000-4000-8000-000000000001/../81818181-0000-4000-8000-000000000003/x.jpg']) $$,
  '42501', null, 'photos must be in the seller''s own folder');
select is(pg_temp.list(array['81818181-0000-4000-8000-000000000001/1.jpg',
    '81818181-0000-4000-8000-000000000001/2.jpg']) is not null, true,
  'approved seller with quota lists');
reset role;

select is((select balance from public.quota_balances where member_id = :a), 0, 'listing takes 1 quota');
select is((select count(*)::int from public.quota_ledger
    where member_id = :a and reason = 'listing' and delta = -1 and listing_id is not null), 1,
  'the ledger records the listing');
select ok((select expires_at between now() + interval '60 days' - interval '1 minute'
    and now() + interval '60 days' from public.listings where seller_id = :a),
  'the listing runs for 60 days');
select is(array(select path from public.listing_photos ph join public.listings l on l.id = ph.listing_id
    where l.seller_id = :a order by ph.position),
  array['81818181-0000-4000-8000-000000000001/1.jpg', '81818181-0000-4000-8000-000000000001/2.jpg'],
  'photos are saved in order');

select pg_temp.act_as(:a);
select throws_ok($$ select pg_temp.list(array['81818181-0000-4000-8000-000000000001/3.jpg']) $$,
  '23514', 'no_quota', 'balance 0 cannot list');
reset role;
select is((select count(*)::int from public.listings where seller_id = :a), 1,
  'a failed listing leaves nothing behind');

-- Who may not list -------------------------------------------------------------------

set local role anon;
select throws_ok($$ select pg_temp.list(array['x/1.jpg']) $$, '42501', null, 'guests cannot list');
reset role;

select pg_temp.act_as(:p);
select throws_ok($$ select pg_temp.list(array['81818181-0000-4000-8000-000000000002/1.jpg']) $$,
  '42501', null, 'pending accounts cannot list');
reset role;

select pg_temp.act_as(:f);
select throws_ok($$ select pg_temp.list(array['81818181-0000-4000-8000-000000000004/1.jpg']) $$,
  '42501', null, 'frozen accounts cannot list');
reset role;
select is((select balance from public.quota_balances where member_id = :f), 1,
  'a refused listing keeps the quota');

select * from finish();
rollback;
