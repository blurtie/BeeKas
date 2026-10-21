begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- A buyer, S seller, C another member: approved. P pending; F approved and frozen;
-- X, Y admins.
\set a '''86868686-0000-4000-8000-000000000001'''
\set s '''86868686-0000-4000-8000-000000000002'''
\set c '''86868686-0000-4000-8000-000000000003'''
\set p '''86868686-0000-4000-8000-000000000004'''
\set f '''86868686-0000-4000-8000-000000000005'''
\set x '''86868686-0000-4000-8000-000000000006'''
\set y '''86868686-0000-4000-8000-000000000007'''
-- Listings: L live (S), G taken down (S), E expired (S), FL of the frozen F.
\set l '''86868686-1111-4000-8000-000000000001'''
\set g '''86868686-1111-4000-8000-000000000002'''
\set e '''86868686-1111-4000-8000-000000000003'''
\set fl '''86868686-1111-4000-8000-000000000004'''
\set lc '''86868686-1111-4000-8000-000000000005'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('86868686-0000-4000-8000-00000000000' || n)::uuid, 't86-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T86 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 7) n;
update public.profiles set phone = '+62812860000' || right(id::text, 2)
  where id::text like '86868686-%';
update public.profiles set status = 'pending' where id::text like '86868686-%';
update public.profiles set status = 'approved' where id in (:a, :s, :c, :f, :x, :y);
update public.profiles set role = 'admin' where id in (:x, :y);
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());

insert into public.listings (id, seller_id, title, description, category, condition, price, campus, is_active, expires_at)
values
  (:l, :s, 'Kalkulator', 'Masih bagus', 'laptop_computer', 'like_new', 50000, 'bandung', true, now() + interval '30 days'),
  (:g, :s, 'Buku', 'Lengkap', 'books_stationery', 'like_new', 20000, 'bandung', false, now() + interval '30 days'),
  (:e, :s, 'Meja', 'Kokoh', 'other', 'like_new', 90000, 'bandung', true, now() - interval '1 day'),
  (:fl, :f, 'Kursi', 'Kokoh', 'other', 'like_new', 90000, 'bandung', true, now() + interval '30 days'),
  (:lc, :c, 'Lampu', 'Terang', 'other', 'like_new', 30000, 'bandung', true, now() + interval '30 days');

-- Starting a chat ---------------------------------------------------------------------

select pg_temp.act_as(:a);
select lives_ok($$ select public.send_message('Masih ada?', p_listing => '86868686-1111-4000-8000-000000000001') $$,
  'a buyer starts a chat from a live listing');
select is((select row(buyer_id, seller_id, listing_id)::text from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001'),
  '(86868686-0000-4000-8000-000000000001,86868686-0000-4000-8000-000000000002,86868686-1111-4000-8000-000000000001)',
  'one conversation for the pair, with the listing card');
select is(public.send_message('Bisa nego?', p_listing => '86868686-1111-4000-8000-000000000001'),
  (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001'), 'the same pair reuses its conversation');
select is((select count(*)::int from public.messages m join public.conversations c on c.id = m.conversation_id where c.buyer_id::text like '86868686-%'), 2, 'the buyer reads both messages');
select throws_ok($$ select public.send_message('x', p_listing => '86868686-1111-4000-8000-000000000002') $$,
  '23514', 'listing_unavailable', 'a taken-down listing cannot start a chat');
select throws_ok($$ select public.send_message('x', p_listing => '86868686-1111-4000-8000-000000000003') $$,
  '23514', 'listing_unavailable', 'an expired listing cannot start a chat');
select throws_ok($$ select public.send_message('x', p_listing => '86868686-1111-4000-8000-000000000004') $$,
  '23514', 'listing_unavailable', 'a frozen seller''s listing cannot start a chat');
select throws_ok($$ select public.send_message('x') $$,
  '23514', 'listing_unavailable', 'a new chat needs a listing');
select throws_ok($$ insert into public.messages (conversation_id, sender_id, body)
  select id, '86868686-0000-4000-8000-000000000001', 'x' from public.conversations $$,
  '42501', null, 'members cannot insert messages directly');
select throws_ok($$ insert into public.conversations (buyer_id, seller_id)
  values ('86868686-0000-4000-8000-000000000001', '86868686-0000-4000-8000-000000000003') $$,
  '42501', null, 'members cannot create conversations directly');
reset role;

select pg_temp.act_as(:s);
select throws_ok($$ select public.send_message('Halo', p_listing => '86868686-1111-4000-8000-000000000001') $$,
  '23514', 'listing_unavailable', 'sellers cannot chat about their own listing');
select is((select count(*)::int from public.messages m join public.conversations c on c.id = m.conversation_id where c.buyer_id::text like '86868686-%'), 2, 'the seller reads the conversation');
select lives_ok($$ select public.send_message('Masih, bisa', (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001')) $$,
  'the seller replies in the conversation');
select is(public.conversation_for_listing('86868686-1111-4000-8000-000000000001'), null,
  'the seller has no buyer conversation for their own listing');
reset role;

select pg_temp.act_as(:a);
select is(public.conversation_for_listing('86868686-1111-4000-8000-000000000001'),
  (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001'), 'the buyer finds the conversation from the listing');
select is((select count(*)::int from public.my_conversations() where i_am_buyer and other_name = 'T86 2' and last_body = 'Masih, bisa'), 1,
  'the list shows the last message, and that I am the buyer');
select throws_ok($$ select public.send_message('', (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001')) $$,
  '23514', null, 'empty messages are refused');
select throws_ok($$ select public.send_message('   ', (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001')) $$,
  '23514', null, 'blank messages are refused');
select throws_ok(format('select public.send_message(%L, (select id from public.conversations where buyer_id = auth.uid()))', repeat('a', 1001)),
  '23514', null, 'messages over 1.000 characters are refused (K-21)');
select lives_ok(format('select public.send_message(%L, (select id from public.conversations where buyer_id = auth.uid()))', repeat('a', 1000)),
  '1.000 characters are allowed');
reset role;

-- The item card only takes this seller's live listings.
select pg_temp.act_as(:a);
select throws_ok($$ select public.send_message('x', (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001'),
  '86868686-1111-4000-8000-000000000002') $$,
  '23514', 'listing_unavailable', 'a taken-down listing cannot become the card');
select throws_ok($$ select public.send_message('x', (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001'),
  '86868686-1111-4000-8000-000000000005') $$,
  '23514', 'listing_unavailable', 'another seller''s listing cannot become the card');
select is((select listing_id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001'), '86868686-1111-4000-8000-000000000001'::uuid,
  'the card stays');
reset role;

-- Own listings (Chat Penjual hidden) ---------------------------------------------------

select pg_temp.act_as(:s);
select is((select is_mine from public.catalog_listings() where id = :l), true,
  'the seller sees the listing as theirs');
reset role;
select pg_temp.act_as(:a);
select is((select is_mine from public.catalog_listings() where id = :l), false,
  'others do not');
reset role;
set local role anon;
select is((select is_mine from public.catalog_listings() where id = :l), false,
  'guests do not');
reset role;

-- Only participants -------------------------------------------------------------------

select set_config('t.conv', (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001')::text, true);

select pg_temp.act_as(:c);
select is((select count(*)::int from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000001') + (select count(*)::int from public.messages m join public.conversations c on c.id = m.conversation_id where c.buyer_id::text like '86868686-%'), 0,
  'others read neither the conversation nor its messages');
select throws_ok(format('select public.send_message(%L, %L)', 'x', current_setting('t.conv')),
  '42501', 'not_participant', 'others cannot write into it');
reset role;

select pg_temp.act_as(:x);
select is((select count(*)::int from public.messages m join public.conversations c on c.id = m.conversation_id where c.buyer_id::text like '86868686-%'), 0, 'admins do not read chats (K-24)');
reset role;

set local role anon;
select throws_ok($$ select public.send_message('x', p_listing => '86868686-1111-4000-8000-000000000001') $$,
  '42501', null, 'guests cannot send');
reset role;

select pg_temp.act_as(:p);
select throws_ok($$ select public.send_message('x', p_listing => '86868686-1111-4000-8000-000000000001') $$,
  '42501', 'chat_not_allowed', 'pending accounts cannot send');
reset role;

-- A frozen buyer, after the conversation exists, cannot write in it (K-26).
insert into public.conversations (buyer_id, seller_id) values (:f, :s);
select pg_temp.act_as(:f);
select throws_ok($$ select public.send_message('x', (select id from public.conversations where buyer_id = '86868686-0000-4000-8000-000000000005')) $$,
  '42501', 'chat_not_allowed', 'frozen accounts cannot send');
reset role;

-- The other member's phone stays hidden (D-26).
select pg_temp.act_as(:a);
select is((select count(*)::int from public.profiles where id = :s), 0,
  'the buyer cannot read the seller''s profile row, phone included');
reset role;

-- Admin BeeKas ------------------------------------------------------------------------

select pg_temp.act_as(:a);
select throws_ok($$ select public.post_announcement('Promo!') $$,
  '42501', 'not_admin', 'members cannot post announcements');
reset role;

select pg_temp.act_as(:x);
select lives_ok($$ select public.post_announcement('Layanan libur 1 November.') $$,
  'admins post announcements (K21)');
reset role;

select pg_temp.act_as(:p);
select is((select body from public.announcements where posted_by = '86868686-0000-4000-8000-000000000006'), 'Layanan libur 1 November.',
  'every signed-in member reads announcements');
reset role;

select is((select count(*)::int from pg_publication_tables
  where pubname = 'supabase_realtime' and tablename = 'messages'), 1,
  'messages are published to Realtime');

select is((select count(*)::int from pg_publication_tables
  where pubname = 'supabase_realtime' and tablename = 'announcements'), 1,
  'announcements are published to Realtime');

-- The card disappears once the listing is no longer live.
update public.listings set is_active = false where id = :l;
select pg_temp.act_as(:a);
select is((select row(listing_id, listing_title)::text from public.my_conversations() where other_name = 'T86 2'), '(,)',
  'no card for a listing that is no longer live');
select is((select last_body from public.my_conversations() where other_name = 'T86 2'), repeat('a', 1000),
  'the conversation itself stays');
reset role;

select * from finish();
rollback;
