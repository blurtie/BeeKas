begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

create function pg_temp.member(p_id uuid, p_email text) returns void
language sql as $$
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (p_id, p_email, json_build_object('full_name', p_email, 'campus', 'online'), 'authenticated', 'authenticated');
  update public.profiles set consent_at = now() where id = p_id;
$$;

-- Uploads p_files into <id>/<attempt>/, p_days ago.
create function pg_temp.upload(p_id uuid, p_attempt text, p_files text[], p_days int) returns void
language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, created_at)
  select 'verification', p_id || '/' || p_attempt || '/' || f, p_id::text, now() - make_interval(days => p_days)
  from unnest(p_files) f;
$$;

create function pg_temp.submit(p_id uuid) returns void
language plpgsql as $$
begin
  perform pg_temp.act_as(p_id);
  perform public.submit_for_review();
  reset role;
end;
$$;

\set f '''ffffffff-6500-4000-8000-000000000001'''
\set g '''aaaaaaaa-6500-4000-8000-000000000001'''
\set h '''bbbbbbbb-6500-4000-8000-000000000001'''
\set p '''cccccccc-6500-4000-8000-000000000001'''
\set r '''dddddddd-6500-4000-8000-000000000001'''
\set v '''eeeeeeee-6500-4000-8000-000000000001'''

-- F: card only, 28 days ago. G: card only, 30 days ago. H: both photos, no Kirim, 30 days.
select pg_temp.member(:f, 't65-f@binus.ac.id');
select pg_temp.upload(:f, '1', array['card.jpg'], 28);
select pg_temp.member(:g, 't65-g@binus.ac.id');
select pg_temp.upload(:g, '1', array['card.jpg'], 30);
select pg_temp.member(:h, 't65-h@binus.ac.id');
select pg_temp.upload(:h, '1', array['card.jpg', 'selfie.jpg'], 30);
-- P: submitted with photos uploaded 30 days ago, still pending.
select pg_temp.member(:p, 't65-p@binus.ac.id');
select pg_temp.upload(:p, '1', array['card.jpg', 'selfie.jpg'], 30);
select pg_temp.submit(:p);
-- R: uploaded 40 days ago, rejected 10 days ago. V: uploaded 40 days ago, approved 10 days ago.
select pg_temp.member(:r, 't65-r@binus.ac.id');
select pg_temp.upload(:r, '1', array['card.jpg', 'selfie.jpg'], 40);
select pg_temp.submit(:r);
select pg_temp.member(:v, 't65-v@binus.ac.id');
select pg_temp.upload(:v, '1', array['card.jpg', 'selfie.jpg'], 40);
select pg_temp.submit(:v);
select pg_temp.act_as('00000000-0000-4000-8000-000000000001');
select public.reject_verification(:r, array['card'], null);
select public.approve_verification(:v);
reset role;
update public.verification_rejections set rejected_at = now() - interval '10 days' where profile_id = :r;
update public.profiles set approved_at = now() - interval '10 days' where id = :v;
-- R then uploads a new card only, 9 days ago.
-- V had a card-only folder 40 days ago, before the approved attempt.
select pg_temp.upload(:v, '0', array['card.jpg'], 40);
select pg_temp.upload(:r, '2', array['card.jpg'], 9);

create temp table due as
  select profile_id::text, attempt, names, reason from public.expired_verification_photos()
  where profile_id in (:f, :g, :h, :p, :r, :v);

select results_eq(
  $$ select profile_id, attempt, reason from due order by profile_id $$,
  $$ values ('aaaaaaaa-6500-4000-8000-000000000001', '1', 'never_submitted'),
            ('bbbbbbbb-6500-4000-8000-000000000001', '1', 'never_submitted'),
            ('eeeeeeee-6500-4000-8000-000000000001', '0', 'never_submitted') $$,
  'only attempts never submitted and uploaded over 29 days ago are due');
select is((select names from due where profile_id = 'bbbbbbbb-6500-4000-8000-000000000001'),
  array['bbbbbbbb-6500-4000-8000-000000000001/1/card.jpg', 'bbbbbbbb-6500-4000-8000-000000000001/1/selfie.jpg'],
  'card and selfie without Kirim');
select ok(not exists (select 1 from due where profile_id = 'ffffffff-6500-4000-8000-000000000001'),
  'card only, 28 days: kept');
select ok(not exists (select 1 from due where profile_id = 'cccccccc-6500-4000-8000-000000000001'),
  'pending attempt: never touched, however old');
select ok(not exists (select 1 from due where profile_id = 'dddddddd-6500-4000-8000-000000000001'),
  'rejected attempt waits for its own 29 days; later card-only upload is too recent');
select ok(not exists (select 1 from due where profile_id = 'eeeeeeee-6500-4000-8000-000000000001' and attempt = '1'),
  'approved attempt waits for its own 29 days');
select ok(exists (select 1 from due where profile_id = 'eeeeeeee-6500-4000-8000-000000000001' and attempt = '0'),
  'unsent folder of an approved account counts from its upload, not approval');

select public.record_photo_deletion(:g, '1', 1, 'never_submitted');
select results_eq(
  $$ select attempt, objects, reason from public.photo_deletions where profile_id = 'aaaaaaaa-6500-4000-8000-000000000001' $$,
  $$ values ('1', 1, 'never_submitted') $$, 'deletion recorded with its reason');
select throws_ok($$ select public.record_photo_deletion('aaaaaaaa-6500-4000-8000-000000000001', '1', 1, 'other') $$,
  '23514', null, 'unknown reason rejected');

select * from finish();
rollback;
