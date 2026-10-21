begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create function pg_temp.sign_up(p_id uuid, p_email text) returns void
language sql as $$
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (p_id, p_email, '{"full_name": "X", "campus": "online"}', 'authenticated', 'authenticated');
$$;

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- H took I's number; I asks Bantuan to release it. Admin from seed.sql.
\set h '''44444444-0000-4000-8000-000000000001'''
\set i '''44444444-0000-4000-8000-000000000002'''
\set admin '''00000000-0000-4000-8000-000000000001'''

select pg_temp.sign_up(:h, 't40-h@binus.ac.id');
select pg_temp.sign_up(:i, 't40-i@binus.ac.id');
select pg_temp.act_as(:h);
select public.set_phone('+6281240000001');
reset role;

-- Members ----------------------------------------------------------------------

select pg_temp.act_as(:i);
select throws_ok($$ select public.release_phone('44444444-0000-4000-8000-000000000001', 'mine') $$,
  '42501', 'not_admin', 'member cannot release another phone');
select throws_ok($$ select public.set_phone('+6281240000001') $$, '23505', null,
  'the number is taken before release');
reset role;
select pg_temp.act_as(:h);
select throws_ok($$ select public.release_phone('44444444-0000-4000-8000-000000000001', 'x') $$,
  '42501', 'not_admin', 'member cannot release their own phone');
reset role;
set local role anon;
select throws_ok($$ select public.release_phone('44444444-0000-4000-8000-000000000001', 'x') $$,
  '42501', null, 'anon cannot release');
reset role;

-- Admin ------------------------------------------------------------------------

select pg_temp.act_as(:admin);
select throws_ok($$ select public.release_phone('44444444-0000-4000-8000-000000000001', '  ') $$,
  '23514', 'note_missing', 'release needs a note');
select throws_ok($$ select public.release_phone('44444444-0000-4000-8000-000000000002', 'x') $$,
  '23514', 'no_phone', 'an account without a phone cannot be released');
select throws_ok(
  $$ insert into public.phone_releases (profile_id, note) values ('44444444-0000-4000-8000-000000000001', 'x') $$,
  '42501', null, 'not even admins write the log directly');
select lives_ok(
  $$ select public.release_phone('44444444-0000-4000-8000-000000000001', ' Pemilik asli lewat Bantuan ') $$,
  'admin releases the phone');
select is((select phone from public.profiles where id = :h), null, 'the phone is cleared');
select results_eq(
  $$ select profile_id, released_by, note from public.phone_releases
     where profile_id = '44444444-0000-4000-8000-000000000001' $$,
  $$ values ('44444444-0000-4000-8000-000000000001'::uuid, '00000000-0000-4000-8000-000000000001'::uuid,
     'Pemilik asli lewat Bantuan') $$,
  'the release is logged with account, admin and note');
reset role;
select is(
  (select count(*)::int from public.phone_releases r where to_jsonb(r)::text like '%81240000001%'),
  0, 'the log never holds the number');

-- After release ----------------------------------------------------------------

select pg_temp.act_as(:i);
select lives_ok($$ select public.set_phone('+6281240000001') $$, 'the real owner can now use the number');
select is((select count(*)::int from public.phone_releases), 0, 'members cannot read the log');
reset role;
select pg_temp.act_as(:h);
select lives_ok($$ select public.set_phone('+6281240000002') $$, 'the released account can add a new number');
reset role;

select * from finish();
rollback;
