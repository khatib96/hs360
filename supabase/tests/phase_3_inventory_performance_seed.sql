-- Optional Phase 3 M7.5 local performance seed.
-- Run manually after db reset when testing inventory list/movement performance:
--   docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_3_inventory_performance_seed.sql
--
-- This script is intentionally outside normal migrations and seed reset.

begin;

do $$
declare
  v_tenant_id uuid;
  v_group_id uuid;
  v_main_wh uuid;
  v_overflow_wh uuid;
  v_spare_wh uuid;
  v_product_id uuid;
  v_user_id uuid;
  v_idx int;
  v_movement_idx int;
  v_qty numeric(15, 3);
  v_reference_id uuid;
begin
  select id into v_tenant_id from tenants order by created_at limit 1;

  if v_tenant_id is null then
    raise exception 'M7.5 seed requires at least one tenant from the normal seed';
  end if;

  select id into v_user_id from auth.users order by created_at limit 1;

  insert into product_groups (tenant_id, name_ar, name_en, is_active)
  values (v_tenant_id, 'M7.5 Performance Group', 'M7.5 Performance Group', true)
  returning id into v_group_id;

  insert into warehouses (tenant_id, name_ar, name_en, type, is_active)
  values (v_tenant_id, 'M7.5 Main Performance Warehouse', 'M7.5 Main Performance Warehouse', 'main', true)
  returning id into v_main_wh;

  insert into warehouses (tenant_id, name_ar, name_en, type, is_active)
  values (v_tenant_id, 'M7.5 Overflow Performance Warehouse', 'M7.5 Overflow Performance Warehouse', 'main', true)
  returning id into v_overflow_wh;

  insert into warehouses (tenant_id, name_ar, name_en, type, is_active)
  values (v_tenant_id, 'M7.5 Spare Performance Warehouse', 'M7.5 Spare Performance Warehouse', 'branch', true)
  returning id into v_spare_wh;

  for v_idx in 1..100 loop
    insert into products (
      tenant_id,
      sku,
      name_ar,
      name_en,
      group_id,
      product_type,
      can_be_sold,
      can_be_rented,
      unit_primary,
      conversion_factor,
      sale_price,
      avg_cost,
      last_purchase_cost,
      is_serialized,
      trackable_for_maintenance,
      reorder_point,
      is_active
    )
    values (
      v_tenant_id,
      'M75-PERF-' || lpad(v_idx::text, 3, '0'),
      'M7.5 Performance Product ' || v_idx,
      'M7.5 Performance Product ' || v_idx,
      v_group_id,
      'sale_only',
      true,
      false,
      'piece',
      1,
      100 + v_idx,
      25 + (v_idx % 9),
      25 + (v_idx % 9),
      false,
      false,
      5 + (v_idx % 6),
      true
    )
    returning id into v_product_id;

    insert into inventory_balances (
      tenant_id,
      warehouse_id,
      product_id,
      qty_available
    )
    values
      (v_tenant_id, v_main_wh, v_product_id, 40 + (v_idx % 20)),
      (v_tenant_id, v_overflow_wh, v_product_id, 10 + (v_idx % 10)),
      (v_tenant_id, v_spare_wh, v_product_id, v_idx % 7);

    for v_movement_idx in 1..10 loop
      v_reference_id := gen_random_uuid();
      v_qty := 1 + (v_movement_idx % 5);

      insert into inventory_movements (
        tenant_id,
        movement_type,
        warehouse_id,
        product_id,
        qty,
        unit_cost,
        reference_table,
        reference_id,
        notes,
        occurred_at,
        created_by
      )
      values (
        v_tenant_id,
        case when v_movement_idx % 2 = 0 then 'adjustment_in'::movement_type else 'adjustment_out'::movement_type end,
        case
          when v_movement_idx % 3 = 0 then v_spare_wh
          when v_movement_idx % 3 = 1 then v_main_wh
          else v_overflow_wh
        end,
        v_product_id,
        v_qty,
        25 + (v_idx % 9),
        'm7_5_performance_seed',
        v_reference_id,
        'M7.5 performance seed movement',
        now() - ((v_idx * 10 + v_movement_idx) || ' minutes')::interval,
        v_user_id
      );
    end loop;
  end loop;
end $$;

analyze inventory_balances;
analyze inventory_movements;
analyze products;

commit;
