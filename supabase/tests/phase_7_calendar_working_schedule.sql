\set ON_ERROR_STOP on

-- Phase 7 M1: calendar working schedule and event model verification.
-- Seed IDs (migration 031): tenant_a 101, owner 201, field 205, tenant_b 102,
-- owner_b 204, agent 601.

create or replace function pg_temp.p7m1_standard_days()
returns jsonb
language sql
immutable
as $$
  select jsonb_build_array(
    jsonb_build_object('iso_weekday', 1, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 2, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 3, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 4, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 5, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '13:00'),
    jsonb_build_object('iso_weekday', 6, 'day_mode', 'day_off'),
    jsonb_build_object('iso_weekday', 7, 'day_mode', '24_hours')
  );
$$;

create or replace function pg_temp.p7m1_configure_calendar()
returns void
language plpgsql
as $$
begin
  perform public.update_calendar_settings(
    jsonb_build_object(
      'timezone_name', 'Asia/Kuwait',
      'remind_event_workday_start', true,
      'remind_previous_workday_start', false,
      'days', pg_temp.p7m1_standard_days()
    )
  );
end;
$$;

create or replace function pg_temp.p7m1_expect_validation_failed(p_sql text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
    raise exception 'p7m1_expect_validation_failed: statement succeeded unexpectedly: %', p_sql;
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise exception 'p7m1_expect_validation_failed: unexpected error for %: %', p_sql, sqlerrm;
      end if;
  end;
end;
$$;

create or replace function pg_temp.p7m1_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    '{"name_ar":"عميل P7M1","phone_primary":"+96550017001","create_account":true}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع P7M1","location_type":"branch","governorate":"Hawalli","area":"Salmiya","contact_person_phone":"+96550017001"}'::jsonb
  );
  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p7m1_inventory_setup(p_customers jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_asset_product uuid := gen_random_uuid();
  v_oil_a uuid := gen_random_uuid();
  v_oil_b uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
  v_unit_b uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_asset_product, v_tenant_a, 'P7M1-AST-' || left(v_asset_product::text, 8),
    'جهاز P7M1', 'P7M1 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values
    (
      v_oil_a, v_tenant_a, 'P7M1-OIL-A-' || left(v_oil_a::text, 8),
      'زيت A P7M1', 'P7M1 Oil A', v_oils_group, 'consumable_rental',
      'ml', 1, 0.015, 0.010, 0.012, false, v_owner
    ),
    (
      v_oil_b, v_tenant_a, 'P7M1-OIL-B-' || left(v_oil_b::text, 8),
      'زيت B P7M1', 'P7M1 Oil B', v_oils_group, 'consumable_rental',
      'ml', 1, 0.020, 0.013, 0.014, false, v_owner
    );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values
    (
      v_unit_a, v_tenant_a, v_asset_product, 'P7M1-SN-' || left(v_unit_a::text, 8),
      'available_new', v_main_warehouse, 60.000, current_date
    ),
    (
      v_unit_b, v_tenant_a, v_asset_product, 'P7M1-SN-' || left(v_unit_b::text, 8),
      'available_new', v_main_warehouse, 60.000, current_date
    );

  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_asset_product, 2.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  update public.tenant_calendar_settings tcs
  set timezone_name = 'Asia/Kuwait'
  where tcs.tenant_id = v_tenant_a;

  return p_customers || jsonb_build_object(
    'asset_product', v_asset_product,
    'oil_a', v_oil_a,
    'oil_b', v_oil_b,
    'unit_a', v_unit_a,
    'unit_b', v_unit_b,
    'main_warehouse', v_main_warehouse
  );
end;
$$;

create or replace function pg_temp.p7m1_create_rental(p_fixture jsonb)
returns uuid
language plpgsql
as $$
declare
  v_start date := current_date - 1;
  v_end date := (v_start + interval '12 months')::date;
begin
  return public.create_rental_contract(
    jsonb_build_object(
      'customer_id', p_fixture ->> 'customer_id',
      'service_location_id', p_fixture ->> 'service_location_id',
      'start_date', v_start,
      'end_date', v_end,
      'billing_day', 5,
      'refill_day', 7,
      'monthly_rental_value', '25.000',
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_fixture ->> 'asset_product',
          'product_unit_id', p_fixture ->> 'unit_a'
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_fixture ->> 'oil_a',
          'qty_per_refill', 500.000,
          'refill_frequency_months', 1
        )
      )
    ),
    gen_random_uuid()
  );
end;
$$;

