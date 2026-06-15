-- Phase 5 M5: purchase invoice engine verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase D.
-- Manual: docker exec -i supabase_db_hs360 psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/phase_5_purchase_invoices.sql

\set ON_ERROR_STOP on

-- Seed constants:
--   tenant_a=101, owner=201, zero_user=202, products_user=203
--   product_a=901 (serialized), oils_group=802, main_warehouse=701
--   owner_tu=301, zero_tu=302, products_tu=303

-- ---------------------------------------------------------------------------
-- 1. Non-serialized purchase: stock + movement + balanced journal
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
  v_invoice_id uuid;
  v_je_id uuid;
  v_stock numeric;
  v_movement_count int;
  v_debit numeric;
  v_credit numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-1', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-OIL-1-' || left(gen_random_uuid()::text, 8),
    'زيت M5-1', 'M5 Oil 1', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 100,
          'unit_price', 2.500,
          'discount_pct', 0,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select qty_available into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  if v_stock <> 100 then
    raise exception 'case1 failed: stock % expected 100', v_stock;
  end if;

  select count(*) into v_movement_count
  from public.inventory_movements
  where tenant_id = v_tenant_a
    and reference_table = 'purchase_invoice'
    and reference_id = v_invoice_id;

  if v_movement_count <> 1 then
    raise exception 'case1 failed: movement count %', v_movement_count;
  end if;

  select journal_entry_id into v_je_id
  from public.invoices
  where id = v_invoice_id;

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.journal_lines
  where journal_entry_id = v_je_id;

  if v_debit <> v_credit or v_debit <> 250 then
    raise exception 'case1 failed: journal debit=% credit=%', v_debit, v_credit;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. Serialized purchase (qty=2, 2 units): exactly 2 units, 1 stock delta
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
  v_invoice_id uuid;
  v_unit_count int;
  v_stock numeric;
  v_movement_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-2', 'create_account', true)
  );

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 2,
          'unit_price', 45.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M5-SER-2A'),
            jsonb_build_object('serial_number', 'M5-SER-2B')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_unit_count
  from public.product_units
  where tenant_id = v_tenant_a
    and purchase_invoice_id = v_invoice_id;

  if v_unit_count <> 2 then
    raise exception 'case2 failed: unit count %', v_unit_count;
  end if;

  select qty_available into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  if v_stock is null then
    raise exception 'case2 failed: no stock row';
  end if;

  select count(*) into v_movement_count
  from public.inventory_movements
  where tenant_id = v_tenant_a
    and reference_id = v_invoice_id
    and product_id = v_product;

  if v_movement_count <> 1 then
    raise exception 'case2 failed: movement count %', v_movement_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3. First-purchase WAC = acquisition unit cost
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
  v_avg numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-3', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-WAC-1-' || left(gen_random_uuid()::text, 8),
    'زيت WAC', 'WAC Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 50,
          'unit_price', 3.200,
          'discount_pct', 0,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select avg_cost into v_avg
  from public.products
  where id = v_product;

  if v_avg <> 3.200 then
    raise exception 'case3 failed: avg_cost % expected 3.200', v_avg;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4. Subsequent WAC weighted average
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
  v_avg numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-4', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-WAC-2-' || left(gen_random_uuid()::text, 8),
    'زيت WAC2', 'WAC Oil 2', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 1.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 3.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select avg_cost into v_avg from public.products where id = v_product;

  if v_avg <> 2.000 then
    raise exception 'case4 failed: avg_cost % expected 2.000', v_avg;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 5. Repeated non-serialized lines aggregated; order-swapped payloads same WAC
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
  v_product_a uuid;
  v_product_b uuid;
  v_avg_a numeric;
  v_avg_b numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-5', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-AGG-A-' || left(gen_random_uuid()::text, 8),
    'زيت تجميع أ', 'Agg A', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product_a;

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-AGG-B-' || left(gen_random_uuid()::text, 8),
    'زيت تجميع ب', 'Agg B', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product_b;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product_a, 'qty', 5, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1),
        jsonb_build_object('product_id', v_product_a, 'qty', 3, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 2)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product_b, 'qty', 3, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1),
        jsonb_build_object('product_id', v_product_b, 'qty', 5, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 2)
      )
    ),
    gen_random_uuid()
  );

  select avg_cost into v_avg_a from public.products where id = v_product_a;
  select avg_cost into v_avg_b from public.products where id = v_product_b;

  if v_avg_a <> 2.000 or v_avg_b <> 2.000 then
    raise exception 'case5 failed: avg_a=% avg_b=%', v_avg_a, v_avg_b;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6. Recoverable tax: Dr Inventory (net) + Dr Input Tax + Cr A/P
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
  v_rate_id uuid;
  v_invoice_id uuid;
  v_je_id uuid;
  v_inv_debit numeric;
  v_tax_debit numeric;
  v_ap_credit numeric;
  v_input_acct uuid;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-6', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_tenant_a, 'M5-TAX-R-' || left(gen_random_uuid()::text, 8),
    'زيت ضريبة', 'Tax Oil R', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, 'taxable', v_owner
  )
  returning id into v_product;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M5-REC', 'name_ar', 'ضريبة', 'name_en', 'Recoverable',
      'rate', 5, 'effective_from', current_date - 30, 'is_recoverable', true
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object('tax_enabled', true, 'default_tax_rate_id', v_rate_id)
  );

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 10.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id from public.invoices where id = v_invoice_id;

  select id into v_input_acct
  from public.chart_of_accounts
  where tenant_id = v_tenant_a and code = '1151';

  select coalesce(sum(debit), 0) into v_inv_debit
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.code = '1301';

  select coalesce(sum(debit), 0) into v_tax_debit
  from public.journal_lines
  where journal_entry_id = v_je_id and account_id = v_input_acct;

  select coalesce(sum(credit), 0) into v_ap_credit
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.type = 'liability';

  if v_inv_debit <> 100 or v_tax_debit <> 5 or v_ap_credit <> 105 then
    raise exception 'case6 failed: inv=% tax=% ap=%', v_inv_debit, v_tax_debit, v_ap_credit;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7. Non-recoverable tax capitalized into inventory + WAC
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
  v_rate_id uuid;
  v_invoice_id uuid;
  v_je_id uuid;
  v_inv_debit numeric;
  v_tax_debit numeric;
  v_ap_credit numeric;
  v_avg numeric;
  v_input_acct uuid;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-7', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_tenant_a, 'M5-TAX-NR-' || left(gen_random_uuid()::text, 8),
    'زيت غير مسترد', 'Non-Rec Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, 'taxable', v_owner
  )
  returning id into v_product;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M5-NREC', 'name_ar', 'ضريبة', 'name_en', 'Non-Recoverable',
      'rate', 5, 'effective_from', current_date - 30, 'is_recoverable', false
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object('tax_enabled', true, 'default_tax_rate_id', v_rate_id)
  );

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 10.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id from public.invoices where id = v_invoice_id;

  select id into v_input_acct
  from public.chart_of_accounts where tenant_id = v_tenant_a and code = '1151';

  select coalesce(sum(debit), 0) into v_inv_debit
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.code = '1301';

  select coalesce(sum(debit), 0) into v_tax_debit
  from public.journal_lines
  where journal_entry_id = v_je_id and account_id = v_input_acct;

  select coalesce(sum(credit), 0) into v_ap_credit
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.type = 'liability';

  select avg_cost into v_avg from public.products where id = v_product;

  if v_inv_debit <> 105 or v_tax_debit <> 0 or v_ap_credit <> 105 then
    raise exception 'case7 failed: inv=% tax=% ap=%', v_inv_debit, v_tax_debit, v_ap_credit;
  end if;

  if v_avg <> 10.500 then
    raise exception 'case7 failed: avg_cost % expected 10.500', v_avg;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8. Line discount before tax
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
  v_invoice_id uuid;
  v_before_tax numeric;
  v_total numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-8', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-DISC-' || left(gen_random_uuid()::text, 8),
    'زيت خصم', 'Disc Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 10.000,
          'discount_pct', 10, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select before_tax_amount, total
  into v_before_tax, v_total
  from public.invoice_lines il
  join public.invoices i on i.id = il.invoice_id
  where il.invoice_id = v_invoice_id;

  if v_before_tax <> 90 or v_total <> 90 then
    raise exception 'case8 failed: before_tax=% total=%', v_before_tax, v_total;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9. Tax-disabled tenant: zero tax, correct totals
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
  v_rate_id uuid;
  v_invoice_id uuid;
  v_tax numeric;
  v_total numeric;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-9', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_tenant_a, 'M5-TAX-OFF-' || left(gen_random_uuid()::text, 8),
    'زيت بدون ضريبة', 'No Tax Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, 'taxable', v_owner
  )
  returning id into v_product;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M5-OFF', 'name_ar', 'ضريبة', 'name_en', 'Off Rate',
      'rate', 5, 'effective_from', current_date
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object('tax_enabled', false, 'default_tax_rate_id', v_rate_id)
  );

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 5, 'unit_price', 20.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select tax_amount, total into v_tax, v_total
  from public.invoices where id = v_invoice_id;

  if v_tax <> 0 or v_total <> 100 then
    raise exception 'case9 failed: tax=% total=%', v_tax, v_total;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10. last_purchase_cost = incoming_total / incoming_qty (order-independent)
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
  v_last_cost numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-10', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-LPC-' || left(gen_random_uuid()::text, 8),
    'زيت LPC', 'LPC Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
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

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 4.000, 'discount_pct', 0, 'line_order', 1),
        jsonb_build_object('product_id', v_product, 'qty', 3, 'unit_price', 4.000, 'discount_pct', 0, 'line_order', 2)
      )
    ),
    gen_random_uuid()
  );

  select last_purchase_cost into v_last_cost from public.products where id = v_product;

  if v_last_cost <> 4.000 then
    raise exception 'case10 failed: last_purchase_cost % expected 4.000', v_last_cost;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11. Idempotent retry: same key+payload returns same id, no duplicate rows
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
  v_key uuid := gen_random_uuid();
  v_payload jsonb;
  v_id1 uuid;
  v_id2 uuid;
  v_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-11', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-IDEM-' || left(gen_random_uuid()::text, 8),
    'زيت تكرار', 'Idem Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_payload := jsonb_build_object(
    'supplier_id', v_supplier,
    'warehouse_id', v_warehouse,
    'date', current_date,
    'lines', jsonb_build_array(
      jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
    )
  );

  v_id1 := public.record_purchase_invoice(v_payload, v_key);
  v_id2 := public.record_purchase_invoice(v_payload, v_key);

  if v_id1 is distinct from v_id2 then
    raise exception 'case11 failed: ids differ % vs %', v_id1, v_id2;
  end if;

  select count(*) into v_count
  from public.invoices
  where tenant_id = v_tenant_a and idempotency_key = v_key;

  if v_count <> 1 then
    raise exception 'case11 failed: invoice count %', v_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12. Same key, different payload -> idempotency_payload_mismatch
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
  v_key uuid := gen_random_uuid();
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-12', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-MIS-' || left(gen_random_uuid()::text, 8),
    'زيت عدم تطابق', 'Mismatch Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    v_key
  );

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 6, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      v_key
    );
    raise exception 'case12 failed: mismatch not raised';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13. Same key, same payload except different invoice_id -> mismatch
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
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_supplier uuid;
  v_product uuid;
  v_draft_a uuid;
  v_draft_b uuid;
  v_key uuid := gen_random_uuid();
  v_base jsonb;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in ('invoices.edit_draft', 'invoices.create_purchase');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'invoices.edit_draft', v_owner),
    (v_tenant_a, v_products_tu, 'invoices.create_purchase', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-13', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-DRAFT-ID-' || left(gen_random_uuid()::text, 8),
    'زيت مسودة', 'Draft Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_base := jsonb_build_object(
    'type', 'purchase',
    'supplier_id', v_supplier,
    'warehouse_id', v_warehouse,
    'date', current_date,
    'lines', jsonb_build_array(
      jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
    )
  );

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000203', true);
  v_draft_a := public.save_invoice_draft(v_base);
  v_draft_b := public.save_invoice_draft(v_base);

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  perform public.record_purchase_invoice(
    (v_base - 'type') || jsonb_build_object('invoice_id', v_draft_a),
    v_key
  );

  begin
    perform public.record_purchase_invoice(
      (v_base - 'type') || jsonb_build_object('invoice_id', v_draft_b),
      v_key
    );
    raise exception 'case13 failed: draft invoice_id mismatch not raised';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14. Duplicate serial -> full rollback
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
  v_serial text := 'M5-DUP-SERIAL-14';
  v_before_units int;
  v_after_units int;
  v_before_invoices int;
  v_after_invoices int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-14', 'create_account', true)
  );

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
          'units', jsonb_build_array(jsonb_build_object('serial_number', v_serial))
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_before_units
  from public.product_units where lower(serial_number) = lower(v_serial);

  select count(*) into v_before_invoices
  from public.invoices where type = 'purchase' and status = 'confirmed';

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
            'units', jsonb_build_array(jsonb_build_object('serial_number', v_serial))
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case14 failed: duplicate serial accepted';
  exception
    when others then
      if sqlerrm not like '%duplicate_serial%' then
        raise;
      end if;
  end;

  select count(*) into v_after_units
  from public.product_units where lower(serial_number) = lower(v_serial);

  select count(*) into v_after_invoices
  from public.invoices where type = 'purchase' and status = 'confirmed';

  if v_after_units <> v_before_units or v_after_invoices <> v_before_invoices then
    raise exception 'case14 failed: partial data units %->% invoices %->%',
      v_before_units, v_after_units, v_before_invoices, v_after_invoices;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 15. Cross-tenant supplier/product/warehouse IDs rejected
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_wh_b uuid;
begin
  insert into public.warehouses (id, tenant_id, name_ar, name_en, is_active)
  values (gen_random_uuid(), v_tenant_b, 'مستودع ب', 'Tenant B WH', true)
  returning id into v_wh_b;

  perform set_config('test.m5.wh_b', v_wh_b::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse_a uuid := '00000000-0000-0000-0000-000000000701';
  v_product_b uuid := '00000000-0000-0000-0000-000000000902';
  v_supplier_a uuid;
  v_wh_b uuid := current_setting('test.m5.wh_b')::uuid;
  v_supplier_b uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier_a := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-15A', 'create_account', true)
  );

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000204', true);
  v_supplier_b := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد ب')
  );

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier_b, 'warehouse_id', v_warehouse_a, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product_b, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case15a failed: cross-tenant supplier accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%'
        and sqlerrm not like '%cross_tenant_reference%' then
        raise;
      end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier_a, 'warehouse_id', v_wh_b, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product_b, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case15b failed: cross-tenant warehouse accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier_a, 'warehouse_id', v_warehouse_a, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product_b, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case15c failed: cross-tenant product accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16. Inactive/missing supplier, warehouse, product rejected
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-16', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-INACT-' || left(gen_random_uuid()::text, 8),
    'زيت غير نشط', 'Inactive Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  perform set_config('test.m5.c16.supplier', v_supplier::text, true);
  perform set_config('test.m5.c16.product', v_product::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c16.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c16.product')::uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  perform set_config('test.m5.c16.phase', 'supplier', true);
end $$;
reset role;
do $$
declare
  v_supplier uuid := current_setting('test.m5.c16.supplier')::uuid;
begin
  if current_setting('test.m5.c16.phase', true) = 'supplier' then
    update public.suppliers set is_active = false where id = v_supplier;
  end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c16.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c16.product')::uuid;
begin
  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case16a failed: inactive supplier accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
reset role;
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c16.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c16.product')::uuid;
begin
  update public.suppliers set is_active = true where id = v_supplier;
  update public.warehouses set is_active = false where id = v_warehouse;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c16.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c16.product')::uuid;
begin
  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case16b failed: inactive warehouse accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
reset role;
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product uuid := current_setting('test.m5.c16.product')::uuid;
begin
  update public.warehouses set is_active = true where id = v_warehouse;
  update public.products set is_active = false where id = v_product;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c16.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c16.product')::uuid;
begin
  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case16c failed: inactive product accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;
-- ---------------------------------------------------------------------------
-- 17. Supplier without A/P account rejected
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
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد بدون حساب')
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-NOAP-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case17 failed: supplier without AP accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18. Fractional serialized qty rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-18', 'create_account', true)
  );

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1.5, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
            'units', jsonb_build_array(
              jsonb_build_object('serial_number', 'M5-FRAC-A'),
              jsonb_build_object('serial_number', 'M5-FRAC-B')
            )
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case18 failed: fractional serialized qty accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19. Unit count != qty rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-19', 'create_account', true)
  );

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 2, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
            'units', jsonb_build_array(jsonb_build_object('serial_number', 'M5-MISMATCH-19'))
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case19 failed: unit count mismatch accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20. Duplicate line_order or line_order < 1 rejected
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
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-20', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-LO-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 0)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case20a failed: line_order 0 accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1),
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case20b failed: duplicate line_order accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 21. Reordered units[] serials produce same idempotency hash (postgres role)
-- ---------------------------------------------------------------------------
begin;
set local role postgres;
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_supplier uuid := gen_random_uuid();
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_hash_a text;
  v_hash_b text;
  v_payload_a jsonb;
  v_payload_b jsonb;
