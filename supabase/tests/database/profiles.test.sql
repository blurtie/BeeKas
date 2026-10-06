begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

-- Helpers ------------------------------------------------------------------

create function pg_temp.sign_up(p_id uuid, p_email text, p_meta jsonb) returns void
language sql as $$
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (p_id, p_email, p_meta, 'authenticated', 'authenticated');
$$;

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

create function pg_temp.status_of(p_id uuid) returns text
language sql as $$ select status::text from public.profiles where id = p_id $$;

-- Ids: A student, B lecturer, admin from seed.sql
\set a '''aaaaaaaa-0000-4000-8000-000000000001'''
\set b '''bbbbbbbb-0000-4000-8000-000000000001'''
\set admin '''00000000-0000-4000-8000-000000000001'''

-- Profile creation (trigger) -------------------------------------------------

select lives_ok(
  $$ select pg_temp.sign_up('aaaaaaaa-0000-4000-8000-000000000001', 'Ani@Binus.ac.id',
       '{"full_name": "Ani", "phone": "+6281234567890", "campus": "alam_sutera",
         "role": "admin", "status": "approved"}') $$,
  'student signs up'
);
select results_eq(
  $$ select role::text, status::text, account_type::text, email from public.profiles
     where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  $$ values ('member', 'incomplete', 'student', 'ani@binus.ac.id') $$,
  'metadata role/status are ignored; type comes from the domain'
);
select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'x@binus.ac.id',
       '{"full_name": "X", "phone": "+6281200000001", "campus": "online", "account_type": "staff"}') $$,
  '23514', 'account_type_not_allowed', 'binus.ac.id cannot choose an account type'
);
select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'x@gmail.com',
       '{"full_name": "X", "phone": "+6281200000002", "campus": "online"}') $$,
  '23514', 'invalid_email_domain', 'non-BINUS domain is rejected'
);
select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'x@binus.edu',
       '{"full_name": "X", "phone": "+6281200000003", "campus": "online"}') $$,
  '23514', 'account_type_required', 'binus.edu must choose lecturer or staff'
);
select lives_ok(
  $$ select pg_temp.sign_up('bbbbbbbb-0000-4000-8000-000000000001', 'budi@binus.edu',
       '{"full_name": "Budi", "phone": "+6281298765432", "campus": "senayan", "account_type": "lecturer"}') $$,
  'lecturer signs up'
);
select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'y@binus.ac.id',
       '{"full_name": "Y", "phone": "081234567890", "campus": "online"}') $$,
  '23514', null, 'phone must be stored as +628...'
);
select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'z@binus.ac.id',
       '{"full_name": "Z", "phone": "+6281234567890", "campus": "online"}') $$,
  '23505', null, 'phone is unique'
);
select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'w@binus.ac.id',
       '{"full_name": "W", "campus": "online"}') $$,
  '23502', 'phone_required', 'phone is required at sign-up'
);

select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'v@binus.ac.id', '{"phone": "+6281200000004", "campus": "online"}') $$,
  '23502', 'full_name_required', 'full name is required at sign-up'
);
select throws_ok(
  $$ select pg_temp.sign_up(gen_random_uuid(), 'u@binus.ac.id',
       '{"full_name": "U", "phone": "+6281200000005", "campus": "jakarta"}') $$,
  '23514', 'invalid_campus', 'campus must be a D-12 code'
);

-- RLS: reading ----------------------------------------------------------------

select pg_temp.act_as(:a);
select results_eq($$ select id::text from public.profiles $$,
  $$ values ('aaaaaaaa-0000-4000-8000-000000000001') $$, 'member reads only own profile');
reset role;

select pg_temp.act_as(:admin);
select ok((select count(*) from public.profiles) >= 3, 'admin reads all profiles');
reset role;

set local role anon;
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon cannot read profiles');
reset role;

-- RLS: no direct member writes -------------------------------------------------

