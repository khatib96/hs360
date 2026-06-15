#!/usr/bin/env bash
# Parallel first-version create_tax_rate race: exactly one session must succeed.
# Uses seeded posting accounts (no tax-account provisioning). Postgres-only cleanup
# on EXIT removes the test rate and restores the no-delete trigger.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'

tmpdir="$(mktemp -d)"
code="CONCUR$(date +%s)"
test_passed=0

cleanup() {
  local exit_code=$?

  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL || true
begin;
update public.tenant_settings
set default_tax_rate_id = null
where tenant_id = '${tenant_a}'::uuid
  and default_tax_rate_id in (
    select id
    from public.tax_rates
    where tenant_id = '${tenant_a}'::uuid
      and code = '${code}'
  );

alter table public.tax_rates disable trigger trg_enforce_tax_rates_no_delete;

delete from public.tax_rates
where tenant_id = '${tenant_a}'::uuid
  and code = '${code}';

alter table public.tax_rates enable trigger trg_enforce_tax_rates_no_delete;
commit;
SQL

  rm -rf "$tmpdir"

  if [[ "$test_passed" -eq 1 ]]; then
    exit 0
  fi

  exit "$exit_code"
}
trap cleanup EXIT

create_sql="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.create_tax_rate(
  jsonb_build_object(
    'code', '${code}',
    'name_ar', 'ضريبة',
    'name_en', 'Concurrent First Version',
    'rate', 5,
    'effective_from', current_date
  )
);
"

printf 'Running phase_5_tax_foundation_concurrency.sh ...\n'

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$create_sql" \
  >"$tmpdir/out1" 2>&1 &
pid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$create_sql" \
  >"$tmpdir/out2" 2>&1 &
pid2=$!

wait "$pid1" || ec1=$?
ec1=${ec1:-0}
wait "$pid2" || ec2=$?
ec2=${ec2:-0}

count="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -c "
    select count(*)
    from public.tax_rates
    where tenant_id = '${tenant_a}'::uuid
      and code = '${code}'
      and effective_from = current_date;
  "
)"

if [[ "$count" != "1" ]]; then
  printf 'Concurrency test failed: expected 1 %s row, got %s\n' "$code" "$count" >&2
  cat "$tmpdir/out1" >&2 || true
  cat "$tmpdir/out2" >&2 || true
  exit 1
fi

if [[ "$ec1" -eq 0 && "$ec2" -eq 0 ]]; then
  printf 'Concurrency test failed: both sessions succeeded (expected exactly one)\n' >&2
  cat "$tmpdir/out1" >&2 || true
  cat "$tmpdir/out2" >&2 || true
  exit 1
fi

if [[ "$ec1" -ne 0 && "$ec2" -ne 0 ]]; then
  printf 'Concurrency test failed: both sessions failed\n' >&2
  cat "$tmpdir/out1" >&2 || true
  cat "$tmpdir/out2" >&2 || true
  exit 1
fi

test_passed=1
printf 'Concurrency test passed: exactly one session succeeded for %s.\n' "$code"
printf 'phase_5_tax_foundation_concurrency.sh: passed\n'
