#!/usr/bin/env bash
# Phase 6 M12: concurrent calendar sync smoke test.
# Creates tagged fixtures, runs parallel sync, then removes all tagged rows (always).
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'
marker_prefix="P6M12C-$(date +%s)-$$"
fixture_file="$(mktemp)"
test_passed=0

psql_exec() {
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

discover_stale_markers() {
  psql_exec -t -A <<SQL
select distinct marker
from (
  select substring(p.sku from '^P6M12C-[0-9]+-[0-9]+') as marker
  from public.products p
  where p.tenant_id = '${tenant_a}'::uuid
    and p.sku like 'P6M12C-%'
  union
  select substring(pu.serial_number from '^P6M12C-[0-9]+-[0-9]+') as marker
  from public.product_units pu
  where pu.tenant_id = '${tenant_a}'::uuid
    and pu.serial_number like 'P6M12C-%'
  union
  select replace(cust.name_ar, 'عميل ', '') as marker
  from public.customers cust
  where cust.tenant_id = '${tenant_a}'::uuid
    and cust.name_ar like 'عميل P6M12C-%'
  union
  select replace(csl.name, 'موقع ', '') as marker
  from public.customer_service_locations csl
  where csl.tenant_id = '${tenant_a}'::uuid
    and csl.name like 'موقع P6M12C-%'
) markers
where marker is not null
order by marker;
SQL
}

count_marker_fixtures() {
  local marker="${1:-}"

  if [[ -n "$marker" ]]; then
    psql_exec -t -A -v marker="$marker" <<'SQL'
select jsonb_build_object(
  'products', (select count(*) from public.products where sku like :'marker' || '%'),
  'units', (select count(*) from public.product_units where serial_number like :'marker' || '%'),
  'customers', (select count(*) from public.customers where name_ar like 'عميل ' || :'marker' || '%'),
  'locations', (select count(*) from public.customer_service_locations where name like 'موقع ' || :'marker' || '%'),
  'contracts', (
    select count(distinct c.id)
    from public.contracts c
    left join public.contract_lines cl on cl.contract_id = c.id
    left join public.products p on p.id = cl.product_id
    left join public.product_units pu on pu.id = cl.product_unit_id
    left join public.customers cust on cust.id = c.customer_id
    left join public.customer_service_locations csl on csl.id = c.service_location_id
    where c.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
      and (
        cust.name_ar like 'عميل ' || :'marker' || '%'
        or csl.name like 'موقع ' || :'marker' || '%'
        or p.sku like :'marker' || '%'
        or pu.serial_number like :'marker' || '%'
      )
  ),
  'calendar', (
    select count(*)
    from public.calendar_events ce
    join public.contracts c on c.id = ce.contract_id
    left join public.customers cust on cust.id = c.customer_id
    left join public.customer_service_locations csl on csl.id = c.service_location_id
    left join public.contract_lines cl on cl.contract_id = c.id
    left join public.products p on p.id = cl.product_id
    left join public.product_units pu on pu.id = cl.product_unit_id
    where ce.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
      and (
        cust.name_ar like 'عميل ' || :'marker' || '%'
        or csl.name like 'موقع ' || :'marker' || '%'
        or p.sku like :'marker' || '%'
        or pu.serial_number like :'marker' || '%'
      )
  )
)::text;
SQL
  else
    psql_exec -t -A <<'SQL'
select jsonb_build_object(
  'products', (select count(*) from public.products where sku like 'P6M12C-%'),
  'units', (select count(*) from public.product_units where serial_number like 'P6M12C-%'),
  'customers', (select count(*) from public.customers where name_ar like 'عميل P6M12C-%'),
  'locations', (select count(*) from public.customer_service_locations where name like 'موقع P6M12C-%'),
  'contracts', (
    select count(distinct c.id)
    from public.contracts c
    left join public.contract_lines cl on cl.contract_id = c.id
    left join public.products p on p.id = cl.product_id
    left join public.product_units pu on pu.id = cl.product_unit_id
    left join public.customers cust on cust.id = c.customer_id
    left join public.customer_service_locations csl on csl.id = c.service_location_id
    where c.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
      and (
        cust.name_ar like 'عميل P6M12C-%'
        or csl.name like 'موقع P6M12C-%'
        or p.sku like 'P6M12C-%'
        or pu.serial_number like 'P6M12C-%'
      )
  ),
  'calendar', (
    select count(*)
    from public.calendar_events ce
    join public.contracts c on c.id = ce.contract_id
    left join public.customers cust on cust.id = c.customer_id
    left join public.customer_service_locations csl on csl.id = c.service_location_id
    left join public.contract_lines cl on cl.contract_id = c.id
    left join public.products p on p.id = cl.product_id
    left join public.product_units pu on pu.id = cl.product_unit_id
    where ce.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
      and (
        cust.name_ar like 'عميل P6M12C-%'
        or csl.name like 'موقع P6M12C-%'
        or p.sku like 'P6M12C-%'
        or pu.serial_number like 'P6M12C-%'
      )
  )
)::text;
SQL
  fi
}

cleanup_fixtures() {
  local marker="$1"

  psql_exec -v marker="$marker" <<'SQL' || true
select set_config('test.p6m12.marker', :'marker', false);

do $cleanup$
declare
  v_marker text := current_setting('test.p6m12.marker');
  v_product_ids uuid[] := '{}';
  v_unit_ids uuid[] := '{}';
  v_contract_ids uuid[] := '{}';
  v_line_ids uuid[] := '{}';
  v_customer_ids uuid[] := '{}';
  v_account_ids uuid[] := '{}';
  v_location_ids uuid[] := '{}';
begin
  select coalesce(array_agg(cust.id), '{}'::uuid[])
  into v_customer_ids
  from public.customers cust
  where cust.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and cust.name_ar like 'عميل ' || v_marker || '%';

  select coalesce(array_agg(csl.id), '{}'::uuid[])
  into v_location_ids
  from public.customer_service_locations csl
  where csl.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and csl.name like 'موقع ' || v_marker || '%';

  select coalesce(array_agg(p.id), '{}'::uuid[])
  into v_product_ids
  from public.products p
  where p.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and p.sku like v_marker || '%';

  select coalesce(array_agg(pu.id), '{}'::uuid[])
  into v_unit_ids
  from public.product_units pu
  where pu.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      pu.product_id = any (v_product_ids)
      or pu.serial_number like v_marker || '%'
    );

  select coalesce(array_agg(distinct c.id), '{}'::uuid[])
  into v_contract_ids
  from public.contracts c
  where c.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      c.customer_id = any (v_customer_ids)
      or c.service_location_id = any (v_location_ids)
      or c.id in (
        select cl.contract_id
        from public.contract_lines cl
        where cl.product_id = any (v_product_ids)
           or cl.product_unit_id = any (v_unit_ids)
      )
    );

  select coalesce(array_agg(cl.id), '{}'::uuid[])
  into v_line_ids
  from public.contract_lines cl
  where cl.contract_id = any (v_contract_ids);

  select coalesce(array_agg(distinct cust.account_id), '{}'::uuid[])
  into v_account_ids
  from public.customers cust
  where cust.id = any (v_customer_ids)
    and cust.account_id is not null;

  delete from public.calendar_refill_execution_facts
  where contract_id = any (v_contract_ids);

  delete from public.calendar_deferred_lifecycle_reconciliations
  where contract_id = any (v_contract_ids);

  delete from public.contract_oil_changes
  where contract_id = any (v_contract_ids);

  delete from public.calendar_events
  where contract_id = any (v_contract_ids);

  delete from public.unit_events
  where contract_id = any (v_contract_ids)
     or product_unit_id = any (v_unit_ids);

  delete from public.inventory_movements
  where contract_line_id = any (v_line_ids)
     or product_unit_id = any (v_unit_ids)
     or product_id = any (v_product_ids)
     or reference_id = any (v_contract_ids);

  update public.product_units
  set
    current_contract_id = null,
    current_customer_id = null,
    current_service_location_id = null,
    status = 'available_new',
    updated_at = now()
  where id = any (v_unit_ids);

  perform public.allow_contract_write();

  delete from public.contracts
  where id = any (v_contract_ids);

  delete from public.inventory_balances
  where product_id = any (v_product_ids);

  delete from public.product_units
  where id = any (v_unit_ids);

  delete from public.products
  where id = any (v_product_ids);

  delete from public.customer_service_locations
  where id = any (v_location_ids);

  delete from public.customers
  where id = any (v_customer_ids);

  delete from public.chart_of_accounts
  where id = any (v_account_ids);

  update public.tenant_calendar_settings
  set timezone_name = null
  where tenant_id = '00000000-0000-0000-0000-000000000101'::uuid;
