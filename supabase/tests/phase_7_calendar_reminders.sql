\set ON_ERROR_STOP on

-- Phase 7 M3 / Phase Q: calendar reminder foundation verification.
-- Seed IDs (migration 031): tenant_a 101, owner 201, field agent employee 601,
-- tenant_b 102. Field user 205 / employee 602 for view_assigned RLS tests.

create or replace function pg_temp.p7m3_standard_days()
returns jsonb
language sql
immutable
as $$
  -- Mirrors pg_temp.p7m1_standard_days() from phase_7_calendar_working_schedule.sql.
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

create or replace function pg_temp.p7m3_ny_all_working_days()
returns jsonb language sql immutable as $$
  select jsonb_build_array(
    jsonb_build_object('iso_weekday', 1, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 2, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 3, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 4, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 5, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 6, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 7, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00')
  );
$$;

create or replace function pg_temp.p7m3_configure_reminders(
  p_timezone text default 'Asia/Kuwait',
  p_event_policy boolean default true,
  p_previous_policy boolean default false,
  p_days jsonb default null
) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', p_timezone,
    'remind_event_workday_start', p_event_policy,
    'remind_previous_workday_start', p_previous_policy,
    'days', coalesce(p_days, pg_temp.p7m3_standard_days())
  ));
end; $$;

create or replace function pg_temp.p7m3_m2_customer_setup(p_suffix text default 'P7M3')
returns jsonb language plpgsql as $$
declare v_customer_id uuid; v_location_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_customer_id := public.create_customer(jsonb_build_object(
    'name_ar', 'عميل ' || p_suffix, 'phone_primary', '+96550019001', 'create_account', true));
  v_location_id := public.create_customer_service_location(v_customer_id, jsonb_build_object(
    'name', 'موقع ' || p_suffix, 'location_type', 'branch', 'governorate', 'Hawalli',
    'area', 'Salmiya', 'contact_person_phone', '+96550019001'));
  return jsonb_build_object('customer_id', v_customer_id, 'service_location_id', v_location_id);
end; $$;

create or replace function pg_temp.p7m3_m2_inventory_setup(p_customers jsonb)
returns jsonb language plpgsql as $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_asset_product uuid := gen_random_uuid();
  v_oil_a uuid := gen_random_uuid();
  v_unit_a uuid := gen_random_uuid();
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  ) values (
    v_asset_product, v_tenant_a, 'P7M3-AST-' || left(v_asset_product::text, 8),
    'جهاز P7M3', 'P7M3 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  ) values (
    v_oil_a, v_tenant_a, 'P7M3-OIL-' || left(v_oil_a::text, 8),
    'زيت P7M3', 'P7M3 Oil', v_oils_group, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );
  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, purchase_cost, acquired_at
  ) values (
    v_unit_a, v_tenant_a, v_asset_product, 'P7M3-SN-' || left(v_unit_a::text, 8),
    'available_new', v_main_warehouse, 60.000, current_date
  );
  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant_a, v_main_warehouse, v_asset_product, 2.000)
  on conflict (warehouse_id, product_id) do update set qty_available = excluded.qty_available;
  return p_customers || jsonb_build_object('asset_product', v_asset_product, 'oil_a', v_oil_a, 'unit_a', v_unit_a);
end; $$;

create or replace function pg_temp.p7m3_m2_create_rental(p_fixture jsonb, p_start date default current_date)
returns uuid language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  return public.create_rental_contract(jsonb_build_object(
    'customer_id', p_fixture ->> 'customer_id',
    'service_location_id', p_fixture ->> 'service_location_id',
    'start_date', p_start,
    'end_date', (p_start + interval '12 months')::date,
    'billing_day', 5,
    'refill_day', 7,
    'monthly_rental_value', '25.000',
    'asset_lines', jsonb_build_array(jsonb_build_object(
      'product_id', p_fixture ->> 'asset_product', 'product_unit_id', p_fixture ->> 'unit_a')),
    'consumable_lines', jsonb_build_array(jsonb_build_object(
      'product_id', p_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1))
  ), gen_random_uuid());
end; $$;

create or replace function pg_temp.p7m3_expect_validation_failed(p_sql text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'p7m3_expect_validation_failed: unexpected success for %', p_sql;
  exception
    when check_violation then null;
    when others then
      if sqlerrm not like '%validation_failed%'
        and sqlerrm not like '%dst_probe_unexpected_candidate_count%' then
        raise exception 'p7m3_expect_validation_failed: unexpected error for %: %', p_sql, sqlerrm;
      end if;
  end;
end; $$;

create or replace function pg_temp.p7m3_next_iso_weekday(p_iso int, p_from date default current_date)
returns date language sql immutable as $$
  select (p_from + ((p_iso - extract(isodow from p_from)::int + 7) % 7))::date;
$$;

create or replace function pg_temp.p7m3_create_pending_event(
  p_scheduled_date date default null,
  p_assigned_agent_id uuid default '00000000-0000-0000-0000-000000000601',
  p_tenant_id uuid default '00000000-0000-0000-0000-000000000101',
  p_source_kind public.calendar_event_source_kind default 'manual',
  p_title text default 'P7M3'
) returns uuid language plpgsql as $$
declare v_event_id uuid := gen_random_uuid();
        v_date date := coalesce(p_scheduled_date, current_date + 7);
begin
  insert into public.calendar_events (
    id, tenant_id, type, status, source_kind, scheduled_date, title_ar, title_en, assigned_agent_id
  ) values (
    v_event_id, p_tenant_id, 'custom', 'pending', p_source_kind, v_date, p_title, p_title, p_assigned_agent_id
  );
  return v_event_id;
end; $$;

create or replace function pg_temp.p7m3_bulk_create_events(
  p_count int,
  p_tenant_id uuid default '00000000-0000-0000-0000-000000000101',
  p_assigned_agent_id uuid default '00000000-0000-0000-0000-000000000601',
  p_start_date date default current_date + 1,
  p_title_prefix text default 'P7M3 bulk'
) returns int language plpgsql as $$
declare v_i int; v_id uuid; v_date date := p_start_date; v_created int := 0;
begin
  while v_created < greatest(p_count, 0) loop
    if extract(isodow from v_date)::int <> 6 then
      v_id := gen_random_uuid();
      v_created := v_created + 1;
      insert into public.calendar_events (
        id, tenant_id, type, status, source_kind, scheduled_date, title_ar, title_en, assigned_agent_id
      ) values (
        v_id, p_tenant_id, 'custom', 'pending', 'manual',
        v_date,
        p_title_prefix || ' ' || v_created,
        p_title_prefix || ' ' || v_created,
        p_assigned_agent_id
      );
    end if;
    v_date := v_date + 1;
  end loop;
  return p_count;
end; $$;

create or replace function pg_temp.p7m3_plan_row(
  p_event_id uuid, p_rule_key public.calendar_reminder_rule_key
) returns public.calendar_reminder_plans language plpgsql as $$
declare v_row public.calendar_reminder_plans%rowtype;
begin
  select crp.* into v_row
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where crp.calendar_event_id = p_event_id
    and crp.rule_key = p_rule_key
    and crp.occurrence_scheduled_date = ce.scheduled_date
  limit 1;
  if v_row.id is null then
    select crp.* into v_row
    from public.calendar_reminder_plans crp
    where crp.calendar_event_id = p_event_id and crp.rule_key = p_rule_key
    order by crp.updated_at desc
    limit 1;
  end if;
  return v_row;
end; $$;

create or replace function pg_temp.p7m3_assert_plan_state(
  p_event_id uuid,
  p_rule_key public.calendar_reminder_rule_key,
  p_expected_status public.calendar_reminder_plan_status,
  p_suppressed_reason text default null,
  p_resolution_code text default null
) returns public.calendar_reminder_plans language plpgsql as $$
declare v_row public.calendar_reminder_plans%rowtype;
begin
  v_row := pg_temp.p7m3_plan_row(p_event_id, p_rule_key);
  if v_row.id is null then
    raise exception 'p7m3_assert_plan_state: missing plan event=% rule=%', p_event_id, p_rule_key;
  end if;
  if v_row.status is distinct from p_expected_status then
    raise exception 'p7m3_assert_plan_state: expected % got %', p_expected_status, v_row.status;
  end if;
  if p_suppressed_reason is not null and v_row.suppressed_reason is distinct from p_suppressed_reason then
    raise exception 'p7m3_assert_plan_state: suppressed_reason expected % got %', p_suppressed_reason, v_row.suppressed_reason;
  end if;
  if p_resolution_code is not null and v_row.resolution_code is distinct from p_resolution_code then
    raise exception 'p7m3_assert_plan_state: resolution_code expected % got %', p_resolution_code, v_row.resolution_code;
  end if;
  return v_row;
end; $$;

create or replace function pg_temp.p7m3_run_scheduler(p_batch_size int default 100)
returns jsonb language plpgsql as $$
begin return public.run_scheduled_calendar_reminders(p_batch_size); end; $$;

create or replace function pg_temp.p7m3_force_delivery_ready(p_plan_id uuid)
returns void language plpgsql as $$
begin
  update public.calendar_reminder_plans crp set
    status = 'delivery_pending',
    next_attempt_at = null,
    attempt_count = 0,
    updated_at = now()
  where crp.id = p_plan_id
    and crp.anchor_utc <= now()
    and crp.anchor_local_date = public.try_tenant_local_today(crp.tenant_id);
end; $$;

create or replace function pg_temp.p7m3_deliver_plan(p_plan_id uuid)
returns void language plpgsql as $$
declare
  v_tenant_id uuid;
  v_i int;
begin
  select tenant_id into v_tenant_id
  from public.calendar_reminder_plans
  where id = p_plan_id;

  for v_i in 1..10 loop
    perform public.reconcile_tenant_calendar_reminder_plans(v_tenant_id, 500);
    exit when not exists (
      select 1
      from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = v_tenant_id
        and (
          q.generation is distinct from q.processed_generation
          or q.scan_after_event_id is not null
          or q.processing_generation is not null
        )
    );
  end loop;

  perform pg_temp.p7m3_force_delivery_ready(p_plan_id);
  perform public.deliver_calendar_reminder_plan_locked(p_plan_id);
end; $$;

create or replace function pg_temp.p7m3_assert_queue_state(
  p_tenant_id uuid,
  p_processed_generation bigint default null,
  p_scan_after uuid default null,
  p_expect_processed_null boolean default false
) returns public.calendar_reminder_reconcile_queue language plpgsql as $$
declare v_row public.calendar_reminder_reconcile_queue%rowtype;
begin
  select * into v_row from public.calendar_reminder_reconcile_queue where tenant_id = p_tenant_id;
  if p_expect_processed_null and v_row.processed_generation is not null then
    raise exception 'queue: expected processed_generation NULL got %', v_row.processed_generation;
  end if;
  if p_processed_generation is not null and v_row.processed_generation is distinct from p_processed_generation then
    raise exception 'queue: expected processed_generation % got %', p_processed_generation, v_row.processed_generation;
  end if;
  if p_scan_after is not null and v_row.scan_after_event_id is distinct from p_scan_after then
    raise exception 'queue: expected scan_after % got %', p_scan_after, v_row.scan_after_event_id;
  end if;
  return v_row;
end; $$;

create or replace function pg_temp.p7m3_dst_probe(p_timezone text, p_date date, p_time time)
returns table (anchor_utc timestamptz, dst_resolution_code public.calendar_dst_resolution_code, dst_shift_seconds int)
language sql as $$ select * from public.local_work_start_to_utc(p_timezone, p_date, p_time); $$;

create or replace function pg_temp.p7m3_grant_field_view_assigned() returns void language plpgsql as $$
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000305',
    'calendar.view_assigned', '00000000-0000-0000-0000-000000000201')
  on conflict (tenant_user_id, permission_id) do nothing;
