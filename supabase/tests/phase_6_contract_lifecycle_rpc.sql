\set ON_ERROR_STOP on

-- Phase 6 M4: lifecycle RPC verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase K.

create or replace function pg_temp.p6m4_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    '{"name_ar":"عميل M4","phone_primary":"+96550008001","create_account":true}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع M4","location_type":"branch","governorate":"Hawalli","area":"Salmiya","contact_person_phone":"+96550008001"}'::jsonb
  );

  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p6m4_inventory_setup(p_customers jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_asset_product uuid := gen_random_uuid();
  v_consumable_product uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
  v_unit_b uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_asset_product, v_tenant_a, 'P6M4-AST-' || left(v_asset_product::text, 8),
    'جهاز M4', 'M4 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_consumable_product, v_tenant_a, 'P6M4-OIL-' || left(v_consumable_product::text, 8),
    'زيت M4', 'M4 Oil', v_oils_group, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values
    (
      v_unit_a, v_tenant_a, v_asset_product, 'P6M4-SN-A-' || left(v_unit_a::text, 8),
      'available_new', v_main_warehouse, 60.000, current_date
    ),
    (
      v_unit_b, v_tenant_a, v_asset_product, 'P6M4-SN-B-' || left(v_unit_b::text, 8),
      'available_new', v_main_warehouse, 48.000, current_date
    );

  insert into public.inventory_balances (
    tenant_id, warehouse_id, product_id, qty_available
  )
  values
    (v_tenant_a, v_main_warehouse, v_asset_product, 2.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  return p_customers || jsonb_build_object(
    'asset_product', v_asset_product,
    'consumable_product', v_consumable_product,
    'unit_a', v_unit_a,
    'unit_b', v_unit_b,
    'main_warehouse', v_main_warehouse
  );
end;
$$;

-- 1. Convert trial to rental successfully.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m4.fixture',
    pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_rental_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a')
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'consumable_product', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );

  v_rental_id := public.convert_trial_to_rental(
    jsonb_build_object(
      'trial_contract_id', v_trial_id,
      'monthly_rental_value', 20.000
    ),
    gen_random_uuid()
  );

  if v_rental_id is null then
    raise exception 'case1 failed: convert returned null id';
  end if;
end $$;
rollback;

-- 2. Conversion links trial and rental records.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_rental_id uuid;
  v_trial public.contracts%rowtype;
  v_rental public.contracts%rowtype;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  v_rental_id := public.convert_trial_to_rental(
    jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
    gen_random_uuid()
  );
  select * into v_trial from public.contracts where id = v_trial_id;
  select * into v_rental from public.contracts where id = v_rental_id;
  if v_trial.converted_to_contract_id is distinct from v_rental_id
    or v_rental.converted_from_contract_id is distinct from v_trial_id then
    raise exception 'case2 failed: conversion links missing';
  end if;
end $$;
rollback;

-- 3. Conversion moves unit status trial -> rented.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_unit public.product_units%rowtype;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.convert_trial_to_rental(
    jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
    gen_random_uuid()
  );
  select * into v_unit from public.product_units where id = (v_fixture ->> 'unit_a')::uuid;
  if v_unit.status <> 'rented'::public.unit_status then
    raise exception 'case3 failed: unit not rented';
  end if;
end $$;
rollback;

-- 4. Conversion moves inventory qty_trial -> qty_rented.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_balance public.inventory_balances%rowtype;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.convert_trial_to_rental(
    jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
    gen_random_uuid()
  );
  select * into v_balance
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;
  if v_balance.qty_trial <> 0 or v_balance.qty_rented <> 1 then
    raise exception 'case4 failed: expected qty_trial=0 and qty_rented=1';
  end if;
end $$;
rollback;

-- 5. Conversion rejects already converted trial.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.convert_trial_to_rental(
    jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
    gen_random_uuid()
  );
  begin
    perform public.convert_trial_to_rental(
      jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
      gen_random_uuid()
    );
    raise exception 'case5 failed: second conversion accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 6. Conversion rejects non-trial contract.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_rental_id uuid;
begin
  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  begin
    perform public.convert_trial_to_rental(
      jsonb_build_object('trial_contract_id', v_rental_id, 'monthly_rental_value', 20.000),
      gen_random_uuid()
    );
    raise exception 'case6 failed: non-trial conversion accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 6b. Conversion rejects trial unit not linked to trial contract.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_other_trial_id uuid;
  v_trial_id uuid;
begin
  v_other_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_b'))
    ),
    gen_random_uuid()
  );
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform set_config('test.p6m4.trial_id', v_trial_id::text, true);
  perform set_config('test.p6m4.other_trial_id', v_other_trial_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_other_trial_id uuid := current_setting('test.p6m4.other_trial_id')::uuid;
begin
  update public.product_units
  set current_contract_id = v_other_trial_id
  where id = (v_fixture ->> 'unit_a')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_trial_id uuid := current_setting('test.p6m4.trial_id')::uuid;
begin
  begin
    perform public.convert_trial_to_rental(
      jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
      gen_random_uuid()
    );
    raise exception 'case6b failed: conversion accepted unit not on trial';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 6c. Conversion rejects end_date before rental start.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  begin
    perform public.convert_trial_to_rental(
      jsonb_build_object(
        'trial_contract_id', v_trial_id,
        'monthly_rental_value', 20.000,
        'end_date', current_date - 1
      ),
      gen_random_uuid()
    );
    raise exception 'case6c failed: past end_date accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 7. Conversion below-min-profit rejected unless override.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
  update public.tenant_settings
  set min_monthly_profit = 1000
  where tenant_id = '00000000-0000-0000-0000-000000000101';
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  begin
    perform public.convert_trial_to_rental(
      jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
      gen_random_uuid()
    );
    raise exception 'case7 failed: below-min-profit accepted without override';
  exception when others then
    if sqlerrm not like '%below_min_profit%' then
      raise;
    end if;
  end;

  perform public.convert_trial_to_rental(
    jsonb_build_object(
      'trial_contract_id', v_trial_id,
      'monthly_rental_value', 20.000,
      'request_override', true,
      'override_reason', 'approved for M4 test'
    ),
    gen_random_uuid()
  );
end $$;
rollback;

-- 8. Extend trial succeeds with reason.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_row public.contracts%rowtype;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'trial_days', 5,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.extend_trial_contract(
    jsonb_build_object(
      'trial_contract_id', v_trial_id,
      'new_trial_end_date', current_date + 30,
      'reason', 'customer requested more time'
    ),
    gen_random_uuid()
  );
  select * into v_row from public.contracts where id = v_trial_id;
  if v_row.trial_end_date <> current_date + 30 then
    raise exception 'case8 failed: trial_end_date not updated';
  end if;
end $$;
rollback;

-- 9. Extend trial rejects missing reason.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'trial_days', 5,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  begin
    perform public.extend_trial_contract(
      jsonb_build_object(
        'trial_contract_id', v_trial_id,
        'new_trial_end_date', current_date + 10,
        'reason', ''
      ),
      gen_random_uuid()
    );
    raise exception 'case9 failed: missing reason accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 10. Extend trial rejects date not after current trial_end_date.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_row public.contracts%rowtype;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'trial_days', 5,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  select * into v_row from public.contracts where id = v_trial_id;
  begin
    perform public.extend_trial_contract(
      jsonb_build_object(
        'trial_contract_id', v_trial_id,
        'new_trial_end_date', v_row.trial_end_date,
        'reason', 'invalid date'
      ),
      gen_random_uuid()
    );
    raise exception 'case10 failed: non-forward date accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 11. Return trial succeeds and releases unit.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_unit public.product_units%rowtype;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.return_trial_contract(
    jsonb_build_object(
      'trial_contract_id', v_trial_id,
      'return_condition', 'available_used',
      'reason', 'not continuing'
    ),
    gen_random_uuid()
  );
  select * into v_unit from public.product_units where id = (v_fixture ->> 'unit_a')::uuid;
  if v_unit.status <> 'available_used'::public.unit_status
    or v_unit.current_contract_id is not null then
    raise exception 'case11 failed: unit not released';
  end if;
