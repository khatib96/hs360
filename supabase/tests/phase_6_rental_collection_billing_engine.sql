\set ON_ERROR_STOP on

-- Phase 6 M5: rental collection and billing engine verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase L.

create or replace function pg_temp.p6m5_setup_fixture(p_create_rental boolean default true)
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
      'name_ar', 'عميل M5',
      'phone_primary', '+96550009001',
      'create_account', true
    )
  );

  v_location := public.create_customer_service_location(
    v_customer,
    jsonb_build_object(
      'name', 'موقع M5',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550009001'
    )
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    can_be_sold, can_be_rented, unit_primary, conversion_factor, sale_price,
    avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_asset_product, v_tenant, 'P6M5-AST-' || left(v_asset_product::text, 8),
    'جهاز M5', 'M5 Asset', v_devices_group, 'asset_rental',
    true, true, 'piece', 1, 15.000,
    45.000, true, 'non_taxable', v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_asset_unit, v_tenant, v_asset_product, 'P6M5-SN-' || left(v_asset_unit::text, 8),
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

-- 1. Confirmed collection creates invoice + voucher + allocation + journals atomically.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_result jsonb;
  v_invoice uuid;
  v_voucher uuid;
  v_alloc_count int;
  v_je_count int;
begin
  v_result := public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(to_char(date_trunc('month', current_date), 'YYYY-MM-DD'))
    ),
    gen_random_uuid()
  );

  v_invoice := (v_result ->> 'invoice_id')::uuid;
  v_voucher := (v_result ->> 'voucher_id')::uuid;

  if v_invoice is null or v_voucher is null then
    raise exception 'case1 failed: missing invoice/voucher ids';
  end if;

  select count(*) into v_alloc_count
  from public.voucher_invoice_allocations via
  where via.invoice_id = v_invoice
    and via.voucher_id = v_voucher;

  if v_alloc_count <> 1 then
    raise exception 'case1 failed: expected one allocation row';
  end if;

  select count(*) into v_je_count
  from public.journal_entries je
  where je.source_id in (v_invoice, v_voucher)
    and je.is_posted = true;

  if v_je_count <> 2 then
    raise exception 'case1 failed: expected two posted journals';
  end if;
end $$;
rollback;

-- 2. One payment can cover multiple months including overdue/current/advance.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_m1 date := date_trunc('month', current_date - interval '1 month')::date;
  v_m2 date := date_trunc('month', current_date)::date;
  v_m3 date := date_trunc('month', current_date + interval '1 month')::date;
  v_result jsonb;
begin
  v_result := public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 75.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_m1::text, v_m2::text, v_m3::text)
    ),
    gen_random_uuid()
  );

  if jsonb_array_length(v_result -> 'coverage_months') <> 3 then
    raise exception 'case2 failed: expected 3 coverage months';
  end if;
  if (v_result ->> 'invoice_total')::numeric(15,3) <> 75.000 then
    raise exception 'case2 failed: invoice total mismatch';
  end if;
end $$;
rollback;

-- 3. Duplicate period billing is rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
begin
  perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month::text)
    ),
    gen_random_uuid()
  );

  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 25.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(v_month::text)
      ),
      gen_random_uuid()
    );
    raise exception 'case3 failed: duplicate month accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 4. Idempotent retry returns same stable JSON and no duplicates.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
  v_key uuid := gen_random_uuid();
  v_a jsonb;
  v_b jsonb;
  v_invoice uuid;
  v_voucher uuid;
  v_count int;
begin
  v_a := public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month::text)
    ),
    v_key
  );
  v_b := public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month::text)
    ),
    v_key
  );

  if v_a is distinct from v_b then
    raise exception 'case4 failed: replay payload changed';
  end if;

  v_invoice := (v_a ->> 'invoice_id')::uuid;
  v_voucher := (v_a ->> 'voucher_id')::uuid;
  select count(*) into v_count from public.invoices where id = v_invoice;
  if v_count <> 1 then
    raise exception 'case4 failed: duplicate invoice rows';
  end if;
  select count(*) into v_count from public.vouchers where id = v_voucher;
  if v_count <> 1 then
    raise exception 'case4 failed: duplicate voucher rows';
  end if;