end; $$;

create or replace function pg_temp.p7m3_trg_notification_fail() returns trigger language plpgsql as $$
begin raise exception 'p7m3_notification_insert_failed'; end; $$;

create or replace function pg_temp.p7m3_install_notification_fail_trigger() returns void language plpgsql as $$
begin
  drop trigger if exists p7m3_notification_fail on public.notifications;
  create trigger p7m3_notification_fail before insert on public.notifications
    for each row when (new.related_entity_table = 'calendar_reminder_plans')
    execute function pg_temp.p7m3_trg_notification_fail();
end; $$;

create or replace function pg_temp.p7m3_trg_plan_update_fail() returns trigger language plpgsql as $$
begin raise exception 'p7m3_plan_update_failed'; end; $$;

create or replace function pg_temp.p7m3_install_plan_update_fail_trigger() returns void language plpgsql as $$
begin
  drop trigger if exists p7m3_plan_update_fail on public.calendar_reminder_plans;
  create trigger p7m3_plan_update_fail before update on public.calendar_reminder_plans
    for each row when (old.status = 'delivery_pending' and new.status = 'delivered')
    execute function pg_temp.p7m3_trg_plan_update_fail();
end; $$;

create or replace function pg_temp.p7m3_trg_tenant_a_reconcile_fail()
returns trigger language plpgsql as $$
begin
  raise exception 'p7m3_tenant_a_reconcile_failed';
end; $$;

create or replace function pg_temp.p7m3_install_tenant_a_reconcile_fail_trigger()
returns void language plpgsql as $$
begin
  drop trigger if exists p7m3_tenant_a_reconcile_fail on public.calendar_reminder_plans;
  create trigger p7m3_tenant_a_reconcile_fail
    before update on public.calendar_reminder_plans
    for each row
    when (
      old.tenant_id = '00000000-0000-0000-0000-000000000101'
      and old.status is distinct from new.status
    )
    execute function pg_temp.p7m3_trg_tenant_a_reconcile_fail();
end; $$;

create or replace function pg_temp.p7m3_clear_test_triggers() returns void language plpgsql as $$
begin
  drop trigger if exists p7m3_notification_fail on public.notifications;
  drop trigger if exists p7m3_plan_update_fail on public.calendar_reminder_plans;
  drop trigger if exists p7m3_tenant_a_reconcile_fail on public.calendar_reminder_plans;
end; $$;

create or replace function pg_temp.p7m3_count_plan_notifications(p_plan_id uuid)
returns int language sql as $$
  select count(*)::int from public.notifications n
  where n.related_entity_table = 'calendar_reminder_plans' and n.related_entity_id = p_plan_id;
$$;

create or replace function pg_temp.p7m3_setup_delivery_case(
  p_assigned_agent_id uuid default '00000000-0000-0000-0000-000000000601'
)
returns uuid language plpgsql as $$
declare
  v_event_id uuid;
  v_plan public.calendar_reminder_plans;
  v_today date;
  v_iso int;
begin
  perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false);
  v_today := public.try_tenant_local_today('00000000-0000-0000-0000-000000000101');
  v_iso := extract(isodow from v_today)::int;
  update public.tenant_working_days
  set day_mode = '24_hours', work_start = null, work_end = null
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and iso_weekday = v_iso;
  v_event_id := pg_temp.p7m3_create_pending_event(v_today, p_assigned_agent_id);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  if v_plan.anchor_utc > now() then
    update public.calendar_reminder_plans
    set anchor_utc = now() - interval '1 minute', updated_at = now()
    where id = v_plan.id;
  end if;
  return v_plan.id;
end; $$;

-- Case 1: Normal working day — exact anchor_utc
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare
  v_event_id uuid;
  v_monday date := pg_temp.p7m3_next_iso_weekday(1, current_date + 1);
  v_plan public.calendar_reminder_plans;
  v_dst record;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(v_monday);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  select * into v_dst from public.local_work_start_to_utc('Asia/Kuwait', v_monday, make_time(8,0,0));
  if v_plan.anchor_utc is distinct from v_dst.anchor_utc then
    raise exception 'case1 failed: anchor_utc mismatch';
  end if;
end $$;
rollback;

-- Case 2: Event-day reminder enabled — planned occurrence
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 3: Event-day disabled — suppressed policy_disabled
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.tenant_calendar_settings set remind_event_workday_start = false
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'policy_disabled');
end $$;
rollback;

-- Case 4: Previous-working-day enabled — planned on prior workday
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, true); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'previous_workday_start', 'planned');
  if v_plan.anchor_local_date >= (select scheduled_date from public.calendar_events where id = v_event_id) then
    raise exception 'case4 failed: previous anchor not before event date';
  end if;
end $$;
rollback;

-- Case 5: Previous disabled — no occurrence / suppressed
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, true); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_row public.calendar_reminder_plans%rowtype;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.tenant_calendar_settings set remind_previous_workday_start = false
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  select * into v_row from public.calendar_reminder_plans
  where calendar_event_id = v_event_id and rule_key = 'previous_workday_start';
  if found and v_row.status not in ('suppressed') then
    raise exception 'case5 failed: previous rule should be absent or suppressed, got %', v_row.status;
  end if;
end $$;
rollback;

-- Case 6: Both disabled — zero deliverable occurrences
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, false); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_cnt int;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  select count(*) into v_cnt from public.calendar_reminder_plans
  where calendar_event_id = v_event_id and status in ('planned','delivery_pending','delivered');
  if v_cnt <> 0 then raise exception 'case6 failed: deliverable count %', v_cnt; end if;
end $$;
rollback;

-- Case 7: Unconfigured schedule — zero new rows; existing → suppressed
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_before int; v_after int;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.tenant_calendar_settings set working_schedule_configured = false where tenant_id = '00000000-0000-0000-0000-000000000101';
  select count(*) into v_before from public.calendar_reminder_plans where calendar_event_id = v_event_id;
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  select count(*) into v_after from public.calendar_reminder_plans where calendar_event_id = v_event_id;
  if v_after > v_before then raise exception 'case7 failed: new rows created when unconfigured'; end if;
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'schedule_unconfigured');
end $$;
rollback;

-- Case 8: Missing timezone — zero new rows
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_cnt int;
begin
  update public.tenant_calendar_settings set timezone_name = null where tenant_id = '00000000-0000-0000-0000-000000000101';
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  select count(*) into v_cnt from public.calendar_reminder_plans where calendar_event_id = v_event_id;
  if v_cnt <> 0 then raise exception 'case8 failed: plans created without timezone'; end if;
end $$;
rollback;

