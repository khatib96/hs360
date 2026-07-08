-- Phase 6 M3: contract creation RPC verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase J.

\set ON_ERROR_STOP on

create or replace function pg_temp.p6m3_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';
  v_customer_id uuid;
  v_location_id uuid;
  v_other_customer_id uuid;
  v_other_location_id uuid;
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_field_tu, 'contracts.create', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  v_customer_id := public.create_customer(
    '{"name_ar":"عميل M3","phone_primary":"+96550007001"}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع M3","location_type":"branch","governorate":"Hawalli","area":"Salmiya","contact_person_phone":"+96550007001"}'::jsonb
  );

  v_other_customer_id := public.create_customer(
    '{"name_ar":"عميل M3 آخر","phone_primary":"+96550007002"}'::jsonb
  );
  v_other_location_id := public.create_customer_service_location(
    v_other_customer_id,
    '{"name":"موقع آخر","location_type":"branch","governorate":"Hawalli","area":"Jabriya"}'::jsonb
  );

  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id,
    'other_customer_id', v_other_customer_id,
    'other_location_id', v_other_location_id
  );
end;
$$;

create or replace function pg_temp.p6m3_inventory_setup(p_customers jsonb)
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
  v_non_serialized_asset uuid := gen_random_uuid();
  v_consumable_product uuid := gen_random_uuid();
  v_consumable_b uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
  v_unit_b uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_asset_product, v_tenant_a, 'P6M3-AST-' || left(v_asset_product::text, 8),
    'جهاز M3', 'M3 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_non_serialized_asset, v_tenant_a, 'P6M3-NS-' || left(v_non_serialized_asset::text, 8),
    'جهاز غير مسلسل', 'M3 Non-serialized Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, false, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_consumable_product, v_tenant_a, 'P6M3-OIL-' || left(v_consumable_product::text, 8),
    'زيت M3', 'M3 Oil', v_oils_group, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_consumable_b, v_tenant_a, 'P6M3-OILB-' || left(v_consumable_b::text, 8),
    'زيت M3 ب', 'M3 Oil B', v_oils_group, 'consumable_rental',
    'ml', 1, 0.020, 0.011, 0.013, false, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values
    (
      v_unit_a, v_tenant_a, v_asset_product, 'P6M3-SN-A-' || left(v_unit_a::text, 8),
      'available_new', v_main_warehouse, 60.000, current_date
    ),
    (
      v_unit_b, v_tenant_a, v_asset_product, 'P6M3-SN-B-' || left(v_unit_b::text, 8),
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
    'non_serialized_asset', v_non_serialized_asset,
    'consumable_product', v_consumable_product,
    'consumable_b', v_consumable_b,
    'unit_a', v_unit_a,
    'unit_b', v_unit_b,
    'main_warehouse', v_main_warehouse
  );
end;
$$;

-- 1. Valid trial creation.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_contract_id uuid;
  v_row public.contracts%rowtype;
  v_unit_status public.unit_status;
  v_movement_type public.movement_type;
  v_qty_trial numeric(15, 3);
begin
  v_contract_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select * into v_row
  from public.contracts
  where id = v_contract_id;

  if v_row.type is distinct from 'trial'::public.contract_type then
    raise exception 'case1 failed: contract type';
  end if;

  if v_row.status is distinct from 'active'::public.contract_status then
    raise exception 'case1 failed: contract status';
  end if;

  if v_row.monthly_rental_value <> 0 then
    raise exception 'case1 failed: monthly_rental_value expected 0';
  end if;

  if v_row.contract_number not like 'CON-%' then
    raise exception 'case1 failed: contract_number format %', v_row.contract_number;
  end if;

  if coalesce(v_row.min_profit_overridden, false) then
    raise exception 'case1 failed: trial should not record override';
  end if;

  select pu.status into v_unit_status
  from public.product_units pu
  where pu.id = (v_fixture ->> 'unit_a')::uuid;

  if v_unit_status is distinct from 'trial'::public.unit_status then
    raise exception 'case1 failed: unit status expected trial';
  end if;

  select movement_type into v_movement_type
  from public.inventory_movements
  where reference_table = 'contracts'
    and reference_id = v_contract_id
  limit 1;

  if v_movement_type is distinct from 'trial_out'::public.movement_type then
    raise exception 'case1 failed: movement type expected trial_out';
  end if;

  select qty_trial into v_qty_trial
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;

  if v_qty_trial < 1 then
    raise exception 'case1 failed: qty_trial bucket not incremented';
  end if;
