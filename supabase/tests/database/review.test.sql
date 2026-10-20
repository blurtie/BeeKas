begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

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

-- Uploads card and selfie into <id>/<attempt>/ as the member, at [p_at].
create function pg_temp.upload(p_id uuid, p_attempt text, p_at timestamptz, p_selfie boolean default true)
returns void language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, created_at)
  select 'verification', p_id || '/' || p_attempt || '/' || f, p_id::text, p_at
  from unnest(case when p_selfie then array['card.jpg', 'selfie.jpg'] else array['card.jpg'] end) f;
$$;

-- E, F pending (F waited longer); G stays incomplete; admin from seed.sql
\set e '''eeeeeeee-0000-4000-8000-000000000001'''
\set f '''ffffffff-0000-4000-8000-000000000001'''
\set g '''99999999-0000-4000-8000-000000000001'''
\set admin '''00000000-0000-4000-8000-000000000001'''

select pg_temp.sign_up(:e, 'eka@binus.ac.id');
select pg_temp.sign_up(:f, 'fajar@binus.ac.id');
select pg_temp.sign_up(:g, 'gita@binus.ac.id');
update public.profiles set phone = '+6281200000011', consent_at = now() where id = :e;
update public.profiles set phone = '+6281200000012', consent_at = now() where id = :f;

-- E: an older full attempt, then a newer partial one (selfie upload failed), then the final.
select pg_temp.upload(:e, '1', now() - interval '3 hours');
select pg_temp.upload(:e, '2', now() - interval '2 hours', false);
select pg_temp.upload(:e, '3', now() - interval '1 hour');
select pg_temp.upload(:f, '1', now() - interval '2 days');
select pg_temp.act_as(:e);
select public.submit_for_review();
reset role;
select pg_temp.act_as(:f);
select public.submit_for_review();
reset role;
select ok((select submitted_at = now() from public.profiles where id = :e), 'submit records submitted_at');
-- Make F the one waiting longest.
update public.profiles set submitted_at = now() - interval '2 days' where id = :f;

-- Members ----------------------------------------------------------------------

select pg_temp.act_as(:e);
select throws_ok($$ select * from public.pending_verifications() $$, '42501', 'not_admin',
  'member cannot list pending accounts');
select throws_ok($$ select public.approve_verification('eeeeeeee-0000-4000-8000-000000000001') $$,
  '42501', 'not_admin', 'member cannot approve themselves');
select throws_ok($$ select public.approve_verification('ffffffff-0000-4000-8000-000000000001') $$,
  '42501', 'not_admin', 'member cannot approve another member');
select is((select count(*)::int from storage.objects where bucket_id = 'verification'), 0,
  'member cannot read any photo');
select is((select count(*)::int from public.profiles), 1, 'member reads only own profile');
reset role;

set local role anon;
select throws_ok($$ select public.approve_verification('eeeeeeee-0000-4000-8000-000000000001') $$,
  '42501', null, 'anon cannot approve');
reset role;
select is((select count(*)::int from public.profiles where status = 'pending' and id in (:e, :f)), 2,
  'nobody was approved by a non-admin');

-- Admin ------------------------------------------------------------------------

select pg_temp.act_as(:admin);
select results_eq(
  $$ select id::text, card_path, selfie_path from public.pending_verifications()
     where id in ('eeeeeeee-0000-4000-8000-000000000001', 'ffffffff-0000-4000-8000-000000000001') $$,
  $$ values
     ('ffffffff-0000-4000-8000-000000000001', 'ffffffff-0000-4000-8000-000000000001/1/card.jpg', 'ffffffff-0000-4000-8000-000000000001/1/selfie.jpg'),
     ('eeeeeeee-0000-4000-8000-000000000001', 'eeeeeeee-0000-4000-8000-000000000001/3/card.jpg', 'eeeeeeee-0000-4000-8000-000000000001/3/selfie.jpg') $$,
  'longest waiting first, latest complete attempt only');
select is((select count(*)::int from public.pending_verifications() where id = :g), 0,
  'incomplete accounts are not listed');
select is((select count(*)::int from storage.objects where bucket_id = 'verification'), 7,
  'admin reads photos');
select throws_ok($$ select public.approve_verification('99999999-0000-4000-8000-000000000001') $$,
  '23514', 'not_pending', 'admin cannot approve an incomplete account');
select throws_ok($$ select public.approve_verification('00000000-0000-4000-8000-000000000001') $$,
  '23514', 'not_pending', 'admin cannot approve an approved account');
select lives_ok($$ select public.approve_verification('eeeeeeee-0000-4000-8000-000000000001') $$,
  'admin approves a pending account');
select throws_ok($$ select public.approve_verification('eeeeeeee-0000-4000-8000-000000000001') $$,
  '23514', 'not_pending', 'cannot approve twice');
reset role;
select results_eq(
  $$ select status::text, approved_by::text, approved_at = now() from public.profiles
     where id = 'eeeeeeee-0000-4000-8000-000000000001' $$,
  $$ values ('approved', '00000000-0000-4000-8000-000000000001', true) $$,
  'approval records the admin and time');

-- Approved by the admin's direct status update (still granted) is stamped too.
select pg_temp.act_as(:admin);
update public.profiles set status = 'approved' where id = :f;
select throws_ok($$ update public.profiles set approved_by = null $$, '42501', null,
  'admin cannot edit approved_by');
reset role;
select is((select approved_by::text from public.profiles where id = :f),
  '00000000-0000-4000-8000-000000000001', 'direct status update stamps approved_by too');

-- The record outlives the photos (D-07, #41).
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'verification' and name like 'eeeeeeee-%';
select results_eq(
  $$ select status::text, approved_by is not null, approved_at is not null from public.profiles
     where id = 'eeeeeeee-0000-4000-8000-000000000001' $$,
  $$ values ('approved', true, true) $$, 'approval record stays after the photos are deleted');

select * from finish();
rollback;