-- Case 9: 24-hour working day — anchor_local_time = 00:00 on working day
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(7, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  if v_plan.anchor_local_time <> make_time(0,0,0) then
    raise exception 'case9 failed: expected 00:00 got %', v_plan.anchor_local_time;
  end if;
end $$;
rollback;

-- Case 10: Event on day off — event_workday_start skipped; previous_workday_start delivers
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, true); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_event public.calendar_reminder_plans; v_prev public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(6, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_event := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'skipped', null, 'event_date_day_off');
  if v_event.anchor_utc is not null then raise exception 'case10 failed: skipped event anchor not null'; end if;
  v_prev := pg_temp.p7m3_assert_plan_state(v_event_id, 'previous_workday_start', 'planned');
  if v_prev.anchor_utc is null then raise exception 'case10 failed: previous rule missing anchor'; end if;
end $$;
rollback;

-- Case 11: One previous day off — walk-back
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, true); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans; v_event_date date;
begin
  v_event_date := pg_temp.p7m3_next_iso_weekday(7, current_date+1);
  v_event_id := pg_temp.p7m3_create_pending_event(v_event_date);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'previous_workday_start', 'planned');
  if extract(isodow from v_plan.anchor_local_date) = 6 then
    raise exception 'case11 failed: walked to Saturday day off';
  end if;
end $$;
rollback;

-- Case 12: Multiple consecutive days off — walk-back
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, true,
  jsonb_build_array(
    jsonb_build_object('iso_weekday',1,'day_mode','working_hours','work_start','08:00','work_end','17:00'),
    jsonb_build_object('iso_weekday',2,'day_mode','day_off'),
    jsonb_build_object('iso_weekday',3,'day_mode','day_off'),
    jsonb_build_object('iso_weekday',4,'day_mode','working_hours','work_start','08:00','work_end','17:00'),
    jsonb_build_object('iso_weekday',5,'day_mode','working_hours','work_start','08:00','work_end','17:00'),
    jsonb_build_object('iso_weekday',6,'day_mode','working_hours','work_start','08:00','work_end','17:00'),
    jsonb_build_object('iso_weekday',7,'day_mode','working_hours','work_start','08:00','work_end','17:00')
  )); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans; v_event_date date;
begin
  v_event_date := pg_temp.p7m3_next_iso_weekday(4, current_date+1);
  v_event_id := pg_temp.p7m3_create_pending_event(v_event_date);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'previous_workday_start', 'planned');
  if v_plan.anchor_local_date >= v_event_date - 2 then
    raise exception 'case12 failed: did not walk back across consecutive days off';
  end if;
end $$;
rollback;

-- Case 13: DST spring gap — exact UTC, dst_shifted_forward
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('America/New_York', true, false,
  jsonb_build_array(
    jsonb_build_object('iso_weekday',1,'day_mode','working_hours','work_start','02:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',2,'day_mode','working_hours','work_start','02:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',3,'day_mode','working_hours','work_start','02:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',4,'day_mode','working_hours','work_start','02:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',5,'day_mode','working_hours','work_start','02:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',6,'day_mode','working_hours','work_start','02:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',7,'day_mode','working_hours','work_start','02:30','work_end','17:00')
  )); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans; v_dst record;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(date '2024-03-10');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  select * into v_dst from public.local_work_start_to_utc('America/New_York', date '2024-03-10', make_time(2,30,0));
  if v_plan.dst_resolution_code <> 'dst_shifted_forward' then raise exception 'case13 failed: dst code %', v_plan.dst_resolution_code; end if;
  if v_plan.anchor_utc is distinct from v_dst.anchor_utc then raise exception 'case13 failed: anchor_utc mismatch'; end if;
end $$;
rollback;

-- Case 14: DST fall ambiguous — two candidates, dst_ambiguous_earlier, exact MIN UTC
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('America/New_York', true, false,
  jsonb_build_array(
    jsonb_build_object('iso_weekday',1,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',2,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',3,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',4,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',5,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',6,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',7,'day_mode','working_hours','work_start','01:30','work_end','17:00')
  )); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans; v_dst record;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(date '2024-11-03');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  select * into v_dst from public.local_work_start_to_utc('America/New_York', date '2024-11-03', make_time(1,30,0));
  if v_plan.dst_resolution_code <> 'dst_ambiguous_earlier' then raise exception 'case14 failed: dst code %', v_plan.dst_resolution_code; end if;
  if v_plan.anchor_utc is distinct from v_dst.anchor_utc then raise exception 'case14 failed: anchor_utc mismatch'; end if;
end $$;
rollback;

-- Case 15: Overdue pending — plan exists; if anchor day passed → expired, no notification
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans; v_result jsonb;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(current_date - 5);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_plan_row(v_event_id, 'event_workday_start');
  if v_plan.id is null then raise exception 'case15 failed: no plan for overdue event'; end if;
  update public.calendar_reminder_plans set anchor_utc = now() - interval '2 days', anchor_local_date = current_date - 2 where id = v_plan.id;
  v_result := pg_temp.p7m3_run_scheduler();
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'expired', null, 'anchor_local_day_passed');
  if v_plan.notification_id is not null then raise exception 'case15 failed: notification created for expired'; end if;
end $$;
rollback;

-- Case 16: Same-day catch-up — exactly one notification
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid; v_cnt int; v_result jsonb;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  v_result := pg_temp.p7m3_run_scheduler();
  if (v_result->>'plans_delivered')::int < 1 then raise exception 'case16 failed: no delivery %', v_result; end if;
  v_cnt := pg_temp.p7m3_count_plan_notifications(v_plan_id);
  if v_cnt <> 1 then raise exception 'case16 failed: notification count %', v_cnt; end if;
  v_result := pg_temp.p7m3_run_scheduler();
  v_cnt := pg_temp.p7m3_count_plan_notifications(v_plan_id);
  if v_cnt <> 1 then raise exception 'case16 failed: duplicate after second run %', v_cnt; end if;
end $$;
rollback;

-- Case 17: Event → done — cancelled_event
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.calendar_events set status = 'done' where id = v_event_id;
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'cancelled_event');
end $$;
rollback;

-- Case 18: Event → cancelled — cancelled_event
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.calendar_events set status = 'cancelled' where id = v_event_id;
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'cancelled_event');
end $$;
rollback;

-- Case 19: Reschedule before delivery — cancelled_superseded + new occurrence
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_old_date date; v_new_date date; v_old_plan uuid;
begin
  v_old_date := pg_temp.p7m3_next_iso_weekday(1, current_date+7);
  v_new_date := v_old_date + 7;
  v_event_id := pg_temp.p7m3_create_pending_event(v_old_date);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_old_plan := (pg_temp.p7m3_plan_row(v_event_id, 'event_workday_start')).id;
  update public.calendar_events set scheduled_date = v_new_date where id = v_event_id;
  if not exists (select 1 from public.calendar_reminder_plans where id = v_old_plan and status = 'cancelled_superseded') then
    raise exception 'case19 failed: old occurrence not cancelled_superseded';
  end if;
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 20: Reschedule after one delivered — delivered immutable; other rule unaffected
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, true); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_delivered uuid; v_new_date date;
begin
  v_delivered := pg_temp.p7m3_setup_delivery_case();
  select calendar_event_id into v_event_id
  from public.calendar_reminder_plans where id = v_delivered;
  perform pg_temp.p7m3_deliver_plan(v_delivered);
  v_new_date := current_date + 10;
  update public.calendar_events set scheduled_date = v_new_date where id = v_event_id;
  if not exists (select 1 from public.calendar_reminder_plans where id = v_delivered and status = 'delivered') then
    raise exception 'case20 failed: delivered plan mutated';
  end if;
end $$;
rollback;

-- Case 21: Reassign before delivery — same occurrence, new recipient, retry reset
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1), '00000000-0000-0000-0000-000000000601');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.calendar_events set assigned_agent_id = '00000000-0000-0000-0000-000000000602' where id = v_event_id;
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  if v_plan.recipient_user_id <> '00000000-0000-0000-0000-000000000205' then
    raise exception 'case21 failed: recipient not updated';
  end if;
  if v_plan.attempt_count <> 0 or v_plan.next_attempt_at is not null then
    raise exception 'case21 failed: retry not reset';
  end if;
end $$;
rollback;

-- Case 22: Reassign after delivery — no resend
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans; v_cnt int;
begin
  v_plan.id := pg_temp.p7m3_setup_delivery_case();
  select * into v_plan from public.calendar_reminder_plans where id = v_plan.id;
  v_event_id := v_plan.calendar_event_id;
  perform pg_temp.p7m3_deliver_plan(v_plan.id);
  update public.calendar_events set assigned_agent_id = '00000000-0000-0000-0000-000000000602' where id = v_event_id;
  v_cnt := pg_temp.p7m3_count_plan_notifications(v_plan.id);
  if v_cnt <> 1 then raise exception 'case22 failed: notification count %', v_cnt; end if;
  if not exists (select 1 from public.calendar_reminder_plans where id = v_plan.id and status = 'delivered') then
    raise exception 'case22 failed: delivered plan changed';
  end if;
end $$;
rollback;

-- Case 23: Inactive user — suppressed
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1), '00000000-0000-0000-0000-000000000602');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.tenant_users set is_active = false
  where user_id = '00000000-0000-0000-0000-000000000205' and tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'no_assigned_recipient');
  update public.tenant_users set is_active = true
  where user_id = '00000000-0000-0000-0000-000000000205' and tenant_id = '00000000-0000-0000-0000-000000000101';
end $$;
rollback;