end;
$cleanup$;
SQL
}

verify_no_fixtures() {
  local counts total

  counts="$(count_marker_fixtures)"
  total="$(
    psql_exec -t -A -c "select coalesce(sum(value::int), 0) from jsonb_each_text('${counts}'::jsonb);"
  )"

  if [[ "${total:-0}" != "0" ]]; then
    printf 'M12 concurrency cleanup left P6M12C fixture rows: %s\n' "$counts" >&2
    return 1
  fi

  return 0
}

cleanup() {
  local exit_code=$?

  cleanup_fixtures "$marker_prefix"
  rm -f "$fixture_file"
  verify_no_fixtures || exit_code=1

  if [[ "$test_passed" -eq 1 && "$exit_code" -eq 0 ]]; then
    exit 0
  fi

  exit "$exit_code"
}
trap cleanup EXIT

run_early_cleanup_self_test() {
  local early_marker="${marker_prefix}-EARLY"
  local before after

  printf 'M12 concurrency early-failure cleanup self-test (marker=%s)\n' "$early_marker"

  psql_exec -v marker="$early_marker" <<'SQL'
select set_config('test.p6m12.marker', :'marker', false);

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_marker text := current_setting('test.p6m12.marker');
  v_customer_id uuid;
begin
  v_customer_id := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل ' || v_marker,
      'phone_primary', '+9655' || lpad((extract(epoch from clock_timestamp())::bigint % 10000000)::text, 7, '0')
    )
  );
  perform public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', 'موقع ' || v_marker,
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya'
    )
  );
