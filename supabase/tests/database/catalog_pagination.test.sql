begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- Seller A (approved) has five listings, three sharing one created_at; seller P is
-- pending with a listing whose title matches every search below.
\set a '''77777777-0000-4000-8000-000000000001'''
\set p '''77777777-0000-4000-8000-000000000002'''

insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  (:a, 't77-a@binus.ac.id', '{"full_name": "Ana Zebrawati", "campus": "bandung", "phone": "+6281277000001"}', 'authenticated', 'authenticated'),
  (:p, 't77-p@binus.ac.id', '{"full_name": "Pending T77", "campus": "bandung", "phone": "+6281277000002"}', 'authenticated', 'authenticated');
update public.profiles set phone = '+6281277000001', status = 'pending' where id = :a;
update public.profiles set status = 'approved' where id = :a;

insert into public.listings (id, seller_id, title, description, category, condition, price, campus, created_at) values
  ('77777777-0000-4000-8000-0000000000a1', :a, 'T77 Laptop Zeta', 'd', 'laptop_computer', 'like_new', 50000, 'bandung', '2030-01-05'),
  ('77777777-0000-4000-8000-0000000000a3', :a, 'T77 Shoes', 'd', 'shoes', 'like_new', 50000, 'bandung', '2030-01-04'),
  ('77777777-0000-4000-8000-0000000000a2', :a, 'T77 Jacket', 'd', 'clothing', 'like_new', 50000, 'bandung', '2030-01-04'),
  ('77777777-0000-4000-8000-0000000000a4', :a, 'T77 Watch', 'd', 'accessories', 'like_new', 50000, 'bandung', '2030-01-04'),
  ('77777777-0000-4000-8000-0000000000a5', :a, 'T77 Book', 'd', 'books_stationery', 'like_new', 50000, 'bandung', '2030-01-01'),
  ('77777777-0000-4000-8000-0000000000b1', :p, 'T77 Pending Zeta', 'd', 'laptop_computer', 'like_new', 50000, 'bandung', '2030-01-06');

set local role anon;

-- Keyset: newest first, ties broken by id; pages of 2 walk all five exactly once.
select is(array(select title from public.catalog_listings(p_limit => 2)),
  array['T77 Laptop Zeta', 'T77 Jacket'], 'first page: newest first, limit respected');
select is(array(select title from public.catalog_listings('t77', p_limit => 2,
    p_after_created_at => '2030-01-04', p_after_id => '77777777-0000-4000-8000-0000000000a2')),
  array['T77 Shoes', 'T77 Watch'], 'next page continues inside equal created_at');
select is(array(select title from public.catalog_listings('t77', p_limit => 2,
    p_after_created_at => '2030-01-04', p_after_id => '77777777-0000-4000-8000-0000000000a4')),
  array['T77 Book'], 'last page is short (with search)');
select is((select count(*)::int from public.catalog_listings('t77', p_limit => 100)), 5,
  'pending seller stays hidden (T1)');
select is((select count(*)::int from public.catalog_listings(p_limit => 0)), 1,
  'limit is at least 1');

-- Search: title or seller name, any case; never the pending seller.
select is(array(select title from public.catalog_listings('zeta')),
  array['T77 Laptop Zeta'], 'search matches the title, ignoring case');
select is((select count(*)::int from public.catalog_listings('ZEBRA')), 5,
  'search matches the seller name, ignoring case');
select is(array(select title from public.catalog_listings('100%_')), '{}'::text[],
  'wildcards in the query are plain text');

-- Category and shortcut-group filters.
select is(array(select title from public.catalog_listings('t77', '{clothing}')),
  array['T77 Jacket'], 'category filter');
select is(array(select title from public.catalog_listings('t77', '{clothing,shoes,bags,accessories}')),
  array['T77 Jacket', 'T77 Shoes', 'T77 Watch'], 'group filter combines with search');

reset role;
select * from finish();
rollback;
