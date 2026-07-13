\set ON_ERROR_STOP on

-- Phase 7 M2: calendar event generation engine verification.
-- Seed IDs: tenant_a 101, owner 201, tenant_b 102, owner_b 204.

create or replace function pg_temp.p7m2_customer_setup(p_suffix text default 'P7M2')
returns jsonb
language plpgsql
as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل ' || p_suffix,
      'phone_primary', '+96550018001',
      'create_account', true
    )
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', 'موقع ' || p_suffix,
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550018001'
    )
  );
  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p7m2_inventory_setup(p_customers jsonb)
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
    v_asset_product, v_tenant_a, 'P7M2-AST-' || left(v_asset_product::text, 8),
    'جهاز P7M2', 'P7M2 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values
    (
      v_oil_a, v_tenant_a, 'P7M2-OIL-A-' || left(v_oil_a::text, 8),
      'زيت A P7M2', 'P7M2 Oil A', v_oils_group, 'consumable_rental',
      'ml', 1, 0.015, 0.010, 0.012, false, v_owner
    ),
    (
      v_oil_b, v_tenant_a, 'P7M2-OIL-B-' || left(v_oil_b::text, 8),
      'زيت B P7M2', 'P7M2 Oil B', v_oils_group, 'consumable_rental',
      'ml', 1, 0.020, 0.013, 0.014, false, v_owner
    );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values
    (
      v_unit_a, v_tenant_a, v_asset_product, 'P7M2-SN-' || left(v_unit_a::text, 8),
      'available_new', v_main_warehouse, 60.000, current_date
    ),
    (
      v_unit_b, v_tenant_a, v_asset_product, 'P7M2-SN-' || left(v_unit_b::text, 8),
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
    'unit_b', v_unit_b
  );
end;
$$;

create or replace function pg_temp.p7m2_create_rental(
  p_fixture jsonb,
  p_start date default current_date,
  p_refill_day int default 7,
  p_refill_frequency int default 1,
  p_unit_key text default 'unit_a'
)
returns uuid
language plpgsql
as $$
declare
  v_end date := (p_start + interval '12 months')::date;
begin
  return public.create_rental_contract(
    jsonb_build_object(
      'customer_id', p_fixture ->> 'customer_id',
      'service_location_id', p_fixture ->> 'service_location_id',
      'start_date', p_start,
      'end_date', v_end,
      'billing_day', 5,
      'refill_day', p_refill_day,
      'monthly_rental_value', '25.000',
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_fixture ->> 'asset_product',
          'product_unit_id', p_fixture ->> p_unit_key
        )
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_fixture ->> 'oil_a',
          'qty_per_refill', 500.000,
          'refill_frequency_months', p_refill_frequency
        )
      )
    ),
    gen_random_uuid()
  );
end;
$$;

create or replace function pg_temp.p7m2_expect_validation_failed(p_sql text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
    raise exception 'p7m2_expect_validation_failed: unexpected success for %', p_sql;
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise exception 'p7m2_expect_validation_failed: unexpected error for %: %', p_sql, sqlerrm;
      end if;
  end;
end;
$$;

-- 1. Helpers: timezone readiness and cadence computation.
begin;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_today date;
begin
  update public.tenant_calendar_settings
  set timezone_name = null
  where tenant_id = v_tenant;

  if public.calendar_timezone_ready(v_tenant) then
    raise exception 'case1 failed: calendar_timezone_ready true without timezone';
  end if;

  if public.try_tenant_local_today(v_tenant) is not null then
    raise exception 'case1 failed: try_tenant_local_today should be null without timezone';
  end if;

  update public.tenant_calendar_settings
  set timezone_name = 'Asia/Kuwait'
  where tenant_id = v_tenant;

  if not public.calendar_timezone_ready(v_tenant) then
    raise exception 'case1 failed: calendar_timezone_ready false with valid timezone';
  end if;

  v_today := public.try_tenant_local_today(v_tenant);
  if v_today is null then
    raise exception 'case1 failed: try_tenant_local_today null with valid timezone';
  end if;

  if public.compute_first_cadence_date_on_or_after(
    date '2026-07-01', 1, 5, date '2026-07-01'
  ) <> date '2026-08-05' then
    raise exception 'case1 failed: cadence freq1 anchor';
  end if;

  if public.compute_first_cadence_date_on_or_after(
    date '2026-07-01', 3, 5, date '2026-07-01'
  ) <> date '2026-10-05' then
    raise exception 'case1 failed: cadence freq3 anchor';
  end if;
end $$;
rollback;

-- 2. Sync skips when timezone is not configured.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup()::text, true); end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p7m2.fixture',
    pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text,
    true
  );
  update public.tenant_calendar_settings
  set timezone_name = null
  where tenant_id = '00000000-0000-0000-0000-000000000101';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_result jsonb;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, current_date - 30);
  perform set_config('test.p7m2.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p7m2.contract_id')::uuid;
  v_result jsonb;