create or replace function pg_temp.p7m1_build_exec_graph(p_with_oil_change boolean default false)
returns jsonb
language plpgsql
as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_agent uuid := '00000000-0000-0000-0000-000000000601';
  v_customers jsonb;
  v_fixture jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_event_id uuid;
  v_event_date date;
  v_visit_id uuid;
  v_product_id uuid;
  v_qty numeric(15, 3);
  v_oil_change_id uuid;
  v_oil_b uuid;
  v_completed_at timestamptz;
  v_actual_completion date;
  v_original_due date;
  v_visit_number text;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  perform pg_temp.p7m1_configure_calendar();
  v_customers := pg_temp.p7m1_customer_setup();
  v_fixture := pg_temp.p7m1_inventory_setup(v_customers);
  v_contract_id := pg_temp.p7m1_create_rental(v_fixture);

  perform public.sync_contract_calendar_events_internal(v_contract_id, 60);

  select ce.id, ce.scheduled_date, ce.contract_line_id
  into v_event_id, v_event_date, v_line_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  order by ce.scheduled_date, ce.id
  limit 1;

  if v_event_id is null then
    raise exception 'p7m1_build_exec_graph: no pending refill_due event';
  end if;

  v_oil_b := (v_fixture ->> 'oil_b')::uuid;
  v_oil_change_id := null;

  if p_with_oil_change then
    if v_event_date < current_date then
      v_event_date := current_date + 14;
      update public.calendar_events
      set scheduled_date = v_event_date
      where id = v_event_id;
    end if;

    perform public.schedule_contract_consumable_change(
      jsonb_build_object(
        'contract_id', v_contract_id,
        'contract_line_id', v_line_id,
        'new_product_id', v_oil_b,
        'effective_date', v_event_date,
        'qty_per_refill', 600.000,
        'reason', 'P7M1 oil change fixture'
      ),
      gen_random_uuid()
    );

    select
      ce.id,
      ce.scheduled_date,
      nullif(ce.source_metadata ->> 'contract_oil_change_id', '')::uuid
    into v_event_id, v_event_date, v_oil_change_id
    from public.calendar_events ce
    where ce.contract_id = v_contract_id
      and ce.type = 'refill_due'::public.calendar_event_type
      and ce.status = 'pending'::public.calendar_event_status
      and ce.source_metadata ? 'contract_oil_change_id'
      and ce.scheduled_date = v_event_date
    order by ce.id
    limit 1;

    if v_oil_change_id is null then
      raise exception 'p7m1_build_exec_graph: oil-change refill event missing';
    end if;

    select coc.oil_product_id, coc.qty_per_refill
    into v_product_id, v_qty
    from public.contract_oil_changes coc
    where coc.id = v_oil_change_id;
  else
    select cl.product_id, cl.qty_per_refill
    into v_product_id, v_qty
    from public.contract_lines cl
    where cl.id = v_line_id;
  end if;

  select ce.original_due_date
  into v_original_due
  from public.calendar_events ce
  where ce.id = v_event_id;

  v_visit_id := gen_random_uuid();
  v_visit_number := 'P7M1-' || left(replace(v_visit_id::text, '-', ''), 12);
  -- Model an overdue visit completed three days after its original due date.
  v_completed_at := ((v_event_date + 3)::timestamp + time '12:00') at time zone 'Asia/Kuwait';
  v_actual_completion := (v_completed_at at time zone 'Asia/Kuwait')::date;

  insert into public.visits (
    id, tenant_id, visit_number, type, status,
    contract_id, customer_id, service_location_id, agent_id,
    scheduled_date, completed_at, created_by
  )
  values (
    v_visit_id,
    v_tenant_a,
    v_visit_number,
    'refill'::public.visit_type,
    'completed'::public.visit_status,
    v_contract_id,
    (v_customers ->> 'customer_id')::uuid,
    (v_customers ->> 'service_location_id')::uuid,
    v_agent,
    v_event_date,
    v_completed_at,
    v_owner
  );

  update public.calendar_events
  set
    status = 'done'::public.calendar_event_status,
    visit_id = v_visit_id
  where id = v_event_id;

  return jsonb_build_object(
    'tenant_id', v_tenant_a,
    'owner_user', v_owner,
    'contract_id', v_contract_id,
    'line_id', v_line_id,
    'customer_id', v_customers ->> 'customer_id',
    'service_location_id', v_customers ->> 'service_location_id',
    'event_id', v_event_id,
    'visit_id', v_visit_id,
    'product_id', v_product_id,
    'qty_per_refill', v_qty,
    'quantity_unit', 'ml',
    'original_due_date', v_original_due,
    'actual_completion_date', v_actual_completion,
    'completed_at', v_completed_at,
    'oil_change_id', v_oil_change_id,
    'oil_b', v_oil_b,
    'oil_a', v_fixture ->> 'oil_a'
  );
end;
$$;

