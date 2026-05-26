-- Phase 3 M1: products & inventory verification.
-- Run after `supabase db reset`:
-- Get-Content supabase\tests\phase_3_products_inventory.sql | docker exec -i supabase_db_hs360 psql -U postgres -d postgres

\set ON_ERROR_STOP on

-- 1. Conversion helpers (ephemeral oil product, postgres setup).
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
  v_primary numeric;
  v_secondary numeric;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor,
    sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'CONV-' || left(gen_random_uuid()::text, 8),
    'زيت تحويل', 'Conversion Oil',
    v_oils_group,
    'consumable_rental',
    'ml', 'liter', 1000,
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  select to_primary(v_product_id, 2) into v_primary;
  select to_secondary(v_product_id, 500) into v_secondary;

  if v_primary <> 2000 then
    raise exception 'to_primary failed: expected 2000, got %', v_primary;
  end if;

  if v_secondary <> 0.5 then
    raise exception 'to_secondary failed: expected 0.5, got %', v_secondary;
  end if;
end $$;
rollback;

-- 2. Tenant isolation: manager cannot adjust tenant B product in tenant A warehouse.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_b_product uuid := '00000000-0000-0000-0000-000000000902';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
begin
  perform record_inventory_adjustment(
    v_main_warehouse,
    v_tenant_b_product,
    1,
    'adjustment_in',
    1.000,
    'Cross-tenant attempt'
  );
  raise exception 'tenant isolation failed: cross-tenant adjustment succeeded';
exception
  when others then
    if sqlerrm <> 'validation_failed' then
      raise exception 'tenant isolation failed: expected validation_failed, got %', sqlerrm;
    end if;
end $$;
rollback;

-- 3. Zero-permission user cannot create adjustment.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
begin
  perform record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    1,
    'adjustment_in',
    1.000,
    'Should be denied'
  );
  raise exception 'zero-permission test failed: adjustment unexpectedly succeeded';
exception
  when others then
    if sqlerrm <> 'permission_denied' then
      raise exception 'zero-permission test failed: expected permission_denied, got %', sqlerrm;
    end if;
end $$;
rollback;

-- 4. Permission gate: grant as postgres, then products user succeeds.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
  v_movement_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor,
    sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'GATE-' || left(gen_random_uuid()::text, 8),
    'منتج صلاحية', 'Permission Gate Product',
    v_oils_group,
    'consumable_rental',
    'ml', 'liter', 1000,
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'inventory_movements.create', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.avg_cost', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.last_purchase_cost', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.min_sale_price', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.min_rental_price', v_owner_user)
  on conflict (tenant_user_id, permission_id) do nothing;

  perform set_config('test.phase3.gate_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.gate_product_id')::uuid;
  v_movement_id uuid;
begin
  v_movement_id := record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    1,
    'adjustment_in',
    0.500,
    'Permission gate stock-in'
  );

  if v_movement_id is null then
    raise exception 'permission gate failed: null movement id';
  end if;
end $$;
rollback;

