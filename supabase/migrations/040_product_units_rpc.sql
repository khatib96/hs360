-- Phase 3 M6: product unit RPCs (create with inventory side effects, safe update).
-- Serialized stock must not use direct product_units INSERT or column-level UPDATE.

create unique index if not exists ux_product_units_tenant_serial_ci
  on product_units (tenant_id, lower(btrim(serial_number)));

comment on index ux_product_units_tenant_serial_ci is
  'Case-insensitive serial uniqueness per tenant (M6).';

-- Same bar as Dart canViewFullProductCosts / canWriteProductCosts.
create or replace function user_has_full_product_cost_access()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if is_manager() then
    return true;
  end if;

  return user_has_permission('products.field.avg_cost')
    and user_has_permission('products.field.last_purchase_cost')
    and user_has_permission('products.field.min_sale_price')
    and user_has_permission('products.field.min_rental_price');
end;
$$;

comment on function user_has_full_product_cost_access() is
  'Manager or all four products.field.* cost permissions (M6 anti-tamper for purchase_cost in JSON).';

-- Creates product_units rows, adjustment_in movements, balance updates, and WAC.
-- last_purchase_cost = last resolved unit cost in JSON array order.
create or replace function create_product_units(
  p_product_id uuid,
  p_warehouse_id uuid,
  p_units jsonb
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_old_avg_cost numeric(15, 3);
  v_is_serialized boolean;
  v_warehouse_exists boolean;
  v_unit_count int;
  v_elem jsonb;
  v_serial text;
  v_serial_key text;
  v_seen_serials text[] := '{}';
  v_has_purchase_cost boolean := false;
  v_purchase_cost numeric(15, 3);
  v_unit_cost numeric(15, 3);
  v_last_resolved_cost numeric(15, 3);
  v_running_avg numeric(15, 3);
  v_running_qty numeric(15, 3);
  v_unit_id uuid;
  v_movement_id uuid;
  v_notes text;
  v_barcode text;
  v_notes_in text;
  v_health text;
  v_acquired date;
  v_created_ids uuid[] := '{}';
  v_i int;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('product_units.create') then
    raise exception 'permission_denied';
  end if;

  if p_units is null or jsonb_typeof(p_units) <> 'array' then
    raise exception 'validation_failed';
  end if;

  v_unit_count := jsonb_array_length(p_units);
  if v_unit_count < 1 or v_unit_count > 100 then
    raise exception 'validation_failed';
  end if;

  -- Anti-tamper: non-null purchase_cost in JSON requires full cost access.
  for v_i in 0 .. (v_unit_count - 1) loop
    v_elem := p_units -> v_i;
    if v_elem ? 'purchase_cost'
      and v_elem->'purchase_cost' is not null
      and v_elem->>'purchase_cost' is not null
    then
      v_has_purchase_cost := true;
      exit;
    end if;
  end loop;

  if v_has_purchase_cost and not user_has_full_product_cost_access() then
    raise exception 'permission_denied';
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

  if not v_is_serialized then
    raise exception 'not_serialized_product';
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

  -- In-batch duplicate check (case-insensitive).
  for v_i in 0 .. (v_unit_count - 1) loop
    v_elem := p_units -> v_i;
    v_serial := btrim(v_elem->>'serial_number');
    if v_serial is null or v_serial = '' then
      raise exception 'validation_failed';
    end if;
    v_serial_key := lower(v_serial);
    if v_serial_key = any (v_seen_serials) then
      raise exception 'duplicate_serial';
    end if;
    v_seen_serials := array_append(v_seen_serials, v_serial_key);

    if exists (
      select 1
      from product_units pu
      where pu.tenant_id = v_tenant_id
        and lower(btrim(pu.serial_number)) = v_serial_key
    ) then
      raise exception 'duplicate_serial';
    end if;
  end loop;

  select coalesce(sum(qty_available), 0)
  into v_running_qty
  from inventory_balances
  where tenant_id = v_tenant_id
    and product_id = p_product_id;

  v_running_avg := v_old_avg_cost;

  for v_i in 0 .. (v_unit_count - 1) loop
    v_elem := p_units -> v_i;
    v_serial := btrim(v_elem->>'serial_number');

    if v_elem ? 'purchase_cost'
      and v_elem->'purchase_cost' is not null
      and v_elem->>'purchase_cost' is not null
    then
      v_purchase_cost := (v_elem->>'purchase_cost')::numeric(15, 3);
      if v_purchase_cost < 0 then
        raise exception 'validation_failed';
      end if;
      v_unit_cost := v_purchase_cost;
    else
      v_purchase_cost := null;
      if v_old_avg_cost is null then
        raise exception 'validation_failed';
      end if;
      v_unit_cost := v_old_avg_cost;
    end if;

    v_last_resolved_cost := v_unit_cost;

    v_barcode := nullif(btrim(v_elem->>'barcode'), '');
    v_notes_in := nullif(btrim(v_elem->>'notes'), '');
    v_health := coalesce(nullif(btrim(v_elem->>'health_status'), ''), 'good');

    if v_elem ? 'acquired_at' and v_elem->>'acquired_at' is not null then
      v_acquired := (v_elem->>'acquired_at')::date;
    else
      v_acquired := current_date;
    end if;

    v_unit_id := gen_random_uuid();
    v_movement_id := gen_random_uuid();
    v_notes := 'Product unit: ' || v_serial;

    insert into product_units (
      id,
      tenant_id,
      product_id,
      serial_number,
      barcode,
      status,
      current_warehouse_id,
      purchase_cost,
      health_status,
      notes,
      acquired_at
    )
    values (
      v_unit_id,
      v_tenant_id,
      p_product_id,
      v_serial,
      v_barcode,
      'available_new',
      p_warehouse_id,
      v_purchase_cost,
      v_health,
      v_notes_in,
      v_acquired
    );

    insert into inventory_movements (
      id,
      tenant_id,
      movement_type,
      warehouse_id,
      product_id,
      product_unit_id,
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
      'adjustment_in',
      p_warehouse_id,
      p_product_id,
      v_unit_id,
      1,
      v_unit_cost,
      'product_unit',
      v_unit_id,
      v_notes,
      auth.uid()
    );

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
      1
    )
    on conflict (warehouse_id, product_id) do update
    set qty_available = inventory_balances.qty_available + 1;

    if v_running_qty = 0 then
      v_running_avg := v_unit_cost;
    else
      v_running_avg :=
        ((v_running_qty * v_running_avg) + v_unit_cost)
        / (v_running_qty + 1);
    end if;
    v_running_qty := v_running_qty + 1;

    v_created_ids := array_append(v_created_ids, v_unit_id);
  end loop;

  update products
  set
    avg_cost = v_running_avg,
    last_purchase_cost = v_last_resolved_cost,
    updated_at = now(),
    updated_by = auth.uid()
  where id = p_product_id
    and tenant_id = v_tenant_id;

  return v_created_ids;
