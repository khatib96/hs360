-- Phase 6 M10a: non-serialized lifecycle, source warehouse linkage, close-date persistence.

-- ---------------------------------------------------------------------------
-- Section A: schema
-- ---------------------------------------------------------------------------
alter table public.contract_lines
  add column if not exists source_warehouse_id uuid references public.warehouses (id);

create index if not exists idx_clines_source_warehouse
  on public.contract_lines (source_warehouse_id)
  where source_warehouse_id is not null;

comment on column public.contract_lines.source_warehouse_id is
  'Outbound warehouse for non-serialized asset lines. Required when product_unit_id is null; null for serialized assets and consumables.';

alter table public.inventory_movements
  add column if not exists contract_line_id uuid references public.contract_lines (id);

create index if not exists idx_movements_contract_line
  on public.inventory_movements (contract_line_id)
  where contract_line_id is not null;

-- ---------------------------------------------------------------------------
-- Section B: contract_lines source_warehouse enforcement
-- ---------------------------------------------------------------------------
create or replace function public.enforce_contract_line_source_warehouse()
returns trigger
language plpgsql
as $$
declare
  v_wh_tenant uuid;
begin
  if new.line_type = 'consumable'::public.contract_line_type then
    if new.source_warehouse_id is not null then
      raise exception 'validation_failed';
    end if;
    return new;
  end if;

  if new.line_type = 'asset'::public.contract_line_type then
    if new.product_unit_id is not null then
      if new.source_warehouse_id is not null then
        raise exception 'validation_failed';
      end if;
      return new;
    end if;

    if new.source_warehouse_id is null then
      raise exception 'validation_failed';
    end if;

    select w.tenant_id into v_wh_tenant
    from public.warehouses w
    where w.id = new.source_warehouse_id;

    if not found or v_wh_tenant is distinct from new.tenant_id then
      raise exception 'validation_failed';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_contract_line_source_warehouse on public.contract_lines;
create trigger trg_enforce_contract_line_source_warehouse
  before insert or update on public.contract_lines
  for each row execute function public.enforce_contract_line_source_warehouse();

