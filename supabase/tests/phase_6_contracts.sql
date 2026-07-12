\set ON_ERROR_STOP on

-- Phase 6 M13: consolidated gap-fill verification (6 cases only).
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase N.

create or replace function pg_temp.p6m13_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    '{"name_ar":"عميل P6M13","phone_primary":"+96550009201","create_account":true}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع P6M13","location_type":"branch","governorate":"Hawalli","area":"Salmiya","contact_person_phone":"+96550009201"}'::jsonb
  );

  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p6m13_inventory_setup(p_customers jsonb)
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
    v_asset_product, v_tenant_a, 'P6M13-AST-' || left(v_asset_product::text, 8),
    'جهاز P6M13', 'P6M13 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values
    (
      v_consumable_product, v_tenant_a, 'P6M13-OIL-A-' || left(v_consumable_product::text, 8),
      'زيت P6M13 A', 'P6M13 Oil A', v_oils_group, 'consumable_rental',
      'ml', 1, 0.015, 0.010, 0.012, false, v_owner
    ),
    (
      v_consumable_b, v_tenant_a, 'P6M13-OIL-B-' || left(v_consumable_b::text, 8),
      'زيت P6M13 B', 'P6M13 Oil B', v_oils_group, 'consumable_rental',
      'ml', 1, 0.020, 0.013, 0.014, false, v_owner
    );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values
    (
      v_unit_a, v_tenant_a, v_asset_product, 'P6M13-SN-A-' || left(v_unit_a::text, 8),
      'available_new', v_main_warehouse, 60.000, current_date
    ),
    (
      v_unit_b, v_tenant_a, v_asset_product, 'P6M13-SN-B-' || left(v_unit_b::text, 8),
      'available_new', v_main_warehouse, 48.000, current_date
    );

  insert into public.inventory_balances (
    tenant_id, warehouse_id, product_id, qty_available
  )
  values (v_tenant_a, v_main_warehouse, v_asset_product, 2.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  return p_customers || jsonb_build_object(
    'asset_product', v_asset_product,
    'consumable_product', v_consumable_product,
    'consumable_b', v_consumable_b,
    'unit_a', v_unit_a,
    'unit_b', v_unit_b,
    'main_warehouse', v_main_warehouse
  );
end;
$$;

create or replace function pg_temp.p6m13_fixture_setup()
returns jsonb
language plpgsql
as $$
begin
  return pg_temp.p6m13_inventory_setup(pg_temp.p6m13_customer_setup());
end;
$$;

create or replace function pg_temp.p6m13_insert_open_rental_invoice(
  p_fixture jsonb,
  p_contract_id uuid,
  p_invoice_number text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_invoice_id uuid := gen_random_uuid();
  v_period_start date := date_trunc('month', current_date)::date;
  v_period_end date := (date_trunc('month', current_date) + interval '1 month - 1 day')::date;
begin
  insert into public.invoices (
    id, tenant_id, invoice_number, type, status, customer_id, contract_id, date,
    subtotal, total, paid_amount, billing_period_start, billing_period_end,
    confirmed_at, confirmed_by
  )
  values (
    v_invoice_id, v_tenant_a, p_invoice_number, 'rental_monthly', 'confirmed',
    (p_fixture ->> 'customer_id')::uuid, p_contract_id, current_date,
    25.000, 25.000, 0.000, v_period_start, v_period_end,
    now(), v_owner
  );

  return v_invoice_id;
end;
$$;

create or replace function pg_temp.p6m13_assert_lifecycle_operation(
  p_operation_type text,
  p_source_contract_id uuid
)
returns void
language plpgsql
as $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.contract_lifecycle_operations clo
  where clo.operation_type = p_operation_type
    and clo.source_contract_id = p_source_contract_id;

  if v_count < 1 then
    raise exception 'P6M13 audit matrix failed: missing % for contract %',
      p_operation_type, p_source_contract_id;
  end if;
end;
$$;

-- P6M13-1 multi_asset_trial
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m13.customers', pg_temp.p6m13_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m13.fixture',
    pg_temp.p6m13_inventory_setup(current_setting('test.p6m13.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m13.fixture')::jsonb;
  v_contract_id uuid;
  v_balance public.inventory_balances%rowtype;
  v_unit_a public.unit_status;
  v_unit_b public.unit_status;
begin
  v_contract_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a'),
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_b')
      )
    ),
    gen_random_uuid()
  );

  select * into v_balance
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;

  if v_balance.qty_available <> 0 or v_balance.qty_trial <> 2 then
    raise exception 'P6M13-1 failed: expected qty_available=0 qty_trial=2, got %/%',
      v_balance.qty_available, v_balance.qty_trial;
  end if;

  select status into v_unit_a from public.product_units where id = (v_fixture ->> 'unit_a')::uuid;
  select status into v_unit_b from public.product_units where id = (v_fixture ->> 'unit_b')::uuid;

  if v_unit_a <> 'trial'::public.unit_status or v_unit_b <> 'trial'::public.unit_status then
    raise exception 'P6M13-1 failed: both units must be trial';
  end if;

  if v_contract_id is null then
    raise exception 'P6M13-1 failed: trial contract id missing';
  end if;
