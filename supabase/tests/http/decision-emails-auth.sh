#!/usr/bin/env bash
# #33: send-decision-emails must reject calls without the right x-cron-secret (401) and claim
# nothing; the right secret sends. Local only: needs `supabase start` + seed.sql, EMAIL_API=mailpit.
# Usage: bash supabase/tests/http/decision-emails-auth.sh
set -u
URL=http://127.0.0.1:54321/functions/v1/send-decision-emails
SECRET=local-decision-emails-cron-secret # seed.sql, local only
q() { docker exec supabase_db_BeeKas psql -U postgres -tAqc "$1"; }
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: got '$2', want '$3'"; fail=1; fi; }

# Pause pg_cron so it cannot drain the test row; always resume it.
q "select cron.alter_job(jobid, active := false) from cron.job where jobname = 'send-decision-emails'" >/dev/null
row=""
cleanup() {
  [ -n "$row" ] && q "delete from public.decision_emails where id = $row" >/dev/null
  q "select cron.alter_job(jobid, active := true) from cron.job where jobname = 'send-decision-emails'" >/dev/null
}
trap cleanup EXIT

# A pending email to the seed admin.
row=$(q "insert into public.decision_emails (profile_id, kind) values ('00000000-0000-4000-8000-000000000001', 'approved') returning id" | head -1 | tr -d '\r')
state() { q "select status || ':' || (claimed_at is null) from public.decision_emails where id = $row" | tr -d '\r'; }

check "no header -> 401" "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL")" 401
check "wrong header -> 401" "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'x-cron-secret: wrong' "$URL")" 401
check "empty header -> 401" "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'x-cron-secret;' "$URL")" 401
check "rejected calls claim nothing" "$(state)" "pending:true"
check "right header -> 200" "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "x-cron-secret: $SECRET" "$URL")" 200
check "right header sends the row" "$(state)" "sent:false"

exit $fail
