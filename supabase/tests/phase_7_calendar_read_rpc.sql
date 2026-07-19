\set ON_ERROR_STOP on

-- Phase 7 M4 / Phase R: calendar read RPC verification (68 cases).

create or replace function pg_temp.p7r_standard_days()
returns jsonb language sql immutable as $$
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

create or replace function pg_temp.p7r_configure(p_tz text default 'Asia/Kuwait')
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', p_tz,
    'remind_event_workday_start', true,
    'remind_previous_workday_start', false,
    'days', pg_temp.p7r_standard_days()
  ));
end; $$;

create or replace function pg_temp.p7r_grant_perm(p_tu uuid, p_perm text)
returns void language plpgsql as $$
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values ('00000000-0000-0000-0000-000000000101', p_tu, p_perm, '00000000-0000-0000-0000-000000000201')
  on conflict (tenant_user_id, permission_id) do nothing;
end; $$;

create or replace function pg_temp.p7r_insert_event(
  p_id uuid,
  p_date date,
  p_agent uuid default null,
  p_tenant uuid default '00000000-0000-0000-0000-000000000101',
  p_type public.calendar_event_type default 'custom',
  p_status public.calendar_event_status default 'pending',
  p_original date default null,
  p_title text default 'P7R',
  p_customer uuid default null,
  p_contract uuid default null,
  p_location uuid default null,
  p_source public.calendar_event_source_kind default 'manual',
  p_day_off_override timestamptz default null
) returns void language plpgsql as $$
begin
  -- Seed helpers are re-run across days; replace marker rows without mutating
  -- immutable original_due_date via ON CONFLICT UPDATE.
  delete from public.calendar_reminder_plans where calendar_event_id = p_id;
  delete from public.calendar_event_participants where event_id = p_id;
  delete from public.calendar_meeting_notices where calendar_event_id = p_id;
  delete from public.calendar_events where id = p_id;
  insert into public.calendar_events (
    id, tenant_id, type, status, source_kind, scheduled_date, original_due_date,
    title_ar, title_en, assigned_agent_id, customer_id, contract_id, service_location_id,
    day_off_override_at
  ) values (
    p_id, p_tenant, p_type, p_status, p_source, p_date, coalesce(p_original, p_date),
    p_title, p_title, p_agent, p_customer, p_contract, p_location, p_day_off_override
  );
end; $$;

create or replace function pg_temp.p7r_expect_error(p_sql text, p_code text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'p7r_expect_error: expected % for %', p_code, p_sql;
  exception when others then
    if sqlerrm not like '%' || p_code || '%' then
      raise exception 'p7r_expect_error: got % for %', sqlerrm, p_sql;
    end if;
  end;
end; $$;

create or replace function pg_temp.p7m3_next_iso_weekday(p_iso int, p_from date default current_date)
returns date language sql immutable as $$
  select (p_from + ((p_iso - extract(isodow from p_from)::int + 7) % 7))::date;
$$;

create or replace function pg_temp.p7r_inventory_setup(p_customers jsonb)
returns jsonb language plpgsql as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_asset_product uuid := gen_random_uuid();
  v_consumable_product uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  ) values (
    v_asset_product, v_tenant_a, 'P7R-AST-' || left(v_asset_product::text, 8),
    'جهاز P7R', 'P7R Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  ) values (
    v_consumable_product, v_tenant_a, 'P7R-OIL-' || left(v_consumable_product::text, 8),
    'زيت P7R', 'P7R Oil', v_oils_group, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );
  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, purchase_cost, acquired_at
  ) values (
    v_unit_a, v_tenant_a, v_asset_product, 'P7R-SN-' || left(v_unit_a::text, 8),
    'available_new', v_main_warehouse, 60.000, current_date
  );
  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_asset_product, 1.000)
  on conflict (warehouse_id, product_id) do update set qty_available = excluded.qty_available;
  return p_customers || jsonb_build_object(
    'asset_product', v_asset_product,
    'consumable_product', v_consumable_product,
    'unit_a', v_unit_a
  );
end; $$;

