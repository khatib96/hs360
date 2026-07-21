\set ON_ERROR_STOP on

-- Phase 7 M12: trusted Phase 8 handoff acceptance (self-contained).
-- Phase 8 (future) owns coverage / next-due math. This suite simulates that
-- contract with a test-only helper, then proves Phase 7 only consumes the
-- trusted confirmed fact. No Phase 7 product coverage calculation.
-- Seed IDs: tenant 101, owner 201, field agent 602, warehouses/groups as seed.

create or replace function pg_temp.p7m12_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل P7M12',
      'phone_primary', '+96550001212',
      'create_account', true
    )
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', 'موقع P7M12',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550001212'
    )
  );
  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p7m12_inventory_setup(p_customers jsonb)
returns jsonb
language plpgsql
as $$
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
    v_asset, v_tenant, 'P7M12-AST-' || left(v_asset::text, 8),
    'جهاز P7M12', 'P7M12 Asset', v_devices, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  ) values (
    v_oil, v_tenant, 'P7M12-OIL-' || left(v_oil::text, 8),
    'زيت P7M12', 'P7M12 Oil', v_oils, 'consumable_rental',
    'ml', 1, 0.015, 0.010, 0.012, false, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  ) values (
    v_unit, v_tenant, v_asset, 'P7M12-SN-' || left(v_unit::text, 8),
    'available_new', v_wh, 60.000, date '2026-07-01'
  );

  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant, v_wh, v_asset, 2.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  update public.tenant_calendar_settings
  set timezone_name = 'Asia/Kuwait'
  where tenant_id = v_tenant;

  return p_customers || jsonb_build_object(
    'asset_product', v_asset,
    'oil_a', v_oil,
    'unit_a', v_unit,
    'main_warehouse', v_wh
  );
end;
$$;

-- Test-only Phase 8 simulation: coverage ratio + whole-month arithmetic.
-- Not a Phase 7 product API.
create or replace function pg_temp.p7m12_phase8_simulate_and_insert_fact(
  p_ctx jsonb
)
returns uuid
language plpgsql
as $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_agent uuid := '00000000-0000-0000-0000-000000000602';
  v_contracted numeric(15, 3) := 500.000;
  v_delivered numeric(15, 3) := 1500.000;
  v_completion date := date '2026-08-04';
  v_ratio numeric;
  v_coverage_months int;
  v_calculated_next date;
  v_confirmed_next date;
  v_visit_id uuid := gen_random_uuid();
  v_fact_id uuid := gen_random_uuid();
  v_event_id uuid := (p_ctx ->> 'event_id')::uuid;
  v_contract_id uuid := (p_ctx ->> 'contract_id')::uuid;
  v_line_id uuid := (p_ctx ->> 'line_id')::uuid;
  v_product_id uuid := (p_ctx ->> 'product_id')::uuid;
  v_customer_id uuid := (p_ctx ->> 'customer_id')::uuid;
  v_location_id uuid := (p_ctx ->> 'service_location_id')::uuid;
  v_original_due date := (p_ctx ->> 'original_due_date')::date;
begin
  -- Phase 8 contract math (simulated here only):
  v_ratio := v_delivered / v_contracted;
  if v_ratio <> 3 then
    raise exception 'p7m12 phase8 sim: expected coverage ratio 3, got %', v_ratio;
  end if;
  v_coverage_months := trunc(v_ratio)::int;
  -- Whole-month calendar arithmetic: 2026-08-04 + 3 months = 2026-11-04
  v_calculated_next := (v_completion + (v_coverage_months || ' months')::interval)::date;
  if v_calculated_next is distinct from date '2026-11-04' then
    raise exception 'p7m12 phase8 sim: expected next due 2026-11-04, got %', v_calculated_next;
  end if;
  v_confirmed_next := v_calculated_next;

  insert into public.visits (
    id, tenant_id, visit_number, type, status,
    contract_id, customer_id, service_location_id, agent_id,
    scheduled_date, completed_at, created_by
  ) values (
    v_visit_id,
    v_tenant,
    'P7M12-' || left(replace(v_visit_id::text, '-', ''), 12),
    'refill'::public.visit_type,
    'completed'::public.visit_status,
    v_contract_id,
    v_customer_id,
    v_location_id,
    v_agent,
    v_original_due,
    (v_completion::timestamp + time '10:00') at time zone 'Asia/Kuwait',
    v_owner
  );

  update public.calendar_events
  set
    status = 'done'::public.calendar_event_status,
    visit_id = v_visit_id
  where id = v_event_id
    and tenant_id = v_tenant;

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
    created_by
  ) values (
    v_fact_id,
    v_tenant,
    v_event_id,
    v_visit_id,
    v_contract_id,
    v_line_id,
    v_product_id,
    v_original_due,
    v_completion,
    v_delivered,
    'ml'::public.unit_of_measure,
    v_contracted,
    v_coverage_months,
    null,
    v_calculated_next,
    v_confirmed_next,
    false,
    v_owner
  );

  return v_fact_id;
