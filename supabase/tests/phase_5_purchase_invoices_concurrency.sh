#!/usr/bin/env bash
# Parallel purchase invoice idempotency + concurrent WAC on same product.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'
main_wh='00000000-0000-0000-0000-000000000701'
oils_group='00000000-0000-0000-0000-000000000802'
idem_key='00000000-0000-0000-0000-00000000c001'
idem_key_c='00000000-0000-0000-0000-00000000c003'
idem_key_d='00000000-0000-0000-0000-00000000c004'

tmpdir="$(mktemp -d)"
test_passed=0
state_ready=0
setup_ready=0
supplier_id=''
idem_product_id=''
wac_product_id=''
prior_tax_enabled=''
prior_default_tax_rate_id=''
prior_tax_updated_at=''
prior_pi_next=''
prior_pi_updated_at=''
prior_je_next=''
prior_je_updated_at=''
prior_audit_max=''

cleanup() {
  local exit_code=$?
  local cleanup_exit=0

  if [[ "$state_ready" -eq 1 && "$setup_ready" -eq 1 ]]; then
    docker exec -i "$container_name" psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 \
      -v supplier_id="$supplier_id" \
      -v idem_product_id="$idem_product_id" \
      -v wac_product_id="$wac_product_id" <<SQL || cleanup_exit=$?
begin;

create temp table m5_test_invoices on commit drop as
select id, journal_entry_id
from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and idempotency_key in (
    '${idem_key}'::uuid, '${idem_key_c}'::uuid, '${idem_key_d}'::uuid
  );

alter table public.journal_lines disable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries disable trigger trg_enforce_posted_journal_entry_immutability;

delete from public.journal_lines
where journal_entry_id in (
  select journal_entry_id
  from m5_test_invoices
  where journal_entry_id is not null
);

delete from public.inventory_movements
where tenant_id = '${tenant_a}'::uuid
  and reference_table = 'purchase_invoice'
  and reference_id in (select id from m5_test_invoices);

delete from public.product_units
where tenant_id = '${tenant_a}'::uuid
  and purchase_invoice_id in (select id from m5_test_invoices);

delete from public.invoice_lines
where tenant_id = '${tenant_a}'::uuid
  and invoice_id in (select id from m5_test_invoices);

delete from public.invoices
where tenant_id = '${tenant_a}'::uuid
  and id in (select id from m5_test_invoices);

delete from public.journal_entries
where tenant_id = '${tenant_a}'::uuid
  and id in (
    select journal_entry_id
    from m5_test_invoices
    where journal_entry_id is not null
  );

delete from public.inventory_balances
where tenant_id = '${tenant_a}'::uuid
  and product_id in (:'idem_product_id'::uuid, :'wac_product_id'::uuid);

delete from public.products
where tenant_id = '${tenant_a}'::uuid
  and id in (:'idem_product_id'::uuid, :'wac_product_id'::uuid);

create temp table m5_cleanup_accounts on commit drop as
select account_id
from public.suppliers
where id = :'supplier_id'::uuid;

delete from public.suppliers
where tenant_id = '${tenant_a}'::uuid
  and id = :'supplier_id'::uuid;

delete from public.chart_of_accounts
where tenant_id = '${tenant_a}'::uuid
  and id in (select account_id from m5_cleanup_accounts);

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
set next_value = ${prior_pi_next}, updated_at = '${prior_pi_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'PI';

update public.document_sequences
set next_value = ${prior_je_next}, updated_at = '${prior_je_updated_at}'::timestamptz
where tenant_id = '${tenant_a}'::uuid and sequence_key = 'JE';

delete from public.audit_log
where tenant_id = '${tenant_a}'::uuid
  and id > ${prior_audit_max};

do \$\$
begin
  if exists (
    select 1
    from public.invoices
    where tenant_id = '${tenant_a}'::uuid
      and idempotency_key in (
        '${idem_key}'::uuid, '${idem_key_c}'::uuid, '${idem_key_d}'::uuid
      )
  ) or exists (
    select 1
    from public.journal_entries
    where tenant_id = '${tenant_a}'::uuid
      and id in (
        select journal_entry_id
        from m5_test_invoices
        where journal_entry_id is not null
      )
  ) or exists (
    select 1
    from public.products
    where id in ('${idem_product_id}'::uuid, '${wac_product_id}'::uuid)
  ) or exists (
    select 1 from public.suppliers where id = '${supplier_id}'::uuid
  ) then
    raise exception 'm5_concurrency_cleanup_failed';
  end if;

  if not exists (
    select 1
    from public.tenant_settings
    where tenant_id = '${tenant_a}'::uuid
      and tax_enabled = ${prior_tax_enabled}
      and default_tax_rate_id is not distinct from nullif('${prior_default_tax_rate_id}', '')::uuid
      and updated_at = '${prior_tax_updated_at}'::timestamptz
  ) then
    raise exception 'm5_concurrency_settings_restore_failed';
  end if;

  if not exists (
    select 1
    from public.document_sequences
    where tenant_id = '${tenant_a}'::uuid
      and sequence_key = 'PI'
      and next_value = ${prior_pi_next}
      and updated_at = '${prior_pi_updated_at}'::timestamptz
  ) or not exists (
    select 1
    from public.document_sequences
    where tenant_id = '${tenant_a}'::uuid
      and sequence_key = 'JE'
      and next_value = ${prior_je_next}
      and updated_at = '${prior_je_updated_at}'::timestamptz
  ) then
    raise exception 'm5_concurrency_sequence_restore_failed';
  end if;
end;
\$\$;

commit;
SQL
  fi

  rm -rf "$tmpdir"

  if [[ "$cleanup_exit" -ne 0 ]]; then
    printf 'phase_5_purchase_invoices_concurrency.sh: cleanup failed\n' >&2
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
        pi.next_value::text,
        pi.updated_at::text,
        je.next_value::text,
        je.updated_at::text,
        coalesce((select max(id) from public.audit_log where tenant_id = ts.tenant_id), 0)::text
      from public.tenant_settings ts
      join public.document_sequences pi
        on pi.tenant_id = ts.tenant_id and pi.sequence_key = 'PI'
      join public.document_sequences je
        on je.tenant_id = ts.tenant_id and je.sequence_key = 'JE'
      where ts.tenant_id = '${tenant_a}'::uuid;
    "
)"
IFS='|' read -r \
  prior_tax_enabled \
  prior_default_tax_rate_id \
  prior_tax_updated_at \
  prior_pi_next \
  prior_pi_updated_at \
  prior_je_next \
  prior_je_updated_at \
  prior_audit_max <<<"$initial_state"

