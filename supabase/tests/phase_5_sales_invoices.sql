-- Phase 5 M6: sales invoice engine verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase E.
-- Manual: docker exec -i supabase_db_hs360 psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/phase_5_sales_invoices.sql

\set ON_ERROR_STOP on

-- Seed constants:
--   tenant_a=101, tenant_b=102, owner=201, zero_user=202, products_user=203
--   owner_tu=301, zero_tu=302, products_tu=303
--   product_a=901 (serialized), oils_group=802, main_warehouse=701

-- ---------------------------------------------------------------------------
-- 1. Non-serialized sale: stock down, movement type sale, balanced journal, A/R debit=total
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
  v_invoice_id uuid;
  v_je_id uuid;
  v_ar_account_id uuid;
  v_stock numeric;
  v_movement_type text;
  v_ref_table text;
  v_debit numeric;
  v_credit numeric;
  v_ar_debit numeric;
  v_total numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-1',
      'phone_primary', '+96550006001',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-1', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-OIL-1-' || left(gen_random_uuid()::text, 8),
    'زيت M6-1', 'M6 Oil 1', v_oils_group, 'consumable_rental', 'ml',
    12.500, 0, false, true, v_owner
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
          'qty', 100,
          'unit_price', 2.500,
          'discount_pct', 0,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  v_invoice_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 10,
          'unit_price', 12.500,
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

  if v_stock <> 90 then
    raise exception 'case1 failed: stock % expected 90', v_stock;
  end if;

  select movement_type::text, reference_table
  into v_movement_type, v_ref_table
  from public.inventory_movements
  where tenant_id = v_tenant_a
    and reference_table = 'sales_invoice'
    and reference_id = v_invoice_id;

  if v_movement_type is distinct from 'sale' or v_ref_table is distinct from 'sales_invoice' then
    raise exception 'case1 failed: movement type=% ref=%', v_movement_type, v_ref_table;
  end if;

  select journal_entry_id, total, c.account_id
  into v_je_id, v_total, v_ar_account_id
  from public.invoices i
  join public.customers c on c.id = i.customer_id
  where i.id = v_invoice_id;

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.journal_lines
  where journal_entry_id = v_je_id;

  select coalesce(sum(debit), 0) into v_ar_debit
  from public.journal_lines
  where journal_entry_id = v_je_id
    and account_id = v_ar_account_id;

  if v_debit <> v_credit then
    raise exception 'case1 failed: journal unbalanced debit=% credit=%', v_debit, v_credit;
  end if;

  if v_ar_debit <> v_total then
    raise exception 'case1 failed: A/R debit=% total=%', v_ar_debit, v_total;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. Serialized sale (2 lines qty=1, product_unit_id): units sold, unit_event metadata
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
  v_unit_a uuid;
  v_unit_b uuid;
  v_prev_status text;
  v_prev_wh uuid;
  v_sold_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  update public.products
  set can_be_sold = true
  where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-2',
      'phone_primary', '+96550006002',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-2', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
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
            jsonb_build_object('serial_number', 'M6-SER-2A'),
            jsonb_build_object('serial_number', 'M6-SER-2B')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_a
  from public.product_units
  where tenant_id = v_tenant_a
    and purchase_invoice_id = v_purchase_id
    and serial_number = 'M6-SER-2A';

  select id into v_unit_b
  from public.product_units
  where tenant_id = v_tenant_a
    and purchase_invoice_id = v_purchase_id
    and serial_number = 'M6-SER-2B';

  if v_unit_a is null or v_unit_b is null then
    raise exception 'case2 failed: missing purchased units';
  end if;

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_price', 12.500,
          'discount_pct', 0,
          'line_order', 1,
          'product_unit_id', v_unit_a
        ),
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_price', 12.500,
          'discount_pct', 0,
          'line_order', 2,
          'product_unit_id', v_unit_b
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_sold_count
  from public.product_units
  where tenant_id = v_tenant_a
    and id in (v_unit_a, v_unit_b)
    and status = 'sold'
    and current_warehouse_id is null
    and current_customer_id = v_customer;

  if v_sold_count <> 2 then
    raise exception 'case2 failed: sold unit count %', v_sold_count;
  end if;

  select
    ue.metadata_json ->> 'previous_status',
    (ue.metadata_json ->> 'previous_warehouse_id')::uuid
  into v_prev_status, v_prev_wh
  from public.unit_events ue
  where ue.tenant_id = v_tenant_a
    and ue.product_unit_id = v_unit_a
    and ue.reference_table = 'sales_invoice'
    and ue.reference_id = v_sale_id
    and ue.event_type = 'sales_invoice';

  if v_prev_status is null or v_prev_wh is distinct from v_warehouse then
    raise exception 'case2 failed: unit_event metadata status=% wh=%',
      v_prev_status, v_prev_wh;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2b. Serialized aggregate: 2 unit lines decrement qty_available by 2
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
  v_unit_a uuid;
  v_unit_b uuid;
  v_stock_before numeric;
  v_stock_after numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  update public.products set can_be_sold = true where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-2b',
      'phone_primary', '+96550006003',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-2b', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
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
            jsonb_build_object('serial_number', 'M6-AGG-A'),
            jsonb_build_object('serial_number', 'M6-AGG-B')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_a
  from public.product_units
  where purchase_invoice_id = v_purchase_id and serial_number = 'M6-AGG-A';

  select id into v_unit_b
  from public.product_units
  where purchase_invoice_id = v_purchase_id and serial_number = 'M6-AGG-B';

  select qty_available into v_stock_before
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  perform public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 12.500,
          'discount_pct', 0, 'line_order', 1, 'product_unit_id', v_unit_a
        ),
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 12.500,
          'discount_pct', 0, 'line_order', 2, 'product_unit_id', v_unit_b
        )
      )
    ),
    gen_random_uuid()
  );

  select qty_available into v_stock_after
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  if v_stock_before - v_stock_after <> 2 then
    raise exception 'case2b failed: stock delta % (before=% after=%)',
      v_stock_before - v_stock_after, v_stock_before, v_stock_after;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3. insufficient_stock
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
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-3',
      'phone_primary', '+96550006004',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-3', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-STK-' || left(gen_random_uuid()::text, 8),
    'زيت M6-3', 'M6 Stock', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 5, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 6, 'unit_price', 5.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case3 failed: insufficient_stock not raised';
  exception
    when others then
      if sqlerrm not like '%insufficient_stock%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4. unit/product mismatch -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_other_product uuid;
  v_purchase_id uuid;
  v_unit_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  update public.products set can_be_sold = true where id = v_product_a;

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-4',
      'phone_primary', '+96550006005',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-4', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-OTH-' || left(gen_random_uuid()::text, 8),
    'منتج آخر', 'Other Product', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_other_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_a,
          'qty', 1,
          'unit_price', 45.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M6-MIS-UNIT')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where purchase_invoice_id = v_purchase_id;

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_other_product,
            'qty', 1,
            'unit_price', 5.000,
            'discount_pct', 0,
            'line_order', 1,
            'product_unit_id', v_unit_id
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case4 failed: unit/product mismatch accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 5. sold unit reuse -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_supplier uuid;
  v_customer_a uuid;
  v_customer_b uuid;
  v_purchase_id uuid;
  v_unit_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));
  update public.products set can_be_sold = true where id = v_product;

  v_customer_a := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-5A',
      'phone_primary', '+96550006006',
      'create_account', true
    )
  );

  v_customer_b := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-5B',
      'phone_primary', '+96550006007',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-5', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_price', 45.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M6-REUSE-1')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where purchase_invoice_id = v_purchase_id;

  perform public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer_a,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 12.500,
          'discount_pct', 0, 'line_order', 1, 'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer_b,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 12.500,
            'discount_pct', 0, 'line_order', 1, 'product_unit_id', v_unit_id
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case5 failed: sold unit reuse accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6a. below min_sale_price -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-6a',
      'phone_primary', '+96550006008',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-6a', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, min_sale_price, avg_cost, is_serialized,
    can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-MIN-' || left(gen_random_uuid()::text, 8),
    'زيت حد أدنى', 'Min Price Oil', v_oils_group, 'consumable_rental', 'ml',
    10.000, 8.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m6.case6a.customer', v_customer::text, true);
  perform set_config('test.m6.case6a.product', v_product::text, true);
