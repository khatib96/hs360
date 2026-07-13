#!/usr/bin/env bash
# Phase 7 M3: parallel reminder scheduler advisory-lock smoke test.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
test_passed=0

cleanup() {
  local exit_code=$?
  rm -rf "$tmpdir"

  if [[ "$test_passed" -eq 1 ]]; then
    exit 0
  fi

  exit "$exit_code"
}
trap cleanup EXIT

batch_sql="
begin;
set local role postgres;
select public.run_scheduled_calendar_reminders(100);
commit;
"

printf 'P7M3 concurrency: parallel reminder scheduler advisory lock\n'

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$batch_sql" \
  >"$tmpdir/out1" 2>&1 &
pid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$batch_sql" \
  >"$tmpdir/out2" 2>&1 &
pid2=$!

wait "$pid1" || ec1=$?
ec1=${ec1:-0}
wait "$pid2" || ec2=$?
ec2=${ec2:-0}

if [[ "$ec1" -ne 0 && "$ec2" -ne 0 ]]; then
  printf 'Both scheduler sessions failed:\n%s\n%s\n' "$(cat "$tmpdir/out1")" "$(cat "$tmpdir/out2")" >&2
  exit 1
fi

completed=0
skipped=0
for f in "$tmpdir/out1" "$tmpdir/out2"; do
  if grep -q 'run_id' "$f"; then
    completed=$((completed + 1))
  fi
  if grep -q 'skipped_duplicate' "$f"; then
    skipped=$((skipped + 1))
  fi
done

if [[ "$completed" -lt 1 || "$skipped" -lt 1 ]]; then
  printf 'Expected one completed run and one skipped_duplicate; completed=%s skipped=%s\n' \
    "$completed" "$skipped" >&2
  cat "$tmpdir/out1" >&2
  cat "$tmpdir/out2" >&2
  exit 1
fi

test_passed=1
printf 'P7M3 reminder scheduler concurrency test passed.\n'