-- ---------------------------------------------------------------------------
-- Section C: release_contract_assets_internal (+ non-serialized pass)
-- ---------------------------------------------------------------------------
create or replace function public.release_contract_assets_internal(
  p_tenant_id uuid,
  p_contract_id uuid,
  p_contract_number text,
  p_source_bucket text,
  p_return_condition text,
  p_movement_type public.movement_type,
  p_event_type text,
  p_occurred_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_line record;
  v_release jsonb;
  v_unit_status public.unit_status;
  v_increment_bucket text;
  v_prev_status public.unit_status;
  v_warehouse_id uuid;
  v_customer_id uuid;
  v_location_id uuid;
  v_unit_contract_id uuid;
begin
  v_release := public.map_return_condition_to_release(p_return_condition);
  v_unit_status := (v_release ->> 'unit_status')::public.unit_status;
  v_increment_bucket := v_release ->> 'increment_bucket';

  for v_line in
    select cl.product_id, cl.product_unit_id
    from public.contract_lines cl
    where cl.tenant_id = p_tenant_id
      and cl.contract_id = p_contract_id
      and cl.line_type = 'asset'::public.contract_line_type
      and cl.product_unit_id is not null
    order by cl.line_order
  loop
    select pu.status, pu.current_warehouse_id, pu.current_customer_id,
           pu.current_service_location_id, pu.current_contract_id
    into v_prev_status, v_warehouse_id, v_customer_id, v_location_id, v_unit_contract_id
    from public.product_units pu
    where pu.id = v_line.product_unit_id
      and pu.tenant_id = p_tenant_id
      and pu.product_id = v_line.product_id
    for update;

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_unit_contract_id is distinct from p_contract_id then
      raise exception 'validation_failed';
    end if;

    if p_source_bucket = 'trial' and v_prev_status <> 'trial'::public.unit_status then
      raise exception 'validation_failed';
    elsif p_source_bucket = 'rented' and v_prev_status <> 'rented'::public.unit_status then
      raise exception 'validation_failed';
    end if;

    if v_warehouse_id is null then
      raise exception 'validation_failed';
    end if;

    if p_source_bucket = 'trial' then
      update public.inventory_balances ib
      set
        qty_trial = ib.qty_trial - 1,
        qty_available = ib.qty_available + case when v_increment_bucket = 'available' then 1 else 0 end,
        qty_maintenance = ib.qty_maintenance + case when v_increment_bucket = 'maintenance' then 1 else 0 end,
        qty_damaged = ib.qty_damaged + case when v_increment_bucket = 'damaged' then 1 else 0 end,
        updated_at = now()
      where ib.tenant_id = p_tenant_id
        and ib.warehouse_id = v_warehouse_id
        and ib.product_id = v_line.product_id
        and ib.qty_trial >= 1;
    else
      update public.inventory_balances ib
      set
        qty_rented = ib.qty_rented - 1,
        qty_available = ib.qty_available + case when v_increment_bucket = 'available' then 1 else 0 end,
        qty_maintenance = ib.qty_maintenance + case when v_increment_bucket = 'maintenance' then 1 else 0 end,
        qty_damaged = ib.qty_damaged + case when v_increment_bucket = 'damaged' then 1 else 0 end,
        updated_at = now()
      where ib.tenant_id = p_tenant_id
        and ib.warehouse_id = v_warehouse_id
        and ib.product_id = v_line.product_id
        and ib.qty_rented >= 1;
    end if;

    if not found then
      raise exception 'insufficient_stock';
    end if;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, reference_table, reference_id, notes, occurred_at, created_by
    )
    values (
      p_tenant_id, p_movement_type, v_warehouse_id, v_line.product_id, v_line.product_unit_id,
      1, 'contracts', p_contract_id,
      'Contract ' || p_contract_number, p_occurred_at, auth.uid()
    );

    insert into public.unit_events (
      tenant_id, product_unit_id, event_type, occurred_at,
      warehouse_id, customer_id, service_location_id, contract_id,
      reference_table, reference_id, notes, metadata_json, created_by
    )
    values (
      p_tenant_id, v_line.product_unit_id, p_event_type, p_occurred_at,
      v_warehouse_id, v_customer_id, v_location_id, p_contract_id,
      'contracts', p_contract_id,
      'Contract ' || p_contract_number,
      jsonb_build_object(
        'previous_status', v_prev_status::text,
        'return_condition', p_return_condition,
        'contract_number', p_contract_number
      ),
      auth.uid()
    );

    update public.product_units pu
    set
      status = v_unit_status,
      current_contract_id = null,
      current_customer_id = null,
      current_service_location_id = null,
      updated_at = now()
    where pu.id = v_line.product_unit_id
      and pu.tenant_id = p_tenant_id;
  end loop;

  for v_line in
    select cl.id, cl.product_id, cl.source_warehouse_id
    from public.contract_lines cl
    where cl.tenant_id = p_tenant_id
      and cl.contract_id = p_contract_id
      and cl.line_type = 'asset'::public.contract_line_type
      and cl.product_unit_id is null
    order by cl.line_order
  loop
    if v_line.source_warehouse_id is null then
      raise exception 'manual_warehouse_resolution_required';
    end if;

    v_warehouse_id := v_line.source_warehouse_id;

    if p_source_bucket = 'trial' then
      update public.inventory_balances ib
      set
        qty_trial = ib.qty_trial - 1,
        qty_available = ib.qty_available + case when v_increment_bucket = 'available' then 1 else 0 end,
        qty_maintenance = ib.qty_maintenance + case when v_increment_bucket = 'maintenance' then 1 else 0 end,
        qty_damaged = ib.qty_damaged + case when v_increment_bucket = 'damaged' then 1 else 0 end,
        updated_at = now()
      where ib.tenant_id = p_tenant_id
        and ib.warehouse_id = v_warehouse_id
        and ib.product_id = v_line.product_id
        and ib.qty_trial >= 1;
    else
      update public.inventory_balances ib
      set
        qty_rented = ib.qty_rented - 1,
        qty_available = ib.qty_available + case when v_increment_bucket = 'available' then 1 else 0 end,
        qty_maintenance = ib.qty_maintenance + case when v_increment_bucket = 'maintenance' then 1 else 0 end,
        qty_damaged = ib.qty_damaged + case when v_increment_bucket = 'damaged' then 1 else 0 end,
        updated_at = now()
      where ib.tenant_id = p_tenant_id
        and ib.warehouse_id = v_warehouse_id
        and ib.product_id = v_line.product_id
        and ib.qty_rented >= 1;
    end if;

    if not found then
      raise exception 'insufficient_stock';
    end if;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, reference_table, reference_id, contract_line_id, notes, occurred_at, created_by
    )
    values (
      p_tenant_id, p_movement_type, v_warehouse_id, v_line.product_id, null,
      1, 'contracts', p_contract_id, v_line.id,
      'Contract ' || p_contract_number, p_occurred_at, auth.uid()
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section D: copy_trial_lines_to_rental_internal (+ source_warehouse_id)
-- ---------------------------------------------------------------------------
create or replace function public.copy_trial_lines_to_rental_internal(
  p_tenant_id uuid,
  p_trial_id uuid,
  p_rental_id uuid,
  p_rental_start date,
  p_pricing jsonb,
  p_asset_count int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_line record;
  v_line_id uuid;
  v_pricing_assets jsonb := coalesce(p_pricing -> 'asset_lines', '[]'::jsonb);
  v_pricing_consumables jsonb := coalesce(p_pricing -> 'consumable_lines', '[]'::jsonb);
  v_asset_idx int := 0;
  v_consumable_idx int := 0;
  v_pricing_line jsonb;
  v_source_cost numeric(15, 3);
  v_line_monthly_cost numeric(15, 3);
  v_snapshot_refill_cost numeric(15, 3);
begin
  for v_line in
    select *
    from public.contract_lines cl
    where cl.tenant_id = p_tenant_id
      and cl.contract_id = p_trial_id
      and cl.line_type = 'asset'::public.contract_line_type
    order by cl.line_order
  loop
    v_asset_idx := v_asset_idx + 1;
    v_pricing_line := v_pricing_assets -> (v_asset_idx - 1);
    if v_pricing_line is null then
      raise exception 'validation_failed';
    end if;

    v_source_cost := (v_pricing_line ->> 'source_unit_cost')::numeric(15, 3);
    v_line_monthly_cost := (v_pricing_line ->> 'monthly_cost')::numeric(15, 3);

    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id, product_unit_id,
      source_warehouse_id,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, p_tenant_id, p_rental_id, 'asset'::public.contract_line_type,
      v_line.product_id, v_line.product_unit_id,
      v_line.source_warehouse_id,
      v_source_cost, v_line_monthly_cost,
      (v_pricing_line ->> 'cost_basis')::public.contract_line_cost_basis,
      v_line.line_order
    );
  end loop;

  for v_line in
    select *
    from public.contract_lines cl
    where cl.tenant_id = p_tenant_id
      and cl.contract_id = p_trial_id
      and cl.line_type = 'consumable'::public.contract_line_type
    order by cl.line_order
  loop
    v_consumable_idx := v_consumable_idx + 1;
    v_pricing_line := v_pricing_consumables -> (v_consumable_idx - 1);
    if v_pricing_line is null then
      raise exception 'validation_failed';
    end if;

    v_source_cost := (v_pricing_line ->> 'source_unit_cost')::numeric(15, 3);
    v_line_monthly_cost := (v_pricing_line ->> 'monthly_cost')::numeric(15, 3);
    v_snapshot_refill_cost := public.round_money(
      v_line.qty_per_refill * v_source_cost,
      public.resolve_tenant_money_precision(p_tenant_id)
    );

    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id,
      qty_per_refill, refill_frequency_months,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, p_tenant_id, p_rental_id, 'consumable'::public.contract_line_type,
      v_line.product_id, v_line.qty_per_refill, v_line.refill_frequency_months,
      v_source_cost, v_line_monthly_cost,
      (v_pricing_line ->> 'cost_basis')::public.contract_line_cost_basis,
      p_asset_count + v_consumable_idx
    );

    insert into public.contract_oil_changes (
      tenant_id, contract_id, contract_line_id,
      effective_from, effective_to,
      oil_product_id, qty_per_refill,
      snapshot_unit_cost, snapshot_refill_cost
    )
    values (
      p_tenant_id, p_rental_id, v_line_id,
      p_rental_start, null,
      v_line.product_id, v_line.qty_per_refill,
      v_source_cost, v_snapshot_refill_cost
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section E: convert_trial_to_rental (+ non-serialized asset lines)
-- ---------------------------------------------------------------------------
create or replace function public.convert_trial_to_rental(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_trial public.contracts%rowtype;
  v_settings public.tenant_settings%rowtype;
  v_rental_id uuid := gen_random_uuid();
  v_rental_number text;
  v_start_date date := current_date;
  v_end_date date;
  v_billing_day int;
  v_refill_day int;
  v_monthly numeric(15, 3);
  v_request_override boolean;
  v_override_reason text;
  v_pricing_payload jsonb;
  v_pricing jsonb;
  v_asset_lines jsonb := '[]'::jsonb;
  v_consumable_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_asset_count int := 0;
  v_min_overridden boolean := false;
  v_line_row record;
  v_prev_status public.unit_status;
  v_warehouse_id uuid;
  v_unit_contract_id uuid;
  v_rental_line_id uuid;
begin
  perform public.allow_contract_write();

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('contracts.convert_trial') then
    raise exception 'permission_denied';
  end if;
  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_convert_trial_payload(p_data);
  v_hash := public.compute_convert_trial_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_contract_lifecycle_idempotency(
    'convert_trial_to_rental',
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  select *
  into v_trial
  from public.contracts c
  where c.tenant_id = v_tenant_id
    and c.id = (v_normalized ->> 'trial_contract_id')::uuid
  for update;

  if not found
    or v_trial.type <> 'trial'::public.contract_type
    or v_trial.status <> 'active'::public.contract_status
    or v_trial.converted_to_contract_id is not null
    or v_trial.returned_at is not null
    or v_trial.closed_at is not null then
    raise exception 'validation_failed';
  end if;

  for v_line_row in
    select cl.product_id, cl.product_unit_id, cl.source_warehouse_id, cl.line_order
    from public.contract_lines cl
    where cl.tenant_id = v_tenant_id
      and cl.contract_id = v_trial.id
      and cl.line_type = 'asset'::public.contract_line_type
    order by cl.line_order
  loop
    v_asset_count := v_asset_count + 1;

    if v_line_row.product_unit_id is not null then
      v_asset_lines := v_asset_lines || jsonb_build_array(
        jsonb_build_object(
          'product_id', v_line_row.product_id,
          'product_unit_id', v_line_row.product_unit_id
        )
      );

      select pu.status, pu.current_warehouse_id, pu.current_contract_id
      into v_prev_status, v_warehouse_id, v_unit_contract_id
      from public.product_units pu
      where pu.id = v_line_row.product_unit_id
        and pu.tenant_id = v_tenant_id
        and pu.product_id = v_line_row.product_id
      for update;

      if not found
        or v_prev_status <> 'trial'::public.unit_status
        or v_unit_contract_id is distinct from v_trial.id
        or v_warehouse_id is null then
        raise exception 'validation_failed';
      end if;
    else
      if v_line_row.source_warehouse_id is null then
        raise exception 'manual_warehouse_resolution_required';
      end if;

      v_asset_lines := v_asset_lines || jsonb_build_array(
        jsonb_build_object(
          'product_id', v_line_row.product_id
        )
      );
    end if;
  end loop;

  if v_asset_count < 1 then
    raise exception 'validation_failed';
  end if;

  for v_line_row in
    select cl.product_id, cl.qty_per_refill, cl.refill_frequency_months
    from public.contract_lines cl
    where cl.tenant_id = v_tenant_id
      and cl.contract_id = v_trial.id
      and cl.line_type = 'consumable'::public.contract_line_type
    order by cl.line_order
  loop
    v_consumable_lines := v_consumable_lines || jsonb_build_array(
      jsonb_build_object(
        'product_id', v_line_row.product_id,
        'qty_per_refill', v_line_row.qty_per_refill,
        'refill_frequency_months', coalesce(v_line_row.refill_frequency_months, 1)
      )
    );
  end loop;

  v_monthly := (v_normalized ->> 'monthly_rental_value')::numeric(15, 3);
  v_request_override := coalesce((v_normalized ->> 'request_override')::boolean, false);
  v_override_reason := nullif(btrim(v_normalized ->> 'override_reason'), '');

  select * into v_settings
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;
  if not found then
    raise exception 'validation_failed';
  end if;

  v_end_date := coalesce(
    nullif(v_normalized ->> 'end_date', '')::date,
    (v_start_date + (coalesce(v_settings.default_contract_term_months, 12)::text || ' months')::interval)::date
  );
  if v_normalized ? 'end_date' and v_end_date < v_start_date then
    raise exception 'validation_failed';
  end if;
  v_billing_day := coalesce(nullif(v_normalized ->> 'billing_day', '')::int, v_trial.billing_day);
  v_refill_day := coalesce(nullif(v_normalized ->> 'refill_day', '')::int, v_trial.refill_day);

  v_pricing_payload := jsonb_build_object(
    'monthly_rental_value', v_monthly,
    'asset_lines', v_asset_lines,
    'consumable_lines', v_consumable_lines,
    'request_override', v_request_override,
    'override_reason', v_override_reason
  );
  v_pricing := public.compute_contract_pricing_internal(v_tenant_id, v_pricing_payload);
  if coalesce((v_pricing ->> 'passes_min_profit')::boolean, false) is not true then
    raise exception 'below_min_profit';
  end if;
  v_min_overridden := coalesce((v_pricing ->> 'min_profit_overridden')::boolean, false);
  if v_min_overridden and v_override_reason is null then
    raise exception 'validation_failed';
  end if;

  v_rental_number := public.next_document_number('CON');
  insert into public.contracts (
    id, tenant_id, contract_number, type, status,
    customer_id, service_location_id,
    contact_person_name, contact_phone, contact_email,
    start_date, end_date,
    billing_day, refill_day, monthly_rental_value,
    snapshot_device_monthly_cost, snapshot_oil_monthly_cost,
    snapshot_total_monthly_cost, snapshot_monthly_profit, snapshot_min_profit_threshold,
    snapshot_asset_cost_basis, snapshot_consumable_cost_basis, snapshot_asset_lifespan_months,
    location_name, location_country, location_governorate, location_area,
    location_lat, location_lng, location_address, location_google_maps_url,
    min_profit_overridden, override_approved_by, override_approved_at, override_reason,
    converted_from_contract_id,
    notes, created_by
  )
  values (
    v_rental_id, v_tenant_id, v_rental_number, 'rental'::public.contract_type, 'active'::public.contract_status,
    v_trial.customer_id, v_trial.service_location_id,
    v_trial.contact_person_name, v_trial.contact_phone, v_trial.contact_email,
    v_start_date, v_end_date,
    v_billing_day, v_refill_day, v_monthly,
    coalesce((v_pricing ->> 'asset_monthly_cost')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'consumable_monthly_cost')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'total_monthly_cost')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'expected_monthly_profit')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'min_monthly_profit_threshold')::numeric(15, 3), 0),
    (v_pricing ->> 'asset_cost_basis')::public.rental_asset_cost_basis,
    (v_pricing ->> 'consumable_cost_basis')::public.rental_consumable_cost_basis,
    nullif(v_pricing ->> 'asset_lifespan_months', '')::int,
    v_trial.location_name, v_trial.location_country, v_trial.location_governorate, v_trial.location_area,
    v_trial.location_lat, v_trial.location_lng, v_trial.location_address, v_trial.location_google_maps_url,
    case when v_min_overridden then true else false end,
    case when v_min_overridden then auth.uid() end,
    case when v_min_overridden then now() end,
    case when v_min_overridden then v_override_reason end,
    v_trial.id,
    v_trial.notes, auth.uid()
  );

  perform public.copy_trial_lines_to_rental_internal(
    v_tenant_id,
    v_trial.id,
    v_rental_id,
    v_start_date,
    v_pricing,
    v_asset_count
  );

  for v_line_row in
    select cl.product_id, cl.product_unit_id
    from public.contract_lines cl
    where cl.tenant_id = v_tenant_id
      and cl.contract_id = v_trial.id
      and cl.line_type = 'asset'::public.contract_line_type
      and cl.product_unit_id is not null
    order by cl.line_order
  loop
    select pu.status, pu.current_warehouse_id, pu.current_contract_id
    into v_prev_status, v_warehouse_id, v_unit_contract_id
    from public.product_units pu
    where pu.id = v_line_row.product_unit_id
      and pu.tenant_id = v_tenant_id
      and pu.product_id = v_line_row.product_id
    for update;

    if not found
      or v_prev_status <> 'trial'::public.unit_status
      or v_unit_contract_id is distinct from v_trial.id
      or v_warehouse_id is null then
      raise exception 'validation_failed';
    end if;

    update public.inventory_balances ib
    set
      qty_trial = ib.qty_trial - 1,
      qty_rented = ib.qty_rented + 1,
      updated_at = now()
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_warehouse_id
      and ib.product_id = v_line_row.product_id
      and ib.qty_trial >= 1;
    if not found then
      raise exception 'insufficient_stock';
    end if;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, reference_table, reference_id, notes, created_by
    )
    values (
      v_tenant_id, 'trial_to_rental'::public.movement_type, v_warehouse_id, v_line_row.product_id, v_line_row.product_unit_id,
      1, 'contracts', v_rental_id, 'Trial conversion ' || v_rental_number, auth.uid()
    );

    insert into public.unit_events (
      tenant_id, product_unit_id, event_type, occurred_at,
      warehouse_id, customer_id, service_location_id, contract_id,
      reference_table, reference_id, notes, metadata_json, created_by
    )
    values (
      v_tenant_id, v_line_row.product_unit_id, 'trial_converted', now(),
      v_warehouse_id, v_trial.customer_id, v_trial.service_location_id, v_rental_id,
      'contracts', v_rental_id, 'Contract ' || v_rental_number,
      jsonb_build_object('previous_status', 'trial', 'contract_number', v_rental_number),
      auth.uid()
    );

    update public.product_units pu
    set
      status = 'rented'::public.unit_status,
      current_contract_id = v_rental_id,
      current_customer_id = v_trial.customer_id,
      current_service_location_id = v_trial.service_location_id,
      updated_at = now()
    where pu.id = v_line_row.product_unit_id
      and pu.tenant_id = v_tenant_id;
  end loop;

  for v_line_row in
    select cl.id, cl.product_id, cl.source_warehouse_id, cl.line_order
    from public.contract_lines cl
    where cl.tenant_id = v_tenant_id
      and cl.contract_id = v_trial.id
      and cl.line_type = 'asset'::public.contract_line_type
      and cl.product_unit_id is null
    order by cl.line_order
  loop
    if v_line_row.source_warehouse_id is null then
      raise exception 'manual_warehouse_resolution_required';
    end if;

    v_warehouse_id := v_line_row.source_warehouse_id;

    update public.inventory_balances ib
    set
      qty_trial = ib.qty_trial - 1,
      qty_rented = ib.qty_rented + 1,
      updated_at = now()
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_warehouse_id
      and ib.product_id = v_line_row.product_id
      and ib.qty_trial >= 1;
    if not found then
      raise exception 'insufficient_stock';
    end if;

    select cl.id
    into v_rental_line_id
    from public.contract_lines cl
    where cl.tenant_id = v_tenant_id
      and cl.contract_id = v_rental_id
      and cl.line_type = 'asset'::public.contract_line_type
      and cl.product_id = v_line_row.product_id
      and cl.product_unit_id is null
      and cl.line_order = v_line_row.line_order;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, reference_table, reference_id, contract_line_id, notes, created_by
    )
    values (
      v_tenant_id, 'trial_to_rental'::public.movement_type, v_warehouse_id, v_line_row.product_id, null,
      1, 'contracts', v_rental_id, v_rental_line_id,
      'Trial conversion ' || v_rental_number, auth.uid()
    );
  end loop;

  update public.contracts c
  set
    status = 'completed'::public.contract_status,
    trial_outcome = 'converted',
    converted_to_contract_id = v_rental_id,
    closed_at = now(),
    closed_by = auth.uid(),
    updated_at = now(),
    updated_by = auth.uid()
  where c.id = v_trial.id
    and c.tenant_id = v_tenant_id;

  perform public.record_contract_lifecycle_operation(
    'convert_trial_to_rental',
    p_idempotency_key,
    v_hash,
    v_trial.id,
    v_rental_id
  );

  return v_rental_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section F: close_contract (business-effective close date)
