-- Phase 6 M8: contract read RPC and ACL hardening verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase M.

\set ON_ERROR_STOP on

create or replace function pg_temp.p6m8_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';
  v_customer_id uuid;
  v_location_id uuid;
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_field_tu, 'contracts.view', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  v_customer_id := public.create_customer(
    '{"name_ar":"عميل M8","name_en":"M8 Customer","phone_primary":"+96550008801"}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع M8","location_type":"branch","governorate":"Hawalli","area":"Salmiya"}'::jsonb
  );

  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p6m8_inventory_setup(p_customers jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_asset_product uuid := gen_random_uuid();
  v_consumable_product uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_asset_product, v_tenant_a, 'P6M8-AST-' || left(v_asset_product::text, 8),
    'جهاز M8', 'M8 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_consumable_product, v_tenant_a, 'P6M8-OIL-' || left(v_consumable_product::text, 8),
    'زيت M8', 'M8 Oil', v_oils_group, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_unit_a, v_tenant_a, v_asset_product, 'P6M8-SN-A-' || left(v_unit_a::text, 8),
    'available_new', v_main_warehouse, 60.000, current_date
  );

  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_asset_product, 1.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  return p_customers || jsonb_build_object(
    'asset_product', v_asset_product,
    'consumable_product', v_consumable_product,
    'unit_a', v_unit_a
  );
end;
$$;

create or replace function pg_temp.p6m8_contract_setup(p_fixture jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_contract_id uuid;
begin
  v_contract_id := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', p_fixture ->> 'customer_id',
      'service_location_id', p_fixture ->> 'service_location_id',
      'start_date', current_date,
      'monthly_rental_value', 25.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_fixture ->> 'asset_product',
          'product_unit_id', p_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        )
      )
    ),
    gen_random_uuid()
  );

  return p_fixture || jsonb_build_object('contract_id', v_contract_id);
end;
$$;

-- Committed fixture for the suite.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config(
    'test.p6m8.customers',
    pg_temp.p6m8_customer_setup()::text,
    false
  );
end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p6m8.inventory',
    pg_temp.p6m8_inventory_setup(current_setting('test.p6m8.customers')::jsonb)::text,
    false
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config(
    'test.p6m8.fixture',
    pg_temp.p6m8_contract_setup(current_setting('test.p6m8.inventory')::jsonb)::text,
    false
  );
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := (current_setting('test.p6m8.fixture')::jsonb ->> 'contract_id')::uuid;
begin
  perform public.allow_contract_write();
  update public.contracts
  set min_profit_overridden = true
  where id = v_contract_id;
end $$;
commit;

begin;
set local role postgres;
do $$
declare
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_customer_b uuid;
  v_contract_b uuid := gen_random_uuid();
begin
  perform public.allow_contract_write();

  insert into public.customers (
    id, tenant_id, code, name_ar, phone_primary, created_by
  )
  values (
    gen_random_uuid(), v_tenant_b, 'TB-CUST-M8', 'عميل ب M8', '+96550008899',
    '00000000-0000-0000-0000-000000000204'
  )
  on conflict (tenant_id, code) do update
  set name_ar = excluded.name_ar
  returning id into v_customer_b;

  if v_customer_b is null then
    select id into v_customer_b
    from public.customers
    where tenant_id = v_tenant_b
      and code = 'TB-CUST-M8';
  end if;

  if not exists (
    select 1 from public.contracts where contract_number = 'CON-TENANT-B-M8'
  ) then
    insert into public.contracts (
      id, tenant_id, contract_number, type, status, customer_id, contact_phone,
      start_date, monthly_rental_value,
      snapshot_device_monthly_cost, snapshot_oil_monthly_cost,
      snapshot_total_monthly_cost, snapshot_monthly_profit, snapshot_min_profit_threshold
    )
    values (
      v_contract_b, v_tenant_b, 'CON-TENANT-B-M8', 'rental', 'active', v_customer_b,
      '+96550008899', current_date, 10.000, 1, 1, 2, 3, 0
    );
  else
    select id into v_contract_b
    from public.contracts
    where tenant_id = v_tenant_b
      and contract_number = 'CON-TENANT-B-M8';
  end if;

  perform set_config('test.p6m8.contract_b_id', v_contract_b::text, false);
end $$;
commit;

-- Grant all field permissions for case 12.
begin;
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
commit;

