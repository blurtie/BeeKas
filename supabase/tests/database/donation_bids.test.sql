begin;
create extension if not exists pgtap with schema extensions;
select plan(49);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- S donor; A, B, C bidders; P pending; F approved and frozen; X, Y admins.
\set s '''46464646-0000-4000-8000-000000000001'''
\set a '''46464646-0000-4000-8000-000000000002'''
\set b '''46464646-0000-4000-8000-000000000003'''
\set c '''46464646-0000-4000-8000-000000000004'''
\set p '''46464646-0000-4000-8000-000000000005'''
\set f '''46464646-0000-4000-8000-000000000006'''
\set x '''46464646-0000-4000-8000-000000000007'''
\set y '''46464646-0000-4000-8000-000000000008'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('46464646-0000-4000-8000-00000000000' || n)::uuid, 't46-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T46 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 8) n;
update public.profiles set phone = '+62812460000' || right(id::text, 2)
  where id::text like '46464646-%';
update public.profiles set status = 'pending' where id::text like '46464646-%';
update public.profiles set status = 'approved' where id in (:s, :a, :b, :c, :f, :x, :y);
update public.profiles set role = 'admin' where id in (:x, :y);
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());
-- Tokens: S 0 (spends nothing on donations), A 10, B 10, C 3.
update public.quota_balances set balance = 0 where member_id = :s;
update public.quota_balances set balance = 10 where member_id in (:a, :b);
update public.quota_balances set balance = 3 where member_id = :c;

create function pg_temp.list(p_donation boolean, p_stock int default 1) returns uuid
language sql as $$
  select public.create_listing(p_title => 'T46 item', p_description => 'desc',
    p_category => 'other', p_condition => 'like_new',
    p_price => case when p_donation then 0 else 50000 end, p_stock => p_stock,
    p_campus => 'bandung', p_warranty => null, p_specs => null, p_is_donation => p_donation,
    p_photos => array[auth.uid()::text || '/' || gen_random_uuid()::text || '.jpg']);
$$;
create function pg_temp.bid(p_listing uuid, p_amount int) returns timestamptz
language sql as $$ select public.place_bid(p_listing, p_amount, 'bandung', 'Lobi') $$;
create function pg_temp.tokens(p_member uuid) returns int
language sql as $$ select balance from public.quota_balances where member_id = p_member $$;

-- Listing a donation is free --------------------------------------------------------------

select pg_temp.act_as(:s);
select lives_ok($$ select pg_temp.list(true) $$, 'a donor with no tokens lists a donation');
-- D-51 allows 3 active donations; this one only shows listing is free.
reset role;
update public.listings set withdrawn_at = now() where seller_id = :s;
select pg_temp.act_as(:s);
select throws_ok($$ select pg_temp.list(false) $$, '23514', 'no_quota', 'a sale still needs a token');
select set_config('t.d1', pg_temp.list(true)::text, true);
select set_config('t.d2', pg_temp.list(true, 2)::text, true);
select set_config('t.d3', pg_temp.list(true)::text, true);
reset role;
select is(pg_temp.tokens(:s), 0, 'the donor kept 0 tokens');
select is((select count(*)::int from public.quota_ledger where member_id = :s), 1,
  'donations add no ledger rows (only the starting grant)');
update public.quota_balances set balance = 1 where member_id = :s;
select pg_temp.act_as(:s);
select set_config('t.l1', pg_temp.list(false)::text, true);
reset role;
select current_setting('t.d1') as d1, current_setting('t.d2') as d2,
  current_setting('t.d3') as d3, current_setting('t.l1') as l1 \gset

-- Who may bid ---------------------------------------------------------------------------

set local role anon;
select throws_ok(format('select pg_temp.bid(%L, 1)', :'d1'), '42501', null, 'guests cannot bid');
reset role;
select pg_temp.act_as(:p);
select throws_ok(format('select pg_temp.bid(%L, 1)', :'d1'), '42501', 'not_allowed', 'pending accounts cannot bid');
reset role;
select pg_temp.act_as(:f);
select throws_ok(format('select pg_temp.bid(%L, 1)', :'d1'), '42501', 'not_allowed', 'frozen accounts cannot bid');
reset role;
select pg_temp.act_as(:s);
select throws_ok(format('select pg_temp.bid(%L, 1)', :'d1'), '23514', 'own_listing', 'donors cannot bid on their own');
reset role;
select pg_temp.act_as(:a);
select throws_ok(format('select pg_temp.bid(%L, 1)', :'l1'), '23514', 'not_donation', 'sales are not bid on');
select throws_ok(format('select pg_temp.bid(%L, 0)', :'d1'), '23514', 'bid_too_low', 'a bid is at least 1 token');
select throws_ok(format('select pg_temp.bid(%L, 11)', :'d1'), '23514', 'not_enough_tokens', 'no more than the balance');
select throws_ok(format('select public.place_order(%L, ''buy'', ''bandung'', null)', :'d1'),
  '23514', 'donation_bid_only', 'donations cannot be bought directly');
reset role;

-- Bidding ----------------------------------------------------------------------------------

select pg_temp.act_as(:a);
select set_config('t.ends', pg_temp.bid(:'d1', 3)::text, true);
select is(current_setting('t.ends')::timestamptz, now() + interval '24 hours',
  'the first bid opens a 24-hour window');
reset role;
select is(pg_temp.tokens(:a), 7, 'the bid holds its tokens');
select pg_temp.act_as(:b);
select lives_ok(format('select pg_temp.bid(%L, 5)', :'d1'), 'B outbids A');
select is((select ends_at from public.listing_bids(:'d1')),
  (select bid_ends_at from public.listings where id = :'d1'), 'later bids keep the window');
select is((select row(bidders, top_amounts, my_amount, my_rank)::text from public.listing_bids(:'d1')),
  '(2,"{5,3}",5,1)', 'B sees the summary and is first');
reset role;
select pg_temp.act_as(:a);
select throws_ok(format('select pg_temp.bid(%L, 3)', :'d1'), '23514', 'bid_too_low', 'a raise must go up');
select lives_ok(format('select pg_temp.bid(%L, 5)', :'d1'), 'A matches 5');
select is((select my_rank from public.listing_bids(:'d1')), 2, 'a tie goes to whoever reached it first');
select lives_ok(format('select pg_temp.bid(%L, 6)', :'d1'), 'A raises to 6');
reset role;
select is(pg_temp.tokens(:a), 4, 'a raise holds only the difference');
select is((select sum(delta)::int from public.quota_ledger where member_id = :a and reason = 'bid'), -6,
  'the ledger records every hold');
select is((select count(*)::int from public.donation_bids where listing_id = :'d1'), 2, 'one bid per member');
select pg_temp.act_as(:c);
select throws_ok($$ select * from public.donation_bids $$, '42501', null, 'bids are not readable directly');
reset role;

-- C bids on the two-unit D2; A and B on D3.
select pg_temp.act_as(:c);
select lives_ok(format('select pg_temp.bid(%L, 2)', :'d2'), 'C bids on D2');
reset role;
select pg_temp.act_as(:a);
select lives_ok(format('select pg_temp.bid(%L, 1)', :'d3'), 'A bids on D3');
reset role;
select pg_temp.act_as(:b);
select lives_ok(format('select pg_temp.bid(%L, 2)', :'d3'), 'B bids on D3');
reset role;

-- Withdrawing ----------------------------------------------------------------------------

select pg_temp.act_as(:s);
select throws_ok(format('select public.withdraw_listing(%L)', :'d1'), '23514', 'listing_has_bids',
  'a donation with bids cannot be withdrawn');
reset role;

-- Closing (pg_cron) ------------------------------------------------------------------------

select is((select count(*)::int from cron.job where jobname = 'donation-bids'), 1, 'closing runs on pg_cron');
select pg_temp.act_as(:a);
select throws_ok($$ select public.close_donation_bids() $$, '42501', null, 'members cannot close bids');
reset role;

select public.close_donation_bids(now() + interval '23 hours');
select is((select count(*)::int from public.donation_bids where status = 'active' and listing_id::text in (:'d1', :'d2', :'d3')), 5,
  'nothing closes before 24 hours');

-- Admin removes D3 before it closes: every bid comes back.
update public.listings set removed_at = now(), removed_by = :x, removal_reason = 'Melanggar aturan' where id = :'d3';
select public.close_donation_bids(now() + interval '24 hours');

select is((select status::text from public.donation_bids where listing_id = :'d1' and bidder_id = :a), 'won', 'A wins D1');
select is((select status::text from public.donation_bids where listing_id = :'d1' and bidder_id = :b), 'lost', 'B loses D1');
select is(pg_temp.tokens(:a), 4, 'A spent 6 on D1 and got 1 back from D3');
select is(pg_temp.tokens(:b), 10, 'B got all tokens back');
select is((select row(kind, status, price, is_donation, buyer_id = :a, seller_id = :s, cod_campus, cod_place)::text
  from public.orders where listing_id = :'d1'),
  '(buy,waiting,0,t,t,t,bandung,Lobi)', 'the win is a Rp0 order waiting for the donor');
select is((select row(stock_left, bid_ends_at)::text from public.listings where id = :'d1'), '(0,)',
  'the unit is taken and the window cleared');
select is((select row(stock_left, bid_ends_at)::text from public.listings where id = :'d2'), '(1,)',
  'D2 had one bidder for two units: one unit stays for new bids');
select is((select count(*)::int from public.donation_bids where listing_id = :'d3' and status = 'lost'), 2,
  'a removed listing refunds every bid');
select is((select count(*)::int from public.quota_ledger where reason = 'bid_refund' and member_id in (:a, :b)), 3,
  'refunds are in the ledger');

-- D2's remaining unit can be bid on again.
select pg_temp.act_as(:b);
select lives_ok(format('select pg_temp.bid(%L, 1)', :'d2'), 'a new window opens on the unit left');
reset role;
select pg_temp.act_as(:c);
select throws_ok(format('select pg_temp.bid(%L, 3)', :'d2'), '23514', 'already_ordered',
  'a winner with a running order cannot bid again');
reset role;

-- After the win ---------------------------------------------------------------------------

select id as o1 from public.orders where listing_id = :'d1' \gset
select id as o2 from public.orders where listing_id = :'d2' \gset

-- The donor cancels A's order: A's 6 tokens return.
select pg_temp.act_as(:s);
select lives_ok(format('select public.cancel_order(%L, ''cannot_meet'', null)', :'o1'), 'the donor cancels');
reset role;
select is(pg_temp.tokens(:a), 10, 'tokens return when the donor cancels');
select is((select status::text from public.donation_bids where order_id = :'o1'), 'refunded', 'the bid is refunded');
select is((select stock_left from public.listings where id = :'d1'), 1, 'the unit returns for new bids');

-- C cancels their own win: no refund.
select pg_temp.act_as(:c);
select lives_ok(format('select public.cancel_order(%L, ''changed_mind'', null)', :'o2'), 'the winner cancels');
reset role;
select is(pg_temp.tokens(:c), 1, 'a winner who cancels keeps nothing back');

select * from finish();
rollback;
