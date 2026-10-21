begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- Seller S (approved) with one active and one inactive listing; member M browses.
\set s '''74747474-0000-4000-8000-000000000001'''
\set m '''74747474-0000-4000-8000-000000000002'''
\set active '''74747474-0000-4000-8000-0000000000a1'''
\set hidden '''74747474-0000-4000-8000-0000000000a2'''

insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  (:s, 't74-s@binus.ac.id', '{"full_name": "Seller T74", "campus": "bandung", "phone": "+6281274000001"}', 'authenticated', 'authenticated'),
  (:m, 't74-m@binus.ac.id', '{"full_name": "Member T74", "campus": "online", "phone": "+6281274000002"}', 'authenticated', 'authenticated');
update public.profiles set phone = '+6281274000001' where id = :s;
update public.profiles set status = 'pending' where id = :s;
update public.profiles set status = 'approved' where id = :s;

insert into public.listings (id, seller_id, title, description, category, condition, price, campus, created_at)
values
  (:active, :s, 'T74 Active', 'desc', 'other', 'like_new', 50000, 'bandung', now() + interval '1 day'),
  (:hidden, :s, 'T74 Hidden', 'desc', 'other', 'like_new', 50000, 'bandung', now());
update public.listings set is_active = false where id = :hidden;
insert into public.listing_photos (listing_id, position, path) values
  (:active, 2, 't74/2.jpg'), (:active, 1, 't74/1.jpg'), (:hidden, 1, 't74/h.jpg');

-- Rules ------------------------------------------------------------------------

select throws_ok($$ insert into public.listings (seller_id, title, description, category, condition, price, campus)
  values ('74747474-0000-4000-8000-000000000001', 'x', 'x', 'other', 'like_new', 999, 'bandung') $$,
  '23514', null, 'a sale costs at least Rp1.000');
select throws_ok($$ insert into public.listings (seller_id, title, description, category, condition, price, campus)
  values ('74747474-0000-4000-8000-000000000001', 'x', 'x', 'other', 'like_new', 50000001, 'bandung') $$,
  '23514', null, 'a sale costs at most Rp50.000.000');
select throws_ok($$ insert into public.listings (seller_id, title, description, category, condition, price, campus, is_donation)
  values ('74747474-0000-4000-8000-000000000001', 'x', 'x', 'other', 'like_new', 1000, 'bandung', true) $$,
  '23514', null, 'a donation is Rp0');
select throws_ok($$ insert into public.listings (seller_id, title, description, category, condition, price, campus, stock)
  values ('74747474-0000-4000-8000-000000000001', 'x', 'x', 'other', 'like_new', 1000, 'bandung', 0) $$,
  '23514', null, 'stock is at least 1');
select throws_ok($$ insert into public.listing_photos values ('74747474-0000-4000-8000-0000000000a1', 6, 'x') $$,
  '23514', null, 'at most 5 photos');

update public.listings set price = 40000 where id = :active;
select is((select previous_price from public.listings where id = :active), 50000,
  'a price drop keeps the old price struck through');
update public.listings set price = 45000 where id = :active;
select is((select previous_price from public.listings where id = :active), null,
  'a price rise clears the struck-through price');

-- Guests -----------------------------------------------------------------------

set local role anon;
select is((select count(*)::int from public.listings where id in (:active, :hidden)), 1,
  'guest reads active listings only');
select is((select count(*)::int from public.listing_photos where listing_id in (:active, :hidden)), 2,
  'guest reads photos of active listings only');
select is((select photos from public.catalog_listings('T74') where id = :active), array['t74/1.jpg', 't74/2.jpg'],
  'catalog lists photos in order');
select is((select count(*)::int from public.catalog_listings('T74') where id = :hidden), 0,
  'catalog hides inactive listings');
select is((select (seller_name, seller_campus::text, seller_verified)::text from public.catalog_listings('T74') where id = :active),
  '("Seller T74",bandung,t)', 'catalog shows seller name, campus and verified');
select throws_ok($$ insert into public.listings (seller_id, title, description, category, condition, price, campus)
  values ('74747474-0000-4000-8000-000000000001', 'x', 'x', 'other', 'like_new', 1000, 'bandung') $$,
  '42501', null, 'guest cannot insert listings');
select throws_ok($$ update public.listings set price = 1000 $$, '42501', null, 'guest cannot update listings');
select throws_ok($$ insert into public.listing_photos values ('74747474-0000-4000-8000-0000000000a1', 3, 'x') $$,
  '42501', null, 'guest cannot add photos');
reset role;

-- Members ----------------------------------------------------------------------

select pg_temp.act_as(:m);
select throws_ok($$ insert into public.listings (seller_id, title, description, category, condition, price, campus)
  values ('74747474-0000-4000-8000-000000000002', 'x', 'x', 'other', 'like_new', 1000, 'online') $$,
  '42501', null, 'member cannot insert listings yet');
select throws_ok($$ update public.listings set price = 1000 where id = '74747474-0000-4000-8000-0000000000a1' $$,
  '42501', null, 'member cannot update listings');
select throws_ok($$ delete from public.listings $$, '42501', null, 'member cannot delete listings');
select is((select count(*)::int from public.profiles where id = '74747474-0000-4000-8000-000000000001'), 0,
  'member still cannot read the seller profile');
reset role;

-- D-26: the seller's email and phone appear nowhere in the catalog, as a guest sees it.
set local role anon;
select ok(
  (select bool_and(row_to_json(c)::text !~ 't74-s@binus|6281274000001|mail|phone') from public.catalog_listings('T74') c),
  'catalog never carries email or phone');
reset role;

select * from finish();
rollback;
