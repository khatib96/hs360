-- Phase 5 M7: voucher, allocation, and payment engine verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase F.
-- Manual: docker exec -i supabase_db_hs360 psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/phase_5_vouchers.sql

\set ON_ERROR_STOP on

-- Seed constants:
--   tenant_a=101, owner=201, zero_user=202, owner_tu=301, zero_tu=302
--   cash=501, bank=502, expense=508, inventory=505, main_warehouse=701, oils_group=802

-- ---------------------------------------------------------------------------
-- 1. Receipt exact allocation manual: sale 125, receipt 125 -> paid
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_voucher_id uuid;
  v_status text;
  v_paid numeric;
  v_total numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-1', 'phone_primary', '+96550007001', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-1', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-1-' || left(gen_random_uuid()::text, 8),
    'زيت M7-1', 'M7 Oil 1', v_oils_group, 'consumable_rental', 'ml',
    125.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 125.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 125,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 125)
      )
    ),
    gen_random_uuid()
  );

  select status::text, paid_amount, total
  into v_status, v_paid, v_total
  from public.invoices where id = v_sale_id;

  if v_status is distinct from 'paid' or v_paid <> 125 or v_total <> 125 then
    raise exception 'case1 failed: status=% paid=% total=%', v_status, v_paid, v_total;
  end if;

  if not exists (
    select 1 from public.vouchers where id = v_voucher_id and status = 'confirmed'
  ) then
    raise exception 'case1 failed: voucher not confirmed';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. Receipt partial manual: sale 125, receipt 50 -> partially_paid paid_amount 50
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_status text;
  v_paid numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-2', 'phone_primary', '+96550007002', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-2', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-2-' || left(gen_random_uuid()::text, 8),
    'زيت M7-2', 'M7 Oil 2', v_oils_group, 'consumable_rental', 'ml',
    125.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 125.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 50,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 50)
      )
    ),
    gen_random_uuid()
  );

  select status::text, paid_amount into v_status, v_paid
  from public.invoices where id = v_sale_id;

  if v_status is distinct from 'partially_paid' or v_paid <> 50 then
    raise exception 'case2 failed: status=% paid=%', v_status, v_paid;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3. FIFO two sales invoices: older due_date allocated first
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_old uuid;
  v_sale_new uuid;
  v_voucher_id uuid;
  v_alloc_old numeric;
  v_alloc_new numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-3', 'phone_primary', '+96550007003', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-3', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-3-' || left(gen_random_uuid()::text, 8),
    'زيت M7-3', 'M7 Oil 3', v_oils_group, 'consumable_rental', 'ml',
    100.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_old := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse,
      'date', current_date, 'due_date', current_date + 5,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 100.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_new := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse,
      'date', current_date, 'due_date', current_date + 30,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 100.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 150,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'fifo'
    ),
    gen_random_uuid()
  );

  select coalesce(sum(allocated_amount), 0) into v_alloc_old
  from public.voucher_invoice_allocations
  where voucher_id = v_voucher_id and invoice_id = v_sale_old and coalesce(is_reversed, false) = false;

  select coalesce(sum(allocated_amount), 0) into v_alloc_new
  from public.voucher_invoice_allocations
  where voucher_id = v_voucher_id and invoice_id = v_sale_new and coalesce(is_reversed, false) = false;

  if v_alloc_old <> 100 or v_alloc_new <> 50 then
    raise exception 'case3 failed: old=% new=%', v_alloc_old, v_alloc_new;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4. Manual valid allocation (partial, sum < voucher amount)
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_voucher_id uuid;
  v_alloc_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-4', 'phone_primary', '+96550007004', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-4', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-4-' || left(gen_random_uuid()::text, 8),
    'زيت M7-4', 'M7 Oil 4', v_oils_group, 'consumable_rental', 'ml',
    125.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 125.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 80,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 75)
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_alloc_count
  from public.voucher_invoice_allocations
  where voucher_id = v_voucher_id and coalesce(is_reversed, false) = false;

  if v_voucher_id is null or v_alloc_count <> 1 then
    raise exception 'case4 failed: voucher=% alloc_count=%', v_voucher_id, v_alloc_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4b. Manual rejects empty allocations[] for receipt and supplier payment
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_supplier uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-4b', 'phone_primary', '+96550007004b', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-4b', 'create_account', true)
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 50,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'manual', 'allocations', '[]'::jsonb
      ),
      gen_random_uuid()
    );
    raise exception 'case4b failed: receipt manual [] accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_payment_voucher(
      jsonb_build_object(
        'payment_destination', 'supplier', 'supplier_id', v_supplier,
        'date', current_date, 'amount', 50,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'manual', 'allocations', '[]'::jsonb
      ),
      gen_random_uuid()
    );
    raise exception 'case4b failed: supplier manual [] accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 5. Customer unallocated: sale 100, receipt 150 unallocated, invoice paid_amount 0
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_voucher_id uuid;
  v_paid numeric;
  v_alloc_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-5', 'phone_primary', '+96550007005', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-5', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-5-' || left(gen_random_uuid()::text, 8),
    'زيت M7-5', 'M7 Oil 5', v_oils_group, 'consumable_rental', 'ml',
    100.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 100.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 150,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated'
    ),
    gen_random_uuid()
  );

  select paid_amount into v_paid from public.invoices where id = v_sale_id;

  select count(*) into v_alloc_count
  from public.voucher_invoice_allocations where voucher_id = v_voucher_id;

  if v_paid <> 0 or v_voucher_id is null or v_alloc_count <> 0 then
    raise exception 'case5 failed: paid=% voucher=% allocs=%', v_paid, v_voucher_id, v_alloc_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6. Wrong customer invoice on receipt manual rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer_a uuid;
  v_customer_b uuid;
  v_product uuid;
  v_sale_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer_a := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-6A', 'phone_primary', '+96550007006a', 'create_account', true)
  );
  v_customer_b := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-6B', 'phone_primary', '+96550007006b', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-6', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-6-' || left(gen_random_uuid()::text, 8),
    'زيت M7-6', 'M7 Oil 6', v_oils_group, 'consumable_rental', 'ml',
    125.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer_a, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 125.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer_b, 'date', current_date, 'amount', 125,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'manual',
        'allocations', jsonb_build_array(
          jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 125)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case6 failed: wrong customer allocation accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7. Purchase invoice on receipt manual rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_purchase_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-7', 'phone_primary', '+96550007007', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-7', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-7-' || left(gen_random_uuid()::text, 8),
    'زيت M7-7', 'M7 Oil 7', v_oils_group, 'consumable_rental', 'ml',
    10.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 100,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'manual',
        'allocations', jsonb_build_array(
          jsonb_build_object('invoice_id', v_purchase_id, 'allocated_amount', 100)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case7 failed: purchase invoice on receipt accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8. Allocation over outstanding rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-8', 'phone_primary', '+96550007008', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-8', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-8-' || left(gen_random_uuid()::text, 8),
    'زيت M7-8', 'M7 Oil 8', v_oils_group, 'consumable_rental', 'ml',
    125.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 125.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 200,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'manual',
        'allocations', jsonb_build_array(
          jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 200)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case8 failed: over-allocation accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9. Supplier payment manual against purchase invoice
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_voucher_id uuid;
  v_status text;
  v_paid numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-9', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-9-' || left(gen_random_uuid()::text, 8),
    'زيت M7-9', 'M7 Oil 9', v_oils_group, 'consumable_rental', 'ml',
    10.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_payment_voucher(
    jsonb_build_object(
      'payment_destination', 'supplier', 'supplier_id', v_supplier,
      'date', current_date, 'amount', 100,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_purchase_id, 'allocated_amount', 100)
      )
    ),
    gen_random_uuid()
  );

  select status::text, paid_amount into v_status, v_paid
  from public.invoices where id = v_purchase_id;

  if v_voucher_id is null or v_status is distinct from 'paid' or v_paid <> 100 then
    raise exception 'case9 failed: voucher=% status=% paid=%', v_voucher_id, v_status, v_paid;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10. Supplier unallocated rejected; supplier manual [] rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-10', 'create_account', true)
  );

  begin
    perform public.record_payment_voucher(
      jsonb_build_object(
        'payment_destination', 'supplier', 'supplier_id', v_supplier,
        'date', current_date, 'amount', 50,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'unallocated'
      ),
      gen_random_uuid()
    );
    raise exception 'case10 failed: supplier unallocated accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11. Direct expense payment 6101 (508) as manager owner
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_expense uuid := '00000000-0000-0000-0000-000000000508';
  v_voucher_id uuid;
  v_je_id uuid;
  v_debit numeric;
  v_credit numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_voucher_id := public.record_payment_voucher(
    jsonb_build_object(
      'payment_destination', 'account', 'account_id', v_expense,
      'date', current_date, 'amount', 25,
      'payment_method', 'cash', 'cash_account_id', v_cash
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id
  from public.vouchers where id = v_voucher_id;

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.journal_lines where journal_entry_id = v_je_id;

  if v_voucher_id is null or v_debit <> v_credit or v_debit <> 25 then
    raise exception 'case11 failed: debit=% credit=%', v_debit, v_credit;
  end if;

  if not exists (
    select 1 from public.journal_lines
    where journal_entry_id = v_je_id and account_id = v_expense and debit = 25
  ) then
    raise exception 'case11 failed: expense debit missing';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12. Direct payment rejects inventory, AR, AP, and cash debit accounts
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_bank uuid := '00000000-0000-0000-0000-000000000502';
  v_ar uuid := '00000000-0000-0000-0000-000000000503';
  v_ap uuid := '00000000-0000-0000-0000-000000000504';
  v_inventory uuid := '00000000-0000-0000-0000-000000000505';
  v_reject_account uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  foreach v_reject_account in array array[v_inventory, v_ar, v_ap, v_cash, v_bank]
  loop
    begin
      perform public.record_payment_voucher(
        jsonb_build_object(
          'payment_destination', 'account', 'account_id', v_reject_account,
          'date', current_date, 'amount', 10,
          'payment_method', 'cash', 'cash_account_id', v_cash
        ),
        gen_random_uuid()
      );
      raise exception 'case12 failed: direct payment to % accepted', v_reject_account;
    exception
      when others then
        if sqlerrm not like '%validation_failed%' then raise; end if;
    end;
  end loop;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13. Invalid cash account: customer AR account as cash_account_id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid;
  v_ar_account uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-13', 'phone_primary', '+96550007013', 'create_account', true)
  );

  select account_id into v_ar_account from public.customers where id = v_customer;

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 50,
        'payment_method', 'cash', 'cash_account_id', v_ar_account,
        'allocation_mode', 'unallocated'
      ),
      gen_random_uuid()
    );
    raise exception 'case13 failed: AR as cash accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14. Status transition to paid on full receipt
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_status_before text;
  v_status_after text;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-14', 'phone_primary', '+96550007014', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-14', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-14-' || left(gen_random_uuid()::text, 8),
    'زيت M7-14', 'M7 Oil 14', v_oils_group, 'consumable_rental', 'ml',
    125.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 125.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select status::text into v_status_before from public.invoices where id = v_sale_id;

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 125,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 125)
      )
    ),
    gen_random_uuid()
  );

  select status::text into v_status_after from public.invoices where id = v_sale_id;

  if v_status_before is distinct from 'confirmed' or v_status_after is distinct from 'paid' then
    raise exception 'case14 failed: before=% after=%', v_status_before, v_status_after;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 15. cancel_voucher restores outstanding and creates balanced reversal journal
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_voucher_id uuid;
  v_reversal_je uuid;
  v_paid numeric;
  v_status text;
  v_debit numeric;
  v_credit numeric;
  v_reversed boolean;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-15', 'phone_primary', '+96550007015', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-15', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-15-' || left(gen_random_uuid()::text, 8),
    'زيت M7-15', 'M7 Oil 15', v_oils_group, 'consumable_rental', 'ml',
    125.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 125.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 125,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 125)
      )
    ),
    gen_random_uuid()
  );

  perform public.cancel_voucher(v_voucher_id, 'M7 case 15 cancel', gen_random_uuid());

  select paid_amount, status::text into v_paid, v_status
  from public.invoices where id = v_sale_id;

  select reversal_journal_entry_id into v_reversal_je
  from public.vouchers where id = v_voucher_id;

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.journal_lines where journal_entry_id = v_reversal_je;

  select bool_and(is_reversed) into v_reversed
  from public.voucher_invoice_allocations where voucher_id = v_voucher_id;

  if v_paid <> 0 or v_status is distinct from 'confirmed'
    or v_debit <> v_credit or v_debit <> 125
    or coalesce(v_reversed, false) = false then
    raise exception 'case15 failed: paid=% status=% debit=% credit=% reversed=%',
      v_paid, v_status, v_debit, v_credit, v_reversed;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16. cancel_voucher double cancel rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_voucher_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-16', 'phone_primary', '+96550007016', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-16', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-16-' || left(gen_random_uuid()::text, 8),
    'زيت M7-16', 'M7 Oil 16', v_oils_group, 'consumable_rental', 'ml',
    50.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 50,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated'
    ),
    gen_random_uuid()
  );

  perform public.cancel_voucher(v_voucher_id, 'M7 case 16 first', gen_random_uuid());

  begin
    perform public.cancel_voucher(v_voucher_id, 'M7 case 16 second', gen_random_uuid());
    raise exception 'case16 failed: double cancel accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17. Idempotency: same key + same payload returns same voucher id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_key uuid := gen_random_uuid();
  v_payload jsonb;
  v_id1 uuid;
  v_id2 uuid;
  v_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-17', 'phone_primary', '+96550007017', 'create_account', true)
  );

  v_payload := jsonb_build_object(
    'customer_id', v_customer, 'date', current_date, 'amount', 25,
    'payment_method', 'cash', 'cash_account_id', v_cash,
    'allocation_mode', 'unallocated'
  );

  v_id1 := public.record_receipt_voucher(v_payload, v_key);
  v_id2 := public.record_receipt_voucher(v_payload, v_key);

  if v_id1 is distinct from v_id2 then
    raise exception 'case17 failed: ids differ % vs %', v_id1, v_id2;
  end if;

  select count(*) into v_count
  from public.vouchers where idempotency_key = v_key;

  if v_count <> 1 then
    raise exception 'case17 failed: voucher count %', v_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18. Idempotency payload mismatch
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_key uuid := gen_random_uuid();
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-18', 'phone_primary', '+96550007018', 'create_account', true)
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 25,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated'
    ),
    v_key
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 30,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'unallocated'
      ),
      v_key
    );
    raise exception 'case18 failed: idempotency mismatch not raised';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19. Permission denied: zero user cannot create receipt
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-19', 'phone_primary', '+96550007019', 'create_account', true)
  );

  perform set_config('test.m7.case19.customer', v_customer::text, true);