end $$;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in ('invoices.create_sales', 'invoices.override_min_price');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'invoices.create_sales', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_customer uuid := current_setting('test.m6.case6a.customer')::uuid;
  v_product uuid := current_setting('test.m6.case6a.product')::uuid;
begin
  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 5.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case6a failed: below min_sale_price accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6b. override with invoices.override_min_price permission succeeds
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-6b',
      'phone_primary', '+96550006009',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-6b', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, min_sale_price, avg_cost, is_serialized,
    can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-OVR-' || left(gen_random_uuid()::text, 8),
    'زيت تجاوز', 'Override Oil', v_oils_group, 'consumable_rental', 'ml',
    10.000, 8.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m6.case6b.customer', v_customer::text, true);
  perform set_config('test.m6.case6b.product', v_product::text, true);
end $$;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in ('invoices.create_sales', 'invoices.override_min_price');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'invoices.create_sales', v_owner),
    (v_tenant_a, v_products_tu, 'invoices.override_min_price', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_customer uuid := current_setting('test.m6.case6b.customer')::uuid;
  v_product uuid := current_setting('test.m6.case6b.product')::uuid;
  v_invoice_id uuid;
begin
  v_invoice_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 5.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  if v_invoice_id is null then
    raise exception 'case6b failed: override sale returned null';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6c. duplicate line_order -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-6c',
      'phone_primary', '+96550006010',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-6c', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-DUP-' || left(gen_random_uuid()::text, 8),
    'زيت تكرار', 'Dup Order Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 20, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 1, 'unit_price', 5.000,
            'discount_pct', 0, 'line_order', 1
          ),
          jsonb_build_object(
            'product_id', v_product, 'qty', 2, 'unit_price', 5.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case6c failed: duplicate line_order accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7. Multi-rate tax: separate output tax journal credit lines per output_account_id
-- ---------------------------------------------------------------------------
begin;
set local role postgres;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_2000 uuid;
  v_output_b uuid;
begin
  perform public.allow_finance_write();

  select id into v_parent_2000
  from public.chart_of_accounts
  where tenant_id = v_tenant_a and code = '2000';

  insert into public.chart_of_accounts (
    tenant_id, code, name_ar, name_en, type, parent_id, is_system, is_active
  )
  values (
    v_tenant_a, 'M6-OUT-B', 'ضريبة مخرجات ب', 'M6 Output Tax B',
    'liability', v_parent_2000, false, true
  )
  returning id into v_output_b;

  perform set_config('test.m6.output_b', v_output_b::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_output_b uuid := current_setting('test.m6.output_b')::uuid;
  v_supplier uuid;
  v_customer uuid;
  v_product_a uuid;
  v_product_b uuid;
  v_rate_a_id uuid;
  v_input_acct uuid;
  v_expense_acct uuid;
  v_output_a uuid;
  v_invoice_id uuid;
  v_je_id uuid;
  v_tax_line_count int;
  v_tax_a numeric;
  v_tax_b numeric;
begin
  v_rate_a_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M6-OUT-A',
      'name_ar', 'ضريبة أ',
      'name_en', 'M6 Tax A',
      'rate', 5,
      'effective_from', current_date - 30
    )
  );

  select output_account_id, input_account_id, expense_account_id
  into v_output_a, v_input_acct, v_expense_acct
  from public.tax_rates
  where id = v_rate_a_id;

  perform public.create_tax_rate(
    jsonb_build_object(
      'code', 'M6-OUT-B',
      'name_ar', 'ضريبة ب',
      'name_en', 'M6 Tax B',
      'rate', 10,
      'effective_from', current_date - 30,
      'output_account_id', v_output_b,
      'input_account_id', v_input_acct,
      'expense_account_id', v_expense_acct
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_rate_a_id
    )
  );

  perform set_config('test.m6.case7', '1', true);
