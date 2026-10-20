begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

create function pg_temp.sign_up(p_id uuid, p_email text, p_name text) returns void
language sql as $$
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (p_id, p_email, json_build_object('full_name', p_name, 'campus', 'online'), 'authenticated', 'authenticated');
$$;

create function pg_temp.act_as(p_id uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- Signs up, uploads one attempt and submits, leaving the account pending.
create function pg_temp.pending(p_id uuid, p_email text, p_name text, p_phone text) returns void
language plpgsql as $$
begin
  perform pg_temp.sign_up(p_id, p_email, p_name);
  update public.profiles set phone = p_phone, consent_at = now() where id = p_id;
  insert into storage.objects (bucket_id, name, owner_id, created_at)
  select 'verification', p_id || '/1/' || f, p_id::text, now() from unnest(array['card.jpg', 'selfie.jpg']) f;
  perform pg_temp.act_as(p_id);
  perform public.submit_for_review();
  reset role;
end;
$$;

\set a '''aaaaaaaa-3300-4000-8000-000000000001'''
\set b '''bbbbbbbb-3300-4000-8000-000000000001'''
\set admin '''00000000-0000-4000-8000-000000000001'''

select pg_temp.pending(:a, 't33-a@binus.ac.id', 'Ayu', '+6281233000001');
select pg_temp.pending(:b, 't33-b@binus.ac.id', E'Budi\r\nBcc: x@evil.test', '+6281233000002');

-- Queued in the decision's transaction ----------------------------------------

select pg_temp.act_as(:admin);
select public.approve_verification(:a);
select public.reject_verification(:b, array['card', 'other'], E'Kartu\r\nterpotong');
reset role;

select results_eq(
  $$ select profile_id::text, kind, status, attempts from public.decision_emails order by id $$,
  $$ values ('aaaaaaaa-3300-4000-8000-000000000001', 'approved', 'pending', 0),
            ('bbbbbbbb-3300-4000-8000-000000000001', 'rejected', 'pending', 0) $$,
  'approve and reject each queue one pending email');
select is((select rejection_id from public.decision_emails where kind = 'rejected'),
  (select id from public.verification_rejections where profile_id = :b), 'rejected email points at its rejection');

-- Content ----------------------------------------------------------------------

create temp table m as
  select d.kind, e.* from public.decision_emails d cross join lateral public.decision_email(d.id) e;

select is((select recipient from m where kind = 'approved'), 't33-a@binus.ac.id', 'sent to the member');
select is((select subject from m where kind = 'approved'), 'Akun BeeKas disetujui / BeeKas account approved',
  'approved subject, no name');
select is((select subject from m where kind = 'rejected'),
  'Verifikasi BeeKas belum disetujui / BeeKas verification not approved', 'rejected subject, no name');
select ok((select body like 'Halo Ayu,%Hi Ayu,%' from m where kind = 'approved'), 'Indonesian first, then English');
select ok((select body !~ '\r' and body !~ E'\nBcc:' from m where kind = 'rejected'), 'no CR/LF from the name or note');
select ok((select body like '%Halo Budi Bcc: x@evil.test,%' from m where kind = 'rejected'), 'name kept on one line');
select ok((select body like E'%- Foto kartu tidak jelas atau tidak lengkap\n- Lainnya\nCatatan admin: Kartu terpotong\n%'
  from m where kind = 'rejected'), 'Indonesian reasons and note');
select ok((select body like E'%- The card photo is unclear or incomplete\n- Other\nAdmin note: Kartu terpotong\n%'
  from m where kind = 'rejected'), 'English reasons and note');
select ok((select body like '%mengirim ulang%resubmit%' from m where kind = 'rejected'), 'asks to resubmit in the app');
select ok((select bool_and(body not like '%+62812%' and body not like '%verification%/1/%') from m),
  'no phone or photo path');

-- Access -----------------------------------------------------------------------

select pg_temp.act_as(:a);
select throws_ok($$ select * from public.decision_emails $$, '42501', null, 'member cannot read the outbox');
select throws_ok($$ select * from public.claim_decision_emails() $$, '42501', null, 'member cannot claim');
select throws_ok($$ select * from public.decision_email(1) $$, '42501', null, 'member cannot render an email');
select throws_ok($$ select public.decision_emails_cron_secret() $$, '42501', null, 'member cannot read the cron secret');
reset role;
set local role anon;
select throws_ok($$ select public.decision_emails_cron_secret() $$, '42501', null, 'anon cannot read the cron secret');
reset role;
set local role service_role;
select isnt(public.decision_emails_cron_secret(), null, 'the function (service_role) reads the cron secret');
reset role;

-- Claiming ---------------------------------------------------------------------

set local role service_role;
select is((select count(*)::int from public.claim_decision_emails()), 2, 'claim takes both pending rows');
select is((select count(*)::int from public.claim_decision_emails()), 0, 'a second run takes nothing');
reset role;
select ok((select bool_and(status = 'sending' and claimed_at is not null) from public.decision_emails),
  'claimed rows are sending with claimed_at');

-- A run that died 11 minutes ago leaves a stuck row; it is claimed again.
update public.decision_emails set claimed_at = now() - interval '11 minutes' where kind = 'approved';
set local role service_role;
select is((select array_agg(recipient) from public.claim_decision_emails()), array['t33-a@binus.ac.id'],
  'a sending row older than 10 minutes is claimed again');
reset role;

-- Finishing --------------------------------------------------------------------

set local role service_role;
select public.finish_decision_email(id, null) from public.decision_emails where kind = 'approved';
select public.finish_decision_email(id, 'smtp down') from public.decision_emails where kind = 'rejected';
reset role;
select results_eq(
  $$ select kind, status, attempts, last_error, sent_at is not null from public.decision_emails order by id $$,
  $$ values ('approved', 'sent', 0, null::text, true), ('rejected', 'pending', 1, 'smtp down', false) $$,
  'success marks sent; a failure counts and goes back to pending');

set local role service_role;
select public.finish_decision_email(id, null) from public.decision_emails where kind = 'approved';
reset role;
select is((select status from public.decision_emails where kind = 'approved'), 'sent',
  'finishing a row that is not sending changes nothing');

-- Four more failures: failed for good, and no longer claimed.
do $$
begin
  for i in 1..4 loop
    perform public.claim_decision_emails();
    perform public.finish_decision_email(id, 'smtp down') from public.decision_emails where kind = 'rejected';
  end loop;
end;
$$;
select results_eq($$ select status, attempts from public.decision_emails where kind = 'rejected' $$,
  $$ values ('failed', 5) $$, 'the fifth failure marks failed');
set local role service_role;
select is((select count(*)::int from public.claim_decision_emails()), 0, 'failed rows are not claimed');
reset role;

-- Requeue (docs/cloud-checklist.md) brings it back.
update public.decision_emails set status = 'pending', attempts = 0, last_error = null where status = 'failed';
set local role service_role;
select is((select count(*)::int from public.claim_decision_emails()), 1, 'a requeued row is claimed again');
reset role;

select * from finish();
rollback;
