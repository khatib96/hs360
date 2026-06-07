-- Phase 5 M2: asset identity, serial, scan, and timeline verification.
-- Run after `supabase db reset`:
-- Get-Content -Raw supabase/tests/phase_5_asset_identity.sql | docker exec -i supabase_db_hs360 psql -U postgres -d postgres

\set ON_ERROR_STOP on

-- 1. SKU auto-generation on product insert.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_sku text;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, created_by
  )
  values (
    v_tenant_a, 'منتج SKU', 'SKU Product', v_group, 'sale_only',
    'piece', 1, 0, v_owner
  )
  returning sku into v_sku;

  if v_sku <> 'SKU-000001' then
    raise exception 'case1 failed: expected SKU-000001 got %', v_sku;
  end if;
end $$;
rollback;

-- 2. SKU immutability on update.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, created_by
  )
  values (
    v_tenant_a, 'منتج ثابت', 'Immutable SKU', v_group, 'sale_only',
    'piece', 1, 0, v_owner
  )
  returning id into v_product_id;

  begin
    update products set sku = 'SKU-HACK' where id = v_product_id;
    raise exception 'case2 failed: sku update succeeded';
  exception
    when others then
      if sqlerrm not like '%immutable_column%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 3. Product barcode uniqueness (trim + case-insensitive).
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, sku, barcode, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, created_by
  )
  values (
    v_tenant_a, 'SKU-BC-1', 'ABC123', 'منتج 1', 'Product 1', v_group, 'sale_only',
    'piece', 1, 0, v_owner
  );

  begin
    insert into products (
      tenant_id, sku, barcode, name_ar, name_en, group_id, product_type,
      unit_primary, conversion_factor, sale_price, created_by
    )
    values (
      v_tenant_a, 'SKU-BC-2', ' abc123 ', 'منتج 2', 'Product 2', v_group, 'sale_only',
      'piece', 1, 0, v_owner
    );
    raise exception 'case3 failed: duplicate barcode insert succeeded';
  exception
    when unique_violation then
      null;
  end;
end $$;
rollback;

-- 4. Product unit barcode uniqueness.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_ids uuid[];
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_ids := create_product_units(
    v_product,
    v_warehouse,
    jsonb_build_array(jsonb_build_object('serial_number', 'UNIT-BC-1', 'barcode', 'UNITBC1'))
  );

  begin
    perform create_product_units(
      v_product,
      v_warehouse,
      jsonb_build_array(jsonb_build_object('serial_number', 'UNIT-BC-2', 'barcode', ' unitbc1 '))
    );
    raise exception 'case4 failed: duplicate unit barcode succeeded';
  exception
    when others then
      if sqlerrm not like '%duplicate%'
        and sqlerrm not like '%unique%'
        and sqlerrm not like '%23505%'
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 5. preview_serialized_stock_reconciliation accuracy.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
  v_qty numeric;
  v_count bigint;
  v_diff bigint;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    v_tenant_a, 'منتج تسلسل', 'Serialized', v_group, 'asset_rental',
    'piece', 1, 0, true, v_owner
  )
  returning id into v_product_id;

  perform create_product_units(
    v_product_id,
    v_warehouse,
    jsonb_build_array(
      jsonb_build_object('serial_number', 'PREV-1'),
      jsonb_build_object('serial_number', 'PREV-2')
    )
  );

  update inventory_balances
  set qty_available = 5
  where tenant_id = v_tenant_a
    and product_id = v_product_id
    and warehouse_id = v_warehouse;

  select qty_available, physical_units_count, difference
  into v_qty, v_count, v_diff
  from preview_serialized_stock_reconciliation(v_product_id, v_warehouse);

  if v_qty <> 5 or v_count <> 2 or v_diff <> 3 then
    raise exception 'case5 failed: qty=%, count=%, diff=%', v_qty, v_count, v_diff;
  end if;
end $$;
rollback;

-- 6. reconcile_serialized_stock creates units without changing balances/movements.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
  v_balance_before numeric;
  v_balance_after numeric;
  v_movements_before bigint;
  v_movements_after bigint;
  v_unit_count bigint;
  v_event_count bigint;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    v_tenant_a, 'مطابقة', 'Reconcile', v_group, 'asset_rental',
    'piece', 1, 0, true, v_owner
  )
  returning id into v_product_id;

  perform create_product_units(
    v_product_id,
    v_warehouse,
    jsonb_build_array(jsonb_build_object('serial_number', 'REC-1'))
  );

  update inventory_balances
  set qty_available = 3
  where tenant_id = v_tenant_a
    and product_id = v_product_id
    and warehouse_id = v_warehouse;

  select qty_available into v_balance_before
  from inventory_balances
  where tenant_id = v_tenant_a
    and product_id = v_product_id
    and warehouse_id = v_warehouse;

  select count(*) into v_movements_before
  from inventory_movements
  where tenant_id = v_tenant_a
    and product_id = v_product_id;

  perform reconcile_serialized_stock(
    v_product_id,
    v_warehouse,
    jsonb_build_array('REC-2', 'REC-3'),
    'Backfill missing serials'
  );

  select qty_available into v_balance_after
  from inventory_balances
  where tenant_id = v_tenant_a
    and product_id = v_product_id
    and warehouse_id = v_warehouse;

  select count(*) into v_movements_after
  from inventory_movements
  where tenant_id = v_tenant_a
    and product_id = v_product_id;

  select count(*) into v_unit_count
  from product_units
  where tenant_id = v_tenant_a
    and product_id = v_product_id
    and current_warehouse_id = v_warehouse
    and status in ('available_new', 'available_used');

  select count(*) into v_event_count
  from unit_events
  where tenant_id = v_tenant_a
    and event_type = 'reconciled';

  if v_balance_before <> v_balance_after then
    raise exception 'case6 failed: balance changed % -> %', v_balance_before, v_balance_after;
  end if;
  if v_movements_before <> v_movements_after then
    raise exception 'case6 failed: movements changed % -> %', v_movements_before, v_movements_after;
  end if;
  if v_unit_count <> 3 then
    raise exception 'case6 failed: expected 3 units got %', v_unit_count;
  end if;
  if v_event_count <> 2 then
    raise exception 'case6 failed: expected 2 unit_events got %', v_event_count;
  end if;
