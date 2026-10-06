begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('dddddddd-0000-4000-8000-000000000001', 'dina@binus.ac.id',
   '{"full_name": "Dina", "campus": "online"}', 'authenticated', 'authenticated'),
  ('dddddddd-0000-4000-8000-000000000002', 'eko@binus.ac.id',
   '{"full_name": "Eko", "campus": "online"}', 'authenticated', 'authenticated');

-- L7 (D-20): no upload before consent.
select pg_temp.act_as('dddddddd-0000-4000-8000-000000000001');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     values ('verification', 'dddddddd-0000-4000-8000-000000000001/1/card.jpg', 'dddddddd-0000-4000-8000-000000000001') $$,
  '42501', null, 'upload without consent is refused');
select throws_ok($$ update public.profiles set consent_at = now(), consent_version = 'x' $$,
  '42501', null, 'member cannot write consent columns directly');
select throws_ok($$ select public.record_consent(' ') $$, '23514', 'consent_version_required',
  'consent needs a text version');
select lives_ok($$ select public.record_consent('2026-10-07') $$, 'member records consent');
select results_eq(
  $$ select consent_version, consent_at = now() from public.profiles
     where id = 'dddddddd-0000-4000-8000-000000000001' $$,
  $$ values ('2026-10-07', true) $$, 'consent time and text version are stored');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     values ('verification', 'dddddddd-0000-4000-8000-000000000001/1/card.jpg', 'dddddddd-0000-4000-8000-000000000001') $$,
  'upload after consent is accepted');
reset role;

select is(
  (select consent_at from public.profiles where id = 'dddddddd-0000-4000-8000-000000000002'), null,
  'record_consent only touches the caller');

-- Only while incomplete or rejected.
update public.profiles set status = 'pending' where id = 'dddddddd-0000-4000-8000-000000000001';
select pg_temp.act_as('dddddddd-0000-4000-8000-000000000001');
select throws_ok($$ select public.record_consent('2026-10-08') $$, '23514', 'consent_locked',
  'no consent change while pending');
reset role;
update public.profiles set status = 'rejected' where id = 'dddddddd-0000-4000-8000-000000000001';
select pg_temp.act_as('dddddddd-0000-4000-8000-000000000001');
select lives_ok($$ select public.record_consent('2026-10-08') $$, 'consent again after a rejection');
reset role;
select is(
  (select consent_version from public.profiles where id = 'dddddddd-0000-4000-8000-000000000001'),
  '2026-10-08', 'the newer version replaces the old one');

set local role anon;
select throws_ok($$ select public.record_consent('2026-10-07') $$, '42501', null,
  'anon cannot record consent');
reset role;
select pg_temp.act_as(null);
select throws_ok($$ select public.record_consent('2026-10-07') $$, '42501', 'not_authenticated',
  'needs a signed-in member');
reset role;

select * from finish();
rollback;