end $$;
set local role postgres;
do $$
begin
  create or replace function public.calculate_invoice_line_snapshot(
    p_tenant_id uuid,
    p_product_id uuid,
    p_invoice_date date,
    p_qty numeric,
    p_unit_price numeric,
    p_discount_pct numeric,
    p_decimal_places integer,
    p_tax_enabled boolean,
    p_default_code text
  )
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
  as $m6case7$
  declare
    v_product public.products%rowtype;
    v_gross numeric;
    v_discount numeric;
    v_before_tax numeric;
    v_taxable numeric := 0;
    v_tax_amount numeric := 0;
    v_tax_rate numeric := 0;
    v_tax_rate_id uuid;
    v_rate_row public.tax_rates;
    v_after_tax numeric;
    v_tax_code text;
  begin
    select * into v_product
    from public.products
    where id = p_product_id and tenant_id = p_tenant_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    v_gross := public.round_money(p_qty * p_unit_price, p_decimal_places);
    v_discount := public.round_money(v_gross * p_discount_pct / 100, p_decimal_places);
    v_before_tax := v_gross - v_discount;
    v_tax_code := p_default_code;

    if current_setting('test.m6.case7', true) = '1' then
      if p_product_id = current_setting('test.m6.case7_product_a', true)::uuid then
        v_tax_code := 'M6-OUT-A';
      elsif p_product_id = current_setting('test.m6.case7_product_b', true)::uuid then
        v_tax_code := 'M6-OUT-B';
      end if;
    end if;

    if p_tax_enabled and v_product.tax_class = 'taxable' and v_tax_code is not null then
      v_rate_row := public.resolve_effective_tax_rate_version(
        p_tenant_id, v_tax_code, p_invoice_date, p_invoice_date >= current_date
      );
      v_tax_rate_id := v_rate_row.id;
      v_tax_rate := v_rate_row.rate;
      v_taxable := v_before_tax;
      v_tax_amount := public.round_money(v_taxable * v_tax_rate / 100, p_decimal_places);
    elsif p_tax_enabled and v_product.tax_class = 'zero_rated' then
      v_taxable := v_before_tax;
      v_tax_rate := 0;
      v_tax_rate_id := null;
      v_tax_amount := 0;
    else
      v_tax_rate := 0;
      v_tax_rate_id := null;
      v_taxable := 0;
      v_tax_amount := 0;
    end if;

    v_after_tax := v_before_tax + v_tax_amount;

    return jsonb_build_object(
      'product_id', p_product_id,
      'tax_class', v_product.tax_class,
      'gross_amount', v_gross,
      'discount_amount', v_discount,
      'before_tax_amount', v_before_tax,
      'tax_rate_id', v_tax_rate_id,
      'tax_rate', v_tax_rate,
      'taxable_amount', v_taxable,
      'tax_amount', v_tax_amount,
      'after_tax_amount', v_after_tax,
      'line_total', v_after_tax
    );
  end;
  $m6case7$;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_output_b uuid := current_setting('test.m6.output_b')::uuid;
  v_supplier uuid;
  v_customer uuid;
  v_product_a uuid;
  v_product_b uuid;
  v_output_a uuid;
  v_invoice_id uuid;
  v_je_id uuid;
  v_tax_line_count int;
  v_tax_a numeric;
  v_tax_b numeric;
