-- Phase 6 M2: contract pricing and profit engine verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase I.
-- Manual: docker exec -i supabase_db_hs360 psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/phase_6_contract_pricing_profit_engine.sql

\set ON_ERROR_STOP on

-- Seed constants:
--   tenant_a=101, owner=201, field_user=205, field_tu=305
--   oils_group=802, devices_group=801, main_warehouse=701

-- Shared fixture builder used by multiple cases.
create or replace function pg_temp.p6m2_base_fixture(
  p_asset_basis public.rental_asset_cost_basis default 'unit_purchase_cost',
  p_consumable_basis public.rental_consumable_cost_basis default 'product_sale_price',
  p_allow_multi_asset boolean default true,
  p_allow_multi_consumable boolean default true
)
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_asset_product uuid := gen_random_uuid();
  v_consumable_product uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
  v_unit_b uuid := gen_random_uuid();
  v_consumable_b uuid := gen_random_uuid();
begin
  update public.tenant_settings
  set
    rental_asset_cost_basis = p_asset_basis,
    rental_consumable_cost_basis = p_consumable_basis,
    allow_multi_asset_contracts = p_allow_multi_asset,
    allow_multi_consumable_contracts = p_allow_multi_consumable
  where tenant_id = v_tenant_a;

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_asset_product, v_tenant_a, 'P6M2-AST-' || left(v_asset_product::text, 8),
    'جهاز M2', 'M2 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_consumable_product, v_tenant_a, 'P6M2-OIL-' || left(v_consumable_product::text, 8),
    'زيت M2', 'M2 Oil', v_oils_group, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_consumable_b, v_tenant_a, 'P6M2-OILB-' || left(v_consumable_b::text, 8),
    'زيت M2 ب', 'M2 Oil B', v_oils_group, 'consumable_rental',
    'ml', 1, 0.020, 0.011, 0.013, false, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values
    (
      v_unit_a, v_tenant_a, v_asset_product, 'P6M2-SN-A-' || left(v_unit_a::text, 8),
      'available_new', '00000000-0000-0000-0000-000000000701', 60.000, current_date
    ),
    (
      v_unit_b, v_tenant_a, v_asset_product, 'P6M2-SN-B-' || left(v_unit_b::text, 8),
      'available_new', '00000000-0000-0000-0000-000000000701', 48.000, current_date
    );

  return jsonb_build_object(
    'asset_product', v_asset_product,
    'consumable_product', v_consumable_product,
    'consumable_b', v_consumable_b,
    'unit_a', v_unit_a,
    'unit_b', v_unit_b
  );
end;
$$;

-- 1. Asset basis unit_purchase_cost (tenant default).
begin;
do $$
begin
  perform set_config(
    'test.p6m2.fixture',
    pg_temp.p6m2_base_fixture()::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
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
    )
  );

  if (v_result ->> 'asset_monthly_cost')::numeric <> 2.500 then
    raise exception 'case1 failed: asset_monthly_cost expected 2.500 got %', v_result ->> 'asset_monthly_cost';
  end if;

  if (v_result ->> 'consumable_monthly_cost')::numeric <> 7.500 then
    raise exception 'case1 failed: consumable_monthly_cost expected 7.500 got %', v_result ->> 'consumable_monthly_cost';
  end if;

  if (v_result ->> 'total_monthly_cost')::numeric <> 10.000 then
    raise exception 'case1 failed: total_monthly_cost expected 10.000 got %', v_result ->> 'total_monthly_cost';
  end if;

  if (v_result ->> 'expected_monthly_profit')::numeric <> 10.000 then
    raise exception 'case1 failed: expected_monthly_profit expected 10.000 got %', v_result ->> 'expected_monthly_profit';
  end if;

  if (v_result ->> 'passes_min_profit')::boolean is distinct from true then
    raise exception 'case1 failed: passes_min_profit expected true';
  end if;
end $$;
rollback;

-- 2. Asset basis product_avg_cost.
begin;
do $$
begin
  perform set_config(
    'test.p6m2.fixture',
    pg_temp.p6m2_base_fixture('product_avg_cost')::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', '[]'::jsonb
    )
  );

  if (v_result ->> 'asset_monthly_cost')::numeric <> 1.875 then
    raise exception 'case2 failed: asset_monthly_cost expected 1.875 got %', v_result ->> 'asset_monthly_cost';
  end if;
end $$;
rollback;

-- 3. Asset basis product_sale_price.
begin;
do $$
begin
  perform set_config(
    'test.p6m2.fixture',
    pg_temp.p6m2_base_fixture('product_sale_price')::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', '[]'::jsonb
    )
  );

  if (v_result ->> 'asset_monthly_cost')::numeric <> 0.521 then
    raise exception 'case3 failed: asset_monthly_cost expected 0.521 got %', v_result ->> 'asset_monthly_cost';
  end if;
end $$;
rollback;

