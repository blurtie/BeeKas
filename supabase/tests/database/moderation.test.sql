begin;
create extension if not exists pgtap with schema extensions;
select plan(56);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- S seller; A, B buyers/reporters; P pending; F frozen; X, Y admins.
\set s '''87878787-0000-4000-8000-000000000001'''
\set a '''87878787-0000-4000-8000-000000000002'''
\set b '''87878787-0000-4000-8000-000000000003'''
\set p '''87878787-0000-4000-8000-000000000004'''
\set f '''87878787-0000-4000-8000-000000000005'''
\set x '''87878787-0000-4000-8000-000000000006'''
\set y '''87878787-0000-4000-8000-000000000007'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('87878787-0000-4000-8000-00000000000' || n)::uuid, 't87-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T87 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 7) n;
update public.profiles set phone = '+62812870000' || right(id::text, 2)
  where id::text like '87878787-%';
update public.profiles set status = 'pending' where id::text like '87878787-%';
update public.profiles set status = 'approved' where id in (:s, :a, :b, :f, :x, :y);
update public.profiles set role = 'admin' where id in (:x, :y);
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());
update public.quota_balances set balance = 10 where member_id in (:s, :a, :b);

create function pg_temp.list(p_donation boolean, p_stock int default 2) returns uuid
language sql as $$
  select public.create_listing(p_title => 'T87 item', p_description => 'desc',
    p_category => 'other', p_condition => 'like_new',
    p_price => case when p_donation then 0 else 50000 end, p_stock => p_stock,
    p_campus => 'bandung', p_warranty => null, p_specs => null, p_is_donation => p_donation,
    p_photos => array[auth.uid()::text || '/' || gen_random_uuid()::text || '.jpg']);
$$;
create function pg_temp.tokens(p_member uuid) returns int
language sql as $$ select balance from public.quota_balances where member_id = p_member $$;

select pg_temp.act_as(:s);
select set_config('t.l1', pg_temp.list(false)::text, true);
select set_config('t.l2', pg_temp.list(false)::text, true);
select set_config('t.d1', pg_temp.list(true)::text, true);
select set_config('t.d2', pg_temp.list(true, 1)::text, true);
reset role;
select current_setting('t.l1') as l1, current_setting('t.l2') as l2,
  current_setting('t.d1') as d1, current_setting('t.d2') as d2 \gset

-- Lapor -------------------------------------------------------------------------------

set local role anon;
select throws_ok(format('select public.submit_report(''spam'', null, %L)', :'l1'), '42501', null,
  'guests cannot report');
reset role;
select pg_temp.act_as(:p);
select throws_ok(format('select public.submit_report(''spam'', null, %L)', :'l1'), '42501',
  'not_allowed', 'pending accounts cannot report');
reset role;
select pg_temp.act_as(:f);
select throws_ok(format('select public.submit_report(''spam'', null, %L)', :'l1'), '42501',
  'not_allowed', 'frozen reporters are refused');
reset role;
select pg_temp.act_as(:s);
select throws_ok(format('select public.submit_report(''spam'', null, %L)', :'l1'), '23514',
  'own_listing', 'nobody reports their own listing');
reset role;
select pg_temp.act_as(:a);
select throws_ok(format('select public.submit_report(''other'', ''  '', %L)', :'l1'), '23514',
  'note_missing', 'Lainnya needs a note');
select throws_ok('select public.submit_report(''spam'')', '23514', 'report_invalid',
  'a report needs an object');
select lives_ok(format('select public.submit_report(''scam'', null, %L)', :'l1'),
  'an approved member reports a listing without a note');
select throws_ok(format('select public.submit_report(''spam'', null, %L)', :'l1'), '23514',
  'already_reported', 'one open report per reporter and listing');
select throws_ok('select * from public.reports', '42501', null, 'members read no reports, not even their own');
reset role;
select pg_temp.act_as(:b);
select lives_ok(format('select public.submit_report(''other'', ''Palsu'', %L)', :'l1'),
  'a second reporter on the same listing');
-- A chat with S, then a report on S from it.
select set_config('t.c1', public.send_message('Halo', null, :'l2')::text, true);
reset role;
select current_setting('t.c1') as c1 \gset
select pg_temp.act_as(:x);
select throws_ok(format('select * from public.admin_report_messages(%L)', :'c1'), '42501',
  'no_open_report', 'admins cannot read a chat without an open report');
reset role;
select pg_temp.act_as(:b);
select lives_ok(format('select public.submit_report(''inappropriate'', null, null, %L)', :'c1'),
  'a member reports the other party of a chat');
select throws_ok(format('select public.submit_report(''spam'', null, null, %L)', :'c1'), '23514',
  'already_reported', 'one open report per reporter and member');
reset role;
select pg_temp.act_as(:a);
select throws_ok(format('select public.submit_report(''spam'', null, null, %L)', :'c1'), '42501',
  'not_participant', 'only participants report from a chat');
reset role;

-- Admin console ------------------------------------------------------------------------

select pg_temp.act_as(:a);
select throws_ok('select * from public.admin_open_reports()', '42501', 'not_admin',
  'members cannot list reports');
select throws_ok(format('select public.remove_listing(%L, ''x'')', :'l1'), '42501', 'not_admin',
  'members cannot take listings down');
select throws_ok(format('select public.dismiss_report(%L)', gen_random_uuid()), '42501', 'not_admin',
  'members cannot dismiss reports');
select throws_ok(format('select public.restore_quota(%L, ''x'')', :a), '42501', 'not_admin',
  'members cannot restore quota');
select throws_ok(format('select * from public.admin_report_messages(%L)', :'c1'), '42501', 'not_admin',
  'members cannot read reported chats');
reset role;
select pg_temp.act_as(:x);
select is((select reporters from public.admin_open_reports() where listing_id = :'l1'), 2,
  'reports are grouped per listing with their reporter count');
select is((select reported_id from public.admin_open_reports() where reported_id is not null), :s::uuid,
  'a chat report names the reported member');
select is((select count(*)::int from public.admin_report_messages(:'c1')), 1,
  'admins read a reported chat while its report is open');
select lives_ok(format('select public.dismiss_report(%L)',
  (select report_id from public.admin_open_reports() where reported_id is not null)),
  'Abaikan closes the chat report');
select throws_ok(format('select * from public.admin_report_messages(%L)', :'c1'), '42501',
  'no_open_report', 'admins cannot read the chat once its report is closed');
reset role;

-- K-23: taking a sale listing down cancels its running orders -----------------------------

select pg_temp.act_as(:a);
select public.place_order(:'l1', 'buy', 'bandung', null);
reset role;
select pg_temp.act_as(:b);
select public.place_order(:'l1', 'booking', 'bandung', null);
reset role;
update public.orders set status = 'processing', cod_at = now() + interval '1 day', accepted_at = now()
  where buyer_id = :b and listing_id = :'l1';
-- A completed order on l2 stays completed.
select pg_temp.act_as(:a);
select public.place_order(:'l2', 'buy', 'bandung', null);
reset role;
update public.orders set status = 'completed', cod_at = now(), completed_at = now()
  where buyer_id = :a and listing_id = :'l2';
select is((select stock_left from public.listings where id = :'l1'), 0, 'both units are ordered');

select pg_temp.act_as(:x);
select throws_ok(format('select public.remove_listing(%L, ''  '')', :'l1'), '23514', 'reason_missing',
  'taking down needs a reason');
select lives_ok(format('select public.remove_listing(%L, ''Barang terlarang'')', :'l1'),
  'an admin takes the listing down');
select throws_ok(format('select public.remove_listing(%L, ''lagi'')', :'l1'), '23514',
  'listing_unavailable', 'a removed listing cannot be removed again');
select lives_ok(format('select public.remove_listing(%L, ''Spam'')', :'l2'),
  'an admin takes a listing with only completed orders down');
reset role;
select is((select array_agg(distinct cancel_reason::text) from public.orders where listing_id = :'l1'),
  array['admin_removed'], 'every running order is cancelled as admin_removed');
select is((select count(*)::int from public.orders where listing_id = :'l1'
  and status = 'cancelled' and cancelled_by = :x and cancel_note = 'Barang terlarang'), 2,
  'the admin and the reason are on both orders');
select is((select stock_left from public.listings where id = :'l1'), 2, 'the units return');
select is((select status::text from public.orders where listing_id = :'l2'), 'completed',
  'a completed order is not cancelled');
select is((select count(*)::int from public.reports where listing_id = :'l1' and status = 'actioned'), 2,
  'the listing''s reports close as actioned');
select pg_temp.act_as(:a);
select throws_ok(format('select public.send_message(''Halo'', null, %L)', :'l1'), '23514',
  'listing_unavailable', 'the buyer cannot start a chat through the removed listing');
reset role;
-- D-45: an admin-removed listing is never relisted.
select pg_temp.act_as(:s);
select throws_ok(format('select public.relist_listing(%L)', :'l1'), '42501', 'not_allowed',
  'the seller cannot relist an admin-removed listing');
select is((select removal_reason from public.listings where id = :'l1'), 'Barang terlarang',
  'the seller reads the reason in Barang Saya');
reset role;

-- Donations: active bids refund at once; a running winner's order refunds once ------------

select pg_temp.act_as(:a);
select public.place_bid(:'d1', 3, 'bandung', null);
reset role;
select pg_temp.act_as(:b);
select public.place_bid(:'d1', 2, 'bandung', null);
select public.place_bid(:'d2', 4, 'bandung', null);
reset role;
select is(pg_temp.tokens(:a) + pg_temp.tokens(:b), 11, 'bids hold 9 tokens');

select pg_temp.act_as(:y);
select public.remove_listing(:'d1', 'Konten tidak pantas');
reset role;
select is(pg_temp.tokens(:a), 10, 'the first bidder gets every token back at once');
select is(pg_temp.tokens(:b), 6, 'the second bidder gets the d1 tokens back (d2 still held)');
select is((select array_agg(distinct status::text) from public.donation_bids where listing_id = :'d1'),
  array['refunded'], 'the bids are refunded');
select is((select bid_ends_at from public.listings where id = :'d1'), null, 'the window is cleared');
select public.close_donation_bids(now() + interval '25 hours');
select is(pg_temp.tokens(:a) + pg_temp.tokens(:b),
  16, 'the bid timer refunds nothing twice (d2 won by B: 4 tokens spent)');

-- B won d2; its Rp0 order runs. Taking d2 down refunds B once.
select is((select status::text from public.orders where listing_id = :'d2'), 'waiting',
  'the donation winner has a running order');
select pg_temp.act_as(:x);
select public.remove_listing(:'d2', 'Penipuan');
reset role;
select is(pg_temp.tokens(:b), 10, 'the winner''s tokens come back');
select is((select count(*)::int from public.quota_ledger where member_id = :b and reason = 'bid_refund'
  and listing_id = :'d2'), 1, 'one refund on the ledger');
select is((select status::text from public.donation_bids where listing_id = :'d2'), 'refunded',
  'the winning bid is refunded');
select public.close_donation_bids(now() + interval '50 hours');
select public.run_order_timers(now() + interval '50 hours');
select is(pg_temp.tokens(:b), 10, 'the timers refund nothing twice');

-- K-26 helper for T10 and chat with a frozen party ----------------------------------------

select pg_temp.act_as(:s);
select set_config('t.l3', pg_temp.list(false)::text, true);
reset role;
select current_setting('t.l3') as l3 \gset
select pg_temp.act_as(:a);
select public.place_order(:'l3', 'buy', 'bandung', null);
reset role;
-- T10 calls the helper from its own security definer function: as the admin, not the role.
select pg_temp.act_as(:x);
reset role;
select public.admin_cancel_member(:s, 'Dibekukan');
select is((select cancel_reason::text from public.orders where listing_id = :'l3'), 'admin_removed',
  'the member helper cancels the orders on their listings');
select is((select stock_left from public.listings where id = :'l3'), 2, 'and returns the units');
select pg_temp.act_as(:x);
select throws_ok('select public.admin_cancel_member(gen_random_uuid(), ''x'')', '42501', null,
  'no signed-in role, admins included, calls the helper directly');
reset role;

insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:s, 'penipuan', :x, :y, now());
select pg_temp.act_as(:b);
select throws_ok(format('select public.send_message(''Halo'', %L)', :'c1'), '42501',
  'chat_not_allowed', 'nobody sends to a frozen member');
reset role;

-- D-29 Kembalikan kuota ---------------------------------------------------------------------

select pg_temp.act_as(:x);
select throws_ok(format('select public.restore_quota(%L, '' '')', :a), '23514', 'note_missing',
  'restoring quota needs a note');
select lives_ok(format('select public.restore_quota(%L, ''Salah turunkan'', %L)', :a, :'l1'),
  'an admin restores a quota');
reset role;
select is(pg_temp.tokens(:a), 11, 'the balance goes up by 1');
select is((select count(*)::int from public.quota_ledger where member_id = :a and reason = 'correction'
  and admin_id = :x and note = 'Salah turunkan'), 1, 'the restore is on the ledger');

select * from finish();
rollback;