create or replace function pg_temp.p7m1_insert_exec_fact(
  p_graph jsonb,
  p_overrides jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
as $$
declare
  v_fact_id uuid := gen_random_uuid();
  v_tenant_id uuid;
  v_event_id uuid;
  v_visit_id uuid;
  v_contract_id uuid;
  v_line_id uuid;
  v_product_id uuid;
  v_original_due date;
  v_actual_completion date;
  v_actual_qty numeric(15, 3);
  v_qty_unit public.unit_of_measure;
  v_contracted_qty numeric(15, 3);
  v_coverage_months int;
  v_coverage_days int;
  v_calc_next date;
  v_confirmed_next date;
  v_overridden boolean;
  v_owner uuid;
begin
  v_tenant_id := coalesce((p_overrides ->> 'tenant_id')::uuid, (p_graph ->> 'tenant_id')::uuid);
  v_event_id := coalesce((p_overrides ->> 'calendar_event_id')::uuid, (p_graph ->> 'event_id')::uuid);
  v_visit_id := coalesce((p_overrides ->> 'visit_id')::uuid, (p_graph ->> 'visit_id')::uuid);
  v_contract_id := coalesce((p_overrides ->> 'contract_id')::uuid, (p_graph ->> 'contract_id')::uuid);
  v_line_id := coalesce((p_overrides ->> 'contract_line_id')::uuid, (p_graph ->> 'line_id')::uuid);
  v_product_id := coalesce((p_overrides ->> 'product_id')::uuid, (p_graph ->> 'product_id')::uuid);
  v_original_due := coalesce((p_overrides ->> 'original_due_date')::date, (p_graph ->> 'original_due_date')::date);
  v_actual_completion := coalesce(
    (p_overrides ->> 'actual_completion_date')::date,
    (p_graph ->> 'actual_completion_date')::date
  );
  v_actual_qty := coalesce(
    (p_overrides ->> 'actual_quantity_delivered')::numeric(15, 3),
    (p_graph ->> 'qty_per_refill')::numeric(15, 3)
  );
  v_qty_unit := coalesce(
    (p_overrides ->> 'quantity_unit')::public.unit_of_measure,
    (p_graph ->> 'quantity_unit')::public.unit_of_measure
  );
  v_contracted_qty := coalesce(
    (p_overrides ->> 'contracted_quantity_per_cycle')::numeric(15, 3),
    (p_graph ->> 'qty_per_refill')::numeric(15, 3)
  );
  v_owner := coalesce((p_overrides ->> 'created_by')::uuid, (p_graph ->> 'owner_user')::uuid);

  if p_overrides ? 'coverage_months' then
    v_coverage_months := nullif(p_overrides ->> 'coverage_months', '')::int;
  elsif p_overrides ? 'coverage_days' then
    v_coverage_months := null;
  else
    v_coverage_months := 1;
  end if;

  if p_overrides ? 'coverage_days' then
    v_coverage_days := nullif(p_overrides ->> 'coverage_days', '')::int;
  else
    v_coverage_days := null;
  end if;

  if v_coverage_months is not null then
    v_calc_next := coalesce(
      (p_overrides ->> 'calculated_next_due_date')::date,
      (v_actual_completion + (v_coverage_months || ' months')::interval)::date
    );
  else
    v_calc_next := coalesce(
      (p_overrides ->> 'calculated_next_due_date')::date,
      v_actual_completion + coalesce(v_coverage_days, 30)
    );
  end if;

  v_overridden := coalesce((p_overrides ->> 'next_due_overridden')::boolean, false);
  v_confirmed_next := coalesce((p_overrides ->> 'confirmed_next_due_date')::date, v_calc_next);

  insert into public.calendar_refill_execution_facts (
    id,
    tenant_id,
    calendar_event_id,
    visit_id,
    contract_id,
    contract_line_id,
    product_id,
    original_due_date,
    actual_completion_date,
    actual_quantity_delivered,
    quantity_unit,
    contracted_quantity_per_cycle,
    coverage_months,
    coverage_days,
    calculated_next_due_date,
    confirmed_next_due_date,
    next_due_overridden,
    next_due_override_reason,
    next_due_overridden_by,
    next_due_overridden_at,
    created_by
  )
  values (
    v_fact_id,
    v_tenant_id,
    v_event_id,
    v_visit_id,
    v_contract_id,
    v_line_id,
    v_product_id,
    v_original_due,
    v_actual_completion,
    v_actual_qty,
    v_qty_unit,
    v_contracted_qty,
    v_coverage_months,
    v_coverage_days,
    v_calc_next,
    v_confirmed_next,
    v_overridden,
    nullif(p_overrides ->> 'next_due_override_reason', ''),
    nullif(p_overrides ->> 'next_due_overridden_by', '')::uuid,
    nullif(p_overrides ->> 'next_due_overridden_at', '')::timestamptz,
    v_owner
  );

  set constraints all immediate;

  return v_fact_id;
end;
$$;

-- Full-suite re-runs can leave tenant A calendar configured (later Phase R/S
-- fixtures commit settings). Restore the migration seed shape so case 1 remains
-- meaningful independently of prior suite pollution.
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.tenant_working_days
  set day_mode = null, work_start = null, work_end = null
  where tenant_id = v_tenant_a;

  update public.tenant_calendar_settings
  set
    timezone_name = null,
    working_schedule_configured = false,
    configured_at = null,
    configured_by = null,
    remind_event_workday_start = true,
    remind_previous_workday_start = true,
    updated_at = now()
  where tenant_id = v_tenant_a;
end $$;

-- 1. Provisioning: seven unreviewed rows, not configured.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_count int;
  v_settings public.tenant_calendar_settings%rowtype;
begin
  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = v_tenant_a;

  if v_settings.working_schedule_configured then
    raise exception 'case1 failed: expected unconfigured settings';
  end if;

  if v_settings.timezone_name is not null then
    raise exception 'case1 failed: timezone should be null before setup';
  end if;

  select count(*) into v_count
  from public.tenant_working_days
  where tenant_id = v_tenant_a
    and day_mode is null;

  if v_count <> 7 then
    raise exception 'case1 failed: expected seven unreviewed days, got %', v_count;
  end if;
end $$;
rollback;

-- 2. Permission seed exists.
begin;
do $$
begin
  if not exists (select 1 from public.permissions where id = 'settings.calendar.view') then
    raise exception 'case2a failed: settings.calendar.view missing';
  end if;
  if not exists (select 1 from public.permissions where id = 'settings.calendar.edit') then
    raise exception 'case2b failed: settings.calendar.edit missing';
  end if;
end $$;
rollback;

-- 3. Manager can read and update calendar settings.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_result jsonb;
begin
  v_result := public.get_calendar_settings();
  if v_result ->> 'legacy_timezone_suggestion' is null then
    raise exception 'case3 failed: legacy suggestion missing';
  end if;
  if (v_result ->> 'timezone_confirmed')::boolean then
    raise exception 'case3 failed: timezone should not be confirmed yet';
  end if;

  v_result := public.update_calendar_settings(
    jsonb_build_object(
      'timezone_name', 'Asia/Kuwait',
      'remind_event_workday_start', true,
      'remind_previous_workday_start', true,
      'days', pg_temp.p7m1_standard_days()
    )
  );

  if not (v_result ->> 'working_schedule_configured')::boolean then
    raise exception 'case3 failed: working_schedule_configured not true after save';
  end if;
end $$;
rollback;

-- 4. View-only permission can read but not update.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id like 'settings.calendar.%';

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'settings.calendar.view', '00000000-0000-0000-0000-000000000201')
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  perform public.get_calendar_settings();
  begin
    perform public.update_calendar_settings(
      jsonb_build_object(
        'timezone_name', 'Asia/Kuwait',
        'days', pg_temp.p7m1_standard_days()
      )
    );
    raise exception 'case4 failed: view-only user updated settings';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 5. calendar.view_assigned does not grant calendar settings access.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
begin
  begin
    perform public.get_calendar_settings();
    raise exception 'case5 failed: calendar.view_assigned user read settings';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 6. Invalid timezone and incomplete days rejected atomically.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_before boolean;
  v_after boolean;