end $$;
commit;
SQL

  before="$(count_marker_fixtures "$early_marker")"
  if [[ "$(psql_exec -t -A -c "select coalesce(sum(value::int), 0) from jsonb_each_text('${before}'::jsonb);")" == "0" ]]; then
    printf 'Early self-test failed: expected seeded customer/location rows\n' >&2
    exit 1
  fi

  cleanup_fixtures "$early_marker"
  after="$(count_marker_fixtures "$early_marker")"

  if [[ "$(psql_exec -t -A -c "select coalesce(sum(value::int), 0) from jsonb_each_text('${after}'::jsonb);")" != "0" ]]; then
    printf 'Early self-test failed: cleanup left rows %s\n' "$after" >&2
    exit 1
  fi

  printf 'M12 concurrency early-failure cleanup self-test passed.\n'
}

printf 'M12 concurrency: parallel sync (marker=%s)\n' "$marker_prefix"

run_early_cleanup_self_test

while IFS= read -r stale_marker; do
  if [[ -n "$stale_marker" ]]; then
    cleanup_fixtures "$stale_marker"
  fi
done < <(discover_stale_markers)

CONTRACT_ID="$(
  psql_exec -t -A -v marker="$marker_prefix" <<'SQL' | grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' | tail -1
select set_config('test.p6m12.marker', :'marker', false);