begin
  v_payload_a := jsonb_build_object(
    'supplier_id', v_supplier,
    'warehouse_id', v_warehouse,
    'date', current_date,
    'lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product, 'qty', 2, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
        'units', jsonb_build_array(
          jsonb_build_object('serial_number', 'M5-HASH-A', 'barcode', 'BC-1'),
          jsonb_build_object('serial_number', 'M5-HASH-B')
        )
      )
    )
  );

  v_payload_b := jsonb_build_object(
    'supplier_id', v_supplier,
    'warehouse_id', v_warehouse,
    'date', current_date,
    'lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product, 'qty', 2, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
        'units', jsonb_build_array(
          jsonb_build_object('serial_number', 'M5-HASH-B'),
          jsonb_build_object('serial_number', 'M5-HASH-A', 'barcode', 'BC-1')
        )
      )
    )
  );

  v_hash_a := public.compute_purchase_invoice_payload_hash(v_payload_a);
  v_hash_b := public.compute_purchase_invoice_payload_hash(v_payload_b);

  if v_hash_a is distinct from v_hash_b then
    raise exception 'case21 failed: hashes differ % vs %', v_hash_a, v_hash_b;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 22. Duplicate serialized product_id on two lines rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-22', 'create_account', true)
  );

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
            'units', jsonb_build_array(jsonb_build_object('serial_number', 'M5-DUP-PROD-A'))
          ),
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 2,
            'units', jsonb_build_array(jsonb_build_object('serial_number', 'M5-DUP-PROD-B'))
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case22 failed: duplicate serialized product lines accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;
-- ---------------------------------------------------------------------------
-- 23. date <= books_locked_through rejected
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
  v_lock_date date := current_date;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  update public.tenant_settings
  set books_locked_through = v_lock_date
  where tenant_id = v_tenant_a;

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-23', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-LOCK-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', v_lock_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case23 failed: locked period purchase accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 24. Direct INSERT invoice/lines/movements/journal denied
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_supplier uuid;
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_invoice_id uuid := gen_random_uuid();
  v_je_id uuid := gen_random_uuid();