end $$;
rollback;

-- 2. Valid rental creation.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_contract_id uuid;
  v_row public.contracts%rowtype;
  v_unit_status public.unit_status;
  v_movement_type public.movement_type;
begin
  v_contract_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_b'
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select * into v_row from public.contracts where id = v_contract_id;

  if v_row.type is distinct from 'rental'::public.contract_type then
    raise exception 'case2 failed: contract type';
  end if;

  if v_row.monthly_rental_value <= 0 then
    raise exception 'case2 failed: monthly_rental_value';
  end if;

  if v_row.snapshot_total_monthly_cost <= 0 then
    raise exception 'case2 failed: profit snapshots missing';
  end if;

  select pu.status into v_unit_status
  from public.product_units pu
  where pu.id = (v_fixture ->> 'unit_b')::uuid;

  if v_unit_status is distinct from 'rented'::public.unit_status then
    raise exception 'case2 failed: unit status expected rented';
  end if;

  select movement_type into v_movement_type
  from public.inventory_movements
  where reference_id = v_contract_id
  limit 1;

  if v_movement_type is distinct from 'rental_out'::public.movement_type then
    raise exception 'case2 failed: movement type expected rental_out';
  end if;
end $$;
rollback;

-- 3. Multi-asset rental.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_contract_id uuid;
  v_asset_lines int;
  v_rented_units int;
begin
  v_contract_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 25.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        ),
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_b'
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*)::int into v_asset_lines
  from public.contract_lines
  where contract_id = v_contract_id
    and line_type = 'asset'::public.contract_line_type;

  if v_asset_lines <> 2 then
    raise exception 'case3 failed: expected 2 asset lines got %', v_asset_lines;
  end if;

  select count(*)::int into v_rented_units
  from public.product_units
  where id in (
    (v_fixture ->> 'unit_a')::uuid,
    (v_fixture ->> 'unit_b')::uuid
  )
    and status = 'rented'::public.unit_status;

  if v_rented_units <> 2 then
    raise exception 'case3 failed: expected 2 rented units got %', v_rented_units;
  end if;
end $$;
rollback;

-- 4. Multi-consumable rental.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_contract_id uuid;
  v_consumable_lines int;
  v_oil_changes int;
begin
  v_contract_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 30.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        ),
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_b',
          'qty_per_refill', 300.000,
          'refill_frequency_months', 2
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*)::int into v_consumable_lines
  from public.contract_lines
  where contract_id = v_contract_id
    and line_type = 'consumable'::public.contract_line_type;

  if v_consumable_lines <> 2 then
    raise exception 'case4 failed: expected 2 consumable lines';
  end if;

  select count(*)::int into v_oil_changes
  from public.contract_oil_changes
  where contract_id = v_contract_id;

  if v_oil_changes <> 2 then
    raise exception 'case4 failed: expected 2 contract_oil_changes rows';
  end if;
end $$;
rollback;

-- 5. Asset line without product_unit_id rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
begin
  begin
    perform public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'service_location_id',
        'start_date', current_date,
        'monthly_rental_value', 20.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object('product_id', v_fixture ->> 'asset_product')
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case5a failed: serialized asset without unit accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    perform public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'service_location_id',
        'start_date', current_date,
        'monthly_rental_value', 20.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object('product_id', v_fixture ->> 'non_serialized_asset')
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case5b failed: non-serialized asset without unit accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 6. Unavailable asset rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
begin
  update public.product_units
  set status = 'rented'::public.unit_status
  where id = (v_fixture ->> 'unit_a')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
begin
  begin
    perform public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'service_location_id',
        'start_date', current_date,
        'monthly_rental_value', 20.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case6 failed: unavailable unit accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 7. Service location from another customer rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
begin
  begin
    perform public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'other_location_id',
        'start_date', current_date,
        'monthly_rental_value', 20.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case7 failed: cross-customer location accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 8. Below-min-profit rental rejected for non-manager.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
begin
  begin
    perform public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'service_location_id',
        'start_date', current_date,
        'monthly_rental_value', 12.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          )
        ),
        'consumable_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'consumable_product',
            'qty_per_refill', 500.000,
            'refill_frequency_months', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case8 failed: below-min-profit accepted for field user';
  exception
    when others then
      if sqlerrm not like '%below_min_profit%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 9. Authorized below-min-profit override accepted.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_contract_id uuid;
  v_row public.contracts%rowtype;
