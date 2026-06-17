-- Phase 5 M4.5: inventory accounting verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase C.5.
\set ON_ERROR_STOP on

-- Seed constants:
--   tenant_a=101, tenant_b=102, owner=201, zero_user=202
--   main_warehouse=701, oils_group=802

-- ---------------------------------------------------------------------------
-- 1. Opening stock: qty, WAC, Dr 1301 / Cr 3101
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_je_id uuid;
  v_stock numeric;
  v_avg numeric;
  v_dr_inv numeric;
  v_cr_eq numeric;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-OS-' || left(gen_random_uuid()::text, 8),
    'M45 OS', 'M45 OS', v_group, 'consumable_rental', 'ml',
    1.000, 0, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_doc_id := public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 opening stock case1',
      'import_key', 'M45-OS-KEY-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 50,
          'unit_cost', 4.000,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select qty_available into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_wh and product_id = v_product;

  select avg_cost into v_avg from public.products where id = v_product;

  select journal_entry_id into v_je_id
  from public.inventory_documents where id = v_doc_id;

  select coalesce(sum(jl.debit), 0) into v_dr_inv
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.code = '1301';

  select coalesce(sum(jl.credit), 0) into v_cr_eq
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.code = '3101';

  if v_stock <> 50 then raise exception 'case1 failed: stock %', v_stock; end if;
  if v_avg <> 4.000 then raise exception 'case1 failed: avg_cost %', v_avg; end if;
  if v_dr_inv <> 200.000 then raise exception 'case1 failed: dr inv %', v_dr_inv; end if;
  if v_cr_eq <> 200.000 then raise exception 'case1 failed: cr eq %', v_cr_eq; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. Stock-in owner contribution -> 3102
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_je_id uuid;
  v_cr_cap numeric;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-STI-' || left(gen_random_uuid()::text, 8),
    'M45 STI', 'M45 STI', v_group, 'consumable_rental', 'ml',
    1.000, 2.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 owner contribution',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 10,
          'unit_cost', 3.000,
          'line_order', 1
        )
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id from public.inventory_documents where id = v_doc_id;

  select coalesce(sum(jl.credit), 0) into v_cr_cap
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.code = '3102';

  if v_cr_cap <> 30.000 then raise exception 'case2 failed: cr cap %', v_cr_cap; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3. Found surplus with WAC fallback when avg_cost exists
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_je_id uuid;
  v_cr_gain numeric;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-FS-' || left(gen_random_uuid()::text, 8),
    'M45 FS', 'M45 FS', v_group, 'consumable_rental', 'ml',
    1.000, 6.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 seed for found surplus',
      'import_key', 'M45-SEED-FS-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_cost', 6.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 found surplus wac',
      'reason_code', 'found_surplus',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 2, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id
  from public.inventory_documents where id = v_doc_id;

  select coalesce(sum(jl.credit), 0) into v_cr_gain
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.code = '4102';

  if v_cr_gain <> 12.000 then raise exception 'case3 failed: cr gain %', v_cr_gain; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4. Found surplus without avg_cost -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-FS0-' || left(gen_random_uuid()::text, 8),
    'M45 FS0', 'M45 FS0', v_group, 'consumable_rental', 'ml',
    1.000, 0, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  begin
    perform public.record_inventory_document(
      jsonb_build_object(
        'document_type', 'stock_in',
        'warehouse_id', v_wh,
        'date', current_date,
        'notes', 'M45 found surplus no wac',
        'reason_code', 'found_surplus',
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case4 failed: expected validation_failed';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 5. Stock-out shrinkage -> 5152; client unit_cost rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_je_id uuid;
  v_dr_loss numeric;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-STO-' || left(gen_random_uuid()::text, 8),
    'M45 STO', 'M45 STO', v_group, 'consumable_rental', 'ml',
    1.000, 5.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 seed for stock out',
      'import_key', 'M45-SEED-STO-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 20, 'unit_cost', 5.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_out',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 shrinkage',
      'reason_code', 'shrinkage',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 4, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id
  from public.inventory_documents where id = v_doc_id;

  select coalesce(sum(jl.debit), 0) into v_dr_loss
  from public.journal_lines jl
  join public.chart_of_accounts c on c.id = jl.account_id
  where jl.journal_entry_id = v_je_id and c.code = '5152';

  if v_dr_loss <> 20.000 then raise exception 'case5 failed: dr loss %', v_dr_loss; end if;

  begin
    perform public.record_inventory_document(
      jsonb_build_object(
        'document_type', 'stock_out',
        'warehouse_id', v_wh,
        'date', current_date,
        'notes', 'M45 reject unit_cost',
        'reason_code', 'shrinkage',
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_cost', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case5b failed: expected validation_failed';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6. Stock count all-zero -> no journal_entries row
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_je_id uuid;
  v_je_count int;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-SC0-' || left(gen_random_uuid()::text, 8),
    'M45 SC0', 'M45 SC0', v_group, 'consumable_rental', 'ml',
    1.000, 5.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 seed zero count',
      'import_key', 'M45-SEED-SC0-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 7, 'unit_cost', 5.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_doc_id := public.record_stock_count(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 zero count diff',
      'gain_reason_code', 'found_surplus',
      'loss_reason_code', 'shrinkage',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'counted_qty', 7, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select journal_entry_id into v_je_id from public.inventory_documents where id = v_doc_id;

  select count(*) into v_je_count
  from public.journal_entries je
  where je.tenant_id = v_tenant_a and je.source_id = v_doc_id;

  if v_je_id is not null then raise exception 'case6 failed: journal_entry_id set'; end if;
  if v_je_count <> 0 then raise exception 'case6 failed: je count %', v_je_count; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7. Mixed stock count + movement reference_table
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_p1 uuid;
  v_p2 uuid;
  v_doc_id uuid;
  v_move_ref int;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-SCM1-' || left(gen_random_uuid()::text, 8),
    'M45 SCM1', 'M45 SCM1', v_group, 'consumable_rental', 'ml',
    1.000, 2.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_p1;

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-SCM2-' || left(gen_random_uuid()::text, 8),
    'M45 SCM2', 'M45 SCM2', v_group, 'consumable_rental', 'ml',
    1.000, 2.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_p2;

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 seed mixed count p1',
      'import_key', 'M45-SEED-SCM1-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_p1, 'qty', 10, 'unit_cost', 2.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 seed mixed count p2',
      'import_key', 'M45-SEED-SCM2-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_p2, 'qty', 8, 'unit_cost', 2.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_doc_id := public.record_stock_count(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 mixed count',
      'gain_reason_code', 'found_surplus',
      'loss_reason_code', 'shrinkage',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_p1, 'counted_qty', 12, 'line_order', 1),
        jsonb_build_object('product_id', v_p2, 'counted_qty', 5, 'line_order', 2)
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_move_ref
  from public.inventory_movements m
  where m.reference_table = 'inventory_document' and m.reference_id = v_doc_id;

  if v_move_ref <> 2 then raise exception 'case7 failed: movement count %', v_move_ref; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8. Payload counter_account_id rejected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.record_inventory_document(
      jsonb_build_object(
        'document_type', 'stock_in',
        'warehouse_id', '00000000-0000-0000-0000-000000000701',
        'date', current_date,
        'notes', 'M45 bad payload',
        'reason_code', 'found_surplus',
        'counter_account_id', gen_random_uuid(),
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', gen_random_uuid(),
            'qty', 1,
            'unit_cost', 1,
            'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case8 failed: counter_account accepted';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9. Warehouse transfer creates no journal
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh_a uuid := '00000000-0000-0000-0000-000000000701';
  v_wh_b uuid := '00000000-0000-0000-0000-000000000702';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_je_before int;
  v_je_after int;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-TR-' || left(gen_random_uuid()::text, 8),
    'M45 TR', 'M45 TR', v_group, 'consumable_rental', 'ml',
    1.000, 3.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh_a,
      'date', current_date,
      'notes', 'M45 seed transfer',
      'import_key', 'M45-SEED-TR-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 15, 'unit_cost', 3.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_je_before from public.journal_entries where tenant_id = v_tenant_a;

  perform public.record_inventory_transfer(v_wh_a, v_wh_b, v_product, 5, null, 'M45 transfer test');

  select count(*) into v_je_after from public.journal_entries where tenant_id = v_tenant_a;

  if v_je_after <> v_je_before then
    raise exception 'case9 failed: journal count changed % -> %', v_je_before, v_je_after;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10. Direct write denied on inventory_documents
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    insert into public.inventory_documents (
      tenant_id, document_type, status, document_number, document_date,
      warehouse_id, notes
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'stock_in', 'confirmed', 'BAD-001', current_date,
      '00000000-0000-0000-0000-000000000701', 'bad'
    );
    raise exception 'case10 failed: direct insert succeeded';
  exception when others then
    if sqlerrm not like '%direct_write_forbidden%'
      and sqlerrm not like '%permission denied%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11. Idempotency replay and mismatch
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_key uuid := '00000000-0000-0000-0000-00000000d101';
  v_id1 uuid;
  v_id2 uuid;
  v_count int;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-IDEM-' || left(gen_random_uuid()::text, 8),
    'M45 IDEM', 'M45 IDEM', v_group, 'consumable_rental', 'ml',
    1.000, 1.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_id1 := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 idem',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_cost', 1, 'line_order', 1)
      )
    ),
    v_key
  );

  v_id2 := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 idem',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_cost', 1, 'line_order', 1)
      )
    ),
    v_key
  );

  select count(*) into v_count
  from public.inventory_documents
  where tenant_id = v_tenant_a and idempotency_key = v_key;

  if v_id1 <> v_id2 or v_count <> 1 then
    raise exception 'case11 failed: id1=% id2=% count=%', v_id1, v_id2, v_count;
  end if;

  begin
    perform public.record_inventory_document(
      jsonb_build_object(
        'document_type', 'stock_in',
        'warehouse_id', v_wh,
        'date', current_date,
        'notes', 'M45 idem mismatch',
        'reason_code', 'owner_contribution',
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_cost', 1, 'line_order', 1)
        )
      ),
      v_key
    );
    raise exception 'case11b failed: mismatch accepted';
  exception when others then
    if sqlerrm <> 'idempotency_payload_mismatch' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12. Legacy wrapper creates journal and returns movement id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_movement_id uuid;
  v_je_count int;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-WRAP-' || left(gen_random_uuid()::text, 8),
    'M45 WRAP', 'M45 WRAP', v_group, 'consumable_rental', 'ml',
    1.000, 0, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_movement_id := public.record_inventory_adjustment(
    v_wh, v_product, 3, 'adjustment_in', 2.500, 'M45 wrapper in'
  );

  select count(*) into v_je_count
  from public.journal_entries je
  join public.inventory_movements m on m.reference_id = je.source_id
  where m.id = v_movement_id and je.source = 'inventory_stock_in';

  if v_movement_id is null then raise exception 'case12 failed: no movement id'; end if;
  if v_je_count < 1 then raise exception 'case12 failed: no journal'; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13. list_inventory_adjustment_reasons hides account_id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_json jsonb;
