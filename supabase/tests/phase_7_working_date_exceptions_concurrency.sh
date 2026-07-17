#!/usr/bin/env bash
# Phase 7 M7B: two parallel create_working_date_exception calls with
# overlapping date ranges (different idempotency keys). Exactly one must
# succeed; the loser must fail with working_date_exception_overlap. No two
# active rows for the tenant may ever overlap after the race settles.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

owner_sub='00000000-0000-0000-0000-000000000201'
marker="P7BOV-$(date +%s)-$$"
tmpdir="$(mktemp -d)"
test_passed=0

psql_exec() {
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
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

printf 'P7B overlap concurrency: parallel overlapping create_working_date_exception (marker=%s)\n' "$marker"

base_offset=$(( ( $(date +%s) % 500 ) + 3000 ))

create_sql_a="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.create_working_date_exception(
  jsonb_build_object(
    'kind', 'official_holiday',
    'start_date', to_char(current_date + ${base_offset}, 'YYYY-MM-DD'),
    'end_date', to_char(current_date + ${base_offset} + 10, 'YYYY-MM-DD'),
    'title_en', '${marker} A'
  ),
  gen_random_uuid()
);
commit;
"

create_sql_b="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.create_working_date_exception(
  jsonb_build_object(
    'kind', 'official_holiday',
    'start_date', to_char(current_date + ${base_offset} + 5, 'YYYY-MM-DD'),
    'end_date', to_char(current_date + ${base_offset} + 15, 'YYYY-MM-DD'),
    'title_en', '${marker} B'
  ),
  gen_random_uuid()
);
commit;
"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$create_sql_a" \
  >"$tmpdir/out_a" 2>&1 &
pid_a=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$create_sql_b" \
  >"$tmpdir/out_b" 2>&1 &
pid_b=$!

wait "$pid_a" || ec_a=$?
ec_a=${ec_a:-0}
wait "$pid_b" || ec_b=$?
ec_b=${ec_b:-0}

if [[ "$ec_a" -eq 0 && "$ec_b" -eq 0 ]]; then
  printf 'Overlap concurrency failed: both overlapping creates succeeded\n' >&2
  cat "$tmpdir/out_a" >&2
  cat "$tmpdir/out_b" >&2
  exit 1
fi

if [[ "$ec_a" -ne 0 && "$ec_b" -ne 0 ]]; then
  printf 'Overlap concurrency failed: both overlapping creates failed\n' >&2
  cat "$tmpdir/out_a" >&2
  cat "$tmpdir/out_b" >&2
  exit 1
fi

failed_out="$tmpdir/out_a"
if [[ "$ec_a" -eq 0 ]]; then
  failed_out="$tmpdir/out_b"
fi

# Concurrent GiST exclusion-constraint checks can legitimately resolve either
# as a clean exclusion_violation (working_date_exception_overlap) or as a
# deadlock between the two overlapping inserts, depending on lock-wait timing.
# Both are acceptable proof that the race was serialized correctly.
if ! grep -qE 'working_date_exception_overlap|deadlock detected' "$failed_out"; then
  printf 'Overlap concurrency failed: losing branch did not report an overlap/deadlock error\n' >&2
  cat "$failed_out" >&2
  exit 1
fi

active_count="$(
  psql_exec -t -A -c "
    select count(*) from public.tenant_working_date_exceptions
    where title_en like '${marker}%' and status = 'active';
  "
)"
if [[ "$active_count" != "1" ]]; then
  printf 'Overlap concurrency failed: expected 1 active row, found %s\n' "$active_count" >&2
  exit 1
fi

overlap_count="$(
  psql_exec -t -A -c "
    select count(*)
    from public.tenant_working_date_exceptions a
    join public.tenant_working_date_exceptions b
      on a.tenant_id = b.tenant_id and a.id < b.id
    where a.title_en like '${marker}%'
      and b.title_en like '${marker}%'
      and a.status = 'active' and b.status = 'active'
      and daterange(a.start_date, a.end_date, '[]') && daterange(b.start_date, b.end_date, '[]');
  "
)"
if [[ "$overlap_count" != "0" ]]; then
  printf 'Overlap concurrency failed: found %s overlapping active pairs\n' "$overlap_count" >&2
  exit 1
fi

test_passed=1
printf 'P7B overlap concurrency test passed.\n'
