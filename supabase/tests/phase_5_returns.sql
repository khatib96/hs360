-- Phase 5 M7.5: sales/purchase return and credit engine verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase G.
-- Manual: docker exec -i supabase_db_hs360 psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/phase_5_returns.sql

\set ON_ERROR_STOP on

-- Seed constants:
--   tenant_a=101, tenant_b=102, owner=201, zero_user=202, products_user=203
--   owner_tu=301, zero_tu=302, products_tu=303
--   product_a=901 (serialized), oils_group=802, main_warehouse=701, van_warehouse=702
--   cash=501
-- Idempotency keys: ...e001 through ...e004
-- Phones: +96550008xxx (case number)

-- ===========================================================================
-- Block A: Sales return (cases 1-4)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Full non-serialized sales return: stock restore, sale_return movement, balanced journal
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
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_je_id uuid;
  v_stock numeric;
  v_movement_type text;
  v_debit numeric;
  v_credit numeric;
  v_inv_type text;
  v_inv_status text;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-1', 'phone_primary', '+96550008001', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-1', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M75-SR-1-' || left(gen_random_uuid()::text, 8),
    'زيت M75-1', 'M75 Oil 1', v_oils_group, 'consumable_rental', 'ml',
    12.500, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 100, 'unit_price', 2.500, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 12.500, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id
  from public.invoice_lines
  where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Full return case 1',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 10, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select qty_available into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  if v_stock <> 100 then
    raise exception 'case1 failed: stock % expected 100', v_stock;
  end if;

  select movement_type::text into v_movement_type
  from public.inventory_movements
  where tenant_id = v_tenant_a
    and reference_table = 'sales_return_invoice'
    and reference_id = v_return_id;

  if v_movement_type is distinct from 'sale_return' then
    raise exception 'case1 failed: movement_type %', v_movement_type;
  end if;

  select journal_entry_id, type::text, status::text, invoice_number
  into v_je_id, v_inv_type, v_inv_status, v_movement_type
  from public.invoices where id = v_return_id;

  if v_inv_type is distinct from 'sales_return'
    or v_inv_status is distinct from 'confirmed'
    or v_movement_type not like 'SR%' then
    raise exception 'case1 failed: type=% status=% number=%', v_inv_type, v_inv_status, v_movement_type;
  end if;

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.journal_lines where journal_entry_id = v_je_id;

  if v_debit <> v_credit or v_debit <= 0 then
    raise exception 'case1 failed: journal debit=% credit=%', v_debit, v_credit;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. Partial sales return: returnable qty decreases
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
  v_sale_id uuid;
  v_line_id uuid;
  v_returnable numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-2', 'phone_primary', '+96550008002', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-2', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M75-SR-2-' || left(gen_random_uuid()::text, 8),
    'زيت M75-2', 'M75 Oil 2', v_oils_group, 'consumable_rental', 'ml',
    10.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 50, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 20, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  perform public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Partial return case 2',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 7, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select returnable_qty into v_returnable
  from public.list_returnable_invoice_lines(v_sale_id)
  where original_line_id = v_line_id;

  if v_returnable <> 13 then
    raise exception 'case2 failed: returnable_qty % expected 13', v_returnable;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3. Unpaid sales return settles original invoice outstanding via original_settlement
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_detail jsonb;
  v_alloc_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-3', 'phone_primary', '+96550008003', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-3', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-SR-3-' || left(gen_random_uuid()::text, 8),
    'زيت M75-3', 'M75 Oil 3', v_oils_group, 'consumable_rental', 'ml',
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

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Unpaid settlement case 3',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_detail := public.get_return_invoice_detail(v_return_id);

  select count(*) into v_alloc_count
  from jsonb_array_elements(v_detail -> 'credit_allocations') elem
  where elem ->> 'allocation_kind' = 'original_settlement'
    and (elem ->> 'allocated_amount')::numeric = 125
    and coalesce((elem ->> 'is_reversed')::boolean, false) = false;

  if v_alloc_count <> 1 or coalesce((v_detail ->> 'credit_remaining')::numeric, -1) <> 0 then
    raise exception 'case3 failed: alloc_count=% detail=%', v_alloc_count, v_detail;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4. Paid sales return creates customer credit (no original settlement)
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_credit_remaining numeric;
  v_credit_acct uuid;
  v_je_credit numeric;
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_detail jsonb;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-4', 'phone_primary', '+96550008004', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-4', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-SR-4-' || left(gen_random_uuid()::text, 8),
    'زيت M75-4', 'M75 Oil 4', v_oils_group, 'consumable_rental', 'ml',
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

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 80.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 80,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 80)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Paid return credit case 4',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_detail := public.get_return_invoice_detail(v_return_id);
  v_credit_remaining := (v_detail ->> 'credit_remaining')::numeric;

  select id into v_credit_acct
  from public.chart_of_accounts
  where tenant_id = v_tenant_a and code = '2150';

  select coalesce(sum(credit), 0) into v_je_credit
  from public.journal_lines jl
  join public.invoices i on i.journal_entry_id = jl.journal_entry_id
  where i.id = v_return_id and jl.account_id = v_credit_acct;

  if v_credit_remaining <> 80 or v_je_credit <> 80 then
    raise exception 'case4 failed: credit_remaining=% je_credit=%', v_credit_remaining, v_je_credit;
  end if;
