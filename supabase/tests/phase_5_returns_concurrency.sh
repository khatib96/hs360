#!/usr/bin/env bash
# Parallel return races: idempotency duplicate submit + concurrent partial return on same line.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'
main_wh='00000000-0000-0000-0000-000000000701'
oils_group='00000000-0000-0000-0000-000000000802'
idem_key='00000000-0000-0000-0000-00000000e001'
race_key_a='00000000-0000-0000-0000-00000000e002'
race_key_b='00000000-0000-0000-0000-00000000e003'

tmpdir="$(mktemp -d)"
test_passed=0
state_ready=0
setup_ready=0
customer_id=''
supplier_id=''
product_id=''
purchase_id=''
sale_id=''
orig_line_id=''
prior_tax_enabled=''
prior_default_tax_rate_id=''
prior_tax_updated_at=''
prior_sr_next=''
prior_sr_updated_at=''
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
      -v purchase_id="$purchase_id" \
      -v sale_id="$sale_id" <<SQL || cleanup_exit=$?
begin;

create temp table m75_test_returns on commit drop as
select id, journal_entry_id, original_invoice_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and idempotency_key in (
    '${idem_key}'::uuid,
    '${race_key_a}'::uuid,
    '${race_key_b}'::uuid
  );

create temp table m75_seed_sale on commit drop as
select id, journal_entry_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id = :'sale_id'::uuid;

create temp table m75_seed_purchase on commit drop as
select id, journal_entry_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id = :'purchase_id'::uuid;

alter table public.journal_lines disable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries disable trigger trg_enforce_posted_journal_entry_immutability;

delete from public.invoice_credit_allocations
where tenant_id = '${tenant_a}'::uuid
  and source_invoice_id in (select id from m75_test_returns);

delete from public.journal_lines
where journal_entry_id in (
  select journal_entry_id from m75_test_returns where journal_entry_id is not null
  union
  select reversal_journal_entry_id from public.invoices
  where id in (select id from m75_test_returns)
    and reversal_journal_entry_id is not null
  union
  select journal_entry_id from m75_seed_sale where journal_entry_id is not null
  union
  select journal_entry_id from m75_seed_purchase where journal_entry_id is not null
);

delete from public.inventory_movements
where tenant_id = '${tenant_a}'::uuid
  and (
    (reference_table = 'sales_return_invoice' and reference_id in (select id from m75_test_returns))
    or (reference_table = 'sales_invoice' and reference_id = :'sale_id'::uuid)
    or (reference_table = 'purchase_invoice' and reference_id = :'purchase_id'::uuid)
  );

delete from public.unit_events
where tenant_id = '${tenant_a}'::uuid
  and reference_table in ('sales_invoice', 'sales_return_invoice')
  and reference_id in (
    select id from m75_test_returns
    union
    select :'sale_id'::uuid
  );

delete from public.invoice_lines
where tenant_id = '${tenant_a}'::uuid
  and invoice_id in (
    select id from m75_test_returns
    union
    select :'sale_id'::uuid
    union
    select :'purchase_id'::uuid
  );

delete from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id in (
    select id from m75_test_returns
    union
    select :'sale_id'::uuid
    union
    select :'purchase_id'::uuid
  );

delete from public.journal_entries
where tenant_id = '${tenant_a}'::uuid
  and id in (
    select journal_entry_id from m75_test_returns where journal_entry_id is not null
    union
    select reversal_journal_entry_id from public.invoices
    where id in (select id from m75_test_returns)
      and reversal_journal_entry_id is not null
    union
    select journal_entry_id from m75_seed_sale where journal_entry_id is not null
    union
    select journal_entry_id from m75_seed_purchase where journal_entry_id is not null
  );

delete from public.inventory_balances
where tenant_id = '${tenant_a}'::uuid
  and product_id = :'product_id'::uuid;