begin
  select id into v_supplier from public.suppliers where tenant_id = v_tenant_a limit 1;
  if v_supplier is null then
    v_supplier := public.create_supplier(
      jsonb_build_object('name_ar', 'مورد M5-24', 'create_account', true)
    );
  end if;

  begin
    insert into public.invoices (
      tenant_id, type, status, supplier_id, warehouse_id, date, subtotal, total
    )
    values (v_tenant_a, 'purchase', 'draft', v_supplier, v_warehouse, current_date, 0, 0);
    raise exception 'case24a failed: direct invoice insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%' then
        raise;
      end if;
  end;

  begin
    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id, qty, unit_price, line_total, line_order
    )
    values (v_tenant_a, v_invoice_id, v_product, 1, 1, 1, 1);
    raise exception 'case24b failed: direct invoice_line insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%' then
        raise;
      end if;
  end;

  begin
    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, qty, unit_cost, reference_table, reference_id
    )
    values (v_tenant_a, 'purchase', v_warehouse, v_product, 1, 1, 'purchase_invoice', v_invoice_id);
    raise exception 'case24c failed: direct movement insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%' then
        raise;
      end if;
  end;

  begin
    insert into public.journal_entries (
      id, tenant_id, entry_number, date, source, is_posted
    )
    values (v_je_id, v_tenant_a, 'JE-TEST-24', current_date, 'manual', false);
    raise exception 'case24d failed: direct journal insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 25. Permission denied without invoices.create_purchase
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_zero_tu uuid := '00000000-0000-0000-0000-000000000302';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  delete from public.user_permissions
  where tenant_user_id = v_zero_tu
    and permission_id = 'invoices.create_purchase';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_supplier uuid;
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
begin
  select id into v_supplier from public.suppliers limit 1;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case25 failed: zero_user purchase succeeded';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 26. list_purchase_invoices / get_purchase_invoice_detail bounded + permission gated
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in ('invoices.view_purchase', 'invoices.view', 'invoices.create_purchase');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'invoices.create_purchase', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  begin
    perform public.list_purchase_invoices();
    raise exception 'case26a failed: list without view permission succeeded';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'invoices.view_purchase', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
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
  v_invoice_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-26', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-LIST-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 5.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m5.c26.invoice', v_invoice_id::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_invoice_id uuid := current_setting('test.m5.c26.invoice')::uuid;
  v_list_count int;
  v_detail jsonb;