begin
  select tr.output_account_id into v_output_a
  from public.tax_rates tr
  where tr.tenant_id = v_tenant_a and tr.code = 'M6-OUT-A';

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-7',
      'phone_primary', '+96550006011',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-7', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, tax_class, created_by
  )
  values (
    v_tenant_a, 'M6-TAX-A-' || left(gen_random_uuid()::text, 8),
    'زيت ضريبة أ', 'Tax Product A', v_oils_group, 'consumable_rental', 'ml',
    10.000, 0, false, true, 'taxable', v_owner
  )
  returning id into v_product_a;

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, tax_class, created_by
  )
  values (
    v_tenant_a, 'M6-TAX-B-' || left(gen_random_uuid()::text, 8),
    'زيت ضريبة ب', 'Tax Product B', v_oils_group, 'consumable_rental', 'ml',
    20.000, 0, false, true, 'taxable', v_owner
  )
  returning id into v_product_b;

  perform set_config('test.m6.case7_product_a', v_product_a::text, true);
  perform set_config('test.m6.case7_product_b', v_product_b::text, true);

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_a, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        ),
        jsonb_build_object(
          'product_id', v_product_b, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 2
        )
      )
    ),
    gen_random_uuid()
  );

  v_invoice_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_a, 'qty', 10, 'unit_price', 10.000,
          'discount_pct', 0, 'line_order', 1
        ),
        jsonb_build_object(
          'product_id', v_product_b, 'qty', 5, 'unit_price', 20.000,
          'discount_pct', 0, 'line_order', 2
        )
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id
  from public.invoices where id = v_invoice_id;

  select count(*) into v_tax_line_count
  from public.journal_lines
  where journal_entry_id = v_je_id
    and account_id in (v_output_a, v_output_b)
    and credit > 0;

  if v_tax_line_count <> 2 then
    raise exception 'case7 failed: output tax line count %', v_tax_line_count;
  end if;

  select coalesce(sum(credit), 0) into v_tax_a
  from public.journal_lines
  where journal_entry_id = v_je_id and account_id = v_output_a;

  select coalesce(sum(credit), 0) into v_tax_b
  from public.journal_lines
  where journal_entry_id = v_je_id and account_id = v_output_b;

  if v_tax_a <> 5 or v_tax_b <> 10 then
    raise exception 'case7 failed: tax credits a=% b=%', v_tax_a, v_tax_b;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8. COGS: serialized purchase_cost, non-serialized avg_cost on line
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product_ser uuid := '00000000-0000-0000-0000-000000000901';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product_ns uuid;
  v_purchase_id uuid;
  v_unit_id uuid;
  v_sale_id uuid;
  v_ser_cost numeric;
  v_ns_cost numeric;
  v_avg_cost numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));
  update public.products set can_be_sold = true where id = v_product_ser;

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-8',
      'phone_primary', '+96550006012',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-8', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-COGS-NS-' || left(gen_random_uuid()::text, 8),
    'زيت تكلفة', 'COGS Oil', v_oils_group, 'consumable_rental', 'ml',
    8.000, 0, false, true, v_owner
  )
  returning id into v_product_ns;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_ns, 'qty', 10, 'unit_price', 3.500,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select avg_cost into v_avg_cost from public.products where id = v_product_ns;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_ser,
          'qty', 1,
          'unit_price', 50.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M6-COGS-SER')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where purchase_invoice_id = v_purchase_id;

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_ser, 'qty', 1, 'unit_price', 12.500,
          'discount_pct', 0, 'line_order', 1, 'product_unit_id', v_unit_id
        ),
        jsonb_build_object(
          'product_id', v_product_ns, 'qty', 4, 'unit_price', 8.000,
          'discount_pct', 0, 'line_order', 2
        )
      )
    ),
    gen_random_uuid()
  );

  select cost_price into v_ser_cost
  from public.invoice_lines
  where invoice_id = v_sale_id and product_unit_id is not null;

  select cost_price into v_ns_cost
  from public.invoice_lines
  where invoice_id = v_sale_id and product_unit_id is null;

  if v_ser_cost <> 50.000 then
    raise exception 'case8 failed: serialized cost_price % expected 50.000', v_ser_cost;
  end if;

  if v_ns_cost <> v_avg_cost then
    raise exception 'case8 failed: non-serialized cost_price % avg_cost %', v_ns_cost, v_avg_cost;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9. WAC unchanged after sale
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_avg_before numeric;
  v_avg_after numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-9',
      'phone_primary', '+96550006013',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-9', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-WAC-' || left(gen_random_uuid()::text, 8),
    'زيت WAC', 'WAC Oil', v_oils_group, 'consumable_rental', 'ml',
    6.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 50, 'unit_price', 4.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select avg_cost into v_avg_before from public.products where id = v_product;

  perform public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 6.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select avg_cost into v_avg_after from public.products where id = v_product;

  if v_avg_before is distinct from v_avg_after then
    raise exception 'case9 failed: avg_cost changed % -> %', v_avg_before, v_avg_after;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10. Idempotency: same key+payload same invoice_id; different payload mismatch
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
  v_key uuid := gen_random_uuid();
  v_payload jsonb;
  v_id1 uuid;
  v_id2 uuid;
  v_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-10',
      'phone_primary', '+96550006014',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-10', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-IDEM-' || left(gen_random_uuid()::text, 8),
    'زيت تكرار', 'Idem Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 20, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  v_payload := jsonb_build_object(
    'customer_id', v_customer,
    'warehouse_id', v_warehouse,
    'date', current_date,
    'lines', jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product, 'qty', 5, 'unit_price', 5.000,
        'discount_pct', 0, 'line_order', 1
      )
    )
  );

  v_id1 := public.record_sales_invoice(v_payload, v_key);
  v_id2 := public.record_sales_invoice(v_payload, v_key);

  if v_id1 is distinct from v_id2 then
    raise exception 'case10 failed: ids differ % vs %', v_id1, v_id2;
  end if;

  select count(*) into v_count
  from public.invoices
  where tenant_id = v_tenant_a and idempotency_key = v_key;

  if v_count <> 1 then
    raise exception 'case10 failed: invoice count %', v_count;
  end if;

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 6, 'unit_price', 5.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      v_key
    );
    raise exception 'case10 failed: idempotency_payload_mismatch not raised';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11. Cross-tenant denial
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

  perform set_config('test.m6.wh_b', v_wh_b::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_warehouse_a uuid := '00000000-0000-0000-0000-000000000701';
  v_product_b uuid := '00000000-0000-0000-0000-000000000902';
  v_wh_b uuid := current_setting('test.m6.wh_b')::uuid;
  v_customer_a uuid;
  v_customer_b uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer_a := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-11A',
      'phone_primary', '+96550006015',
      'create_account', true
    )
  );

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000204', true);
  v_customer_b := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل ب',
      'phone_primary', '+96550006016'
    )
  );
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer_b,
        'warehouse_id', v_warehouse_a,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product_b, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case11a failed: cross-tenant customer accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%'
        and sqlerrm not like '%cross_tenant_reference%' then
        raise;
      end if;
  end;

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer_a,
        'warehouse_id', v_wh_b,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product_b, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case11b failed: cross-tenant warehouse accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer_a,
        'warehouse_id', v_warehouse_a,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product_b, 'qty', 1, 'unit_price', 1.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case11c failed: cross-tenant product accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12. Balanced journal sum debit=credit
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_invoice_id uuid;
  v_je_id uuid;
  v_debit numeric;
  v_credit numeric;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-12',
      'phone_primary', '+96550006017',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-12', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-BAL-' || left(gen_random_uuid()::text, 8),
    'زيت توازن', 'Balance Oil', v_oils_group, 'consumable_rental', 'ml',
    7.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 30, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  v_invoice_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 7, 'unit_price', 7.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id from public.invoices where id = v_invoice_id;

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.journal_lines
  where journal_entry_id = v_je_id;

  if v_debit <> v_credit then
    raise exception 'case12 failed: debit=% credit=%', v_debit, v_credit;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13. Sales cancel restores available_used from unit_event metadata
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
  v_status text;
  v_wh uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));
  update public.products set can_be_sold = true where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-13',
      'phone_primary', '+96550006018',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-13', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_price', 45.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M6-USED-RESTORE')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where purchase_invoice_id = v_purchase_id;

  perform set_config('test.m6.case13.unit_id', v_unit_id::text, true);
  perform set_config('test.m6.case13.customer_id', v_customer::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.product_units
  set status = 'available_used'
  where id = current_setting('test.m6.case13.unit_id')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_customer uuid := current_setting('test.m6.case13.customer_id')::uuid;
  v_sale_id uuid;
  v_unit_id uuid := current_setting('test.m6.case13.unit_id')::uuid;
  v_status text;
  v_wh uuid;
begin
  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 12.500,
          'discount_pct', 0, 'line_order', 1, 'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  perform public.cancel_invoice(
    v_sale_id, 'M6 case 13 cancel', gen_random_uuid()
  );

  select status::text, current_warehouse_id
  into v_status, v_wh
  from public.product_units
  where id = v_unit_id;

  if v_status is distinct from 'available_used' or v_wh is distinct from v_warehouse then
    raise exception 'case13 failed: status=% wh=%', v_status, v_wh;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14. Cancel reversal movement sale negative qty, no sale_return movement
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_rev_qty numeric;
  v_return_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-14',
      'phone_primary', '+96550006019',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-14', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-MOV-' || left(gen_random_uuid()::text, 8),
    'زيت حركة', 'Move Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 20, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 3, 'unit_price', 5.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  perform public.cancel_invoice(
    v_sale_id, 'M6 case 14 cancel', gen_random_uuid()
  );

  select qty into v_rev_qty
  from public.inventory_movements
  where reference_table = 'sales_invoice'
    and reference_id = v_sale_id
    and movement_type = 'sale'
    and qty < 0
  order by created_at desc
  limit 1;

  if v_rev_qty is distinct from -3 then
    raise exception 'case14 failed: reversal qty %', v_rev_qty;
  end if;

  select count(*) into v_return_count
  from public.inventory_movements
  where reference_id = v_sale_id
    and movement_type = 'sale_return';

  if v_return_count <> 0 then
    raise exception 'case14 failed: sale_return count %', v_return_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 15. Cancel blocked by paid_amount > 0
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-15',
      'phone_primary', '+96550006020',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-15', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-PAID-' || left(gen_random_uuid()::text, 8),
    'زيت مدفوع', 'Paid Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 2, 'unit_price', 5.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m6.sale15', v_sale_id::text, true);
