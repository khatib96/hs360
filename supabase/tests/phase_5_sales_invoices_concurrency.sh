#!/usr/bin/env bash
# Parallel sales invoice stock-out race: exactly one winner for last unit.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'
main_wh='00000000-0000-0000-0000-000000000701'
oils_group='00000000-0000-0000-0000-000000000802'
idem_key_a='00000000-0000-0000-0000-00000000d001'
idem_key_b='00000000-0000-0000-0000-00000000d002'

tmpdir="$(mktemp -d)"
test_passed=0
state_ready=0
setup_ready=0
customer_id=''
supplier_id=''
product_id=''
purchase_id=''
prior_tax_enabled=''
prior_default_tax_rate_id=''
prior_tax_updated_at=''
prior_si_next=''
prior_si_updated_at=''
prior_je_next=''
prior_je_updated_at=''
prior_audit_max=''

cleanup() {
  local exit_code=$?
  local cleanup_exit=0

  if [[ "$state_ready" -eq 1 && "$setup_ready" -eq 1 ]]; then
    docker exec -i "$container_name" psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 \
      -v customer_id="$customer_id" \
      -v supplier_id="$supplier_id" \
      -v product_id="$product_id" \
      -v purchase_id="$purchase_id" <<SQL || cleanup_exit=$?
begin;

create temp table m6_test_invoices on commit drop as
select id, journal_entry_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and idempotency_key in ('${idem_key_a}'::uuid, '${idem_key_b}'::uuid);

create temp table m6_seed_purchase on commit drop as
select id, journal_entry_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id = :'purchase_id'::uuid;

alter table public.journal_lines disable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries disable trigger trg_enforce_posted_journal_entry_immutability;

delete from public.journal_lines
where journal_entry_id in (
  select journal_entry_id from m6_test_invoices where journal_entry_id is not null
  union
  select journal_entry_id from m6_seed_purchase where journal_entry_id is not null
);

delete from public.inventory_movements
where tenant_id = '${tenant_a}'::uuid
  and reference_table = 'purchase_invoice'
  and reference_id = :'purchase_id'::uuid;

delete from public.invoice_lines
where tenant_id = '${tenant_a}'::uuid
  and invoice_id = :'purchase_id'::uuid;

delete from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id = :'purchase_id'::uuid;

delete from public.inventory_movements
where tenant_id = '${tenant_a}'::uuid
  and reference_table = 'sales_invoice'
  and reference_id in (select id from m6_test_invoices);

delete from public.unit_events
where tenant_id = '${tenant_a}'::uuid
  and reference_table = 'sales_invoice'
  and reference_id in (select id from m6_test_invoices);

delete from public.invoice_lines
where tenant_id = '${tenant_a}'::uuid
  and invoice_id in (select id from m6_test_invoices);

delete from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id in (select id from m6_test_invoices);

delete from public.journal_entries
where tenant_id = '${tenant_a}'::uuid
  and id in (
    select journal_entry_id from m6_test_invoices where journal_entry_id is not null
    union
    select journal_entry_id from m6_seed_purchase where journal_entry_id is not null
  );

delete from public.inventory_balances
where tenant_id = '${tenant_a}'::uuid
  and product_id = :'product_id'::uuid;

create temp table m6_cleanup_accounts on commit drop as
select account_id
from public.customers
where id = :'customer_id'::uuid
union
select account_id
from public.suppliers
where id = :'supplier_id'::uuid;

delete from public.customers
where tenant_id = '${tenant_a}'::uuid
  and id = :'customer_id'::uuid;

delete from public.products
where tenant_id = '${tenant_a}'::uuid
  and id = :'product_id'::uuid;

delete from public.suppliers
where tenant_id = '${tenant_a}'::uuid
  and id = :'supplier_id'::uuid;

delete from public.chart_of_accounts
where tenant_id = '${tenant_a}'::uuid
  and id in (select account_id from m6_cleanup_accounts);

alter table public.journal_lines enable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries enable trigger trg_enforce_posted_journal_entry_immutability;

alter table public.tenant_settings disable trigger trg_touch_tenant_settings;
alter table public.tenant_settings disable trigger trg_audit_tenant_settings_update;
update public.tenant_settings
set
  tax_enabled = ${prior_tax_enabled},
  default_tax_rate_id = nullif('${prior_default_tax_rate_id}', '')::uuid,
  updated_at = '${prior_tax_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid;
alter table public.tenant_settings enable trigger trg_audit_tenant_settings_update;
alter table public.tenant_settings enable trigger trg_touch_tenant_settings;

update public.document_sequences
set next_value = ${prior_si_next}, updated_at = '${prior_si_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'SI';

update public.document_sequences
set next_value = ${prior_je_next}, updated_at = '${prior_je_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'JE';

delete from public.audit_log
where tenant_id = '${tenant_a}'::uuid
  and id > ${prior_audit_max};

do \$\$
begin
  if exists (
    select 1 from public.invoices
    where tenant_id = '${tenant_a}'::uuid
      and idempotency_key in ('${idem_key_a}'::uuid, '${idem_key_b}'::uuid)
  ) or exists (
    select 1 from public.products where id = '${product_id}'::uuid
  ) or exists (
    select 1 from public.customers where id = '${customer_id}'::uuid
  ) then
    raise exception 'm6_concurrency_cleanup_failed';
  end if;
end;
\$\$;

commit;
SQL
  fi

  rm -rf "$tmpdir"

  if [[ "$cleanup_exit" -ne 0 ]]; then
    printf 'phase_5_sales_invoices_concurrency.sh: cleanup failed\n' >&2
    exit "$cleanup_exit"
  fi

  if [[ "$test_passed" -eq 1 && "$exit_code" -eq 0 ]]; then
    exit 0
  fi

  exit "$exit_code"
}
trap cleanup EXIT

