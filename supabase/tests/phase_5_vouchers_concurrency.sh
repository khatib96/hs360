#!/usr/bin/env bash
# Parallel voucher races: idempotency duplicate submit + concurrent invoice allocation.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'
main_wh='00000000-0000-0000-0000-000000000701'
oils_group='00000000-0000-0000-0000-000000000802'
cash_acct='00000000-0000-0000-0000-000000000501'
idem_key='00000000-0000-0000-0000-00000000f001'
race_key_a='00000000-0000-0000-0000-00000000f002'
race_key_b='00000000-0000-0000-0000-00000000f003'

tmpdir="$(mktemp -d)"
test_passed=0
state_ready=0
setup_ready=0
customer_id=''
supplier_id=''
product_id=''
sale_id=''
purchase_id=''
prior_tax_enabled=''
prior_default_tax_rate_id=''
prior_tax_updated_at=''
prior_rv_next=''
prior_rv_updated_at=''
prior_pv_next=''
prior_pv_updated_at=''
prior_je_next=''
prior_je_updated_at=''
prior_audit_max=''

cleanup() {
  local exit_code=$?
  local cleanup_exit=0

  if [[ "$state_ready" -eq 1 && "$setup_ready" -eq 1 ]]; then
    docker exec -i "$container_name" psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 <<SQL || cleanup_exit=$?
begin;

create temp table m7_test_vouchers on commit drop as
select id, journal_entry_id
from public.vouchers
where tenant_id = '${tenant_a}'::uuid
  and idempotency_key in (
    '${idem_key}'::uuid,
    '${race_key_a}'::uuid,
    '${race_key_b}'::uuid
  );

create temp table m7_seed_purchase on commit drop as
select id, journal_entry_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id = '${purchase_id}'::uuid;

create temp table m7_seed_sale on commit drop as
select id, journal_entry_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id = '${sale_id}'::uuid;

alter table public.journal_lines disable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries disable trigger trg_enforce_posted_journal_entry_immutability;

delete from public.journal_lines
where journal_entry_id in (
  select journal_entry_id from m7_test_vouchers where journal_entry_id is not null
  union
  select reversal_journal_entry_id from public.vouchers
  where id in (select id from m7_test_vouchers)
    and reversal_journal_entry_id is not null
  union
  select journal_entry_id from m7_seed_purchase where journal_entry_id is not null
  union
  select journal_entry_id from m7_seed_sale where journal_entry_id is not null
);

delete from public.voucher_invoice_allocations
where tenant_id = '${tenant_a}'::uuid
  and voucher_id in (select id from m7_test_vouchers);

delete from public.vouchers
where tenant_id = '${tenant_a}'::uuid
  and id in (select id from m7_test_vouchers);

delete from public.inventory_movements
where tenant_id = '${tenant_a}'::uuid
  and (
    (reference_table = 'purchase_invoice' and reference_id = '${purchase_id}'::uuid)
    or (reference_table = 'sales_invoice' and reference_id = '${sale_id}'::uuid)
  );

delete from public.invoice_lines
where tenant_id = '${tenant_a}'::uuid
  and invoice_id in ('${purchase_id}'::uuid, '${sale_id}'::uuid);

delete from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id in ('${purchase_id}'::uuid, '${sale_id}'::uuid);

delete from public.journal_entries
where tenant_id = '${tenant_a}'::uuid
  and id in (
    select journal_entry_id from m7_test_vouchers where journal_entry_id is not null
    union
    select reversal_journal_entry_id from public.vouchers
    where id in (select id from m7_test_vouchers)
      and reversal_journal_entry_id is not null
    union
    select journal_entry_id from m7_seed_purchase where journal_entry_id is not null
    union
    select journal_entry_id from m7_seed_sale where journal_entry_id is not null
  );

delete from public.inventory_balances
where tenant_id = '${tenant_a}'::uuid
  and product_id = '${product_id}'::uuid;

create temp table m7_cleanup_accounts on commit drop as
select account_id from public.customers where id = '${customer_id}'::uuid
union
select account_id from public.suppliers where id = '${supplier_id}'::uuid;

delete from public.customers
where tenant_id = '${tenant_a}'::uuid and id = '${customer_id}'::uuid;

delete from public.products
where tenant_id = '${tenant_a}'::uuid and id = '${product_id}'::uuid;

delete from public.suppliers
where tenant_id = '${tenant_a}'::uuid and id = '${supplier_id}'::uuid;

delete from public.chart_of_accounts
where tenant_id = '${tenant_a}'::uuid
  and id in (select account_id from m7_cleanup_accounts);

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
set next_value = ${prior_rv_next}, updated_at = '${prior_rv_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'RV';

update public.document_sequences
set next_value = ${prior_pv_next}, updated_at = '${prior_pv_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'PV';

update public.document_sequences
set next_value = ${prior_je_next}, updated_at = '${prior_je_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'JE';

delete from public.audit_log
where tenant_id = '${tenant_a}'::uuid
  and id > ${prior_audit_max};

do \$\$
begin
  if exists (
    select 1 from public.vouchers
    where tenant_id = '${tenant_a}'::uuid
      and idempotency_key in (
        '${idem_key}'::uuid,
        '${race_key_a}'::uuid,
        '${race_key_b}'::uuid
      )
  ) or exists (
    select 1 from public.products where id = '${product_id}'::uuid
  ) or exists (
    select 1 from public.customers where id = '${customer_id}'::uuid
  ) or exists (
    select 1 from public.suppliers where id = '${supplier_id}'::uuid
  ) then
    raise exception 'm7_concurrency_cleanup_failed';
  end if;
end;
\$\$;

commit;
SQL
  fi

  rm -rf "$tmpdir"

  if [[ "$cleanup_exit" -ne 0 ]]; then
    printf 'phase_5_vouchers_concurrency.sh: cleanup failed\n' >&2
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
        rv.next_value::text,
        rv.updated_at::text,
        pv.next_value::text,
        pv.updated_at::text,
        je.next_value::text,
        je.updated_at::text,
        coalesce((select max(id) from public.audit_log where tenant_id = ts.tenant_id), 0)::text
      from public.tenant_settings ts
      join public.document_sequences rv
        on rv.tenant_id = ts.tenant_id and rv.sequence_key = 'RV'
      join public.document_sequences pv
        on pv.tenant_id = ts.tenant_id and pv.sequence_key = 'PV'
      join public.document_sequences je
        on je.tenant_id = ts.tenant_id and je.sequence_key = 'JE'
      where ts.tenant_id = '${tenant_a}'::uuid;
    "
)"
IFS='|' read -r \
  prior_tax_enabled \
  prior_default_tax_rate_id \
  prior_tax_updated_at \
  prior_rv_next \
  prior_rv_updated_at \
  prior_pv_next \
  prior_pv_updated_at \
  prior_je_next \
  prior_je_updated_at \
  prior_audit_max <<<"$initial_state"