-- 4. Consumable basis product_sale_price.
begin;
do $$
begin
  perform set_config(
    'test.p6m2.fixture',
    pg_temp.p6m2_base_fixture('unit_purchase_cost', 'product_sale_price')::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
      'asset_lines', '[]'::jsonb,
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        )
      )
    )
  );

  if (v_result ->> 'consumable_monthly_cost')::numeric <> 7.500 then
    raise exception 'case4 failed: consumable_monthly_cost expected 7.500 got %', v_result ->> 'consumable_monthly_cost';
  end if;
end $$;
rollback;

-- 5. Multiple asset lines summed.
begin;
do $$
begin
  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 30.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        ),
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_b'
        )
      ),
      'consumable_lines', '[]'::jsonb
    )
  );

  if (v_result ->> 'asset_monthly_cost')::numeric <> 4.500 then
    raise exception 'case5 failed: asset_monthly_cost expected 4.500 got %', v_result ->> 'asset_monthly_cost';
  end if;
end $$;
rollback;

-- 6. Multiple consumable lines summed.
begin;
do $$
begin
  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 30.000,
      'asset_lines', '[]'::jsonb,
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        ),
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_b',
          'qty_per_refill', 250.000,
          'refill_frequency_months', 1
        )
      )
    )
  );

  if (v_result ->> 'consumable_monthly_cost')::numeric <> 12.500 then
    raise exception 'case6 failed: consumable_monthly_cost expected 12.500 got %', v_result ->> 'consumable_monthly_cost';
  end if;
end $$;
rollback;

-- 7. Below-min-profit without override; field user sees flags only.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_field_tu, 'contracts.create', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
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
    )
  );

  if (v_result ->> 'passes_min_profit')::boolean is distinct from false then
    raise exception 'case7 failed: passes_min_profit expected false';
  end if;

  if (v_result ->> 'below_min_profit')::boolean is distinct from true then
    raise exception 'case7 failed: below_min_profit expected true';
  end if;

  if (v_result ->> 'requires_override')::boolean is distinct from true then
    raise exception 'case7 failed: requires_override expected true';
  end if;

  if v_result ? 'expected_monthly_profit'
    or v_result ? 'total_monthly_cost'
    or v_result ? 'asset_monthly_cost'
    or v_result ? 'minimum_allowed_monthly_value' then
    raise exception 'case7 failed: sensitive numerics leaked to field user';
  end if;
end $$;
rollback;

-- 8. Authorized override by manager.
begin;
do $$
begin
  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
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
      ),
      'request_override', true,
      'override_reason', 'Strategic customer retention'
    )
  );

  if (v_result ->> 'passes_min_profit')::boolean is distinct from true then
    raise exception 'case8 failed: passes_min_profit expected true with override';
  end if;

  if (v_result ->> 'min_profit_overridden')::boolean is distinct from true then
    raise exception 'case8 failed: min_profit_overridden expected true';
  end if;
end $$;
rollback;

-- 9. Missing purchase_cost -> validation_failed.
begin;
do $$
declare
  v_fixture jsonb;
  v_unit_no_cost uuid := gen_random_uuid();
begin
  v_fixture := pg_temp.p6m2_base_fixture();

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_unit_no_cost, '00000000-0000-0000-0000-000000000101',
    (v_fixture ->> 'asset_product')::uuid,
    'P6M2-NOCOST-' || left(v_unit_no_cost::text, 8),
    'available_new', '00000000-0000-0000-0000-000000000701', null, current_date
  );

  perform set_config(
    'test.p6m2.fixture',
    (v_fixture || jsonb_build_object('unit_no_cost', v_unit_no_cost))::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_unit_no_cost uuid := (v_fixture ->> 'unit_no_cost')::uuid;
begin
  begin
    perform public.preview_contract_profit(
      jsonb_build_object(
        'monthly_rental_value', 20.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_unit_no_cost
          )
        ),
        'consumable_lines', '[]'::jsonb
      )
    );
    raise exception 'case9 failed: missing purchase_cost accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 10. refill_frequency_months = 2 halves consumable monthly cost.
begin;
do $$
begin
  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_result jsonb;
begin

  v_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
      'asset_lines', '[]'::jsonb,
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'consumable_product',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 2
        )
      )
    )
  );

  if (v_result ->> 'consumable_monthly_cost')::numeric <> 3.750 then
    raise exception 'case10 failed: consumable_monthly_cost expected 3.750 got %', v_result ->> 'consumable_monthly_cost';
  end if;
end $$;
rollback;

-- 11. Preview performs zero writes.
begin;
do $$
begin
  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_contracts_before bigint;
  v_contracts_after bigint;
  v_lines_before bigint;
  v_lines_after bigint;
begin

  select count(*) into v_contracts_before from public.contracts;
  select count(*) into v_lines_before from public.contract_lines;

  perform public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
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
    )
  );

  select count(*) into v_contracts_after from public.contracts;
  select count(*) into v_lines_after from public.contract_lines;

  if v_contracts_before is distinct from v_contracts_after then
    raise exception 'case11 failed: contracts row count changed';
  end if;

  if v_lines_before is distinct from v_lines_after then
    raise exception 'case11 failed: contract_lines row count changed';
  end if;