end $$;
reset role;
do $$
declare
  v_sale_id uuid := current_setting('test.m6.sale15')::uuid;
begin
  perform public.allow_finance_write();
  update public.invoices
  set paid_amount = 1.000
  where id = v_sale_id;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_sale_id uuid := current_setting('test.m6.sale15')::uuid;
begin
  begin
    perform public.cancel_invoice(
      v_sale_id, 'M6 case 15 cancel', gen_random_uuid()
    );
    raise exception 'case15 failed: cancel with paid_amount succeeded';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16. Cancel blocked by voucher_invoice_allocations (postgres + allow_finance_write)
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
  v_ar_account uuid;
  v_voucher_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-16',
      'phone_primary', '+96550006021',
      'create_account', true
    )
  );

  select account_id into v_ar_account
  from public.customers where id = v_customer;

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-16', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-ALLOC-' || left(gen_random_uuid()::text, 8),
    'زيت تخصيص', 'Alloc Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 2, 'unit_price', 5.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m6.sale16', v_sale_id::text, true);
  perform set_config('test.m6.cust16', v_customer::text, true);
  perform set_config('test.m6.ar16', v_ar_account::text, true);
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_sale_id uuid := current_setting('test.m6.sale16')::uuid;
  v_customer uuid := current_setting('test.m6.cust16')::uuid;
  v_ar_account uuid := current_setting('test.m6.ar16')::uuid;
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_voucher_id uuid := gen_random_uuid();
begin
  perform public.allow_finance_write();

  insert into public.vouchers (
    id, tenant_id, voucher_number, type, date, amount, payment_method,
    customer_id, account_id, cash_account_id, status, confirmed_at, confirmed_by
  )
  values (
    v_voucher_id, v_tenant_a, 'RV-M6-16', 'receipt', current_date, 5.000,
    'cash', v_customer, v_ar_account, v_cash, 'confirmed',
    now(), '00000000-0000-0000-0000-000000000201'::uuid
  );

  insert into public.voucher_invoice_allocations (
    tenant_id, voucher_id, invoice_id, allocated_amount
  )
  values (v_tenant_a, v_voucher_id, v_sale_id, 5.000);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_sale_id uuid := current_setting('test.m6.sale16')::uuid;