begin
  select working_schedule_configured into v_before
  from public.tenant_calendar_settings
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  begin
    perform public.update_calendar_settings(
      jsonb_build_object(
        'timezone_name', 'Not/A/Timezone',
        'days', pg_temp.p7m1_standard_days()
      )
    );
    raise exception 'case6a failed: invalid timezone accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  select working_schedule_configured into v_after
  from public.tenant_calendar_settings
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  if v_before is distinct from v_after then
    raise exception 'case6b failed: settings changed after failed update';
  end if;
end $$;
rollback;

-- 7. configured_at preserved on second save.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_first timestamptz;
  v_second timestamptz;
  v_result jsonb;
begin
  perform pg_temp.p7m1_configure_calendar();
  select configured_at into v_first
  from public.tenant_calendar_settings
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  v_result := public.update_calendar_settings(
    jsonb_build_object(
      'timezone_name', 'Asia/Dubai',
      'remind_event_workday_start', false,
      'remind_previous_workday_start', true,
      'days', pg_temp.p7m1_standard_days()
    )
  );

  select configured_at into v_second
  from public.tenant_calendar_settings
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  if v_first is null or v_second is null or v_first <> v_second then
    raise exception 'case7 failed: configured_at changed on second save';
  end if;

  if (v_result ->> 'timezone_name') <> 'Asia/Dubai' then
    raise exception 'case7b failed: timezone not updated on second save';
  end if;
end $$;
rollback;

-- 8. Direct table writes blocked for authenticated on settings.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    update public.tenant_calendar_settings
    set working_schedule_configured = true
    where tenant_id = '00000000-0000-0000-0000-000000000101';
    raise exception 'case8 failed: direct settings update allowed';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- 9. original_due_date forced on insert and immutable.
begin;
set local role postgres;
do $$
declare
  v_event_id uuid := gen_random_uuid();
  v_row public.calendar_events%rowtype;
begin
  insert into public.calendar_events (
    id, tenant_id, type, scheduled_date, title_ar, title_en, original_due_date
  )
  values (
    v_event_id,
    '00000000-0000-0000-0000-000000000101',
    'custom'::public.calendar_event_type,
    '2026-08-15',
    'اختبار',
    'Test',
    '2026-01-01'
  );

  select * into v_row from public.calendar_events where id = v_event_id;
  if v_row.original_due_date <> '2026-08-15'::date then
    raise exception 'case9a failed: original_due_date not forced from scheduled_date';
  end if;

  begin
    update public.calendar_events
    set original_due_date = '2026-01-01'
    where id = v_event_id;
    raise exception 'case9b failed: original_due_date mutation allowed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 10. Internal helper works without auth session.
begin;
set local role postgres;
do $$
declare
  v_result jsonb;
begin
  v_result := public.resolve_tenant_working_window(
    '00000000-0000-0000-0000-000000000101',
    current_date
  );
  if v_result ->> 'tenant_id' is null then
    raise exception 'case10 failed: resolve helper returned empty tenant';
  end if;
end $$;
rollback;

-- 11. Authenticated cannot read execution facts table.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform 1 from public.calendar_refill_execution_facts limit 1;
    raise exception 'case11 failed: authenticated selected execution facts';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- 12. Audit row written on settings update (exactly one semantic row per save).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_before int;
  v_after int;
  v_delta int;
begin
  select count(*) into v_before
  from public.audit_log
  where entity_type = 'tenant_calendar_settings'
    and tenant_id = '00000000-0000-0000-0000-000000000101';

  perform pg_temp.p7m1_configure_calendar();

  select count(*) into v_after
  from public.audit_log
  where entity_type = 'tenant_calendar_settings'
    and tenant_id = '00000000-0000-0000-0000-000000000101';

  v_delta := v_after - v_before;
  if v_delta <> 1 then
    raise exception 'case12 failed: expected audit delta 1, got %', v_delta;
  end if;
end $$;
rollback;

-- 13. list_calendar_timezones returns rows.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.list_calendar_timezones('Asia') tz;

  if v_count = 0 then
    raise exception 'case13 failed: timezone search returned zero rows';
  end if;
end $$;
rollback;

-- 14. Overdue helper unconfigured vs configured.
begin;
set local role postgres;
do $$
declare
  v_event_id uuid := gen_random_uuid();
  v_unconfigured jsonb;
begin
  insert into public.calendar_events (
    id, tenant_id, type, status, scheduled_date, title_ar, title_en
  )
  values (
    v_event_id,
    '00000000-0000-0000-0000-000000000101',
    'custom'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    current_date - 3,
    'متأخر',
    'Overdue test'
  );

  v_unconfigured := public.derive_calendar_event_overdue(v_event_id);
  if v_unconfigured ->> 'state' <> 'unconfigured_schedule' then
    raise exception 'case14a failed: expected unconfigured_schedule, got %', v_unconfigured;
  end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m1_configure_calendar(); end $$;
set local role postgres;
do $$
declare
  v_event_id uuid := gen_random_uuid();
  v_overdue jsonb;
begin
  insert into public.calendar_events (
    id, tenant_id, type, status, scheduled_date, title_ar, title_en
  )
  values (
    v_event_id,
    '00000000-0000-0000-0000-000000000101',
    'custom'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    current_date - 5,
    'متأخر',
    'Overdue configured'
  );

  v_overdue := public.derive_calendar_event_overdue(v_event_id);
  if (v_overdue ->> 'state') <> 'overdue' then
    raise exception 'case14b failed: expected overdue, got %', v_overdue;
  end if;
end $$;
rollback;

-- 15. Invalid working time 99:99 rejected with validation_failed.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_bad_days jsonb;
begin
  v_bad_days := jsonb_set(
    pg_temp.p7m1_standard_days(),
    '{0,work_start}',
    '"99:99"'::jsonb
  );

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select public.update_calendar_settings(%L::jsonb)$sql$,
      jsonb_build_object(
        'timezone_name', 'Asia/Kuwait',
        'days', v_bad_days
      )::text
    )
  );
