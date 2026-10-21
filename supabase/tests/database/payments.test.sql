begin;
create extension if not exists pgtap with schema extensions;
select plan(46);

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- A approved; B approved; P pending; F approved and frozen; X, Y admins.
\set a '''84848484-0000-4000-8000-000000000001'''
\set b '''84848484-0000-4000-8000-000000000002'''
\set p '''84848484-0000-4000-8000-000000000003'''
\set f '''84848484-0000-4000-8000-000000000004'''
\set x '''84848484-0000-4000-8000-000000000005'''
\set y '''84848484-0000-4000-8000-000000000006'''

insert into auth.users (id, email, raw_user_meta_data, aud, role)
select ('84848484-0000-4000-8000-00000000000' || n)::uuid, 't84-' || n || '@binus.ac.id',
  json_build_object('full_name', 'T84 ' || n, 'campus', 'bandung'), 'authenticated', 'authenticated'
from generate_series(1, 6) n;
update public.profiles set phone = '+62812840000' || right(id::text, 2)
  where id::text like '84848484-%';
update public.profiles set status = 'pending' where id::text like '84848484-%';
update public.profiles set status = 'approved' where id in (:a, :b, :f, :x, :y);
update public.profiles set role = 'admin' where id in (:x, :y);
insert into public.freezes (member_id, reason, proposed_by, approved_by, approved_at)
values (:f, 'penipuan', :x, :y, now());

create function pg_temp.upload(p_name text) returns void
language sql as $$
  insert into storage.objects (bucket_id, name, owner_id)
  values ('payment-proofs', p_name, auth.uid()::text);
$$;

-- Proof bucket (K-10) ------------------------------------------------------------------

select is((select public from storage.buckets where id = 'payment-proofs'), false,
  'the proof bucket is private');

select pg_temp.act_as(:a);
select lives_ok($$ select pg_temp.upload('84848484-0000-4000-8000-000000000001/p1.jpg') $$,
  'member uploads a proof into their own folder');
select throws_ok($$ select pg_temp.upload('84848484-0000-4000-8000-000000000002/p1.jpg') $$,
  '42501', null, 'members cannot upload into another folder');
select is((select count(*)::int from storage.objects where bucket_id = 'payment-proofs'), 1,
  'members read their own proof while no payment records it');
reset role;
select pg_temp.act_as(:b);
select is((select count(*)::int from storage.objects where bucket_id = 'payment-proofs'), 0,
  'members cannot read another member''s proof');
reset role;

select pg_temp.act_as(:f);
select throws_ok($$ select pg_temp.upload('84848484-0000-4000-8000-000000000004/p1.jpg') $$,
  '42501', null, 'frozen accounts cannot upload a proof');
reset role;

set local role anon;
select is((select count(*)::int from storage.objects where bucket_id = 'payment-proofs'), 0,
  'guests cannot read the proof bucket');
reset role;

select pg_temp.act_as(:x);
select is((select count(*)::int from storage.objects where bucket_id = 'payment-proofs'
  and name like '84848484-%'), 1, 'admins read proofs');
reset role;

select is((select public from storage.buckets where id = 'payment-qris'), true,
  'the QRIS image is public (K-09)');

-- submit_payment -----------------------------------------------------------------------

select pg_temp.act_as(:a);
select lives_ok($$ select public.submit_payment('package', '84848484-0000-4000-8000-000000000001/p1.jpg') $$,
  'member submits a package payment');
select is((select row(kind, amount, status)::text from public.payments
  where member_id = '84848484-0000-4000-8000-000000000001'), '(package,15000,pending)',
  'pending, at the package price');
select throws_ok($$ select public.submit_payment('package', '84848484-0000-4000-8000-000000000002/p1.jpg') $$,
  '42501', 'not_own_proof', 'the proof must be in the member''s own folder');
select throws_ok($$ select public.submit_payment('package', '84848484-0000-4000-8000-000000000001/../x.jpg') $$,
  '42501', 'not_own_proof', 'no path tricks');
