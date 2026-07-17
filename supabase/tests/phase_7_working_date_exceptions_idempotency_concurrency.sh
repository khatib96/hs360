#!/usr/bin/env bash
# Phase 7 M7B: idempotency concurrency for create/update/cancel_working_date_exception.
#   1) Parallel same-key same-payload create -> exactly one row, identical results.
#   2) Parallel same-key same-patch update -> version bumps exactly once.
#   3) Replaying a now-stale update key (after a later unrelated update moved
#      the version forward) still returns the original stored result.
#   4) Replaying a cancel key after the row is already cancelled replays.
#   5) Reusing that cancel key with a different reason raises
#      idempotency_payload_mismatch.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

owner_sub='00000000-0000-0000-0000-000000000201'
marker="P7BID-$(date +%s)-$$"
tmpdir="$(mktemp -d)"
test_passed=0
exception_id=''

pid_hex="$(printf '%012x' "$$")"
create_key="00000000-a001-4000-8000-${pid_hex}"
update_key1="00000000-a002-4000-8000-${pid_hex}"
update_key2="00000000-a003-4000-8000-${pid_hex}"
cancel_key="00000000-a004-4000-8000-${pid_hex}"

psql_exec() {
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

run_sql() {
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$1"
}

cleanup_fixtures() {
  psql_exec -v marker="$marker" <<'SQL' || true
begin;
set local role postgres;
delete from public.working_date_exception_operations op
using public.tenant_working_date_exceptions twde
where op.result_exception_id = twde.id
  and twde.title_en like :'marker' || '%';
delete from public.tenant_working_date_exceptions
where title_en like :'marker' || '%';
commit;
SQL
}

cleanup() {
  local exit_code=$?
  cleanup_fixtures || true
  rm -rf "$tmpdir"
  if [[ "$test_passed" -eq 1 ]]; then
    exit 0
  fi
  exit "$exit_code"
}
trap cleanup EXIT

printf 'P7B idempotency concurrency: create/update/cancel replay (marker=%s)\n' "$marker"

base_offset=$(( ( $(date +%s) % 500 ) + 3600 ))

create_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.create_working_date_exception(
  jsonb_build_object(
    'kind', 'official_holiday',
    'start_date', to_char(current_date + ${base_offset}, 'YYYY-MM-DD'),
    'end_date', to_char(current_date + ${base_offset}, 'YYYY-MM-DD'),
    'title_en', '${marker} Create'
  ),
  '${create_key}'::uuid
);
commit;
"

# Step 1: parallel same-key same-payload create -> exactly one row.
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$create_sql" \
  >"$tmpdir/create1" 2>&1 &
pid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$create_sql" \
  >"$tmpdir/create2" 2>&1 &
pid2=$!

wait "$pid1" || ec1=$?
ec1=${ec1:-0}
wait "$pid2" || ec2=$?
ec2=${ec2:-0}

if [[ "$ec1" -ne 0 || "$ec2" -ne 0 ]]; then
  printf 'Parallel create failed: ec1=%s ec2=%s\n' "$ec1" "$ec2" >&2
  cat "$tmpdir/create1" >&2
  cat "$tmpdir/create2" >&2
  exit 1
fi

row_count="$(
  psql_exec -t -A -c "
    select count(*) from public.tenant_working_date_exceptions
    where title_en like '${marker}%';
  "
)"
if [[ "$row_count" != "1" ]]; then
  printf 'Idempotent create concurrency failed: expected 1 row, found %s\n' "$row_count" >&2
  exit 1
fi

id1="$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$tmpdir/create1" | head -1)"
id2="$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$tmpdir/create2" | head -1)"
if [[ -z "$id1" || -z "$id2" || "$id1" != "$id2" ]]; then
  printf 'Idempotent create concurrency failed: ids differ (%s vs %s)\n' "$id1" "$id2" >&2
  exit 1
fi
exception_id="$id1"

printf 'Step 1 passed: parallel create idempotency produced one row (%s).\n' "$exception_id"

# Step 2: parallel same-key same-patch update (version 1 -> 2), replayed identically.
update1_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.update_working_date_exception(
  '${exception_id}'::uuid, 1,
  jsonb_build_object('title_en', '${marker} Update1'),
  '${update_key1}'::uuid
);
commit;
"

docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$update1_sql" \
  >"$tmpdir/update1a" 2>&1 &
pidu1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$update1_sql" \
  >"$tmpdir/update1b" 2>&1 &
pidu2=$!

wait "$pidu1" || ecu1=$?
ecu1=${ecu1:-0}
wait "$pidu2" || ecu2=$?
ecu2=${ecu2:-0}