end $$;
rollback;

-- 16. Invalid working time 24:00 rejected with validation_failed.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_bad_days jsonb;
begin
  v_bad_days := jsonb_set(
    pg_temp.p7m1_standard_days(),
    '{0,work_end}',
    '"24:00"'::jsonb
  );

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select public.update_calendar_settings(%L::jsonb)$sql$,
      jsonb_build_object(
        'timezone_name', 'Asia/Kuwait',
        'days', v_bad_days
      )::text
    )
  );
end $$;
rollback;

-- 17. End before start rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_bad_days jsonb;
begin
  v_bad_days := jsonb_set(
    jsonb_set(pg_temp.p7m1_standard_days(), '{0,work_start}', '"17:00"'::jsonb),
    '{0,work_end}',
    '"08:00"'::jsonb
  );

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select public.update_calendar_settings(%L::jsonb)$sql$,
      jsonb_build_object(
        'timezone_name', 'Asia/Kuwait',
        'days', v_bad_days
      )::text
    )
  );
end $$;
rollback;

-- 18. Fewer than seven days rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_short_days jsonb;
begin
  select jsonb_agg(value)
  into v_short_days
  from (
    select value
    from jsonb_array_elements(pg_temp.p7m1_standard_days())
    limit 6
  ) s;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select public.update_calendar_settings(%L::jsonb)$sql$,
      jsonb_build_object(
        'timezone_name', 'Asia/Kuwait',
        'days', v_short_days
      )::text
    )
  );
end $$;
rollback;

-- 19. Configured invariant rejects null day_mode after configured.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m1_configure_calendar(); end $$;
set local role postgres;
do $$
begin
  update public.tenant_working_days
  set day_mode = null,
      work_start = null,
      work_end = null
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and iso_weekday = 1;

  begin
    set constraints all immediate;
    raise exception 'case19 failed: null day_mode accepted when configured';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 20. Direct DELETE working day when configured rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m1_configure_calendar(); end $$;
set local role postgres;
do $$
begin
  begin
    delete from public.tenant_working_days
    where tenant_id = '00000000-0000-0000-0000-000000000101'
      and iso_weekday = 2;
    raise exception 'case20 failed: configured working-day delete allowed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 21. Disposable tenant delete cascade allowed.
begin;
set local role postgres;
do $$
declare
  v_tenant uuid := gen_random_uuid();
  v_slug text := 'p7m1-disposable-' || left(replace(v_tenant::text, '-', ''), 10);
  v_count int;
begin
  insert into public.tenants (id, name, slug, default_locale, country_code, timezone)
  values (v_tenant, 'P7M1 Disposable', v_slug, 'en', 'KW', 'Asia/Kuwait');

  update public.tenant_calendar_settings
  set
    timezone_name = 'Asia/Kuwait',
    working_schedule_configured = true,
    configured_at = now(),
    configured_by = '00000000-0000-0000-0000-000000000201'
  where tenant_id = v_tenant;

  update public.tenant_working_days
  set
    day_mode = 'working_hours'::public.tenant_working_day_mode,
    work_start = time '08:00',
    work_end = time '17:00'
  where tenant_id = v_tenant;

  set constraints all immediate;

  delete from public.tenants where id = v_tenant;

  select count(*) into v_count
  from public.tenant_working_days
  where tenant_id = v_tenant;

  if v_count <> 0 then
    raise exception 'case21 failed: working days survived tenant delete (% rows)', v_count;
  end if;
end $$;
rollback;

-- 22. Cross-tenant: tenant B manager cannot read tenant A settings.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m1_configure_calendar(); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.tenant_calendar_settings
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  if v_count <> 0 then
    raise exception 'case22 failed: tenant B manager read % tenant A settings rows', v_count;
  end if;
end $$;
rollback;

-- 23. Anon blocked on get_calendar_settings.
begin;
set local role anon;
do $$
begin
  begin
    perform public.get_calendar_settings();
    raise exception 'case23 failed: anon read calendar settings';
  exception
    when others then
      if sqlerrm not like '%permission_denied%'
        and sqlerrm not like '%tenant_not_found%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 24. calendar.view alone cannot access settings.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in (
      'settings.calendar.view',
      'settings.calendar.edit',
      'calendar.view_assigned'
    );

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'calendar.view', '00000000-0000-0000-0000-000000000201')
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  begin
    perform public.get_calendar_settings();
    raise exception 'case24 failed: calendar.view user read settings';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 25. Direct INSERT/UPDATE/DELETE on tenant_working_days blocked for authenticated.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    insert into public.tenant_working_days (tenant_id, iso_weekday)
    values ('00000000-0000-0000-0000-000000000101', 1);
    raise exception 'case25a failed: direct working-day insert allowed';
  exception
    when insufficient_privilege then null;
  end;

  begin
    update public.tenant_working_days
    set day_mode = 'day_off'::public.tenant_working_day_mode
    where tenant_id = '00000000-0000-0000-0000-000000000101'
      and iso_weekday = 1;
    raise exception 'case25b failed: direct working-day update allowed';
  exception
    when insufficient_privilege then null;
  end;

  begin
    delete from public.tenant_working_days
    where tenant_id = '00000000-0000-0000-0000-000000000101'
      and iso_weekday = 1;
    raise exception 'case25c failed: direct working-day delete allowed';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- 26. scheduled_date update does not change original_due_date.
begin;
set local role postgres;
do $$
declare
  v_event_id uuid := gen_random_uuid();
  v_original date;