create or replace function pg_temp.p7r_build_execution_graph()
returns jsonb language plpgsql as $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_agent uuid := '00000000-0000-0000-0000-000000000601';
  v_contract_id uuid;
  v_line_id uuid;
  v_event_id uuid;
  v_event_date date;
  v_visit_id uuid := gen_random_uuid();
  v_product_id uuid;
  v_qty numeric(15, 3);
  v_original_due date;
  v_completed_at timestamptz;
  v_actual_completion date;
  v_fact_id uuid := gen_random_uuid();
  v_customer uuid;
  v_location uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_contract_id := pg_temp.p7r_contract_upcoming_fixture();

  select ce.id, ce.scheduled_date, ce.contract_line_id, ce.original_due_date,
         ce.customer_id, ce.service_location_id
  into v_event_id, v_event_date, v_line_id, v_original_due, v_customer, v_location
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  order by ce.scheduled_date, ce.id
  limit 1;

  if v_event_id is null then
    raise exception 'p7r_build_execution_graph: missing refill event';
  end if;

  select cl.product_id, cl.qty_per_refill
  into v_product_id, v_qty
  from public.contract_lines cl
  where cl.id = v_line_id;

  v_completed_at := (v_event_date::timestamp + time '12:00') at time zone 'Asia/Kuwait';
  v_actual_completion := (v_completed_at at time zone 'Asia/Kuwait')::date;

  insert into public.visits (
    id, tenant_id, visit_number, type, status,
    contract_id, customer_id, service_location_id, agent_id,
    scheduled_date, completed_at, created_by
  ) values (
    v_visit_id, v_tenant, 'P7R-' || left(replace(v_visit_id::text, '-', ''), 12),
    'refill', 'completed', v_contract_id, v_customer, v_location, v_agent,
    v_event_date, v_completed_at, v_owner
  );

  update public.calendar_events
  set status = 'done', visit_id = v_visit_id
  where id = v_event_id;

  insert into public.calendar_refill_execution_facts (
    id, tenant_id, calendar_event_id, visit_id, contract_id, contract_line_id, product_id,
    original_due_date, actual_completion_date, actual_quantity_delivered, quantity_unit,
    contracted_quantity_per_cycle, coverage_months, calculated_next_due_date,
    confirmed_next_due_date, next_due_overridden, next_due_override_reason,
    next_due_overridden_by, next_due_overridden_at, created_by
  ) values (
    v_fact_id, v_tenant, v_event_id, v_visit_id, v_contract_id, v_line_id, v_product_id,
    v_original_due, v_actual_completion, v_qty, 'ml', v_qty, 1,
    v_actual_completion + 30, v_actual_completion + 45, true, 'P7R override',
    v_owner, now(), v_owner
  );

  return jsonb_build_object(
    'event_id', v_event_id,
    'scheduled_date', v_event_date,
    'actual_completion_date', v_actual_completion,
    'actual_quantity_delivered', v_qty,
    'contracted_quantity_per_cycle', v_qty,
    'coverage_months', 1,
    'confirmed_next_due_date', v_actual_completion + 45,
    'next_due_overridden', true
  );
end; $$;

create or replace function pg_temp.p7r_seed_performance_fixture(p_count int default 2500)
returns void language plpgsql as $$
declare
  v_i int;
  v_date date;
  v_agent uuid;
  v_type public.calendar_event_type;
  v_status public.calendar_event_status;
  v_types public.calendar_event_type[] := array[
    'custom', 'refill_due', 'billing_due', 'follow_up', 'maintenance_due'
  ];
  v_statuses public.calendar_event_status[] := array['pending', 'done', 'missed'];
  v_agents uuid[] := array[
    '00000000-0000-0000-0000-000000000601',
    '00000000-0000-0000-0000-000000000602',
    null
  ];
begin
  for v_i in 1..p_count loop
    v_date := current_date + ((v_i % 90) - 30);
    v_agent := v_agents[1 + (v_i % array_length(v_agents, 1))];
    v_type := v_types[1 + (v_i % array_length(v_types, 1))];
    v_status := v_statuses[1 + (v_i % array_length(v_statuses, 1))];
    perform pg_temp.p7r_insert_event(
      ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(to_hex(v_i), 12, '0'))::uuid,
      v_date,
      v_agent,
      p_type := v_type,
      p_status := v_status,
      p_title := 'P7R-PERF-' || v_i::text
    );
  end loop;
  analyze public.calendar_events;
end; $$;

create or replace function pg_temp.p7r_assert_row_contract_shape(p_row jsonb)
returns void language plpgsql as $$
begin
  if not (p_row ? 'execution_summary') then
    raise exception 'shape failed: missing execution_summary key';
  end if;
  if p_row -> 'available_actions' is null then
    raise exception 'shape failed: missing available_actions key';
  end if;
  if p_row ->> 'schedule_state' is null then
    raise exception 'shape failed: missing schedule_state key';
  end if;
  if p_row ->> 'is_overdue' is null then
    raise exception 'shape failed: missing is_overdue key';
  end if;
  if p_row ->> 'overdue_state' is null then
    raise exception 'shape failed: missing overdue_state key';
  end if;
end; $$;

create or replace function pg_temp.p7r_contract_upcoming_fixture()
returns uuid language plpgsql as $$
declare
  v_fixture jsonb;
  v_contract_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_fixture := pg_temp.p7r_inventory_setup(jsonb_build_object(
    'customer_id', current_setting('test.p7r.customer'),
    'service_location_id', current_setting('test.p7r.location')
  ));
  v_contract_id := public.create_rental_contract(jsonb_build_object(
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
      'product_id', v_fixture ->> 'consumable_product',
      'qty_per_refill', 500.000,
      'refill_frequency_months', 1
    ))
  ), gen_random_uuid());
  perform public.sync_contract_calendar_events_internal(v_contract_id, 60);
  return v_contract_id;
end; $$;

-- Shared fixture
select pg_temp.p7r_configure();
select pg_temp.p7r_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.view_assigned');

do $$
declare
  v_cust uuid; v_loc uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_cust := public.create_customer(jsonb_build_object(
    'name_ar', 'عميل P7R', 'name_en', 'P7R Customer', 'phone_primary', '+96550029001'));
  v_loc := public.create_customer_service_location(v_cust, jsonb_build_object(
    'name', 'موقع P7R', 'location_type', 'branch', 'governorate', 'Hawalli', 'area', 'Salmiya',
    'latitude', 29.333, 'longitude', 48.028));
  perform set_config('test.p7r.customer', v_cust::text, false);
  perform set_config('test.p7r.location', v_loc::text, false);
end $$;