initial_state="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -F '|' \
    -v ON_ERROR_STOP=1 -c "
      select
        case when ts.tax_enabled then 'true' else 'false' end,
        coalesce(ts.default_tax_rate_id::text, ''),
        ts.updated_at::text,
        si.next_value::text,
        si.updated_at::text,
        je.next_value::text,
        je.updated_at::text,
        coalesce((select max(id) from public.audit_log where tenant_id = ts.tenant_id), 0)::text
      from public.tenant_settings ts
      join public.document_sequences si
        on si.tenant_id = ts.tenant_id and si.sequence_key = 'SI'
      join public.document_sequences je
        on je.tenant_id = ts.tenant_id and je.sequence_key = 'JE'
      where ts.tenant_id = '${tenant_a}'::uuid;
    "
)"
IFS='|' read -r \
  prior_tax_enabled \
  prior_default_tax_rate_id \
  prior_tax_updated_at \
  prior_si_next \
  prior_si_updated_at \
  prior_je_next \
  prior_je_updated_at \
  prior_audit_max <<<"$initial_state"

if [[ -z "$prior_tax_enabled" ]]; then
  printf 'Concurrency state capture failed\n' >&2
  exit 1
fi
state_ready=1

setup_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.update_tax_settings(jsonb_build_object('tax_enabled', false));
with customer as (
  select public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل تزامن M6',
      'phone_primary', '+96550000888',
      'create_account', true
    )
  ) as id
),
supplier as (
  select public.create_supplier(
    jsonb_build_object('name_ar', 'مورد تزامن M6', 'create_account', true)
  ) as id
),
product as (
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    can_be_sold, can_be_rented, unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  select
    '${tenant_a}'::uuid,
    'M6-CONCUR-' || substr(gen_random_uuid()::text, 1, 8),
    'زيت تزامن', 'Concurrency Oil', '${oils_group}'::uuid, 'sale_only',
    true, false, 'ml', 5.000, 2.000, false, '${owner_sub}'::uuid
  returning id
)
select
  customer.id::text || ',' ||
  supplier.id::text || ',' ||
  product.id::text
from customer
cross join supplier
cross join product;
commit;
"

setup_ids="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$setup_sql" \
    | grep -E '^[0-9a-f-]{36},[0-9a-f-]{36},[0-9a-f-]{36}$' \
    | tail -1
)"
IFS=',' read -r customer_id supplier_id product_id <<<"$setup_ids"

if [[ -z "$customer_id" || -z "$product_id" ]]; then
  printf 'Concurrency setup failed\n' >&2
  exit 1
fi
setup_ready=1

purchase_id="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_purchase_invoice(
  jsonb_build_object(
    'supplier_id', '${supplier_id}'::uuid,
    'warehouse_id', '${main_wh}'::uuid,
    'date', current_date,
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', '${product_id}'::uuid,
      'qty', 1,
      'unit_price', 2.000,
      'discount_pct', 0,
      'line_order', 1
    ))
  ),
  gen_random_uuid()
);
commit;
" | grep -E '^[0-9a-f-]{36}$' | tail -1
)"

if [[ -z "$purchase_id" ]]; then
  printf 'Concurrency purchase seed failed\n' >&2
  exit 1
fi

sale_payload="
  jsonb_build_object(
    'customer_id', '${customer_id}'::uuid,
    'warehouse_id', '${main_wh}'::uuid,
    'date', current_date,
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', '${product_id}'::uuid,
      'qty', 1,
      'unit_price', 5.000,
      'discount_pct', 0,
      'line_order', 1
    ))
  )
"

sale_a="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_sales_invoice(${sale_payload}, '${idem_key_a}'::uuid);
"

sale_b="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_sales_invoice(${sale_payload}, '${idem_key_b}'::uuid);
"

printf 'Running phase_5_sales_invoices_concurrency.sh ...\n'

docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$sale_a" \
  >"$tmpdir/out1" 2>&1 &
pid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$sale_b" \
  >"$tmpdir/out2" 2>&1 &
pid2=$!

wait "$pid1" || ec1=$?
ec1=${ec1:-0}
wait "$pid2" || ec2=$?
ec2=${ec2:-0}

success_count=$(( (ec1 == 0 ? 1 : 0) + (ec2 == 0 ? 1 : 0) ))
insufficient_count=0
if grep -q 'insufficient_stock' "$tmpdir/out1" 2>/dev/null; then insufficient_count=$((insufficient_count + 1)); fi
if grep -q 'insufficient_stock' "$tmpdir/out2" 2>/dev/null; then insufficient_count=$((insufficient_count + 1)); fi

invoice_count="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -c "
    select count(*) from public.invoices
    where tenant_id = '${tenant_a}'::uuid
      and type = 'sales'
      and idempotency_key in ('${idem_key_a}'::uuid, '${idem_key_b}'::uuid);
  "
)"

if [[ "$success_count" -ne 1 || "$insufficient_count" -ne 1 || "$invoice_count" != "1" ]]; then
  printf 'Sales concurrency failed: success=%s insufficient=%s invoices=%s\n' \
    "$success_count" "$insufficient_count" "$invoice_count" >&2
  cat "$tmpdir/out1" >&2 || true
  cat "$tmpdir/out2" >&2 || true
  exit 1
fi

test_passed=1
printf 'phase_5_sales_invoices_concurrency.sh: passed\n'
