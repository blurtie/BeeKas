begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- Uploads card and selfie into <id>/<attempt>/ and submits, leaving the account pending.
create function pg_temp.submit(p_id uuid, p_attempt text) returns void
language plpgsql as $$
begin
  insert into storage.objects (bucket_id, name, owner_id, created_at)
  select 'verification', p_id || '/' || p_attempt || '/' || f, p_id::text, now() + make_interval(secs => p_attempt::int) -- newer attempt sorts last
  from unnest(array['card.jpg', 'selfie.jpg']) f;
  perform pg_temp.act_as(p_id);
  perform public.submit_for_review();
  reset role;
end;
$$;

create function pg_temp.member(p_id uuid, p_email text) returns void
language plpgsql as $$
begin
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (p_id, p_email, json_build_object('full_name', p_email, 'campus', 'online'), 'authenticated', 'authenticated');
  update public.profiles set consent_at = now() where id = p_id;
  perform pg_temp.submit(p_id, '1');
end;
$$;

-- Rejects the latest attempt, dated p_days ago, so the member can resubmit.
create function pg_temp.reject(p_id uuid, p_days int) returns void
language plpgsql as $$
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-000000000001');
  perform public.reject_verification(p_id, array['card'], null);
  reset role;
  update public.verification_rejections set rejected_at = now() - make_interval(days => p_days)
    where profile_id = p_id and rejected_at = now();
  update public.profiles set last_rejected_at = now() - make_interval(days => p_days) where id = p_id;
end;
$$;

\set a '''aaaaaaaa-4100-4000-8000-000000000001'''
\set b '''bbbbbbbb-4100-4000-8000-000000000001'''
\set c '''cccccccc-4100-4000-8000-000000000001'''
\set d '''dddddddd-4100-4000-8000-000000000001'''
\set e '''eeeeeeee-4100-4000-8000-000000000001'''

-- A approved 31 days ago, B 29 days ago, C still pending.
select pg_temp.member(:a, 't41-a@binus.ac.id');
select pg_temp.member(:b, 't41-b@binus.ac.id');
select pg_temp.member(:c, 't41-c@binus.ac.id');
select pg_temp.act_as('00000000-0000-4000-8000-000000000001');
select public.approve_verification(:a);
select public.approve_verification(:b);
reset role;
update public.profiles set approved_at = now() - interval '31 days' where id = :a;
update public.profiles set approved_at = now() - interval '29 days' where id = :b;

-- D: attempt 1 rejected 31 days ago, attempt 2 pending.
select pg_temp.member(:d, 't41-d@binus.ac.id');
select pg_temp.reject(:d, 31);
select pg_temp.submit(:d, '2');
-- E: attempt 1 rejected 31 days ago, attempt 2 rejected 29 days ago.
select pg_temp.member(:e, 't41-e@binus.ac.id');
select pg_temp.reject(:e, 31);
select pg_temp.submit(:e, '2');
select pg_temp.reject(:e, 29);

create temp table due as
  select profile_id::text, attempt, names from public.expired_verification_photos()
  where profile_id in (:a, :b, :c, :d, :e);

select results_eq(
  $$ select profile_id, attempt from due order by profile_id $$,
  $$ values ('aaaaaaaa-4100-4000-8000-000000000001', '1'),
            ('dddddddd-4100-4000-8000-000000000001', '1'),
            ('eeeeeeee-4100-4000-8000-000000000001', '1') $$,
  'only attempts decided over 29 days ago are due');
select is((select names from due where profile_id = 'aaaaaaaa-4100-4000-8000-000000000001'),
  array['aaaaaaaa-4100-4000-8000-000000000001/1/card.jpg', 'aaaaaaaa-4100-4000-8000-000000000001/1/selfie.jpg'],
  'both card and selfie of the attempt');
select ok(not exists (select 1 from due where profile_id = 'bbbbbbbb-4100-4000-8000-000000000001'),
  'approved 29 days ago: kept');
select ok(not exists (select 1 from due where profile_id = 'cccccccc-4100-4000-8000-000000000001'),
  'pending: never touched');
select ok(not exists (select 1 from due where profile_id = 'dddddddd-4100-4000-8000-000000000001' and attempt = '2'),
  'resubmitted attempt still pending: kept');
select ok(not exists (select 1 from due where profile_id = 'eeeeeeee-4100-4000-8000-000000000001' and attempt = '2'),
  'each attempt counts from its own rejection');

-- Recording and L15 ----------------------------------------------------------------

select public.record_photo_deletion(:d, '1', 2);
select results_eq(
  $$ select attempt, objects, deleted_at = now() from public.photo_deletions where profile_id = 'dddddddd-4100-4000-8000-000000000001' $$,
  $$ values ('1', 2, true) $$, 'deletion recorded: attempt, count, time');

select pg_temp.act_as('00000000-0000-4000-8000-000000000001');
select results_eq(
  $$ select photos_deleted, card_path is not null from public.pending_verifications()
     where id = 'dddddddd-4100-4000-8000-000000000001' $$,
  $$ values (true, true) $$, 'L15 knows earlier photos were deleted; the pending attempt stays');
reset role;

-- Access -------------------------------------------------------------------------

select pg_temp.act_as(:d);
select throws_ok($$ select * from public.photo_deletions $$, '42501', null, 'member cannot read the log');
select throws_ok($$ select * from public.expired_verification_photos() $$, '42501', null,
  'member cannot list due photos');
select throws_ok($$ select public.photo_retention_cron_secret() $$, '42501', null, 'member cannot read the secret');
reset role;

select * from finish();
rollback;