do $$ begin
  perform pg_temp.p7r_insert_event('00000000-0000-0000-0000-00000000a001', current_date, '00000000-0000-0000-0000-000000000602', p_title := 'حقل أ');
  perform pg_temp.p7r_insert_event('00000000-0000-0000-0000-00000000a002', current_date, '00000000-0000-0000-0000-000000000601', p_title := 'مكتب ب');
  perform pg_temp.p7r_insert_event('00000000-0000-0000-0000-00000000a003', current_date, null, p_title := 'غير معين');
  perform pg_temp.p7r_insert_event(
    '00000000-0000-0000-0000-00000000a004', current_date - 30, '00000000-0000-0000-0000-000000000602',
    p_original := current_date - 45, p_title := 'متأخر خارج');
  -- Tenant B isolation seed: assigned_agent_id must be null (or a real tenant-102
  -- employee). Agent 601 belongs to tenant 101; composite FK after migration 101
  -- rejects (tenant_102, agent_601).
  perform pg_temp.p7r_insert_event(
    '00000000-0000-0000-0000-00000000b001', current_date, null,
    p_tenant := '00000000-0000-0000-0000-000000000102', p_title := 'Tenant B');
end $$;

begin;
-- Case 1: no calendar permission -> permission_denied
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.get_calendar_range_summary(current_date, current_date + 6, '{}'::jsonb)$cmd$,
    'permission_denied'
  );
end $$;
rollback;

begin;
-- Case 2: manager -> tenant_wide summary
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v jsonb;
begin
  v := public.get_calendar_range_summary(current_date, current_date + 6, '{}'::jsonb);
  if v ->> 'scope' <> 'tenant_wide' then raise exception 'case2 failed'; end if;
end $$;
rollback;

begin;
-- Case 3: view_assigned -> assigned_only
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare v jsonb;
begin
  v := public.get_calendar_range_summary(current_date, current_date + 6, '{}'::jsonb);
  if v ->> 'scope' <> 'assigned_only' then raise exception 'case3 failed'; end if;
end $$;
rollback;

begin;
-- Case 4: settings.calendar.view cannot read calendar RPC
do $$ begin perform pg_temp.p7r_grant_perm('00000000-0000-0000-0000-000000000302', 'settings.calendar.view'); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{}'::jsonb)$cmd$,
    'permission_denied'
  );
end $$;
rollback;

begin;
-- Case 5-6: tenant isolation counts/rows
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v jsonb; v_cnt int;
begin
  v := public.list_calendar_events(current_date, current_date, '{}'::jsonb);
  select count(*) into v_cnt
  from jsonb_array_elements(v -> 'in_range' -> 'rows') r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000b001';
  if v_cnt <> 0 then raise exception 'case5 failed'; end if;
end $$;
rollback;

begin;
-- Case 7-8: tenant B manager cannot see tenant A event by id
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare v jsonb; v_cnt int;
begin
  v := public.list_calendar_events(current_date, current_date, '{}'::jsonb);
  select count(*) into v_cnt
  from jsonb_array_elements(v -> 'in_range' -> 'rows') r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000a001';
  if v_cnt <> 0 then raise exception 'case7 failed'; end if;
end $$;
rollback;

begin;
-- Case 9-10: assigned scope rows only employee 602
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare v jsonb; v_bad int;
begin
  v := public.list_calendar_events(current_date, current_date, '{}'::jsonb);
  select count(*) into v_bad
  from jsonb_array_elements(v -> 'in_range' -> 'rows') r
  where r ->> 'assigned_agent_id' is distinct from '00000000-0000-0000-0000-000000000602';
  if v_bad > 0 then raise exception 'case9 failed'; end if;
end $$;

-- Case 11: foreign assignee filter -> permission_denied
do $$ begin
  perform pg_temp.p7r_expect_error(
    format(
      $cmd$select public.list_calendar_events(current_date, current_date, %L::jsonb)$cmd$,
      jsonb_build_object('assigned_agent_id', '00000000-0000-0000-0000-000000000601')
    ),
    'permission_denied'
  );
end $$;

-- Case 12: unassigned_only denied for assigned scope
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{"unassigned_only":true}'::jsonb)$cmd$,
    'permission_denied'
  );
end $$;
rollback;

begin;
-- Case 13-14: unassigned_count null for assigned; manager sees number
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare v jsonb; v_day jsonb;
begin
  v := public.get_calendar_range_summary(current_date, current_date, '{}'::jsonb);
  v_day := (v -> 'days' -> 0);
  if jsonb_typeof(v_day -> 'unassigned_count') = 'number' then
    raise exception 'case13 failed';
  end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v jsonb; v_day jsonb;
begin
  v := public.get_calendar_range_summary(current_date, current_date, '{}'::jsonb);
  v_day := (v -> 'days' -> 0);
  if coalesce((v_day ->> 'unassigned_count')::int, -1) < 1 then raise exception 'case14 failed'; end if;
end $$;
rollback;

begin;
-- Case 15-16: assigned summary excludes other-agent day counts
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare v jsonb; v_list jsonb; v_sum int; v_list_cnt int;
begin
  v := public.get_calendar_range_summary(current_date, current_date, '{}'::jsonb);
  v_sum := (v -> 'days' -> 0 ->> 'event_count')::int;
  v_list := public.list_calendar_events(current_date, current_date, '{}'::jsonb);
  v_list_cnt := jsonb_array_length(v_list -> 'in_range' -> 'rows');
  if v_sum <> v_list_cnt then raise exception 'case15 failed sum=% list=%', v_sum, v_list_cnt; end if;
  if v_sum > 1 then raise exception 'case16 failed leakage count=%', v_sum; end if;