-- ---------------------------------------------------------------------------
create or replace function public.close_contract(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_contract public.contracts%rowtype;
  v_close_date date;
  v_effective_at timestamptz;
  v_new_status public.contract_status;
begin
  perform public.allow_contract_write();

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('contracts.close') then
    raise exception 'permission_denied';
  end if;
  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_close_contract_payload(p_data);
  v_hash := public.compute_close_contract_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_contract_lifecycle_idempotency(
    'close_contract',
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  select *
  into v_contract
  from public.contracts c
  where c.tenant_id = v_tenant_id
    and c.id = (v_normalized ->> 'contract_id')::uuid
  for update;

  if not found
    or v_contract.type <> 'rental'::public.contract_type
    or v_contract.status not in ('active'::public.contract_status, 'suspended'::public.contract_status)
    or v_contract.closed_at is not null then
    raise exception 'validation_failed';
  end if;

  v_close_date := coalesce(nullif(v_normalized ->> 'close_date', '')::date, current_date);
  if v_close_date < v_contract.start_date then
    raise exception 'validation_failed';
  end if;
  v_effective_at := (v_close_date::text || ' 12:00:00+00')::timestamptz;
  v_new_status := case
    when (v_normalized ->> 'closure_type') = 'normal' then 'completed'::public.contract_status
    else 'terminated_early'::public.contract_status
  end;

  perform public.release_contract_assets_internal(
    v_tenant_id,
    v_contract.id,
    v_contract.contract_number,
    'rented',
    v_normalized ->> 'return_condition',
    'rental_return'::public.movement_type,
    'contract_closed',
    v_effective_at
  );

  update public.contracts c
  set
    status = v_new_status,
    returned_at = v_effective_at,
    returned_by = auth.uid(),
    return_condition = v_normalized ->> 'return_condition',
    return_reason = v_normalized ->> 'close_reason',
    closed_at = v_effective_at,
    closed_by = auth.uid(),
    closure_reason = v_normalized ->> 'close_reason',
    updated_at = now(),
    updated_by = auth.uid()
  where c.id = v_contract.id
    and c.tenant_id = v_tenant_id;

  update public.calendar_events ce
  set status = 'cancelled'::public.calendar_event_status
  where ce.tenant_id = v_tenant_id
    and ce.contract_id = v_contract.id
    and ce.status = 'pending'::public.calendar_event_status
    and ce.scheduled_date > v_close_date;

  perform public.record_contract_lifecycle_operation(
    'close_contract',
    p_idempotency_key,
    v_hash,
    v_contract.id,
    v_contract.id
  );

  return v_contract.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section G: preview_contract_profit (+ convert_trial permission)
-- ---------------------------------------------------------------------------
create or replace function public.preview_contract_profit(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_result jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not (
    public.user_has_permission('contracts.create')
    or public.user_has_permission('contracts.convert_trial')
  ) then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'asset_cost_basis'
    or p_data ? 'consumable_cost_basis'
    or p_data ? 'asset_lifespan_months' then
    raise exception 'validation_failed';
  end if;

  v_result := public.compute_contract_pricing_internal(v_tenant_id, p_data);
  return public.mask_contract_pricing_preview(v_result);
end;
$$;

-- ---------------------------------------------------------------------------
-- Section H: create_contract_internal (+ source_warehouse_id, contract_line_id)
-- ---------------------------------------------------------------------------
do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.create_contract_internal(public.contract_type, jsonb, uuid)'::regprocedure
  ) into v_sql;

  v_sql := replace(
    v_sql,
$old$
    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id, product_unit_id,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, v_tenant_id, v_contract_id, 'asset'::public.contract_line_type,
      v_product_id, v_product_unit_id,
      v_source_cost, v_line_monthly_cost,
      v_cost_basis::public.contract_line_cost_basis,
      v_line_idx
    );

    if v_product_unit_id is not null then
      select pu.status, pu.current_warehouse_id
      into v_prev_status, v_unit_warehouse_id
      from public.product_units pu
      where pu.id = v_product_unit_id
        and pu.tenant_id = v_tenant_id
      for update;
    else
      select ib.warehouse_id
      into v_unit_warehouse_id
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.product_id = v_product_id
        and ib.qty_available >= 1
      order by ib.updated_at desc, ib.id
      limit 1
      for update;
    end if;

    if v_unit_warehouse_id is null then
      raise exception 'insufficient_stock';
    end if;
$old$,
$new$
    if v_product_unit_id is not null then
      select pu.status, pu.current_warehouse_id
      into v_prev_status, v_unit_warehouse_id
      from public.product_units pu
      where pu.id = v_product_unit_id
        and pu.tenant_id = v_tenant_id
      for update;
    else
      select ib.warehouse_id
      into v_unit_warehouse_id
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.product_id = v_product_id
        and ib.qty_available >= 1
      order by ib.updated_at desc, ib.id
      limit 1
      for update;
    end if;

    if v_unit_warehouse_id is null then
      raise exception 'insufficient_stock';
    end if;

    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id, product_unit_id,
      source_warehouse_id,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, v_tenant_id, v_contract_id, 'asset'::public.contract_line_type,
      v_product_id, v_product_unit_id,
      case when v_product_unit_id is null then v_unit_warehouse_id else null end,
      v_source_cost, v_line_monthly_cost,
      v_cost_basis::public.contract_line_cost_basis,
      v_line_idx
    );
$new$
  );

  v_sql := replace(
    v_sql,
$old$
    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, reference_table, reference_id, notes, created_by
    )
    values (
      v_tenant_id, v_movement_type, v_unit_warehouse_id, v_product_id, v_product_unit_id,
      1, 'contracts', v_contract_id,
      'Contract ' || v_contract_number, auth.uid()
    );
