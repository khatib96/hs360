-- Phase 6 M9 corrective pass: prepare serial tracking for existing stock.

create or replace function public.prepare_product_serial_tracking(
  p_product_id uuid,
  p_warehouse_id uuid,
  p_serials jsonb,
  p_reason text
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_product public.products%rowtype;
  v_qty numeric(15, 3);
  v_existing_count bigint;
  v_difference bigint;
  v_serial_count int;
  v_elem jsonb;
  v_serial text;
  v_serial_key text;
  v_seen text[] := '{}'::text[];
  v_unit_id uuid;
  v_created_ids uuid[] := '{}'::uuid[];
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not (
    public.is_manager()
    or public.user_has_permission('product_units.reconcile_serials')
  ) then
    raise exception 'permission_denied';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'validation_failed';
  end if;

  if p_serials is null or jsonb_typeof(p_serials) <> 'array' then
    raise exception 'validation_failed';
  end if;

  select *
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = v_tenant_id
    and p.is_active = true
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_product.product_type is distinct from 'asset_rental'::public.product_type then
    raise exception 'validation_failed';
  end if;

  if v_product.unit_primary is distinct from 'piece'::public.unit_of_measure then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1
    from public.warehouses w
    where w.id = p_warehouse_id
      and w.tenant_id = v_tenant_id
      and w.is_active = true
  ) then
    raise exception 'validation_failed';
  end if;

  select coalesce(ib.qty_available, 0)
  into v_qty
  from public.inventory_balances ib
  where ib.tenant_id = v_tenant_id
    and ib.product_id = p_product_id
    and ib.warehouse_id = p_warehouse_id
  for update;

  if not found then
    v_qty := 0;
  end if;

  if v_qty <= 0 or v_qty <> trunc(v_qty) then
    raise exception 'validation_failed';
  end if;

  select count(*)
  into v_existing_count
  from public.product_units pu
  where pu.tenant_id = v_tenant_id
    and pu.product_id = p_product_id
    and pu.current_warehouse_id = p_warehouse_id
    and pu.status in ('available_new', 'available_used');

  v_difference := v_qty::bigint - v_existing_count;
  v_serial_count := jsonb_array_length(p_serials);

  if v_difference <= 0 then
    raise exception 'validation_failed';
  end if;

  if v_serial_count <> v_difference then
    raise exception 'validation_failed';
  end if;

  if v_serial_count > 500 then
    raise exception 'validation_failed';
  end if;

  for v_idx in 0 .. (v_serial_count - 1) loop
    v_elem := p_serials -> v_idx;
    if jsonb_typeof(v_elem) <> 'string' then
      raise exception 'validation_failed';
    end if;

    v_serial := btrim(v_elem #>> '{}');
    if v_serial = '' then
      raise exception 'validation_failed';
    end if;

    v_serial_key := lower(v_serial);
    if v_serial_key = any (v_seen) then
      raise exception 'duplicate_serial';
    end if;
    v_seen := array_append(v_seen, v_serial_key);

    if exists (
      select 1
      from public.product_units pu
      where pu.tenant_id = v_tenant_id
        and lower(btrim(pu.serial_number)) = v_serial_key
    ) then
      raise exception 'duplicate_serial';
    end if;
  end loop;

  update public.products
  set
    is_serialized = true,
    unit_primary = 'piece'::public.unit_of_measure,
    unit_secondary = null,
    conversion_factor = 1,
    updated_at = now()
  where id = p_product_id
    and tenant_id = v_tenant_id;

  for v_idx in 0 .. (v_serial_count - 1) loop
    v_serial := btrim((p_serials -> v_idx) #>> '{}');
    v_unit_id := gen_random_uuid();

    insert into public.product_units (
      id,
      tenant_id,
      product_id,
      serial_number,
      status,
      current_warehouse_id,
      purchase_cost,
      health_status,
      acquired_at,
      notes
    )
    values (
      v_unit_id,
      v_tenant_id,
      p_product_id,
      v_serial,
      'available_new',
      p_warehouse_id,
      v_product.avg_cost,
      'good',
      current_date,
      btrim(p_reason)
    );

    insert into public.unit_events (
      tenant_id,
      product_unit_id,
      event_type,
      occurred_at,
      warehouse_id,
      notes,
      metadata_json,
      created_by
    )
    values (
      v_tenant_id,
      v_unit_id,
      'serial_tracking_prepared',
      now(),
      p_warehouse_id,
      btrim(p_reason),
      jsonb_build_object(
        'serial_number', v_serial,
        'source', 'prepare_product_serial_tracking'
      ),
      auth.uid()
    );

    v_created_ids := array_append(v_created_ids, v_unit_id);
  end loop;

  return v_created_ids;
end;
$$;

revoke all on function public.prepare_product_serial_tracking(uuid, uuid, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.prepare_product_serial_tracking(uuid, uuid, jsonb, text)
  to authenticated;

comment on function public.prepare_product_serial_tracking(uuid, uuid, jsonb, text) is
  'Turns an existing active rental asset product into serialized tracking and creates product_units for existing available stock without changing inventory balances.';