select throws_ok($$ select public.submit_payment('boost', '84848484-0000-4000-8000-000000000001/p2.jpg') $$,
  '0A000', 'not_supported', 'Boost waits for K22');
select throws_ok($$ insert into public.payments (member_id, kind, amount, proof_path)
  values ('84848484-0000-4000-8000-000000000001', 'package', 15000, 'x') $$,
  '42501', null, 'members cannot insert payments directly');
reset role;

select pg_temp.act_as(:p);
select throws_ok($$ select public.submit_payment('package', '84848484-0000-4000-8000-000000000003/p1.jpg') $$,
  '42501', 'not_allowed', 'pending accounts cannot pay');
reset role;

select pg_temp.act_as(:b);
select pg_temp.upload('84848484-0000-4000-8000-000000000002/p1.jpg');
select lives_ok($$ select public.submit_payment('package', '84848484-0000-4000-8000-000000000002/p1.jpg') $$,
  'B submits too');
select throws_ok($$ select public.submit_payment('package', '84848484-0000-4000-8000-000000000002/p2.jpg') $$,
  '23514', 'payment_pending', 'one pending payment per member (D-43)');
select is((select count(*)::int from public.payments where member_id::text like '84848484-%'), 1,
  'members read only their own payments');
reset role;

select throws_ok($$ insert into public.payments (member_id, kind, amount, proof_path)
  values ('84848484-0000-4000-8000-000000000001', 'package', 1000, 'x') $$,
  '23514', null, 'the amount follows the kind');

-- D-43 backstop: even a direct insert cannot add a second pending payment.
select throws_ok($$ insert into public.payments (member_id, kind, amount, proof_path)
  values ('84848484-0000-4000-8000-000000000002', 'package', 15000, 'x') $$,
  '23505', null, 'the database allows one pending payment per member');

-- Delete policy: the app removes a proof whose payment was not recorded -----------------

-- The Storage API sets this before its own delete.
set local storage.allow_delete_query = 'true';

select pg_temp.act_as(:a);
select pg_temp.upload('84848484-0000-4000-8000-000000000001/p9.jpg');
select is((select array_agg(name) from storage.objects where bucket_id = 'payment-proofs'),
  array['84848484-0000-4000-8000-000000000001/p9.jpg'],
  'a recorded proof is no longer readable by its member');
reset role;

select pg_temp.act_as(:b);
select is(public.is_payment_proof('84848484-0000-4000-8000-000000000001/nope.jpg'), true,
  'is_payment_proof says nothing about another member''s folder');
delete from storage.objects where bucket_id = 'payment-proofs'
  and name = '84848484-0000-4000-8000-000000000001/p9.jpg';
reset role;
select is((select count(*)::int from storage.objects
    where name = '84848484-0000-4000-8000-000000000001/p9.jpg'), 1,
  'another member cannot delete the proof');

select pg_temp.act_as(:a);
delete from storage.objects where bucket_id = 'payment-proofs'
  and name in ('84848484-0000-4000-8000-000000000001/p1.jpg',
               '84848484-0000-4000-8000-000000000001/p9.jpg');
reset role;
select is((select count(*)::int from storage.objects
    where name = '84848484-0000-4000-8000-000000000001/p1.jpg'), 1,
  'a proof a payment records cannot be deleted');
select is((select count(*)::int from storage.objects
    where name = '84848484-0000-4000-8000-000000000001/p9.jpg'), 0,
  'the member deletes their unrecorded proof');

\set pa '(select id from public.payments where member_id = ''84848484-0000-4000-8000-000000000001'')'
\set pb '(select id from public.payments where member_id = ''84848484-0000-4000-8000-000000000002'')'

-- admin_pending_payments: K18 list, oldest first ------------------------------------

-- B waited longer than A.
update public.payments set created_at = now() - interval '1 hour'
  where member_id = '84848484-0000-4000-8000-000000000002';

select pg_temp.act_as(:a);
select throws_ok('select * from public.admin_pending_payments()',
  '42501', 'not_admin', 'members cannot list pending payments');