if [[ -z "$prior_tax_enabled" || -z "$prior_rv_next" || -z "$prior_je_next" ]]; then
  printf 'Concurrency state capture failed: %s\n' "$initial_state" >&2
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
    jsonb_build_object('name_ar', 'عميل تزامن M7', 'phone_primary', '+96550007999', 'create_account', true)
  ) as id
),
supplier as (
  select public.create_supplier(
    jsonb_build_object('name_ar', 'مورد تزامن M7', 'create_account', true)
  ) as id
),
product as (
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  select
    '${tenant_a}'::uuid,
    'M7-CONCUR-' || substr(gen_random_uuid()::text, 1, 8),
    'زيت تزامن', 'Concurrency Oil', '${oils_group}'::uuid, 'consumable_rental',
    'ml', 100.000, 0, false, true, '${owner_sub}'::uuid
  returning id
),
purchase as (
  select public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', supplier.id,
      'warehouse_id', '${main_wh}'::uuid,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', product.id,
          'qty', 5,
          'unit_price', 10.000,
          'discount_pct', 0,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  ) as id
  from supplier, product
),
sale as (
  select public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', customer.id,
      'warehouse_id', '${main_wh}'::uuid,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', product.id,
          'qty', 1,
          'unit_price', 100.000,
          'discount_pct', 0,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  ) as id
  from customer, product
)
select
  customer.id::text || ',' ||
  supplier.id::text || ',' ||
  product.id::text || ',' ||
  purchase.id::text || ',' ||
  sale.id::text
from customer, supplier, product, purchase, sale;
commit;
"

setup_ids="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$setup_sql" \
    | grep -E '^[0-9a-f-]{36},[0-9a-f-]{36},[0-9a-f-]{36},[0-9a-f-]{36},[0-9a-f-]{36}$' \
    | tail -1
)"
IFS=',' read -r customer_id supplier_id product_id purchase_id sale_id <<<"$setup_ids"