end $$;
rollback;

-- 12. Permission mask: owner sees numerics; field user does not.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_field_tu, 'contracts.create', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_owner_result jsonb;
begin

  v_owner_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
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
    )
  );

  if not (v_owner_result ? 'expected_monthly_profit' and v_owner_result ? 'total_monthly_cost') then
    raise exception 'case12a failed: owner missing cost/profit numerics';
  end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_field_result jsonb;
begin
  v_field_result := public.preview_contract_profit(
    jsonb_build_object(
      'monthly_rental_value', 20.000,
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
    )
  );

  if v_field_result ? 'expected_monthly_profit'
    or v_field_result ? 'total_monthly_cost'
    or v_field_result ? 'asset_monthly_cost'
    or v_field_result ? 'consumable_monthly_cost' then
    raise exception 'case12b failed: field user saw sensitive numerics';
  end if;

  if (v_field_result ->> 'passes_min_profit')::boolean is distinct from true then
    raise exception 'case12b failed: field user should still see passes_min_profit';
  end if;
end $$;
rollback;

-- 13a-c. Forbidden keys in payload -> validation_failed.
begin;
do $$
begin
  perform set_config('test.p6m2.fixture', pg_temp.p6m2_base_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_payload jsonb;
  v_key text;
begin

  foreach v_key in array array['asset_cost_basis', 'consumable_cost_basis', 'asset_lifespan_months'] loop
    v_payload := jsonb_build_object(
      'monthly_rental_value', 20.000,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', '[]'::jsonb
    ) || jsonb_build_object(v_key, 'unit_purchase_cost');

    if v_key = 'asset_lifespan_months' then
      v_payload := jsonb_build_object(
        'monthly_rental_value', 20.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          )
        ),
        'consumable_lines', '[]'::jsonb,
        'asset_lifespan_months', 36
      );
    end if;

    begin
      perform public.preview_contract_profit(v_payload);
      raise exception 'case13 failed: forbidden key % accepted', v_key;
    exception
      when others then
        if sqlerrm not like '%validation_failed%' then
          raise;
        end if;
    end;
  end loop;
end $$;
rollback;

-- 14. allow_multi_asset_contracts = false + 2 asset lines -> validation_failed.
begin;
do $$
begin
  perform set_config(
    'test.p6m2.fixture',
    pg_temp.p6m2_base_fixture('unit_purchase_cost', 'product_sale_price', false, true)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
begin
  begin
    perform public.preview_contract_profit(
      jsonb_build_object(
        'monthly_rental_value', 30.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_a'
          ),
          jsonb_build_object(
            'product_id', v_fixture ->> 'asset_product',
            'product_unit_id', v_fixture ->> 'unit_b'
          )
        ),
        'consumable_lines', '[]'::jsonb
      )
    );
    raise exception 'case14 failed: multi-asset accepted when disabled';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 15. allow_multi_consumable_contracts = false + 2 consumable lines -> validation_failed.
begin;
do $$
begin
  perform set_config(
    'test.p6m2.fixture',
    pg_temp.p6m2_base_fixture('unit_purchase_cost', 'product_sale_price', true, false)::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
begin
  begin
    perform public.preview_contract_profit(
      jsonb_build_object(
        'monthly_rental_value', 30.000,
        'asset_lines', '[]'::jsonb,
        'consumable_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_fixture ->> 'consumable_product',
            'qty_per_refill', 500.000,
            'refill_frequency_months', 1
          ),
          jsonb_build_object(
            'product_id', v_fixture ->> 'consumable_b',
            'qty_per_refill', 250.000,
            'refill_frequency_months', 1
          )
        )
      )
    );
    raise exception 'case15 failed: multi-consumable accepted when disabled';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 16. Non-unit_purchase_cost basis still rejects invalid product_unit_id on serialized assets.
begin;
do $$
begin
  perform set_config(
    'test.p6m2.fixture',
    pg_temp.p6m2_base_fixture('product_avg_cost')::text,
    true
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m2.fixture')::jsonb;
  v_basis public.rental_asset_cost_basis;
begin
  foreach v_basis in array array[
    'product_avg_cost'::public.rental_asset_cost_basis,
    'product_sale_price'::public.rental_asset_cost_basis
  ] loop
    update public.tenant_settings
    set rental_asset_cost_basis = v_basis
    where tenant_id = '00000000-0000-0000-0000-000000000101';

    begin
      perform public.preview_contract_profit(
        jsonb_build_object(
          'monthly_rental_value', 20.000,
          'asset_lines', jsonb_build_array(
            jsonb_build_object(
              'product_id', v_fixture ->> 'asset_product',
              'product_unit_id', gen_random_uuid()
            )
          ),
          'consumable_lines', '[]'::jsonb
        )
      );
      raise exception 'case16 failed: invalid product_unit_id accepted for basis %', v_basis;
    exception
      when others then
        if sqlerrm not like '%validation_failed%' then
          raise;
        end if;
    end;
  end loop;
end $$;
rollback;
