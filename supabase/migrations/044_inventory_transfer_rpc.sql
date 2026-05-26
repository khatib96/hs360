-- Phase 3 M7E: internal warehouse transfers + create-only lookup RPCs.

-- Active warehouses for transfer UI (gated by inventory_movements.create).
create or replace function list_transfer_warehouses()
returns table (
  id uuid,
  name_ar text,
  name_en text,
  type warehouse_type
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('inventory_movements.create') then
    raise exception 'permission_denied';
  end if;

  return query
  select w.id, w.name_ar, w.name_en, w.type
  from warehouses w
  where w.tenant_id = v_tenant_id
    and w.is_active = true
  order by w.name_en, w.name_ar;
end;
$$;

revoke all on function list_transfer_warehouses() from public;
grant execute on function list_transfer_warehouses() to authenticated;

-- Product search for transfer UI (includes serialized; no cost fields).
create or replace function search_transfer_products(
  p_search text,
  p_limit int default 20
)
returns table (
  id uuid,
  sku text,
  name_ar text,
  name_en text,
  is_serialized boolean,
  unit_primary text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_search text;
  v_limit int;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('inventory_movements.create') then
    raise exception 'permission_denied';
  end if;

  v_search := nullif(btrim(p_search), '');
  if v_search is null then
    return;
  end if;

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 50);

  return query
  select
    p.id,
    p.sku,
    p.name_ar,
    p.name_en,
    p.is_serialized,
    p.unit_primary::text
  from products p
  where p.tenant_id = v_tenant_id
    and p.is_active = true
    and (
      p.sku ilike '%' || v_search || '%'
      or p.name_ar ilike '%' || v_search || '%'
      or p.name_en ilike '%' || v_search || '%'
    )
  order by p.name_en, p.sku
  limit v_limit;
end;
$$;

revoke all on function search_transfer_products(text, int) from public;
grant execute on function search_transfer_products(text, int) to authenticated;

-- Source qty preview for transfer UI (0 when no balance row).
create or replace function get_transfer_source_qty(
  p_warehouse_id uuid,
  p_product_id uuid
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_qty numeric(15, 3);
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('inventory_movements.create') then
    raise exception 'permission_denied';
  end if;

  if p_warehouse_id is null or p_product_id is null then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1
    from warehouses w
    where w.id = p_warehouse_id
      and w.tenant_id = v_tenant_id
      and w.is_active = true
  ) then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1
    from products p
    where p.id = p_product_id
      and p.tenant_id = v_tenant_id
      and p.is_active = true
  ) then
    raise exception 'validation_failed';
  end if;

  select b.qty_available
  into v_qty
  from inventory_balances b
  where b.tenant_id = v_tenant_id
    and b.warehouse_id = p_warehouse_id
    and b.product_id = p_product_id;

  return coalesce(v_qty, 0);
end;
$$;

revoke all on function get_transfer_source_qty(uuid, uuid) from public;
grant execute on function get_transfer_source_qty(uuid, uuid) to authenticated;

-- Atomic internal transfer: balances before ledger inserts.
-- Returns transfer reference id (shared reference_id on both movements),
-- unlike record_inventory_adjustment which returns the movement id.
create or replace function record_inventory_transfer(
  p_from_warehouse_id uuid,
  p_to_warehouse_id uuid,
  p_product_id uuid,
  p_qty numeric,
  p_product_unit_id uuid default null,
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
  v_transfer_id uuid;
  v_is_serialized boolean;
  v_qty_available numeric(15, 3);
  v_from_exists boolean;
  v_to_exists boolean;
  v_movement_out_id uuid;
  v_movement_in_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('inventory_movements.create') then
    raise exception 'permission_denied';
  end if;

  if p_from_warehouse_id is null
     or p_to_warehouse_id is null
     or p_product_id is null then
    raise exception 'validation_failed';
  end if;

  if p_from_warehouse_id = p_to_warehouse_id then
    raise exception 'validation_failed';
  end if;

  if p_qty is null or p_qty <= 0 then
    raise exception 'validation_failed';
  end if;

  v_notes := nullif(btrim(p_notes), '');
  if v_notes is null then
    raise exception 'validation_failed';
  end if;

  if p_product_unit_id is not null then
    raise exception 'serialized_transfer_not_supported';
  end if;

  select p.is_serialized
  into v_is_serialized
  from products p
  where p.id = p_product_id
    and p.tenant_id = v_tenant_id
    and p.is_active = true;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_is_serialized then
    raise exception 'serialized_transfer_not_supported';
  end if;

  select exists (
    select 1
    from warehouses w
    where w.id = p_from_warehouse_id
      and w.tenant_id = v_tenant_id
      and w.is_active = true
  )
  into v_from_exists;

  if not v_from_exists then
    raise exception 'validation_failed';
  end if;

  select exists (
    select 1
    from warehouses w
    where w.id = p_to_warehouse_id
      and w.tenant_id = v_tenant_id
      and w.is_active = true
  )
  into v_to_exists;

  if not v_to_exists then
    raise exception 'validation_failed';
  end if;

  select b.qty_available
  into v_qty_available
  from inventory_balances b
  where b.tenant_id = v_tenant_id
    and b.warehouse_id = p_from_warehouse_id
    and b.product_id = p_product_id
  for update;

  if not found or coalesce(v_qty_available, 0) < p_qty then
    raise exception 'insufficient_stock';
  end if;

  update inventory_balances
  set
    qty_available = qty_available - p_qty,
    updated_at = now()
  where tenant_id = v_tenant_id
    and warehouse_id = p_from_warehouse_id
    and product_id = p_product_id;

  insert into inventory_balances (
    tenant_id,
    warehouse_id,
    product_id,
    qty_available
  )
  values (
    v_tenant_id,
    p_to_warehouse_id,
    p_product_id,
    p_qty
  )
  on conflict (warehouse_id, product_id) do update
  set
    qty_available = inventory_balances.qty_available + excluded.qty_available,
    updated_at = now();

  v_transfer_id := gen_random_uuid();
  v_movement_out_id := gen_random_uuid();
  v_movement_in_id := gen_random_uuid();

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
    v_movement_out_id,
    v_tenant_id,
    'transfer_out',
    p_from_warehouse_id,
    p_product_id,
    p_qty,
    null,
    'inventory_transfer',
    v_transfer_id,
    v_notes,
    auth.uid()
  );

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
    v_movement_in_id,
    v_tenant_id,
    'transfer_in',
    p_to_warehouse_id,
    p_product_id,
    p_qty,
    null,
    'inventory_transfer',
    v_transfer_id,
    v_notes,
    auth.uid()
  );

  return v_transfer_id;
end;
$$;

comment on function record_inventory_transfer(
  uuid,
  uuid,
  uuid,
  numeric,
  uuid,
  text
) is
  'Returns the transfer reference id used as reference_id on both movement rows; '
  'unlike record_inventory_adjustment which returns the movement id.';

revoke all on function record_inventory_transfer(
  uuid,
  uuid,
  uuid,
  numeric,
  uuid,
  text
) from public;

grant execute on function record_inventory_transfer(
  uuid,
  uuid,
  uuid,
  numeric,
  uuid,
  text
) to authenticated;