end $$;
rollback;

-- 7. correct_product_unit_serial updates serial and logs unit_event.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_unit_id uuid;
  v_new_serial text := 'CORR-NEW-001';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_unit_id := (create_product_units(
    v_product,
    v_warehouse,
    jsonb_build_array(jsonb_build_object('serial_number', 'CORR-OLD-001'))
  ))[1];

  perform correct_product_unit_serial(v_unit_id, v_new_serial, 'Typo fix');

  if not exists (
    select 1 from product_units
    where id = v_unit_id and serial_number = v_new_serial
  ) then
    raise exception 'case7 failed: serial not updated';
  end if;

  if not exists (
    select 1 from unit_events
    where product_unit_id = v_unit_id
      and event_type = 'serial_correction'
      and metadata_json->>'new_serial' = v_new_serial
  ) then
    raise exception 'case7 failed: serial_correction event missing';
  end if;

  begin
    perform correct_product_unit_serial(v_unit_id, 'CORR-OLD-001', 'Duplicate attempt');
    raise exception 'case7b failed: duplicate serial correction succeeded';
  exception
    when others then
      if sqlerrm not like '%duplicate_serial%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 8. resolve_scan_code priority and not-found.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_unit_id uuid;
  v_result jsonb;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_unit_id := (create_product_units(
    v_product,
    v_warehouse,
    jsonb_build_array(jsonb_build_object(
      'serial_number', 'SCAN-SERIAL-1',
      'barcode', 'SCAN-UNIT-BC'
    ))
  ))[1];

  v_result := resolve_scan_code('SCAN-UNIT-BC');
  if v_result->>'matched_by' <> 'unit_barcode'
    or v_result->>'kind' <> 'product_unit'
    or (v_result->>'id')::uuid <> v_unit_id
  then
    raise exception 'case8a failed: unit barcode priority %', v_result;
  end if;

  v_result := resolve_scan_code('628000000001');
  if v_result->>'matched_by' <> 'product_barcode'
    or v_result->>'kind' <> 'product'
    or (v_result->>'id')::uuid <> v_product
  then
    raise exception 'case8b failed: product barcode priority %', v_result;
  end if;

  v_result := resolve_scan_code('scan-serial-1');
  if v_result->>'matched_by' <> 'serial_number'
    or (v_result->>'id')::uuid <> v_unit_id
  then
    raise exception 'case8c failed: serial priority %', v_result;
  end if;

  begin
    perform resolve_scan_code('DOES-NOT-EXIST-999');
    raise exception 'case8d failed: scan_not_found not raised';
  exception
    when others then
      if sqlerrm not like '%scan_not_found%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 9. Duplicate unit barcodes rejected on bulk create (case-insensitive).
begin;
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  begin
    perform create_product_units(
      v_product,
      v_warehouse,
      jsonb_build_array(
        jsonb_build_object('serial_number', 'AMB-1', 'barcode', 'AMBIG-BC'),
        jsonb_build_object('serial_number', 'AMB-2', 'barcode', 'ambig-bc')
      )
    );
    raise exception 'case9 failed: duplicate barcodes allowed in batch';
  exception
    when unique_violation then
      null;
    when others then
      if sqlerrm not like '%unique%'
        and sqlerrm not like '%23505%'
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 10. Tenant isolation for resolve_scan_code.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
begin
  begin
    perform resolve_scan_code('628000000001');
    raise exception 'case10 failed: tenant B resolved tenant A barcode';
  exception
    when others then
      if sqlerrm not like '%scan_not_found%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 11. Tenant B cannot reconcile tenant A product.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse_a uuid := '00000000-0000-0000-0000-000000000701';
begin
  begin
    perform reconcile_serialized_stock(
      v_product_a,
      v_warehouse_a,
      jsonb_build_array('X-1'),
      'Cross tenant'
    );
    raise exception 'case11 failed: cross-tenant reconcile succeeded';
  exception
    when others then
      if sqlerrm not like '%validation_failed%'
        and sqlerrm not like '%tenant_not_found%'
        and sqlerrm not like '%permission_denied%'
      then
        raise;
      end if;
  end;
end $$;
rollback;

\echo 'phase_5_asset_identity.sql: all cases passed'
