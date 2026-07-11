\set ON_ERROR_STOP on

-- Phase 6 M10b: schedule contract consumable change RPC verification.

create or replace function pg_temp.p6m10b_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    '{"name_ar":"عميل M10b","phone_primary":"+96550009001","create_account":true}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع M10b","location_type":"branch","governorate":"Hawalli","area":"Salmiya","contact_person_phone":"+96550009001"}'::jsonb
  );

  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p6m10b_fixture_setup(p_customers jsonb)
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
  v_oil_a uuid := gen_random_uuid();
  v_oil_b uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_asset_product, v_tenant_a, 'P6M10B-AST-' || left(v_asset_product::text, 8),
    'جهاز M10b', 'M10b Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values
    (
      v_oil_a, v_tenant_a, 'P6M10B-OIL-A-' || left(v_oil_a::text, 8),
      'زيت A M10b', 'M10b Oil A', v_oils_group, 'consumable_rental',
      'ml', 1, 0.015, 0.010, 0.012, false, v_owner
    ),
    (
      v_oil_b, v_tenant_a, 'P6M10B-OIL-B-' || left(v_oil_b::text, 8),
      'زيت B M10b', 'M10b Oil B', v_oils_group, 'consumable_rental',
      'ml', 1, 0.020, 0.013, 0.014, false, v_owner
    );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_unit_a, v_tenant_a, v_asset_product, 'P6M10B-SN-A-' || left(v_unit_a::text, 8),
    'available_new', v_main_warehouse, 60.000, current_date
  );

  insert into public.inventory_balances (
    tenant_id, warehouse_id, product_id, qty_available
  )
  values (v_tenant_a, v_main_warehouse, v_asset_product, 1.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  return p_customers || jsonb_build_object(
    'asset_product', v_asset_product,
    'unit_a', v_unit_a,
    'oil_a', v_oil_a,
    'oil_b', v_oil_b
  );
end;
$$;

-- 1. Forward schedule closes current row and inserts future row.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m10b.customers', pg_temp.p6m10b_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m10b.fixture',
    pg_temp.p6m10b_fixture_setup(current_setting('test.p6m10b.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
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
        jsonb_build_object('product_id', v_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', current_date + 5,
      'qty_per_refill', 700.000,
      'reason', 'planned upgrade'
    ),
    gen_random_uuid()
  );

  perform set_config('test.p6m10b.case1.contract_id', v_contract_id::text, true);
  perform set_config('test.p6m10b.case1.line_id', v_line_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m10b.case1.contract_id')::uuid;
  v_line_id uuid := current_setting('test.p6m10b.case1.line_id')::uuid;
  v_current public.contract_oil_changes%rowtype;
  v_future public.contract_oil_changes%rowtype;
  v_open_count int;
begin
  select *
  into v_current
  from public.contract_oil_changes coc
  where coc.contract_line_id = v_line_id
    and coc.effective_from <= current_date
    and coc.effective_to = current_date + 4
  order by coc.created_at desc
  limit 1;

  select *
  into v_future
  from public.contract_oil_changes coc
  where coc.contract_line_id = v_line_id
    and coc.effective_from = current_date + 5
    and coc.effective_to is null
  order by coc.created_at desc
  limit 1;

  select count(*)::int
  into v_open_count
  from public.contract_oil_changes coc
  where coc.contract_line_id = v_line_id
    and coc.effective_to is null;

  if v_current.id is null then
    raise exception 'case1 failed: current row not closed to effective_date - 1';
  end if;
  if v_future.id is null or v_future.contract_id is distinct from v_contract_id then
    raise exception 'case1 failed: future row missing';
  end if;
  if v_open_count <> 1 then
    raise exception 'case1 failed: expected one open-ended row, got %', v_open_count;
  end if;
end $$;
rollback;

-- 2. Same-day schedule replaces current row.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m10b.customers', pg_temp.p6m10b_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m10b.fixture',
    pg_temp.p6m10b_fixture_setup(current_setting('test.p6m10b.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
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
        jsonb_build_object('product_id', v_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', current_date,
      'qty_per_refill', 650.000,
      'reason', 'same-day correction'
    ),
    gen_random_uuid()
  );

  perform set_config('test.p6m10b.case2.line_id', v_line_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_line_id uuid := current_setting('test.p6m10b.case2.line_id')::uuid;
  v_closed_exists boolean;
  v_new_exists boolean;
begin
  select exists (
    select 1
    from public.contract_oil_changes coc
    where coc.contract_line_id = v_line_id
      and coc.effective_to = current_date - 1
  ) into v_closed_exists;

  select exists (
    select 1
    from public.contract_oil_changes coc
    where coc.contract_line_id = v_line_id
      and coc.effective_from = current_date
      and coc.effective_to is null
  ) into v_new_exists;

  if not v_closed_exists or not v_new_exists then
    raise exception 'case2 failed: same-day replacement not applied';
  end if;
end $$;
rollback;

-- 3. Reject schedule conflict when future row already exists.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m10b.customers', pg_temp.p6m10b_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m10b.fixture',
    pg_temp.p6m10b_fixture_setup(current_setting('test.p6m10b.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
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
        jsonb_build_object('product_id', v_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', current_date + 3,
      'qty_per_refill', 700.000,
      'reason', 'first future schedule'
    ),
    gen_random_uuid()
  );

  begin
    perform public.schedule_contract_consumable_change(
      jsonb_build_object(
        'contract_id', v_contract_id,
        'contract_line_id', v_line_id,
        'new_product_id', v_fixture ->> 'oil_a',
        'effective_date', current_date + 5,
        'qty_per_refill', 500.000,
        'reason', 'second schedule should fail'
      ),
      gen_random_uuid()
    );
    raise exception 'case3 failed: conflict schedule accepted';
  exception when others then
    if sqlerrm not like '%consumable_schedule_conflict%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 4. Trigger rejects second open-ended row for same line.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m10b.customers', pg_temp.p6m10b_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m10b.fixture',
    pg_temp.p6m10b_fixture_setup(current_setting('test.p6m10b.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
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
        jsonb_build_object('product_id', v_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform set_config('test.p6m10b.case4.contract_id', v_contract_id::text, true);
  perform set_config('test.p6m10b.case4.line_id', v_line_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid := current_setting('test.p6m10b.case4.contract_id')::uuid;
  v_line_id uuid := current_setting('test.p6m10b.case4.line_id')::uuid;
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  perform public.allow_contract_write();
  begin
    insert into public.contract_oil_changes (
      tenant_id, contract_id, contract_line_id,
      effective_from, effective_to,
      oil_product_id, qty_per_refill,
      snapshot_unit_cost, snapshot_refill_cost, reason
    )
    values (
      v_tenant_a, v_contract_id, v_line_id,
      current_date + 2, null,
      (v_fixture ->> 'oil_b')::uuid, 600.000,
      0.013, 7.800, 'should fail second open tail'
    );
    raise exception 'case4 failed: second open-ended row accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 5. get_contract_detail includes current and scheduled consumable enrichment.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m10b.customers', pg_temp.p6m10b_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m10b.fixture',
    pg_temp.p6m10b_fixture_setup(current_setting('test.p6m10b.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
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
        jsonb_build_object('product_id', v_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', current_date + 4,
      'qty_per_refill', 900.000,
      'reason', 'future planned consumable'
    ),
    gen_random_uuid()
  );

  perform set_config('test.p6m10b.case5.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_field_tu, 'contracts.view', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  delete from public.user_permissions
  where tenant_user_id = v_field_tu
    and permission_id like 'contracts.field.snapshot_%';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid := current_setting('test.p6m10b.case5.contract_id')::uuid;
  v_detail jsonb;
  v_line jsonb;
begin
  v_detail := public.get_contract_detail(v_contract_id);
  v_line := (v_detail -> 'consumable_lines') -> 0;

  if (v_line ->> 'current_oil_product_id')::uuid is distinct from (v_fixture ->> 'oil_a')::uuid then
    raise exception 'case5 failed: current oil product enrichment mismatch';
  end if;
  if (v_line ->> 'current_qty_per_refill')::numeric(15, 3) is distinct from 500.000::numeric(15, 3) then
    raise exception 'case5 failed: current qty enrichment mismatch';
  end if;
  if (v_line ->> 'scheduled_oil_product_id')::uuid is distinct from (v_fixture ->> 'oil_b')::uuid then
    raise exception 'case5 failed: scheduled oil product enrichment mismatch';
  end if;
  if (v_line ->> 'scheduled_qty_per_refill')::numeric(15, 3) is distinct from 900.000::numeric(15, 3) then
    raise exception 'case5 failed: scheduled qty enrichment mismatch';
  end if;
  if (v_line ->> 'scheduled_effective_from')::date is distinct from current_date + 4 then
    raise exception 'case5 failed: scheduled effective_from enrichment mismatch';
  end if;

  if v_detail ? 'snapshot_oil_monthly_cost'
    or (v_line ? 'snapshot_unit_cost')
    or (v_line ? 'snapshot_monthly_cost') then
    raise exception 'case5 failed: cost fields leaked through read mask';
  end if;
end $$;
set local role postgres;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  select v_tenant_a, v_field_tu, p.permission_id, v_owner
  from (values
    ('contracts.field.snapshot_device_cost'),
    ('contracts.field.snapshot_oil_cost'),
    ('contracts.field.snapshot_total_cost'),
    ('contracts.field.snapshot_profit')
  ) as p(permission_id)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
rollback;

-- 6. Permission denied without contracts.oil_change.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m10b.customers', pg_temp.p6m10b_customer_setup()::text, true);
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m10b.fixture',
    pg_temp.p6m10b_fixture_setup(current_setting('test.p6m10b.customers')::jsonb)::text,
    true
  );
end $$;
set local role authenticated;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m10b.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
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
        jsonb_build_object('product_id', v_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000202', true);

  begin
    perform public.schedule_contract_consumable_change(
      jsonb_build_object(
        'contract_id', v_contract_id,
        'contract_line_id', v_line_id,
        'new_product_id', v_fixture ->> 'oil_b',
        'effective_date', current_date + 2,
        'qty_per_refill', 600.000,
        'reason', 'unauthorized test'
      ),
      gen_random_uuid()
    );
    raise exception 'case6 failed: unauthorized schedule accepted';
  exception when others then
    if sqlerrm not like '%permission_denied%' then
      raise;
    end if;
  end;
end $$;
rollback;