begin
  insert into public.calendar_events (
    id, tenant_id, type, status, scheduled_date, title_ar, title_en
  )
  values (
    v_event_id,
    '00000000-0000-0000-0000-000000000101',
    'custom'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    current_date + 10,
    'جدولة',
    'Schedule test'
  );

  select original_due_date into v_original
  from public.calendar_events
  where id = v_event_id;

  update public.calendar_events
  set scheduled_date = current_date + 20
  where id = v_event_id;

  if (
    select original_due_date from public.calendar_events where id = v_event_id
  ) is distinct from v_original then
    raise exception 'case26 failed: original_due_date changed after scheduled_date update';
  end if;
end $$;
rollback;

-- 27. M12 smoke: rental creates contract_generated refill_due with source_metadata.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m1.customers', pg_temp.p7m1_customer_setup()::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m1.fixture', pg_temp.p7m1_inventory_setup(current_setting('test.p7m1.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m1.fixture')::jsonb;
  v_contract_id uuid;
begin
  v_contract_id := pg_temp.p7m1_create_rental(v_fixture);
  perform set_config('test.p7m1.ctx.v_contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := nullif(current_setting('test.p7m1.ctx.v_contract_id', true), '')::uuid;
  v_count int;
begin
  select count(*) into v_count
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.source_metadata is not null;

  if v_count < 1 then
    raise exception 'case27 failed: expected refill_due with source_metadata, got %', v_count;
  end if;
end $$;
rollback;

-- 28. Execution fact happy path: contract line product.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_fact_id uuid;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  v_fact_id := pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  if not exists (select 1 from public.calendar_refill_execution_facts where id = v_fact_id) then
    raise exception 'case28 failed: line-product fact not persisted';
  end if;
end $$;
rollback;

-- 29. Execution fact happy path: oil change metadata product and quantity.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_fact_id uuid;
  v_oil_change_id uuid;
  v_product_id uuid;
  v_qty numeric(15, 3);
begin
  v_graph := pg_temp.p7m1_build_exec_graph(true);
  v_oil_change_id := (v_graph ->> 'oil_change_id')::uuid;

  select coc.oil_product_id, coc.qty_per_refill
  into v_product_id, v_qty
  from public.contract_oil_changes coc
  where coc.id = v_oil_change_id;

  if (v_graph ->> 'product_id')::uuid is distinct from v_product_id
    or (v_graph ->> 'qty_per_refill')::numeric is distinct from v_qty then
    raise exception 'case29 failed: graph product/qty mismatch oil change row';
  end if;

  v_fact_id := pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  if not exists (
    select 1
    from public.calendar_refill_execution_facts f
    where f.id = v_fact_id
      and f.product_id = v_product_id
      and f.contracted_quantity_per_cycle = v_qty
  ) then
    raise exception 'case29 failed: oil-change fact not aligned with change row';
  end if;
end $$;
rollback;

-- 30. Execution fact happy path: coverage_months.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_fact_id uuid;
  v_expected_next date;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  v_expected_next := (
    (v_graph ->> 'actual_completion_date')::date + interval '3 months'
  )::date;
  v_fact_id := pg_temp.p7m1_insert_exec_fact(
    v_graph,
    jsonb_build_object('coverage_months', 3, 'coverage_days', null)
  );

  if not exists (
    select 1
    from public.calendar_refill_execution_facts f
    where f.id = v_fact_id
      and f.coverage_months = 3
      and f.coverage_days is null
      and f.calculated_next_due_date = v_expected_next
      and f.calculated_next_due_date
        <> (f.original_due_date + interval '3 months')::date
  ) then
    raise exception 'case30 failed: coverage_months fact missing';
  end if;
end $$;
rollback;

-- 31. Execution fact happy path: coverage_days.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_fact_id uuid;
  v_expected_next date;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  v_expected_next := (v_graph ->> 'actual_completion_date')::date + 45;
  v_fact_id := pg_temp.p7m1_insert_exec_fact(
    v_graph,
    jsonb_build_object('coverage_months', null, 'coverage_days', 45)
  );

  if not exists (
    select 1
    from public.calendar_refill_execution_facts f
    where f.id = v_fact_id
      and f.coverage_days = 45
      and f.coverage_months is null
      and f.calculated_next_due_date = v_expected_next
      and f.calculated_next_due_date <> f.original_due_date + 45
  ) then
    raise exception 'case31 failed: coverage_days fact missing';
  end if;
end $$;
rollback;

-- 32. Execution fact happy path: override with reason/user/timestamp.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_fact_id uuid;
  v_override_at timestamptz := '2026-08-05 10:00:00+00';
  v_confirmed date := '2027-02-01';
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  v_fact_id := pg_temp.p7m1_insert_exec_fact(
    v_graph,
    jsonb_build_object(
      'next_due_overridden', true,
      'confirmed_next_due_date', v_confirmed,
      'next_due_override_reason', 'Customer requested delay',
      'next_due_overridden_by', v_graph ->> 'owner_user',
      'next_due_overridden_at', v_override_at
    )
  );

  if not exists (
    select 1
    from public.calendar_refill_execution_facts f
    where f.id = v_fact_id
      and f.next_due_overridden
      and f.confirmed_next_due_date = v_confirmed
      and f.next_due_override_reason = 'Customer requested delay'
  ) then
    raise exception 'case32 failed: override fact missing';
  end if;
end $$;
rollback;

-- 33. Reject unconfigured calendar.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  update public.tenant_calendar_settings
  set working_schedule_configured = false,
      timezone_name = null
  where tenant_id = (v_graph ->> 'tenant_id')::uuid;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, '{}'::jsonb)$sql$,
      v_graph::text
    )
  );
end $$;
rollback;

-- 34. Reject wrong event type billing_due.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_billing_event uuid;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  select ce.id into v_billing_event
  from public.calendar_events ce
  where ce.contract_id = (v_graph ->> 'contract_id')::uuid
    and ce.type = 'billing_due'::public.calendar_event_type
  limit 1;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('calendar_event_id', v_billing_event)::text
    )
  );
end $$;
rollback;