begin;
create or replace function pg_temp.p6m12_customer_setup(p_marker text)
returns jsonb language plpgsql as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل ' || p_marker,
      'phone_primary', '+9655' || lpad((extract(epoch from clock_timestamp())::bigint % 10000000)::text, 7, '0')
    )
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', 'موقع ' || p_marker,
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya'
    )
  );
  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p6m12_inventory_setup(p_customers jsonb, p_marker text)
returns jsonb language plpgsql as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_asset_product uuid := gen_random_uuid();
  v_oil_a uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_asset_product, v_tenant_a, p_marker || '-AST-' || left(v_asset_product::text, 8),
    'جهاز M12C', 'M12C Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_oil_a, v_tenant_a, p_marker || '-OIL-' || left(v_oil_a::text, 8),
    'زيت M12C', 'M12C Oil', v_oils_group, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_unit_a, v_tenant_a, v_asset_product, p_marker || '-SN-' || left(v_unit_a::text, 8),
    'available_new', v_main_warehouse, 60.000, current_date
  );

  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_asset_product, 2.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  update public.tenant_calendar_settings tcs
  set timezone_name = 'Asia/Kuwait'
  where tcs.tenant_id = v_tenant_a;

  return p_customers || jsonb_build_object(
    'marker', p_marker,
    'asset_product', v_asset_product,
    'oil_a', v_oil_a,
    'unit_a', v_unit_a
  );
end;
$$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config(
    'test.p6m12.customers',
    pg_temp.p6m12_customer_setup(current_setting('test.p6m12.marker'))::text,
    true
  );
end $$;

set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m12.fixture',
    pg_temp.p6m12_inventory_setup(
      current_setting('test.p6m12.customers')::jsonb,
      current_setting('test.p6m12.marker')
    )::text,
    true
  );
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select public.create_rental_contract(
  jsonb_build_object(
    'customer_id', current_setting('test.p6m12.fixture')::jsonb ->> 'customer_id',
    'service_location_id', current_setting('test.p6m12.fixture')::jsonb ->> 'service_location_id',
    'start_date', current_date,
    'end_date', (current_date + interval '12 months')::date,
    'billing_day', 5,
    'refill_day', 7,
    'monthly_rental_value', '25.000',
    'asset_lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', current_setting('test.p6m12.fixture')::jsonb ->> 'asset_product',
        'product_unit_id', current_setting('test.p6m12.fixture')::jsonb ->> 'unit_a'
      )
    ),
    'consumable_lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', current_setting('test.p6m12.fixture')::jsonb ->> 'oil_a',
        'qty_per_refill', 500.000,
        'refill_frequency_months', 1
      )
    )
  ),
  gen_random_uuid()
);
commit;
SQL
)"

if [[ -z "$CONTRACT_ID" ]]; then
  printf 'Failed to seed rental contract for concurrency test\n' >&2
  exit 1
fi

printf '%s\n' "$CONTRACT_ID" >"$fixture_file"

for _ in 1 2; do
  (
    psql_exec <<SQL
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.sync_tenant_contract_calendar_events(30);
commit;
SQL
  ) &
done
wait

COUNT="$(
  psql_exec -t -A <<SQL
select count(*)
from public.calendar_events
where contract_id = '$CONTRACT_ID'::uuid
  and source_kind = 'contract_generated';
SQL
)"

if [[ "$COUNT" -lt 1 ]]; then
  printf 'Expected generated events after concurrent sync, found %s\n' "$COUNT" >&2
  exit 1
fi

DUP="$(
  psql_exec -t -A <<SQL
select count(*)
from (
  select source_key, count(*) as c
  from public.calendar_events
  where contract_id = '$CONTRACT_ID'::uuid
    and source_kind = 'contract_generated'
  group by source_key
  having count(*) > 1
) d;
SQL
)"

if [[ "$DUP" != "0" ]]; then
  printf 'Duplicate source_key rows after concurrent sync: %s\n' "$DUP" >&2
  exit 1
fi

test_passed=1
printf 'M12 concurrency test passed.\n'