end $$;
rollback;

-- 5. Same idempotency key with different payload is rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
  v_key uuid := gen_random_uuid();
begin
  perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month::text)
    ),
    v_key
  );

  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 50.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(v_month::text, (v_month + interval '1 month')::date::text)
      ),
      v_key
    );
    raise exception 'case5 failed: mismatch payload accepted';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 6. Trial contract billing is rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture(false);
  v_trial uuid;
begin
  v_trial := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product_id',
          'product_unit_id', v_fixture ->> 'asset_unit_id'
        )
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_trial,
        'date', current_date,
        'amount', 25.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(date_trunc('month', current_date)::date::text)
      ),
      gen_random_uuid()
    );
    raise exception 'case6 failed: trial billing accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 7. Closed contract billing beyond allowed month is rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_contract uuid := (v_fixture ->> 'contract_id')::uuid;
  v_future_month date := date_trunc('month', current_date + interval '2 month')::date;
begin
  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_contract,
      'closure_type', 'normal',
      'close_reason', 'closed for M5 test',
      'close_date', current_date,
      'return_condition', 'available_used'
    ),
    gen_random_uuid()
  );

  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_contract,
        'date', current_date,
        'amount', 25.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(v_future_month::text)
      ),
      gen_random_uuid()
    );
    raise exception 'case7 failed: closed out-of-window billing accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 8. Amount mismatch is rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
begin
  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 20.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(date_trunc('month', current_date)::date::text)
      ),
      gen_random_uuid()
    );
    raise exception 'case8 failed: mismatch amount accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 9. Rental invoice creates no stock movement and no COGS lines.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_result jsonb;
  v_invoice uuid;
  v_invoice_je uuid;
  v_move_count int;
  v_cogs_count int;
begin
  v_result := public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(date_trunc('month', current_date)::date::text)
    ),
    gen_random_uuid()
  );

  v_invoice := (v_result ->> 'invoice_id')::uuid;
  select i.journal_entry_id into v_invoice_je from public.invoices i where i.id = v_invoice;

  select count(*) into v_move_count
  from public.inventory_movements im
  where im.reference_table = 'sales_invoice'
    and im.reference_id = v_invoice;

  if v_move_count <> 0 then
    raise exception 'case9 failed: unexpected inventory movement';
  end if;

  select count(*) into v_cogs_count
  from public.journal_lines jl
  join public.chart_of_accounts coa
    on coa.id = jl.account_id
   and coa.tenant_id = jl.tenant_id
  where jl.journal_entry_id = v_invoice_je
    and coa.code in ('5101', '1301');

  if v_cogs_count <> 0 then
    raise exception 'case9 failed: COGS/inventory lines found';
  end if;
end $$;
rollback;

-- 10. Tax/rounding and rental service product tax policy behave as expected (non_taxable v1).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_result jsonb;
  v_invoice uuid;
  v_product uuid;
  v_tax_class public.product_tax_class;
  v_tax_amount numeric(15,3);
begin
  v_result := public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(date_trunc('month', current_date)::date::text)
    ),
    gen_random_uuid()
  );

  v_invoice := (v_result ->> 'invoice_id')::uuid;
  select il.product_id, il.tax_amount
  into v_product, v_tax_amount
  from public.invoice_lines il
  where il.invoice_id = v_invoice
  order by il.line_order
  limit 1;

  select p.tax_class into v_tax_class
  from public.products p
  where p.id = v_product;

  if v_tax_class <> 'non_taxable'::public.product_tax_class then
    raise exception 'case10 failed: system rental product tax_class must be non_taxable';
  end if;
  if coalesce(v_tax_amount, 0) <> 0 then
    raise exception 'case10 failed: tax amount must be zero for non_taxable v1';
  end if;
  if (v_result ->> 'invoice_total')::numeric(15,3) <> (v_result ->> 'collected_amount')::numeric(15,3) then
    raise exception 'case10 failed: invoice total must equal collected amount';
  end if;