end $$;
do $$
declare
  v_zero_tu uuid := '00000000-0000-0000-0000-000000000302';
begin
  delete from public.user_permissions where tenant_user_id = v_zero_tu;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid := current_setting('test.m7.case19.customer')::uuid;
begin
  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'unallocated'
      ),
      gen_random_uuid()
    );
    raise exception 'case19 failed: receipt allowed for zero user';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20. Permission denied: zero user cannot create payment
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_supplier uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-20', 'create_account', true)
  );

  perform set_config('test.m7.case20.supplier', v_supplier::text, true);
end $$;
do $$
declare
  v_zero_tu uuid := '00000000-0000-0000-0000-000000000302';
begin
  delete from public.user_permissions where tenant_user_id = v_zero_tu;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid := current_setting('test.m7.case20.supplier')::uuid;
begin
  begin
    perform public.record_payment_voucher(
      jsonb_build_object(
        'payment_destination', 'supplier', 'supplier_id', v_supplier,
        'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'fifo'
      ),
      gen_random_uuid()
    );
    raise exception 'case20 failed: payment allowed for zero user';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 21. Permission denied: zero user cannot cancel or list vouchers
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_voucher_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-21', 'phone_primary', '+96550007021', 'create_account', true)
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 10,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated'
    ),
    gen_random_uuid()
  );

  perform set_config('test.m7.case21.voucher_id', v_voucher_id::text, true);
