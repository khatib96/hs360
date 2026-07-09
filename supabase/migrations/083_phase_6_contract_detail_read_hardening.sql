-- Phase 6 M8 follow-up: expose total_contract_value in detail JSON;
-- revoke unnecessary idempotency column grants on contracts.

-- ---------------------------------------------------------------------------
-- Read RPC: include total_contract_value in detail JSON
-- ---------------------------------------------------------------------------
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
      'product_name_ar', p.name_ar,
      'product_name_en', p.name_en
    )
    order by cl.line_order, cl.id
  ), '[]'::jsonb)
  into v_asset_lines
  from public.contract_lines cl
  join public.products p
    on p.id = cl.product_id
    and p.tenant_id = cl.tenant_id
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
      'product_name_ar', p.name_ar,
      'product_name_en', p.name_en
    )
    order by cl.line_order, cl.id
  ), '[]'::jsonb)
  into v_consumable_lines
  from public.contract_lines cl
  join public.products p
    on p.id = cl.product_id
    and p.tenant_id = cl.tenant_id
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

-- ---------------------------------------------------------------------------
-- ACL: remove idempotency columns from authenticated direct SELECT grants
-- ---------------------------------------------------------------------------
revoke select (
  idempotency_key,
  idempotency_payload_hash
) on table public.contracts from authenticated;