begin
  v_result := public.sync_contract_calendar_events_entry_internal(v_contract_id, 30);

  if coalesce(v_result ->> 'skipped', 'false') <> 'true'
    or v_result ->> 'reason' <> 'calendar_setup_required' then
    raise exception 'case2 failed: %', v_result;
  end if;

  if exists (
    select 1
    from public.calendar_events ce
    where ce.contract_id = v_contract_id
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
  ) then
    raise exception 'case2 failed: calendar events created without timezone';
  end if;
end $$;
rollback;

-- 3. Deferred suspend/reactivate from lifecycle handoff reconciles after timezone setup.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2DEF')::text, true); end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p7m2.fixture',
    pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text,
    true
  );
  update public.tenant_calendar_settings
  set timezone_name = null
  where tenant_id = '00000000-0000-0000-0000-000000000101';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_contract_id uuid;
  v_deferred_count int;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, date '2026-06-01', 15, 1);

  perform set_config('test.p7m2.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p7m2.contract_id')::uuid;
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_deferred_count int;
begin
  update public.contracts
  set status = 'suspended'::public.contract_status
  where id = v_contract_id;

  update public.contracts
  set status = 'active'::public.contract_status
  where id = v_contract_id;

  select count(*) into v_deferred_count
  from public.calendar_deferred_lifecycle_reconciliations d
  where d.contract_id = v_contract_id
    and d.processed_at is null;

  if v_deferred_count < 2 then
    raise exception 'case3 failed: expected deferred enqueue from handoff, got %', v_deferred_count;
  end if;

  update public.tenant_calendar_settings
  set timezone_name = 'Asia/Kuwait'
  where tenant_id = v_tenant;

  perform public.reconcile_deferred_calendar_lifecycle_ops(v_tenant, v_contract_id);

  select count(*) into v_deferred_count
  from public.calendar_deferred_lifecycle_reconciliations d
  where d.contract_id = v_contract_id
    and d.processed_at is null;

  if v_deferred_count <> 0 then
    raise exception 'case3 failed: deferred rows still open: %', v_deferred_count;
  end if;
end $$;
rollback;

-- 4. Rule 0 materializes initial oil change at contract start when no outstanding refill exists.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2R0')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_event_date date;
  v_action text;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, date '2026-06-01', 15, 1);

  select ce.scheduled_date, ce.source_metadata ->> 'action_kind'
  into v_event_date, v_action
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  limit 1;

  if v_event_date <> date '2026-06-01' or v_action <> 'consumable_change' then
    raise exception 'case4 failed: date=% action=%', v_event_date, v_action;
  end if;
end $$;
rollback;

-- 5. Rule 1 merges consumable change on the same refill date.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2R1')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_merge_date date := current_date + 14;
  v_outstanding_id uuid;
  v_count int;
  v_action text;