end $$;
do $$
declare
  v_zero_tu uuid := '00000000-0000-0000-0000-000000000302';
begin
  delete from public.user_permissions where tenant_user_id = v_zero_tu;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_voucher_id uuid := current_setting('test.m7.case21.voucher_id')::uuid;
begin
  begin
    perform public.cancel_voucher(v_voucher_id, 'denied', gen_random_uuid());
    raise exception 'case21 failed: cancel allowed for zero user';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;

  begin
    perform count(*) from public.list_vouchers();
    raise exception 'case21 failed: list_vouchers allowed for zero user';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 22. Cross-tenant cash account rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash_b uuid := '00000000-0000-0000-0000-000000000509';
  v_customer uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-22', 'phone_primary', '+96550007022', 'create_account', true)
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash_b,
        'allocation_mode', 'unallocated'
      ),
      gen_random_uuid()
    );
    raise exception 'case22 failed: tenant B cash accepted';
  exception
    when others then
      if sqlerrm not like '%cross_tenant_reference%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 23. books_locked_through rejects voucher post
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_prior_lock date;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  select books_locked_through into v_prior_lock
  from public.tenant_settings where tenant_id = v_tenant_a;

  update public.tenant_settings
  set books_locked_through = current_date
  where tenant_id = v_tenant_a;

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-23', 'phone_primary', '+96550007023', 'create_account', true)
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'unallocated'
      ),
      gen_random_uuid()
    );
    raise exception 'case23 failed: locked period post accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  update public.tenant_settings
  set books_locked_through = v_prior_lock
  where tenant_id = v_tenant_a;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 24. Direct insert on vouchers and allocations denied
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
begin
  begin
    insert into public.vouchers (
      tenant_id, voucher_number, type, date, amount, payment_method,
      account_id, cash_account_id
    )
    values (
      v_tenant_a, 'RV-TEST', 'receipt', current_date, 10, 'cash',
      v_cash, v_cash
    );
    raise exception 'case24 failed: direct voucher insert accepted';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%'
        and sqlerrm not like '%insufficient_privilege%' then
        raise;
      end if;
  end;

  begin
    insert into public.voucher_invoice_allocations (
      tenant_id, voucher_id, invoice_id, allocated_amount
    )
    values (
      v_tenant_a, gen_random_uuid(), gen_random_uuid(), 1
    );
    raise exception 'case24 failed: direct allocation insert accepted';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%'
        and sqlerrm not like '%insufficient_privilege%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 25. Unknown JSON keys rejected on receipt payload
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-25', 'phone_primary', '+96550007025', 'create_account', true)
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'unallocated',
        'voucher_number', 'RV-HACK'
      ),
      gen_random_uuid()
    );
    raise exception 'case25 failed: unknown key accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 26. Malformed allocation_mode rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-26', 'phone_primary', '+96550007026', 'create_account', true)
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'bogus_mode'
      ),
      gen_random_uuid()
    );
    raise exception 'case26 failed: bogus allocation_mode accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 27. cancel_invoice blocked after RPC receipt allocation
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-27', 'phone_primary', '+96550007027', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-27', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-27-' || left(gen_random_uuid()::text, 8),
    'زيت M7-27', 'M7 Oil 27', v_oils_group, 'consumable_rental', 'ml',
    100.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 100.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 50,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 50)
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.cancel_invoice(v_sale_id, 'M7 case 27', gen_random_uuid());
    raise exception 'case27 failed: cancel_invoice allowed after voucher';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 28. Internal helper ACL denied for authenticated
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.normalize_receipt_voucher_payload('{}'::jsonb);
    raise exception 'case28 failed: normalize helper callable';
  exception
    when others then
      if sqlerrm not like '%insufficient_privilege%'
        and sqlerrm not like '%permission denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 29. cancel_voucher idempotency retry returns same voucher
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_voucher_id uuid;
  v_key uuid := gen_random_uuid();
  v_id1 uuid;
  v_id2 uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-29', 'phone_primary', '+96550007029', 'create_account', true)
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 15,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated'
    ),
    gen_random_uuid()
  );

  v_id1 := public.cancel_voucher(v_voucher_id, 'M7 case 29 cancel', v_key);
  v_id2 := public.cancel_voucher(v_voucher_id, 'M7 case 29 cancel', v_key);

  if v_id1 is distinct from v_id2 or v_id1 is distinct from v_voucher_id then
    raise exception 'case29 failed: ids % % %', v_id1, v_id2, v_voucher_id;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 30. Late failure rollback: zero residual voucher/allocation/journal