end $$;
rollback;

-- 11. Allocation updates payment state only (no third journal).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_before int;
  v_after int;
begin
  select count(*) into v_before from public.journal_entries;

  perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(date_trunc('month', current_date)::date::text)
    ),
    gen_random_uuid()
  );

  select count(*) into v_after from public.journal_entries;
  if v_after - v_before <> 2 then
    raise exception 'case11 failed: expected exactly two journals (invoice + receipt)';
  end if;
end $$;
rollback;

-- 12. Coverage remains blocked after invoice cancellation (permanent coverage rule in M5 v1).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
  v_result jsonb;
begin
  v_result := public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month::text)
    ),
    gen_random_uuid()
  );

  perform public.cancel_voucher((v_result ->> 'voucher_id')::uuid, 'test cancellation', gen_random_uuid());

  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 25.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(v_month::text)
      ),
      gen_random_uuid()
    );
    raise exception 'case12 failed: rebilling cancelled coverage month accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 13. Unauthorized user cannot collect rental payment.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.p6m5.fixture', pg_temp.p6m5_setup_fixture()::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m5.fixture')::jsonb;
begin
  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 25.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(date_trunc('month', current_date)::date::text)
      ),
      gen_random_uuid()
    );
    raise exception 'case13 failed: unauthorized collection accepted';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 14. Preview is read-only and does not provision SYS-RENTAL-MONTHLY.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_tenant uuid := (v_fixture ->> 'tenant_id')::uuid;
  v_month date := date_trunc('month', current_date)::date;
  v_before int;
  v_after int;
  v_preview jsonb;
begin
  select count(*) into v_before
  from public.products p
  where p.tenant_id = v_tenant
    and p.sku = 'SYS-RENTAL-MONTHLY';

  if v_before <> 0 then
    raise exception 'case14 failed: fixture must start without system rental product';
  end if;

  v_preview := public.preview_rental_collection(
    jsonb_build_object(
      'contract_id', v_fixture ->> 'contract_id',
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', v_fixture ->> 'cash_account_id',
      'coverage_months', jsonb_build_array(v_month::text)
    )
  );

  select count(*) into v_after
  from public.products p
  where p.tenant_id = v_tenant
    and p.sku = 'SYS-RENTAL-MONTHLY';

  if v_after <> 0 then
    raise exception 'case14 failed: preview must not create SYS-RENTAL-MONTHLY';
  end if;

  if (v_preview ->> 'invoice_total')::numeric(15,3) <> 25.000 then
    raise exception 'case14 failed: preview invoice total mismatch';
  end if;
  if (v_preview ->> 'tax_policy') <> 'non_taxable_v1' then
    raise exception 'case14 failed: preview tax_policy must be non_taxable_v1';
  end if;
end $$;
rollback;

-- 15. Duplicate coverage months in one payload are rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
  v_month date := date_trunc('month', current_date)::date;
begin
  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 50.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array(v_month::text, v_month::text)
      ),
      gen_random_uuid()
    );
    raise exception 'case15 failed: duplicate coverage months accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 16. Invalid coverage month input is rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.p6m5_setup_fixture();
begin
  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 25.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array('not-a-date')
      ),
      gen_random_uuid()
    );
    raise exception 'case16 failed: invalid coverage month accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    perform public.collect_rental_payment(
      jsonb_build_object(
        'contract_id', v_fixture ->> 'contract_id',
        'date', current_date,
        'amount', 25.000,
        'payment_method', 'cash',
        'cash_account_id', v_fixture ->> 'cash_account_id',
        'coverage_months', jsonb_build_array('2026-13-01')
      ),
      gen_random_uuid()
    );
    raise exception 'case16 failed: out-of-range coverage month accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