begin
  v_contract_id := pg_temp.p7m2_create_rental(
    v_fixture,
    current_date,
    extract(day from v_merge_date)::int,
    1
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  select ce.id into v_outstanding_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  limit 1;

  perform set_config('test.p7m2.contract_id', v_contract_id::text, true);
  perform set_config('test.p7m2.line_id', v_line_id::text, true);
  perform set_config('test.p7m2.merge_date', v_merge_date::text, true);
  perform set_config('test.p7m2.outstanding_id', v_outstanding_id::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.calendar_events
  set scheduled_date = current_setting('test.p7m2.merge_date')::date
  where id = current_setting('test.p7m2.outstanding_id')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid := current_setting('test.p7m2.contract_id')::uuid;
  v_line_id uuid := current_setting('test.p7m2.line_id')::uuid;
  v_merge_date date := current_setting('test.p7m2.merge_date')::date;
  v_count int;
  v_action text;
begin
  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', v_merge_date,
      'qty_per_refill', 500.000,
      'reason', 'merge on cadence date'
    ),
    gen_random_uuid()
  );

  -- A routine regeneration must not erase the Rule 1 oil-change semantics.
  perform public.sync_tenant_contract_calendar_events(60);

  select count(*), max(ce.source_metadata ->> 'action_kind')
  into v_count, v_action
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.scheduled_date = v_merge_date
    and ce.status = 'pending'::public.calendar_event_status;

  if v_count <> 1 or v_action <> 'refill_with_consumable_change' then
    raise exception 'case5 failed: count=% action=% date=%', v_count, v_action, v_merge_date;
  end if;
end $$;
rollback;

-- 6. Rule 2 replacement before outstanding cadence date.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2R2')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_outstanding_date date := current_date + 21;
  v_replacement_date date := current_date + 7;
  v_outstanding_id uuid;
  v_action text;
begin
  v_contract_id := pg_temp.p7m2_create_rental(
    v_fixture,
    current_date,
    extract(day from v_outstanding_date)::int,
    1
  );

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  select ce.id into v_outstanding_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  limit 1;

  perform set_config('test.p7m2.contract_id', v_contract_id::text, true);
  perform set_config('test.p7m2.line_id', v_line_id::text, true);
  perform set_config('test.p7m2.outstanding_id', v_outstanding_id::text, true);
  perform set_config('test.p7m2.outstanding_date', v_outstanding_date::text, true);
  perform set_config('test.p7m2.replacement_date', v_replacement_date::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.calendar_events
  set scheduled_date = current_setting('test.p7m2.outstanding_date')::date
  where id = current_setting('test.p7m2.outstanding_id')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid := current_setting('test.p7m2.contract_id')::uuid;
  v_line_id uuid := current_setting('test.p7m2.line_id')::uuid;
  v_outstanding_date date := current_setting('test.p7m2.outstanding_date')::date;
  v_replacement_date date := current_setting('test.p7m2.replacement_date')::date;
  v_action text;
begin
  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', v_replacement_date,
      'qty_per_refill', 500.000,
      'reason', 'replacement before cadence'
    ),
    gen_random_uuid()
  );

  select ce.source_metadata ->> 'action_kind'
  into v_action
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.scheduled_date = v_replacement_date
    and ce.status = 'pending'::public.calendar_event_status
  limit 1;

  if v_action <> 'consumable_change' then
    raise exception 'case6 failed: action=% replacement=% outstanding=%',
      v_action, v_replacement_date, v_outstanding_date;
  end if;
end $$;
rollback;

-- 7. One outstanding refill per consumable line.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2ONE')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_pending_count int;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, date '2026-07-01', 5, 1);

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  select count(*) into v_pending_count
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.contract_line_id = v_line_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  if v_pending_count <> 1 then
    raise exception 'case7 failed: expected one outstanding refill, got %', v_pending_count;
  end if;
end $$;
rollback;