-- 1. list_contracts denied without contracts.view
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  begin
    perform * from public.list_contracts();
    raise exception 'case1 failed: expected permission_denied';
  exception when others then
    if sqlerrm not like '%permission_denied%' then
      raise exception 'case1 failed: %', sqlerrm;
    end if;
  end;
end $$;
rollback;

-- 2. Tenant isolation
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_contract_b uuid := current_setting('test.p6m8.contract_b_id')::uuid;
  v_count int;
begin
  select count(*) into v_count
  from public.list_contracts()
  where id = v_contract_b;

  if v_count <> 0 then
    raise exception 'case2 failed: other tenant contract visible';
  end if;
end $$;
rollback;

-- 3. Pagination bounds
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.list_contracts(p_limit := 1, p_offset := 0);

  if v_count > 1 then
    raise exception 'case3 failed: limit not respected';
  end if;
end $$;
rollback;

-- 4. Filter by customer
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_count int;
begin
  select count(*) into v_count
  from public.list_contracts(
    p_customer_id := (v_fixture ->> 'customer_id')::uuid
  )
  where id = (v_fixture ->> 'contract_id')::uuid;

  if v_count <> 1 then
    raise exception 'case4 failed: customer filter';
  end if;
end $$;
rollback;

-- 5. Filter by type/status
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_count int;
begin
  select count(*) into v_count
  from public.list_contracts(p_type := 'rental', p_status := 'active')
  where id = (v_fixture ->> 'contract_id')::uuid;

  if v_count <> 1 then
    raise exception 'case5 failed: type/status filter';
  end if;
end $$;
rollback;

-- 6. Search by contract number
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_number text;
  v_count int;
begin
  select contract_number into v_number
  from public.list_contracts(
    p_customer_id := (v_fixture ->> 'customer_id')::uuid
  )
  where id = (v_fixture ->> 'contract_id')::uuid;

  select count(*) into v_count
  from public.list_contracts(p_search := v_number)
  where id = (v_fixture ->> 'contract_id')::uuid;

  if v_count <> 1 then
    raise exception 'case6 failed: contract number search';
  end if;
end $$;
rollback;

-- 6b. Search by phone_primary
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_count int;
begin
  select count(*) into v_count
  from public.list_contracts(p_search := '96550008801')
  where id = (v_fixture ->> 'contract_id')::uuid;

  if v_count <> 1 then
    raise exception 'case6b failed: phone search';
  end if;
end $$;
rollback;

-- 7. List has no snapshot columns for field-restricted user
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_result text;
begin
  select pg_get_function_result(p.oid) into v_result
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'list_contracts'
    and pg_get_function_identity_arguments(p.oid) like '%uuid, text, text, date, date, text, boolean, integer, integer%';

  if v_result like '%snapshot%' then
    raise exception 'case7 failed: list_contracts exposes snapshot columns';
  end if;
end $$;
rollback;

-- 8. List has no snapshot columns for user with all field permissions
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_result text;
begin
  select pg_get_function_result(p.oid) into v_result
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'list_contracts'
    and pg_get_function_identity_arguments(p.oid) like '%uuid, text, text, date, date, text, boolean, integer, integer%';

  if v_result like '%snapshot%' then
    raise exception 'case8 failed: list_contracts exposes snapshot columns';
  end if;
end $$;
rollback;

-- 9. get_contract_detail denied without contracts.view
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
begin
  begin
    perform public.get_contract_detail((v_fixture ->> 'contract_id')::uuid);
    raise exception 'case9 failed: expected permission_denied';
  exception when others then
    if sqlerrm not like '%permission_denied%' then
      raise exception 'case9 failed: %', sqlerrm;
    end if;
  end;
end $$;
rollback;

-- 10. Detail includes asset and consumable lines
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_detail jsonb;
  v_assets int;
  v_consumables int;
begin
  v_detail := public.get_contract_detail((v_fixture ->> 'contract_id')::uuid);
  v_assets := jsonb_array_length(coalesce(v_detail -> 'asset_lines', '[]'::jsonb));
  v_consumables := jsonb_array_length(coalesce(v_detail -> 'consumable_lines', '[]'::jsonb));

  if v_assets < 1 or v_consumables < 1 then
    raise exception 'case10 failed: missing lines';
  end if;
end $$;
rollback;