create temp table m75_cleanup_accounts on commit drop as
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
  and id in (select account_id from m75_cleanup_accounts);

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
set next_value = ${prior_sr_next}, updated_at = '${prior_sr_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'SR';

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
      and idempotency_key in (
        '${idem_key}'::uuid,
        '${race_key_a}'::uuid,
        '${race_key_b}'::uuid
      )
  ) or exists (
    select 1 from public.products where id = '${product_id}'::uuid
  ) or exists (
    select 1 from public.customers where id = '${customer_id}'::uuid
  ) then
    raise exception 'm75_concurrency_cleanup_failed';
  end if;
end;
\$\$;

commit;
SQL
  fi

  rm -rf "$tmpdir"

  if [[ "$cleanup_exit" -ne 0 ]]; then
    printf 'phase_5_returns_concurrency.sh: cleanup failed\n' >&2
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
        sr.next_value::text,
        sr.updated_at::text,
        si.next_value::text,
        si.updated_at::text,
        je.next_value::text,
        je.updated_at::text,
        coalesce((select max(id) from public.audit_log where tenant_id = ts.tenant_id), 0)::text
      from public.tenant_settings ts
      join public.document_sequences sr
        on sr.tenant_id = ts.tenant_id and sr.sequence_key = 'SR'
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
  prior_sr_next \
  prior_sr_updated_at \
  prior_si_next \
  prior_si_updated_at \
  prior_je_next \
  prior_je_updated_at \
  prior_audit_max <<<"$initial_state"

if [[ -z "$prior_tax_enabled" || -z "$prior_sr_next" ]]; then
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
    jsonb_build_object(
      'name_ar', 'عميل تزامن M7.5',
      'phone_primary', '+96550008' || substr(gen_random_uuid()::text, 1, 4),
      'create_account', true
    )
  ) as id
),
supplier as (
  select public.create_supplier(
    jsonb_build_object('name_ar', 'مورد تزامن M7.5', 'create_account', true)
  ) as id
),
product as (
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  select
    '${tenant_a}'::uuid,
    'M75-CONCUR-' || substr(gen_random_uuid()::text, 1, 8),
    'زيت تزامن', 'Concurrency Oil', '${oils_group}'::uuid, 'consumable_rental',
    'ml', 10.000, 2.000, false, true, '${owner_sub}'::uuid
  returning id
)
select
  customer.id::text || ',' ||
  supplier.id::text || ',' ||
  product.id::text
from customer, supplier, product;
commit;
"

setup_ids="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$setup_sql" \
    | grep -E '^[0-9a-f-]{36},[0-9a-f-]{36},[0-9a-f-]{36}$' \
    | tail -1
)"
IFS=',' read -r customer_id supplier_id product_id <<<"$setup_ids"

if [[ -z "$customer_id" || -z "$product_id" ]]; then
  printf 'Concurrency setup failed: %s\n' "$setup_ids" >&2
  exit 1
fi

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
      'qty', 10,
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

sale_id="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_sales_invoice(
  jsonb_build_object(
    'customer_id', '${customer_id}'::uuid,
    'warehouse_id', '${main_wh}'::uuid,
    'date', current_date,
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', '${product_id}'::uuid,
      'qty', 10,
      'unit_price', 10.000,
      'discount_pct', 0,
      'line_order', 1
    ))
  ),
  gen_random_uuid()
);
commit;
" | grep -E '^[0-9a-f-]{36}$' | tail -1
)"

if [[ -z "$sale_id" ]]; then
  printf 'Concurrency sale seed failed\n' >&2
  exit 1
fi

orig_line_id="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
    select id::text
    from public.invoice_lines
    where tenant_id = '${tenant_a}'::uuid
      and invoice_id = '${sale_id}'::uuid
      and line_order = 1
    limit 1;
  "
)"

if [[ -z "$orig_line_id" ]]; then
  printf 'Concurrency orig line lookup failed\n' >&2
  exit 1