-- 5. Direct inventory_movements insert is blocked even with create permission.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor,
    sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'DIRECT-' || left(gen_random_uuid()::text, 8),
    'منع حركة مباشرة', 'Direct Movement Block Product',
    v_oils_group,
    'consumable_rental',
    'ml', 'liter', 1000,
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'inventory_movements.create', v_owner_user)
  on conflict (tenant_user_id, permission_id) do nothing;

  perform set_config('test.phase3.direct_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';

do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_user uuid := '00000000-0000-0000-0000-000000000203';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.direct_product_id')::uuid;
begin
  begin
    insert into inventory_movements (
      tenant_id,
      movement_type,
      warehouse_id,
      product_id,
      qty,
      reference_table,
      notes,
      created_by
    )
    values (
      v_tenant_a,
      'adjustment_in',
      v_main_warehouse,
      v_product_id,
      1,
      'direct_insert_test',
      'Should be blocked by RPC-only policy',
      v_products_user
    );

    raise exception 'direct inventory movement insert unexpectedly succeeded';
  exception
    when insufficient_privilege or with_check_option_violation then
      null;
  end;
end $$;
rollback;

-- 6. Serialized product rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
begin
  perform record_inventory_adjustment(
    v_main_warehouse,
    v_product_a,
    1,
    'adjustment_in',
    45.000,
    'Serialized attempt'
  );
  raise exception 'serialized reject failed: adjustment unexpectedly succeeded';
exception
  when others then
    if sqlerrm <> 'serialized_adjustment_not_supported' then
      raise exception 'serialized reject failed: expected serialized_adjustment_not_supported, got %', sqlerrm;
    end if;
end $$;
rollback;

-- 7. adjustment_in creates movement, balance, and WAC update.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor,
    sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'IN-' || left(gen_random_uuid()::text, 8),
    'زيت ادخال', 'Stock In Oil',
    v_oils_group,
    'consumable_rental',
    'ml', 'liter', 1000,
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  perform set_config('test.phase3.product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.product_id')::uuid;
  v_movement_id uuid;
  v_balance numeric;
  v_avg_cost numeric;
  v_movement_count int;
begin
  v_movement_id := record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    5,
    'adjustment_in',
    0.500,
    'Phase 3 stock-in test'
  );

  select qty_available into v_balance
  from inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_main_warehouse
    and product_id = v_product_id;

  select avg_cost into v_avg_cost
  from products
  where id = v_product_id;

  select count(*) into v_movement_count
  from inventory_movements
  where id = v_movement_id;

  if v_movement_count <> 1 then
    raise exception 'adjustment_in failed: movement not found';
  end if;

  if v_balance <> 5 then
    raise exception 'adjustment_in failed: expected balance 5, got %', v_balance;
  end if;

  if v_avg_cost <> 0.500 then
    raise exception 'adjustment_in failed: expected avg_cost 0.500, got %', v_avg_cost;
  end if;

  perform set_config('test.phase3.product_id', v_product_id::text, true);
end $$;
rollback;

-- 8. adjustment_out decreases balance; unit_cost null on movement.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor,
    sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'OUT-' || left(gen_random_uuid()::text, 8),
    'زيت اخراج', 'Stock Out Oil',
    v_oils_group,
    'consumable_rental',
    'ml', 'liter', 1000,
    1.000, 0.500, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 5);

  perform set_config('test.phase3.product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.product_id')::uuid;
  v_balance numeric;
  v_unit_cost numeric;
begin
  perform record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    2,
    'adjustment_out',
    null,
    'Phase 3 stock-out test'
  );

  select qty_available into v_balance
  from inventory_balances
  where tenant_id = v_tenant_a
    and warehouse_id = v_main_warehouse
    and product_id = v_product_id;

  select unit_cost into v_unit_cost
  from inventory_movements
  where tenant_id = v_tenant_a
    and product_id = v_product_id
    and movement_type = 'adjustment_out'
  order by created_at desc
  limit 1;

  if v_balance <> 3 then
    raise exception 'adjustment_out failed: expected balance 3, got %', v_balance;
  end if;

  if v_unit_cost is not null then
    raise exception 'adjustment_out failed: expected null unit_cost on movement';
  end if;
end $$;
rollback;

-- 9. Insufficient stock rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor,
    sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'LOW-' || left(gen_random_uuid()::text, 8),
    'زيت نفاد', 'Low Stock Oil',
    v_oils_group,
    'consumable_rental',
    'ml', 'liter', 1000,
    1.000, 0.500, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 5);

  perform set_config('test.phase3.product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.product_id')::uuid;
begin
  perform record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    999,
    'adjustment_out',
    null,
    'Overdraw attempt'
  );
  raise exception 'insufficient stock test failed: adjustment unexpectedly succeeded';
exception
  when others then
    if sqlerrm <> 'insufficient_stock' then
      raise exception 'insufficient stock test failed: expected insufficient_stock, got %', sqlerrm;
    end if;
end $$;
rollback;

-- 10. adjustment_in without unit_cost rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor,
    sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'NOCOST-' || left(gen_random_uuid()::text, 8),
    'بدون تكلفة', 'No Cost Oil',
    v_oils_group,
    'consumable_rental',
    'ml', 'liter', 1000,
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  perform set_config('test.phase3.product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.product_id')::uuid;
begin
  perform record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    1,
    'adjustment_in',
    null,
    'Missing unit cost'
  );
  raise exception 'no unit_cost test failed: adjustment unexpectedly succeeded';
