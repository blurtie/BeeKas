#!/usr/bin/env bash
# #41: delete-expired-photos must reject calls without the right x-cron-secret (401) and
# delete nothing; the right secret deletes a due attempt through the Storage API and logs it.
# Local only: needs `supabase start` + seed.sql.
# Usage: bash supabase/tests/http/photo-retention-auth.sh
set -u
API=http://127.0.0.1:54321
URL=$API/functions/v1/delete-expired-photos
SECRET=local-photo-retention-cron-secret # seed.sql, local only
KEY=$(supabase status -o json 2>/dev/null | grep -o '"SERVICE_ROLE_KEY": *"[^"]*"' | cut -d'"' -f4)
ADMIN=00000000-0000-4000-8000-000000000001
q() { docker exec supabase_db_BeeKas psql -U postgres -tAqc "$1"; }
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: got '$2', want '$3'"; fail=1; fi; }

# A fake photo in the seed admin's folder (approved), with approved_at 31 days back.
OBJ=$ADMIN/t41-http/card.jpg
old=$(q "select approved_at from public.profiles where id = '$ADMIN'" | tr -d '\r')
cleanup() {
  curl -s -o /dev/null -X DELETE -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
    -d "{\"prefixes\":[\"$OBJ\"]}" "$API/storage/v1/object/verification"
  q "delete from public.photo_deletions where profile_id = '$ADMIN' and attempt = 't41-http'" >/dev/null
  q "update public.profiles set approved_at = nullif('$old', '')::timestamptz where id = '$ADMIN'" >/dev/null
}
trap cleanup EXIT
printf '\xff\xd8\xff\xd9' > "${TMPDIR:-/tmp}/t41.jpg"
curl -s -o /dev/null -X POST -H "Authorization: Bearer $KEY" -H 'Content-Type: image/jpeg' \
  --data-binary @"${TMPDIR:-/tmp}/t41.jpg" "$API/storage/v1/object/verification/$OBJ"
q "update public.profiles set approved_at = now() - interval '31 days' where id = '$ADMIN'" >/dev/null
exists() { curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $KEY" "$API/storage/v1/object/verification/$OBJ"; }
logged() { q "select count(*) from public.photo_deletions where profile_id = '$ADMIN' and attempt = 't41-http'" | tr -d '\r'; }

check "fake photo uploaded" "$(exists)" 200
check "no header -> 401" "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL")" 401
check "wrong header -> 401" "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'x-cron-secret: wrong' "$URL")" 401
check "empty header -> 401" "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'x-cron-secret;' "$URL")" 401
check "rejected calls delete nothing" "$(exists):$(logged)" "200:0"
check "right header -> 200" "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "x-cron-secret: $SECRET" "$URL")" 200
check "file gone from the bucket" "$(exists)" 400
check "deletion logged" "$(logged)" 1

exit $fail
