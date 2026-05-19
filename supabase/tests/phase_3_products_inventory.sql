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
  values (v_tenant_a, v_products_tu, 'inventory_movements.create', v_owner_user)
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

select 'phase_3_products_inventory_verification_passed' as result;
