begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- Like GoTrue's OTP sign-up: a random hash is written at INSERT.
insert into auth.users (id, email, encrypted_password, raw_user_meta_data, aud, role) values
  ('cccccccc-0000-4000-8000-000000000001', 'otp@binus.ac.id',
   extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
   '{"full_name": "O", "campus": "online"}', 'authenticated', 'authenticated'),
  ('cccccccc-0000-4000-8000-000000000002', 'nul@binus.ac.id', null,
   '{"full_name": "N", "campus": "online"}', 'authenticated', 'authenticated');

select pg_temp.act_as('cccccccc-0000-4000-8000-000000000001');
select is(public.has_password(), false, 'random hash from an OTP sign-up is no password');
reset role;

-- L6: the member sets a password (GoTrue updates the hash).
update auth.users set encrypted_password = extensions.crypt('abc12345', extensions.gen_salt('bf'))
  where id = 'cccccccc-0000-4000-8000-000000000001';
select pg_temp.act_as('cccccccc-0000-4000-8000-000000000001');
select is(public.has_password(), true, 'a password set after sign-up is reported');
reset role;

-- From NULL too.
update auth.users set encrypted_password = extensions.crypt('abc12345', extensions.gen_salt('bf'))
  where id = 'cccccccc-0000-4000-8000-000000000002';
select isnt((select password_set_at from public.profiles where id = 'cccccccc-0000-4000-8000-000000000002'),
  null, 'NULL to a password marks it');

-- Other updates do not mark it.
insert into auth.users (id, email, encrypted_password, raw_user_meta_data, aud, role) values
  ('cccccccc-0000-4000-8000-000000000003', 'conf@binus.ac.id', 'x',
   '{"full_name": "C", "campus": "online"}', 'authenticated', 'authenticated');
update auth.users set email_confirmed_at = now() where id = 'cccccccc-0000-4000-8000-000000000003';
select is((select password_set_at from public.profiles where id = 'cccccccc-0000-4000-8000-000000000003'),
  null, 'confirming the email is not a password');

-- No profile row: the auth update still succeeds.
insert into auth.users (id, email, encrypted_password, raw_user_meta_data, aud, role) values
  ('cccccccc-0000-4000-8000-000000000004', 'noprofile@binus.ac.id', 'x',
   '{"full_name": "P", "campus": "online"}', 'authenticated', 'authenticated');
delete from public.profiles where id = 'cccccccc-0000-4000-8000-000000000004';
select lives_ok(
  $$ update auth.users set encrypted_password = 'y' where id = 'cccccccc-0000-4000-8000-000000000004' $$,
  'password change without a profile does not fail'
);

-- Members cannot write it themselves.
select pg_temp.act_as('cccccccc-0000-4000-8000-000000000003');
select throws_ok(
  $$ update public.profiles set password_set_at = now() where id = 'cccccccc-0000-4000-8000-000000000003' $$,
  '42501', null, 'member cannot update password_set_at'
);
select throws_ok($$ select public.mark_password_set() $$, '42501', null,
  'member cannot call the trigger function');
reset role;
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosrc ilike '%password_set_at%'
       and p.proname not in ('mark_password_set', 'has_password') $$,
  'no other function writes password_set_at'
);
select is(public.has_password(), false, 'no session: false');

select function_returns('public', 'has_password', array[]::text[], 'boolean', 'returns only a boolean');
set local role anon;
select throws_ok($$ select public.has_password() $$, '42501', null, 'anon cannot call');
reset role;

select * from finish();
rollback;