begin
  select count(*) into v_list_count
  from public.list_purchase_invoices(p_limit := 200);

  if v_list_count > 100 then
    raise exception 'case26b failed: limit not clamped, count=%', v_list_count;
  end if;

  v_detail := public.get_purchase_invoice_detail(v_invoice_id);

  if v_detail ->> 'id' is distinct from v_invoice_id::text then
    raise exception 'case26c failed: detail id mismatch';
  end if;

  if jsonb_array_length(v_detail -> 'lines') <> 1 then
    raise exception 'case26d failed: detail lines count';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 27. Draft save (type=purchase) -> confirm via invoice_id -> same row confirmed
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in ('invoices.edit_draft', 'invoices.create_purchase');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'invoices.edit_draft', v_owner),
    (v_tenant_a, v_products_tu, 'invoices.create_purchase', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
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
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-27', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-DRAFT-' || left(gen_random_uuid()::text, 8),
    'زيت مسودة', 'Draft Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  perform set_config('test.m5.c27.supplier', v_supplier::text, true);
  perform set_config('test.m5.c27.product', v_product::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c27.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c27.product')::uuid;
  v_draft_id uuid;
  v_confirmed_id uuid;
begin
  v_draft_id := public.save_invoice_draft(
    jsonb_build_object(
      'type', 'purchase',
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 4, 'unit_price', 2.500, 'discount_pct', 0, 'line_order', 1)
      )
    )
  );

  v_confirmed_id := public.record_purchase_invoice(
    jsonb_build_object(
      'invoice_id', v_draft_id,
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 4, 'unit_price', 2.500, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  if v_confirmed_id is null then
    raise exception 'case27 failed: record_purchase_invoice returned null';
  end if;

  if v_confirmed_id is distinct from v_draft_id then
    raise exception 'case27 failed: confirmed id % != draft %', v_confirmed_id, v_draft_id;
  end if;

  perform set_config('test.m5.c27.draft', v_draft_id::text, true);
  perform set_config('test.m5.c27.supplier', v_supplier::text, true);
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_draft_id uuid := current_setting('test.m5.c27.draft')::uuid;
  v_supplier uuid := current_setting('test.m5.c27.supplier')::uuid;
  v_status text;
  v_number text;
  v_invoice_count int;
begin
  select status::text, invoice_number into v_status, v_number
  from public.invoices where id = v_draft_id;

  if v_status <> 'confirmed' or v_number is null or v_number not like 'PI-%' then
    raise exception 'case27 failed: status=% number=%', v_status, v_number;
  end if;

  select count(*) into v_invoice_count
  from public.invoices
  where tenant_id = v_tenant_a and supplier_id = v_supplier and type = 'purchase';

  if v_invoice_count <> 1 then
    raise exception 'case27 failed: invoice count %', v_invoice_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 28. discard_invoice_draft removes draft only
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu and permission_id = 'invoices.edit_draft';

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'invoices.edit_draft', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-28', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-DISCARD-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  perform set_config('test.m5.c28.supplier', v_supplier::text, true);
  perform set_config('test.m5.c28.product', v_product::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c28.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c28.product')::uuid;
  v_draft_id uuid;
  v_exists boolean;
begin
  v_draft_id := public.save_invoice_draft(
    jsonb_build_object(
      'type', 'purchase',
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    )
  );

  perform set_config('test.m5.c28.draft', v_draft_id::text, true);
  perform public.discard_invoice_draft(v_draft_id);
end $$;
reset role;
do $$
declare
  v_draft_id uuid := current_setting('test.m5.c28.draft')::uuid;
  v_exists boolean;
begin
  select exists(select 1 from public.invoices where id = v_draft_id) into v_exists;

  if v_exists then
    raise exception 'case28 failed: draft still exists';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 29. Non-manager cannot edit/discard/confirm another user's draft
--     (owner creates draft; products_user attacks)
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in ('invoices.edit_draft', 'invoices.create_purchase');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'invoices.edit_draft', v_owner),
    (v_tenant_a, v_products_tu, 'invoices.create_purchase', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
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
  v_draft_id uuid;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-29', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-OWN-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_draft_id := public.save_invoice_draft(
    jsonb_build_object(
      'type', 'purchase',
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
      )
    )
  );

  perform set_config('test.m5.c29.supplier', v_supplier::text, true);
  perform set_config('test.m5.c29.product', v_product::text, true);
  perform set_config('test.m5.c29.draft', v_draft_id::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c29.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c29.product')::uuid;
  v_draft_id uuid := current_setting('test.m5.c29.draft')::uuid;
begin
  begin
    perform public.save_invoice_draft(
      jsonb_build_object(
        'type', 'purchase',
        'invoice_id', v_draft_id,
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      )
    );
    raise exception 'case29a failed: products_user edited owner draft';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;

  begin
    perform public.discard_invoice_draft(v_draft_id);
    raise exception 'case29b failed: products_user discarded owner draft';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'invoice_id', v_draft_id,
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case29c failed: products_user confirmed owner draft';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 30. Manager can edit any same-tenant purchase draft
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu and permission_id = 'invoices.edit_draft';

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'invoices.edit_draft', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_product uuid;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-30', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-MGR-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  perform set_config('test.m5.c30.supplier', v_supplier::text, true);
  perform set_config('test.m5.c30.product', v_product::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c30.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c30.product')::uuid;
  v_draft_id uuid;
begin
  v_draft_id := public.save_invoice_draft(
    jsonb_build_object(
      'type', 'purchase',
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    )
  );

  perform set_config('test.m5.c30.draft', v_draft_id::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c30.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c30.product')::uuid;
  v_draft_id uuid := current_setting('test.m5.c30.draft')::uuid;
begin
  v_draft_id := public.save_invoice_draft(
    jsonb_build_object(
      'type', 'purchase',
      'invoice_id', v_draft_id,
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 3, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
      )
    )
  );
end $$;
reset role;
do $$
declare
  v_draft_id uuid := current_setting('test.m5.c30.draft')::uuid;
  v_total numeric;
begin
  select total into v_total from public.invoices where id = v_draft_id;

  if v_total <> 30 then
    raise exception 'case30 failed: manager edit total % expected 30', v_total;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 31. Forbidden client totals/numbers in payload rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_supplier uuid;
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-31', 'create_account', true)
  );

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'subtotal', 100,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case31a failed: forbidden subtotal accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'invoice_number', 'PI-FAKE-001',
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case31b failed: forbidden invoice_number accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 32. Journal/movement/unit references correct
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
  v_invoice_id uuid;
  v_je_id uuid;
  v_move_ref text;
  v_je_source text;
  v_je_source_id uuid;
  v_unit_invoice uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-32', 'create_account', true)
  );

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 45.000, 'discount_pct', 0, 'line_order', 1,
          'units', jsonb_build_array(jsonb_build_object('serial_number', 'M5-REF-32'))
        )
      )
    ),
    gen_random_uuid()
  );

  select reference_table, reference_id into v_move_ref, v_je_source_id
  from public.inventory_movements
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and reference_id = v_invoice_id
  limit 1;

  if v_move_ref <> 'purchase_invoice' then
    raise exception 'case32 failed: movement ref %', v_move_ref;
  end if;

  select journal_entry_id into v_je_id from public.invoices where id = v_invoice_id;

  select source::text, source_id into v_je_source, v_je_source_id
  from public.journal_entries where id = v_je_id;

  if v_je_source <> 'purchase_invoice' or v_je_source_id <> v_invoice_id then
    raise exception 'case32 failed: journal source % id %', v_je_source, v_je_source_id;
  end if;

  select purchase_invoice_id into v_unit_invoice
  from public.product_units
  where lower(serial_number) = lower('M5-REF-32');

  if v_unit_invoice <> v_invoice_id then
    raise exception 'case32 failed: unit invoice ref %', v_unit_invoice;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 33. Internal helpers not executable by authenticated
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.normalize_purchase_invoice_payload('{}'::jsonb);
    raise exception 'case33a failed: normalize callable';
  exception
    when insufficient_privilege then null;
  end;

  begin
    perform public.compute_purchase_invoice_payload_hash('{}'::jsonb);
    raise exception 'case33b failed: hash callable';
  exception
    when insufficient_privilege then null;
  end;

  begin
    perform public.resolve_system_inventory_account('00000000-0000-0000-0000-000000000101');
    raise exception 'case33c failed: resolve inventory callable';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 34. Missing or invalid system inventory account 1301 blocks posting
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_inv_acct uuid;
  v_was_active boolean;