fi

setup_ready=1

return_payload="
  jsonb_build_object(
    'original_invoice_id', '${sale_id}'::uuid,
    'warehouse_id', '${main_wh}'::uuid,
    'date', current_date,
    'reason', 'Concurrency idempotency test',
    'lines', jsonb_build_array(
      jsonb_build_object(
        'original_invoice_line_id', '${orig_line_id}'::uuid,
        'qty', 3,
        'line_order', 1
      )
    )
  )
"

idem_sql="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_sales_return(
  ${return_payload},
  '${idem_key}'::uuid
);
"

printf 'Running phase_5_returns_concurrency.sh (idempotency) ...\n'

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
    from public.invoices
    where tenant_id = '${tenant_a}'::uuid
      and type = 'sales_return'
      and idempotency_key = '${idem_key}'::uuid;
  "
)"

if [[ "$idem_id1" != "$idem_id2" || "$idem_count" != "1" ]]; then
  printf 'Return idempotency race failed: id1=%s id2=%s count=%s\n' "$idem_id1" "$idem_id2" "$idem_count" >&2
  exit 1
fi

race_payload="
  jsonb_build_object(
    'original_invoice_id', '${sale_id}'::uuid,
    'warehouse_id', '${main_wh}'::uuid,
    'date', current_date,
    'reason', 'Concurrency over-return race',
    'lines', jsonb_build_array(
      jsonb_build_object(
        'original_invoice_line_id', '${orig_line_id}'::uuid,
        'qty', 6,
        'line_order', 1
      )
    )
  )
"

race_a="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_sales_return(
  ${race_payload},
  '${race_key_a}'::uuid
);
"

race_b="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_sales_return(
  ${race_payload},
  '${race_key_b}'::uuid
);
"

printf 'Running phase_5_returns_concurrency.sh (partial return race) ...\n'

docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$race_a" \
  >"$tmpdir/race1" 2>&1 &
pid3=$!
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$race_b" \
  >"$tmpdir/race2" 2>&1 &
pid4=$!

wait "$pid3" || ec3=$?
ec3=${ec3:-0}
wait "$pid4" || ec4=$?
ec4=${ec4:-0}

race_success=$(( (ec3 == 0 ? 1 : 0) + (ec4 == 0 ? 1 : 0) ))
validation_fail=0
if grep -q 'validation_failed' "$tmpdir/race1" 2>/dev/null; then validation_fail=$((validation_fail + 1)); fi
if grep -q 'validation_failed' "$tmpdir/race2" 2>/dev/null; then validation_fail=$((validation_fail + 1)); fi

returned_qty="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
    select coalesce(sum(il.qty), 0)::text
    from public.invoice_lines il
    join public.invoices i on i.id = il.invoice_id
    where i.tenant_id = '${tenant_a}'::uuid
      and i.type = 'sales_return'
      and i.status <> 'cancelled'
      and il.original_invoice_line_id = '${orig_line_id}'::uuid
      and i.idempotency_key in ('${idem_key}'::uuid, '${race_key_a}'::uuid, '${race_key_b}'::uuid);
  "
)"

race_count="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
    select count(*)::text
    from public.invoices
    where tenant_id = '${tenant_a}'::uuid
      and type = 'sales_return'
      and idempotency_key in ('${race_key_a}'::uuid, '${race_key_b}'::uuid);
  "
)"

if [[ "$race_success" -ne 1 || "$validation_fail" -ne 1 || "$returned_qty" != "9.000" || "$race_count" != "1" ]]; then
  printf 'Partial return race failed: success=%s validation=%s returned=%s race_count=%s\n' \
    "$race_success" "$validation_fail" "$returned_qty" "$race_count" >&2
  cat "$tmpdir/race1" "$tmpdir/race2" >&2
  exit 1
fi

test_passed=1
printf 'phase_5_returns_concurrency.sh: passed\n'