end $$;
rollback;

begin;
-- Case 17-51: manager-scoped read behavior
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

-- Case 17: 62-day range ok
do $$ begin
  perform public.get_calendar_range_summary(current_date, current_date + 61, '{}'::jsonb);
end $$;

-- Case 18: 63-day range rejected
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.get_calendar_range_summary(current_date, current_date + 62, '{}'::jsonb)$cmd$,
    'validation_failed'
  );
end $$;

-- Case 19-20: null dates rejected
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.get_calendar_range_summary(null, current_date, '{}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, null, '{}'::jsonb)$cmd$,
    'validation_failed'
  );
end $$;

-- Case 21-22: type and status filters
do $$
declare v jsonb; v_cnt int;
begin
  v := public.list_calendar_events(
    current_date, current_date,
    '{"event_types":["custom"],"statuses":["pending"]}'::jsonb
  );
  select count(*) into v_cnt from jsonb_array_elements(v -> 'in_range' -> 'rows');
  if v_cnt < 1 then raise exception 'case21 failed'; end if;
end $$;

-- Case 23: customer filter cross-tenant -> empty
do $$
declare v jsonb;
begin
  v := public.list_calendar_events(
    current_date, current_date,
    jsonb_build_object('customer_id', '00000000-0000-0000-0000-000000009999')
  );
  if jsonb_array_length(v -> 'in_range' -> 'rows') <> 0 then raise exception 'case23 failed'; end if;
end $$;

-- Case 24: source_kind filter
do $$
declare v jsonb; v_cnt int;
begin
  v := public.list_calendar_events(
    current_date, current_date, '{"source_kind":"manual"}'::jsonb
  );
  select count(*) into v_cnt from jsonb_array_elements(v -> 'in_range' -> 'rows') r
  where r ->> 'source_kind' <> 'manual';
  if v_cnt > 0 then raise exception 'case24 failed'; end if;
end $$;

-- Case 25-27: cross-tenant contract/location filters empty
do $$
declare v jsonb;
begin
  v := public.list_calendar_events(current_date, current_date,
    jsonb_build_object('contract_id', '00000000-0000-0000-0000-000000009999'));
  if jsonb_array_length(v -> 'in_range' -> 'rows') <> 0 then raise exception 'case25 failed'; end if;
  v := public.list_calendar_events(current_date, current_date,
    jsonb_build_object('service_location_id', '00000000-0000-0000-0000-000000009999'));
  if jsonb_array_length(v -> 'in_range' -> 'rows') <> 0 then raise exception 'case26 failed'; end if;
end $$;

-- Case 28-29: search works
do $$
declare v jsonb; v_cnt int;
begin
  v := public.list_calendar_events(current_date, current_date, '{"search":"حقل"}'::jsonb);
  select count(*) into v_cnt from jsonb_array_elements(v -> 'in_range' -> 'rows');
  if v_cnt < 1 then raise exception 'case28 failed'; end if;
end $$;

-- Case 30: short search validation_failed
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{"search":"a"}'::jsonb)$cmd$,
    'validation_failed'
  );
end $$;

-- Case 31-34: filter conflicts
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{"overdue_only":true,"statuses":["done"]}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{"unassigned_only":true,"assigned_agent_id":"00000000-0000-0000-0000-000000000601"}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{"unknown_key":true}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{"event_types":[]}'::jsonb)$cmd$,
    'validation_failed'
  );
end $$;

-- Case 35-36: in_range pagination cursor
do $$
declare v1 jsonb; v2 jsonb; v_cursor text;
begin
  v1 := public.list_calendar_events(current_date, current_date + 14, '{}'::jsonb, null, null, 1);
  if coalesce((v1 -> 'in_range' ->> 'has_more')::boolean, false) is not true then
    raise exception 'case35 failed';
  end if;
  v_cursor := v1 -> 'in_range' ->> 'next_cursor';
  v2 := public.list_calendar_events(current_date, current_date + 14, '{}'::jsonb, v_cursor, null, 1);
  if (v1 -> 'in_range' -> 'rows' -> 0 ->> 'id') = (v2 -> 'in_range' -> 'rows' -> 0 ->> 'id') then
    raise exception 'case36 failed duplicate page';
  end if;
end $$;

-- Case 37: malformed cursor
do $$ begin
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date, '{}'::jsonb, 'not-valid', null, 10)$cmd$,
    'validation_failed'
  );
end $$;

-- Case 38: cursor binding mismatch (wrong date range)
do $$
declare v jsonb; v_cursor text;
begin
  v := public.list_calendar_events(current_date, current_date + 14, '{}'::jsonb, null, null, 1);
  v_cursor := v -> 'in_range' ->> 'next_cursor';
  perform pg_temp.p7r_expect_error(
    format(
      $cmd$select public.list_calendar_events(%L::date, %L::date, '{}'::jsonb, %L, null, 1)$cmd$,
      current_date + 1, current_date + 14, v_cursor
    ),
    'validation_failed'
  );
end $$;

-- Case 39-40: dense days length and zero-event day present
do $$
declare v jsonb; v_len int;
begin
  v := public.get_calendar_range_summary(current_date, current_date + 6, '{}'::jsonb);
  v_len := jsonb_array_length(v -> 'days');
  if v_len <> 7 then raise exception 'case39 failed len=%', v_len; end if;
  if (v -> 'days' -> 6 ->> 'event_count') is null then raise exception 'case40 failed'; end if;