begin
  begin
    perform public.cancel_invoice(
      v_sale_id, 'M6 case 16 cancel', gen_random_uuid()
    );
    raise exception 'case16 failed: cancel with allocation succeeded';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17. Cancel blocked by post-sale unit_event -> return_document_required
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
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));
  update public.products set can_be_sold = true where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-17',
      'phone_primary', '+96550006022',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-17', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_price', 45.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M6-DOWNSTREAM')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where purchase_invoice_id = v_purchase_id;

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 12.500,
          'discount_pct', 0, 'line_order', 1, 'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  perform set_config('test.m6.sale17', v_sale_id::text, true);
  perform set_config('test.m6.unit17', v_unit_id::text, true);
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_unit_id uuid := current_setting('test.m6.unit17')::uuid;
  v_sale_id uuid := current_setting('test.m6.sale17')::uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform public.allow_finance_write();

  insert into public.unit_events (
    tenant_id, product_unit_id, event_type, occurred_at,
    reference_table, reference_id, notes, created_by
  )
  values (
    v_tenant_a, v_unit_id, 'inspection', now() + interval '1 second',
    'manual', gen_random_uuid(), 'M6 case 17 downstream blocker',
    v_owner
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_sale_id uuid := current_setting('test.m6.sale17')::uuid;
begin
  begin
    perform public.cancel_invoice(
      v_sale_id, 'M6 case 17 cancel', gen_random_uuid()
    );
    raise exception 'case17 failed: cancel after downstream unit_event succeeded';
  exception
    when others then
      if sqlerrm not like '%return_document_required%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18a. Purchase cancel safe: stock/WAC reversed, units retired not deleted
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
  v_stock_before numeric;
  v_stock_after numeric;
  v_avg_before numeric;
  v_avg_after numeric;
  v_unit_count int;
  v_retired_count int;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-18a', 'create_account', true)
  );

  select coalesce(qty_available, 0) into v_stock_before
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  if v_stock_before is null then
    v_stock_before := 0;
  end if;

  select avg_cost into v_avg_before from public.products where id = v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_price', 40.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M6-PCANCEL-SAFE')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_unit_count
  from public.product_units
  where purchase_invoice_id = v_purchase_id;

  perform public.cancel_invoice(
    v_purchase_id, 'M6 case 18a cancel', gen_random_uuid()
  );

  select coalesce(qty_available, 0) into v_stock_after
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  if v_stock_after is null then
    v_stock_after := 0;
  end if;

  select avg_cost into v_avg_after from public.products where id = v_product;

  select count(*) into v_retired_count
  from public.product_units
  where purchase_invoice_id = v_purchase_id
    and status = 'retired';

  if v_stock_after <> v_stock_before then
    raise exception 'case18a failed: stock % -> %', v_stock_before, v_stock_after;
  end if;

  if v_stock_before = 0 and v_avg_after is distinct from 0 then
    raise exception 'case18a failed: avg_cost expected 0 after sole purchase cancel, got %', v_avg_after;
  elsif v_stock_before > 0 and v_avg_after is distinct from v_avg_before then
    raise exception 'case18a failed: avg_cost % -> %', v_avg_before, v_avg_after;
  end if;

  if v_unit_count <> 1 or v_retired_count <> 1 then
    raise exception 'case18a failed: units % retired %', v_unit_count, v_retired_count;
  end if;

  if not exists (
    select 1 from public.product_units where purchase_invoice_id = v_purchase_id
  ) then
    raise exception 'case18a failed: unit row deleted';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18b. Sell unit then cancel purchase -> return_document_required
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
  v_unit_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));
  update public.products set can_be_sold = true where id = v_product;

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-18b',
      'phone_primary', '+96550006023',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-18b', 'create_account', true)
  );

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_price', 45.000,
          'discount_pct', 0,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M6-PCANCEL-UNSAFE')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where purchase_invoice_id = v_purchase_id;

  perform public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 1, 'unit_price', 12.500,
          'discount_pct', 0, 'line_order', 1, 'product_unit_id', v_unit_id
        )
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.cancel_invoice(
      v_purchase_id, 'M6 case 18b cancel', gen_random_uuid()
    );
    raise exception 'case18b failed: purchase cancel after sale succeeded';
  exception
    when others then
      if sqlerrm not like '%return_document_required%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18c. Post-purchase movement with later occurred_at blocks cancel
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
  v_purchase_occurred timestamptz;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-18c', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-18C-' || left(gen_random_uuid()::text, 8),
    'زيت لاحق', 'Later Move Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select occurred_at into v_purchase_occurred
  from public.inventory_movements
  where tenant_id = v_tenant_a
    and reference_table = 'purchase_invoice'
    and reference_id = v_purchase_id
    and product_id = v_product
  limit 1;

  perform set_config('test.m6.purchase18c', v_purchase_id::text, true);
  perform set_config('test.m6.product18c', v_product::text, true);
  perform set_config('test.m6.occurred18c', v_purchase_occurred::text, true);
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_purchase_id uuid := current_setting('test.m6.purchase18c')::uuid;
  v_product uuid := current_setting('test.m6.product18c')::uuid;
  v_purchase_occurred timestamptz := current_setting('test.m6.occurred18c')::timestamptz;
