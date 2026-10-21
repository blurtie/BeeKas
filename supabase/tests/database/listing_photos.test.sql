begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- A approved; B approved; P pending; F approved and frozen; X, Y admins.
\set a '''82828282-0000-4000-8000-000000000001'''
\set b '''82828282-0000-4000-8000-000000000002'''
\set p '''82828282-0000-4000-8000-000000000003'''
\set f '''82828282-0000-4000-8000-000000000004'''
\set x '''82828282-0000-4000-8000-000000000005'''
\set y '''82828282-0000-4000-8000-000000000006'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('82828282-0000-4000-8000-00000000000' || n)::uuid, 't82-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T82 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 6) n;
update public.profiles set phone = '+62812820000' || right(id::text, 2)
  where id::text like '82828282-%';
update public.profiles set status = 'pending' where id::text like '82828282-%';
update public.profiles set status = 'approved' where id in (:a, :b, :f, :x, :y);
update public.profiles set role = 'admin' where id in (:x, :y);
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());

create function pg_temp.upload(p_name text) returns void
language sql as $$
  insert into storage.objects (bucket_id, name, owner_id)
  values ('listing-photos', p_name, auth.uid()::text);
$$;

-- Bucket (K-05) ----------------------------------------------------------------------

select is((select allowed_mime_types from storage.buckets where id = 'listing-photos'),
  array['image/jpeg'], 'the bucket takes JPEG only');
select is((select file_size_limit from storage.buckets where id = 'listing-photos'),
  5242880::bigint, 'the bucket takes at most 5 MB');

-- Upload policy ----------------------------------------------------------------------

select pg_temp.act_as(:a);
select lives_ok($$ select pg_temp.upload('82828282-0000-4000-8000-000000000001/one.jpg') $$,
  'approved member uploads a JPEG into their own folder');
select throws_ok($$ select pg_temp.upload('82828282-0000-4000-8000-000000000002/one.jpg') $$,
  '42501', null, 'upload into another member''s folder is refused');
select throws_ok($$ select pg_temp.upload('82828282-0000-4000-8000-000000000001/one.png') $$,
  '42501', null, 'a non-JPEG name is refused');
select throws_ok($$ select pg_temp.upload('82828282-0000-4000-8000-000000000001/x/one.jpg') $$,
  '42501', null, 'nested folders are refused');
select is((select count(*)::int from storage.objects where bucket_id = 'listing-photos'
    and name like '82828282-%'), 1, 'member sees their own uploaded photo');
reset role;

select pg_temp.act_as(:p);
select throws_ok($$ select pg_temp.upload('82828282-0000-4000-8000-000000000003/one.jpg') $$,
  '42501', null, 'pending accounts cannot upload');
reset role;

select pg_temp.act_as(:f);
select throws_ok($$ select pg_temp.upload('82828282-0000-4000-8000-000000000004/one.jpg') $$,
  '42501', null, 'frozen accounts cannot upload');
reset role;

set local role anon;
select throws_ok($$ insert into storage.objects (bucket_id, name)
  values ('listing-photos', '82828282-0000-4000-8000-000000000001/anon.jpg') $$,
  '42501', null, 'guests cannot upload');
reset role;

-- Delete policy: the app removes photos of a listing that was not created ---------------

-- The Storage API sets this before its own delete.
set local storage.allow_delete_query = 'true';

select pg_temp.act_as(:b);
delete from storage.objects where bucket_id = 'listing-photos'
  and name = '82828282-0000-4000-8000-000000000001/one.jpg';
reset role;
select is((select count(*)::int from storage.objects
    where name = '82828282-0000-4000-8000-000000000001/one.jpg'), 1,
  'another member cannot delete the photo');

select pg_temp.act_as(:a);
delete from storage.objects where bucket_id = 'listing-photos'
  and name = '82828282-0000-4000-8000-000000000001/one.jpg';
reset role;
select is((select count(*)::int from storage.objects
    where name = '82828282-0000-4000-8000-000000000001/one.jpg'), 0,
  'the owner deletes their photo');

-- Listing goes live after create_listing; description and stock_left ------------------

select pg_temp.act_as(:a);
select pg_temp.upload('82828282-0000-4000-8000-000000000001/two.jpg');
select throws_ok($$ select public.create_listing(p_title => 'T82 item',
    p_description => repeat('x', 501), p_category => 'other', p_condition => 'like_new',
    p_price => 50000, p_stock => 3, p_campus => 'bandung', p_warranty => null,
    p_specs => null, p_is_donation => false,
    p_photos => array['82828282-0000-4000-8000-000000000001/two.jpg']) $$,
  '23514', null, 'a description over 500 characters is refused (K-04)');
create function pg_temp.list(p_id uuid) returns uuid
language sql as $$
  select public.create_listing(p_title => 'T82 item', p_description => repeat('x', 500),
    p_category => 'other', p_condition => 'like_new', p_price => 50000, p_stock => 3,
    p_campus => 'bandung', p_warranty => null, p_specs => null, p_is_donation => false,
    p_photos => array['82828282-0000-4000-8000-000000000001/two.jpg'], p_id => p_id);
$$;
\set l '''82828282-1111-4000-8000-000000000001'''
select is(pg_temp.list(:l), :l::uuid, 'create_listing uses the id the app sent');
select is(pg_temp.list(:l), :l::uuid, 'the same id again returns the listing already made');
reset role;
select is((select count(*)::int from public.listings where id = :l), 1,
  'a repeated id makes one listing');
select is((select count(*)::int from public.quota_ledger
    where member_id = :a and reason = 'listing'), 1,
  'a repeated id takes the quota once');

select pg_temp.act_as(:b);
select throws_ok($$ select pg_temp.list('82828282-1111-4000-8000-000000000001') $$,
  '42501', null, 'another seller cannot claim the id of someone else''s listing');
reset role;

set local role anon;
select is((select count(*)::int from public.catalog_listings() where title = 'T82 item'), 1,
  'the listing is in the catalog right after create_listing');
reset role;

select pg_temp.act_as(:a);
delete from storage.objects where bucket_id = 'listing-photos'
  and name = '82828282-0000-4000-8000-000000000001/two.jpg';
reset role;
select is((select count(*)::int from storage.objects
    where name = '82828282-0000-4000-8000-000000000001/two.jpg'), 1,
  'a photo a listing uses cannot be deleted');

select is((select stock_left from public.listings where title = 'T82 item'), 3,
  'stock_left starts at stock');
select throws_ok($$ update public.listings set stock_left = 4 where title = 'T82 item' $$,
  '23514', null, 'stock_left cannot exceed stock');

select * from finish();
rollback;