-- 35. Reject wrong event type custom.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_custom_event uuid := gen_random_uuid();
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  insert into public.calendar_events (
    id, tenant_id, type, status, scheduled_date, title_ar, title_en,
    contract_id, contract_line_id, customer_id, service_location_id, visit_id
  )
  values (
    v_custom_event,
    (v_graph ->> 'tenant_id')::uuid,
    'custom'::public.calendar_event_type,
    'done'::public.calendar_event_status,
    (v_graph ->> 'original_due_date')::date,
    'مخصص',
    'Custom',
    (v_graph ->> 'contract_id')::uuid,
    (v_graph ->> 'line_id')::uuid,
    (v_graph ->> 'customer_id')::uuid,
    (v_graph ->> 'service_location_id')::uuid,
    (v_graph ->> 'visit_id')::uuid
  );

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('calendar_event_id', v_custom_event)::text
    )
  );
end $$;
rollback;

-- 36. Reject event not done.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  update public.calendar_events
  set status = 'pending'::public.calendar_event_status
  where id = (v_graph ->> 'event_id')::uuid;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, '{}'::jsonb)$sql$,
      v_graph::text
    )
  );
end $$;
rollback;

-- 37. Reject visit not completed.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  update public.visits
  set status = 'scheduled'::public.visit_status,
      completed_at = null
  where id = (v_graph ->> 'visit_id')::uuid;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, '{}'::jsonb)$sql$,
      v_graph::text
    )
  );
end $$;
rollback;

-- 38. Reject visit wrong type.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  update public.visits
  set type = 'collection'::public.visit_type
  where id = (v_graph ->> 'visit_id')::uuid;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, '{}'::jsonb)$sql$,
      v_graph::text
    )
  );
end $$;
rollback;

-- 39. Reject visit_id mismatch.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_other_visit uuid := gen_random_uuid();
  v_visit_number text;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  v_visit_number := 'P7M1-' || left(replace(v_other_visit::text, '-', ''), 12);

  insert into public.visits (
    id, tenant_id, visit_number, type, status,
    contract_id, customer_id, service_location_id, agent_id,
    scheduled_date, completed_at, created_by
  )
  values (
    v_other_visit,
    (v_graph ->> 'tenant_id')::uuid,
    v_visit_number,
    'refill'::public.visit_type,
    'completed'::public.visit_status,
    (v_graph ->> 'contract_id')::uuid,
    (v_graph ->> 'customer_id')::uuid,
    (v_graph ->> 'service_location_id')::uuid,
    '00000000-0000-0000-0000-000000000601',
    (v_graph ->> 'original_due_date')::date,
    (v_graph ->> 'completed_at')::timestamptz,
    (v_graph ->> 'owner_user')::uuid
  );

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('visit_id', v_other_visit)::text
    )
  );
end $$;
rollback;

-- 40. Reject tenant mismatch (composite FK rejects before deferred integrity).
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object('tenant_id', '00000000-0000-0000-0000-000000000102')
    );
    raise exception 'case40 failed: tenant mismatch fact accepted';
  exception
    when foreign_key_violation then null;
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 41. Reject contract mismatch.
begin;
set local role postgres;
do $$
declare
  v_graph_a jsonb;
  v_graph_b jsonb;
begin
  v_graph_a := pg_temp.p7m1_build_exec_graph(false);
  v_graph_b := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph_a::text,
      jsonb_build_object(
        'contract_id', v_graph_b ->> 'contract_id',
        'contract_line_id', v_graph_b ->> 'line_id'
      )::text
    )
  );
end $$;
rollback;

-- 42. Reject contract line mismatch.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_asset_line uuid;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  select cl.id
  into v_asset_line
  from public.contract_lines cl
  where cl.contract_id = (v_graph ->> 'contract_id')::uuid
    and cl.line_type = 'asset'::public.contract_line_type
  limit 1;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('contract_line_id', v_asset_line)::text
    )
  );
end $$;
rollback;

-- 43. Reject product mismatch on line path.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('product_id', v_graph ->> 'oil_b')::text
    )
  );
end $$;
rollback;

-- 44. Reject oil A product with oil B change quantity.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_oil_b_qty numeric(15, 3);
begin
  v_graph := pg_temp.p7m1_build_exec_graph(true);

  select coc.qty_per_refill
  into v_oil_b_qty
  from public.contract_oil_changes coc
  where coc.id = (v_graph ->> 'oil_change_id')::uuid;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object(
        'product_id', v_graph ->> 'oil_a',
        'contracted_quantity_per_cycle', v_oil_b_qty
      )::text
    )
  );
end $$;
rollback;

-- 45. Reject quantity unit mismatch.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('quantity_unit', 'piece')::text
    )
  );
end $$;
rollback;

-- 46. Reject contracted quantity mismatch.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('contracted_quantity_per_cycle', 999.000)::text
    )
  );
end $$;
rollback;

-- 47. Reject completion date mismatch.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('actual_completion_date', '2020-01-01')::text
    )
  );
end $$;
rollback;

-- 48. Reject original_due_date mismatch.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('original_due_date', '2020-01-01')::text
    )
  );
end $$;
rollback;

-- 49. Reject zero actual quantity.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('actual_quantity_delivered', 0)::text
    )
  );
end $$;
rollback;

-- 50. Reject negative contracted quantity.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, %L::jsonb)$sql$,
      v_graph::text,
      jsonb_build_object('contracted_quantity_per_cycle', -1)::text
    )
  );
end $$;
rollback;

