\set ON_ERROR_STOP on

-- Phase 7 M11 cross-module hardening (transactional; rolls back).

create or replace function pg_temp.m11x_customer_setup()
returns jsonb language plpgsql as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل M11X',
      'phone_primary', '+96550001111',
      'create_account', true
    )
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', 'موقع M11X',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550001111'
    )
  );
  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end; $$;

create or replace function pg_temp.m11x_inventory_setup(p_customers jsonb)
returns jsonb language plpgsql as $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_devices uuid := '00000000-0000-0000-0000-000000000801';
  v_oils uuid := '00000000-0000-0000-0000-000000000802';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_asset uuid := gen_random_uuid();
  v_oil uuid := gen_random_uuid();
  v_unit uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  ) values (
    v_asset, v_tenant, 'M11X-AST-' || left(v_asset::text, 8),
    'جهاز M11X', 'M11X Asset', v_devices, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  ) values (
    v_oil, v_tenant, 'M11X-OIL-' || left(v_oil::text, 8),
    'زيت M11X', 'M11X Oil', v_oils, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );
  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id,
    purchase_cost, acquired_at
  ) values (
    v_unit, v_tenant, v_asset, 'M11X-' || left(v_unit::text, 8),
    'available_new', v_wh, 60.000, current_date
  );
  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant, v_wh, v_asset, 2.000)
  on conflict (warehouse_id, product_id) do update
    set qty_available = excluded.qty_available;
  return p_customers || jsonb_build_object(
    'asset_product', v_asset,
    'oil_a', v_oil,
    'unit_a', v_unit,
    'main_warehouse', v_wh
  );
end; $$;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', 'Asia/Kuwait',
    'remind_event_workday_start', true,
    'remind_previous_workday_start', false,
    'days', jsonb_build_array(
      jsonb_build_object('iso_weekday', 1, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
      jsonb_build_object('iso_weekday', 2, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
      jsonb_build_object('iso_weekday', 3, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
      jsonb_build_object('iso_weekday', 4, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
      jsonb_build_object('iso_weekday', 5, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '13:00'),
      jsonb_build_object('iso_weekday', 6, 'day_mode', 'day_off'),
      jsonb_build_object('iso_weekday', 7, 'day_mode', '24_hours')
    )
  ));
  perform set_config('test.m11x.customers', pg_temp.m11x_customer_setup()::text, false);
end $$;
set local role postgres;
do $$ begin
  perform set_config(
    'test.m11x.fixture',
    pg_temp.m11x_inventory_setup(current_setting('test.m11x.customers')::jsonb)::text,
    false
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.m11x.fixture')::jsonb;
  v_contract uuid;
begin
  v_contract := public.create_rental_contract(jsonb_build_object(
    'customer_id', v_fixture ->> 'customer_id',
    'service_location_id', v_fixture ->> 'service_location_id',
    'start_date', current_date,
    'end_date', (current_date + interval '12 months')::date,
    'billing_day', 5,
    'refill_day', 7,
    'monthly_rental_value', '25.000',
    'asset_lines', jsonb_build_array(jsonb_build_object(
      'product_id', v_fixture ->> 'asset_product',
      'product_unit_id', v_fixture ->> 'unit_a'
    )),
    'consumable_lines', jsonb_build_array(jsonb_build_object(
      'product_id', v_fixture ->> 'oil_a',
      'qty_per_refill', 500.000,
      'refill_frequency_months', 1
    ))
  ), gen_random_uuid());
  perform set_config('test.m11x.contract_id', v_contract::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_field uuid := '00000000-0000-0000-0000-000000000602';
  v_fixture jsonb := current_setting('test.m11x.fixture')::jsonb;
  v_contract uuid := current_setting('test.m11x.contract_id')::uuid;
  v_product uuid := (v_fixture ->> 'asset_product')::uuid;
  v_warehouse uuid := (v_fixture ->> 'main_warehouse')::uuid;
  v_events int;
  v_dups int;
  v_event_id uuid;
  v_version int;
  v_plan_count int;
  v_visits_before int;
  v_visits_after int;
  v_invoices_before int;
  v_invoices_after int;
  v_journals_before int;
  v_journals_after int;
  v_stock_before numeric(15,3);
  v_stock_after numeric(15,3);
  v_list jsonb;
  v_actions jsonb;
begin
  perform public.sync_contract_calendar_events_internal(v_contract, 30);
  perform public.sync_contract_calendar_events_internal(v_contract, 30);

  select count(*) into v_events
  from public.calendar_events
  where tenant_id = v_tenant
    and contract_id = v_contract
    and source_kind = 'contract_generated';
  if v_events < 1 then
    raise exception 'm11x: no generated events';
  end if;

  select count(*) into v_dups
  from (
    select source_key
    from public.calendar_events
    where tenant_id = v_tenant
      and contract_id = v_contract
      and source_kind = 'contract_generated'
    group by source_key
    having count(*) > 1
  ) d;
  if v_dups <> 0 then
    raise exception 'm11x: duplicate source_key';
  end if;

  select id, schedule_version into v_event_id, v_version
  from public.calendar_events
  where tenant_id = v_tenant
    and contract_id = v_contract
    and source_kind = 'contract_generated'
    and status = 'pending'
  order by scheduled_date
  limit 1;

  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  select count(*) into v_plan_count
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id;
  if v_plan_count < 1 then
    raise exception 'm11x: reminder plans missing';
  end if;

  select count(*) into v_visits_before from public.visits where tenant_id = v_tenant;
  select count(*) into v_invoices_before from public.invoices where tenant_id = v_tenant;
  select count(*) into v_journals_before from public.journal_entries where tenant_id = v_tenant;
  select qty_available into v_stock_before
  from public.inventory_balances
  where tenant_id = v_tenant and warehouse_id = v_warehouse and product_id = v_product;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform public.assign_calendar_event(
    v_event_id,
    v_version,
    jsonb_build_object('assigned_agent_id', v_field::text),
    gen_random_uuid()
  );

  select count(*) into v_visits_after from public.visits where tenant_id = v_tenant;
  select count(*) into v_invoices_after from public.invoices where tenant_id = v_tenant;
  select count(*) into v_journals_after from public.journal_entries where tenant_id = v_tenant;
  select qty_available into v_stock_after
  from public.inventory_balances
  where tenant_id = v_tenant and warehouse_id = v_warehouse and product_id = v_product;

  if v_visits_after <> v_visits_before
    or v_invoices_after <> v_invoices_before
    or v_journals_after <> v_journals_before
    or v_stock_after is distinct from v_stock_before then
    raise exception 'm11x: schedule assign created finance/visit/stock side effects';
  end if;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_list := public.list_calendar_events(
    current_date - 1,
    current_date + 60,
    jsonb_build_object('contract_id', v_contract::text),
    null,
    null,
    50
  );
  select r -> 'available_actions' into v_actions
  from jsonb_array_elements(v_list -> 'in_range' -> 'rows') r
  where r ->> 'id' = v_event_id::text
  limit 1;
  if v_actions is null then
    raise exception 'm11x: generated event missing from list';
  end if;
  if coalesce((v_actions ->> 'can_edit_manual')::boolean, false) then
    raise exception 'm11x: generated event exposes can_edit_manual';
  end if;

  raise notice 'phase_7_m11_cross_module_passed';
end $$;
rollback;