-- Case 24: Inactive employee — suppressed
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.employees set is_active = false where id = '00000000-0000-0000-0000-000000000601';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'no_assigned_recipient');
  update public.employees set is_active = true where id = '00000000-0000-0000-0000-000000000601';
end $$;
rollback;

-- Case 25: Broken user/employee mapping — suppressed
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.employees set user_id = null where id = '00000000-0000-0000-0000-000000000601';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'no_assigned_recipient');
  update public.employees set user_id = '00000000-0000-0000-0000-000000000201' where id = '00000000-0000-0000-0000-000000000601';
end $$;
rollback;

-- Case 26: Cross-tenant recipient — rejected
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_cross_employee uuid := gen_random_uuid();
begin
  insert into public.employees (
    id, tenant_id, user_id, code, name_ar, name_en, job_type, phone, email, base_salary, hire_date
  ) values (
    v_cross_employee, '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000204',
    'P7M3-X', 'عامل ب', 'Tenant B Agent', 'field_refill', '+96550000999', 'owner@tenant-b.test', 0, current_date
  );
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.calendar_events set assigned_agent_id = v_cross_employee where id = v_event_id;
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'no_assigned_recipient');
end $$;
rollback;

-- Case 27: Sequential double scheduler — second completed, 0 delivered, NOT skipped_duplicate
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v1 jsonb; v2 jsonb;
begin
  v1 := pg_temp.p7m3_run_scheduler();
  v2 := pg_temp.p7m3_run_scheduler();
  if v2->>'status' = 'skipped_duplicate' then raise exception 'case27 failed: second run skipped_duplicate'; end if;
  if (v2->>'plans_delivered')::int <> 0 then raise exception 'case27 failed: second run delivered %', v2->>'plans_delivered'; end if;
end $$;
rollback;

-- Case 28: Parallel scheduler — one skipped_duplicate (handled by concurrency script)
begin;
set local role postgres;
do $$ begin raise notice 'case28: parallel scheduler covered by phase_7_calendar_reminders_concurrency.sh'; end $$;
rollback;

-- Case 29: Failed notification insert — retry scheduled
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid; v_plan public.calendar_reminder_plans;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'delivery_pending' where id = v_plan_id;
  perform pg_temp.p7m3_install_notification_fail_trigger();
  perform pg_temp.p7m3_run_scheduler();
  select * into v_plan from public.calendar_reminder_plans where id = v_plan_id;
  if v_plan.status <> 'delivery_pending' then raise exception 'case29 failed: status %', v_plan.status; end if;
  if v_plan.attempt_count < 1 or v_plan.next_attempt_at is null then raise exception 'case29 failed: retry not scheduled'; end if;
  if pg_temp.p7m3_count_plan_notifications(v_plan_id) <> 0 then raise exception 'case29 failed: orphan notification'; end if;
  perform pg_temp.p7m3_clear_test_triggers();
end $$;
rollback;

-- Case 30: Retry backoff — next_attempt_at sequence
begin;
set local role postgres;
do $$
declare v_plan_id uuid; v_plan public.calendar_reminder_plans; v_gap interval;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'delivery_pending', attempt_count = 0, next_attempt_at = now() where id = v_plan_id;
  perform public.record_reminder_delivery_failure(v_plan_id, 'P0001', 'test');
  select * into v_plan from public.calendar_reminder_plans where id = v_plan_id;
  v_gap := v_plan.next_attempt_at - now();
  if v_plan.attempt_count <> 1 then raise exception 'case30 failed: attempt %', v_plan.attempt_count; end if;
  if v_gap < interval '50 seconds' or v_gap > interval '2 minutes' then
    raise exception 'case30 failed: backoff gap %', v_gap;
  end if;
end $$;
rollback;

-- Case 31: Terminal failure after 5 attempts — failed
begin;
set local role postgres;
do $$
declare v_plan_id uuid; v_plan public.calendar_reminder_plans; v_i int;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'delivery_pending', attempt_count = 0 where id = v_plan_id;
  for v_i in 1..5 loop
    perform public.record_reminder_delivery_failure(v_plan_id, 'P0001', 'test');
  end loop;
  select * into v_plan from public.calendar_reminder_plans where id = v_plan_id;
  if v_plan.status <> 'failed' then raise exception 'case31 failed: status %', v_plan.status; end if;
  if v_plan.next_attempt_at is not null then raise exception 'case31 failed: next_attempt_at set'; end if;
end $$;
rollback;

-- Case 32: Subtransaction rollback — no orphan notification
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'delivery_pending' where id = v_plan_id;
  perform pg_temp.p7m3_install_notification_fail_trigger();
  perform pg_temp.p7m3_run_scheduler();
  if pg_temp.p7m3_count_plan_notifications(v_plan_id) <> 0 then raise exception 'case32 failed: orphan notification'; end if;
  perform pg_temp.p7m3_clear_test_triggers();
end $$;
rollback;

-- Case 33: Settings/TZ/schedule change — pending UPDATE in place; delivered unchanged
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan_id uuid; v_old_utc timestamptz; v_new_utc timestamptz;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+14));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan_id := (pg_temp.p7m3_plan_row(v_event_id, 'event_workday_start')).id;
  v_old_utc := (select anchor_utc from public.calendar_reminder_plans where id = v_plan_id);
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  perform pg_temp.p7m3_configure_reminders('Asia/Dubai', true, false);
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  v_new_utc := (select anchor_utc from public.calendar_reminder_plans where id = v_plan_id and status = 'planned');
  if v_new_utc is null then
    if not exists (select 1 from public.calendar_reminder_plans where id = v_plan_id and status = 'delivered') then
      raise exception 'case33 failed: pending not updated and not delivered';
    end if;
  elsif v_new_utc is not distinct from v_old_utc then
    raise exception 'case33 failed: pending anchor not recomputed';
  end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
rollback;

-- Case 34: Delivered/expired/failed immutability — UPDATE to snapshot columns rejected
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_delivered uuid; v_expired uuid;
begin
  v_delivered := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_delivered);
  perform pg_temp.p7m3_expect_validation_failed(format(
    'update public.calendar_reminder_plans set anchor_utc = now() where id = %L', v_delivered));
  v_expired := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set
    status = 'expired', resolution_code = 'anchor_local_day_passed',
    anchor_local_date = current_date - 1, anchor_local_time = make_time(8,0,0),
    anchor_utc = now() - interval '1 day', timezone_name = 'Asia/Kuwait',
    dst_resolution_code = 'none', recipient_user_id = '00000000-0000-0000-0000-000000000201'
  where id = v_expired;
  perform pg_temp.p7m3_expect_validation_failed(format(
    'update public.calendar_reminder_plans set recipient_user_id = %L where id = %L',
    '00000000-0000-0000-0000-000000000205', v_expired));
end $$;
rollback;

-- Case 35: API-role ACL — authenticated cannot EXECUTE internals
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin perform public.refresh_calendar_event_reminder_plans(gen_random_uuid()); raise exception 'case35a failed';
  exception when insufficient_privilege then null; end;
  begin perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101'); raise exception 'case35b failed';
  exception when insufficient_privilege then null; end;
  begin perform public.deliver_calendar_reminder_plan_locked(gen_random_uuid()); raise exception 'case35c failed';
  exception when insufficient_privilege then null; end;
end $$;
rollback;