exception
  when others then
    if sqlerrm <> 'validation_failed' then
      raise exception 'no unit_cost test failed: expected validation_failed, got %', sqlerrm;
    end if;
end $$;
rollback;

-- 11. products_safe does not expose sensitive cost columns.
begin;
do $$
declare
  v_sensitive_count int;
begin
  select count(*) into v_sensitive_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'products_safe'
    and column_name in (
      'avg_cost',
      'last_purchase_cost',
      'min_sale_price',
      'min_rental_price'
    );

  if v_sensitive_count <> 0 then
    raise exception 'products_safe failed: exposed % sensitive columns', v_sensitive_count;
  end if;
end $$;
rollback;

-- 12. Storage bucket and policies exist (DB catalog only).
begin;
do $$
declare
  v_bucket_count int;
  v_policy_count int;
begin
  select count(*) into v_bucket_count
  from storage.buckets
  where id = 'product_images';

  if v_bucket_count <> 1 then
    raise exception 'storage bucket failed: product_images not found';
  end if;

  select count(*) into v_policy_count
  from pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
    and policyname in ('product_images_public_read', 'product_images_admin_write');

  if v_policy_count <> 2 then
    raise exception 'storage policies failed: expected 2 policies, found %', v_policy_count;
  end if;
end $$;
rollback;

-- 13. M6: create_product_units bulk (10 units), movements, balance.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_units jsonb;
  v_ids uuid[];
  v_unit_count int;
  v_movement_count int;
  v_qty numeric(15, 3);
  v_i int;
begin
  select jsonb_agg(
    jsonb_build_object('serial_number', 'M6-' || lpad(g::text, 4, '0'), 'purchase_cost', 50.000)
  )
  into v_units
  from generate_series(1, 10) g;

  v_ids := create_product_units(v_product_id, v_warehouse, v_units);

  if coalesce(array_length(v_ids, 1), 0) <> 10 then
    raise exception 'M6 bulk create: expected 10 ids, got %', coalesce(array_length(v_ids, 1), 0);
  end if;

  select count(*) into v_unit_count
  from product_units
  where product_id = v_product_id
    and serial_number like 'M6-%';

  if v_unit_count <> 10 then
    raise exception 'M6 bulk create: expected 10 units, got %', v_unit_count;
  end if;

  select count(*) into v_movement_count
  from inventory_movements im
  where im.product_id = v_product_id
    and im.product_unit_id is not null
    and im.notes like 'Product unit: M6-%';

  if v_movement_count <> 10 then
    raise exception 'M6 bulk create: expected 10 movements, got %', v_movement_count;
  end if;

  select qty_available into v_qty
  from inventory_balances
  where warehouse_id = v_warehouse
    and product_id = v_product_id;

  if coalesce(v_qty, 0) < 10 then
    raise exception 'M6 bulk create: qty_available expected >= 10, got %', coalesce(v_qty, 0);
  end if;
end $$;
rollback;

-- 14. M6: duplicate serial in batch rolls back.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_units jsonb := jsonb_build_array(
    jsonb_build_object('serial_number', 'M6-DUP-A'),
    jsonb_build_object('serial_number', 'm6-dup-a')
  );
  v_before int;
  v_after int;
begin
  select count(*) into v_before
  from product_units
  where serial_number ilike 'M6-DUP-A';

  begin
    perform create_product_units(v_product_id, v_warehouse, v_units);
    raise exception 'M6 duplicate batch: expected duplicate_serial';
  exception
    when others then
      if position('duplicate_serial' in sqlerrm) = 0 then
        raise;
      end if;
  end;

  select count(*) into v_after
  from product_units
  where serial_number ilike 'M6-DUP-A';

  if v_after <> v_before then
    raise exception 'M6 duplicate batch: rows changed from % to %', v_before, v_after;
  end if;
end $$;
rollback;