begin
  v_json := public.list_inventory_adjustment_reasons('stock_in', null);
  if v_json = '[]'::jsonb then raise exception 'case13 failed: empty reasons'; end if;
  if v_json::text like '%account_id%' then
    raise exception 'case13 failed: account_id exposed';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14. books_locked_through rejection
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_lock date := current_date;
begin
  update public.tenant_settings
  set books_locked_through = v_lock
  where tenant_id = v_tenant_a;

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-LOCK-' || left(gen_random_uuid()::text, 8),
    'M45 LOCK', 'M45 LOCK', v_group, 'consumable_rental', 'ml',
    1.000, 1.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  begin
    perform public.record_opening_stock(
      jsonb_build_object(
        'warehouse_id', v_wh,
        'date', v_lock,
        'notes', 'M45 locked',
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_cost', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case14 failed: locked period accepted';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 15. Serialized stock-in through M4.5 RPC
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_unit_count int;
  v_stock numeric;
  v_move_count int;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-SERIN-' || left(gen_random_uuid()::text, 8),
    'M45 SerIn', 'M45 SerIn', v_group, 'asset_rental', 'piece',
    1.000, 0, true, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 serialized stock-in',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 2,
          'unit_cost', 50.000,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M45-SIN-1'),
            jsonb_build_object('serial_number', 'M45-SIN-2')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select count(*) into v_unit_count
  from public.product_units
  where tenant_id = v_tenant_a and product_id = v_product and status = 'available_new';

  select qty_available into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_wh and product_id = v_product;

  select count(*) into v_move_count
  from public.inventory_movements
  where reference_table = 'inventory_document' and reference_id = v_doc_id;

  if v_unit_count <> 2 then raise exception 'case15 failed: units %', v_unit_count; end if;
  if v_stock <> 2 then raise exception 'case15 failed: stock %', v_stock; end if;
  if v_move_count <> 1 then raise exception 'case15 failed: movements %', v_move_count; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16. Serialized stock-out through M4.5 RPC
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_unit_id uuid;
  v_doc_id uuid;
  v_status text;
  v_stock numeric;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-SEROUT-' || left(gen_random_uuid()::text, 8),
    'M45 SerOut', 'M45 SerOut', v_group, 'asset_rental', 'piece',
    1.000, 40.000, true, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  perform public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 seed serialized out',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_cost', 40.000,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M45-SOUT-1')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  select id into v_unit_id
  from public.product_units
  where tenant_id = v_tenant_a and product_id = v_product and serial_number = 'M45-SOUT-1';

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_out',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 serialized stock-out',
      'reason_code', 'damage',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'line_order', 1,
          'unit_ids', jsonb_build_array(v_unit_id::text)
        )
      )
    ),
    gen_random_uuid()
  );

  select status into v_status from public.product_units where id = v_unit_id;
  select coalesce(qty_available, 0) into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_wh and product_id = v_product;

  if v_status <> 'retired' then raise exception 'case16 failed: status %', v_status; end if;
  if v_stock <> 0 then raise exception 'case16 failed: stock %', v_stock; end if;
  if v_doc_id is null then raise exception 'case16 failed: no doc'; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17. Cancel safe + idempotent retry returns same document id
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_cancel_key uuid := '00000000-0000-0000-0000-00000000d201';
  v_cancel1 uuid;
  v_cancel2 uuid;
  v_status text;
  v_stock numeric;
  v_reversal_count int;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-CANOK-' || left(gen_random_uuid()::text, 8),
    'M45 CanOk', 'M45 CanOk', v_group, 'consumable_rental', 'ml',
    1.000, 5.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 cancel safe seed',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 6, 'unit_cost', 5.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_cancel1 := public.cancel_inventory_document(v_doc_id, 'M45 safe cancel', v_cancel_key);
  v_cancel2 := public.cancel_inventory_document(v_doc_id, 'M45 safe cancel', v_cancel_key);

  select status into v_status from public.inventory_documents where id = v_doc_id;
  select coalesce(qty_available, 0) into v_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_wh and product_id = v_product;

  select count(*) into v_reversal_count
  from public.journal_entries je
  where je.tenant_id = v_tenant_a and je.idempotency_key = v_cancel_key;

  if v_cancel1 <> v_doc_id or v_cancel2 <> v_doc_id then
    raise exception 'case17 failed: cancel ids % %', v_cancel1, v_cancel2;
  end if;
  if v_status <> 'cancelled' then raise exception 'case17 failed: status %', v_status; end if;
  if v_stock <> 0 then raise exception 'case17 failed: stock %', v_stock; end if;
  if v_reversal_count <> 1 then raise exception 'case17 failed: reversals %', v_reversal_count; end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18. Cancel idempotency payload mismatch
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_cancel_key uuid := '00000000-0000-0000-0000-00000000d202';
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-CANMM-' || left(gen_random_uuid()::text, 8),
    'M45 CanMM', 'M45 CanMM', v_group, 'consumable_rental', 'ml',
    1.000, 3.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 cancel mismatch seed',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_cost', 3.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.cancel_inventory_document(v_doc_id, 'Reason A', v_cancel_key);

  begin
    perform public.cancel_inventory_document(v_doc_id, 'Reason B', v_cancel_key);
    raise exception 'case18 failed: mismatch accepted';
  exception when others then
    if sqlerrm <> 'idempotency_payload_mismatch' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19. Cancel unsafe -> correction_document_required
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-CANBAD-' || left(gen_random_uuid()::text, 8),
    'M45 CanBad', 'M45 CanBad', v_group, 'consumable_rental', 'ml',
    1.000, 4.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 unsafe cancel seed',
      'import_key', 'M45-SEED-CANBAD-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 10, 'unit_cost', 4.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 first doc',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 5, 'unit_cost', 4.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_out',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 later movement blocks cancel',
      'reason_code', 'shrinkage',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.cancel_inventory_document(
      v_doc_id, 'Should be blocked', gen_random_uuid()
    );
    raise exception 'case19 failed: unsafe cancel accepted';
  exception when others then
    if sqlerrm <> 'correction_document_required' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20. Serialized document cancel -> correction_document_required
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-CANSER-' || left(gen_random_uuid()::text, 8),
    'M45 CanSer', 'M45 CanSer', v_group, 'asset_rental', 'piece',
    1.000, 0, true, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 serialized cancel block',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'qty', 1,
          'unit_cost', 25.000,
          'line_order', 1,
          'units', jsonb_build_array(
            jsonb_build_object('serial_number', 'M45-CANSER-1')
          )
        )
      )
    ),
    gen_random_uuid()
  );

  begin
    perform public.cancel_inventory_document(v_doc_id, 'Try cancel serialized', gen_random_uuid());
    raise exception 'case20 failed: serialized cancel accepted';
  exception when others then
    if sqlerrm <> 'correction_document_required' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 21. Permission denied for zero-permission user
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  begin
    perform public.record_inventory_document(
      jsonb_build_object(
        'document_type', 'stock_in',
        'warehouse_id', '00000000-0000-0000-0000-000000000701',
        'date', current_date,
        'notes', 'M45 perm denied',
        'reason_code', 'owner_contribution',
        'lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', '00000000-0000-0000-0000-000000000901',
            'qty', 1,
            'unit_cost', 1,
            'line_order', 1
          )
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case21 failed: zero user accepted';
  exception when others then
    if sqlerrm <> 'permission_denied' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 22. Cross-tenant cancel denied
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-XTEN-' || left(gen_random_uuid()::text, 8),
    'M45 XTen', 'M45 XTen', v_group, 'consumable_rental', 'ml',
    1.000, 2.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  v_doc_id := public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 cross tenant seed',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 1, 'unit_cost', 2.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000204', true);

  begin
    perform public.cancel_inventory_document(v_doc_id, 'Cross tenant', gen_random_uuid());
    raise exception 'case22 failed: tenant B cancel accepted';
  exception when others then
    if sqlerrm <> 'validation_failed' and sqlerrm <> 'permission_denied' then raise; end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 23. Forced late failure -> zero residual document/stock/journal
