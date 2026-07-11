-- Phase 6 M10b: schedule consumable (oil) change RPC.
-- Adds lifecycle operation type, single-open-tail guard, scheduling RPC, and detail read enrichment.

alter table public.contract_lifecycle_operations
  drop constraint if exists chk_contract_lifecycle_operations_type;

alter table public.contract_lifecycle_operations
  add constraint chk_contract_lifecycle_operations_type check (
    operation_type in (
      'convert_trial_to_rental',
      'extend_trial',
      'return_trial',
      'close_contract',
      'schedule_consumable_change'
    )
  );

create or replace function public.enforce_contract_oil_changes_single_open_tail()
returns trigger
language plpgsql
as $$
begin
  if new.effective_to is null then
    if exists (
      select 1
      from public.contract_oil_changes coc
      where coc.tenant_id = new.tenant_id
        and coc.contract_line_id = new.contract_line_id
        and coc.effective_to is null
        and (tg_op = 'INSERT' or coc.id <> new.id)
    ) then
      raise exception 'validation_failed';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_contract_oil_changes_single_open_tail on public.contract_oil_changes;
create trigger trg_contract_oil_changes_single_open_tail
  before insert or update on public.contract_oil_changes
  for each row execute function public.enforce_contract_oil_changes_single_open_tail();