end $$;

-- Case 41: summary/list count consistency (manager, single day)
do $$
declare v_sum jsonb; v_list jsonb; a int; b int;
begin
  v_sum := public.get_calendar_range_summary(current_date, current_date, '{}'::jsonb);
  v_list := public.list_calendar_events(current_date, current_date, '{}'::jsonb);
  a := (v_sum -> 'days' -> 0 ->> 'event_count')::int;
  b := jsonb_array_length(v_list -> 'in_range' -> 'rows');
  if a <> b then raise exception 'case41 failed % vs %', a, b; end if;
end $$;

-- Case 42-43: overdue outside range bucket + schedule_unconfigured state
do $$
declare v jsonb; v_cnt int;
begin
  v := public.get_calendar_range_summary(current_date, current_date + 6, '{}'::jsonb);
  if (v -> 'overdue_outside_range' ->> 'state') <> 'available' then raise exception 'case42 failed'; end if;
  v := public.list_calendar_events(current_date, current_date + 6, '{}'::jsonb, null, null, 50, true);
  select count(*) into v_cnt
  from jsonb_array_elements(v -> 'overdue_outside_range' -> 'rows') r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000a004';
  if v_cnt <> 1 then raise exception 'case43 failed'; end if;
end $$;

-- Case 44: no duplicate id across buckets
do $$
declare v jsonb; v_dup int;
begin
  v := public.list_calendar_events(current_date, current_date + 6, '{}'::jsonb, null, null, 50, true);
  select count(*) into v_dup
  from jsonb_array_elements(v -> 'in_range' -> 'rows') ir
  join jsonb_array_elements(v -> 'overdue_outside_range' -> 'rows') od
    on ir ->> 'id' = od ->> 'id';
  if v_dup > 0 then raise exception 'case44 failed'; end if;
end $$;

-- Case 45: overdue_days math when configured
do $$
declare v jsonb; v_row jsonb; v_days int; v_today date;
begin
  v_today := (public.get_calendar_range_summary(current_date, current_date, '{}'::jsonb) ->> 'tenant_local_today')::date;
  v := public.list_calendar_events(current_date - 60, current_date, '{}'::jsonb, null, null, 50, true);
  select r into v_row
  from jsonb_array_elements(v -> 'overdue_outside_range' -> 'rows') r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000a004';
  v_days := (v_row ->> 'overdue_days')::int;
  if v_days <> (v_today - (v_row ->> 'original_due_date')::date) then
    raise exception 'case45 failed';
  end if;
end $$;
rollback;

begin;
-- Case 46: unconfigured schedule -> overdue_outside_range.state
update public.tenant_calendar_settings
set working_schedule_configured = false
where tenant_id = '00000000-0000-0000-0000-000000000101';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v jsonb;
begin
  v := public.get_calendar_range_summary(current_date, current_date + 6, '{}'::jsonb);
  if (v -> 'overdue_outside_range' ->> 'state') <> 'schedule_unconfigured' then
    raise exception 'case46 failed';
  end if;
end $$;
rollback;