end;
$$;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
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
  perform set_config('test.p7m12.customers', pg_temp.p7m12_customer_setup()::text, false);
end $$;

set local role postgres;
do $$
begin
  perform set_config(
    'test.p7m12.fixture',
    pg_temp.p7m12_inventory_setup(current_setting('test.p7m12.customers')::jsonb)::text,
    false
  );
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m12.fixture')::jsonb;
  v_contract uuid;
begin
  -- Original refill cycle quantity = 500ml; start aligned to 2026-08-04.
  v_contract := public.create_rental_contract(jsonb_build_object(
    'customer_id', v_fixture ->> 'customer_id',
    'service_location_id', v_fixture ->> 'service_location_id',
    'start_date', date '2026-08-04',
    'end_date', date '2027-08-04',
    'billing_day', 5,
    'refill_day', 4,
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
  perform set_config('test.p7m12.contract_id', v_contract::text, true);
end $$;

set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_fixture jsonb := current_setting('test.p7m12.fixture')::jsonb;
  v_contract uuid := current_setting('test.p7m12.contract_id')::uuid;
  v_line_id uuid;
  v_event_id uuid;
  v_pending int;
  v_product_id uuid;
  v_original_due date;
  v_fact_id uuid;
  v_stored record;
  v_next_count int;
  v_next_id uuid;
  v_dup_count int;
  v_visits_before int;
  v_visits_after int;
  v_invoices_before int;
  v_invoices_after int;
  v_vouchers_before int;
  v_vouchers_after int;
  v_journals_before int;
  v_journals_after int;
  v_stock_before numeric(15, 3);
  v_stock_after numeric(15, 3);
  v_wh uuid := (v_fixture ->> 'main_warehouse')::uuid;
  v_oil uuid := (v_fixture ->> 'oil_a')::uuid;
  v_ctx jsonb;
begin
  perform public.sync_contract_calendar_events_internal(v_contract, 180);

  select cl.id, cl.product_id
  into v_line_id, v_product_id
  from public.contract_lines cl
  where cl.contract_id = v_contract
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  if v_line_id is null then
    raise exception 'p7m12: consumable line missing';
  end if;

  if v_product_id is distinct from v_oil then
    raise exception 'p7m12: unexpected oil product on line';
  end if;

  select ce.id, ce.original_due_date
  into v_event_id, v_original_due
  from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and ce.contract_id = v_contract
    and ce.contract_line_id = v_line_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  order by ce.scheduled_date, ce.id
  limit 1;

  if v_event_id is null then
    raise exception 'p7m12: original refill missing';
  end if;

  -- Align original due to the acceptance story date when generation chose another day.
  if v_original_due is distinct from date '2026-08-04'
    or (select scheduled_date from public.calendar_events where id = v_event_id)
         is distinct from date '2026-08-04' then
    update public.calendar_events
    set
      scheduled_date = date '2026-08-04',
      original_due_date = date '2026-08-04'
    where id = v_event_id;
    v_original_due := date '2026-08-04';
  end if;

  select count(*) into v_pending
  from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and ce.contract_id = v_contract
    and ce.contract_line_id = v_line_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  if v_pending <> 1 then
    raise exception 'p7m12: expected exactly one pending refill before fact, got %', v_pending;
  end if;

  -- No subsequent refill before trusted execution fact.
  if exists (
    select 1
    from public.calendar_events ce
    where ce.tenant_id = v_tenant
      and ce.contract_id = v_contract
      and ce.contract_line_id = v_line_id
      and ce.type = 'refill_due'::public.calendar_event_type
      and ce.id is distinct from v_event_id
      and ce.scheduled_date > v_original_due
  ) then
    raise exception 'p7m12: subsequent refill existed before trusted fact';
  end if;

  v_ctx := jsonb_build_object(
    'event_id', v_event_id,
    'contract_id', v_contract,
    'line_id', v_line_id,
    'product_id', v_product_id,
    'customer_id', v_fixture ->> 'customer_id',
    'service_location_id', v_fixture ->> 'service_location_id',
    'original_due_date', v_original_due
  );

  v_fact_id := pg_temp.p7m12_phase8_simulate_and_insert_fact(v_ctx);

  select
    f.actual_completion_date,
    f.actual_quantity_delivered,
    f.contracted_quantity_per_cycle,
    f.coverage_months,
    f.calculated_next_due_date,
    f.confirmed_next_due_date
  into v_stored
  from public.calendar_refill_execution_facts f
  where f.id = v_fact_id
    and f.tenant_id = v_tenant;

  if not found then
    raise exception 'p7m12: fact not accepted/persisted';
  end if;

  if v_stored.actual_completion_date is distinct from date '2026-08-04'
    or v_stored.actual_quantity_delivered is distinct from 1500.000
    or v_stored.contracted_quantity_per_cycle is distinct from 500.000
    or v_stored.coverage_months is distinct from 3
    or v_stored.calculated_next_due_date is distinct from date '2026-11-04'
    or v_stored.confirmed_next_due_date is distinct from date '2026-11-04' then
    raise exception 'p7m12: persisted fact contract mismatch: %', to_jsonb(v_stored);
  end if;

  select count(*) into v_visits_before from public.visits where tenant_id = v_tenant;
  select count(*) into v_invoices_before from public.invoices where tenant_id = v_tenant;
  select count(*) into v_vouchers_before from public.vouchers where tenant_id = v_tenant;
  select count(*) into v_journals_before from public.journal_entries where tenant_id = v_tenant;
  select coalesce(qty_available, 0) into v_stock_before
  from public.inventory_balances
  where tenant_id = v_tenant and warehouse_id = v_wh and product_id = v_oil;
  v_stock_before := coalesce(v_stock_before, 0);

  -- Phase 7 generation consumes confirmed_next_due_date from the trusted fact.
  perform public.sync_contract_calendar_events_internal(v_contract, 180);

  select count(*)
  into v_next_count
  from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and ce.contract_id = v_contract
    and ce.contract_line_id = v_line_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
    and ce.scheduled_date = date '2026-11-04'
    and ce.generated_from_execution_fact_id = v_fact_id;

  if v_next_count <> 1 then
    raise exception 'p7m12: expected one next refill on 2026-11-04 from fact, got %', v_next_count;
  end if;

  select ce.id
  into v_next_id
  from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and ce.contract_id = v_contract
    and ce.contract_line_id = v_line_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
    and ce.scheduled_date = date '2026-11-04'
    and ce.generated_from_execution_fact_id = v_fact_id
  limit 1;

  -- Idempotent generation: no duplicate.
  perform public.sync_contract_calendar_events_internal(v_contract, 180);
  perform public.sync_contract_calendar_events_internal(v_contract, 180);

  select count(*) into v_dup_count
  from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and ce.contract_id = v_contract
    and ce.contract_line_id = v_line_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.scheduled_date = date '2026-11-04'
    and ce.generated_from_execution_fact_id = v_fact_id;

  if v_dup_count <> 1 then
    raise exception 'p7m12: duplicate next refill after re-generation, count=%', v_dup_count;
  end if;

  select count(*) into v_visits_after from public.visits where tenant_id = v_tenant;
  select count(*) into v_invoices_after from public.invoices where tenant_id = v_tenant;
  select count(*) into v_vouchers_after from public.vouchers where tenant_id = v_tenant;
  select count(*) into v_journals_after from public.journal_entries where tenant_id = v_tenant;
  select coalesce(qty_available, 0) into v_stock_after
  from public.inventory_balances
  where tenant_id = v_tenant and warehouse_id = v_wh and product_id = v_oil;
  v_stock_after := coalesce(v_stock_after, 0);

  if v_visits_after <> v_visits_before
    or v_invoices_after <> v_invoices_before
    or v_vouchers_after <> v_vouchers_before
    or v_journals_after <> v_journals_before
    or v_stock_after is distinct from v_stock_before then
    raise exception
      'p7m12: side effects from generation visits=%->% invoices=%->% vouchers=%->% journals=%->% stock=%->%',
      v_visits_before, v_visits_after,
      v_invoices_before, v_invoices_after,
      v_vouchers_before, v_vouchers_after,
      v_journals_before, v_journals_after,
      v_stock_before, v_stock_after;
  end if;

  -- Fixture cleanup: this suite runs inside begin/rollback so all rows
  -- (events, facts, visits, reminder plans, contracts, products) are discarded.
  -- Explicit deletes are omitted to avoid reminder-plan / fact FK ordering noise.

  raise notice 'phase_7_m12_trusted_handoff_acceptance_passed';
end $$;
rollback;
