\set ON_ERROR_STOP on

-- Phase 6 M13 / migration 092: list_covered_rental_months RPC verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase N.

create or replace function pg_temp.p6m92_setup_fixture(p_create_rental boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_main_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_customer uuid;
  v_location uuid;
  v_asset_product uuid := gen_random_uuid();
  v_asset_unit uuid := gen_random_uuid();
  v_contract uuid;
  v_cash_account uuid;
begin
  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل 092',
      'phone_primary', '+96550009101',
      'create_account', true
    )
  );

  v_location := public.create_customer_service_location(
    v_customer,
    jsonb_build_object(
      'name', 'موقع 092',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550009101'
    )
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    can_be_sold, can_be_rented, unit_primary, conversion_factor, sale_price,
    avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_asset_product, v_tenant, 'P6M92-AST-' || left(v_asset_product::text, 8),
    'جهاز 092', '092 Asset', v_devices_group, 'asset_rental',
    true, true, 'piece', 1, 15.000,
    45.000, true, 'non_taxable', v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_asset_unit, v_tenant, v_asset_product, 'P6M92-SN-' || left(v_asset_unit::text, 8),
    'available_new', v_main_wh, 55.000, current_date
  );

  insert into public.inventory_balances (
    tenant_id, warehouse_id, product_id, qty_available
  )
  values (v_tenant, v_main_wh, v_asset_product, 1)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  if p_create_rental then
    v_contract := public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_customer,
        'service_location_id', v_location,
        'start_date', current_date - 60,
        'monthly_rental_value', 25.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_asset_product,
            'product_unit_id', v_asset_unit
          )
        )
      ),
      gen_random_uuid()
    );
  end if;

  select id into v_cash_account
  from public.chart_of_accounts
  where tenant_id = v_tenant
    and code = '1101'
  limit 1;

  if v_cash_account is null then
    raise exception 'fixture failed: cash account 1101 missing';
  end if;

  return jsonb_build_object(
    'tenant_id', v_tenant,
    'customer_id', v_customer,
    'service_location_id', v_location,
    'asset_product_id', v_asset_product,
    'asset_unit_id', v_asset_unit,
    'contract_id', v_contract,
    'cash_account_id', v_cash_account
  );
end;
$$;

-- 092-1 Positive: owner collects month, collect-eligible user reads coverage_month_keys.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m92_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
  v_month_key text := to_char(v_month, 'YYYY-MM-DD');
  v_result jsonb;
  v_keys jsonb;
begin
  perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month_key)
    ),
    gen_random_uuid()
  );

  v_result := public.list_covered_rental_months((v_fixture ->> 'contract_id')::uuid);

  if (v_result ->> 'contract_id')::uuid is distinct from (v_fixture ->> 'contract_id')::uuid then
    raise exception '092-1 failed: contract_id mismatch';
  end if;

  v_keys := v_result -> 'coverage_month_keys';
  if jsonb_array_length(v_keys) <> 1 then
    raise exception '092-1 failed: expected one covered month, got %', v_keys;
  end if;

  if v_keys ->> 0 is distinct from v_month_key then
    raise exception '092-1 failed: expected month %, got %', v_month_key, v_keys ->> 0;
  end if;
end $$;
rollback;

-- 092-2 Permission denied: user without preview/collect permissions.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m92.fixture', pg_temp.p6m92_setup_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m92.fixture')::jsonb;
begin
  begin
    perform public.list_covered_rental_months((v_fixture ->> 'contract_id')::uuid);
    raise exception '092-2 failed: unauthorized read accepted';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 092-3 Tenant isolation: tenant B cannot read tenant A contract coverages.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m92_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
begin
  perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(to_char(v_month, 'YYYY-MM-DD'))
    ),
    gen_random_uuid()
  );

  perform set_config('test.p6m92.contract_id', v_fixture ->> 'contract_id', true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_contract_id uuid := current_setting('test.p6m92.contract_id')::uuid;
begin
  begin
    perform public.list_covered_rental_months(v_contract_id);
    raise exception '092-3 failed: tenant B read tenant A coverages';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 092-4 Invalid contract ID: trial or random uuid returns validation_failed without leaking data.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m92_setup_fixture();
  v_trial_fixture jsonb := pg_temp.p6m92_setup_fixture(false);
  v_trial_id uuid;
  v_random_id uuid := gen_random_uuid();
  v_month date := date_trunc('month', current_date)::date;
  v_month_key text := to_char(v_month, 'YYYY-MM-DD');
  v_result jsonb;
begin
  perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month_key)
    ),
    gen_random_uuid()
  );

  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_trial_fixture ->> 'customer_id',
      'service_location_id', v_trial_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_trial_fixture ->> 'asset_product_id',
          'product_unit_id', v_trial_fixture ->> 'asset_unit_id'
        )
      )
    ),
    gen_random_uuid()
  );

  begin
    v_result := public.list_covered_rental_months(v_random_id);
    raise exception '092-4 failed: random uuid returned data %', v_result;
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    v_result := public.list_covered_rental_months(v_trial_id);
    raise exception '092-4 failed: trial contract returned data %', v_result;
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  v_result := public.list_covered_rental_months((v_fixture ->> 'contract_id')::uuid);
  if jsonb_array_length(v_result -> 'coverage_month_keys') <> 1 then
    raise exception '092-4 failed: valid rental read broken after invalid attempts';
  end if;
end $$;
rollback;

-- 092-5 Payload shape: response has only contract_id and coverage_month_keys.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m92_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
  v_result jsonb;
  v_key_count int;
  v_forbidden text[] := array[
    'invoice_total', 'amount', 'paid_amount', 'collected_amount',
    'invoice_id', 'voucher_id', 'tax_amount', 'subtotal', 'total'
  ];
  v_bad_key text;
begin
  perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(to_char(v_month, 'YYYY-MM-DD'))
    ),
    gen_random_uuid()
  );

  v_result := public.list_covered_rental_months((v_fixture ->> 'contract_id')::uuid);

  select count(*) into v_key_count
  from jsonb_object_keys(v_result) as k(key);

  if v_key_count <> 2 then
    raise exception '092-5 failed: expected exactly two top-level keys, got %', v_result;
  end if;

  if not (v_result ? 'contract_id' and v_result ? 'coverage_month_keys') then
    raise exception '092-5 failed: missing required keys in %', v_result;
  end if;

  foreach v_bad_key in array v_forbidden loop
    if v_result ? v_bad_key then
      raise exception '092-5 failed: forbidden financial key % present', v_bad_key;
    end if;
  end loop;

  if jsonb_typeof(v_result -> 'coverage_month_keys') <> 'array' then
    raise exception '092-5 failed: coverage_month_keys must be an array';
  end if;
end $$;
rollback;

select 'phase_6_list_covered_rental_months_rpc_verification_passed' as result;