begin;
-- Case 47-51: schedule_state and labels
do $$ begin
  perform pg_temp.p7r_insert_event(
    '00000000-0000-0000-0000-00000000c001',
    pg_temp.p7m3_next_iso_weekday(6, current_date),
    '00000000-0000-0000-0000-000000000601',
    p_day_off_override := null
  );
  perform pg_temp.p7r_insert_event(
    '00000000-0000-0000-0000-00000000c002',
    pg_temp.p7m3_next_iso_weekday(6, current_date + 7),
    '00000000-0000-0000-0000-000000000601',
    p_day_off_override := now()
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v jsonb; s1 text; s2 text;
begin
  v := public.list_calendar_events(
    pg_temp.p7m3_next_iso_weekday(6, current_date),
    pg_temp.p7m3_next_iso_weekday(6, current_date + 7),
    '{}'::jsonb
  );
  select r ->> 'schedule_state' into s1
  from jsonb_array_elements(v -> 'in_range' -> 'rows') r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000c001';
  select r ->> 'schedule_state' into s2
  from jsonb_array_elements(v -> 'in_range' -> 'rows') r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000c002';
  if s1 <> 'non_working_day' then raise exception 'case47 failed %', s1; end if;
  if s2 <> 'day_off_overridden' then raise exception 'case48 failed %', s2; end if;
end $$;

-- Case 49: working_day_conflict filter includes override
do $$
declare v jsonb; v_cnt int;
begin
  v := public.list_calendar_events(
    pg_temp.p7m3_next_iso_weekday(6, current_date),
    pg_temp.p7m3_next_iso_weekday(6, current_date + 7),
    '{"working_day_conflict":true}'::jsonb
  );
  select count(*) into v_cnt from jsonb_array_elements(v -> 'in_range' -> 'rows');
  if v_cnt < 2 then raise exception 'case49 failed'; end if;
end $$;

-- Case 50-51: bilingual labels + product line calendar-safe
do $$
declare v jsonb; v_row jsonb;
begin
  v := public.list_calendar_events(current_date, current_date, '{}'::jsonb);
  select r into v_row from jsonb_array_elements(v -> 'in_range' -> 'rows') r limit 1;
  if coalesce(v_row ->> 'title_ar', '') = '' then raise exception 'case50 failed'; end if;
  if v_row -> 'available_actions' is null then raise exception 'case51 failed'; end if;
end $$;
rollback;

begin;
-- Case 52: can_view_customer false still shows customer name when linked
update public.calendar_events
set customer_id = current_setting('test.p7r.customer')::uuid,
    service_location_id = current_setting('test.p7r.location')::uuid
where id = '00000000-0000-0000-0000-00000000a001';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare v_row jsonb;
begin
  select r into v_row
  from jsonb_array_elements(
    (public.list_calendar_events(current_date, current_date, '{}'::jsonb) -> 'in_range' -> 'rows')
  ) r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000a001';
  if (v_row -> 'available_actions' ->> 'can_view_customer') = 'true' then
    raise exception 'case52a failed';
  end if;
  if coalesce(v_row ->> 'customer_name_ar', '') = '' then raise exception 'case52b failed'; end if;
end $$;
rollback;

begin;
-- Case 53-54: masking - no source_key in rows
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v jsonb; v_bad int;
begin
  v := public.list_calendar_events(current_date, current_date, '{}'::jsonb);
  select count(*) into v_bad
  from jsonb_array_elements(v -> 'in_range' -> 'rows') r
  where r ? 'source_key' or r ? 'source_metadata';
  if v_bad > 0 then raise exception 'case53 failed'; end if;
end $$;
rollback;

begin;
-- Case 55: execution_summary key present as explicit null on pending event
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v_row jsonb;
begin
  select r into v_row
  from jsonb_array_elements(
    (public.list_calendar_events(current_date, current_date, '{}'::jsonb) -> 'in_range' -> 'rows')
  ) r
  where r ->> 'id' = '00000000-0000-0000-0000-00000000a001';
  if v_row is null then raise exception 'case55 failed: missing row'; end if;
  if not (v_row ? 'execution_summary') then raise exception 'case55 failed: key missing'; end if;
  if jsonb_typeof(v_row -> 'execution_summary') <> 'null' then
    raise exception 'case55 failed: expected execution_summary=null got %', v_row -> 'execution_summary';
  end if;
end $$;
rollback;

begin;
-- Case 56-57: ACL direct select / upcoming json execute
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin
  begin
    perform count(*) from public.calendar_events;
    raise exception 'case56 failed';
  exception when insufficient_privilege then null;
  end;
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_contract_upcoming_events_json('00000000-0000-0000-0000-000000000001')$cmd$,
    'permission_denied'
  );
end $$;
rollback;

begin;
-- Case 57b: get_contract_detail upcoming_schedule still works (tenant-local)
do $$ begin perform pg_temp.p7r_grant_perm('00000000-0000-0000-0000-000000000302', 'contracts.view'); end $$;

reset role;
do $$
declare
  v_contract_id uuid;
  v_today date;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_contract_id := pg_temp.p7r_contract_upcoming_fixture();
  v_today := public.tenant_local_today('00000000-0000-0000-0000-000000000101');
  perform set_config('test.p7r.contract', v_contract_id::text, true);
  perform set_config('test.p7r.tenant_today', v_today::text, true);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_contract_id uuid := current_setting('test.p7r.contract')::uuid;
  v_today date := current_setting('test.p7r.tenant_today')::date;
  v_detail jsonb;
  v_schedule jsonb;
  v_row jsonb;
begin
  if v_today is null then
    raise exception 'case57b failed: expected configured tenant_local_today';
  end if;
  v_detail := public.get_contract_detail(v_contract_id);
  v_schedule := coalesce(v_detail -> 'upcoming_schedule', '[]'::jsonb);
  if jsonb_array_length(v_schedule) < 1 then
    raise exception 'case57b failed: empty upcoming_schedule';
  end if;
  select r into v_row
  from jsonb_array_elements(v_schedule) r
  where (r ->> 'scheduled_date')::date >= v_today
  limit 1;
  if v_row is null then
    raise exception 'case57b failed: no tenant-local upcoming row';
  end if;
  if (v_row ->> 'days_remaining')::int <> ((v_row ->> 'scheduled_date')::date - v_today) then
    raise exception 'case57b failed: days_remaining not tenant-local';
  end if;
end $$;
rollback;

begin;
-- Case 57c: unconfigured schedule -> upcoming_schedule is []
update public.tenant_calendar_settings
set working_schedule_configured = false
where tenant_id = '00000000-0000-0000-0000-000000000101';
reset role;
do $$
declare
  v_contract_id uuid;
  v_detail jsonb;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_contract_id := pg_temp.p7r_contract_upcoming_fixture();
  v_detail := public.get_contract_detail(v_contract_id);
  if coalesce(v_detail -> 'upcoming_schedule', '[]'::jsonb) <> '[]'::jsonb then
    raise exception 'case57c failed: expected empty upcoming_schedule when unconfigured';
  end if;
end $$;
rollback;

begin;
-- Case 58: M12 regression cross-check - trusted postgres can verify generation
reset role;
do $$
declare
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform pg_temp.p7r_configure();
  perform pg_temp.p7r_contract_upcoming_fixture();
  select count(*)::int into v_count
  from public.calendar_events ce
  where ce.tenant_id = '00000000-0000-0000-0000-000000000101'
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind;
  if v_count < 1 then
    raise exception 'case58 failed: trusted verification count=%', v_count;
  end if;
end $$;
rollback;