end $$;
rollback;

-- ===========================================================================
-- Block B: Purchase return (cases 5-8)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 5. Full non-serialized purchase return: stock down, purchase_return movement, balanced journal
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
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_je_id uuid;
  v_stock numeric;
  v_movement_type text;
  v_debit numeric;
  v_credit numeric;
  v_inv_type text;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-5', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M75-PR-5-' || left(gen_random_uuid()::text, 8),
    'زيت M75-5', 'M75 Oil 5', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 50, 'unit_price', 2.500, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  v_return_id := public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Full purchase return case 5',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 50, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select qty_available into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  if v_stock <> 0 then
    raise exception 'case5 failed: stock % expected 0', v_stock;
  end if;

  select movement_type::text into v_movement_type
  from public.inventory_movements
  where tenant_id = v_tenant_a
    and reference_table = 'purchase_return_invoice'
    and reference_id = v_return_id;

  if v_movement_type is distinct from 'purchase_return' then
    raise exception 'case5 failed: movement_type %', v_movement_type;
  end if;

  select journal_entry_id, type::text into v_je_id, v_inv_type
  from public.invoices where id = v_return_id;

  if v_inv_type is distinct from 'purchase_return' then
    raise exception 'case5 failed: type %', v_inv_type;
  end if;

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.journal_lines where journal_entry_id = v_je_id;

  if v_debit <> v_credit or v_debit <= 0 then
    raise exception 'case5 failed: journal debit=% credit=%', v_debit, v_credit;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6. Partial purchase return
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
  v_stock numeric;
  v_returnable numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-6', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-PR-6-' || left(gen_random_uuid()::text, 8),
    'زيت M75-6', 'M75 Oil 6', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 40, 'unit_price', 3.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  perform public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Partial purchase return case 6',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 15, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select qty_available into v_stock
  from public.inventory_balances
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and warehouse_id = v_warehouse and product_id = v_product;

  select returnable_qty into v_returnable
  from public.list_returnable_invoice_lines(v_purchase_id)
  where original_line_id = v_line_id;

  if v_stock <> 25 or v_returnable <> 25 then
    raise exception 'case6 failed: stock=% returnable=%', v_stock, v_returnable;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7. Unpaid purchase return settles supplier A/P via original_settlement
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_detail jsonb;
  v_alloc_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-7', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-PR-7-' || left(gen_random_uuid()::text, 8),
    'زيت M75-7', 'M75 Oil 7', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 12.500, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  v_return_id := public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Unpaid purchase settlement case 7',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 10, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_detail := public.get_return_invoice_detail(v_return_id);

  select count(*) into v_alloc_count
  from jsonb_array_elements(v_detail -> 'credit_allocations') elem
  where elem ->> 'allocation_kind' = 'original_settlement'
    and (elem ->> 'allocated_amount')::numeric = 125
    and coalesce((elem ->> 'is_reversed')::boolean, false) = false;

  if v_alloc_count <> 1 or coalesce((v_detail ->> 'credit_remaining')::numeric, -1) <> 0 then
    raise exception 'case7 failed: alloc_count=% detail=%', v_alloc_count, v_detail;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8. Paid purchase return creates supplier credit receivable
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_credit_remaining numeric;
  v_detail jsonb;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-8', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-PR-8-' || left(gen_random_uuid()::text, 8),
    'زيت M75-8', 'M75 Oil 8', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 9.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_payment_voucher(
    jsonb_build_object(
      'payment_destination', 'supplier', 'supplier_id', v_supplier,
      'date', current_date, 'amount', 90,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_purchase_id, 'allocated_amount', 90)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  v_return_id := public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Paid purchase return credit case 8',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 10, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_detail := public.get_return_invoice_detail(v_return_id);
  v_credit_remaining := (v_detail ->> 'credit_remaining')::numeric;

  if v_credit_remaining <> 90 then
    raise exception 'case8 failed: credit_remaining %', v_credit_remaining;
  end if;
end $$;
rollback;


-- ===========================================================================
-- Block C: Validation (cases 9-14)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 9. Cumulative over-return rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-9', 'phone_primary', '+96550008009', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-9', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-V-9-' || left(gen_random_uuid()::text, 8),
    'زيت M75-9', 'M75 Oil 9', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 20, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  perform public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'First partial return',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 6, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Over-return attempt',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 5, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case9 failed: over-return accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10. Original line from different invoice rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_a uuid;
  v_sale_b uuid;
  v_line_b uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-10', 'phone_primary', '+96550008010', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-10', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-V-10-' || left(gen_random_uuid()::text, 8),
    'زيت M75-10', 'M75 Oil 10', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 30, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_a := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_b := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_b from public.invoice_lines where invoice_id = v_sale_b and line_order = 1;

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_a,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Wrong line linkage',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_b, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case10 failed: foreign line accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11. Warehouse mismatch rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_main_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_van_wh uuid := '00000000-0000-0000-0000-000000000702';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-11', 'phone_primary', '+96550008011', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-11', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-V-11-' || left(gen_random_uuid()::text, 8),
    'زيت M75-11', 'M75 Oil 11', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_main_wh, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_main_wh, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_van_wh,
        'date', current_date,
        'reason', 'Wrong warehouse',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case11 failed: warehouse mismatch accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12. Empty reason rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-12', 'phone_primary', '+96550008012', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-12', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-V-12-' || left(gen_random_uuid()::text, 8),
    'زيت M75-12', 'M75 Oil 12', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', '   ',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case12 failed: empty reason accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13. Sales return RPC against purchase invoice rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-13', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-V-13-' || left(gen_random_uuid()::text, 8),
    'زيت M75-13', 'M75 Oil 13', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_purchase_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Wrong invoice type',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case13 failed: sales return on purchase accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14. Purchase return rejected when insufficient stock
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-14', 'create_account', true)
  );
  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-14', 'phone_primary', '+96550008014', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-V-14-' || left(gen_random_uuid()::text, 8),
    'زيت M75-14', 'M75 Oil 14', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 8, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  begin
    perform public.record_purchase_return(
      jsonb_build_object(
        'original_invoice_id', v_purchase_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Return more than on hand',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 10, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case14 failed: insufficient stock accepted';
  exception
    when others then
      if sqlerrm not like '%insufficient_stock%' then raise; end if;
  end;
end $$;
rollback;


-- ===========================================================================
-- Block D: Tax (cases 15-17)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 15. Sales return reverses recoverable output tax
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_rate_id uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_output_acct uuid;
  v_tax_debit numeric;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-15', 'create_account', true)
  );
  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-15', 'phone_primary', '+96550008015', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, tax_class, created_by
  )
  values (
    v_tenant_a, 'M75-TAX-SR-' || left(gen_random_uuid()::text, 8),
    'زيت ضريبة مبيعات', 'Tax Sales Oil', v_oils_group, 'consumable_rental', 'ml',
    100.000, 0, false, true, 'taxable', v_owner
  )
  returning id into v_product;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M75-OUT-15', 'name_ar', 'ضريبة', 'name_en', 'Output 15',
      'rate', 5, 'effective_from', current_date - 30, 'is_recoverable', true
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object('tax_enabled', true, 'default_tax_rate_id', v_rate_id)
  );

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 20.000, 'discount_pct', 0, 'line_order', 1)
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

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Tax reversal case 15',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select output_account_id into v_output_acct from public.tax_rates where id = v_rate_id;

  select coalesce(sum(debit), 0) into v_tax_debit
  from public.journal_lines jl
  join public.invoices i on i.journal_entry_id = jl.journal_entry_id
  where i.id = v_return_id and jl.account_id = v_output_acct;

  if v_tax_debit <> 5 then
    raise exception 'case15 failed: output tax debit %', v_tax_debit;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16. Purchase return reverses recoverable input tax
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
  v_rate_id uuid;
  v_purchase_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_input_acct uuid;
  v_tax_credit numeric;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-16', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_tenant_a, 'M75-TAX-PR-R-' || left(gen_random_uuid()::text, 8),
    'زيت ضريبة شراء', 'Tax Purchase Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, 'taxable', v_owner
  )
  returning id into v_product;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M75-IN-16', 'name_ar', 'ضريبة', 'name_en', 'Input 16',
      'rate', 5, 'effective_from', current_date - 30, 'is_recoverable', true
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object('tax_enabled', true, 'default_tax_rate_id', v_rate_id)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  v_return_id := public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Recoverable tax return case 16',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 10, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select input_account_id into v_input_acct from public.tax_rates where id = v_rate_id;

  select coalesce(sum(credit), 0) into v_tax_credit
  from public.journal_lines jl
  join public.invoices i on i.journal_entry_id = jl.journal_entry_id
  where i.id = v_return_id and jl.account_id = v_input_acct;

  if v_tax_credit <> 5 then
    raise exception 'case16 failed: input tax credit %', v_tax_credit;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17. Purchase return with non-recoverable tax: no input tax reversal line
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
  v_rate_id uuid;
  v_purchase_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_input_acct uuid;
  v_tax_credit numeric;
  v_inv_credit numeric;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-17', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_tenant_a, 'M75-TAX-PR-NR-' || left(gen_random_uuid()::text, 8),
    'زيت غير مسترد', 'Non-Rec Purchase', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, 'taxable', v_owner
  )
  returning id into v_product;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M75-NR-17', 'name_ar', 'ضريبة', 'name_en', 'Non-Rec 17',
      'rate', 5, 'effective_from', current_date - 30, 'is_recoverable', false
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object('tax_enabled', true, 'default_tax_rate_id', v_rate_id)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  v_return_id := public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Non-recoverable tax return case 17',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 10, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select input_account_id into v_input_acct from public.tax_rates where id = v_rate_id;

  select coalesce(sum(credit), 0) into v_tax_credit
  from public.journal_lines jl
  join public.invoices i on i.journal_entry_id = jl.journal_entry_id
  where i.id = v_return_id and jl.account_id = v_input_acct;

  select coalesce(sum(credit), 0) into v_inv_credit
  from public.journal_lines jl
  join public.invoices i on i.journal_entry_id = jl.journal_entry_id
  join public.chart_of_accounts c on c.id = jl.account_id
  where i.id = v_return_id and c.code = '1301';

  if v_tax_credit <> 0 or v_inv_credit <> 105 then
    raise exception 'case17 failed: tax_credit=% inv_credit=%', v_tax_credit, v_inv_credit;
  end if;