-- 51. Reject coverage null both.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object('coverage_months', null, 'coverage_days', null)
    );
    raise exception 'case51 failed: both-null coverage accepted';
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%check%' and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 52. Reject coverage both set.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object('coverage_months', 1, 'coverage_days', 30)
    );
    raise exception 'case52 failed: dual coverage accepted';
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%check%' and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 53. Reject zero coverage.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object('coverage_months', 0, 'coverage_days', null)
    );
    raise exception 'case53 failed: zero coverage accepted';
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%check%' and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 54. Reject override without reason.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object(
        'next_due_overridden', true,
        'confirmed_next_due_date', '2027-03-01',
        'next_due_overridden_by', v_graph ->> 'owner_user',
        'next_due_overridden_at', '2026-08-05T10:00:00+00'
      )
    );
    raise exception 'case54 failed: override without reason accepted';
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%check%' and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 55. Reject override without actor.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object(
        'next_due_overridden', true,
        'confirmed_next_due_date', '2027-03-01',
        'next_due_override_reason', 'missing actor',
        'next_due_overridden_at', '2026-08-05T10:00:00+00'
      )
    );
    raise exception 'case55 failed: override without actor accepted';
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%check%' and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 56. Reject override without timestamp.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object(
        'next_due_overridden', true,
        'confirmed_next_due_date', '2027-03-01',
        'next_due_override_reason', 'missing timestamp',
        'next_due_overridden_by', v_graph ->> 'owner_user'
      )
    );
    raise exception 'case56 failed: override without timestamp accepted';
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%check%' and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 57. Reject non-override confirmed != calculated.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  begin
    perform pg_temp.p7m1_insert_exec_fact(
      v_graph,
      jsonb_build_object(
        'next_due_overridden', false,
        'confirmed_next_due_date', '2099-01-01'
      )
    );
    raise exception 'case57 failed: mismatched confirmed date accepted';
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%check%' and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 58. Post-fact immutability: reject event status change.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  perform pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  begin
    update public.calendar_events
    set status = 'pending'::public.calendar_event_status
    where id = (v_graph ->> 'event_id')::uuid;
    raise exception 'case58 failed: event status change allowed after fact';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 59. Post-fact immutability: reject event visit_id change.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  perform pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  begin
    update public.calendar_events
    set visit_id = gen_random_uuid()
    where id = (v_graph ->> 'event_id')::uuid;
    raise exception 'case59 failed: event visit_id change allowed after fact';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 60. Post-fact immutability: reject visit status change.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  perform pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  begin
    update public.visits
    set status = 'cancelled'::public.visit_status
    where id = (v_graph ->> 'visit_id')::uuid;
    raise exception 'case60 failed: visit status change allowed after fact';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 61. Post-fact immutability: reject visit completed_at change.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  perform pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  begin
    update public.visits
    set completed_at = now() + interval '1 day'
    where id = (v_graph ->> 'visit_id')::uuid;
    raise exception 'case61 failed: visit completed_at change allowed after fact';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 62. ACL: authenticated SELECT on execution facts blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform 1 from public.calendar_refill_execution_facts limit 1;
    raise exception 'case62 failed: authenticated SELECT allowed';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- 63. ACL: authenticated INSERT on execution facts blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    insert into public.calendar_refill_execution_facts (
      tenant_id, calendar_event_id, visit_id, contract_id, contract_line_id,
      product_id, original_due_date, actual_completion_date,
      actual_quantity_delivered, quantity_unit, contracted_quantity_per_cycle,
      coverage_months, calculated_next_due_date, confirmed_next_due_date, created_by
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      gen_random_uuid(),
      gen_random_uuid(),
      gen_random_uuid(),
      gen_random_uuid(),
      gen_random_uuid(),
      current_date,
      current_date,
      1,
      'ml',
      1,
      1,
      current_date,
      current_date,
      '00000000-0000-0000-0000-000000000201'
    );
    raise exception 'case63 failed: authenticated INSERT allowed';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- 64. ACL: authenticated UPDATE on execution facts blocked.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_fact_id uuid;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  v_fact_id := pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  begin
    update public.calendar_refill_execution_facts
    set actual_quantity_delivered = 999
    where id = v_fact_id;
    raise exception 'case64 failed: authenticated UPDATE allowed';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- 65. ACL: authenticated DELETE on execution facts blocked.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_fact_id uuid;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);
  v_fact_id := pg_temp.p7m1_insert_exec_fact(v_graph, '{}'::jsonb);

  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  begin
    delete from public.calendar_refill_execution_facts where id = v_fact_id;
    raise exception 'case65 failed: authenticated DELETE allowed';
  exception
    when insufficient_privilege then null;
  end;
end $$;
rollback;

-- 66. Reject completed visit aligned to a different customer.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_other_customer uuid;
  v_other_location uuid;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  v_other_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل مختلف P7M1',
      'phone_primary', '+9655' || left(replace(gen_random_uuid()::text, '-', ''), 7),
      'create_account', true
    )
  );
  v_other_location := public.create_customer_service_location(
    v_other_customer,
    jsonb_build_object(
      'name', 'موقع عميل مختلف P7M1',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550017002'
    )
  );

  update public.visits
  set customer_id = v_other_customer,
      service_location_id = v_other_location
  where id = (v_graph ->> 'visit_id')::uuid;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, '{}'::jsonb)$sql$,
      v_graph::text
    )
  );
end $$;
rollback;

-- 67. Reject completed visit aligned to another location for the same customer.
begin;
set local role postgres;
do $$
declare
  v_graph jsonb;
  v_other_location uuid;
begin
  v_graph := pg_temp.p7m1_build_exec_graph(false);

  v_other_location := public.create_customer_service_location(
    (v_graph ->> 'customer_id')::uuid,
    jsonb_build_object(
      'name', 'موقع ثان P7M1',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550017003'
    )
  );

  update public.visits
  set service_location_id = v_other_location
  where id = (v_graph ->> 'visit_id')::uuid;

  perform pg_temp.p7m1_expect_validation_failed(
    format(
      $sql$select pg_temp.p7m1_insert_exec_fact(%L::jsonb, '{}'::jsonb)$sql$,
      v_graph::text
    )
  );
end $$;
rollback;

select 'phase_7_calendar_working_schedule_verification_passed' as result;
