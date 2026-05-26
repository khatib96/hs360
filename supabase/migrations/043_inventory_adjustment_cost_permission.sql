-- Phase 3 M7D: tighten record_inventory_adjustment — adjustment_in requires full cost access.

create or replace function record_inventory_adjustment(
  p_warehouse_id uuid,
  p_product_id uuid,
  p_qty numeric,
  p_movement_type movement_type,
  p_unit_cost numeric default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_notes text;
  v_movement_id uuid;
  v_old_avg_cost numeric(15, 3);
  v_is_serialized boolean;
  v_qty_available numeric(15, 3);
  v_old_total_qty numeric(15, 3);
  v_new_avg_cost numeric(15, 3);
  v_warehouse_exists boolean;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_movement_type = 'adjustment_in' then
    if not user_has_permission('inventory_movements.create')
       or not user_has_full_product_cost_access() then
      raise exception 'permission_denied';
    end if;
  elsif p_movement_type = 'adjustment_out' then
    if not user_has_permission('inventory_movements.create') then
      raise exception 'permission_denied';
    end if;
  else
    raise exception 'validation_failed';
  end if;

  if p_movement_type not in ('adjustment_in', 'adjustment_out') then
    raise exception 'validation_failed';
  end if;

  if p_qty is null or p_qty <= 0 then
    raise exception 'validation_failed';
  end if;

  v_notes := nullif(btrim(p_notes), '');
  if v_notes is null then
    raise exception 'validation_failed';
  end if;

  select avg_cost, is_serialized
  into v_old_avg_cost, v_is_serialized
  from products
  where id = p_product_id
    and tenant_id = v_tenant_id
    and is_active = true
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_is_serialized then
    raise exception 'serialized_adjustment_not_supported';
  end if;

  select exists (
    select 1
    from warehouses
    where id = p_warehouse_id
      and tenant_id = v_tenant_id
      and is_active = true
  )
  into v_warehouse_exists;

  if not v_warehouse_exists then
    raise exception 'validation_failed';
  end if;

  if p_movement_type = 'adjustment_in' then
    if p_unit_cost is null or p_unit_cost < 0 then
      raise exception 'validation_failed';
    end if;
  elsif p_movement_type = 'adjustment_out' then
    select qty_available
    into v_qty_available
    from inventory_balances
    where tenant_id = v_tenant_id
      and warehouse_id = p_warehouse_id
      and product_id = p_product_id
    for update;

    if not found or coalesce(v_qty_available, 0) < p_qty then
      raise exception 'insufficient_stock';
    end if;
  end if;

  v_movement_id := gen_random_uuid();

  insert into inventory_movements (
    id,
    tenant_id,
    movement_type,
    warehouse_id,
    product_id,
    qty,
    unit_cost,
    reference_table,
    reference_id,
    notes,
    created_by
  )
  values (
    v_movement_id,
    v_tenant_id,
    p_movement_type,
    p_warehouse_id,
    p_product_id,
    p_qty,
    case when p_movement_type = 'adjustment_in' then p_unit_cost else null end,
    'inventory_adjustment',
    v_movement_id,
    v_notes,
    auth.uid()
  );

  if p_movement_type = 'adjustment_in' then
    insert into inventory_balances (
      tenant_id,
      warehouse_id,
      product_id,
      qty_available
    )
    values (
      v_tenant_id,
      p_warehouse_id,
      p_product_id,
      p_qty
    )
    on conflict (warehouse_id, product_id) do update
    set qty_available = inventory_balances.qty_available + excluded.qty_available;

    select coalesce(sum(qty_available), 0)
    into v_old_total_qty
    from inventory_balances
    where tenant_id = v_tenant_id
      and product_id = p_product_id;

    -- WAC uses qty before this movement's delta.
    v_old_total_qty := v_old_total_qty - p_qty;

    if v_old_total_qty = 0 then
      v_new_avg_cost := p_unit_cost;
    else
      v_new_avg_cost :=
        ((v_old_total_qty * v_old_avg_cost) + (p_qty * p_unit_cost))
        / (v_old_total_qty + p_qty);
    end if;

    update products
    set
      avg_cost = v_new_avg_cost,
      last_purchase_cost = p_unit_cost,
      updated_at = now(),
      updated_by = auth.uid()
    where id = p_product_id
      and tenant_id = v_tenant_id;
  else
    update inventory_balances
    set qty_available = qty_available - p_qty
    where tenant_id = v_tenant_id
      and warehouse_id = p_warehouse_id
      and product_id = p_product_id;
  end if;

  return v_movement_id;
end;
$$;

revoke all on function record_inventory_adjustment(
  uuid,
  uuid,
  numeric,
  movement_type,
  numeric,
  text
) from public;

grant execute on function record_inventory_adjustment(
  uuid,
  uuid,
  numeric,
  movement_type,
  numeric,
  text
) to authenticated;