end $$;
rollback;


-- ===========================================================================
-- Block E: Serialized (cases 18-21)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 18. Serialized sales return restores unit status and warehouse
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
  v_customer uuid;
  v_purchase_id uuid;
  v_sale_id uuid;
  v_unit_id uuid;
  v_line_id uuid;
  v_unit_status text;
  v_unit_wh uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  update public.products set can_be_sold = true where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-18', 'phone_primary', '+96550008018', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-18', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
          'units', jsonb_build_array(jsonb_build_object('serial_number', 'M75-SER-18'))
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where tenant_id = v_tenant_a and purchase_invoice_id = v_purchase_id and serial_number = 'M75-SER-18';

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 60.000, 'discount_pct', 0, 'line_order', 1,
          'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  perform public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Serialized sales return case 18',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1, 'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  select status::text, current_warehouse_id
  into v_unit_status, v_unit_wh
  from public.product_units where id = v_unit_id;

  if v_unit_status is distinct from 'available_new' or v_unit_wh is distinct from v_warehouse then
    raise exception 'case18 failed: status=% warehouse=%', v_unit_status, v_unit_wh;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19. Serialized purchase return retires unit
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
  v_purchase_id uuid;
  v_unit_id uuid;
  v_line_id uuid;
  v_unit_status text;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-19', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
          'units', jsonb_build_array(jsonb_build_object('serial_number', 'M75-SER-19'))
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where tenant_id = v_tenant_a and purchase_invoice_id = v_purchase_id and serial_number = 'M75-SER-19';

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  set local role postgres;
  perform public.allow_finance_write();
  update public.invoice_lines
  set product_unit_id = v_unit_id
  where id = v_line_id;
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

  perform public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Serialized purchase return case 19',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1, 'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  select status::text into v_unit_status from public.product_units where id = v_unit_id;

  if v_unit_status is distinct from 'retired' then
    raise exception 'case19 failed: status %', v_unit_status;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20. Serialized sales return requires product_unit_id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
  v_customer uuid;
  v_purchase_id uuid;
  v_sale_id uuid;
  v_unit_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  update public.products set can_be_sold = true where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-20', 'phone_primary', '+96550008020', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-20', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
          'units', jsonb_build_array(jsonb_build_object('serial_number', 'M75-SER-20'))
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where purchase_invoice_id = v_purchase_id and serial_number = 'M75-SER-20';

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 60.000, 'discount_pct', 0, 'line_order', 1,
          'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Missing unit id',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case20 failed: serialized return without unit accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 21. Serialized sales return rejects wrong product_unit_id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
  v_customer uuid;
  v_purchase_id uuid;
  v_sale_id uuid;
  v_unit_sold uuid;
  v_unit_other uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  update public.products set can_be_sold = true where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-21', 'phone_primary', '+96550008021', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-21', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 2, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M75-SER-21A'),
            jsonb_build_object('serial_number', 'M75-SER-21B')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_sold
  from public.product_units where purchase_invoice_id = v_purchase_id and serial_number = 'M75-SER-21A';

  select id into v_unit_other
  from public.product_units where purchase_invoice_id = v_purchase_id and serial_number = 'M75-SER-21B';

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 60.000, 'discount_pct', 0, 'line_order', 1,
          'product_unit_id', v_unit_sold
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Wrong unit id',
        'lines', jsonb_build_array(
          jsonb_build_object(
            'original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1, 'product_unit_id', v_unit_other
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case21 failed: wrong unit accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;


-- ===========================================================================
-- Block F: Credits and refunds (cases 22-27)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 22. apply_return_credit_to_invoice reduces future sales invoice outstanding
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_key uuid := '00000000-0000-0000-0000-00000000e003';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_paid uuid;
  v_sale_open uuid;
  v_line_paid uuid;
  v_return_id uuid;
  v_outstanding numeric;
  v_credit_remaining numeric;
  v_future_alloc int;
  v_detail jsonb;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-22', 'phone_primary', '+96550008022', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-22', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-CR-22-' || left(gen_random_uuid()::text, 8),
    'زيت M75-22', 'M75 Oil 22', v_oils_group, 'consumable_rental', 'ml',
    50.000, 0, false, true, v_owner
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

  v_sale_paid := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 50.000, 'discount_pct', 0, 'line_order', 1)
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
        jsonb_build_object('invoice_id', v_sale_paid, 'allocated_amount', 50)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_paid from public.invoice_lines where invoice_id = v_sale_paid and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_paid,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Credit for future invoice case 22',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_paid, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_open := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 40.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.apply_return_credit_to_invoice(v_return_id, v_sale_open, 50, gen_random_uuid());
    raise exception 'case22 failed: over-apply accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  perform public.apply_return_credit_to_invoice(v_return_id, v_sale_open, 40, v_key);

  v_detail := public.get_return_invoice_detail(v_return_id);
  v_credit_remaining := (v_detail ->> 'credit_remaining')::numeric;

  select count(*) into v_future_alloc
  from jsonb_array_elements(v_detail -> 'credit_allocations') elem
  where elem ->> 'allocation_kind' = 'future_invoice'
    and (elem ->> 'target_invoice_id')::uuid = v_sale_open
    and (elem ->> 'allocated_amount')::numeric = 40
    and coalesce((elem ->> 'is_reversed')::boolean, false) = false;

  if v_future_alloc <> 1 or v_credit_remaining <> 10 then
    raise exception 'case22 failed: future_alloc=% credit_remaining=%', v_future_alloc, v_credit_remaining;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 23. apply_return_credit_to_invoice on purchase return credit
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_key uuid := '00000000-0000-0000-0000-00000000e004';
  v_supplier uuid;
  v_product uuid;
  v_purchase_paid uuid;
  v_purchase_open uuid;
  v_line_paid uuid;
  v_return_id uuid;
  v_future_alloc int;
  v_detail jsonb;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-23', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-CR-23-' || left(gen_random_uuid()::text, 8),
    'زيت M75-23', 'M75 Oil 23', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_paid := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 8.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_payment_voucher(
    jsonb_build_object(
      'payment_destination', 'supplier', 'supplier_id', v_supplier,
      'date', current_date, 'amount', 80,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_purchase_paid, 'allocated_amount', 80)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_paid from public.invoice_lines where invoice_id = v_purchase_paid and line_order = 1;

  v_return_id := public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_paid,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Supplier credit apply case 23',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_paid, 'qty', 10, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_purchase_open := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 8.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.apply_return_credit_to_invoice(v_return_id, v_purchase_open, 40, v_key);

  v_detail := public.get_return_invoice_detail(v_return_id);

  select count(*) into v_future_alloc
  from jsonb_array_elements(v_detail -> 'credit_allocations') elem
  where elem ->> 'allocation_kind' = 'future_invoice'
    and (elem ->> 'target_invoice_id')::uuid = v_purchase_open
    and (elem ->> 'allocated_amount')::numeric = 40
    and coalesce((elem ->> 'is_reversed')::boolean, false) = false;

  if v_future_alloc <> 1 then
    raise exception 'case23 failed: future_alloc % detail=%', v_future_alloc, v_detail;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 24. Customer refund vouchers support partial and multi-return allocations
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_sale_id_2 uuid;
  v_line_id uuid;
  v_line_id_2 uuid;
  v_return_id uuid;
  v_return_id_2 uuid;
  v_voucher_id uuid;
  v_voucher_id_2 uuid;
  v_detail jsonb;
  v_detail_2 jsonb;
  v_credit_remaining numeric;
  v_credit_remaining_2 numeric;
  v_cash_refund_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-24', 'phone_primary', '+96550008024', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-24', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-CR-24-' || left(gen_random_uuid()::text, 8),
    'زيت M75-24', 'M75 Oil 24', v_oils_group, 'consumable_rental', 'ml',
    30.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 30.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 30,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 30)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id_2 := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 30.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 30,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id_2, 'allocated_amount', 30)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;
  select id into v_line_id_2 from public.invoice_lines where invoice_id = v_sale_id_2 and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Customer refund case 24',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_return_id_2 := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id_2,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Customer refund second return case 24',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id_2, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_customer_refund_voucher(
    null,
    jsonb_build_object(
      'date', current_date, 'amount', 30,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocations', jsonb_build_array(
        jsonb_build_object('return_invoice_id', v_return_id, 'allocated_amount', 20),
        jsonb_build_object('return_invoice_id', v_return_id_2, 'allocated_amount', 10)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id_2 := public.record_customer_refund_voucher(
    v_return_id,
    jsonb_build_object(
      'date', current_date, 'amount', 10,
      'payment_method', 'bank_transfer', 'cash_account_id', v_cash
    ),
    gen_random_uuid()
  );

  v_detail := public.get_return_invoice_detail(v_return_id);
  v_detail_2 := public.get_return_invoice_detail(v_return_id_2);
  v_credit_remaining := (v_detail ->> 'credit_remaining')::numeric;
  v_credit_remaining_2 := (v_detail_2 ->> 'credit_remaining')::numeric;

  select count(*) into v_cash_refund_count
  from jsonb_array_elements(v_detail -> 'credit_allocations') elem
  where elem ->> 'allocation_kind' = 'cash_refund'
    and coalesce((elem ->> 'is_reversed')::boolean, false) = false
    and (elem ->> 'voucher_id')::uuid in (v_voucher_id, v_voucher_id_2);

  if v_credit_remaining <> 0
    or v_credit_remaining_2 <> 20
    or v_cash_refund_count <> 2
    or v_voucher_id is null
    or v_voucher_id_2 is null then
    raise exception 'case24 failed: remaining1=% remaining2=% refund_count=% vouchers=%,%',
      v_credit_remaining, v_credit_remaining_2, v_cash_refund_count, v_voucher_id, v_voucher_id_2;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 25. record_supplier_refund_receipt clears purchase return credit
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_voucher_id uuid;
  v_detail jsonb;
  v_credit_remaining numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-25', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-CR-25-' || left(gen_random_uuid()::text, 8),
    'زيت M75-25', 'M75 Oil 25', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 7.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_payment_voucher(
    jsonb_build_object(
      'payment_destination', 'supplier', 'supplier_id', v_supplier,
      'date', current_date, 'amount', 70,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_purchase_id, 'allocated_amount', 70)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;

  v_return_id := public.record_purchase_return(
    jsonb_build_object(
      'original_invoice_id', v_purchase_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Supplier refund case 25',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 10, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_voucher_id := public.record_supplier_refund_receipt(
    v_return_id,
    jsonb_build_object(
      'date', current_date, 'amount', 70,
      'payment_method', 'cash', 'cash_account_id', v_cash
    ),
    gen_random_uuid()
  );

  v_detail := public.get_return_invoice_detail(v_return_id);
  v_credit_remaining := (v_detail ->> 'credit_remaining')::numeric;

  if v_credit_remaining <> 0 or v_voucher_id is null then
    raise exception 'case25 failed: credit_remaining=% voucher=%', v_credit_remaining, v_voucher_id;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 26. Standard payment voucher rejects customer_id key
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
    jsonb_build_object('name_ar', 'عميل M75-26', 'phone_primary', '+96550008026', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-26', 'create_account', true)
  );

  begin
    perform public.record_payment_voucher(
      jsonb_build_object(
        'payment_destination', 'supplier', 'supplier_id', v_supplier,
        'customer_id', v_customer,
        'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'fifo'
      ),
      gen_random_uuid()
    );
    raise exception 'case26 failed: payment with customer_id accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 27. Standard receipt voucher rejects supplier_id key
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
    jsonb_build_object('name_ar', 'عميل M75-27', 'phone_primary', '+96550008027', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-27', 'create_account', true)
  );

  begin
    perform public.record_receipt_voucher(
      jsonb_build_object(
        'customer_id', v_customer,
        'supplier_id', v_supplier,
        'date', current_date, 'amount', 10,
        'payment_method', 'cash', 'cash_account_id', v_cash,
        'allocation_mode', 'unallocated'
      ),
      gen_random_uuid()
    );
    raise exception 'case27 failed: receipt with supplier_id accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;


-- ===========================================================================
-- Block G: Cancellation (cases 28-30)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 28. Safe cancel_return_invoice reverses stock and marks cancelled
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_stock_before numeric;
  v_stock_after numeric;
  v_status text;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-28', 'phone_primary', '+96550008028', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-28', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M75-CAN-28-' || left(gen_random_uuid()::text, 8),
    'زيت M75-28', 'M75 Oil 28', v_oils_group, 'consumable_rental', 'ml',
    10.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 20, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  select qty_available into v_stock_before
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Cancel test case 28',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 5, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.cancel_return_invoice(v_return_id, 'Mistake', gen_random_uuid());

  select status::text into v_status from public.invoices where id = v_return_id;

  select qty_available into v_stock_after
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  if v_status is distinct from 'cancelled' or v_stock_after <> v_stock_before then
    raise exception 'case28 failed: status=% stock_before=% stock_after=%',
      v_status, v_stock_before, v_stock_after;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 29. Cancel blocked when future_invoice credit allocation exists
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_paid uuid;
  v_sale_open uuid;
  v_line_paid uuid;
  v_return_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-29', 'phone_primary', '+96550008029', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-29', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-CAN-29-' || left(gen_random_uuid()::text, 8),
    'زيت M75-29', 'M75 Oil 29', v_oils_group, 'consumable_rental', 'ml',
    20.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_paid := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 20.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 20,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_paid, 'allocated_amount', 20)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_paid from public.invoice_lines where invoice_id = v_sale_paid and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_paid,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Cancel blocked case 29',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_paid, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_open := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 15.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.apply_return_credit_to_invoice(v_return_id, v_sale_open, 15, gen_random_uuid());

  begin
    perform public.cancel_return_invoice(v_return_id, 'Should fail', gen_random_uuid());
    raise exception 'case29 failed: cancel allowed with future allocation';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 30. Cancel blocked when cash_refund allocation exists
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-30', 'phone_primary', '+96550008030', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-30', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-CAN-30-' || left(gen_random_uuid()::text, 8),
    'زيت M75-30', 'M75 Oil 30', v_oils_group, 'consumable_rental', 'ml',
    25.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 25.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 25,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 25)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Refund then cancel block case 30',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_customer_refund_voucher(
    v_return_id,
    jsonb_build_object(
      'date', current_date, 'amount', 25,
      'payment_method', 'cash', 'cash_account_id', v_cash
    ),
    gen_random_uuid()
  );

  begin
    perform public.cancel_return_invoice(v_return_id, 'Should fail', gen_random_uuid());
    raise exception 'case30 failed: cancel allowed with cash refund';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ===========================================================================
-- Block H: Security (cases 31-34)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 31. Permission denied: zero user cannot create sales return
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-31', 'phone_primary', '+96550008031', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-31', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-SEC-31-' || left(gen_random_uuid()::text, 8),
    'زيت M75-31', 'M75 Oil 31', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;
  perform set_config('test.m75.case31.sale_id', v_sale_id::text, true);
  perform set_config('test.m75.case31.line_id', v_line_id::text, true);
  perform set_config('test.m75.case31.warehouse', v_warehouse::text, true);
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
  v_sale_id uuid := current_setting('test.m75.case31.sale_id')::uuid;
  v_line_id uuid := current_setting('test.m75.case31.line_id')::uuid;
  v_warehouse uuid := current_setting('test.m75.case31.warehouse')::uuid;
begin
  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Denied',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case31 failed: zero user sales return succeeded';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 32. Permission denied: zero user cannot create purchase return
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
  v_purchase_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-32', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-SEC-32-' || left(gen_random_uuid()::text, 8),
    'زيت M75-32', 'M75 Oil 32', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_purchase_id and line_order = 1;
  perform set_config('test.m75.case32.purchase_id', v_purchase_id::text, true);
  perform set_config('test.m75.case32.line_id', v_line_id::text, true);
  perform set_config('test.m75.case32.warehouse', v_warehouse::text, true);
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
  v_purchase_id uuid := current_setting('test.m75.case32.purchase_id')::uuid;
  v_line_id uuid := current_setting('test.m75.case32.line_id')::uuid;
  v_warehouse uuid := current_setting('test.m75.case32.warehouse')::uuid;
begin
  begin
    perform public.record_purchase_return(
      jsonb_build_object(
        'original_invoice_id', v_purchase_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Denied',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case32 failed: zero user purchase return succeeded';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 33. Permission denied: zero user cannot list or view returns
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-33', 'phone_primary', '+96550008033', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-33', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-SEC-33-' || left(gen_random_uuid()::text, 8),
    'زيت M75-33', 'M75 Oil 33', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'View denied case 33',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m75.case33.return_id', v_return_id::text, true);
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
  v_return_id uuid := current_setting('test.m75.case33.return_id')::uuid;
begin
  begin
    perform count(*) from public.list_return_invoices();
    raise exception 'case33 failed: list_return_invoices allowed';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;

  begin
    perform public.get_return_invoice_detail(v_return_id);
    raise exception 'case33 failed: get_return_invoice_detail allowed';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 34. Cross-tenant return detail rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-34', 'phone_primary', '+96550008034', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-34', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-SEC-34-' || left(gen_random_uuid()::text, 8),
    'زيت M75-34', 'M75 Oil 34', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Tenant isolation case 34',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m75.case34.return_id', v_return_id::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_return_id uuid := current_setting('test.m75.case34.return_id')::uuid;
begin
  begin
    perform public.get_return_invoice_detail(v_return_id);
    raise exception 'case34 failed: tenant B read tenant A return';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' and sqlerrm not like '%tenant_not_found%' then raise; end if;
  end;
end $$;
rollback;


-- ===========================================================================
-- Block I: Idempotency (cases 35-36)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 35. Idempotency: same key + same payload returns same return id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_key uuid := '00000000-0000-0000-0000-00000000e001';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_payload jsonb;
  v_id1 uuid;
  v_id2 uuid;
  v_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-35', 'phone_primary', '+96550008035', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-35', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-ID-35-' || left(gen_random_uuid()::text, 8),
    'زيت M75-35', 'M75 Oil 35', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_payload := jsonb_build_object(
    'original_invoice_id', v_sale_id,
    'warehouse_id', v_warehouse,
    'date', current_date,
    'reason', 'Idempotent return case 35',
    'lines', jsonb_build_array(
      jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
    )
  );

  v_id1 := public.record_sales_return(v_payload, v_key);
  v_id2 := public.record_sales_return(v_payload, v_key);

  if v_id1 is distinct from v_id2 then
    raise exception 'case35 failed: ids differ % vs %', v_id1, v_id2;
  end if;

  select count(*) into v_count
  from public.invoices where idempotency_key = v_key;

  if v_count <> 1 then
    raise exception 'case35 failed: invoice count %', v_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 36. Idempotency payload mismatch rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_key uuid := '00000000-0000-0000-0000-00000000e002';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-36', 'phone_primary', '+96550008036', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-36', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-ID-36-' || left(gen_random_uuid()::text, 8),
    'زيت M75-36', 'M75 Oil 36', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  perform public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'First payload case 36',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    v_key
  );

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Different payload case 36',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
        )
      ),
      v_key
    );
    raise exception 'case36 failed: idempotency mismatch not raised';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then raise; end if;
  end;