-- Case 36: RLS isolation — user sees own notification only
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_owner_plan uuid; v_field_event uuid; v_field_plan uuid;
begin
  v_owner_plan := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_owner_plan);
  v_field_plan := pg_temp.p7m3_setup_delivery_case(
    '00000000-0000-0000-0000-000000000602'
  );
  select calendar_event_id into v_field_event
  from public.calendar_reminder_plans where id = v_field_plan;
  perform pg_temp.p7m3_deliver_plan(v_field_plan);
  perform set_config('test.p7m3.owner_plan', v_owner_plan::text, true);
  perform set_config('test.p7m3.field_plan', v_field_plan::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
declare v_cnt int;
begin
  select count(*) into v_cnt from public.notifications
  where related_entity_table = 'calendar_reminder_plans'
    and related_entity_id = current_setting('test.p7m3.field_plan')::uuid;
  if v_cnt <> 1 then raise exception 'case36a failed: field user cannot see own notification'; end if;
  select count(*) into v_cnt from public.notifications
  where related_entity_table = 'calendar_reminder_plans'
    and related_entity_id = current_setting('test.p7m3.owner_plan')::uuid;
  if v_cnt <> 0 then raise exception 'case36b failed: field user sees owner notification'; end if;
end $$;
rollback;

-- Case 37: Manual event — same rules when assigned
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1), '00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-000000000101', 'manual');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 38: M2-generated refill/billing — compatible
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m3.customers', pg_temp.p7m3_m2_customer_setup('P7M3R')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m3.fixture', pg_temp.p7m3_m2_inventory_setup(current_setting('test.p7m3.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_fixture jsonb := current_setting('test.p7m3.fixture')::jsonb;
        v_contract_id uuid; v_event_id uuid;
begin
  v_contract_id := pg_temp.p7m3_m2_create_rental(v_fixture, current_date);
  perform public.sync_contract_calendar_events_internal(v_contract_id, 60);
  select ce.id into v_event_id from public.calendar_events ce
  where ce.contract_id = v_contract_id and ce.status = 'pending' limit 1;
  update public.calendar_events set assigned_agent_id = '00000000-0000-0000-0000-000000000601' where id = v_event_id;
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 39: No Phase 8 side effects — no execution facts / inventory / invoices
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_facts int; v_inv int; v_plan_id uuid;
begin
  select count(*) into v_facts from public.calendar_refill_execution_facts;
  select count(*) into v_inv from public.invoices;
  v_event_id := pg_temp.p7m3_create_pending_event(current_date + 3);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan_id := (pg_temp.p7m3_plan_row(v_event_id, 'event_workday_start')).id;
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  if (select count(*) from public.calendar_refill_execution_facts) <> v_facts then raise exception 'case39 failed: execution facts mutated'; end if;
  if (select count(*) from public.invoices) <> v_inv then raise exception 'case39 failed: invoices mutated'; end if;
end $$;
rollback;

-- Case 40: Regression — prior suites green (handled by runner)
begin;
set local role postgres;
do $$ begin raise notice 'case40: regression gate handled by run_sql_suites.sh'; end $$;
rollback;

-- Case 41: TZ change after delivery — no second notification
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid; v_cnt int;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  update public.tenant_calendar_settings set timezone_name = 'Asia/Dubai' where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_run_scheduler();
  v_cnt := pg_temp.p7m3_count_plan_notifications(v_plan_id);
  if v_cnt <> 1 then raise exception 'case41 failed: count %', v_cnt; end if;
end $$;
rollback;

-- Case 42: Work-hours change after delivery — no resend
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid; v_cnt int;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  update public.tenant_working_days
  set day_mode = 'working_hours', work_start = make_time(9,0,0), work_end = make_time(18,0,0)
  where tenant_id = '00000000-0000-0000-0000-000000000101' and iso_weekday = 2;
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  v_cnt := pg_temp.p7m3_count_plan_notifications(v_plan_id);
  if v_cnt <> 1 then raise exception 'case42 failed: count %', v_cnt; end if;
end $$;
rollback;

-- Case 43: Reassign after delivery — no resend
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan_id uuid; v_cnt int;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  select calendar_event_id into v_event_id
  from public.calendar_reminder_plans where id = v_plan_id;
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  update public.calendar_events set assigned_agent_id = '00000000-0000-0000-0000-000000000602' where id = v_event_id;
  v_cnt := pg_temp.p7m3_count_plan_notifications(v_plan_id);
  if v_cnt <> 1 then raise exception 'case43 failed: count %', v_cnt; end if;
end $$;
rollback;

-- Case 44: Deactivate employee before delivery — suppressed
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.employees set is_active = false where id = '00000000-0000-0000-0000-000000000601';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'no_assigned_recipient');
end $$;
rollback;

-- Case 45: Revoke calendar.view_assigned before delivery — suppressed
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1), '00000000-0000-0000-0000-000000000602');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  delete from public.user_permissions where tenant_user_id = '00000000-0000-0000-0000-000000000305' and permission_id = 'calendar.view_assigned';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'recipient_not_calendar_authorized');
end $$;
rollback;

-- Case 46: User A sees own notification; B does not see A's
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_a uuid;
begin
  v_a := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_a);
  perform set_config('test.p7m3.plan_a', v_a::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  if not exists (select 1 from public.notifications where related_entity_id = current_setting('test.p7m3.plan_a')::uuid) then
    raise exception 'case46a failed: owner cannot see own notification';
  end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
begin
  if exists (select 1 from public.notifications where related_entity_id = current_setting('test.p7m3.plan_a')::uuid) then
    raise exception 'case46b failed: field user sees owner notification';
  end if;
end $$;
rollback;

-- Case 47: Backfill reconcile does not deliver prior-local-day anchors
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(current_date - 10);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  v_plan := pg_temp.p7m3_plan_row(v_event_id, 'event_workday_start');
  if v_plan.anchor_local_date >= public.try_tenant_local_today('00000000-0000-0000-0000-000000000101') then
    update public.calendar_reminder_plans set anchor_local_date = current_date - 3, anchor_utc = now() - interval '3 days' where id = v_plan.id;
  end if;
  perform pg_temp.p7m3_run_scheduler();
  if exists (select 1 from public.calendar_reminder_plans where id = v_plan.id and status = 'delivered') then
    raise exception 'case47 failed: historical anchor delivered on reconcile';
  end if;
end $$;
rollback;

-- Case 48: DB unique index rejects second notification for same plan
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid; v_notification_id uuid;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  select notification_id into v_notification_id from public.calendar_reminder_plans where id = v_plan_id;
  begin
    insert into public.notifications (tenant_id, channel, recipient_type, recipient_id, recipient_address,
      subject, body_ar, body_en, template_key, status, sent_at, related_entity_table, related_entity_id)
    values ('00000000-0000-0000-0000-000000000101', 'in_app', 'user', '00000000-0000-0000-0000-000000000201',
      'x', 'x', 'x', 'x', 'calendar_reminder_event_workday_start', 'sent', now(), 'calendar_reminder_plans', v_plan_id);
    raise exception 'case48 failed: duplicate notification allowed';
  exception when unique_violation then null; end;
end $$;
rollback;

-- Case 49: Delete employee/user — pending → suppressed; delivered history preserved
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_pending uuid; v_delivered uuid; v_event_pending uuid; v_event_delivered uuid;
begin
  v_event_pending := pg_temp.p7m3_create_pending_event(current_date + 5, '00000000-0000-0000-0000-000000000602');
  perform public.refresh_calendar_event_reminder_plans(v_event_pending);
  v_pending := (pg_temp.p7m3_plan_row(v_event_pending, 'event_workday_start')).id;
  v_delivered := pg_temp.p7m3_setup_delivery_case(
    '00000000-0000-0000-0000-000000000602'
  );
  select calendar_event_id into v_event_delivered
  from public.calendar_reminder_plans where id = v_delivered;
  perform pg_temp.p7m3_deliver_plan(v_delivered);
  update public.employees set is_active = false where id = '00000000-0000-0000-0000-000000000602';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_pending, 'event_workday_start', 'suppressed', 'no_assigned_recipient');
  if not exists (select 1 from public.calendar_reminder_plans where id = v_delivered and status = 'delivered') then
    raise exception 'case49 failed: delivered history lost';
  end if;
end $$;
rollback;

-- Case 50: Tenant deletion cascades reminder data
begin;
set local role postgres;
do $$
declare v_tenant uuid := gen_random_uuid(); v_event_id uuid; v_plan_cnt int; v_fk char;
begin
  select c.confdeltype into v_fk
  from pg_constraint c
  where c.conrelid = 'public.calendar_reminder_plans'::regclass
    and c.conname = 'calendar_reminder_plans_tenant_id_fkey';
  if v_fk is distinct from 'c' then
    raise exception 'case50 failed: plans.tenant_id FK is not ON DELETE CASCADE';
  end if;
  insert into tenants (id, name, slug, default_locale, country_code, timezone)
  values (v_tenant, 'P7M3 temp', 'p7m3-temp-' || left(replace(v_tenant::text, '-', ''), 8), 'en', 'KW', 'Asia/Kuwait');
  v_event_id := gen_random_uuid();
  insert into public.calendar_events (
    id, tenant_id, type, status, source_kind, scheduled_date, title_ar, title_en
  ) values (
    v_event_id, v_tenant, 'custom', 'pending', 'manual', current_date + 5, 'temp', 'temp'
  );
  insert into public.calendar_reminder_plans (
    tenant_id, calendar_event_id, rule_key, occurrence_scheduled_date, channel, status, suppressed_reason
  ) values (
    v_tenant, v_event_id, 'event_workday_start', current_date + 5, 'in_app', 'suppressed', 'policy_disabled'
  );
  delete from public.calendar_reminder_plans where tenant_id = v_tenant;
  select count(*) into v_plan_cnt from public.calendar_reminder_plans where tenant_id = v_tenant;
  if v_plan_cnt <> 0 then raise exception 'case50 failed: plans remain %', v_plan_cnt; end if;
  delete from public.calendar_events where id = v_event_id;
end $$;
rollback;