end $$;
rollback;

-- P6M13-2 return_trial_bucket_restore
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m13.customers', pg_temp.p6m13_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m13.fixture',
    pg_temp.p6m13_inventory_setup(current_setting('test.p6m13.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m13.fixture')::jsonb;
  v_trial_id uuid;
  v_before public.inventory_balances%rowtype;
  v_after public.inventory_balances%rowtype;
begin
  select * into v_before
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;

  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a')
      )
    ),
    gen_random_uuid()
  );

  perform public.return_trial_contract(
    jsonb_build_object(
      'trial_contract_id', v_trial_id,
      'return_condition', 'available_used',
      'reason', 'P6M13-2 restore buckets'
    ),
    gen_random_uuid()
  );

  select * into v_after
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;

  if v_after.qty_trial <> 0 then
    raise exception 'P6M13-2 failed: qty_trial not restored, got %', v_after.qty_trial;
  end if;

  if v_after.qty_available <> v_before.qty_available then
    raise exception 'P6M13-2 failed: qty_available not restored before=% after=%',
      v_before.qty_available, v_after.qty_available;
  end if;
end $$;
rollback;

-- P6M13-3 close_rental_bucket_restore
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m13.customers', pg_temp.p6m13_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m13.fixture',
    pg_temp.p6m13_inventory_setup(current_setting('test.p6m13.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m13.fixture')::jsonb;
  v_rental_id uuid;
  v_before public.inventory_balances%rowtype;
  v_after public.inventory_balances%rowtype;
begin
  select * into v_before
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;

  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a')
      )
    ),
    gen_random_uuid()
  );

  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_rental_id,
      'closure_type', 'normal',
      'close_reason', 'P6M13-3 restore buckets',
      'return_condition', 'available_used'
    ),
    gen_random_uuid()
  );

  select * into v_after
  from public.inventory_balances
  where warehouse_id = (v_fixture ->> 'main_warehouse')::uuid
    and product_id = (v_fixture ->> 'asset_product')::uuid;

  if v_after.qty_rented <> 0 then
    raise exception 'P6M13-3 failed: qty_rented not cleared, got %', v_after.qty_rented;
  end if;

  if v_after.qty_available <> v_before.qty_available then
    raise exception 'P6M13-3 failed: qty_available not restored before=% after=%',
      v_before.qty_available, v_after.qty_available;
  end if;
end $$;
rollback;

-- P6M13-4 close_preserves_open_rental_invoice_ar (fixture invoice not from collect)
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m13.customers', pg_temp.p6m13_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m13.fixture',
    pg_temp.p6m13_inventory_setup(current_setting('test.p6m13.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m13.fixture')::jsonb;
  v_rental_id uuid;
begin
  v_rental_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a')
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.p6m13.case4.rental_id', v_rental_id::text, true);
  perform set_config('test.p6m13.case4.fixture', v_fixture::text, true);
end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m13.case4.fixture')::jsonb;
  v_rental_id uuid := current_setting('test.p6m13.case4.rental_id')::uuid;
  v_invoice_id uuid;
begin
  v_invoice_id := pg_temp.p6m13_insert_open_rental_invoice(
    v_fixture,
    v_rental_id,
    'P6M13-RM-' || left(gen_random_uuid()::text, 8)
  );
  perform set_config('test.p6m13.case4.invoice_id', v_invoice_id::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_rental_id uuid := current_setting('test.p6m13.case4.rental_id')::uuid;
  v_invoice_id uuid := current_setting('test.p6m13.case4.invoice_id')::uuid;
  v_status public.invoice_status;
  v_total numeric(15, 3);
  v_paid numeric(15, 3);
  v_je_count_before int;
  v_je_count_after int;
begin
  select status, total, paid_amount
  into v_status, v_total, v_paid
  from public.invoices
  where id = v_invoice_id;

  if v_status <> 'confirmed'::public.invoice_status or coalesce(v_paid, 0) <> 0 then
    raise exception 'P6M13-4 failed: fixture invoice must be confirmed open A/R';
  end if;

  select count(*)::int into v_je_count_before
  from public.journal_entries
  where source = 'rental_invoice';

  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_rental_id,
      'closure_type', 'normal',
      'close_reason', 'P6M13-4 preserve open rental A/R',
      'return_condition', 'available_used'
    ),
    gen_random_uuid()
  );

  if exists (
    select 1
    from public.invoices i
    where i.id = v_invoice_id
      and (
        i.status is distinct from v_status
        or i.total is distinct from v_total
        or i.paid_amount is distinct from v_paid
      )
  ) then
    raise exception 'P6M13-4 failed: open rental_monthly invoice mutated by close';
  end if;

  select count(*)::int into v_je_count_after
  from public.journal_entries
  where source = 'rental_invoice';

  if v_je_count_after <> v_je_count_before then
    raise exception 'P6M13-4 failed: close altered rental_invoice journal entries';
  end if;