end $$;
rollback;

-- ===========================================================================
-- Block J: Rollback (case 37)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 37. Forced late failure on journal_lines -> zero residual return data
-- ---------------------------------------------------------------------------
begin;
create or replace function public.test_m75_journal_lines_fail_trigger()
returns trigger
language plpgsql
as $$
begin
  if current_setting('test.m75.journal_fail_marker', true) = '__M75_ROLLBACK_MARKER__' then
    raise exception 'test_m75_late_failure';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_test_m75_journal_fail on public.journal_lines;
create trigger trg_test_m75_journal_fail
  before insert on public.journal_lines
  for each row
  execute function public.test_m75_journal_lines_fail_trigger();

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_before_inv int;
  v_after_inv int;
  v_before_move int;
  v_after_move int;
  v_before_je int;
  v_after_je int;
  v_before_stock numeric;
  v_after_stock numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-37', 'phone_primary', '+96550008037', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-37', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M75-ROLL-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 20, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  select count(*) into v_before_inv
  from public.invoices where tenant_id = v_tenant_a and type = 'sales_return';

  select count(*) into v_before_move
  from public.inventory_movements where tenant_id = v_tenant_a and movement_type = 'sale_return';

  select count(*) into v_before_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'sales_return';

  select coalesce(qty_available, 0) into v_before_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  perform set_config('test.m75.journal_fail_marker', '__M75_ROLLBACK_MARKER__', true);

  begin
    perform public.record_sales_return(
      jsonb_build_object(
        'original_invoice_id', v_sale_id,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'reason', 'Rollback case 37',
        'lines', jsonb_build_array(
          jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 3, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case37 failed: late failure not raised';
  exception
    when others then
      if sqlerrm not like '%test_m75_late_failure%' then raise; end if;
  end;

  select count(*) into v_after_inv
  from public.invoices where tenant_id = v_tenant_a and type = 'sales_return';

  select count(*) into v_after_move
  from public.inventory_movements where tenant_id = v_tenant_a and movement_type = 'sale_return';

  select count(*) into v_after_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'sales_return';

  select coalesce(qty_available, 0) into v_after_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  if v_after_inv <> v_before_inv
    or v_after_move <> v_before_move
    or v_after_je <> v_before_je
    or v_after_stock <> v_before_stock then
    raise exception 'case37 failed: residual inv %->% move %->% je %->% stock %->%',
      v_before_inv, v_after_inv, v_before_move, v_after_move,
      v_before_je, v_after_je, v_before_stock, v_after_stock;
  end if;
end $$;
rollback;

-- ===========================================================================
-- Block K: Read RPCs (cases 38-39)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 38. list_return_invoices and list_returnable_invoice_lines smoke
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_list_count int;
  v_returnable_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-38', 'phone_primary', '+96550008038', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-38', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-RD-38-' || left(gen_random_uuid()::text, 8),
    'زيت M75-38', 'M75 Oil 38', v_oils_group, 'consumable_rental', 'ml',
    8.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 4, 'unit_price', 8.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Read RPC case 38',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_list_count
  from public.list_return_invoices(v_customer, 'sales_return', 'confirmed', null, null, 'M75-38', 50, 0);

  select count(*) into v_returnable_count
  from public.list_returnable_invoice_lines(v_sale_id);

  if v_list_count < 1 or v_returnable_count < 1 then
    raise exception 'case38 failed: list=% returnable_lines=%', v_list_count, v_returnable_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 39. get_return_invoice_detail and list_available_party_credits smoke
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_line_id uuid;
  v_return_id uuid;
  v_detail jsonb;
  v_credit_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object('name_ar', 'عميل M75-39', 'phone_primary', '+96550008039', 'create_account', true)
  );
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M75-39', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'M75-RD-39-' || left(gen_random_uuid()::text, 8),
    'زيت M75-39', 'M75 Oil 39', v_oils_group, 'consumable_rental', 'ml',
    15.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 15.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_receipt_voucher(
    jsonb_build_object(
      'customer_id', v_customer, 'date', current_date, 'amount', 15,
      'payment_method', 'cash', 'cash_account_id', v_cash,
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object('invoice_id', v_sale_id, 'allocated_amount', 15)
      )
    ),
    gen_random_uuid()
  );

  select id into v_line_id from public.invoice_lines where invoice_id = v_sale_id and line_order = 1;

  v_return_id := public.record_sales_return(
    jsonb_build_object(
      'original_invoice_id', v_sale_id,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'reason', 'Detail RPC case 39',
      'lines', jsonb_build_array(
        jsonb_build_object('original_invoice_line_id', v_line_id, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_detail := public.get_return_invoice_detail(v_return_id);

  select count(*) into v_credit_count
  from public.list_available_party_credits(v_customer, 'sales');

  if (v_detail ->> 'id')::uuid is distinct from v_return_id
    or coalesce((v_detail ->> 'credit_remaining')::numeric, 0) <> 15
    or v_credit_count < 1 then
    raise exception 'case39 failed: detail=% credit_count=%', v_detail, v_credit_count;
  end if;
end $$;
rollback;