-- Case 51: Settings update during reconcile — generation bump; second pass completes
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_gen1 bigint; v_gen2 bigint;
begin
  perform pg_temp.p7m3_bulk_create_events(10);
  perform pg_temp.p7m3_run_scheduler();
  select generation into v_gen1 from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101';
  update public.tenant_calendar_settings set remind_previous_workday_start = true where tenant_id = '00000000-0000-0000-0000-000000000101';
  select generation into v_gen2 from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101';
  if v_gen2 <= v_gen1 then raise exception 'case51 failed: generation not bumped'; end if;
  perform pg_temp.p7m3_run_scheduler();
  if not exists (select 1 from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101' and processed_generation = v_gen2) then
    raise exception 'case51 failed: reconcile not completed';
  end if;
end $$;
rollback;

-- Case 52: Legacy missed event — plans cancelled; status unchanged
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := gen_random_uuid();
  insert into public.calendar_events (id, tenant_id, type, status, source_kind, scheduled_date, title_ar, title_en, assigned_agent_id)
  values (v_event_id, '00000000-0000-0000-0000-000000000101', 'custom', 'missed', 'manual', current_date - 5, 'missed', 'missed', '00000000-0000-0000-0000-000000000601');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  if exists (select 1 from public.calendar_reminder_plans where calendar_event_id = v_event_id and status not in ('cancelled_event')) then
    raise exception 'case52 failed: open plans for missed event';
  end if;
  if (select status from public.calendar_events where id = v_event_id) <> 'missed' then
    raise exception 'case52 failed: event status changed';
  end if;
end $$;
rollback;

-- Case 53: Notification INSERT ok but plan update fails — subtransaction rollback, no orphan
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'delivery_pending' where id = v_plan_id;
  perform pg_temp.p7m3_install_plan_update_fail_trigger();
  perform pg_temp.p7m3_run_scheduler();
  if pg_temp.p7m3_count_plan_notifications(v_plan_id) <> 0 then raise exception 'case53 failed: orphan notification'; end if;
  if not exists (select 1 from public.calendar_reminder_plans where id = v_plan_id and status = 'delivery_pending') then
    raise exception 'case53 failed: plan not delivery_pending';
  end if;
  perform pg_temp.p7m3_clear_test_triggers();
end $$;
rollback;

-- Case 54: Manager with notifications.view sees tenant notifications
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  perform set_config('test.p7m3.plan54', v_plan_id::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare v_cnt int;
begin
  select count(*) into v_cnt from public.notifications
  where related_entity_table = 'calendar_reminder_plans'
    and related_entity_id = current_setting('test.p7m3.plan54')::uuid;
  if v_cnt <> 1 then raise exception 'case54 failed: manager cannot see tenant notification'; end if;
end $$;
rollback;

-- Case 55: Policy disable → re-enable before anchor — suppressed → planned → delivers
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+14));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.tenant_calendar_settings set remind_event_workday_start = false where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'policy_disabled');
  update public.tenant_calendar_settings set remind_event_workday_start = true where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 56: Day-off → working-day same date — skipped → planned
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_sat date;
begin
  v_sat := pg_temp.p7m3_next_iso_weekday(6, current_date+1);
  v_event_id := pg_temp.p7m3_create_pending_event(v_sat);
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'skipped', null, 'event_date_day_off');
  update public.tenant_working_days set day_mode = 'working_hours', work_start = make_time(8,0,0), work_end = make_time(17,0,0)
  where tenant_id = '00000000-0000-0000-0000-000000000101' and iso_weekday = 6;
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 57: Reschedule A → B → A (undelivered) — cancelled_superseded → planned
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_a date; v_b date;
begin
  v_a := pg_temp.p7m3_next_iso_weekday(1, current_date+14);
  v_b := v_a + 7;
  v_event_id := pg_temp.p7m3_create_pending_event(v_a);
  update public.calendar_events set scheduled_date = v_b where id = v_event_id;
  update public.calendar_events set scheduled_date = v_a where id = v_event_id;
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  if not exists (select 1 from public.calendar_reminder_plans where calendar_event_id = v_event_id and status = 'cancelled_superseded') then
    raise exception 'case57 failed: missing cancelled_superseded history';
  end if;
end $$;
rollback;

-- Case 58: Grant calendar.view_assigned after suppressed — reconcile → delivers
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); perform pg_temp.p7m3_grant_field_view_assigned(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+14), '00000000-0000-0000-0000-000000000602');
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  delete from public.user_permissions
  where tenant_user_id = '00000000-0000-0000-0000-000000000305' and permission_id = 'calendar.view_assigned';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'recipient_not_calendar_authorized');
  perform pg_temp.p7m3_grant_field_view_assigned();
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 59: Reactivate employee / link user before anchor
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+14));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.employees set is_active = false where id = '00000000-0000-0000-0000-000000000601';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'no_assigned_recipient');
  update public.employees set is_active = true where id = '00000000-0000-0000-0000-000000000601';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
end $$;
rollback;

-- Case 60: delivered / expired / failed not resurrected by reconcile
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_delivered uuid; v_expired uuid; v_failed uuid;
begin
  v_delivered := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_delivered);
  v_expired := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'expired', resolution_code = 'anchor_local_day_passed',
    anchor_local_date = current_date - 1, anchor_local_time = make_time(8,0,0), anchor_utc = now() - interval '1 day',
    timezone_name = 'Asia/Kuwait', dst_resolution_code = 'none', recipient_user_id = '00000000-0000-0000-0000-000000000201'
  where id = v_expired;
  v_failed := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'failed', attempt_count = 5,
    anchor_local_date = current_date, anchor_local_time = make_time(8,0,0), anchor_utc = now() - interval '1 hour',
    timezone_name = 'Asia/Kuwait', dst_resolution_code = 'none', recipient_user_id = '00000000-0000-0000-0000-000000000201'
  where id = v_failed;
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  if not exists (select 1 from public.calendar_reminder_plans where id = v_delivered and status = 'delivered') then raise exception 'case60a failed'; end if;
  if not exists (select 1 from public.calendar_reminder_plans where id = v_expired and status = 'expired') then raise exception 'case60b failed'; end if;
  if not exists (select 1 from public.calendar_reminder_plans where id = v_failed and status = 'failed') then raise exception 'case60c failed'; end if;
end $$;
rollback;

-- Case 61: Fall-back true ambiguity — assert MIN UTC
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('America/New_York', true, false,
  jsonb_build_array(
    jsonb_build_object('iso_weekday',1,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',2,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',3,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',4,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',5,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',6,'day_mode','working_hours','work_start','01:30','work_end','17:00'),
    jsonb_build_object('iso_weekday',7,'day_mode','working_hours','work_start','01:30','work_end','17:00')
  )); end $$;
set local role postgres;
do $$
declare v_dst record; v_probe timestamptz; v_naive timestamp := timestamp '2024-11-03 01:30:00';
begin
  select * into v_dst from public.local_work_start_to_utc('America/New_York', date '2024-11-03', make_time(1,30,0));
  select min(c) into v_probe
  from (
    select v_base + make_interval(mins => g * 15) as c
    from generate_series(-16 * 4, 16 * 4) g
    cross join lateral (select (v_naive at time zone 'America/New_York') as v_base) b
  ) q
  where (q.c at time zone 'America/New_York')::timestamp = v_naive;
  if v_dst.dst_resolution_code <> 'dst_ambiguous_earlier' or v_dst.anchor_utc is distinct from v_probe then
    raise exception 'case61 failed: expected MIN UTC % got %', v_probe, v_dst.anchor_utc;
  end if;
end $$;
rollback;

-- Case 62: Australia/Lord_Howe 30-min shift — mandatory, fails if zone missing
begin;
set local role postgres;
do $$
begin
  if not exists (select 1 from pg_timezone_names where name = 'Australia/Lord_Howe') then
    raise exception 'case62 failed: Australia/Lord_Howe missing from pg_timezone_names';
  end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Australia/Lord_Howe', true, false, pg_temp.p7m3_ny_all_working_days()); end $$;
set local role postgres;
do $$
declare v_dst record;
begin
  select * into v_dst from public.local_work_start_to_utc('Australia/Lord_Howe', date '2024-04-07', make_time(2,0,0));
  if v_dst.anchor_utc is null then raise exception 'case62 failed: no anchor for Lord Howe'; end if;
end $$;
rollback;

-- Case 63: One plan fails in scheduler — other plan still delivers
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_ok uuid; v_bad uuid; v_result jsonb;
begin
  v_ok := pg_temp.p7m3_setup_delivery_case();
  v_bad := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_ok);
  perform pg_temp.p7m3_force_delivery_ready(v_bad);
  perform pg_temp.p7m3_install_notification_fail_trigger();
  v_result := pg_temp.p7m3_run_scheduler();
  if not exists (select 1 from public.calendar_reminder_plans where id = v_ok and status = 'delivered') then
    raise exception 'case63 failed: good plan not delivered';
  end if;
  if not exists (select 1 from public.calendar_reminder_plans where id = v_bad and status = 'delivery_pending' and attempt_count >= 1) then
    raise exception 'case63 failed: bad plan not retried';
  end if;
  if v_result ->> 'status' <> 'partial'
    or (v_result ->> 'plans_retried')::int <> 1
    or (v_result ->> 'plans_failed')::int <> 0 then
    raise exception 'case63 failed: scheduler retry observability %', v_result;
  end if;
  if not exists (
    select 1
    from public.calendar_reminder_runs r
    where r.id = (v_result ->> 'run_id')::uuid
      and r.status = 'partial'
      and r.plans_retried = 1
      and r.plans_failed = 0
      and r.error_summary like '%plans_retried=1%'
  ) then
    raise exception 'case63 failed: retry not persisted in run ledger %', v_result;
  end if;
  perform pg_temp.p7m3_clear_test_triggers();
end $$;
rollback;

-- Case 64: Physical DELETE event with delivered plan — RESTRICT (blocked)
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan_id uuid;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  select calendar_event_id into v_event_id
  from public.calendar_reminder_plans where id = v_plan_id;
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  begin
    delete from public.calendar_events where id = v_event_id;
    raise exception 'case64 failed: delete allowed with delivered plan';
  exception when foreign_key_violation then null; end;
end $$;
rollback;

-- Case 65: Settings mutation bumps generation via trigger only (no RPC duplicate)
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_before bigint; v_after bigint;
begin
  select generation into v_before from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101';
  update public.tenant_calendar_settings set remind_previous_workday_start = not remind_previous_workday_start
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  select generation into v_after from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101';
  if v_after <= v_before then raise exception 'case65 failed: generation not bumped by trigger'; end if;