end $$;
rollback;

-- 12. Return trial rejects converted trial.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.convert_trial_to_rental(
    jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000),
    gen_random_uuid()
  );
  begin
    perform public.return_trial_contract(
      jsonb_build_object('trial_contract_id', v_trial_id, 'return_condition', 'available_used', 'reason', 'too late'),
      gen_random_uuid()
    );
    raise exception 'case12 failed: returned converted trial';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 13. Close rental succeeds and releases units.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_rental_id uuid;
  v_unit public.product_units%rowtype;
begin
  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_rental_id,
      'closure_type', 'normal',
      'close_reason', 'normal closure',
      'return_condition', 'available_used'
    ),
    gen_random_uuid()
  );
  select * into v_unit from public.product_units where id = (v_fixture ->> 'unit_a')::uuid;
  if v_unit.status <> 'available_used'::public.unit_status then
    raise exception 'case13 failed: unit not released';
  end if;
end $$;
rollback;

-- 14. Close rental keeps outstanding invoices/customer debt untouched.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_fixture jsonb;
  v_supplier uuid;
  v_sale_product uuid;
begin
  v_fixture := pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb);
  perform set_config('test.p6m4.fixture', v_fixture::text, true);

  v_supplier := public.create_supplier(jsonb_build_object('name_ar', 'مورد M4-14', 'create_account', true));
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M4-SALE-' || left(gen_random_uuid()::text, 8),
    'منتج بيع M4', 'M4 Sale Product', v_oils_group, 'sale_only',
    'piece', 10, 0, false, true, v_owner
  )
  returning id into v_sale_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_sale_product, 'qty', 10, 'unit_price', 3.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_rental_id uuid;
  v_invoice_id uuid;
  v_status public.invoice_status;
  v_total numeric(15, 3);
  v_paid numeric(15, 3);
  v_je_count_before int;
  v_je_count_after int;