-- ---------------------------------------------------------------------------
begin;
create or replace function public.test_m7_journal_lines_fail_trigger()
returns trigger
language plpgsql
as $$
begin
  if current_setting('test.m7.journal_fail_marker', true) = '__M7_ROLLBACK_MARKER__' then
    raise exception 'test_m7_late_failure';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_test_m7_journal_fail on public.journal_lines;
create trigger trg_test_m7_journal_fail
  before insert on public.journal_lines
  for each row
  execute function public.test_m7_journal_lines_fail_trigger();

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_before_v int;
  v_after_v int;
  v_before_alloc int;
  v_after_alloc int;
  v_before_je int;
  v_after_je int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-30', 'phone_primary', '+96550007030', 'create_account', true)
  );

  select count(*) into v_before_v from public.vouchers where tenant_id = v_tenant_a;
  select count(*) into v_before_alloc from public.voucher_invoice_allocations where tenant_id = v_tenant_a;
  select count(*) into v_before_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'receipt_voucher';

  perform set_config('test.m7.journal_fail_marker', '__M7_ROLLBACK_MARKER__', true);

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer, 'date', current_date, 'amount', 20,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'unallocated'
      ),
      gen_random_uuid()
    );
    raise exception 'case30 failed: late failure not raised';
  exception
    when others then
      if sqlerrm not like '%test_m7_late_failure%' then raise; end if;
  end;

  select count(*) into v_after_v from public.vouchers where tenant_id = v_tenant_a;
  select count(*) into v_after_alloc from public.voucher_invoice_allocations where tenant_id = v_tenant_a;
  select count(*) into v_after_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'receipt_voucher';

  if v_after_v <> v_before_v or v_after_alloc <> v_before_alloc or v_after_je <> v_before_je then
    raise exception 'case30 failed: residual v %->% alloc %->% je %->%',
      v_before_v, v_after_v, v_before_alloc, v_after_alloc, v_before_je, v_after_je;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 31. list_vouchers and get_voucher_detail smoke
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_voucher_id uuid;
  v_list_count int;
  v_detail jsonb;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-31', 'phone_primary', '+96550007031', 'create_account', true)
  );

  v_voucher_id := public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 33,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated', 'reference_no', 'M7-31'
    ),
    gen_random_uuid()
  );

  select count(*) into v_list_count
  from public.list_vouchers(v_customer, 'receipt', null, null, null, 'M7-31', 50, 0);

  if v_list_count < 1 then
    raise exception 'case31 failed: list_vouchers count %', v_list_count;
  end if;

  v_detail := public.get_voucher_detail(v_voucher_id);

  if (v_detail ->> 'id')::uuid is distinct from v_voucher_id
    or (v_detail ->> 'unallocated_amount')::numeric <> 33 then
    raise exception 'case31 failed: detail %', v_detail;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 32. list_open_customer_invoices and list_open_supplier_invoices smoke
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_cust_open int;
  v_supp_open int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-32', 'phone_primary', '+96550007032', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M7-32', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M7-OIL-32-' || left(gen_random_uuid()::text, 8),
    'زيت M7-32', 'M7 Oil 32', v_oils_group, 'consumable_rental', 'ml',
    80.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 80.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_cust_open from public.list_open_customer_invoices(v_customer);
  select count(*) into v_supp_open from public.list_open_supplier_invoices(v_supplier);

  if v_cust_open < 1 or v_supp_open < 1 then
    raise exception 'case32 failed: cust_open=% supp_open=%', v_cust_open, v_supp_open;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 33. get_cash_bank_activity opening balance from prior posted journal lines
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_prior_date date := current_date - 5;
  v_activity jsonb;
  v_opening numeric;
  v_first_running numeric;
  v_first_net numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M7-33', 'phone_primary', '+96550007033', 'create_account', true)
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', v_prior_date, 'amount', 50,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated'
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 10,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'unallocated'
    ),
    gen_random_uuid()
  );

  v_activity := public.get_cash_bank_activity(v_cash, current_date, current_date, 50, 0);
  v_opening := (v_activity ->> 'opening_balance')::numeric;

  if v_opening <> 50 then
    raise exception 'case33 failed: opening_balance=% expected 50', v_opening;
  end if;

  if jsonb_array_length(v_activity -> 'rows') < 1 then
    raise exception 'case33 failed: no activity rows on current_date';
  end if;

  v_first_net := (
    (v_activity -> 'rows' -> 0 ->> 'debit')::numeric
    - (v_activity -> 'rows' -> 0 ->> 'credit')::numeric
  );
  v_first_running := (v_activity -> 'rows' -> 0 ->> 'running_balance')::numeric;

  if v_first_running <> v_opening + v_first_net then
    raise exception 'case33 failed: running=% opening=% net=%',
      v_first_running, v_opening, v_first_net;
  end if;
end $$;
rollback;