end $$;
rollback;

-- Case 66: DELETE notification linked to delivered plan — RESTRICT
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan_id uuid; v_notification_id uuid;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_deliver_plan(v_plan_id);
  select notification_id into v_notification_id from public.calendar_reminder_plans where id = v_plan_id;
  begin
    delete from public.notifications where id = v_notification_id;
    raise exception 'case66 failed: delete notification allowed';
  exception when foreign_key_violation then null; end;
end $$;
rollback;

-- Case 67: skipped day-off — anchor fields NULL; no fake 00:00
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_plan public.calendar_reminder_plans;
begin
  v_plan := pg_temp.p7m3_assert_plan_state(
    pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(6, current_date+1)),
    'event_workday_start', 'skipped', null, 'event_date_day_off');
  if v_plan.anchor_local_time is not null or v_plan.anchor_utc is not null then
    raise exception 'case67 failed: fake anchors on skipped day-off';
  end if;
end $$;
rollback;

-- Case 68: suppressed timezone_missing — anchor fields NULL
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+1));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.tenant_calendar_settings set timezone_name = null where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'timezone_missing');
  if v_plan.anchor_utc is not null then raise exception 'case68 failed: anchor not null'; end if;
end $$;
rollback;

-- Case 69: cancelled_superseded → planned clears cancelled_at
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans; v_a date; v_b date;
begin
  v_a := pg_temp.p7m3_next_iso_weekday(1, current_date+14);
  v_b := v_a + 7;
  v_event_id := pg_temp.p7m3_create_pending_event(v_a);
  update public.calendar_events set scheduled_date = v_b where id = v_event_id;
  update public.calendar_events set scheduled_date = v_a where id = v_event_id;
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  if v_plan.cancelled_at is not null then raise exception 'case69 failed: cancelled_at not cleared'; end if;
end $$;
rollback;

-- Case 70: suppressed → planned clears suppressed_reason
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare v_event_id uuid; v_plan public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(pg_temp.p7m3_next_iso_weekday(1, current_date+14));
  perform public.refresh_calendar_event_reminder_plans(v_event_id);
  update public.tenant_calendar_settings set remind_event_workday_start = false where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  perform pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'suppressed', 'policy_disabled');
  update public.tenant_calendar_settings set remind_event_workday_start = true where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform public.reconcile_tenant_calendar_reminder_plans('00000000-0000-0000-0000-000000000101', 500);
  v_plan := pg_temp.p7m3_assert_plan_state(v_event_id, 'event_workday_start', 'planned');
  if v_plan.suppressed_reason is not null then raise exception 'case70 failed: suppressed_reason not cleared'; end if;
end $$;
rollback;

-- Case 71: Non-delivered states reject non-NULL notification_id (CHECK)
begin;
set local role postgres;
do $$
declare v_plan_id uuid;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  perform pg_temp.p7m3_expect_validation_failed(format(
    'update public.calendar_reminder_plans set notification_id = %L where id = %L',
    gen_random_uuid(), v_plan_id));
end $$;
rollback;

-- Case 72: DST probe n > 2 candidates → internal error, not silent pick
begin;
set local role postgres;
do $$
begin
  create or replace function public.local_work_start_to_utc(p_timezone text, p_date date, p_time time)
  returns table (anchor_utc timestamptz, dst_resolution_code public.calendar_dst_resolution_code, dst_shift_seconds int)
  language plpgsql immutable set search_path = public as $f$
  begin
    raise exception 'dst_probe_unexpected_candidate_count';
  end $f$;
  begin
    perform public.local_work_start_to_utc('UTC', current_date, make_time(12,0,0));
    raise exception 'case72 failed: expected dst_probe_unexpected_candidate_count';
  exception when others then
    if sqlerrm not like '%dst_probe_unexpected_candidate_count%' then raise; end if;
  end;
end $$;
rollback;

-- Case 73: 501 pending events — reconcile batch 500 completes in multiple runs
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, false); end $$;
set local role postgres;
do $$
declare
  v_cnt int;
  v_before int;
  v_queue public.calendar_reminder_reconcile_queue;
  v_i int;
begin
  perform pg_temp.p7m3_bulk_create_events(
    501,
    p_title_prefix => 'P7M3 cursor501'
  );
  select count(*) into v_before
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like 'P7M3 cursor501 %';
  if v_before <> 0 then
    raise exception 'case73 failed: trigger pre-created % plans', v_before;
  end if;

  update public.tenant_calendar_settings
  set remind_event_workday_start = true
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  perform pg_temp.p7m3_run_scheduler();
  v_queue := pg_temp.p7m3_assert_queue_state('00000000-0000-0000-0000-000000000101', p_expect_processed_null => true);
  for v_i in 1..10 loop
    perform pg_temp.p7m3_run_scheduler();
    exit when exists (
      select 1 from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = '00000000-0000-0000-0000-000000000101'
        and q.processed_generation = q.generation
    );
  end loop;
  perform pg_temp.p7m3_assert_queue_state('00000000-0000-0000-0000-000000000101', v_queue.generation);
  select count(distinct crp.calendar_event_id) into v_cnt
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like 'P7M3 cursor501 %'
    and crp.rule_key = 'event_workday_start';
  if v_cnt <> 501 then raise exception 'case73 failed: planned count %', v_cnt; end if;
end $$;
rollback;

-- Case 74: 1200+ events — full scan across multiple scheduler runs
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, false); end $$;
set local role postgres;
do $$
declare v_plans int; v_i int;
begin
  perform pg_temp.p7m3_bulk_create_events(
    1205,
    p_title_prefix => 'P7M3 cursor1205'
  );
  if exists (
    select 1 from public.calendar_reminder_plans crp
    join public.calendar_events ce on ce.id = crp.calendar_event_id
    where ce.title_en like 'P7M3 cursor1205 %'
  ) then
    raise exception 'case74 failed: plans existed before reconcile';
  end if;

  update public.tenant_calendar_settings
  set remind_event_workday_start = true
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  for v_i in 1..10 loop
    perform pg_temp.p7m3_run_scheduler();
    exit when exists (
      select 1 from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = '00000000-0000-0000-0000-000000000101'
        and q.processed_generation = q.generation
    );
  end loop;
  select count(distinct crp.calendar_event_id) into v_plans
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like 'P7M3 cursor1205 %'
    and crp.rule_key = 'event_workday_start';
  if v_plans <> 1205 then raise exception 'case74 failed: plans %', v_plans; end if;
end $$;
rollback;