-- ---------------------------------------------------------------------------
begin;
set local role postgres;
create or replace function public.test_m45_journal_lines_fail_trigger()
returns trigger
language plpgsql
as $$
begin
  if current_setting('test.m45.journal_fail_marker', true) = '__M45_ROLLBACK_MARKER__' then
    raise exception 'test_m45_late_failure';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_test_m45_journal_fail on public.journal_lines;
create trigger trg_test_m45_journal_fail
  before insert on public.journal_lines
  for each row
  execute function public.test_m45_journal_lines_fail_trigger();

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_before_docs int;
  v_after_docs int;
  v_before_je int;
  v_after_je int;
  v_before_stock numeric;
  v_after_stock numeric;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-ROLL-' || left(gen_random_uuid()::text, 8),
    'M45 Roll', 'M45 Roll', v_group, 'consumable_rental', 'ml',
    1.000, 0, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  select count(*) into v_before_docs from public.inventory_documents where tenant_id = v_tenant_a;
  select count(*) into v_before_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'opening_stock';
  select coalesce(qty_available, 0) into v_before_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_wh and product_id = v_product;
  if v_before_stock is null then v_before_stock := 0; end if;

  perform set_config('test.m45.journal_fail_marker', '__M45_ROLLBACK_MARKER__', true);

  begin
    perform public.record_opening_stock(
      jsonb_build_object(
        'warehouse_id', v_wh,
        'date', current_date,
        'notes', 'M45 forced rollback',
        'import_key', 'M45-ROLL-KEY-' || left(gen_random_uuid()::text, 8),
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 4, 'unit_cost', 3.000, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );
    raise exception 'case23 failed: late failure not raised';
  exception when others then
    if sqlerrm not like '%test_m45_late_failure%' then raise; end if;
  end;

  select count(*) into v_after_docs from public.inventory_documents where tenant_id = v_tenant_a;
  select count(*) into v_after_je
  from public.journal_entries where tenant_id = v_tenant_a and source = 'opening_stock';
  select coalesce(qty_available, 0) into v_after_stock
  from public.inventory_balances
  where tenant_id = v_tenant_a and warehouse_id = v_wh and product_id = v_product;
  if v_after_stock is null then v_after_stock := 0; end if;

  if v_after_docs <> v_before_docs or v_after_je <> v_before_je
    or v_after_stock <> v_before_stock then
    raise exception 'case23 failed: residual docs %->% je %->% stock %->%',
      v_before_docs, v_after_docs, v_before_je, v_after_je, v_before_stock, v_after_stock;
  end if;
end $$;

set local role postgres;
drop trigger if exists trg_test_m45_journal_fail on public.journal_lines;
drop function if exists public.test_m45_journal_lines_fail_trigger();
rollback;

-- ---------------------------------------------------------------------------
-- 24. All-owned-buckets WAC uses qty_rented in denominator
-- ---------------------------------------------------------------------------
begin;
set local role postgres;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-WACB-' || left(gen_random_uuid()::text, 8),
    'M45 WACB', 'M45 WACB', v_group, 'consumable_rental', 'ml',
    1.000, 10.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  insert into public.inventory_balances (
    tenant_id, product_id, warehouse_id, qty_available, qty_rented
  )
  values (v_tenant_a, v_product, v_wh, 0, 5)
  on conflict (warehouse_id, product_id)
  do update set qty_available = 0, qty_rented = 5;
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_product uuid;
  v_avg numeric;
  v_expected numeric := 58.000 / 7.000;
begin
  select id into v_product
  from public.products
  where tenant_id = v_tenant_a and sku like 'M45-WACB-%'
  order by created_at desc
  limit 1;

  perform public.record_inventory_document(
    jsonb_build_object(
      'document_type', 'stock_in',
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 owned-bucket wac',
      'reason_code', 'owner_contribution',
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 2, 'unit_cost', 4.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  select avg_cost into v_avg from public.products where id = v_product;

  if abs(v_avg - round(v_expected, 3)) > 0.001 then
    raise exception 'case24 failed: avg % expected %', v_avg, round(v_expected, 3);
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 25. Reason-specific postings: owner_withdrawal, internal_consumption, loss reasons
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_group uuid := '00000000-0000-0000-0000-000000000802';
  v_product uuid;
  v_doc_id uuid;
  v_je_id uuid;
  v_dr_draw numeric;
  v_dr_cons numeric;
  v_dr_loss numeric;
  v_reason text;
begin
  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a, 'M45-RSN-' || left(gen_random_uuid()::text, 8),
    'M45 Rsn', 'M45 Rsn', v_group, 'consumable_rental', 'ml',
    1.000, 10.000, false, '00000000-0000-0000-0000-000000000201'
  )
  returning id into v_product;

  perform public.record_opening_stock(
    jsonb_build_object(
      'warehouse_id', v_wh,
      'date', current_date,
      'notes', 'M45 reason seed',
      'import_key', 'M45-SEED-RSN-' || left(gen_random_uuid()::text, 8),
      'lines', jsonb_build_array(
        jsonb_build_object('product_id', v_product, 'qty', 20, 'unit_cost', 10.000, 'line_order', 1)
      )
    ),
    gen_random_uuid()
  );

  foreach v_reason in array array['owner_withdrawal', 'internal_consumption', 'damage', 'expiry', 'write_off']
  loop
    v_doc_id := public.record_inventory_document(
      jsonb_build_object(
        'document_type', 'stock_out',
        'warehouse_id', v_wh,
        'date', current_date,
        'notes', 'M45 reason ' || v_reason,
        'reason_code', v_reason,
        'lines', jsonb_build_array(
          jsonb_build_object('product_id', v_product, 'qty', 1, 'line_order', 1)
        )
      ),
      gen_random_uuid()
    );

    select journal_entry_id into v_je_id from public.inventory_documents where id = v_doc_id;

    select coalesce(sum(jl.debit), 0) into v_dr_draw
    from public.journal_lines jl
    join public.chart_of_accounts c on c.id = jl.account_id
    where jl.journal_entry_id = v_je_id and c.code = '3201';

    select coalesce(sum(jl.debit), 0) into v_dr_cons
    from public.journal_lines jl
    join public.chart_of_accounts c on c.id = jl.account_id
    where jl.journal_entry_id = v_je_id and c.code = '5901';

    select coalesce(sum(jl.debit), 0) into v_dr_loss
    from public.journal_lines jl
    join public.chart_of_accounts c on c.id = jl.account_id
    where jl.journal_entry_id = v_je_id and c.code = '5152';

    if v_reason = 'owner_withdrawal' and v_dr_draw <> 10.000 then
      raise exception 'case25 failed: withdrawal dr %', v_dr_draw;
    elsif v_reason = 'internal_consumption' and v_dr_cons <> 10.000 then
      raise exception 'case25 failed: consumption dr %', v_dr_cons;
    elsif v_reason in ('damage', 'expiry', 'write_off') and v_dr_loss <> 10.000 then
      raise exception 'case25 failed: % loss dr %', v_reason, v_dr_loss;
    end if;
  end loop;
end $$;
rollback;