if [[ -z "$customer_id" || -z "$sale_id" ]]; then
  printf 'Concurrency setup failed: %s\n' "$setup_ids" >&2
  exit 1
fi
setup_ready=1

idem_payload="
  jsonb_build_object(
    'customer_id', '${customer_id}'::uuid,
    'date', current_date,
    'amount', 25,
    'payment_method', 'cash',
    'cash_account_id', '${cash_acct}'::uuid,
    'allocation_mode', 'unallocated'
  )
"

idem_sql="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_receipt_voucher(
  ${idem_payload},
  '${idem_key}'::uuid
);
"

printf 'Running phase_5_vouchers_concurrency.sh (idempotency) ...\n'

docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$idem_sql" \
  >"$tmpdir/idem1" 2>&1 &
pid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$idem_sql" \
  >"$tmpdir/idem2" 2>&1 &
pid2=$!

wait "$pid1" || ec1=$?
ec1=${ec1:-0}
wait "$pid2" || ec2=$?
ec2=${ec2:-0}

if [[ "$ec1" -ne 0 && "$ec2" -ne 0 ]]; then
  cat "$tmpdir/idem1" "$tmpdir/idem2" >&2
  exit 1
fi

idem_id1="$(tr -d '[:space:]' <"$tmpdir/idem1")"
idem_id2="$(tr -d '[:space:]' <"$tmpdir/idem2")"

idem_count="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
    select count(*)::text
    from public.vouchers
    where tenant_id = '${tenant_a}'::uuid
      and idempotency_key = '${idem_key}'::uuid;
  "
)"

if [[ "$idem_id1" != "$idem_id2" || "$idem_count" != "1" ]]; then
  printf 'Idempotency race failed: id1=%s id2=%s count=%s\n' "$idem_id1" "$idem_id2" "$idem_count" >&2
  exit 1
fi

race_payload_a="
  jsonb_build_object(
    'customer_id', '${customer_id}'::uuid,
    'date', current_date,
    'amount', 100,
    'payment_method', 'cash',
    'cash_account_id', '${cash_acct}'::uuid,
    'allocation_mode', 'manual',
    'allocations', jsonb_build_array(
      jsonb_build_object('invoice_id', '${sale_id}'::uuid, 'allocated_amount', 100)
    )
  )
"

race_payload_b="$race_payload_a"

race_sql_a="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_receipt_voucher(
  ${race_payload_a},
  '${race_key_a}'::uuid
);
"

race_sql_b="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_receipt_voucher(
  ${race_payload_b},
  '${race_key_b}'::uuid
);
"

printf 'Running phase_5_vouchers_concurrency.sh (allocation race) ...\n'

docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$race_sql_a" \
  >"$tmpdir/race1" 2>&1 &
rpid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$race_sql_b" \
  >"$tmpdir/race2" 2>&1 &
rpid2=$!

wait "$rpid1" || rec1=$?
rec1=${rec1:-0}
wait "$rpid2" || rec2=$?
rec2=${rec2:-0}

success_count=0
if [[ "$rec1" -eq 0 ]]; then success_count=$((success_count + 1)); fi
if [[ "$rec2" -eq 0 ]]; then success_count=$((success_count + 1)); fi

alloc_sum="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
    select coalesce(sum(via.allocated_amount), 0)::text
    from public.voucher_invoice_allocations via
  join public.vouchers v on v.id = via.voucher_id
    where via.tenant_id = '${tenant_a}'::uuid
      and via.invoice_id = '${sale_id}'::uuid
      and coalesce(via.is_reversed, false) = false
      and v.idempotency_key in ('${race_key_a}'::uuid, '${race_key_b}'::uuid);
  "
)"

paid_amount="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
    select paid_amount::text
    from public.invoices
    where id = '${sale_id}'::uuid;
  "
)"

if [[ "$success_count" -ne 1 ]]; then
  cat "$tmpdir/race1" "$tmpdir/race2" >&2
  printf 'Allocation race failed: success_count=%s (expected 1)\n' "$success_count" >&2
  exit 1
fi

if [[ "$alloc_sum" != "100.000" && "$alloc_sum" != "100" ]]; then
  printf 'Allocation race failed: alloc_sum=%s paid=%s\n' "$alloc_sum" "$paid_amount" >&2
  exit 1
fi

test_passed=1
printf 'phase_5_vouchers_concurrency.sh passed.\n'
