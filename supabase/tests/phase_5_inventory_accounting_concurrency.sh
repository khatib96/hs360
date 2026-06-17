#!/usr/bin/env bash
# Parallel inventory document idempotency on same product.
# Postgres-only cleanup on EXIT removes test product/document/journal rows.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'
main_wh='00000000-0000-0000-0000-000000000701'
oils_group='00000000-0000-0000-0000-000000000802'
idem_key='00000000-0000-0000-0000-00000000d001'

tmpdir="$(mktemp -d)"
test_passed=0
state_ready=0
product_id=''
prior_sti_next=''
prior_sti_updated_at=''

cleanup() {
  local exit_code=$?
  local cleanup_exit=0

  if [[ "$state_ready" -eq 1 && -n "$product_id" ]]; then
    docker exec -i "$container_name" psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 \
      -v product_id="$product_id" <<SQL || cleanup_exit=$?
begin;

create temp table m45_test_docs on commit drop as
select id, journal_entry_id
from public.inventory_documents
where tenant_id = '${tenant_a}'::uuid
  and idempotency_key = '${idem_key}'::uuid;

alter table public.journal_lines disable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries disable trigger trg_enforce_posted_journal_entry_immutability;

delete from public.journal_lines
where journal_entry_id in (
  select journal_entry_id
  from m45_test_docs
  where journal_entry_id is not null
);

delete from public.inventory_movements
where tenant_id = '${tenant_a}'::uuid
  and reference_table = 'inventory_document'
  and reference_id in (select id from m45_test_docs);

delete from public.inventory_document_lines
where tenant_id = '${tenant_a}'::uuid
  and document_id in (select id from m45_test_docs);

delete from public.inventory_documents
where tenant_id = '${tenant_a}'::uuid
  and id in (select id from m45_test_docs);

delete from public.journal_entries
where tenant_id = '${tenant_a}'::uuid
  and id in (
    select journal_entry_id
    from m45_test_docs
    where journal_entry_id is not null
  );

delete from public.inventory_balances
where tenant_id = '${tenant_a}'::uuid
  and product_id = :'product_id'::uuid;

delete from public.products
where tenant_id = '${tenant_a}'::uuid
  and id = :'product_id'::uuid;

alter table public.journal_lines enable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries enable trigger trg_enforce_posted_journal_entry_immutability;

update public.document_sequences
set next_value = ${prior_sti_next}, updated_at = '${prior_sti_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'STI';

commit;
SQL
  fi

  rm -rf "$tmpdir"

  if [[ "$test_passed" -eq 1 && "$cleanup_exit" -eq 0 ]]; then
    exit 0
  fi

  exit "${cleanup_exit:-$exit_code}"
}
trap cleanup EXIT

setup_sql() {
  prior_sti_next="$(docker exec -i "$container_name" psql -U postgres -d postgres -At -c \
    "select next_value from public.document_sequences where tenant_id='${tenant_a}'::uuid and sequence_key='STI'")"
  prior_sti_updated_at="$(docker exec -i "$container_name" psql -U postgres -d postgres -At -c \
    "select updated_at from public.document_sequences where tenant_id='${tenant_a}'::uuid and sequence_key='STI'")"

  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';

insert into public.products (
  tenant_id, sku, name_ar, name_en, group_id, product_type,
  unit_primary, sale_price, avg_cost, is_serialized, created_by
)
values (
  '${tenant_a}'::uuid, 'M45-CONC-' || left(gen_random_uuid()::text, 8),
  'M45 Conc', 'M45 Conc', '${oils_group}'::uuid, 'consumable_rental', 'ml',
  1.000, 5.000, false, '${owner_sub}'::uuid
);

commit;
SQL

  product_id="$(docker exec -i "$container_name" psql -U postgres -d postgres -tA -c \
    "select id from public.products where tenant_id='${tenant_a}'::uuid and sku like 'M45-CONC-%' order by created_at desc limit 1")"
  state_ready=1
}

run_idempotent() {
  local outfile="$1"
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$outfile" 2>&1 <<SQL || true
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_inventory_document(
  jsonb_build_object(
    'document_type', 'stock_in',
    'warehouse_id', '${main_wh}',
    'date', current_date,
    'notes', 'M45 concurrency stock-in',
    'reason_code', 'owner_contribution',
    'lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', '${product_id}',
        'qty', 3,
        'unit_cost', 5.000,
        'line_order', 1
      )
    )
  ),
  '${idem_key}'::uuid
);
commit;
SQL
}

printf 'Running phase_5_inventory_accounting_concurrency.sh ...\n'
setup_sql
run_idempotent "$tmpdir/a.out" &
run_idempotent "$tmpdir/b.out" &
wait

success_count=0
grep -q 'record_inventory_document' "$tmpdir/a.out" && success_count=$((success_count + 1)) || true
grep -q 'record_inventory_document' "$tmpdir/b.out" && success_count=$((success_count + 1)) || true

if [[ "$success_count" -ne 2 ]]; then
  echo "M4.5 concurrency: expected both sessions to return id, got $success_count" >&2
  cat "$tmpdir/a.out" "$tmpdir/b.out" >&2
  exit 1
fi

doc_count=$(docker exec -i "$container_name" psql -U postgres -d postgres -tA -c \
  "select count(*) from public.inventory_documents where tenant_id='${tenant_a}'::uuid and idempotency_key='${idem_key}'::uuid")

if [[ "$doc_count" != "1" ]]; then
  echo "M4.5 concurrency: expected 1 document, got $doc_count" >&2
  exit 1
fi

test_passed=1
echo "M4.5 inventory accounting concurrency passed."