create or replace function public.schedule_contract_consumable_change(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_tenant_id uuid;
  v_allowed text[] := array[
    'contract_id', 'contract_line_id', 'new_product_id', 'effective_date', 'qty_per_refill', 'reason'
  ];
  v_key text;
  v_contract_id uuid;
  v_line_id uuid;
  v_new_product_id uuid;
  v_effective_date date;
  v_qty_per_refill numeric(15, 3);
  v_reason text;
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_contract public.contracts%rowtype;
  v_line public.contract_lines%rowtype;
  v_current_change public.contract_oil_changes%rowtype;
  v_new_product public.products%rowtype;
  v_future_exists boolean;
  v_settings jsonb;
  v_consumable_basis public.rental_consumable_cost_basis;
  v_source_cost numeric(15, 3);
  v_snapshot_refill_cost numeric(15, 3);
begin
  perform public.allow_contract_write();

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('contracts.oil_change') then
    raise exception 'permission_denied';
  end if;
  if p_idempotency_key is null or p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if not (v_key = any (v_allowed)) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (
    p_data ? 'contract_id'
    and p_data ? 'contract_line_id'
    and p_data ? 'new_product_id'
    and p_data ? 'effective_date'
    and p_data ? 'qty_per_refill'
    and p_data ? 'reason'
  ) then
    raise exception 'validation_failed';
  end if;

  begin
    v_contract_id := (p_data ->> 'contract_id')::uuid;
    v_line_id := (p_data ->> 'contract_line_id')::uuid;
    v_new_product_id := (p_data ->> 'new_product_id')::uuid;
    v_effective_date := (p_data ->> 'effective_date')::date;
    v_qty_per_refill := (p_data ->> 'qty_per_refill')::numeric(15, 3);
  exception
    when others then
      raise exception 'validation_failed';
  end;

  v_reason := nullif(btrim(p_data ->> 'reason'), '');
  if v_reason is null or v_qty_per_refill <= 0 then
    raise exception 'validation_failed';
  end if;

  v_normalized := jsonb_build_object(
    'contract_id', v_contract_id,
    'contract_line_id', v_line_id,
    'new_product_id', v_new_product_id,
    'effective_date', v_effective_date,
    'qty_per_refill', v_qty_per_refill,
    'reason', v_reason
  );
  v_hash := encode(digest(convert_to(v_normalized::text, 'UTF8'), 'sha256'), 'hex');

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_contract_lifecycle_idempotency(
    'schedule_consumable_change',
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
    and c.id = v_contract_id
  for update;

  if not found
    or v_contract.type <> 'rental'::public.contract_type
    or v_contract.status not in ('active'::public.contract_status, 'suspended'::public.contract_status)
    or v_contract.closed_at is not null then
    raise exception 'validation_failed';
  end if;

  select *
  into v_line
  from public.contract_lines cl
  where cl.tenant_id = v_tenant_id
    and cl.id = v_line_id
    and cl.contract_id = v_contract.id
    and cl.line_type = 'consumable'::public.contract_line_type
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  perform 1
  from public.contract_oil_changes coc
  where coc.tenant_id = v_tenant_id
    and coc.contract_line_id = v_line.id
  for update;

  select *
  into v_current_change
  from public.contract_oil_changes coc
  where coc.tenant_id = v_tenant_id
    and coc.contract_line_id = v_line.id
    and coc.effective_from <= current_date
    and (coc.effective_to is null or coc.effective_to >= current_date)
  order by coc.effective_from desc, coc.created_at desc, coc.id desc
  limit 1;

  if v_current_change.id is null then
    raise exception 'validation_failed';
  end if;

  select exists (
    select 1
    from public.contract_oil_changes coc
    where coc.tenant_id = v_tenant_id
      and coc.contract_line_id = v_line.id
      and coc.effective_from > current_date
  )
  into v_future_exists;

  if v_future_exists then
    raise exception 'consumable_schedule_conflict';
  end if;

  if v_effective_date < current_date
    or v_effective_date < v_contract.start_date then
    raise exception 'validation_failed';
  end if;
  if v_effective_date = current_date
    and v_effective_date <= v_current_change.effective_from then
    raise exception 'validation_failed';
  end if;

  select *
  into v_new_product
  from public.products p
  where p.tenant_id = v_tenant_id
    and p.id = v_new_product_id;

  if not found
    or v_new_product.product_type is distinct from 'consumable_rental'::public.product_type then
    raise exception 'validation_failed';
  end if;

  v_settings := public.resolve_tenant_contract_settings(v_tenant_id);
  v_consumable_basis := (v_settings ->> 'rental_consumable_cost_basis')::public.rental_consumable_cost_basis;
  v_source_cost := public.resolve_rental_consumable_unit_cost(v_tenant_id, v_new_product.id, v_consumable_basis);
  v_snapshot_refill_cost := public.round_money(
    v_qty_per_refill * v_source_cost,
    public.resolve_tenant_money_precision(v_tenant_id)
  );

  update public.contract_oil_changes coc
  set effective_to = v_effective_date - 1
  where coc.id = v_current_change.id
    and coc.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  insert into public.contract_oil_changes (
    tenant_id,
    contract_id,
    contract_line_id,
    effective_from,
    effective_to,
    oil_product_id,
    qty_per_refill,
    snapshot_unit_cost,
    snapshot_refill_cost,
    changed_by_agent_id,
    reason
  )
  values (
    v_tenant_id,
    v_contract.id,
    v_line.id,
    v_effective_date,
    null,
    v_new_product.id,
    v_qty_per_refill,
    v_source_cost,
    v_snapshot_refill_cost,
    public.current_employee_id(),
    v_reason
  );

  perform public.record_contract_lifecycle_operation(
    'schedule_consumable_change',
    p_idempotency_key,
    v_hash,
    v_contract.id,
    v_contract.id
  );

  return v_contract.id;
end;
$$;

create or replace function public.build_contract_detail_json(p_contract_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_contract public.contracts%rowtype;
  v_customer public.customers%rowtype;
  v_location_name text;
  v_asset_lines jsonb;
  v_consumable_lines jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  select * into v_contract
  from public.contracts c
  where c.id = p_contract_id
    and c.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  select * into v_customer
  from public.customers cu
  where cu.id = v_contract.customer_id
    and cu.tenant_id = v_tenant_id;

  select coalesce(nullif(btrim(csl.name), ''), nullif(btrim(v_contract.location_name), ''))
  into v_location_name
  from public.customer_service_locations csl
  where csl.id = v_contract.service_location_id
    and csl.tenant_id = v_tenant_id
  limit 1;

  if v_location_name is null then
    v_location_name := nullif(btrim(v_contract.location_name), '');
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cl.id,
      'product_id', cl.product_id,
      'product_unit_id', cl.product_unit_id,
      'line_order', cl.line_order,
      'snapshot_unit_cost', cl.snapshot_unit_cost,
      'snapshot_monthly_cost', cl.snapshot_monthly_cost,
      'serial_number', pu.serial_number,
      'product_sku', p.sku,
      'product_name_ar', p.name_ar,
      'product_name_en', p.name_en,
      'product_group_name_ar', pg.name_ar,
      'product_group_name_en', pg.name_en
    )
    order by cl.line_order, cl.id
  ), '[]'::jsonb)
  into v_asset_lines
  from public.contract_lines cl
  join public.products p
    on p.id = cl.product_id
    and p.tenant_id = cl.tenant_id
  join public.product_groups pg
    on pg.id = p.group_id
    and pg.tenant_id = p.tenant_id
  left join public.product_units pu
    on pu.id = cl.product_unit_id
    and pu.tenant_id = cl.tenant_id
  where cl.contract_id = p_contract_id
    and cl.tenant_id = v_tenant_id
    and cl.line_type = 'asset';

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cl.id,
      'product_id', cl.product_id,
      'line_order', cl.line_order,
      'qty_per_refill', cl.qty_per_refill,
      'refill_frequency_months', cl.refill_frequency_months,
      'snapshot_unit_cost', cl.snapshot_unit_cost,
      'snapshot_monthly_cost', cl.snapshot_monthly_cost,
      'product_sku', p.sku,
      'product_name_ar', p.name_ar,
      'product_name_en', p.name_en,
      'product_group_name_ar', pg.name_ar,
      'product_group_name_en', pg.name_en,
      'current_oil_product_id', cur.oil_product_id,
      'current_oil_product_name_ar', cur.product_name_ar,
      'current_oil_product_name_en', cur.product_name_en,
      'current_qty_per_refill', cur.qty_per_refill,
      'current_effective_from', cur.effective_from,
      'scheduled_oil_product_id', sch.oil_product_id,
      'scheduled_oil_product_name_ar', sch.product_name_ar,
      'scheduled_oil_product_name_en', sch.product_name_en,
      'scheduled_qty_per_refill', sch.qty_per_refill,
      'scheduled_effective_from', sch.effective_from
    )
    order by cl.line_order, cl.id
  ), '[]'::jsonb)
  into v_consumable_lines
  from public.contract_lines cl
  join public.products p
    on p.id = cl.product_id
    and p.tenant_id = cl.tenant_id
  join public.product_groups pg
    on pg.id = p.group_id
    and pg.tenant_id = p.tenant_id
  left join lateral (
    select coc.oil_product_id, coc.qty_per_refill, coc.effective_from, op.name_ar as product_name_ar, op.name_en as product_name_en
    from public.contract_oil_changes coc
    join public.products op on op.id = coc.oil_product_id and op.tenant_id = coc.tenant_id
    where coc.tenant_id = cl.tenant_id
      and coc.contract_line_id = cl.id
      and coc.effective_from <= current_date
      and (coc.effective_to is null or coc.effective_to >= current_date)
    order by coc.effective_from desc, coc.created_at desc, coc.id desc
    limit 1
  ) cur on true
  left join lateral (
    select coc.oil_product_id, coc.qty_per_refill, coc.effective_from, op.name_ar as product_name_ar, op.name_en as product_name_en
    from public.contract_oil_changes coc
    join public.products op on op.id = coc.oil_product_id and op.tenant_id = coc.tenant_id
    where coc.tenant_id = cl.tenant_id
      and coc.contract_line_id = cl.id
      and coc.effective_from > current_date
    order by coc.effective_from asc, coc.created_at asc, coc.id asc
    limit 1
  ) sch on true
  where cl.contract_id = p_contract_id
    and cl.tenant_id = v_tenant_id
    and cl.line_type = 'consumable';

  return jsonb_build_object(
    'id', v_contract.id,
    'contract_number', v_contract.contract_number,
    'type', v_contract.type,
    'status', v_contract.status,
    'customer_id', v_contract.customer_id,
    'customer_name_ar', v_customer.name_ar,
    'customer_name_en', v_customer.name_en,
    'service_location_id', v_contract.service_location_id,
    'service_location_name', v_location_name,
    'start_date', v_contract.start_date,
    'end_date', v_contract.end_date,
    'trial_days', v_contract.trial_days,
    'trial_end_date', v_contract.trial_end_date,
    'trial_outcome', v_contract.trial_outcome,
    'billing_day', v_contract.billing_day,
    'refill_day', v_contract.refill_day,
    'monthly_rental_value', v_contract.monthly_rental_value,
    'total_contract_value', v_contract.total_contract_value,
    'snapshot_device_monthly_cost', v_contract.snapshot_device_monthly_cost,
    'snapshot_oil_monthly_cost', v_contract.snapshot_oil_monthly_cost,
    'snapshot_total_monthly_cost', v_contract.snapshot_total_monthly_cost,
    'snapshot_monthly_profit', v_contract.snapshot_monthly_profit,
    'snapshot_min_profit_threshold', v_contract.snapshot_min_profit_threshold,
    'snapshot_asset_cost_basis', v_contract.snapshot_asset_cost_basis,
    'snapshot_consumable_cost_basis', v_contract.snapshot_consumable_cost_basis,
    'snapshot_asset_lifespan_months', v_contract.snapshot_asset_lifespan_months,
    'min_profit_overridden', v_contract.min_profit_overridden,
    'override_reason', v_contract.override_reason,
    'converted_from_contract_id', v_contract.converted_from_contract_id,
    'converted_to_contract_id', v_contract.converted_to_contract_id,
    'renewed_from_contract_id', v_contract.renewed_from_contract_id,
    'renewed_to_contract_id', v_contract.renewed_to_contract_id,
    'extension_reason', v_contract.extension_reason,
    'returned_at', v_contract.returned_at,
    'returned_by', v_contract.returned_by,
    'return_reason', v_contract.return_reason,
    'return_condition', v_contract.return_condition,
    'closed_at', v_contract.closed_at,
    'closed_by', v_contract.closed_by,
    'closure_reason', v_contract.closure_reason,
    'notes', v_contract.notes,
    'asset_lines', v_asset_lines,
    'consumable_lines', v_consumable_lines
  );