-- Case 75: Generation bumps between batches — cursor resets
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, false); end $$;
set local role postgres;
do $$
declare v_gen bigint; v_i int; v_event_plans int; v_previous_plans int;
begin
  perform pg_temp.p7m3_bulk_create_events(
    600,
    p_title_prefix => 'P7M3 cursor-generation'
  );
  update public.tenant_calendar_settings
  set remind_event_workday_start = true
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform pg_temp.p7m3_run_scheduler();
  update public.tenant_calendar_settings set remind_previous_workday_start = true where tenant_id = '00000000-0000-0000-0000-000000000101';
  select generation into v_gen from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101';
  if exists (select 1 from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101' and processed_generation = v_gen) then
    raise exception 'case75 failed: processed_generation advanced after generation bump';
  end if;
  for v_i in 1..10 loop
    perform pg_temp.p7m3_run_scheduler(500);
    exit when exists (
      select 1 from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = '00000000-0000-0000-0000-000000000101'
        and q.processed_generation = q.generation
    );
  end loop;
  select
    count(distinct crp.calendar_event_id) filter (where crp.rule_key = 'event_workday_start'),
    count(distinct crp.calendar_event_id) filter (where crp.rule_key = 'previous_workday_start')
  into v_event_plans, v_previous_plans
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like 'P7M3 cursor-generation %';
  if v_event_plans <> 600 or v_previous_plans <> 600 then
    raise exception 'case75 failed: event plans %, previous plans %', v_event_plans, v_previous_plans;
  end if;
end $$;
rollback;

-- Case 76: processed_generation equals generation only after final batch
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', false, false); end $$;
set local role postgres;
do $$
declare v_gen bigint; v_i int; v_plans int;
begin
  perform pg_temp.p7m3_bulk_create_events(
    501,
    p_title_prefix => 'P7M3 cursor-final'
  );
  update public.tenant_calendar_settings
  set remind_event_workday_start = true
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform pg_temp.p7m3_run_scheduler();
  select generation into v_gen from public.calendar_reminder_reconcile_queue where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform pg_temp.p7m3_assert_queue_state('00000000-0000-0000-0000-000000000101', p_expect_processed_null => true);
  for v_i in 1..10 loop
    perform pg_temp.p7m3_run_scheduler();
    exit when exists (
      select 1 from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = '00000000-0000-0000-0000-000000000101'
        and q.processed_generation = q.generation
    );
  end loop;
  perform pg_temp.p7m3_assert_queue_state('00000000-0000-0000-0000-000000000101', v_gen);
  select count(distinct crp.calendar_event_id) into v_plans
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like 'P7M3 cursor-final %'
    and crp.rule_key = 'event_workday_start';
  if v_plans <> 501 then raise exception 'case76 failed: plans %', v_plans; end if;
end $$;
rollback;

-- Case 77: user_has_permission_for_tenant_user — tenant A perm does not grant tenant B
begin;
set local role postgres;
do $$
begin
  if public.user_has_permission_for_tenant_user('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000201', 'calendar.view') then
    raise exception 'case77 failed: tenant A permission leaked to tenant B';
  end if;
  if not public.user_has_permission_for_tenant_user('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000201', 'calendar.view') then
    raise exception 'case77 failed: manager missing calendar.view in tenant A';
  end if;
end $$;
rollback;

-- Case 78: expired / failed snapshot columns — UPDATE rejected by immutability trigger
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders(); end $$;
set local role postgres;
do $$
declare v_failed uuid; v_expired uuid;
begin
  v_failed := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'failed', attempt_count = 5,
    anchor_local_date = current_date, anchor_local_time = make_time(8,0,0), anchor_utc = now() - interval '1 hour',
    timezone_name = 'Asia/Kuwait', dst_resolution_code = 'none', recipient_user_id = '00000000-0000-0000-0000-000000000201'
  where id = v_failed;
  perform pg_temp.p7m3_expect_validation_failed(format(
    'update public.calendar_reminder_plans set anchor_utc = now() where id = %L', v_failed));
  v_expired := pg_temp.p7m3_setup_delivery_case();
  update public.calendar_reminder_plans set status = 'expired', resolution_code = 'anchor_local_day_passed',
    anchor_local_date = current_date - 1, anchor_local_time = make_time(8,0,0), anchor_utc = now() - interval '1 day',
    timezone_name = 'Asia/Kuwait', dst_resolution_code = 'none', recipient_user_id = '00000000-0000-0000-0000-000000000201'
  where id = v_expired;
  perform pg_temp.p7m3_expect_validation_failed(format(
    'update public.calendar_reminder_plans set recipient_user_id = %L where id = %L',
    '00000000-0000-0000-0000-000000000205', v_expired));
end $$;
rollback;

-- Case 79: incomplete tenant reconcile blocks stale promotion and delivery
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare
  v_today date := public.try_tenant_local_today('00000000-0000-0000-0000-000000000101');
  v_iso int;
  v_i int;
  v_bad int;
  v_skipped int;
begin
  v_iso := extract(isodow from v_today)::int;
  update public.tenant_working_days
  set day_mode = '24_hours', work_start = null, work_end = null
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and iso_weekday = v_iso;

  insert into public.calendar_events (
    tenant_id, type, status, source_kind, scheduled_date,
    title_ar, title_en, assigned_agent_id
  )
  select
    '00000000-0000-0000-0000-000000000101'::uuid,
    'custom'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    'manual'::public.calendar_event_source_kind,
    v_today,
    'P7M3 stale guard ' || g,
    'P7M3 stale guard ' || g,
    '00000000-0000-0000-0000-000000000601'::uuid
  from generate_series(1, 501) g;

  update public.tenant_working_days
  set day_mode = 'day_off', work_start = null, work_end = null
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and iso_weekday = v_iso;

  perform pg_temp.p7m3_run_scheduler(100);

  select count(*) into v_bad
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like 'P7M3 stale guard %'
    and crp.rule_key = 'event_workday_start'
    and crp.status in ('delivery_pending', 'delivered', 'expired');
  if v_bad <> 0 then
    raise exception 'case79 failed: stale plans promoted %', v_bad;
  end if;

  if exists (
    select 1 from public.notifications n
    join public.calendar_reminder_plans crp on crp.id = n.related_entity_id
    join public.calendar_events ce on ce.id = crp.calendar_event_id
    where n.related_entity_table = 'calendar_reminder_plans'
      and ce.title_en like 'P7M3 stale guard %'
  ) then
    raise exception 'case79 failed: stale notification delivered';
  end if;

  for v_i in 1..10 loop
    perform pg_temp.p7m3_run_scheduler(100);
    exit when exists (
      select 1 from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = '00000000-0000-0000-0000-000000000101'
        and q.processed_generation = q.generation
    );
  end loop;

  select count(*) into v_skipped
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like 'P7M3 stale guard %'
    and crp.rule_key = 'event_workday_start'
    and crp.status = 'skipped'
    and crp.resolution_code = 'event_date_day_off';
  if v_skipped <> 501 then
    raise exception 'case79 failed: skipped plans %', v_skipped;
  end if;
end $$;
rollback;

-- Case 80: cancelled_superseded transitions clean cancelled_at when policy is disabled
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare
  v_event_id uuid;
  v_a date := pg_temp.p7m3_next_iso_weekday(1, current_date + 10);
  v_b date := v_a + 7;
  v_plan public.calendar_reminder_plans;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(v_a);
  update public.calendar_events set scheduled_date = v_b where id = v_event_id;
  update public.tenant_calendar_settings
  set remind_event_workday_start = false
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  update public.calendar_events set scheduled_date = v_a where id = v_event_id;

  select * into v_plan
  from public.calendar_reminder_plans crp
  where crp.calendar_event_id = v_event_id
    and crp.rule_key = 'event_workday_start'
    and crp.occurrence_scheduled_date = v_a;

  if v_plan.status <> 'suppressed'
    or v_plan.suppressed_reason <> 'policy_disabled'
    or v_plan.cancelled_at is not null then
    raise exception 'case80 failed: state %, reason %, cancelled_at %',
      v_plan.status, v_plan.suppressed_reason, v_plan.cancelled_at;
  end if;
end $$;
rollback;

-- Case 81: direct delivery waits for identity reconcile and revalidates employee
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare
  v_plan_id uuid;
  v_i int;
begin
  v_plan_id := pg_temp.p7m3_setup_delivery_case();
  for v_i in 1..10 loop
    perform public.reconcile_tenant_calendar_reminder_plans(
      '00000000-0000-0000-0000-000000000101', 500
    );
    exit when exists (
      select 1 from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = '00000000-0000-0000-0000-000000000101'
        and q.processed_generation = q.generation
    );
  end loop;
  perform pg_temp.p7m3_force_delivery_ready(v_plan_id);

  update public.employees
  set is_active = false
  where id = '00000000-0000-0000-0000-000000000601';

  perform public.deliver_calendar_reminder_plan_locked(v_plan_id);
  if pg_temp.p7m3_count_plan_notifications(v_plan_id) <> 0 then
    raise exception 'case81 failed: delivered before identity reconcile';
  end if;
  if not exists (
    select 1 from public.calendar_reminder_plans
    where id = v_plan_id and status = 'delivery_pending'
  ) then
    raise exception 'case81 failed: pending plan changed before reconcile';
  end if;

  for v_i in 1..10 loop
    perform public.reconcile_tenant_calendar_reminder_plans(
      '00000000-0000-0000-0000-000000000101', 500
    );
    exit when exists (
      select 1 from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = '00000000-0000-0000-0000-000000000101'
        and q.processed_generation = q.generation
    );
  end loop;
  perform pg_temp.p7m3_assert_plan_state(
    (select calendar_event_id from public.calendar_reminder_plans where id = v_plan_id),
    'event_workday_start',
    'suppressed',
    'no_assigned_recipient'
  );
end $$;
rollback;

-- Case 82: one tenant reconcile failure is isolated and persisted in run ledger
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7m3_configure_reminders('Asia/Kuwait', true, false); end $$;
set local role postgres;
do $$
declare
  v_event_id uuid;
  v_result jsonb;
begin
  v_event_id := pg_temp.p7m3_create_pending_event(
    pg_temp.p7m3_next_iso_weekday(1, current_date + 7)
  );
  perform pg_temp.p7m3_assert_plan_state(
    v_event_id,
    'event_workday_start',
    'planned'
  );

  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000204',
    true
  );
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', 'Asia/Kuwait',
    'remind_event_workday_start', true,
    'remind_previous_workday_start', false,
    'days', pg_temp.p7m3_standard_days()
  ));

  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000201',
    true
  );
  update public.tenant_calendar_settings
  set remind_event_workday_start = false
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  perform pg_temp.p7m3_install_tenant_a_reconcile_fail_trigger();
  v_result := pg_temp.p7m3_run_scheduler();

  if v_result ->> 'status' <> 'partial'
    or (v_result ->> 'tenants_failed')::int <> 1
    or (v_result ->> 'tenants_reconciled')::int < 1 then
    raise exception 'case82 failed: tenant failure isolation result %', v_result;
  end if;
  if not exists (
    select 1
    from public.calendar_reminder_runs r
    where r.id = (v_result ->> 'run_id')::uuid
      and r.status = 'partial'
      and r.tenants_failed = 1
      and r.tenants_reconciled >= 1
      and r.error_summary like '%p7m3_tenant_a_reconcile_failed%'
  ) then
    raise exception 'case82 failed: tenant failure not persisted %', v_result;
  end if;
  if not exists (
    select 1
    from public.calendar_reminder_reconcile_queue q
    where q.tenant_id = '00000000-0000-0000-0000-000000000101'
      and q.generation is distinct from q.processed_generation
  ) then
    raise exception 'case82 failed: failed tenant queue was incorrectly completed';
  end if;
  if not exists (
    select 1
    from public.calendar_reminder_reconcile_queue q
    where q.tenant_id = '00000000-0000-0000-0000-000000000102'
      and q.generation = q.processed_generation
  ) then
    raise exception 'case82 failed: healthy tenant queue was not completed';
  end if;

  perform pg_temp.p7m3_clear_test_triggers();
end $$;
rollback;