begin
  perform public.allow_finance_write();

  insert into public.inventory_movements (
    tenant_id, movement_type, warehouse_id, product_id, qty, unit_cost,
    reference_table, reference_id, notes, occurred_at, created_by
  )
  values (
    v_tenant_a, 'adjustment_out', v_warehouse, v_product, 1, 2.000,
    'manual', gen_random_uuid(), 'M6-18c later movement',
    v_purchase_occurred + interval '1 second', v_owner
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_purchase_id uuid := current_setting('test.m6.purchase18c')::uuid;
begin
  begin
    perform public.cancel_invoice(
      v_purchase_id, 'M6 case 18c cancel', gen_random_uuid()
    );
    raise exception 'case18c failed: purchase cancel with later movement succeeded';
  exception
    when others then
      if sqlerrm not like '%return_document_required%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18d. Same occurred_at different id blocks cancel
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
  v_purchase_occurred timestamptz;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-18d', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-18D-' || left(gen_random_uuid()::text, 8),
    'زيت نفس الوقت', 'Same TS Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  v_purchase_id := public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select occurred_at into v_purchase_occurred
  from public.inventory_movements
  where tenant_id = v_tenant_a
    and reference_table = 'purchase_invoice'
    and reference_id = v_purchase_id
    and product_id = v_product
  limit 1;

  perform set_config('test.m6.purchase18d', v_purchase_id::text, true);
  perform set_config('test.m6.product18d', v_product::text, true);
  perform set_config('test.m6.occurred18d', v_purchase_occurred::text, true);
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product uuid := current_setting('test.m6.product18d')::uuid;
  v_purchase_occurred timestamptz := current_setting('test.m6.occurred18d')::timestamptz;
begin
  perform public.allow_finance_write();

  insert into public.inventory_movements (
    tenant_id, movement_type, warehouse_id, product_id, qty, unit_cost,
    reference_table, reference_id, notes, occurred_at, created_by
  )
  values (
    v_tenant_a, 'adjustment_out', v_warehouse, v_product, 1, 2.000,
    'manual', gen_random_uuid(), 'M6-18d same timestamp movement',
    v_purchase_occurred, v_owner
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_purchase_id uuid := current_setting('test.m6.purchase18d')::uuid;
begin
  begin
    perform public.cancel_invoice(
      v_purchase_id, 'M6 case 18d cancel', gen_random_uuid()
    );
    raise exception 'case18d failed: purchase cancel with same-ts movement succeeded';
  exception
    when others then
      if sqlerrm not like '%return_document_required%' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19. Cancel idempotency retry returns invoice_id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_supplier uuid;
  v_customer uuid;
  v_product uuid;
  v_sale_id uuid;
  v_cancel_key uuid := gen_random_uuid();
  v_retry_id uuid;
begin
  perform public.update_tax_settings(jsonb_build_object('tax_enabled', false));

  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M6-19',
      'phone_primary', '+96550006024',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-19', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'M6-CANID-' || left(gen_random_uuid()::text, 8),
    'زيت إلغاء', 'Cancel Idem Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 10, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  v_sale_id := public.record_sales_invoice(
    jsonb_build_object(
      'customer_id', v_customer,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 2, 'unit_price', 5.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  perform public.cancel_invoice(
    v_sale_id, 'M6 case 19 cancel', v_cancel_key
  );

  v_retry_id := public.cancel_invoice(
    v_sale_id, 'M6 case 19 cancel', v_cancel_key
  );

  if v_retry_id is distinct from v_sale_id then
    raise exception 'case19 failed: retry returned % expected %', v_retry_id, v_sale_id;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20. Rollback after forced failure on journal_lines (like M5 case 37)
-- ---------------------------------------------------------------------------
begin;
create or replace function public.test_m6_journal_lines_fail_trigger()
returns trigger
language plpgsql
as $$
begin
  if current_setting('test.m6.journal_fail_marker', true) = '__M6_ROLLBACK_MARKER__' then
    raise exception 'test_m6_late_failure';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_test_m6_journal_fail on public.journal_lines;
create trigger trg_test_m6_journal_fail
  before insert on public.journal_lines
  for each row
  execute function public.test_m6_journal_lines_fail_trigger();

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
    jsonb_build_object(
      'name_ar', 'عميل M6-20',
      'phone_primary', '+96550006025',
      'create_account', true
    )
  );

  v_supplier := public.create_supplier(
    jsonb_build_object('name_ar', 'مورد M6-20', 'create_account', true)
  );

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, can_be_sold, created_by
  )
  values (
    v_tenant_a, 'M6-ROLLBACK-' || left(gen_random_uuid()::text, 8),
    'زيت تراجع', 'Rollback Oil', v_oils_group, 'consumable_rental', 'ml',
    5.000, 0, false, true, v_owner
  )
  returning id into v_product;

  perform public.record_purchase_invoice(
    jsonb_build_object(
      'supplier_id', v_supplier,
      'warehouse_id', v_warehouse,
      'date', current_date,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product, 'qty', 20, 'unit_price', 2.000,
          'discount_pct', 0, 'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_before_inv
  from public.invoices
  where tenant_id = v_tenant_a and type = 'sales' and status = 'confirmed';

  select count(*) into v_before_move
  from public.inventory_movements
  where tenant_id = v_tenant_a and movement_type = 'sale' and qty > 0;

  select count(*) into v_before_je
  from public.journal_entries
  where tenant_id = v_tenant_a and source = 'sales_invoice';

  select coalesce(qty_available, 0) into v_before_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  perform set_config('test.m6.journal_fail_marker', '__M6_ROLLBACK_MARKER__', true);

  begin
    perform public.record_sales_invoice(
      jsonb_build_object(
        'customer_id', v_customer,
        'warehouse_id', v_warehouse,
        'date', current_date,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product, 'qty', 5, 'unit_price', 5.000,
            'discount_pct', 0, 'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case20 failed: late failure not raised';
  exception
    when others then
      if sqlerrm not like '%test_m6_late_failure%' then raise; end if;
  end;

  select count(*) into v_after_inv
  from public.invoices
  where tenant_id = v_tenant_a and type = 'sales' and status = 'confirmed';

  select count(*) into v_after_move
  from public.inventory_movements
  where tenant_id = v_tenant_a and movement_type = 'sale' and qty > 0;

  select count(*) into v_after_je
  from public.journal_entries
  where tenant_id = v_tenant_a and source = 'sales_invoice';

  select coalesce(qty_available, 0) into v_after_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_warehouse
    and product_id = v_product;

  if v_after_inv <> v_before_inv
    or v_after_move <> v_before_move
    or v_after_je <> v_before_je
    or v_after_stock <> v_before_stock then
    raise exception 'case20 failed: residual inv %->% move %->% je %->% stock %->%',
      v_before_inv, v_after_inv, v_before_move, v_after_move,
      v_before_je, v_after_je, v_before_stock, v_after_stock;
  end if;
end $$;
rollback;
