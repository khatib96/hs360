-- Phase 6 M9 follow-up: enrich contract read models for operational UI.
-- Read-only change: product SKU/group names and contract location summary.

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
      'product_group_name_en', v_line -> 'product_group_name_en'
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
      'product_group_name_en', pg.name_en
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

drop function if exists public.list_contracts(
  uuid, text, text, date, date, text, boolean, integer, integer
);

create function public.list_contracts(
  p_customer_id uuid default null,
  p_type text default null,
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_search text default null,
  p_low_profit_override_only boolean default false,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  contract_number text,
  type public.contract_type,
  status public.contract_status,
  start_date date,
  end_date date,
  customer_id uuid,
  customer_name_ar text,
  customer_name_en text,
  service_location_id uuid,
  service_location_name text,
  location_governorate text,
  location_area text,
  monthly_rental_value numeric(15, 3),
  min_profit_overridden boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_search text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('contracts.view') then
    raise exception 'permission_denied';
  end if;

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    c.id,
    c.contract_number,
    c.type,
    c.status,
    c.start_date,
    c.end_date,
    c.customer_id,
    cu.name_ar as customer_name_ar,
    cu.name_en as customer_name_en,
    c.service_location_id,
    coalesce(nullif(btrim(csl.name), ''), nullif(btrim(c.location_name), '')) as service_location_name,
    c.location_governorate,
    c.location_area,
    c.monthly_rental_value,
    c.min_profit_overridden
  from public.contracts c
  join public.customers cu
    on cu.id = c.customer_id
    and cu.tenant_id = c.tenant_id
  left join public.customer_service_locations csl
    on csl.id = c.service_location_id
    and csl.tenant_id = c.tenant_id
  where c.tenant_id = v_tenant_id
    and (p_customer_id is null or c.customer_id = p_customer_id)
    and (p_type is null or c.type::text = p_type)
    and (p_status is null or c.status::text = p_status)
    and (p_date_from is null or c.start_date >= p_date_from)
    and (p_date_to is null or c.start_date <= p_date_to)
    and (not coalesce(p_low_profit_override_only, false) or c.min_profit_overridden is true)
    and (
      v_search is null
      or lower(coalesce(c.contract_number, '')) like '%' || v_search || '%'
      or lower(coalesce(cu.name_ar, '')) like '%' || v_search || '%'
      or lower(coalesce(cu.name_en, '')) like '%' || v_search || '%'
      or lower(coalesce(cu.phone_primary, '')) like '%' || v_search || '%'
      or lower(coalesce(c.location_governorate, '')) like '%' || v_search || '%'
      or lower(coalesce(c.location_area, '')) like '%' || v_search || '%'
    )
  order by c.start_date desc nulls last, c.contract_number desc nulls last, c.id desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.list_contracts(
  uuid, text, text, date, date, text, boolean, integer, integer
) from public, anon, authenticated;

grant execute on function public.list_contracts(
  uuid, text, text, date, date, text, boolean, integer, integer
) to authenticated;

comment on function public.list_contracts(
  uuid, text, text, date, date, text, boolean, integer, integer
) is 'Phase 6 M9: bounded contract list includes snapshot governorate/area and searches them.';

comment on function public.get_contract_detail(uuid) is
  'Phase 6 M9: contract detail includes product SKU/group labels with permission-masked costs.';