begin
  v_contract_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 12.000,
      'request_override', true,
      'override_reason', 'Strategic retention',
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select * into v_row from public.contracts where id = v_contract_id;

  if coalesce(v_row.min_profit_overridden, false) is distinct from true then
    raise exception 'case9 failed: min_profit_overridden expected true';
  end if;
end $$;
rollback;

-- 10. Rental with monthly_rental_value = 0 rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
begin
  begin
    perform public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'service_location_id',
        'start_date', current_date,
        'monthly_rental_value', 0,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case10 failed: zero rental value accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 11. Idempotent retry returns same contract id.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_key uuid := gen_random_uuid();
  v_payload jsonb;
  v_first uuid;
  v_second uuid;
  v_contract_count int;
begin
  v_payload := jsonb_build_object(
    'customer_id', v_fixture ->> 'customer_id',
    'service_location_id', v_fixture ->> 'service_location_id',
    'start_date', current_date,
    'monthly_rental_value', 20.000,
    'asset_lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', v_fixture ->> 'asset_product',
        'product_unit_id', v_fixture ->> 'unit_a'
      )
    )
  );

  v_first := public.create_rental_contract(v_payload, v_key);
  v_second := public.create_rental_contract(v_payload, v_key);

  if v_first is distinct from v_second then
    raise exception 'case11 failed: idempotent retry returned different ids';
  end if;

  select count(*)::int into v_contract_count
  from public.contracts
  where idempotency_key = v_key;

  if v_contract_count <> 1 then
    raise exception 'case11 failed: duplicate contracts for same idempotency key';
  end if;
end $$;
rollback;

-- 12. Idempotency payload mismatch.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_key uuid := gen_random_uuid();
begin
  perform public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      )
    ),
    v_key
  );

  begin
    perform public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'service_location_id',
        'start_date', current_date,
        'monthly_rental_value', 21.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          )
        )
      ),
      v_key
    );
    raise exception 'case12 failed: payload mismatch accepted';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 13. Unit pointers updated together.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_contract_id uuid;
  v_unit public.product_units%rowtype;
begin
  v_contract_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      )
    ),
    gen_random_uuid()
  );

  select * into v_unit
  from public.product_units
  where id = (v_fixture ->> 'unit_a')::uuid;

  if v_unit.current_contract_id is distinct from v_contract_id then
    raise exception 'case13 failed: current_contract_id';
  end if;

  if v_unit.current_customer_id is distinct from (v_fixture ->> 'customer_id')::uuid then
    raise exception 'case13 failed: current_customer_id';
  end if;

  if v_unit.current_service_location_id is distinct from (v_fixture ->> 'service_location_id')::uuid then
    raise exception 'case13 failed: current_service_location_id';
  end if;
end $$;
rollback;

-- 14. Inventory balance buckets correct.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_qty_available numeric(15, 3);
  v_qty_rented numeric(15, 3);
begin
  perform public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      )
    ),
    gen_random_uuid()
  );

  select qty_available, qty_rented
  into v_qty_available, v_qty_rented
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;

  if v_qty_available <> 1.000 then
    raise exception 'case14 failed: qty_available expected 1 got %', v_qty_available;
  end if;

  if v_qty_rented <> 1.000 then
    raise exception 'case14 failed: qty_rented expected 1 got %', v_qty_rented;
  end if;
end $$;
rollback;

-- 15. Unauthorized user cannot create contracts.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
begin
  begin
    perform public.create_trial_contract(
      jsonb_build_object(
        'customer_id', v_fixture ->> 'customer_id',
        'service_location_id', v_fixture ->> 'service_location_id',
        'start_date', current_date,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case15 failed: unauthorized user created contract';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 16. Trial ignores profit gate.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m3.customers', pg_temp.p6m3_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m3.fixture',
    pg_temp.p6m3_inventory_setup(current_setting('test.p6m3.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m3.fixture')::jsonb;
  v_contract_id uuid;
  v_row public.contracts%rowtype;
begin
  v_contract_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select * into v_row from public.contracts where id = v_contract_id;

  if v_row.id is null then
    raise exception 'case16 failed: trial contract not created';
  end if;

  if coalesce(v_row.min_profit_overridden, false) then
    raise exception 'case16 failed: trial recorded override';
  end if;

  if v_row.monthly_rental_value <> 0 then
    raise exception 'case16 failed: trial monthly_rental_value not zero';
  end if;
end $$;
rollback;