-- 8. Source-key parser rejects mismatched fact linkage on update.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2KEY')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_event_id uuid;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, date '2026-06-01', 15, 1);

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  select ce.id into v_event_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
  limit 1;

  perform set_config('test.p7m2.key_contract_id', v_contract_id::text, true);
  perform set_config('test.p7m2.key_line_id', v_line_id::text, true);
  perform set_config('test.p7m2.key_event_id', v_event_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p7m2.key_contract_id')::uuid;
  v_line_id uuid := current_setting('test.p7m2.key_line_id')::uuid;
  v_event_id uuid := current_setting('test.p7m2.key_event_id')::uuid;
  v_fact uuid := gen_random_uuid();
  v_key text;
  v_parsed record;
begin

  v_key := public.build_contract_calendar_source_key(
    v_contract_id, 'refill_from_fact', v_line_id, null, null, v_fact
  );

  select * into v_parsed
  from public.parse_calendar_refill_source_key(v_key) p
  limit 1;

  if v_parsed.contract_id <> v_contract_id
    or v_parsed.contract_line_id <> v_line_id
    or v_parsed.tail_uuid <> v_fact
    or v_parsed.kind <> 'from_fact' then
    raise exception 'case8 failed: parser mismatch';
  end if;

  perform pg_temp.p7m2_expect_validation_failed(format(
    'update public.calendar_events set source_key = %L, generated_from_execution_fact_id = %L where id = %L',
    v_key,
    gen_random_uuid(),
    v_event_id
  ));
end $$;
rollback;

-- 9. Batch generation records run ledger (duplicate skip covered by concurrency script).
begin;
set local role postgres;
do $$
declare
  v_first jsonb;
  v_run_id uuid;
begin
  update public.tenant_calendar_settings
  set timezone_name = 'Asia/Kuwait'
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  v_first := public.run_scheduled_calendar_generation(30);
  v_run_id := (v_first ->> 'run_id')::uuid;

  if v_run_id is null then
    raise exception 'case9 failed: missing run_id from first batch %', v_first;
  end if;

  if not exists (
    select 1
    from public.calendar_generation_runs r
    where r.id = v_run_id
      and r.status in ('completed', 'partial')
  ) then
    raise exception 'case9 failed: run row missing or not completed: %', v_first;
  end if;

  if not exists (
    select 1
    from public.calendar_generation_run_tenants rt
    where rt.run_id = v_run_id
  ) then
    raise exception 'case9 failed: missing tenant ledger rows for run %', v_run_id;
  end if;
end $$;
rollback;

-- 10. Batch skips tenants without timezone configuration.
begin;
set local role postgres;
do $$
declare
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_result jsonb;
  v_run_id uuid;
begin
  update public.tenant_calendar_settings
  set timezone_name = null
  where tenant_id = v_tenant_b;

  v_result := public.run_scheduled_calendar_generation(30);
  v_run_id := (v_result ->> 'run_id')::uuid;

  if not exists (
    select 1
    from public.calendar_generation_run_tenants rt
    where rt.run_id = v_run_id
      and rt.tenant_id = v_tenant_b
      and rt.status = 'skipped_calendar_setup_required'
  ) then
    raise exception 'case10 failed: tenant_b not skipped in batch ledger';
  end if;

  update public.tenant_calendar_settings
  set timezone_name = 'Asia/Kuwait'
  where tenant_id = v_tenant_b;
end $$;
rollback;

-- 11. Suspension cancels future generated events; overdue rows preserved.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2SUS')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_overdue_id uuid;
  v_future_billing_id uuid;
  v_today date;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, date '2026-01-01', 15, 1);
  v_today := (now() at time zone 'Asia/Kuwait')::date;

  select ce.id into v_overdue_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  limit 1;

  perform set_config('test.p7m2.contract_id', v_contract_id::text, true);
  perform set_config('test.p7m2.overdue_id', v_overdue_id::text, true);
  perform set_config('test.p7m2.overdue_date', (v_today - 10)::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.calendar_events
  set scheduled_date = current_setting('test.p7m2.overdue_date')::date
  where id = current_setting('test.p7m2.overdue_id')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_contract_id uuid := current_setting('test.p7m2.contract_id')::uuid;
  v_overdue_id uuid := current_setting('test.p7m2.overdue_id')::uuid;
  v_future_billing_id uuid;
  v_today date := (now() at time zone 'Asia/Kuwait')::date;
begin
  select ce.id into v_future_billing_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type
    and ce.scheduled_date >= v_today
    and ce.status = 'pending'::public.calendar_event_status
  order by ce.scheduled_date
  limit 1;

  if v_future_billing_id is null then
    raise exception 'case11 failed: missing future billing event fixture';
  end if;

  perform set_config('test.p7m2.suspend_contract_id', v_contract_id::text, true);
  perform set_config('test.p7m2.future_billing_id', v_future_billing_id::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.contracts
  set status = 'suspended'::public.contract_status
  where id = current_setting('test.p7m2.suspend_contract_id')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_overdue_id uuid := current_setting('test.p7m2.overdue_id')::uuid;
  v_future_billing_id uuid := current_setting('test.p7m2.future_billing_id')::uuid;
begin
  if exists (
    select 1
    from public.calendar_events ce
    where ce.id = v_future_billing_id
      and ce.status = 'pending'::public.calendar_event_status
  ) then
    raise exception 'case11 failed: future billing still pending after suspend';
  end if;

  if not exists (
    select 1
    from public.calendar_events ce
    where ce.id = v_overdue_id
      and ce.status = 'pending'::public.calendar_event_status
  ) then
    raise exception 'case11 failed: overdue refill cancelled by suspend';
  end if;
end $$;
rollback;

-- 12. Error sanitization, internal helper ACL, and manual fact-link rejection.
begin;
set local role postgres;
do $$
declare
  v_signature text;
begin
  if public.sanitize_sql_error_code('23505') <> '23505'
    or public.sanitize_sql_error_code('invalid') <> 'P0001' then
    raise exception 'case12 failed: SQLSTATE sanitizer mismatch';
  end if;

  foreach v_signature in array array[
    'public.sanitize_sql_error_code(text)',
    'public.calendar_timezone_ready(uuid)',
    'public.try_tenant_local_today(uuid)',
    'public.calendar_event_is_regen_safe(uuid)',
    'public.compute_first_cadence_date_on_or_after(date,integer,integer,date)',
    'public.build_contract_calendar_source_key(uuid,text,uuid,date,date,uuid)',
    'public.calendar_event_source_requires_execution_fact(text)',
    'public.parse_calendar_refill_source_key(text)'
  ] loop
    if has_function_privilege('authenticated', v_signature, 'EXECUTE')
      or has_function_privilege('anon', v_signature, 'EXECUTE')
      or has_function_privilege('service_role', v_signature, 'EXECUTE') then
      raise exception 'case12 failed: internal helper executable through API role: %', v_signature;
    end if;
  end loop;

  perform pg_temp.p7m2_expect_validation_failed(format(
    'insert into public.calendar_events '
      || '(tenant_id, type, status, scheduled_date, source_kind, generated_from_execution_fact_id) '
      || 'values (%L, %L, %L, current_date, %L, %L)',
    '00000000-0000-0000-0000-000000000101',
    'refill_due',
    'pending',
    'manual',
    gen_random_uuid()
  ));
end $$;
rollback;

-- 13. A done predecessor without an execution fact cannot advance the chain.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2NOFACT')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_id uuid;
  v_event_id uuid;
  v_oil_id uuid;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, current_date - 30, 15, 1);

  select ce.id into v_event_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  select coc.id into v_oil_id
  from public.contract_oil_changes coc
  where coc.contract_id = v_contract_id
  order by coc.effective_from, coc.id
  limit 1;

  perform set_config('test.p7m2.nofact_contract', v_contract_id::text, true);
  perform set_config('test.p7m2.nofact_event', v_event_id::text, true);
  perform set_config('test.p7m2.nofact_oil', v_oil_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p7m2.nofact_contract')::uuid;
  v_event_id uuid := current_setting('test.p7m2.nofact_event')::uuid;
  v_oil_id uuid := current_setting('test.p7m2.nofact_oil')::uuid;
  v_result jsonb;
  v_pending int;
  v_status text;
  v_queued_after uuid;
begin
  update public.calendar_events
  set status = 'done'::public.calendar_event_status
  where id = v_event_id;

  update public.contract_oil_changes
  set
    calendar_materialization_status = null,
    calendar_event_id = null,
    calendar_queued_after_event_id = null,
    calendar_conflict_event_id = null,
    calendar_conflict_code = null
  where id = v_oil_id;

  perform public.sync_contract_calendar_events_core_internal(v_contract_id, 60);

  select count(*) into v_pending
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  if v_pending <> 0 then
    raise exception 'case13 failed: sync advanced without execution fact';
  end if;

  v_result := public.apply_consumable_change_to_calendar(v_oil_id);
  select coc.calendar_materialization_status, coc.calendar_queued_after_event_id
  into v_status, v_queued_after
  from public.contract_oil_changes coc
  where coc.id = v_oil_id;

  if v_result ->> 'reason' <> 'awaiting_execution_fact'
    or v_status <> 'queued'
    or v_queued_after is distinct from v_event_id then
    raise exception 'case13 failed: result=% status=% queued_after=%',
      v_result, v_status, v_queued_after;
  end if;
end $$;
rollback;

-- 14. on_activation affects only the first invoice; later billing months still generate.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2BILL')::text, true); end $$;
set local role postgres;
do $$
begin
  perform set_config(
    'test.p7m2.fixture',
    pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text,
    true
  );
  update public.tenant_settings
  set first_rental_invoice_policy = 'on_activation'::public.first_rental_invoice_policy
  where tenant_id = '00000000-0000-0000-0000-000000000101';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_contract_id uuid;
  v_count int;
begin
  v_contract_id := pg_temp.p7m2_create_rental(
    current_setting('test.p7m2.fixture')::jsonb,
    current_date,
    15,
    1
  );

  perform public.sync_tenant_contract_calendar_events(60);

  select count(*) into v_count
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  if v_count < 2 then
    raise exception 'case14 failed: on_activation generated only % billing event(s)', v_count;
  end if;
end $$;
rollback;

-- 15. Deferred failure is isolated and retry metadata survives subtransaction rollback.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2FAIL')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_contract_id uuid;
begin
  v_contract_id := pg_temp.p7m2_create_rental(
    current_setting('test.p7m2.fixture')::jsonb,
    current_date,
    15,
    1
  );
  perform set_config('test.p7m2.fail_contract', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.tenant_calendar_settings
  set timezone_name = null
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  update public.contracts
  set status = 'suspended'::public.contract_status
  where id = current_setting('test.p7m2.fail_contract')::uuid;

  update public.tenant_calendar_settings
  set timezone_name = 'Asia/Kuwait'
  where tenant_id = '00000000-0000-0000-0000-000000000101';
end $$;

create or replace function pg_temp.p7m2_force_calendar_failure()
returns trigger
language plpgsql
as $$
begin
  if new.contract_id = current_setting('test.p7m2.fail_contract')::uuid then
    raise exception 'forced_calendar_failure';
  end if;
  return new;
end;
$$;

create trigger trg_p7m2_force_calendar_failure
  before update on public.calendar_events
  for each row execute function pg_temp.p7m2_force_calendar_failure();

do $$
declare
  v_attempts int;
  v_error text;
  v_processed timestamptz;
begin
  perform public.reconcile_deferred_calendar_lifecycle_ops(
    '00000000-0000-0000-0000-000000000101',
    current_setting('test.p7m2.fail_contract')::uuid
  );

  select d.attempt_count, d.last_error_code, d.processed_at
  into v_attempts, v_error, v_processed
  from public.calendar_deferred_lifecycle_reconciliations d
  where d.contract_id = current_setting('test.p7m2.fail_contract')::uuid
    and d.operation = 'suspend';

  if v_attempts <> 1 or v_error <> 'P0001' or v_processed is not null then
    raise exception 'case15 failed after forced error: attempts=% error=% processed=%',
      v_attempts, v_error, v_processed;
  end if;
end $$;

drop trigger trg_p7m2_force_calendar_failure on public.calendar_events;

do $$
declare
  v_attempts int;
  v_error text;
  v_processed timestamptz;
begin
  perform public.reconcile_deferred_calendar_lifecycle_ops(
    '00000000-0000-0000-0000-000000000101',
    current_setting('test.p7m2.fail_contract')::uuid
  );

  select d.attempt_count, d.last_error_code, d.processed_at
  into v_attempts, v_error, v_processed
  from public.calendar_deferred_lifecycle_reconciliations d
  where d.contract_id = current_setting('test.p7m2.fail_contract')::uuid
    and d.operation = 'suspend';

  if v_attempts <> 2 or v_error is not null or v_processed is null then
    raise exception 'case15 failed after retry: attempts=% error=% processed=%',
      v_attempts, v_error, v_processed;
  end if;
end $$;
rollback;

-- 16. Deferred reactivation materializes queued oil and retains predecessor lineage.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p7m2.customers', pg_temp.p7m2_customer_setup('P7M2REACT')::text, true); end $$;
set local role postgres;
do $$ begin perform set_config('test.p7m2.fixture', pg_temp.p7m2_inventory_setup(current_setting('test.p7m2.customers')::jsonb)::text, true); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_contract_start date := current_date;
  v_business_today date := (now() at time zone 'Asia/Kuwait')::date;
  v_contract_id uuid;
  v_line_id uuid;
  v_event_id uuid;
begin
  v_contract_id := pg_temp.p7m2_create_rental(v_fixture, v_contract_start, 15, 1);

  select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type;

  select ce.id into v_event_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  perform set_config('test.p7m2.react_contract', v_contract_id::text, true);
  perform set_config('test.p7m2.react_line', v_line_id::text, true);
  perform set_config('test.p7m2.react_predecessor', v_event_id::text, true);
  perform set_config('test.p7m2.react_event_date', (v_business_today - 2)::text, true);
  perform set_config('test.p7m2.react_oil_date', (v_contract_start + 10)::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.calendar_events
  set scheduled_date = current_setting('test.p7m2.react_event_date')::date
  where id = current_setting('test.p7m2.react_predecessor')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p7m2.fixture')::jsonb;
  v_oil_id uuid;
begin
  perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', current_setting('test.p7m2.react_contract'),
      'contract_line_id', current_setting('test.p7m2.react_line'),
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', current_setting('test.p7m2.react_oil_date'),
      'qty_per_refill', 500.000,
      'reason', 'queued deferred reactivation'
    ),
    gen_random_uuid()
  );

  select coc.id into v_oil_id
  from public.contract_oil_changes coc
  where coc.contract_id = current_setting('test.p7m2.react_contract')::uuid
    and coc.contract_line_id = current_setting('test.p7m2.react_line')::uuid
    and coc.effective_from = current_setting('test.p7m2.react_oil_date')::date;

  perform set_config('test.p7m2.react_oil', v_oil_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_contract_id uuid := current_setting('test.p7m2.react_contract')::uuid;
  v_today date := (now() at time zone 'Asia/Kuwait')::date;
  v_oil_id uuid := current_setting('test.p7m2.react_oil')::uuid;
  v_status text;
  v_event_id uuid;
  v_queued_after uuid;
  v_event_date date;
  v_action text;
begin
  if not exists (
    select 1
    from public.contract_oil_changes coc
    where coc.id = v_oil_id
      and coc.calendar_materialization_status = 'queued'
      and coc.calendar_queued_after_event_id = current_setting('test.p7m2.react_predecessor')::uuid
  ) then
    raise exception 'case16 failed: oil change was not queued before suspension';
  end if;

  update public.tenant_calendar_settings
  set timezone_name = null
  where tenant_id = v_tenant;

  update public.contracts
  set status = 'suspended'::public.contract_status
  where id = v_contract_id;

  update public.contracts
  set status = 'active'::public.contract_status
  where id = v_contract_id;

  update public.calendar_deferred_lifecycle_reconciliations d
  set occurred_at = case d.operation
    when 'suspend' then (v_today - 5)::timestamp at time zone 'Asia/Kuwait'
    when 'reactivate' then (v_today - 1)::timestamp at time zone 'Asia/Kuwait'
  end
  where d.contract_id = v_contract_id
    and d.processed_at is null;

  update public.tenant_calendar_settings
  set timezone_name = 'Asia/Kuwait'
  where tenant_id = v_tenant;

  perform public.reconcile_deferred_calendar_lifecycle_ops(v_tenant, v_contract_id);

  select
    coc.calendar_materialization_status,
    coc.calendar_event_id,
    coc.calendar_queued_after_event_id
  into v_status, v_event_id, v_queued_after
  from public.contract_oil_changes coc
  where coc.id = v_oil_id;

  select ce.scheduled_date, ce.source_metadata ->> 'action_kind'
  into v_event_date, v_action
  from public.calendar_events ce
  where ce.id = v_event_id
    and ce.status = 'pending'::public.calendar_event_status;

  if v_status <> 'materialized'
    or v_event_id is null
    or v_queued_after is distinct from current_setting('test.p7m2.react_predecessor')::uuid
    or v_event_date is distinct from current_setting('test.p7m2.react_oil_date')::date
    or v_action <> 'refill_with_consumable_change' then
    raise exception 'case16 failed: status=% event=% queued_after=% date=% action=%',
      v_status, v_event_id, v_queued_after, v_event_date, v_action;
  end if;
end $$;
rollback;

do $$
begin
  raise notice 'phase_7_calendar_event_generation_engine: all 16 cases passed';
end $$;