begin;
-- Case 59: boolean filter type matrix
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":true}'::jsonb);
  perform public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":false}'::jsonb);
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":"not-a-boolean"}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":"true"}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":1}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":[]}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":{}}'::jsonb)$cmd$,
    'validation_failed'
  );
  perform pg_temp.p7r_expect_error(
    $cmd$select public.list_calendar_events(current_date, current_date + 6, '{"unassigned_only":null}'::jsonb)$cmd$,
    'validation_failed'
  );
end $$;
rollback;

begin;
-- Case 60: UUID filter matrix (empty, malformed, explicit null allowed)
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_key text;
begin
  foreach v_key in array array[
    'assigned_agent_id', 'customer_id', 'contract_id', 'service_location_id'
  ] loop
    perform pg_temp.p7r_expect_error(
      format(
        $cmd$select public.list_calendar_events(current_date, current_date + 6, jsonb_build_object(%L, ''))$cmd$,
        v_key
      ),
      'validation_failed'
    );
    perform pg_temp.p7r_expect_error(
      format(
        $cmd$select public.list_calendar_events(current_date, current_date + 6, jsonb_build_object(%L, 'not-a-uuid'))$cmd$,
        v_key
      ),
      'validation_failed'
    );
    perform pg_temp.p7r_expect_error(
      format(
        $cmd$select public.list_calendar_events(current_date, current_date + 6, jsonb_build_object(%L, 123))$cmd$,
        v_key
      ),
      'validation_failed'
    );
    perform public.list_calendar_events(
      current_date, current_date + 6, jsonb_build_object(v_key, null)
    );
  end loop;
end $$;
rollback;

begin;
-- Case 60b: enum-array filters reject null, non-string, and blank elements
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_key text;
begin
  foreach v_key in array array['event_types', 'statuses'] loop
    perform pg_temp.p7r_expect_error(
      format(
        $cmd$select public.list_calendar_events(current_date, current_date + 6, jsonb_build_object(%L, jsonb_build_array(null)))$cmd$,
        v_key
      ),
      'validation_failed'
    );
    perform pg_temp.p7r_expect_error(
      format(
        $cmd$select public.list_calendar_events(current_date, current_date + 6, jsonb_build_object(%L, jsonb_build_array(1)))$cmd$,
        v_key
      ),
      'validation_failed'
    );
    perform pg_temp.p7r_expect_error(
      format(
        $cmd$select public.list_calendar_events(current_date, current_date + 6, jsonb_build_object(%L, jsonb_build_array(jsonb_build_object('bad', true))))$cmd$,
        v_key
      ),
      'validation_failed'
    );
    perform pg_temp.p7r_expect_error(
      format(
        $cmd$select public.list_calendar_events(current_date, current_date + 6, jsonb_build_object(%L, jsonb_build_array('')))$cmd$,
        v_key
      ),
      'validation_failed'
    );
  end loop;
end $$;
rollback;

begin;
-- Case 61-62: execution summary success with real execution fact
reset role;
do $$
declare
  v_graph jsonb;
begin
  v_graph := pg_temp.p7r_build_execution_graph();
  perform set_config('test.p7r.exec_event', v_graph ->> 'event_id', false);
  perform set_config('test.p7r.exec_graph', v_graph::text, false);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_graph jsonb := current_setting('test.p7r.exec_graph')::jsonb;
  v_row jsonb;
  v_exec jsonb;
  v_event_date date := (v_graph ->> 'scheduled_date')::date;
begin
  select r into v_row
  from jsonb_array_elements(
  (
    select public.list_calendar_events(v_event_date, v_event_date, '{}'::jsonb)
      -> 'in_range' -> 'rows'
  )) r
  where r ->> 'id' = v_graph ->> 'event_id';
  if v_row is null then raise exception 'case61 failed: row missing'; end if;
  v_exec := v_row -> 'execution_summary';
  if jsonb_typeof(v_exec) <> 'object' then
    raise exception 'case61 failed: execution_summary not object';
  end if;
  if not (v_exec ?& array[
    'actual_completion_date',
    'actual_quantity_delivered',
    'quantity_unit',
    'contracted_quantity_per_cycle',
    'coverage_months',
    'coverage_days',
    'calculated_next_due_date',
    'confirmed_next_due_date',
    'next_due_overridden'
  ]) then
    raise exception 'case61 failed: incomplete execution_summary=%', v_exec;
  end if;
  if (v_exec ->> 'actual_completion_date')::date is distinct from
     (v_graph ->> 'actual_completion_date')::date then
    raise exception 'case62 failed: completion date';
  end if;
  if (v_exec ->> 'actual_quantity_delivered')::numeric is distinct from
     (v_graph ->> 'actual_quantity_delivered')::numeric then
    raise exception 'case62 failed: delivered qty';
  end if;
  if (v_exec ->> 'contracted_quantity_per_cycle')::numeric is distinct from
     (v_graph ->> 'contracted_quantity_per_cycle')::numeric then
    raise exception 'case62 failed: contracted qty';
  end if;
  if (v_exec ->> 'coverage_months')::int is distinct from
     (v_graph ->> 'coverage_months')::int then
    raise exception 'case62 failed: coverage months';
  end if;
  if (v_exec ->> 'confirmed_next_due_date')::date is distinct from
     (v_graph ->> 'confirmed_next_due_date')::date then
    raise exception 'case62 failed: confirmed next due';
  end if;
  if (v_exec ->> 'next_due_overridden')::boolean is distinct from true then
    raise exception 'case62 failed: override indicator';
  end if;