-- 15. M6: not_serialized_product rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
  v_units jsonb := jsonb_build_array(jsonb_build_object('serial_number', 'M6-NS-1'));
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M6-NS-' || left(gen_random_uuid()::text, 8),
    'غير متسلسل', 'Not Serialized',
    v_oils_group, 'sale_only', 'piece', 1, 1.000, 1.000, false, v_owner_user
  )
  returning id into v_product_id;

  begin
    perform create_product_units(v_product_id, v_warehouse, v_units);
    raise exception 'M6 not serialized: expected not_serialized_product';
  exception
    when others then
      if position('not_serialized_product' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 16. M6: direct INSERT on product_units blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
begin
  begin
    insert into product_units (
      tenant_id, product_id, serial_number, acquired_at
    )
    values (v_tenant_a, v_product_id, 'M6-DIRECT-INSERT', current_date);
    raise exception 'M6 direct insert: expected failure';
  exception
    when insufficient_privilege then
      null;
    when others then
      if position('policy' in lower(sqlerrm)) = 0
        and position('permission' in lower(sqlerrm)) = 0
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 17. M6: write policies removed from product_units catalog.
begin;
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'product_units'
    and policyname in (
      'product_units_insert',
      'product_units_update',
      'product_units_delete'
    );

  if v_count <> 0 then
    raise exception 'M6 policies: expected 0 write policies, found %', v_count;
  end if;
end $$;
rollback;

-- 17b. M6: update_product_unit_safe + unit_not_editable on rented.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_units jsonb := jsonb_build_array(jsonb_build_object('serial_number', 'M6-EDIT-1'));
  v_unit_id uuid;
  v_barcode text;
begin
  perform create_product_units(v_product_id, v_warehouse, v_units);

  select id into v_unit_id
  from product_units
  where serial_number = 'M6-EDIT-1';

  perform update_product_unit_safe(v_unit_id, 'BC-M6', 'Note M6', 'needs_service');

  select barcode into v_barcode
  from product_units
  where id = v_unit_id;

  if v_barcode <> 'BC-M6' then
    raise exception 'M6 safe update: barcode expected BC-M6, got %', v_barcode;
  end if;

  update product_units
  set status = 'rented'
  where id = v_unit_id
    and tenant_id = '00000000-0000-0000-0000-000000000101';

  begin
    perform update_product_unit_safe(v_unit_id, 'X', null, null);
    raise exception 'M6 rented edit: expected unit_not_editable';
  exception
    when others then
      if position('unit_not_editable' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 18. M6: purchase_cost without full cost permission denied.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'product_units.create', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.view', v_owner_user)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';

do $$
declare
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_units jsonb := jsonb_build_array(
    jsonb_build_object('serial_number', 'M6-COST-TAMPER', 'purchase_cost', 99.000)
  );
begin
  begin
    perform create_product_units(v_product_id, v_warehouse, v_units);
    raise exception 'M6 cost tamper: expected permission_denied';
  exception
    when others then
      if position('permission_denied' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 19. M6: last_purchase_cost = last JSON element resolved cost.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_units jsonb := jsonb_build_array(
    jsonb_build_object('serial_number', 'M6-LPC-1', 'purchase_cost', 10.000),
    jsonb_build_object('serial_number', 'M6-LPC-2', 'purchase_cost', 20.000),
    jsonb_build_object('serial_number', 'M6-LPC-3', 'purchase_cost', 30.000)
  );
  v_lpc numeric(15, 3);
begin
  perform create_product_units(v_product_id, v_warehouse, v_units);

  select last_purchase_cost into v_lpc
  from products
  where id = v_product_id;

  if v_lpc <> 30.000 then
    raise exception 'M6 last_purchase_cost: expected 30.000, got %', v_lpc;
  end if;
end $$;
rollback;

-- 20. M7A: deactivated van + new active van for same employee succeeds.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_field_employee uuid := '00000000-0000-0000-0000-000000000602';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_new_van uuid;
begin
  update warehouses
  set is_active = false
  where id = v_van_warehouse
    and tenant_id = v_tenant_a;

  insert into warehouses (tenant_id, name_ar, name_en, type, agent_id, is_active)
  values (
    v_tenant_a,
    'سيارة أحمد جديدة',
    'Ahmad van renewed',
    'van',
    v_field_employee,
    true
  )
  returning id into v_new_van;

  if v_new_van is null then
    raise exception 'M7A: expected new active van after deactivating old one';
  end if;
end $$;
rollback;

-- 21. M7A: second active van for same employee fails.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_field_employee uuid := '00000000-0000-0000-0000-000000000602';
begin
  begin
    insert into warehouses (tenant_id, name_ar, name_en, type, agent_id, is_active)
    values (
      v_tenant_a,
      'سيارة مكررة',
      'Duplicate van',
      'van',
      v_field_employee,
      true
    );
    raise exception 'M7A duplicate active van: expected unique violation';
  exception
    when unique_violation then
      if position('ux_warehouses_active_van_agent' in sqlerrm) = 0
         and position('23505' in sqlstate) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 22. M7A: van without agent_id fails CHECK constraint.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  begin
    insert into warehouses (tenant_id, name_ar, name_en, type, agent_id, is_active)
    values (
      v_tenant_a,
      'سيارة بدون مندوب',
      'Van without agent',
      'van',
      null,
      true
    );
    raise exception 'M7A van requires agent: expected check violation';
  exception
    when check_violation then
      if position('warehouses_van_requires_agent' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 23. M7D: adjustment_in denied without full cost access; adjustment_out allowed.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
begin
  delete from user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in (
      'inventory_movements.create',
      'products.field.avg_cost',
      'products.field.last_purchase_cost',
      'products.field.min_sale_price',
      'products.field.min_rental_price'
    );

  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7D-A-' || left(gen_random_uuid()::text, 8),
    'منتج M7D A', 'M7D Fixture A Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 10)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'inventory_movements.create', v_owner_user);

  perform set_config('test.phase3.m7d_a_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.m7d_a_product_id')::uuid;
begin
  begin
    perform record_inventory_adjustment(
      v_main_warehouse,
      v_product_id,
      1,
      'adjustment_in',
      1.000,
      'M7D should deny stock-in without cost'
    );
    raise exception 'M7D fixture A failed: adjustment_in succeeded without cost access';
  exception
    when others then
      if sqlerrm <> 'permission_denied' then
        raise exception 'M7D fixture A failed: expected permission_denied, got %', sqlerrm;
      end if;
  end;

  perform record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    1,
    'adjustment_out',
    null,
    'M7D create-only stock-out'
  );
end $$;
rollback;

-- 24. M7D: adjustment_in succeeds with full cost permissions.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
  v_movement_id uuid;
begin
  delete from user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in (
      'inventory_movements.create',
      'products.field.avg_cost',
      'products.field.last_purchase_cost',
      'products.field.min_sale_price',
      'products.field.min_rental_price'
    );

  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7D-B-' || left(gen_random_uuid()::text, 8),
    'منتج M7D B', 'M7D Fixture B Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'inventory_movements.create', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.avg_cost', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.last_purchase_cost', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.min_sale_price', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.field.min_rental_price', v_owner_user);

  perform set_config('test.phase3.m7d_b_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.m7d_b_product_id')::uuid;
  v_movement_id uuid;
begin
  v_movement_id := record_inventory_adjustment(
    v_main_warehouse,
    v_product_id,
    2,
    'adjustment_in',
    0.500,
    'M7D full cost stock-in'
  );

  if v_movement_id is null then
    raise exception 'M7D fixture B failed: null movement id';
  end if;
end $$;
rollback;

-- 25. M7E: successful transfer main -> van decreases source and increases destination.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid;
  v_transfer_id uuid;
  v_source_qty numeric(15, 3);
  v_dest_qty numeric(15, 3);
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7E-25-' || left(gen_random_uuid()::text, 8),
    'منتج M7E 25', 'M7E Fixture 25 Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 5.000, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 20)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_van_warehouse, v_product_id, 3)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  perform set_config('test.phase3.m7e_25_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid := current_setting('test.phase3.m7e_25_product_id')::uuid;
  v_transfer_id uuid;
  v_source_qty numeric(15, 3);
  v_dest_qty numeric(15, 3);
begin
  v_transfer_id := record_inventory_transfer(
    v_main_warehouse,
    v_van_warehouse,
    v_product_id,
    5,
    null,
    'M7E happy path transfer'
  );

  if v_transfer_id is null then
    raise exception 'M7E fixture 25 failed: null transfer id';
  end if;

  select qty_available into v_source_qty
  from inventory_balances
  where warehouse_id = v_main_warehouse and product_id = v_product_id;

  select qty_available into v_dest_qty
  from inventory_balances
  where warehouse_id = v_van_warehouse and product_id = v_product_id;

  if v_source_qty <> 15 then
    raise exception 'M7E fixture 25 failed: source expected 15, got %', v_source_qty;
  end if;

  if v_dest_qty <> 8 then
    raise exception 'M7E fixture 25 failed: dest expected 8, got %', v_dest_qty;
  end if;
end $$;
rollback;

-- 26. M7E: transfer to same warehouse fails validation_failed.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7E-26-' || left(gen_random_uuid()::text, 8),
    'منتج M7E 26', 'M7E Fixture 26 Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 10)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  perform set_config('test.phase3.m7e_26_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.m7e_26_product_id')::uuid;
begin
  begin
    perform record_inventory_transfer(
      v_main_warehouse,
      v_main_warehouse,
      v_product_id,
      1,
      null,
      'Same warehouse attempt'
    );
    raise exception 'M7E fixture 26 failed: same-warehouse transfer succeeded';
  exception
    when others then
      if sqlerrm <> 'validation_failed' then
        raise exception 'M7E fixture 26 failed: expected validation_failed, got %', sqlerrm;
      end if;
  end;
end $$;
rollback;

-- 27. M7E: transfer above available stock fails insufficient_stock.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7E-27-' || left(gen_random_uuid()::text, 8),
    'منتج M7E 27', 'M7E Fixture 27 Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 2)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  perform set_config('test.phase3.m7e_27_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid := current_setting('test.phase3.m7e_27_product_id')::uuid;
begin
  begin
    perform record_inventory_transfer(
      v_main_warehouse,
      v_van_warehouse,
      v_product_id,
      5,
      null,
      'Over stock attempt'
    );
    raise exception 'M7E fixture 27 failed: over-stock transfer succeeded';
  exception
    when others then
      if sqlerrm <> 'insufficient_stock' then
        raise exception 'M7E fixture 27 failed: expected insufficient_stock, got %', sqlerrm;
      end if;
  end;
end $$;
rollback;

-- 28. M7E: two movement rows with shared reference_id equal to returned transfer id.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7E-28-' || left(gen_random_uuid()::text, 8),
    'منتج M7E 28', 'M7E Fixture 28 Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 10)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  perform set_config('test.phase3.m7e_28_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid := current_setting('test.phase3.m7e_28_product_id')::uuid;
  v_transfer_id uuid;
  v_movement_count int;
  v_out_count int;
  v_in_count int;
begin
  v_transfer_id := record_inventory_transfer(
    v_main_warehouse,
    v_van_warehouse,
    v_product_id,
    3,
    null,
    'M7E movement audit'
  );

  select count(*) into v_movement_count
  from inventory_movements
  where reference_table = 'inventory_transfer'
    and reference_id = v_transfer_id;

  select count(*) into v_out_count
  from inventory_movements
  where reference_table = 'inventory_transfer'
    and reference_id = v_transfer_id
    and movement_type = 'transfer_out'
    and unit_cost is null;

  select count(*) into v_in_count
  from inventory_movements
  where reference_table = 'inventory_transfer'
    and reference_id = v_transfer_id
    and movement_type = 'transfer_in'
    and unit_cost is null;

  if v_movement_count <> 2 then
    raise exception 'M7E fixture 28 failed: expected 2 movements, got %', v_movement_count;
  end if;

  if v_out_count <> 1 or v_in_count <> 1 then
    raise exception 'M7E fixture 28 failed: expected transfer_out/in pair';
  end if;
end $$;
rollback;

-- 29. M7E: avg_cost and last_purchase_cost unchanged after transfer.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7E-29-' || left(gen_random_uuid()::text, 8),
    'منتج M7E 29', 'M7E Fixture 29 Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 12.500, 15.000, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 50)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  perform set_config('test.phase3.m7e_29_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid := current_setting('test.phase3.m7e_29_product_id')::uuid;
  v_avg numeric(15, 3);
  v_lpc numeric(15, 3);
begin
  perform record_inventory_transfer(
    v_main_warehouse,
    v_van_warehouse,
    v_product_id,
    4,
    null,
    'M7E WAC unchanged'
  );

  select avg_cost, last_purchase_cost into v_avg, v_lpc
  from products
  where id = v_product_id;

  if v_avg <> 12.500 then
    raise exception 'M7E fixture 29 failed: avg_cost changed to %', v_avg;
  end if;

  if v_lpc <> 15.000 then
    raise exception 'M7E fixture 29 failed: last_purchase_cost changed to %', v_lpc;
  end if;
end $$;
rollback;

-- 30. M7E: zero-permission user cannot record transfer.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
begin
  begin
    perform record_inventory_transfer(
      v_main_warehouse,
      v_van_warehouse,
      v_product_id,
      1,
      null,
      'Should be denied'
    );
    raise exception 'M7E fixture 30 failed: zero-permission transfer succeeded';
  exception
    when others then
      if sqlerrm <> 'permission_denied' then
        raise exception 'M7E fixture 30 failed: expected permission_denied, got %', sqlerrm;
      end if;
  end;
end $$;
rollback;

-- 31. M7E: lookup RPCs — create-only user succeeds; zero-permission denied.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid;
begin
  delete from user_permissions
  where tenant_user_id = v_products_tu
    and permission_id = 'inventory_movements.create';

  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, sale_price, avg_cost, is_serialized, created_by
  )
  values (
    v_tenant_a,
    'M7E-31-' || left(gen_random_uuid()::text, 8),
    'منتج M7E 31', 'M7E Fixture 31 Product',
    v_oils_group,
    'sale_only',
    'piece',
    1.000, 0, false,
    v_owner_user
  )
  returning id into v_product_id;

  insert into inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_product_id, 7)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'inventory_movements.create', v_owner_user);

  perform set_config('test.phase3.m7e_31_product_id', v_product_id::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := current_setting('test.phase3.m7e_31_product_id')::uuid;
  v_wh_count int;
  v_prod_count int;
  v_qty numeric;
begin
  select count(*) into v_wh_count from list_transfer_warehouses();
  if v_wh_count = 0 then
    raise exception 'M7E fixture 31 failed: no warehouses from lookup';
  end if;

  select count(*) into v_prod_count
  from search_transfer_products('M7E-31', 20);
  if v_prod_count = 0 then
    raise exception 'M7E fixture 31 failed: product search returned no rows';
  end if;

  v_qty := get_transfer_source_qty(v_main_warehouse, v_product_id);
  if v_qty <> 7 then
    raise exception 'M7E fixture 31 failed: expected qty 7, got %', v_qty;
  end if;
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';

do $$
declare
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_product_id uuid := '00000000-0000-0000-0000-000000000901';
begin
  begin
    perform list_transfer_warehouses();
    raise exception 'M7E fixture 31 failed: zero user listed warehouses';
  exception
    when others then
      if sqlerrm <> 'permission_denied' then
        raise exception 'M7E fixture 31 failed: warehouses expected permission_denied, got %', sqlerrm;
      end if;
  end;

  begin
    perform search_transfer_products('test', 20);
    raise exception 'M7E fixture 31 failed: zero user searched products';
  exception
    when others then
      if sqlerrm <> 'permission_denied' then
        raise exception 'M7E fixture 31 failed: search expected permission_denied, got %', sqlerrm;
      end if;
  end;

  begin
    perform get_transfer_source_qty(v_main_warehouse, v_product_id);
    raise exception 'M7E fixture 31 failed: zero user got source qty';
  exception
    when others then
      if sqlerrm <> 'permission_denied' then
        raise exception 'M7E fixture 31 failed: qty expected permission_denied, got %', sqlerrm;
      end if;
  end;
end $$;
rollback;

select 'phase_3_products_inventory_verification_passed' as result;