begin
  alter table public.chart_of_accounts disable trigger trg_enforce_chart_account_protection;

  select id, is_active into v_inv_acct, v_was_active
  from public.chart_of_accounts
  where tenant_id = v_tenant_a and code = '1301';

  update public.chart_of_accounts set is_active = false where id = v_inv_acct;

  alter table public.chart_of_accounts enable trigger trg_enforce_chart_account_protection;

  perform set_config('test.m5.c34.inv_acct', v_inv_acct::text, true);
  perform set_config('test.m5.c34.was_active', coalesce(v_was_active, true)::text, true);
end $$;
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
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-34', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-1301-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 1.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case34 failed: broken 1301 accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
reset role;
do $$
declare
  v_inv_acct uuid := current_setting('test.m5.c34.inv_acct')::uuid;
  v_was_active boolean := current_setting('test.m5.c34.was_active')::boolean;
begin
  alter table public.chart_of_accounts disable trigger trg_enforce_chart_account_protection;

  update public.chart_of_accounts
  set is_active = v_was_active
  where id = v_inv_acct;

  alter table public.chart_of_accounts enable trigger trg_enforce_chart_account_protection;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 35. Audit log rows created for invoice + journal + movement
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
  v_invoice_id uuid;
  v_je_id uuid;
  v_movement_id uuid;
  v_audit_inv int;
  v_audit_je int;
  v_audit_move int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-35', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-AUDIT-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  v_invoice_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_price', 3.000, 'discount_pct', 0, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id from public.invoices where id = v_invoice_id;

  select id into v_movement_id
  from public.inventory_movements
  where reference_id = v_invoice_id
  limit 1;

  select count(*) into v_audit_inv
  from public.audit_log
  where tenant_id = v_tenant_a and entity_type = 'invoices' and entity_id = v_invoice_id;

  select count(*) into v_audit_je
  from public.audit_log
  where tenant_id = v_tenant_a and entity_type = 'journal_entries' and entity_id = v_je_id;

  select count(*) into v_audit_move
  from public.audit_log
  where tenant_id = v_tenant_a and entity_type = 'inventory_movements' and entity_id = v_movement_id;

  if v_audit_inv < 1 or v_audit_je < 1 or v_audit_move < 1 then
    raise exception 'case35 failed: audit inv=% je=% move=%', v_audit_inv, v_audit_je, v_audit_move;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 36. Tax-enabled purchase with missing/inactive input tax account blocks posting
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
  v_rate_id uuid;
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-36', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_tenant_a, 'M5-TAX-ACCT-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, 'taxable', v_owner
  )
  returning id into v_product;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M5-INACT-IN', 'name_ar', 'ضريبة', 'name_en', 'Input Test',
      'rate', 5, 'effective_from', current_date - 30, 'is_recoverable', true
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object('tax_enabled', true, 'default_tax_rate_id', v_rate_id)
  );

  perform set_config('test.m5.c36.supplier', v_supplier::text, true);
  perform set_config('test.m5.c36.product', v_product::text, true);
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_input_acct uuid;
  v_was_active boolean;