-- 11. View-only user: sensitive keys absent
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';
begin
  delete from public.user_permissions
  where tenant_user_id = v_field_tu
    and permission_id like 'contracts.field.snapshot_%';
end $$;
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_detail jsonb;
begin
  v_detail := public.get_contract_detail((v_fixture ->> 'contract_id')::uuid);

  if v_detail ? 'snapshot_device_monthly_cost'
    or v_detail ? 'snapshot_total_monthly_cost'
    or v_detail ? 'snapshot_monthly_profit' then
    raise exception 'case11 failed: sensitive header keys leaked';
  end if;

  if (v_detail -> 'asset_lines' -> 0) ? 'snapshot_unit_cost' then
    raise exception 'case11 failed: sensitive asset line key leaked';
  end if;
end $$;
rollback;

-- Restore field permissions for case 12
begin;
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
commit;

-- 12. User with all field permissions: sensitive keys present
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_detail jsonb;
begin
  v_detail := public.get_contract_detail((v_fixture ->> 'contract_id')::uuid);

  if not (v_detail ? 'snapshot_device_monthly_cost'
    and v_detail ? 'snapshot_total_monthly_cost'
    and v_detail ? 'snapshot_monthly_profit') then
    raise exception 'case12 failed: expected sensitive header keys';
  end if;

  if not ((v_detail -> 'asset_lines' -> 0) ? 'snapshot_unit_cost') then
    raise exception 'case12 failed: expected sensitive asset line key';
  end if;
end $$;
rollback;

-- 13. low_profit_override_only filter
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_count int;
begin
  select count(*) into v_count
  from public.list_contracts(p_low_profit_override_only := true)
  where id = (v_fixture ->> 'contract_id')::uuid;

  if v_count <> 1 then
    raise exception 'case13 failed: low profit override filter';
  end if;
end $$;
rollback;

-- 14. Base table sensitive column SELECT fails
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
begin
  begin
    execute 'select snapshot_device_monthly_cost from public.contracts limit 1';
    raise exception 'case14 failed: expected insufficient_privilege';
  exception
    when insufficient_privilege then
      null;
    when others then
      raise exception 'case14 failed: %', sqlerrm;
  end;
end $$;
rollback;

-- 15. Base table line sensitive column SELECT fails
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
begin
  begin
    execute 'select snapshot_unit_cost from public.contract_lines limit 1';
    raise exception 'case15 failed: expected insufficient_privilege';
  exception
    when insufficient_privilege then
      null;
    when others then
      raise exception 'case15 failed: %', sqlerrm;
  end;
end $$;
rollback;

-- 16. Safe views succeed and omit sensitive columns
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_count int;
  v_sensitive int;
begin
  select count(*) into v_count from public.contracts_safe limit 1;
  if v_count < 1 then
    raise exception 'case16 failed: contracts_safe empty';
  end if;

  select count(*) into v_sensitive
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'contracts_safe'
    and column_name like 'snapshot%';

  if v_sensitive > 0 then
    raise exception 'case16 failed: contracts_safe has snapshot columns';
  end if;

  select count(*) into v_sensitive
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'contract_lines_safe'
    and column_name like 'snapshot%';

  if v_sensitive > 0 then
    raise exception 'case16 failed: contract_lines_safe has snapshot columns';
  end if;
end $$;
rollback;

-- 17. Detail JSON includes total_contract_value when set
begin;
set local role postgres;
do $$
declare
  v_contract_id uuid := (current_setting('test.p6m8.fixture')::jsonb ->> 'contract_id')::uuid;
begin
  perform public.allow_contract_write();
  update public.contracts
  set total_contract_value = 300.000
  where id = v_contract_id;
end $$;
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m8.fixture')::jsonb;
  v_detail jsonb;
begin
  v_detail := public.get_contract_detail((v_fixture ->> 'contract_id')::uuid);

  if (v_detail ->> 'total_contract_value')::numeric <> 300.000 then
    raise exception 'case17 failed: total_contract_value missing or wrong';
  end if;
end $$;
rollback;

-- 18. Idempotency columns not selectable by authenticated
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
begin
  begin
    execute 'select idempotency_key from public.contracts limit 1';
    raise exception 'case18 failed: expected insufficient_privilege';
  exception
    when insufficient_privilege then
      null;
    when others then
      raise exception 'case18 failed: %', sqlerrm;
  end;
end $$;
rollback;

select 'phase_6_contract_read_rpc_verification_passed' as result;