select pg_temp.act_as(:a);
select throws_ok($$ update public.profiles set full_name = 'Hacked' $$, '42501', null,
  'member cannot update name directly');
update public.profiles set status = 'approved';
update public.profiles set status = 'pending' where id = 'bbbbbbbb-0000-4000-8000-000000000001';
reset role;
select is(pg_temp.status_of(:b), 'incomplete', 'member cannot update another profile');
select is(pg_temp.status_of(:a), 'incomplete', 'member cannot update status directly');

-- Member functions ------------------------------------------------------------

select pg_temp.act_as(:a);
select throws_ok($$ select public.submit_for_review() $$, '23514', 'photos_missing',
  'submit needs both photos');
select lives_ok($$ select public.update_identity('Ani Wijaya', 'kemanggisan') $$,
  'update_identity while incomplete');
reset role;

select pg_temp.act_as(:b);
select lives_ok($$ select public.update_identity('Budi S', 'bekasi') $$, 'B updates own identity');
reset role;
select results_eq(
  $$ select full_name, campus::text from public.profiles where id = 'aaaaaaaa-0000-4000-8000-000000000001' $$,
  $$ values ('Ani Wijaya', 'kemanggisan') $$, 'B calling update_identity does not touch A');

-- Storage: uploads into own folder only, while incomplete or rejected.
select pg_temp.act_as(:a);
select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     values ('verification', 'aaaaaaaa-0000-4000-8000-000000000001/card.jpg', 'aaaaaaaa-0000-4000-8000-000000000001'),
            ('verification', 'aaaaaaaa-0000-4000-8000-000000000001/selfie.jpg', 'aaaaaaaa-0000-4000-8000-000000000001') $$,
  'member uploads own card and selfie');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('verification', 'bbbbbbbb-0000-4000-8000-000000000001/card.jpg') $$,
  '42501', null, 'member cannot upload into another folder');
select is((select count(*)::int from storage.objects where bucket_id = 'verification'), 0,
  'member cannot read photos, not even their own');
select lives_ok($$ select public.submit_for_review() $$, 'submit with both photos');
reset role;
select is(pg_temp.status_of(:a), 'pending', 'A is pending');

select pg_temp.act_as(:a);
select throws_ok($$ select public.submit_for_review() $$, '23514', 'illegal_status_transition',
  'cannot submit again while pending');
select throws_ok($$ select public.update_identity('X', 'online') $$, '23514', 'identity_locked',
  'identity locked while pending');
select throws_ok($$ select public.set_phone('+6281111111111') $$, '23514', 'phone_not_released',
  'set_phone needs a released number');
reset role;

-- Admin ------------------------------------------------------------------------

select pg_temp.act_as(:admin);
select is((select count(*)::int from storage.objects where bucket_id = 'verification'), 2,
  'admin reads photos');
select throws_ok($$ update public.profiles set status = 'incomplete' where email = 'ani@binus.ac.id' $$,
  '23514', null, 'pending -> incomplete is illegal');
select throws_ok($$ update public.profiles set status = 'approved' where email = 'budi@binus.edu' $$,
  '23514', null, 'incomplete -> approved is illegal');
update public.profiles set status = 'approved', phone = null where email = 'ani@binus.ac.id';
reset role;
select is(pg_temp.status_of(:a), 'approved', 'admin approves pending');

select pg_temp.act_as(:a);
select throws_ok($$ select public.set_phone('081111111111') $$, '23514', null,
  'set_phone keeps the +628 format');
select throws_ok($$ select public.set_phone('+6281298765432') $$, '23505', null,
  'set_phone keeps numbers unique');
select lives_ok($$ select public.set_phone('+6281111111111') $$, 'set_phone after release');
select throws_ok($$ select public.update_identity('X', 'online') $$, '23514', 'identity_locked',
  'identity locked while approved');
reset role;

select * from finish();
rollback;