begin
  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );

  v_invoice_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'warehouse_id', v_fixture ->> 'main_warehouse',
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', (select id::text from public.products where sku like 'M4-SALE-%' order by created_at desc limit 1),
          'qty', 1,
          'unit_price', 10.000,
          'discount_pct', 0,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select status, total, paid_amount into v_status, v_total, v_paid
  from public.invoices where id = v_invoice_id;
  select count(*)::int into v_je_count_before from public.journal_entries where source = 'rental_invoice';

  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_rental_id,
      'closure_type', 'normal',
      'close_reason', 'closed with debt',
      'return_condition', 'available_used'
    ),
    gen_random_uuid()
  );

  if exists (
    select 1 from public.invoices i
    where i.id = v_invoice_id
      and (i.status is distinct from v_status or i.total is distinct from v_total or i.paid_amount is distinct from v_paid)
  ) then
    raise exception 'case14 failed: invoice mutated by close';
  end if;

  select count(*)::int into v_je_count_after from public.journal_entries where source = 'rental_invoice';
  if v_je_count_after <> v_je_count_before then
    raise exception 'case14 failed: close altered rental_invoice journal entries';
  end if;
end $$;
rollback;

-- 15. Close rental rejects already closed contract.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_rental_id uuid;
begin
  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.close_contract(
    jsonb_build_object('contract_id', v_rental_id, 'closure_type', 'normal', 'close_reason', 'closed', 'return_condition', 'available_used'),
    gen_random_uuid()
  );
  begin
    perform public.close_contract(
      jsonb_build_object('contract_id', v_rental_id, 'closure_type', 'normal', 'close_reason', 'closed again', 'return_condition', 'available_used'),
      gen_random_uuid()
    );
    raise exception 'case15 failed: already closed accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 16-19. Unauthorized user rejected for each lifecycle operation.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_rental_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_b'))
    ),
    gen_random_uuid()
  );
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000202', true);

  begin
    perform public.convert_trial_to_rental(jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000), gen_random_uuid());
    raise exception 'case16 failed: unauthorized convert accepted';
  exception when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
  begin
    perform public.extend_trial_contract(jsonb_build_object('trial_contract_id', v_trial_id, 'new_trial_end_date', current_date + 20, 'reason', 'x'), gen_random_uuid());
    raise exception 'case17 failed: unauthorized extend accepted';
  exception when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
  begin
    perform public.return_trial_contract(jsonb_build_object('trial_contract_id', v_trial_id, 'return_condition', 'available_used', 'reason', 'x'), gen_random_uuid());
    raise exception 'case18 failed: unauthorized return accepted';
  exception when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
  begin
    perform public.close_contract(jsonb_build_object('contract_id', v_rental_id, 'closure_type', 'normal', 'close_reason', 'x', 'return_condition', 'available_used'), gen_random_uuid());
    raise exception 'case19 failed: unauthorized close accepted';
  exception when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- 20. Idempotent retry returns same result.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_key uuid := gen_random_uuid();
  v_a uuid;
  v_b uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  v_a := public.convert_trial_to_rental(jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000), v_key);
  v_b := public.convert_trial_to_rental(jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000), v_key);
  if v_a is distinct from v_b then
    raise exception 'case20 failed: idempotent retry changed result';
  end if;