if [[ -z "$prior_tax_enabled" || -z "$prior_tax_updated_at" \
  || -z "$prior_pi_next" || -z "$prior_pi_updated_at" \
  || -z "$prior_je_next" || -z "$prior_je_updated_at" \
  || -z "$prior_audit_max" ]]; then
  printf 'Concurrency state capture failed: %s\n' "$initial_state" >&2
  exit 1
fi
state_ready=1

setup_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.update_tax_settings(jsonb_build_object('tax_enabled', false));
with supplier as (
  select public.create_supplier(
    jsonb_build_object('name_ar', 'مورد تزامن', 'create_account', true)
  ) as id
),
idem_product as (
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  select
    '${tenant_a}'::uuid,
    'M5-CONCUR-IDEM-' || substr(gen_random_uuid()::text, 1, 8),
    'زيت تزامن', 'Idempotency Oil', '${oils_group}'::uuid, 'consumable_rental',
    'ml', 5.000, 0, false, '${owner_sub}'::uuid
  returning id
),
wac_product as (
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  select
    '${tenant_a}'::uuid,
    'M5-CONCUR-WAC-' || substr(gen_random_uuid()::text, 1, 8),
    'زيت واك', 'WAC Oil', '${oils_group}'::uuid, 'consumable_rental',
    'ml', 5.000, 0, false, '${owner_sub}'::uuid
  returning id
)
select
  supplier.id::text || ',' ||
  idem_product.id::text || ',' ||
  wac_product.id::text
from supplier,
idem_product,
wac_product;
commit;
"

setup_ids="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$setup_sql" \
    | grep -E '^[0-9a-f-]{36},[0-9a-f-]{36},[0-9a-f-]{36}$' \
    | tail -1
)"
IFS=',' read -r supplier_id idem_product_id wac_product_id <<<"$setup_ids"

if [[ -z "$supplier_id" || -z "$idem_product_id" || -z "$wac_product_id" ]]; then
  printf 'Concurrency setup failed: supplier=%s idem_product=%s wac_product=%s\n' \
    "$supplier_id" "$idem_product_id" "$wac_product_id" >&2
  exit 1
fi
setup_ready=1