end;
$$;

comment on function create_product_units(uuid, uuid, jsonb) is
  'M6: Insert serialized units with adjustment_in movements and balance updates. '
  'last_purchase_cost = last resolved cost in JSON order. Max 100 units per call.';

create or replace function update_product_unit_safe(
  p_unit_id uuid,
  p_barcode text,
  p_notes text,
  p_health_status text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_status unit_status;
  v_barcode text;
  v_notes text;
  v_health text;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('product_units.edit') then
    raise exception 'permission_denied';
  end if;

  select pu.status
  into v_status
  from product_units pu
  where pu.id = p_unit_id
    and pu.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_status not in (
    'available_new',
    'available_used',
    'damaged',
    'lost'
  ) then
    raise exception 'unit_not_editable';
  end if;

  if p_barcode is null then
    v_barcode := null;
  else
    v_barcode := nullif(btrim(p_barcode), '');
  end if;

  if p_notes is null then
    v_notes := null;
  else
    v_notes := nullif(btrim(p_notes), '');
  end if;

  if p_health_status is null then
    v_health := null;
  else
    v_health := btrim(p_health_status);
    if v_health = '' then
      raise exception 'validation_failed';
    end if;
    if v_health not in ('good', 'needs_service', 'damaged', 'lost') then
      raise exception 'validation_failed';
    end if;
  end if;

  update product_units
  set
    barcode = case
      when p_barcode is null then null
      else v_barcode
    end,
    notes = case
      when p_notes is null then null
      else v_notes
    end,
    health_status = case
      when p_health_status is null then health_status
      else v_health
    end,
    updated_at = now()
  where id = p_unit_id
    and tenant_id = v_tenant_id
    and status in (
      'available_new',
      'available_used',
      'damaged',
      'lost'
    );

  if not found then
    raise exception 'unit_not_editable';
  end if;

  return p_unit_id;
end;
$$;

comment on function update_product_unit_safe(uuid, text, text, text) is
  'M6: Safe edit of barcode, notes, health_status only. Tenant-scoped; status guard.';

revoke all on function user_has_full_product_cost_access() from public;
grant execute on function user_has_full_product_cost_access() to authenticated;

revoke all on function create_product_units(uuid, uuid, jsonb) from public;
grant execute on function create_product_units(uuid, uuid, jsonb) to authenticated;

revoke all on function update_product_unit_safe(uuid, text, text, text) from public;
grant execute on function update_product_unit_safe(uuid, text, text, text) to authenticated;

drop policy if exists product_units_insert on product_units;
drop policy if exists product_units_update on product_units;
drop policy if exists product_units_delete on product_units;