if [[ "$ecu1" -ne 0 || "$ecu2" -ne 0 ]]; then
  printf 'Parallel update replay failed: ecu1=%s ecu2=%s\n' "$ecu1" "$ecu2" >&2
  cat "$tmpdir/update1a" >&2
  cat "$tmpdir/update1b" >&2
  exit 1
fi

if ! diff -q "$tmpdir/update1a" "$tmpdir/update1b" >/dev/null; then
  printf 'Parallel update replay failed: responses differ\n' >&2
  cat "$tmpdir/update1a" >&2
  cat "$tmpdir/update1b" >&2
  exit 1
fi

version_after_update1="$(
  psql_exec -t -A -c "
    select version from public.tenant_working_date_exceptions where id = '${exception_id}'::uuid;
  "
)"
if [[ "$version_after_update1" != "2" ]]; then
  printf 'Parallel update replay failed: expected version 2, got %s\n' "$version_after_update1" >&2
  exit 1
fi

printf 'Step 2 passed: parallel same-key update stayed at version 2.\n'

# Step 3: unrelated later update (version 2 -> 3) with a fresh key.
update2_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.update_working_date_exception(
  '${exception_id}'::uuid, 2,
  jsonb_build_object('title_en', '${marker} Update2'),
  '${update_key2}'::uuid
);
commit;
"
run_sql "$update2_sql" >"$tmpdir/update2" 2>&1

version_after_update2="$(
  psql_exec -t -A -c "
    select version from public.tenant_working_date_exceptions where id = '${exception_id}'::uuid;
  "
)"
if [[ "$version_after_update2" != "3" ]]; then
  printf 'Setup failed: expected version 3 after second update, got %s\n' "$version_after_update2" >&2
  cat "$tmpdir/update2" >&2
  exit 1
fi

# Step 4: replay the now-stale update key -> must replay, not stale_version.
replay1_out="$(run_sql "$update1_sql" 2>&1)"
if echo "$replay1_out" | grep -qi 'stale_version'; then
  printf 'Update replay-after-bump failed: got stale_version\n%s\n' "$replay1_out" >&2
  exit 1
fi
if ! echo "$replay1_out" | grep -qF "${marker} Update1"; then
  printf 'Update replay-after-bump failed: unexpected response\n%s\n' "$replay1_out" >&2
  exit 1
fi

printf 'Step 3 passed: stale-looking update key still replays the original result.\n'

# Step 5: cancel, then replay the same cancel key -> replay (not validation_failed).
cancel_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.cancel_working_date_exception(
  '${exception_id}'::uuid, 3, 'P7B idempotency cancel', '${cancel_key}'::uuid
);
commit;
"
run_sql "$cancel_sql" >"$tmpdir/cancel1" 2>&1

status_after_cancel="$(
  psql_exec -t -A -c "
    select status from public.tenant_working_date_exceptions where id = '${exception_id}'::uuid;
  "
)"
if [[ "$status_after_cancel" != "cancelled" ]]; then
  printf 'Cancel failed: expected cancelled status, got %s\n' "$status_after_cancel" >&2
  cat "$tmpdir/cancel1" >&2
  exit 1
fi

replay2_out="$(run_sql "$cancel_sql" 2>&1)"
if echo "$replay2_out" | grep -qi 'validation_failed'; then
  printf 'Cancel-after-cancelled replay failed: got validation_failed\n%s\n' "$replay2_out" >&2
  exit 1
fi
if ! echo "$replay2_out" | grep -Eq '"status": *"cancelled"'; then
  printf 'Cancel-after-cancelled replay failed: unexpected response\n%s\n' "$replay2_out" >&2
  exit 1
fi

printf 'Step 4 passed: cancel-after-cancelled replays the original result.\n'

# Step 6: same cancel key with a different reason -> idempotency_payload_mismatch.
mismatch_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.cancel_working_date_exception(
  '${exception_id}'::uuid, 3, 'P7B idempotency cancel DIFFERENT', '${cancel_key}'::uuid
);
commit;
"
mismatch_out="$(run_sql "$mismatch_sql" 2>&1)" || true
if ! echo "$mismatch_out" | grep -qF 'idempotency_payload_mismatch'; then
  printf 'Mismatch check failed: expected idempotency_payload_mismatch\n%s\n' "$mismatch_out" >&2
  exit 1
fi

printf 'Step 5 passed: changed payload under the same key raised idempotency_payload_mismatch.\n'

test_passed=1
printf 'P7B idempotency concurrency test passed.\n'