end;
$$;

grant execute on function public.schedule_contract_consumable_change(jsonb, uuid) to authenticated;

revoke all on function public.enforce_contract_oil_changes_single_open_tail()
  from public, anon, authenticated;

-- Preserve non-sensitive consumable schedule fields through read masking.
create or replace function public.mask_contract_read_json(p_json jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_has_device boolean;
  v_has_oil boolean;
  v_has_total boolean;
  v_has_profit boolean;
  v_asset_lines jsonb := '[]'::jsonb;
  v_consumable_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_masked_line jsonb;
begin
  v_has_device := public.user_has_permission('contracts.field.snapshot_device_cost');
  v_has_oil := public.user_has_permission('contracts.field.snapshot_oil_cost');
  v_has_total := public.user_has_permission('contracts.field.snapshot_total_cost');
  v_has_profit := public.user_has_permission('contracts.field.snapshot_profit');

  for v_line in
    select value
    from jsonb_array_elements(coalesce(p_json -> 'asset_lines', '[]'::jsonb))
  loop
    v_masked_line := jsonb_build_object(
      'id', v_line -> 'id',
      'product_id', v_line -> 'product_id',
      'product_unit_id', v_line -> 'product_unit_id',
      'line_order', v_line -> 'line_order',
      'serial_number', v_line -> 'serial_number',
      'product_sku', v_line -> 'product_sku',
      'product_name_ar', v_line -> 'product_name_ar',
      'product_name_en', v_line -> 'product_name_en',
      'product_group_name_ar', v_line -> 'product_group_name_ar',
      'product_group_name_en', v_line -> 'product_group_name_en'
    );

    if v_has_device then
      v_masked_line := v_masked_line || jsonb_build_object(
        'snapshot_unit_cost', v_line -> 'snapshot_unit_cost',
        'snapshot_monthly_cost', v_line -> 'snapshot_monthly_cost'
      );
    end if;

    v_asset_lines := v_asset_lines || jsonb_build_array(v_masked_line);
  end loop;

  for v_line in
    select value
    from jsonb_array_elements(coalesce(p_json -> 'consumable_lines', '[]'::jsonb))
  loop
    v_masked_line := jsonb_build_object(
      'id', v_line -> 'id',
      'product_id', v_line -> 'product_id',
      'line_order', v_line -> 'line_order',
      'qty_per_refill', v_line -> 'qty_per_refill',
      'refill_frequency_months', v_line -> 'refill_frequency_months',
      'product_sku', v_line -> 'product_sku',
      'product_name_ar', v_line -> 'product_name_ar',
      'product_name_en', v_line -> 'product_name_en',
      'product_group_name_ar', v_line -> 'product_group_name_ar',
      'product_group_name_en', v_line -> 'product_group_name_en',
      'current_oil_product_id', v_line -> 'current_oil_product_id',
      'current_oil_product_name_ar', v_line -> 'current_oil_product_name_ar',
      'current_oil_product_name_en', v_line -> 'current_oil_product_name_en',
      'current_qty_per_refill', v_line -> 'current_qty_per_refill',
      'current_effective_from', v_line -> 'current_effective_from',
      'scheduled_oil_product_id', v_line -> 'scheduled_oil_product_id',
      'scheduled_oil_product_name_ar', v_line -> 'scheduled_oil_product_name_ar',
      'scheduled_oil_product_name_en', v_line -> 'scheduled_oil_product_name_en',
      'scheduled_qty_per_refill', v_line -> 'scheduled_qty_per_refill',
      'scheduled_effective_from', v_line -> 'scheduled_effective_from'
    );

    if v_has_oil then
      v_masked_line := v_masked_line || jsonb_build_object(
        'snapshot_unit_cost', v_line -> 'snapshot_unit_cost',
        'snapshot_monthly_cost', v_line -> 'snapshot_monthly_cost'
      );
    end if;

    v_consumable_lines := v_consumable_lines || jsonb_build_array(v_masked_line);
  end loop;

  return jsonb_strip_nulls(
    jsonb_build_object(
      'id', p_json -> 'id',
      'contract_number', p_json -> 'contract_number',
      'type', p_json -> 'type',
      'status', p_json -> 'status',
      'customer_id', p_json -> 'customer_id',
      'customer_name_ar', p_json -> 'customer_name_ar',
      'customer_name_en', p_json -> 'customer_name_en',
      'service_location_id', p_json -> 'service_location_id',
      'service_location_name', p_json -> 'service_location_name',
      'start_date', p_json -> 'start_date',
      'end_date', p_json -> 'end_date',
      'trial_days', p_json -> 'trial_days',
      'trial_end_date', p_json -> 'trial_end_date',
      'trial_outcome', p_json -> 'trial_outcome',
      'billing_day', p_json -> 'billing_day',
      'refill_day', p_json -> 'refill_day',
      'monthly_rental_value', p_json -> 'monthly_rental_value',
      'total_contract_value', p_json -> 'total_contract_value',
      'min_profit_overridden', p_json -> 'min_profit_overridden',
      'override_reason', p_json -> 'override_reason',
      'converted_from_contract_id', p_json -> 'converted_from_contract_id',
      'converted_to_contract_id', p_json -> 'converted_to_contract_id',
      'renewed_from_contract_id', p_json -> 'renewed_from_contract_id',
      'renewed_to_contract_id', p_json -> 'renewed_to_contract_id',
      'extension_reason', p_json -> 'extension_reason',
      'returned_at', p_json -> 'returned_at',
      'returned_by', p_json -> 'returned_by',
      'return_reason', p_json -> 'return_reason',
      'return_condition', p_json -> 'return_condition',
      'closed_at', p_json -> 'closed_at',
      'closed_by', p_json -> 'closed_by',
      'closure_reason', p_json -> 'closure_reason',
      'notes', p_json -> 'notes',
      'snapshot_device_monthly_cost',
        case when v_has_device then p_json -> 'snapshot_device_monthly_cost' end,
      'snapshot_oil_monthly_cost',
        case when v_has_oil then p_json -> 'snapshot_oil_monthly_cost' end,
      'snapshot_total_monthly_cost',
        case when v_has_total then p_json -> 'snapshot_total_monthly_cost' end,
      'snapshot_monthly_profit',
        case when v_has_profit then p_json -> 'snapshot_monthly_profit' end,
      'snapshot_min_profit_threshold',
        case when v_has_profit then p_json -> 'snapshot_min_profit_threshold' end,
      'snapshot_asset_cost_basis',
        case when v_has_profit then p_json -> 'snapshot_asset_cost_basis' end,
      'snapshot_consumable_cost_basis',
        case when v_has_profit then p_json -> 'snapshot_consumable_cost_basis' end,
      'snapshot_asset_lifespan_months',
        case when v_has_profit then p_json -> 'snapshot_asset_lifespan_months' end,
      'asset_lines', v_asset_lines,
      'consumable_lines', v_consumable_lines
    )
  );
end;
$$;