$old$,
$new$
    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, reference_table, reference_id, contract_line_id, notes, created_by
    )
    values (
      v_tenant_id, v_movement_type, v_unit_warehouse_id, v_product_id, v_product_unit_id,
      1, 'contracts', v_contract_id, v_line_id,
      'Contract ' || v_contract_number, auth.uid()
    );
$new$
  );

  execute v_sql;
end $$;

-- ---------------------------------------------------------------------------
-- Section I: historical backfill (unambiguous outbound warehouse only)
-- ---------------------------------------------------------------------------
update public.contract_lines cl
set source_warehouse_id = bw.warehouse_id
from (
  select
    cl2.id as contract_line_id,
    min(im.warehouse_id::text)::uuid as warehouse_id
  from public.contract_lines cl2
  inner join public.inventory_movements im
    on im.tenant_id = cl2.tenant_id
   and im.reference_table = 'contracts'
   and im.reference_id = cl2.contract_id
   and im.product_id = cl2.product_id
   and im.product_unit_id is null
   and im.movement_type in (
     'trial_out'::public.movement_type,
     'rental_out'::public.movement_type,
     'trial_to_rental'::public.movement_type
   )
  where cl2.line_type = 'asset'::public.contract_line_type
    and cl2.product_unit_id is null
    and cl2.source_warehouse_id is null
  group by cl2.id, cl2.contract_id, cl2.product_id
  having count(distinct im.warehouse_id) = 1
) bw
where cl.id = bw.contract_line_id;