end $$;
rollback;

-- P6M13-5 schedule_consumable_no_stock_movement
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m13.customers', pg_temp.p6m13_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m13.fixture',
    pg_temp.p6m13_inventory_setup(current_setting('test.p6m13.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m13.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_before int;
  v_after int;
begin
  v_contract_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date - 10,
      'monthly_rental_value', 35.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a')
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

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  select count(*)::int into v_before from public.inventory_movements;

  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'consumable_b',
      'effective_date', current_date + 5,
      'qty_per_refill', 700.000,
      'reason', 'P6M13-5 schedule only'
    ),
    gen_random_uuid()
  );

  select count(*)::int into v_after from public.inventory_movements;

  if v_after - v_before <> 0 then
    raise exception 'P6M13-5 failed: schedule created % inventory movements', v_after - v_before;
  end if;
end $$;
rollback;

-- P6M13-6 lifecycle_operations_audit_matrix
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m13.customers', pg_temp.p6m13_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m13.fixture',
    pg_temp.p6m13_inventory_setup(current_setting('test.p6m13.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m13.fixture')::jsonb;
  v_trial_return uuid;
  v_trial_extend uuid;
  v_trial_convert uuid;
  v_rental_convert uuid;
  v_rental_schedule uuid;
  v_line_id uuid;
begin
  v_trial_return := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a')
      )
    ),
    gen_random_uuid()
  );
  perform public.return_trial_contract(
    jsonb_build_object(
      'trial_contract_id', v_trial_return,
      'return_condition', 'available_used',
      'reason', 'P6M13-6 return audit'
    ),
    gen_random_uuid()
  );
  perform pg_temp.p6m13_assert_lifecycle_operation('return_trial', v_trial_return);

  v_trial_extend := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'trial_days', 5,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_b')
      )
    ),
    gen_random_uuid()
  );
  perform public.extend_trial_contract(
    jsonb_build_object(
      'trial_contract_id', v_trial_extend,
      'new_trial_end_date', current_date + 20,
      'reason', 'P6M13-6 extend audit'
    ),
    gen_random_uuid()
  );
  perform pg_temp.p6m13_assert_lifecycle_operation('extend_trial', v_trial_extend);

  v_trial_convert := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_a')
      )
    ),
    gen_random_uuid()
  );
  v_rental_convert := public.convert_trial_to_rental(
    jsonb_build_object('trial_contract_id', v_trial_convert, 'monthly_rental_value', 20.000),
    gen_random_uuid()
  );
  perform pg_temp.p6m13_assert_lifecycle_operation('convert_trial_to_rental', v_trial_convert);

  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_rental_convert,
      'closure_type', 'normal',
      'close_reason', 'P6M13-6 close audit',
      'return_condition', 'available_used'
    ),
    gen_random_uuid()
  );
  perform pg_temp.p6m13_assert_lifecycle_operation('close_contract', v_rental_convert);

  perform public.return_trial_contract(
    jsonb_build_object(
      'trial_contract_id', v_trial_extend,
      'return_condition', 'available_used',
      'reason', 'P6M13-6 release unit_b for schedule'
    ),
    gen_random_uuid()
  );

  v_rental_schedule := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date - 10,
      'monthly_rental_value', 30.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_b')
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

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_rental_schedule
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_rental_schedule,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'consumable_b',
      'effective_date', current_date + 7,
      'qty_per_refill', 650.000,
      'reason', 'P6M13-6 schedule audit'
    ),
    gen_random_uuid()
  );
  perform pg_temp.p6m13_assert_lifecycle_operation('schedule_consumable_change', v_rental_schedule);

  if v_rental_convert is null then
    raise exception 'P6M13-6 failed: convert result missing';
  end if;
end $$;
rollback;

select 'phase_6_contracts_verification_passed';