purchase_payload="
  jsonb_build_object(
    'supplier_id', '${supplier_id}'::uuid,
    'date', current_date,
    'due_date', current_date + 30,
    'warehouse_id', '${main_wh}'::uuid,
    'lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', '${idem_product_id}'::uuid,
        'qty', 10,
        'unit_price', 4.000,
        'discount_pct', 0,
        'line_order', 1
      )
    )
  )
"

idem_sql="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_purchase_invoice(
  ${purchase_payload},
  '${idem_key}'::uuid
);
"

printf 'Running phase_5_purchase_invoices_concurrency.sh (idempotency) ...\n'

docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$idem_sql" \
  >"$tmpdir/out1" 2>&1 &
pid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "$idem_sql" \
  >"$tmpdir/out2" 2>&1 &
pid2=$!

wait "$pid1" || ec1=$?
ec1=${ec1:-0}
wait "$pid2" || ec2=$?
ec2=${ec2:-0}

invoice_count="$(
  docker exec -i "$container_name" psql -U postgres -d postgres -At -c "
    select count(*) from public.invoices
    where tenant_id = '${tenant_a}'::uuid and idempotency_key = '${idem_key}'::uuid;
  "
)"

id1="$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$tmpdir/out1" | tail -1 || true)"
id2="$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$tmpdir/out2" | tail -1 || true)"

if [[ "$invoice_count" != "1" ]]; then
  printf 'Idempotency concurrency failed: expected 1 invoice, got %s\n' "$invoice_count" >&2
  cat "$tmpdir/out1" >&2 || true
  cat "$tmpdir/out2" >&2 || true
  exit 1
fi

if [[ -z "$id1" || -z "$id2" || "$id1" != "$id2" ]]; then
  printf 'Idempotency concurrency failed: returned ids differ (%s vs %s)\n' "$id1" "$id2" >&2
  exit 1
fi

printf 'Idempotency concurrency passed.\n'

# Concurrent purchases on same product (different idempotency keys)
purchase_a="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_purchase_invoice(
  jsonb_build_object(
    'supplier_id', '${supplier_id}'::uuid,
    'date', current_date,
    'warehouse_id', '${main_wh}'::uuid,
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', '${wac_product_id}'::uuid, 'qty', 5, 'unit_price', 2.000,
      'discount_pct', 0, 'line_order', 1))
  ),
  '${idem_key_c}'::uuid
);
"

purchase_b="
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.record_purchase_invoice(
  jsonb_build_object(
    'supplier_id', '${supplier_id}'::uuid,
    'date', current_date,
    'warehouse_id', '${main_wh}'::uuid,
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', '${wac_product_id}'::uuid, 'qty', 3, 'unit_price', 6.000,
      'discount_pct', 0, 'line_order', 1))
  ),
  '${idem_key_d}'::uuid
);
"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$purchase_a" >"$tmpdir/wac1" 2>&1 &
pid3=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$purchase_b" >"$tmpdir/wac2" 2>&1 &
pid4=$!

wait "$pid3" || ec3=$?
ec3=${ec3:-0}
wait "$pid4" || ec4=$?
ec4=${ec4:-0}

if [[ "$ec3" -ne 0 || "$ec4" -ne 0 ]]; then
  printf 'WAC concurrency posting failed: exits %s and %s\n' "$ec3" "$ec4" >&2
  cat "$tmpdir/wac1" >&2 || true
  cat "$tmpdir/wac2" >&2 || true
  exit 1
fi

wac="$(docker exec -i "$container_name" psql -U postgres -d postgres -At -c "
  select avg_cost from public.products where id = '${wac_product_id}'::uuid;
")"
qty="$(docker exec -i "$container_name" psql -U postgres -d postgres -At -c "
  select qty_available from public.inventory_balances
  where product_id = '${wac_product_id}'::uuid and warehouse_id = '${main_wh}'::uuid;
")"

# Sequential expectation for 5@2 + 3@6 on empty product: WAC = 28/8 = 3.500, qty = 8
if [[ "$qty" != "8.000" && "$qty" != "8" ]]; then
  printf 'WAC concurrency failed: qty %s expected 8\n' "$qty" >&2
  cat "$tmpdir/wac1" >&2 || true
  cat "$tmpdir/wac2" >&2 || true
  exit 1
fi

if [[ "$wac" != "3.500" ]]; then
  printf 'WAC concurrency failed: avg_cost %s expected 3.500\n' "$wac" >&2
  cat "$tmpdir/wac1" >&2 || true
  cat "$tmpdir/wac2" >&2 || true
  exit 1
fi

test_passed=1
printf 'phase_5_purchase_invoices_concurrency.sh: passed\n'