reset role;

select pg_temp.act_as(:x);
select is((select array_agg(member_name order by ord) from (
    select member_name, row_number() over () as ord from public.admin_pending_payments()) l
  where member_name like 'T84 %'), array['T84 2', 'T84 1'],
  'the longest waiting comes first');
select is((select row(member_email, kind, amount, proof_path)::text from public.admin_pending_payments()
  where member_name = 'T84 1'),
  '(t84-1@binus.ac.id,package,15000,84848484-0000-4000-8000-000000000001/p1.jpg)',
  'with the member, the kind, the amount and the proof');
reset role;

-- confirm_payment / reject_payment: admins only ----------------------------------------

select pg_temp.act_as(:a);
select throws_ok(format('select public.confirm_payment(%L, 15000)', :pa),
  '42501', 'not_admin', 'members cannot confirm');
select throws_ok(format('select public.reject_payment(%L, %L)', :pb, 'no'),
  '42501', 'not_admin', 'members cannot reject');
reset role;

select pg_temp.act_as(:x);
select throws_ok(format('select public.confirm_payment(%L, 0)', :pa),
  '23514', 'invalid_amount', 'the amount received must be above 0');
select lives_ok(format('select public.confirm_payment(%L, 15000)', :pa), 'admin confirms');
select throws_ok(format('select public.confirm_payment(%L, 15000)', :pa),
  '23514', 'not_pending', 'confirming twice fails');
select throws_ok(format('select public.reject_payment(%L, %L)', :pa, 'late'),
  '23514', 'not_pending', 'a confirmed payment cannot be rejected');
reset role;

select is((select balance from public.quota_balances where member_id = :a), 4,
  'confirming adds 3 to the balance once');
select is((select count(*)::int from public.quota_ledger where member_id = :a and reason = 'purchase'), 1,
  'one purchase in the ledger');
select is((select row(status, received_amount, decided_by = :x, decided_at is not null)::text
  from public.payments where member_id = :a), '(confirmed,15000,t,t)',
  'the amount, the admin and the time are recorded');
select is((select payment_id = (select id from public.payments where member_id = :a)
  from public.quota_ledger where member_id = :a and reason = 'purchase'), true,
  'the ledger points at the payment');

select pg_temp.act_as(:y);
select throws_ok(format('select public.reject_payment(%L, %L)', :pb, '  '),
  '23514', 'reason_missing', 'rejecting needs a reason');
select lives_ok(format('select public.reject_payment(%L, %L)', :pb, 'Bukti buram'), 'admin rejects');
reset role;

select is((select row(status, reason, decided_by = :y)::text from public.payments where member_id = :b),
  '(rejected,"Bukti buram",t)', 'the reason and the admin are recorded');
select is((select balance from public.quota_balances where member_id = :b), 1,
  'rejecting adds nothing');

select pg_temp.act_as(:b);
select lives_ok($$ select public.submit_payment('package', '84848484-0000-4000-8000-000000000002/p3.jpg') $$,
  'after a rejection the member can upload again');
reset role;

-- Proof retention (K-10) ---------------------------------------------------------------

select is((select array_agg(n order by n) from public.expired_payment_proofs() n where n like '84848484-%'),
  array['84848484-0000-4000-8000-000000000001/p1.jpg', '84848484-0000-4000-8000-000000000002/p1.jpg'],
  'decided proofs are due for deletion');

-- C: undecided for 30 days.
insert into storage.objects (bucket_id, name, owner_id, created_at)
values ('payment-proofs', '84848484-0000-4000-8000-000000000003/old.jpg', null, now() - interval '30 days'),
       ('payment-proofs', '84848484-0000-4000-8000-000000000003/new.jpg', null, now());
select is((select count(*)::int from public.expired_payment_proofs() n
  where n like '84848484-0000-4000-8000-000000000003/%'), 1,
  'an undecided proof is due after 29 days, not before');

select * from finish();
rollback;
