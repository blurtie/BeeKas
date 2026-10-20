-- Decision emails, #33 (PRD L14-L15, D-08). The outbox row is written in the same transaction
-- as the decision, so a closed or crashed admin app cannot lose the email. The Edge Function
-- send-decision-emails drains it every minute (pg_cron + pg_net). Delivery is at-least-once:
-- a send that succeeds but is not marked sent (crash, timeout) is retried.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create table public.decision_emails (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles on delete cascade,
  kind text not null check (kind in ('approved', 'rejected')),
  rejection_id bigint references public.verification_rejections on delete cascade,
  -- pending -> sending -> sent; a real send failure goes back to pending until the 5th, then failed.
  status text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed')),
  attempts int not null default 0,
  last_error text,
  claimed_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  check ((kind = 'rejected') = (rejection_id is not null))
);
create index on public.decision_emails (status, created_at);

-- Server-only: no client role can read or write it.
alter table public.decision_emails enable row level security;
revoke all on public.decision_emails from anon, authenticated;

create function public.queue_approved_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.decision_emails (profile_id, kind) values (new.id, 'approved');
  return new;
end;
$$;
create trigger profiles_queue_approved_email
  after update of status on public.profiles
  for each row when (new.status = 'approved' and old.status is distinct from 'approved')
  execute function public.queue_approved_email();

create function public.queue_rejected_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.decision_emails (profile_id, kind, rejection_id)
  values (new.profile_id, 'rejected', new.id);
  return new;
end;
$$;
create trigger rejections_queue_rejected_email
  after insert on public.verification_rejections
  for each row execute function public.queue_rejected_email();

-- Reason texts, same as rejectReason_* in lib/config/copy.dart (test/config/reason_sql_test.dart).
create function public.reason_text(p_code text, p_lang text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_lang
    when 'id' then case p_code
      when 'card' then 'Foto kartu tidak jelas atau tidak lengkap'
      when 'selfie' then 'Selfie tidak cocok dengan foto di kartu'
      when 'data' then 'Data diri tidak sesuai dengan kartu'
      when 'other' then 'Lainnya'
    end
    else case p_code
      when 'card' then 'The card photo is unclear or incomplete'
      when 'selfie' then 'The selfie doesn''t match the card photo'
      when 'data' then 'Your details don''t match the card'
      when 'other' then 'Other'
    end
  end;
$$;

-- Plain text, Indonesian first, then English. Only the name, reasons and admin note go in;
-- no photos, NIM or phone (D-07). The name stays out of the subject. CR/LF are stripped from
-- every inserted value so nothing can add headers or fake lines.
create function public.decision_email(p_id bigint)
returns table (recipient text, subject text, body text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e public.decision_emails;
  p public.profiles;
  r public.verification_rejections;
  name text;
  note text;
  reasons_id text;
  reasons_en text;
begin
  select * into e from public.decision_emails where id = p_id;
  select * into p from public.profiles where id = e.profile_id;
  name := regexp_replace(coalesce(p.full_name, ''), '[\r\n]+', ' ', 'g');
  recipient := regexp_replace(p.email, '[\r\n]', '', 'g');
  if e.kind = 'approved' then
    subject := 'Akun BeeKas disetujui / BeeKas account approved';
    body := 'Halo ' || name || E',\n\n'
      || E'Verifikasi akun BeeKas kamu sudah disetujui. Buka aplikasi BeeKas untuk mulai.\n\n'
      || E'---\n\n'
      || 'Hi ' || name || E',\n\n'
      || E'Your BeeKas account verification has been approved. Open the BeeKas app to get started.\n';
    return next;
    return;
  end if;
  select * into r from public.verification_rejections where id = e.rejection_id;
  note := regexp_replace(coalesce(r.note, ''), '[\r\n]+', ' ', 'g');
  select string_agg('- ' || public.reason_text(c, 'id'), E'\n' order by o),
         string_agg('- ' || public.reason_text(c, 'en'), E'\n' order by o)
    into reasons_id, reasons_en
  from unnest(r.reasons) with ordinality as u(c, o);
  subject := 'Verifikasi BeeKas belum disetujui / BeeKas verification not approved';
  body := 'Halo ' || name || E',\n\n'
    || E'Verifikasi akun BeeKas kamu belum disetujui karena alasan berikut:\n'
    || reasons_id || E'\n'
    || case when note <> '' then 'Catatan admin: ' || note || E'\n' else '' end
    || E'\nBuka aplikasi BeeKas untuk mengirim ulang foto kartu dan selfie.\n\n'
    || E'---\n\n'
    || 'Hi ' || name || E',\n\n'
    || E'Your BeeKas account verification was not approved for these reasons:\n'
    || reasons_en || E'\n'
    || case when note <> '' then 'Admin note: ' || note || E'\n' else '' end
    || E'\nOpen the BeeKas app to resubmit your card photo and selfie.\n';
  return next;
end;
$$;

-- Claims up to p_limit rows for one run. SKIP LOCKED keeps overlapping runs from taking the
-- same row; a row stuck in 'sending' for over 10 minutes (crashed run) can be claimed again.
create function public.claim_decision_emails(p_limit int default 20)
returns table (id bigint, recipient text, subject text, body text)
language sql
security definer
set search_path = ''
as $$
  with claimed as (
    update public.decision_emails d
    set status = 'sending', claimed_at = now()
    where d.id in (
      select c.id from public.decision_emails c
      where c.status = 'pending'
        or (c.status = 'sending' and c.claimed_at < now() - interval '10 minutes')
      order by c.created_at
      limit p_limit
      for update skip locked
    )
    returning d.id
  )
  select c.id, m.recipient, m.subject, m.body
  from claimed c cross join lateral public.decision_email(c.id) m;
$$;

-- p_error null: sent. Otherwise a real send failure: counted, retried, failed after the 5th.
create function public.finish_decision_email(p_id bigint, p_error text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.decision_emails
  set status = case when p_error is null then 'sent'
                    when attempts + 1 >= 5 then 'failed' else 'pending' end,
      attempts = attempts + (p_error is not null)::int,
      last_error = coalesce(p_error, last_error),
      sent_at = case when p_error is null then now() end
  where id = p_id and status = 'sending';
$$;

revoke execute on function public.queue_approved_email(), public.queue_rejected_email(),
  public.reason_text(text, text), public.decision_email(bigint),
  public.claim_decision_emails(int), public.finish_decision_email(bigint, text)
  from public, anon, authenticated;
grant execute on function public.claim_decision_emails(int), public.finish_decision_email(bigint, text)
  to service_role;

-- The shared secret pg_cron sends and the function checks (it runs with verify_jwt = false).
-- Lives in Vault: seed.sql locally, docs/cloud-checklist.md for cloud. Only service_role reads it.
create function public.decision_emails_cron_secret()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'decision_emails_cron_secret';
$$;
revoke execute on function public.decision_emails_cron_secret() from public, anon, authenticated;
grant execute on function public.decision_emails_cron_secret() to service_role;

-- Every minute, poke the function. URL and secret live in Vault per environment; without
-- them nothing is called and rows wait as pending.
select cron.schedule('send-decision-emails', '* * * * *', $$
  select net.http_post(
    url := u.decrypted_secret,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', s.decrypted_secret))
  from vault.decrypted_secrets u, vault.decrypted_secrets s
  where u.name = 'decision_emails_url' and s.name = 'decision_emails_cron_secret'
$$);
