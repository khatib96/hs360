-- Phase 6 M9 corrective pass: non-serialized rental assets and trial default.

alter table public.tenant_settings
  alter column default_trial_days set default 3;

update public.tenant_settings
set default_trial_days = 3
where default_trial_days is null
   or default_trial_days = 30;

comment on column public.tenant_settings.default_trial_days is
  'Default trial-contract duration in days. HS default is 3 days; users may change it per contract.';

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.resolve_rental_asset_unit_cost(uuid, uuid, uuid, public.rental_asset_cost_basis)'::regprocedure
  ) into v_sql;

  v_sql := replace(
    v_sql,
$old$
  if v_product.is_serialized and p_product_unit_id is null then
$old$,
$new$
  if coalesce(v_product.is_serialized, false) and p_product_unit_id is null then
$new$
  );

  v_sql := replace(
    v_sql,
$old$
    when 'unit_purchase_cost' then
      if p_product_unit_id is null then
        raise exception 'validation_failed';
      end if;
$old$,
$new$
    when 'unit_purchase_cost' then
      if p_product_unit_id is null then
        if coalesce(v_product.is_serialized, false) then
          raise exception 'validation_failed';
        end if;

        return v_product.avg_cost;
      end if;
$new$
  );

  execute v_sql;

  select pg_get_functiondef(
    'public.normalize_contract_creation_payload(public.contract_type, jsonb)'::regprocedure
  ) into v_sql;

  v_sql := replace(
    v_sql,
$old$
      if not (v_line ? 'product_unit_id') then
        raise exception 'validation_failed';
      end if;
      v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;
$old$,
$new$
      if v_line ? 'product_unit_id' and nullif(btrim(v_line ->> 'product_unit_id'), '') is not null then
        v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;
      else
        v_product_unit_id := null;
      end if;
$new$
  );

  v_sql := replace(
    v_sql,
$old$
    v_norm_line := jsonb_build_object(
      'product_id', v_product_id,
      'product_unit_id', v_product_unit_id
    );
$old$,
$new$
    v_norm_line := jsonb_build_object(
      'product_id', v_product_id
    );
    if v_product_unit_id is not null then
      v_norm_line := v_norm_line || jsonb_build_object(
        'product_unit_id', v_product_unit_id
      );
    end if;
$new$
  );

  execute v_sql;

  select pg_get_functiondef(
    'public.create_contract_internal(public.contract_type, jsonb, uuid)'::regprocedure
  ) into v_sql;

  v_sql := replace(
    v_sql,
$old$
  v_prev_status public.unit_status;
  v_qty_per_refill numeric(15, 3);
$old$,
$new$
  v_prev_status public.unit_status;
  v_product_is_serialized boolean;
  v_qty_per_refill numeric(15, 3);
$new$
  );

  v_sql := replace(
    v_sql,
$old$
  for v_line in select value from jsonb_array_elements(v_asset_lines) loop
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;

    if v_product_unit_id = any (v_seen_units) then
      raise exception 'validation_failed';
    end if;
    v_seen_units := array_append(v_seen_units, v_product_unit_id);

    if not exists (
      select 1
      from public.products p
      where p.id = v_product_id
        and p.tenant_id = v_tenant_id
        and p.product_type = 'asset_rental'::public.product_type
        and coalesce(p.is_active, true)
    ) then
      raise exception 'validation_failed';
    end if;

    select pu.status, pu.current_warehouse_id
    into v_unit_status, v_unit_warehouse_id
    from public.product_units pu
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id
      and pu.product_id = v_product_id
    for update;

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_unit_status not in ('available_new'::public.unit_status, 'available_used'::public.unit_status) then
      raise exception 'validation_failed';
    end if;

    if exists (
      select 1
      from public.product_units pu
      where pu.id = v_product_unit_id
        and pu.current_contract_id is not null
    ) then
      raise exception 'validation_failed';
    end if;

    if v_unit_warehouse_id is null then
      raise exception 'validation_failed';
    end if;
  end loop;
$old$,
$new$
  for v_line in select value from jsonb_array_elements(v_asset_lines) loop
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_product_unit_id := nullif(btrim(v_line ->> 'product_unit_id'), '')::uuid;

    select p.is_serialized
    into v_product_is_serialized
    from public.products p
    where p.id = v_product_id
      and p.tenant_id = v_tenant_id
      and p.product_type = 'asset_rental'::public.product_type
      and coalesce(p.is_active, true);

    if not found then
      raise exception 'validation_failed';
    end if;

    if coalesce(v_product_is_serialized, false) then
      if v_product_unit_id is null then
        raise exception 'validation_failed';
      end if;

      if v_product_unit_id = any (v_seen_units) then
        raise exception 'validation_failed';
      end if;
      v_seen_units := array_append(v_seen_units, v_product_unit_id);

      select pu.status, pu.current_warehouse_id
      into v_unit_status, v_unit_warehouse_id
      from public.product_units pu
      where pu.id = v_product_unit_id
        and pu.tenant_id = v_tenant_id
        and pu.product_id = v_product_id
      for update;

      if not found then
        raise exception 'validation_failed';
      end if;

      if v_unit_status not in ('available_new'::public.unit_status, 'available_used'::public.unit_status) then
        raise exception 'validation_failed';
      end if;

      if exists (
        select 1
        from public.product_units pu
        where pu.id = v_product_unit_id
          and pu.current_contract_id is not null
      ) then
        raise exception 'validation_failed';
      end if;

      if v_unit_warehouse_id is null then
        raise exception 'validation_failed';
      end if;
    else
      if v_product_unit_id is not null then
        raise exception 'validation_failed';
      end if;

      v_unit_warehouse_id := null;
      select ib.warehouse_id
      into v_unit_warehouse_id
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.product_id = v_product_id
        and ib.qty_available >= 1
      order by ib.updated_at desc, ib.id
      limit 1
      for update;

      if not found then
        raise exception 'insufficient_stock';
      end if;
    end if;
  end loop;
$new$
  );

  v_sql := replace(
    v_sql,
$old$
      30
$old$,
$new$
      3
$new$
  );

  v_sql := replace(
    v_sql,
$old$
    v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;
$old$,
$new$
    v_product_unit_id := nullif(btrim(v_line ->> 'product_unit_id'), '')::uuid;
    v_unit_warehouse_id := null;
    v_prev_status := null;
$new$
  );

  v_sql := replace(
    v_sql,
$old$
    select pu.status, pu.current_warehouse_id
    into v_prev_status, v_unit_warehouse_id
    from public.product_units pu
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id
    for update;
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
$new$
  );

  v_sql := replace(
    v_sql,
$old$
    insert into public.unit_events (
      tenant_id, product_unit_id, event_type, occurred_at,
      warehouse_id, customer_id, service_location_id, contract_id,
      reference_table, reference_id, notes, metadata_json, created_by
    )
    values (
      v_tenant_id, v_product_unit_id, v_event_type, now(),
      v_unit_warehouse_id, v_customer_id, v_service_location_id, v_contract_id,
      'contracts', v_contract_id,
      'Contract ' || v_contract_number,
      jsonb_build_object(
        'previous_status', v_prev_status::text,
        'contract_type', p_contract_type::text,
        'contract_number', v_contract_number
      ),
      auth.uid()
    );

    update public.product_units pu
    set
      status = v_unit_target_status,
      current_contract_id = v_contract_id,
      current_customer_id = v_customer_id,
      current_service_location_id = v_service_location_id,
      updated_at = now()
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id;
$old$,
$new$
    if v_product_unit_id is not null then
      insert into public.unit_events (
        tenant_id, product_unit_id, event_type, occurred_at,
        warehouse_id, customer_id, service_location_id, contract_id,
        reference_table, reference_id, notes, metadata_json, created_by
      )
      values (
        v_tenant_id, v_product_unit_id, v_event_type, now(),
        v_unit_warehouse_id, v_customer_id, v_service_location_id, v_contract_id,
        'contracts', v_contract_id,
        'Contract ' || v_contract_number,
        jsonb_build_object(
          'previous_status', v_prev_status::text,
          'contract_type', p_contract_type::text,
          'contract_number', v_contract_number
        ),
        auth.uid()
      );

      update public.product_units pu
      set
        status = v_unit_target_status,
        current_contract_id = v_contract_id,
        current_customer_id = v_customer_id,
        current_service_location_id = v_service_location_id,
        updated_at = now()
      where pu.id = v_product_unit_id
        and pu.tenant_id = v_tenant_id;
    end if;
$new$
  );

  execute v_sql;
end $$;
