-- Phase 6 M2: contract pricing and profit engine.
-- Shared helpers + preview_contract_profit (read-only). M3 creation RPCs reuse compute_contract_pricing_internal.

-- ---------------------------------------------------------------------------
-- Section A: tenant settings and unit-cost resolution
-- ---------------------------------------------------------------------------
create or replace function public.resolve_tenant_contract_settings(p_tenant_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.tenant_settings%rowtype;
begin
  select * into v_row
  from public.tenant_settings ts
  where ts.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  return jsonb_build_object(
    'rental_asset_cost_basis', v_row.rental_asset_cost_basis::text,
    'rental_consumable_cost_basis', v_row.rental_consumable_cost_basis::text,
    'min_monthly_profit', v_row.min_monthly_profit,
    'default_device_lifespan_months', v_row.default_device_lifespan_months,
    'allow_multi_asset_contracts', v_row.allow_multi_asset_contracts,
    'allow_multi_consumable_contracts', v_row.allow_multi_consumable_contracts
  );
end;
$$;

create or replace function public.resolve_rental_asset_unit_cost(
  p_tenant_id uuid,
  p_product_id uuid,
  p_product_unit_id uuid,
  p_basis public.rental_asset_cost_basis
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_product public.products%rowtype;
  v_purchase_cost numeric(15, 3);
begin
  select * into v_product
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_product.product_type is distinct from 'asset_rental'::public.product_type then
    raise exception 'validation_failed';
  end if;

  if coalesce(v_product.is_serialized, false) and p_product_unit_id is null then
    raise exception 'validation_failed';
  end if;

  if p_product_unit_id is not null then
    if not exists (
      select 1
      from public.product_units pu
      where pu.id = p_product_unit_id
        and pu.tenant_id = p_tenant_id
        and pu.product_id = p_product_id
    ) then
      raise exception 'validation_failed';
    end if;
  end if;

  case p_basis
    when 'unit_purchase_cost' then
      if p_product_unit_id is null then
        if coalesce(v_product.is_serialized, false) then
          raise exception 'validation_failed';
        end if;

        return v_product.avg_cost;
      end if;

      select pu.purchase_cost
      into v_purchase_cost
      from public.product_units pu
      where pu.id = p_product_unit_id
        and pu.tenant_id = p_tenant_id
        and pu.product_id = p_product_id;

      if not found or v_purchase_cost is null then
        raise exception 'validation_failed';
      end if;

      return v_purchase_cost;
    when 'product_avg_cost' then
      return v_product.avg_cost;
    when 'product_sale_price' then
      return v_product.sale_price;
    else
      raise exception 'validation_failed';
  end case;
end;
$$;

create or replace function public.resolve_rental_consumable_unit_cost(
  p_tenant_id uuid,
  p_product_id uuid,
  p_basis public.rental_consumable_cost_basis
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_product public.products%rowtype;
begin
  select * into v_product
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_product.product_type is distinct from 'consumable_rental'::public.product_type then
    raise exception 'validation_failed';
  end if;

  case p_basis
    when 'product_sale_price' then
      return v_product.sale_price;
    when 'product_avg_cost' then
      return v_product.avg_cost;
    when 'product_last_purchase_cost' then
      if v_product.last_purchase_cost is null then
        raise exception 'validation_failed';
      end if;
      return v_product.last_purchase_cost;
    else
      raise exception 'validation_failed';
  end case;
end;
$$;

create or replace function public.convert_contract_consumable_qty_to_primary(
  p_product_id uuid,
  p_qty_per_refill numeric
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.products p where p.id = p_product_id) then
    raise exception 'validation_failed';
  end if;

  if p_qty_per_refill is null or p_qty_per_refill <= 0 then
    raise exception 'validation_failed';
  end if;

  return p_qty_per_refill;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section B: monthly cost and profit math
-- ---------------------------------------------------------------------------
create or replace function public.calculate_contract_asset_monthly_cost(
  p_source_cost numeric,
  p_lifespan_months int,
  p_decimal_places integer
)
returns numeric
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_lifespan_months is null or p_lifespan_months <= 0 then
    raise exception 'validation_failed';
  end if;

  return public.round_money(p_source_cost / p_lifespan_months, p_decimal_places);
end;
$$;

create or replace function public.calculate_contract_consumable_monthly_cost(
  p_qty_primary numeric,
  p_unit_cost numeric,
  p_refill_frequency_months int,
  p_decimal_places integer
)
returns numeric
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_refill_frequency_months is null or p_refill_frequency_months < 1 then
    raise exception 'validation_failed';
  end if;

  return public.round_money(
    (p_qty_primary * p_unit_cost) / p_refill_frequency_months,
    p_decimal_places
  );
end;
$$;

create or replace function public.calculate_contract_total_monthly_cost(
  p_asset_total numeric,
  p_consumable_total numeric,
  p_decimal_places integer
)
returns numeric
language sql
immutable
set search_path = public
as $$
  select public.round_money(coalesce(p_asset_total, 0) + coalesce(p_consumable_total, 0), p_decimal_places);
$$;

create or replace function public.calculate_contract_expected_monthly_profit(
  p_monthly_rental_value numeric,
  p_total_monthly_cost numeric,
  p_decimal_places integer
)
returns numeric
language sql
immutable
set search_path = public
as $$
  select public.round_money(p_monthly_rental_value - p_total_monthly_cost, p_decimal_places);
$$;

create or replace function public.validate_contract_minimum_monthly_profit(
  p_monthly_rental_value numeric,
  p_total_monthly_cost numeric,
  p_min_monthly_profit numeric,
  p_request_override boolean,
  p_override_reason text,
  p_decimal_places integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_expected_profit numeric(15, 3);
  v_minimum_allowed numeric(15, 3);
  v_passes boolean;
  v_below boolean;
  v_requires_override boolean := false;
  v_overridden boolean := false;
begin
  v_expected_profit := public.calculate_contract_expected_monthly_profit(
    p_monthly_rental_value,
    p_total_monthly_cost,
    p_decimal_places
  );
  v_minimum_allowed := public.round_money(
    p_total_monthly_cost + p_min_monthly_profit,
    p_decimal_places
  );
  v_below := v_expected_profit < p_min_monthly_profit;
  v_passes := not v_below;

  if v_below and coalesce(p_request_override, false) then
    if not public.user_has_permission('contracts.approve_override') then
      raise exception 'permission_denied';
    end if;

    if nullif(btrim(coalesce(p_override_reason, '')), '') is null then
      raise exception 'validation_failed';
    end if;

    v_passes := true;
    v_overridden := true;
    v_requires_override := false;
  elsif v_below then
    v_requires_override := true;
  end if;

  return jsonb_build_object(
    'expected_monthly_profit', v_expected_profit,
    'minimum_allowed_monthly_value', v_minimum_allowed,
    'passes_min_profit', v_passes,
    'below_min_profit', v_below,
    'requires_override', v_requires_override,
    'min_profit_overridden', v_overridden
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section C: shared pricing compute (internal)
-- ---------------------------------------------------------------------------
create or replace function public.compute_contract_pricing_internal(
  p_tenant_id uuid,
  p_data jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_settings jsonb;
  v_asset_basis public.rental_asset_cost_basis;
  v_consumable_basis public.rental_consumable_cost_basis;
  v_min_profit numeric(15, 3);
  v_default_lifespan int;
  v_decimal_places integer;
  v_monthly_rental_value numeric(15, 3);
  v_request_override boolean;
  v_override_reason text;
  v_asset_lines jsonb;
  v_consumable_lines jsonb;
  v_asset_count int;
  v_consumable_count int;
  v_line jsonb;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_qty_per_refill numeric(15, 3);
  v_refill_frequency int;
  v_product public.products%rowtype;
  v_source_cost numeric(15, 3);
  v_lifespan_months int;
  v_qty_primary numeric(15, 3);
  v_line_monthly_cost numeric(15, 3);
  v_asset_monthly_total numeric(15, 3) := 0;
  v_consumable_monthly_total numeric(15, 3) := 0;
  v_norm_asset_lines jsonb := '[]'::jsonb;
  v_norm_consumable_lines jsonb := '[]'::jsonb;
  v_profit_result jsonb;
  v_contract_lifespan int;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_settings := public.resolve_tenant_contract_settings(p_tenant_id);
  v_asset_basis := (v_settings ->> 'rental_asset_cost_basis')::public.rental_asset_cost_basis;
  v_consumable_basis := (v_settings ->> 'rental_consumable_cost_basis')::public.rental_consumable_cost_basis;
  v_min_profit := (v_settings ->> 'min_monthly_profit')::numeric(15, 3);
  v_default_lifespan := (v_settings ->> 'default_device_lifespan_months')::int;
  v_decimal_places := public.resolve_tenant_money_precision(p_tenant_id);

  if not (p_data ? 'monthly_rental_value') then
    raise exception 'validation_failed';
  end if;

  begin
    v_monthly_rental_value := (p_data ->> 'monthly_rental_value')::numeric(15, 3);
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if v_monthly_rental_value < 0 then
    raise exception 'validation_failed';
  end if;

  v_request_override := coalesce((p_data ->> 'request_override')::boolean, false);
  v_override_reason := p_data ->> 'override_reason';

  v_asset_lines := coalesce(p_data -> 'asset_lines', '[]'::jsonb);
  v_consumable_lines := coalesce(p_data -> 'consumable_lines', '[]'::jsonb);

  if jsonb_typeof(v_asset_lines) <> 'array' or jsonb_typeof(v_consumable_lines) <> 'array' then
    raise exception 'validation_failed';
  end if;

  v_asset_count := jsonb_array_length(v_asset_lines);
  v_consumable_count := jsonb_array_length(v_consumable_lines);

  if v_asset_count = 0 and v_consumable_count = 0 then
    raise exception 'validation_failed';
  end if;

  if v_asset_count > 1 and not (v_settings ->> 'allow_multi_asset_contracts')::boolean then
    raise exception 'validation_failed';
  end if;

  if v_consumable_count > 1 and not (v_settings ->> 'allow_multi_consumable_contracts')::boolean then
    raise exception 'validation_failed';
  end if;

  for v_line in select value from jsonb_array_elements(v_asset_lines) loop
    if jsonb_typeof(v_line) <> 'object' or not (v_line ? 'product_id') then
      raise exception 'validation_failed';
    end if;

    begin
      v_product_id := (v_line ->> 'product_id')::uuid;
      if v_line ? 'product_unit_id' then
        v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;
      else
        v_product_unit_id := null;
      end if;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    select * into v_product
    from public.products p
    where p.id = v_product_id
      and p.tenant_id = p_tenant_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_product.is_serialized and v_product_unit_id is null then
      raise exception 'validation_failed';
    end if;

    v_source_cost := public.resolve_rental_asset_unit_cost(
      p_tenant_id,
      v_product_id,
      v_product_unit_id,
      v_asset_basis
    );

    v_lifespan_months := coalesce(v_product.expected_lifespan_months, v_default_lifespan);

    v_line_monthly_cost := public.calculate_contract_asset_monthly_cost(
      v_source_cost,
      v_lifespan_months,
      v_decimal_places
    );
    v_asset_monthly_total := v_asset_monthly_total + v_line_monthly_cost;

    v_norm_asset_lines := v_norm_asset_lines || jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product_id,
        'product_unit_id', v_product_unit_id,
        'source_unit_cost', v_source_cost,
        'monthly_cost', v_line_monthly_cost,
        'cost_basis', v_asset_basis::text,
        'lifespan_months', v_lifespan_months
      )
    );

    if v_asset_count = 1 then
      v_contract_lifespan := v_lifespan_months;
    end if;
  end loop;

  for v_line in select value from jsonb_array_elements(v_consumable_lines) loop
    if jsonb_typeof(v_line) <> 'object' or not (v_line ? 'product_id' and v_line ? 'qty_per_refill') then
      raise exception 'validation_failed';
    end if;

    begin
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_qty_per_refill := (v_line ->> 'qty_per_refill')::numeric(15, 3);
      v_refill_frequency := coalesce((v_line ->> 'refill_frequency_months')::int, 1);
    exception
      when others then
        raise exception 'validation_failed';
    end;

    v_qty_primary := public.convert_contract_consumable_qty_to_primary(
      v_product_id,
      v_qty_per_refill
    );

    v_source_cost := public.resolve_rental_consumable_unit_cost(
      p_tenant_id,
      v_product_id,
      v_consumable_basis
    );

    v_line_monthly_cost := public.calculate_contract_consumable_monthly_cost(
      v_qty_primary,
      v_source_cost,
      v_refill_frequency,
      v_decimal_places
    );
    v_consumable_monthly_total := v_consumable_monthly_total + v_line_monthly_cost;

    v_norm_consumable_lines := v_norm_consumable_lines || jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product_id,
        'qty_per_refill', v_qty_per_refill,
        'qty_primary', v_qty_primary,
        'refill_frequency_months', v_refill_frequency,
        'source_unit_cost', v_source_cost,
        'monthly_cost', v_line_monthly_cost,
        'cost_basis', v_consumable_basis::text
      )
    );
  end loop;

  v_asset_monthly_total := public.round_money(v_asset_monthly_total, v_decimal_places);
  v_consumable_monthly_total := public.round_money(v_consumable_monthly_total, v_decimal_places);

  v_profit_result := public.validate_contract_minimum_monthly_profit(
    v_monthly_rental_value,
    public.calculate_contract_total_monthly_cost(
      v_asset_monthly_total,
      v_consumable_monthly_total,
      v_decimal_places
    ),
    v_min_profit,
    v_request_override,
    v_override_reason,
    v_decimal_places
  );

  return jsonb_build_object(
    'monthly_rental_value', v_monthly_rental_value,
    'asset_cost_basis', v_asset_basis::text,
    'consumable_cost_basis', v_consumable_basis::text,
    'asset_lifespan_months', v_contract_lifespan,
    'asset_monthly_cost', v_asset_monthly_total,
    'consumable_monthly_cost', v_consumable_monthly_total,
    'total_monthly_cost', public.calculate_contract_total_monthly_cost(
      v_asset_monthly_total,
      v_consumable_monthly_total,
      v_decimal_places
    ),
    'expected_monthly_profit', v_profit_result -> 'expected_monthly_profit',
    'min_monthly_profit_threshold', v_min_profit,
    'minimum_allowed_monthly_value', v_profit_result -> 'minimum_allowed_monthly_value',
    'passes_min_profit', v_profit_result -> 'passes_min_profit',
    'below_min_profit', v_profit_result -> 'below_min_profit',
    'requires_override', v_profit_result -> 'requires_override',
    'min_profit_overridden', v_profit_result -> 'min_profit_overridden',
    'asset_lines', v_norm_asset_lines,
    'consumable_lines', v_norm_consumable_lines
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section D: permission mask + public preview RPC
-- ---------------------------------------------------------------------------
create or replace function public.mask_contract_pricing_preview(p_result jsonb)
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
    select value from jsonb_array_elements(coalesce(p_result -> 'asset_lines', '[]'::jsonb))
  loop
    v_masked_line := jsonb_build_object(
      'product_id', v_line -> 'product_id',
      'product_unit_id', v_line -> 'product_unit_id'
    );

    if v_has_device then
      v_masked_line := v_masked_line || jsonb_build_object(
        'source_unit_cost', v_line -> 'source_unit_cost',
        'monthly_cost', v_line -> 'monthly_cost',
        'cost_basis', v_line -> 'cost_basis',
        'lifespan_months', v_line -> 'lifespan_months'
      );
    end if;

    v_asset_lines := v_asset_lines || jsonb_build_array(v_masked_line);
  end loop;

  for v_line in
    select value from jsonb_array_elements(coalesce(p_result -> 'consumable_lines', '[]'::jsonb))
  loop
    v_masked_line := jsonb_build_object(
      'product_id', v_line -> 'product_id',
      'qty_per_refill', v_line -> 'qty_per_refill',
      'refill_frequency_months', v_line -> 'refill_frequency_months'
    );

    if v_has_oil then
      v_masked_line := v_masked_line || jsonb_build_object(
        'qty_primary', v_line -> 'qty_primary',
        'source_unit_cost', v_line -> 'source_unit_cost',
        'monthly_cost', v_line -> 'monthly_cost',
        'cost_basis', v_line -> 'cost_basis'
      );
    end if;

    v_consumable_lines := v_consumable_lines || jsonb_build_array(v_masked_line);
  end loop;

  return jsonb_strip_nulls(
    jsonb_build_object(
      'monthly_rental_value', p_result -> 'monthly_rental_value',
      'passes_min_profit', p_result -> 'passes_min_profit',
      'below_min_profit', p_result -> 'below_min_profit',
      'requires_override', p_result -> 'requires_override',
      'can_override', public.user_has_permission('contracts.approve_override'),
      'min_profit_overridden', p_result -> 'min_profit_overridden',
      'asset_monthly_cost', case when v_has_device then p_result -> 'asset_monthly_cost' end,
      'consumable_monthly_cost', case when v_has_oil then p_result -> 'consumable_monthly_cost' end,
      'total_monthly_cost', case when v_has_total then p_result -> 'total_monthly_cost' end,
      'expected_monthly_profit', case when v_has_profit then p_result -> 'expected_monthly_profit' end,
      'minimum_allowed_monthly_value',
        case when v_has_profit then p_result -> 'minimum_allowed_monthly_value' end,
      'min_monthly_profit_threshold',
        case when v_has_profit then p_result -> 'min_monthly_profit_threshold' end,
      'asset_cost_basis', case when v_has_profit then p_result -> 'asset_cost_basis' end,
      'consumable_cost_basis', case when v_has_profit then p_result -> 'consumable_cost_basis' end,
      'asset_lifespan_months', case when v_has_profit then p_result -> 'asset_lifespan_months' end,
      'asset_lines', v_asset_lines,
      'consumable_lines', v_consumable_lines
    )
  );
end;
$$;

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

  if not public.user_has_permission('contracts.create') then
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
-- Section E: grants
-- ---------------------------------------------------------------------------
revoke all on function public.resolve_tenant_contract_settings(uuid) from public, anon, authenticated;
revoke all on function public.resolve_rental_asset_unit_cost(uuid, uuid, uuid, public.rental_asset_cost_basis) from public, anon, authenticated;
revoke all on function public.resolve_rental_consumable_unit_cost(uuid, uuid, public.rental_consumable_cost_basis) from public, anon, authenticated;
revoke all on function public.convert_contract_consumable_qty_to_primary(uuid, numeric) from public, anon, authenticated;
revoke all on function public.calculate_contract_asset_monthly_cost(numeric, int, integer) from public, anon, authenticated;
revoke all on function public.calculate_contract_consumable_monthly_cost(numeric, numeric, int, integer) from public, anon, authenticated;
revoke all on function public.calculate_contract_total_monthly_cost(numeric, numeric, integer) from public, anon, authenticated;
revoke all on function public.calculate_contract_expected_monthly_profit(numeric, numeric, integer) from public, anon, authenticated;
revoke all on function public.validate_contract_minimum_monthly_profit(numeric, numeric, numeric, boolean, text, integer) from public, anon, authenticated;
revoke all on function public.compute_contract_pricing_internal(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.mask_contract_pricing_preview(jsonb) from public, anon, authenticated;

grant execute on function public.preview_contract_profit(jsonb) to authenticated;

comment on function public.preview_contract_profit(jsonb) is
  'Phase 6 M2: read-only contract profit preview. Uses tenant cost basis settings; rejects forbidden basis overrides.';