begin
  alter table public.chart_of_accounts disable trigger trg_enforce_chart_account_protection;

  select id, is_active into v_input_acct, v_was_active
  from public.chart_of_accounts
  where tenant_id = v_tenant_a and code = '1151';

  update public.chart_of_accounts set is_active = false where id = v_input_acct;

  alter table public.chart_of_accounts enable trigger trg_enforce_chart_account_protection;

  perform set_config('test.m5.c36.input_acct', v_input_acct::text, true);
  perform set_config('test.m5.c36.was_active', coalesce(v_was_active, true)::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid := current_setting('test.m5.c36.supplier')::uuid;
  v_product uuid := current_setting('test.m5.c36.product')::uuid;
begin
  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_price', 10.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case36 failed: inactive input tax account accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
reset role;
do $$
declare
  v_input_acct uuid := current_setting('test.m5.c36.input_acct')::uuid;
  v_was_active boolean := current_setting('test.m5.c36.was_active')::boolean;
begin
  alter table public.chart_of_accounts disable trigger trg_enforce_chart_account_protection;

  update public.chart_of_accounts
  set is_active = v_was_active
  where id = v_input_acct;

  alter table public.chart_of_accounts enable trigger trg_enforce_chart_account_protection;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 37. Forced late failure on journal_lines -> zero residual data
-- ---------------------------------------------------------------------------
begin;
create or replace function public.test_m5_journal_lines_fail_trigger()
returns trigger
language plpgsql
as $$
begin
  if current_setting('test.m5.journal_fail_marker', true) = '__M5_ROLLBACK_MARKER__' then
    raise exception 'test_m5_late_failure';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_test_m5_journal_fail on public.journal_lines;
create trigger trg_test_m5_journal_fail
  before insert on public.journal_lines
  for each row
  execute function public.test_m5_journal_lines_fail_trigger();

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

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M5-37', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-ROLLBACK-' || left(gen_random_uuid()::text, 8),
    'زيت', 'Oil', v_oils_group, 'consumable_rental', 'ml',
    1.000, 0, false, v_owner
  )
  returning id into v_product;

  select count(*) into v_before_inv
  from public.invoices where tenant_id = v_tenant_a and type = 'purchase' and status = 'confirmed';

  select count(*) into v_before_move
  from public.inventory_movements where tenant_id = v_tenant_a and movement_type = 'purchase';

  select count(*) into v_before_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'purchase_invoice';

  select coalesce(qty_available, 0) into v_before_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  if v_before_stock is null then
    v_before_stock := 0;
  end if;

  perform set_config('test.m5.journal_fail_marker', '__M5_ROLLBACK_MARKER__', true);

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier, 'warehouse_id', v_warehouse, 'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_price', 2.000, 'discount_pct', 0, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case37 failed: late failure not raised';
  exception
    when others then
      if sqlerrm not like '%test_m5_late_failure%' then raise; end if;
  end;

  select count(*) into v_after_inv
  from public.invoices where tenant_id = v_tenant_a and type = 'purchase' and status = 'confirmed';

  select count(*) into v_after_move
  from public.inventory_movements where tenant_id = v_tenant_a and movement_type = 'purchase';

  select count(*) into v_after_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'purchase_invoice';

  select coalesce(qty_available, 0) into v_after_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_warehouse and product_id = v_product;

  if v_after_stock is null then
    v_after_stock := 0;
  end if;

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