end $$;
rollback;

-- 21. Idempotency payload mismatch raises idempotency_payload_mismatch.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_key uuid := gen_random_uuid();
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.convert_trial_to_rental(jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 20.000), v_key);
  begin
    perform public.convert_trial_to_rental(jsonb_build_object('trial_contract_id', v_trial_id, 'monthly_rental_value', 21.000), v_key);
    raise exception 'case21 failed: mismatch accepted';
  exception when others then
    if sqlerrm not like '%idempotency_payload_mismatch%' then raise; end if;
  end;
end $$;
rollback;

-- 22. Direct client contract status update remains blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  begin
    perform set_config('hs360.contract_write', '', true);
    update public.contracts set status = 'completed' where id = v_trial_id;
    raise exception 'case22 failed: direct status update allowed';
  exception when others then
    if sqlerrm not like '%direct_write_forbidden%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 23. Lost explicit from trial and rented.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
  v_trial_id uuid;
  v_rental_id uuid;
  v_balance public.inventory_balances%rowtype;
  v_unit public.product_units%rowtype;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'))
    ),
    gen_random_uuid()
  );
  perform public.return_trial_contract(
    jsonb_build_object('trial_contract_id', v_trial_id, 'return_condition', 'lost', 'reason', 'lost during trial'),
    gen_random_uuid()
  );
  select * into v_balance from public.inventory_balances where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid and product_id = (v_fixture ->> 'asset_product')::uuid;
  select * into v_unit from public.product_units where id = (v_fixture ->> 'unit_a')::uuid;
  if v_balance.qty_available <> 1 or v_balance.qty_trial <> 0 or v_balance.qty_maintenance <> 0 or v_balance.qty_damaged <> 0 then
    raise exception 'case23 failed: trial lost bucket movement incorrect';
  end if;
  if v_unit.status <> 'lost'::public.unit_status or v_unit.current_contract_id is not null then
    raise exception 'case23 failed: trial lost unit state incorrect';
  end if;

  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_b'))
    ),
    gen_random_uuid()
  );
  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_rental_id,
      'closure_type', 'normal',
      'close_reason', 'lost on close',
      'return_condition', 'lost'
    ),
    gen_random_uuid()
  );
  select * into v_balance from public.inventory_balances where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid and product_id = (v_fixture ->> 'asset_product')::uuid;
  select * into v_unit from public.product_units where id = (v_fixture ->> 'unit_b')::uuid;
  if v_balance.qty_rented <> 0 or v_balance.qty_available <> 0 or v_balance.qty_maintenance <> 0 or v_balance.qty_damaged <> 0 then
    raise exception 'case23 failed: rented lost bucket movement incorrect';
  end if;
  if v_unit.status <> 'lost'::public.unit_status or v_unit.current_contract_id is not null then
    raise exception 'case23 failed: rented lost unit state incorrect';
  end if;
end $$;
rollback;

-- 24. Product_units direct write baseline (non-blocking).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m4.customers', pg_temp.p6m4_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config('test.p6m4.fixture', pg_temp.p6m4_inventory_setup(current_setting('test.p6m4.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m4.fixture')::jsonb;
begin
  begin
    update public.product_units
    set status = 'maintenance'::public.unit_status, current_contract_id = null
    where id = (v_fixture ->> 'unit_a')::uuid;
    raise notice 'case24 notice: direct product_units update allowed (baseline only; out of M4 scope).';
  exception when others then
    raise notice 'case24 notice: direct product_units update blocked by existing rules: %', sqlerrm;
  end;
end $$;
rollback;