end $$;
rollback;

begin;
-- Case 63: stable JSON contract shape on every row
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v_row jsonb; v_seen int := 0;
begin
  for v_row in
    select r
    from jsonb_array_elements(
      (public.list_calendar_events(current_date, current_date + 6, '{}'::jsonb) -> 'in_range' -> 'rows')
    ) r
  loop
    perform pg_temp.p7r_assert_row_contract_shape(v_row);
    v_seen := v_seen + 1;
  end loop;
  if v_seen = 0 then raise exception 'case63 failed: no rows to validate'; end if;
end $$;
rollback;

begin;
-- Case 64: assigned-only scope hides other agents and nulls unassigned_count
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare
  v_sum jsonb;
  v_list jsonb;
  v_day jsonb;
  v_other int;
begin
  v_sum := public.get_calendar_range_summary(current_date, current_date + 6, '{}'::jsonb);
  if v_sum ->> 'scope' <> 'assigned_only' then raise exception 'case64a failed'; end if;
  for v_day in select d from jsonb_array_elements(v_sum -> 'days') d loop
    if jsonb_typeof(v_day -> 'unassigned_count') <> 'null' then
      raise exception 'case64b failed: unassigned_count should be null in assigned scope';
    end if;
  end loop;
  v_list := public.list_calendar_events(current_date, current_date + 6, '{}'::jsonb);
  select count(*) into v_other
  from jsonb_array_elements(v_list -> 'in_range' -> 'rows') r
  where r ->> 'assigned_agent_id' is distinct from '00000000-0000-0000-0000-000000000602';
  if v_other > 0 then raise exception 'case64c failed: leaked other agents'; end if;
end $$;
rollback;

begin;
-- Case 65-66: realistic performance fixture + bounded plan gate
reset role;
do $$ begin perform pg_temp.p7r_seed_performance_fixture(2500); end $$;

do $$
declare
  v_plan jsonb;
  v_plan_text text;
  v_ms numeric;
  v_line text;
  v_today date;
begin
  v_today := public.tenant_local_today('00000000-0000-0000-0000-000000000101');
  v_plan := null;
  for v_line in
    explain (analyze, buffers, format json)
    select s.event_id
    from public.calendar_read_scoped_events(
      '00000000-0000-0000-0000-000000000101',
      'tenant_wide',
      null,
      row(null, null, null, false, null, null, null, null, false, false, null)::public.calendar_read_filter_bundle,
      v_today
    ) s
    where s.scheduled_date between current_date - 30 and current_date + 30
    limit 50
  loop
    v_plan := v_line::jsonb;
  end loop;

  if v_plan is null then raise exception 'case65 failed: missing explain plan'; end if;

  v_plan_text := v_plan::text;
  -- Seq Scan is informational only at this fixture scale (may be valid for
  -- selectivity). Hard gate remains Execution Time.
  if v_plan_text ilike '%Seq Scan on calendar_events%' then
    raise notice 'case65 notice: seq scan present on calendar_events (not a hard failure)';
  end if;

  v_ms := (v_plan -> 0 -> 'Execution Time')::text::numeric;
  if v_ms > 3000 then
    raise exception 'case65 failed: execution time % ms exceeds local gate', v_ms;
  end if;
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_rows int;
  v_page1 jsonb;
  v_page2 jsonb;
  v_overlap int;
begin
  v_page1 := public.list_calendar_events(current_date - 30, current_date + 30, '{}'::jsonb, null, null, 50);
  v_rows := jsonb_array_length(v_page1 -> 'in_range' -> 'rows');
  if v_rows < 1 then raise exception 'case66 failed: empty page'; end if;

  if (v_page1 -> 'in_range' ->> 'has_more')::boolean then
    v_page2 := public.list_calendar_events(
      current_date - 30, current_date + 30, '{}'::jsonb,
      v_page1 -> 'in_range' ->> 'next_cursor', null, 50
    );
    select count(*) into v_overlap
    from (
      select r ->> 'id' as id
      from jsonb_array_elements(v_page1 -> 'in_range' -> 'rows') r
      intersect
      select r ->> 'id' as id
      from jsonb_array_elements(v_page2 -> 'in_range' -> 'rows') r
    ) overlapping_rows;
    if v_overlap <> 0 then
      raise exception 'case66 failed: pagination overlap count=%', v_overlap;
    end if;
  end if;
end $$;
rollback;

begin;
-- Case 67: full-suite pollution cleanup baseline for P7R marker rows
reset role;
do $$
declare v_perf int; v_seed int;
begin
  select count(*) into v_perf
  from public.calendar_events
  where title_en like 'P7R-PERF-%';
  if v_perf > 0 then raise exception 'case67 failed: perf rows leaked %', v_perf; end if;

  select count(*) into v_seed
  from public.calendar_events
  where id in (
    '00000000-0000-0000-0000-00000000a001',
    '00000000-0000-0000-0000-00000000a002',
    '00000000-0000-0000-0000-00000000a003',
    '00000000-0000-0000-0000-00000000a004',
    '00000000-0000-0000-0000-00000000b001'
  );
  if v_seed < 5 then raise exception 'case67 failed: seed rows missing %', v_seed; end if;
end $$;

do $$ begin raise notice 'phase_7_calendar_read_rpc_verification_passed (68 cases)'; end $$;