-- ---------------------------------------------------------------------------
-- 38. Confirm/draft payloads reject unknown top, line, and unit keys
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
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'M5 case 38 supplier', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-STRICT-' || left(gen_random_uuid()::text, 8),
    'M5 strict product', 'M5 strict product', v_oils_group,
    'consumable_rental', 'ml', 1.000, 0, false, v_owner
  )
  returning id into v_product;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'unexpected_top_key', true,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case38 failed: unknown confirm top key accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1, 'unexpected_line_key', true
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case38 failed: unknown confirm line key accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1,
            'units', jsonb_build_array(
              jsonb_build_object(
                'serial_number', 'M5-STRICT-UNIT',
                'unexpected_unit_key', true
              )
            )
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case38 failed: unknown confirm unit key accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.save_invoice_draft(
      jsonb_build_object(
        'type', 'purchase',
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'unexpected_top_key', true,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      )
    );
    raise exception 'case38 failed: unknown draft top key accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.save_invoice_draft(
      jsonb_build_object(
        'type', 'purchase',
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1,
            'units', jsonb_build_array()
          )
        )
      )
    );
    raise exception 'case38 failed: confirm-only draft line key accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 39. Numeric/date/UUID fields reject strings, fractions, and malformed values
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
begin
  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'M5 case 39 supplier', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M5-TYPES-' || left(gen_random_uuid()::text, 8),
    'M5 type product', 'M5 type product', v_oils_group,
    'consumable_rental', 'ml', 1.000, 0, false, v_owner
  )
  returning id into v_product;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', '1', 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case39 failed: string qty accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1.5
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case39 failed: fractional line_order accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_purchase_invoice(
      jsonb_build_object(
        'supplier_id', 'not-a-uuid',
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case39 failed: malformed supplier UUID accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.save_invoice_draft(
      jsonb_build_object(
        'type', 'purchase',
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', 20260615,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      )
    );
    raise exception 'case39 failed: non-string draft date accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.save_invoice_draft(
      jsonb_build_object(
        'type', 'purchase',
        'supplier_id', v_supplier,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 'NaN',
            'discount_pct', 0, 'line_order', 1
          )
        )
      )
    );
    raise exception 'case39 failed: string unit_price accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

select 'phase_5_purchase_invoices.sql: passed' as result;
