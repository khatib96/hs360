\set ON_ERROR_STOP on

-- Phase 6 M12: contract calendar handoff verification.

create or replace function pg_temp.p6m12_customer_setup()
returns jsonb
language plpgsql
as $$
declare
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    '{"name_ar":"عميل M12","phone_primary":"+96550012001","create_account":true}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع M12","location_type":"branch","governorate":"Hawalli","area":"Salmiya","contact_person_phone":"+96550012001"}'::jsonb
  );
  return jsonb_build_object(
    'customer_id', v_customer_id,
    'service_location_id', v_location_id
  );
end;
$$;

create or replace function pg_temp.p6m12_inventory_setup(p_customers jsonb)
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
    v_asset_product, v_tenant_a, 'P6M12-AST-' || left(v_asset_product::text, 8),
    'جهاز M12', 'M12 Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    is_serialized, created_by
  )
  values
    (
      v_oil_a, v_tenant_a, 'P6M12-OIL-A-' || left(v_oil_a::text, 8),
      'زيت A M12', 'M12 Oil A', v_oils_group, 'consumable_rental',
      'ml', 1, 0.015, 0.010, 0.012, false, v_owner
    ),
    (
      v_oil_b, v_tenant_a, 'P6M12-OIL-B-' || left(v_oil_b::text, 8),
      'زيت B M12', 'M12 Oil B', v_oils_group, 'consumable_rental',
      'ml', 1, 0.020, 0.013, 0.014, false, v_owner
    );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values
    (
      v_unit_a, v_tenant_a, v_asset_product, 'P6M12-SN-' || left(v_unit_a::text, 8),
      'available_new', v_main_warehouse, 60.000, current_date
    ),
    (
      v_unit_b, v_tenant_a, v_asset_product, 'P6M12-SN-' || left(v_unit_b::text, 8),
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

create or replace function pg_temp.p6m12_create_rental(
  p_fixture jsonb,
  p_start date default current_date,
  p_end date default null,
  p_billing_day int default 5,
  p_refill_day int default 7,
  p_refill_frequency int default 1,
  p_unit_key text default 'unit_a'
)
returns uuid
language plpgsql
as $$
declare
  v_end date := coalesce(p_end, (p_start + interval '12 months')::date);
  v_unit_id uuid := (p_fixture ->> p_unit_key)::uuid;
begin
  return public.create_rental_contract(
    jsonb_build_object(
      'customer_id', p_fixture ->> 'customer_id',
      'service_location_id', p_fixture ->> 'service_location_id',
      'start_date', p_start,
      'end_date', v_end,
      'billing_day', p_billing_day,
      'refill_day', p_refill_day,
      'monthly_rental_value', '25.000',
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_fixture ->> 'asset_product',
          'product_unit_id', v_unit_id
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


-- Trusted backend verification helpers (postgres role only).
create or replace function pg_temp.p6m12_assert_no_direct_select_authenticated()
returns void language plpgsql as $$
begin
  begin
    perform count(*) from public.calendar_events;
    raise exception 'm12 regression failed: authenticated direct SELECT succeeded';
  exception when insufficient_privilege then
    null;
  end;
end; $$;

create or replace function pg_temp.p6m12_configure_calendar()
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
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
end; $$;

create or replace function pg_temp.p6m12_cash_account()
returns uuid
language sql
as $$
  select id
  from public.chart_of_accounts
  where tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and code = '1101'
  limit 1;
$$;

-- 1. Active trial creates trial_ending with identity fields.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_trial_id uuid;
  v_count int;
begin
v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'trial_days', 5,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      )
    ),
    gen_random_uuid()
  );
  perform set_config('test.p6m12.ctx.v_trial_id', v_trial_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_trial_id uuid;
  v_count int;
begin
  v_trial_id := nullif(current_setting('test.p6m12.ctx.v_trial_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
select count(*) into v_count
  from public.calendar_events ce
  where ce.contract_id = v_trial_id
    and ce.type = 'trial_ending'::public.calendar_event_type
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.customer_id is not null
    and ce.service_location_id is not null;
if v_count <> 1 then
    raise exception 'case1 failed: expected one trial_ending, got %', v_count;
end if;
  perform set_config('test.p6m12.ctx.v_count', v_count::text, true);
  perform set_config('test.p6m12.ctx.v_trial_id', v_trial_id::text, true);
end $$;
rollback;

-- 2. Active rental creates billing + refill within horizon.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_billing int;
  v_refill int;
begin
v_contract_id := pg_temp.p6m12_create_rental(v_fixture);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_billing int;
  v_refill int;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
select count(*) into v_billing
  from public.calendar_events ce
  where ce.contract_id = v_contract_id and ce.type = 'billing_due'::public.calendar_event_type;
  perform set_config('test.p6m12.ctx.v_billing', v_billing::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_billing int;
  v_refill int;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_billing := nullif(current_setting('test.p6m12.ctx.v_billing', true), '')::int;
select count(*) into v_refill
  from public.calendar_events ce
  where ce.contract_id = v_contract_id and ce.type = 'refill_due'::public.calendar_event_type;
if v_billing < 1 or v_refill < 1 then
    raise exception 'case2 failed: billing=% refill=%', v_billing, v_refill;
end if;
  perform set_config('test.p6m12.ctx.v_refill', v_refill::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_billing', v_billing::text, true);
end $$;
rollback;

-- 3. Fixed-term rental creates contract_end; open-ended does not.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_fixed uuid;
  v_open uuid;
  v_fixed_end int;
  v_open_end int;
begin
v_fixed := pg_temp.p6m12_create_rental(v_fixture, current_date, (current_date + 20)::date);
  perform set_config('test.p6m12.ctx.v_fixed', v_fixed::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_fixed uuid;
  v_open uuid;
  v_fixed_end int;
  v_open_end int;
begin
  v_fixed := nullif(current_setting('test.p6m12.ctx.v_fixed', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
select count(*) into v_fixed_end
  from public.calendar_events
  where contract_id = v_fixed and type = 'contract_end'::public.calendar_event_type;
  perform set_config('test.p6m12.ctx.v_fixed_end', v_fixed_end::text, true);
  perform set_config('test.p6m12.ctx.v_fixed', v_fixed::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_fixed uuid;
  v_open uuid;
  v_fixed_end int;
  v_open_end int;
begin
  v_fixed := nullif(current_setting('test.p6m12.ctx.v_fixed', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_fixed_end := nullif(current_setting('test.p6m12.ctx.v_fixed_end', true), '')::int;
v_open := public.create_rental_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'billing_day', 5,
      'refill_day', 7,
      'monthly_rental_value', '25.000',
      'asset_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'asset_product', 'product_unit_id', v_fixture ->> 'unit_b')
      ),
      'consumable_lines', jsonb_build_array(
        jsonb_build_object('product_id', v_fixture ->> 'oil_a', 'qty_per_refill', 500.000, 'refill_frequency_months', 1)
      )
    ),
    gen_random_uuid()
  );
  perform set_config('test.p6m12.ctx.v_open', v_open::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_fixed uuid;
  v_open uuid;
  v_fixed_end int;
  v_open_end int;
begin
  v_fixed := nullif(current_setting('test.p6m12.ctx.v_fixed', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_fixed_end := nullif(current_setting('test.p6m12.ctx.v_fixed_end', true), '')::int;
  v_open := nullif(current_setting('test.p6m12.ctx.v_open', true), '')::uuid;
select count(*) into v_open_end
  from public.calendar_events
  where contract_id = v_open and type = 'contract_end'::public.calendar_event_type;
if v_fixed_end <> 1 or v_open_end <> 0 then
    raise exception 'case3 failed: fixed=% open=%', v_fixed_end, v_open_end;
end if;
  perform set_config('test.p6m12.ctx.v_open_end', v_open_end::text, true);
  perform set_config('test.p6m12.ctx.v_open', v_open::text, true);
  perform set_config('test.p6m12.ctx.v_fixed_end', v_fixed_end::text, true);
end $$;
rollback;

-- 4. Re-sync is idempotent (no duplicate source_key).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
begin
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture);
  perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_before int;
  v_after int;
  v_dup int;
begin
  select count(*) into v_before from public.calendar_events where contract_id = v_contract_id and source_kind = 'contract_generated';
  perform public.sync_contract_calendar_events_internal(v_contract_id, 30);
  select count(*) into v_after from public.calendar_events where contract_id = v_contract_id and source_kind = 'contract_generated';
  select count(*) into v_dup
  from (
    select source_key, count(*) c
    from public.calendar_events
    where contract_id = v_contract_id and source_kind = 'contract_generated'
    group by source_key having count(*) > 1
  ) d;
  if v_before <> v_after or v_dup <> 0 then
    raise exception 'case4 failed: before=% after=% dup=%', v_before, v_after, v_dup;
  end if;
end $$;
rollback;

-- 9. Provenance: authenticated spoof + service_role direct fail; calendar.edit succeeds.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
begin
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture);

  perform set_config('hs360.contract_calendar_write', '1', true);
  begin
    insert into public.calendar_events (
      tenant_id, type, scheduled_date, contract_id, customer_id, service_location_id,
      source_kind, source_key, source_metadata
    )
    select c.tenant_id, 'billing_due', current_date + 10, c.id, c.customer_id, c.service_location_id,
      'contract_generated', 'contract:' || c.id::text || ':billing:2099-01-01', '{}'::jsonb
    from public.contracts c where c.id = v_contract_id;
    raise exception 'case9 failed: authenticated spoof insert succeeded';
  exception when others then
    if sqlerrm not like '%permission_denied%' then
      raise;
    end if;
  end;

  perform public.sync_tenant_contract_calendar_events(30);
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  perform public.sync_tenant_contract_calendar_events(30);
  raise exception 'case9 failed: user without calendar.edit succeeded';
exception when others then
  if sqlerrm not like '%permission_denied%' then
    raise;
  end if;
end $$;
rollback;

begin;
set local role service_role;
do $$
begin
  begin
    insert into public.calendar_events (
      tenant_id, type, scheduled_date, source_kind, source_key, source_metadata
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'billing_due', current_date + 5,
      'contract_generated', 'contract:00000000-0000-0000-0000-000000009999:billing:2099-02-01',
      '{}'::jsonb
    );
    raise exception 'case9 failed: service_role direct insert succeeded';
  exception when others then
    if sqlerrm not like '%permission_denied%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 13. manual first_rental_invoice_policy creates zero billing_due.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.tenant_settings
  set first_rental_invoice_policy = 'manual'::public.first_rental_invoice_policy
  where tenant_id = v_tenant;
  perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_billing int;
  v_start date := date '2026-03-20';
begin
v_contract_id := pg_temp.p6m12_create_rental(v_fixture, v_start, (v_start + interval '12 months')::date, 5, 7, 1);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
  perform set_config('test.p6m12.ctx.v_start', v_start::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_billing int;
  v_start date := date '2026-03-20';
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_start := nullif(current_setting('test.p6m12.ctx.v_start', true), '')::date;
select count(*) into v_billing
  from public.calendar_events
  where contract_id = v_contract_id and type = 'billing_due'::public.calendar_event_type;
if v_billing <> 0 then
    raise exception 'case13 manual policy failed: billing=%', v_billing;
end if;
  perform set_config('test.p6m12.ctx.v_billing', v_billing::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.tenant_settings
  set first_rental_invoice_policy = 'first_billing_day'::public.first_rental_invoice_policy
  where tenant_id = v_tenant;
end $$;
rollback;

-- 14. Billing identity uses coverage month key in source_key.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_key text;
begin
v_contract_id := pg_temp.p6m12_create_rental(v_fixture, current_date, (current_date + 120)::date, 5, 7, 1);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_key text;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
select ce.source_key into v_key
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type
  order by ce.scheduled_date
  limit 1;
if v_key is null or v_key !~ ':billing:[0-9]{4}-[0-9]{2}-01$' then
    raise exception 'case14 failed: source_key=%', v_key;
end if;
  perform set_config('test.p6m12.ctx.v_key', v_key::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
rollback;

-- 19b. active -> suspended -> active restores billing/refill without duplicates.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_billing_day int := least(extract(day from current_date)::int + 5, 28);
begin
  v_contract_id := pg_temp.p6m12_create_rental(
    v_fixture,
    current_date,
    (current_date + 25)::date,
    v_billing_day,
    7,
    1
  );
  perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_active_billing int;
  v_suspended_billing int;
  v_reactive_billing int;
  v_end int;
  v_dup int;
begin
  select count(*) into v_active_billing
  from public.calendar_events
  where contract_id = v_contract_id
    and type = 'billing_due'::public.calendar_event_type
    and status = 'pending'::public.calendar_event_status;

  perform public.allow_contract_write();
  update public.contracts set status = 'suspended'::public.contract_status where id = v_contract_id;

  select count(*) into v_suspended_billing
  from public.calendar_events
  where contract_id = v_contract_id
    and type = 'billing_due'::public.calendar_event_type
    and status = 'pending'::public.calendar_event_status;

  perform public.allow_contract_write();
  update public.contracts set status = 'active'::public.contract_status where id = v_contract_id;

  select count(*) into v_reactive_billing
  from public.calendar_events
  where contract_id = v_contract_id
    and type = 'billing_due'::public.calendar_event_type
    and status = 'pending'::public.calendar_event_status;

  select count(*) into v_end
  from public.calendar_events
  where contract_id = v_contract_id and type = 'contract_end'::public.calendar_event_type;

  select count(*) into v_dup
  from (
    select source_key, count(*) c
    from public.calendar_events
    where contract_id = v_contract_id and source_kind = 'contract_generated'
    group by source_key having count(*) > 1
  ) d;

  if v_active_billing < 1 or v_suspended_billing <> 0 or v_reactive_billing < 1
    or v_end <> 1 or v_dup <> 0 then
    raise exception 'case19b failed: active=% susp=% react=% end=% dup=%',
      v_active_billing, v_suspended_billing, v_reactive_billing, v_end, v_dup;
  end if;
end $$;
rollback;

-- 20b. Same-day consumable change queues after outstanding start-date oil event (M2 Rule 3).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_outstanding_id uuid;
  v_status text;
  v_queued_after uuid;
begin
v_contract_id := pg_temp.p6m12_create_rental(v_fixture, current_date - 1);
select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
  perform set_config('test.p6m12.ctx.v_line_id', v_line_id::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_outstanding_id uuid;
  v_status text;
  v_queued_after uuid;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_line_id := nullif(current_setting('test.p6m12.ctx.v_line_id', true), '')::uuid;
select ce.id into v_outstanding_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  limit 1;
if v_outstanding_id is null then
    raise exception 'case20b failed: expected outstanding refill from Rule 0 materialization';
end if;
  perform set_config('test.p6m12.ctx.v_outstanding_id', v_outstanding_id::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_outstanding_id uuid;
  v_status text;
  v_queued_after uuid;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_line_id := nullif(current_setting('test.p6m12.ctx.v_line_id', true), '')::uuid;
  v_outstanding_id := nullif(current_setting('test.p6m12.ctx.v_outstanding_id', true), '')::uuid;
perform public.schedule_contract_consumable_change(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'contract_line_id', v_line_id,
      'new_product_id', v_fixture ->> 'oil_b',
      'effective_date', current_date,
      'qty_per_refill', 500.000,
      'reason', 'same-day change'
    ),
    gen_random_uuid()
  );
select coc.calendar_materialization_status, coc.calendar_queued_after_event_id
  into v_status, v_queued_after
  from public.contract_oil_changes coc
  where coc.contract_id = v_contract_id
    and coc.contract_line_id = v_line_id
    and coc.effective_from = current_date
  limit 1;
if v_status <> 'queued' or v_queued_after is distinct from v_outstanding_id then
    raise exception 'case20b failed: status=% queued_after=% outstanding=%',
      v_status, v_queued_after, v_outstanding_id;
end if;
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_line_id', v_line_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
  perform set_config('test.p6m12.ctx.v_status', v_status::text, true);
  perform set_config('test.p6m12.ctx.v_queued_after', v_queued_after::text, true);
  perform set_config('test.p6m12.ctx.v_outstanding_id', v_outstanding_id::text, true);
end $$;
rollback;

-- 24. get_contract_detail exposes upcoming_schedule without cost keys.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p6m12_configure_calendar(); end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_detail jsonb;
  v_schedule jsonb;
begin
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture);
  v_detail := public.get_contract_detail(v_contract_id);
  v_schedule := coalesce(v_detail -> 'upcoming_schedule', '[]'::jsonb);
  if jsonb_array_length(v_schedule) < 1 then
    raise exception 'case24 failed: empty upcoming_schedule';
  end if;
  if v_schedule::text like '%snapshot_%'
    or v_schedule::text like '%avg_cost%'
    or v_schedule::text like '%monthly_cost%' then
    raise exception 'case24 failed: cost keys leaked in upcoming_schedule';
  end if;
end $$;
rollback;

-- 8. Manual calendar event survives close; generated future cancelled.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_manual_id uuid;
begin
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture, current_date, (current_date + 20)::date);

  v_manual_id := gen_random_uuid();
  insert into public.calendar_events (
    id, tenant_id, type, status, scheduled_date,
    contract_id, customer_id, service_location_id,
    title_en, source_kind, source_metadata
  )
  values (
    v_manual_id,
    '00000000-0000-0000-0000-000000000101'::uuid,
    'custom'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    current_date + 15,
    v_contract_id,
    (v_fixture ->> 'customer_id')::uuid,
    (v_fixture ->> 'service_location_id')::uuid,
    'Manual follow-up',
    'manual'::public.calendar_event_source_kind,
    '{}'::jsonb
  );

  perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.manual_id', v_manual_id::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
begin
  perform public.close_contract(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'close_date', current_date,
      'closure_type', 'normal',
      'close_reason', 'M12 test close',
      'return_condition', 'available_used'
    ),
    gen_random_uuid()
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_manual_id uuid := current_setting('test.p6m12.manual_id')::uuid;
  v_manual_pending int;
  v_generated_pending int;
begin
  select count(*) into v_manual_pending
  from public.calendar_events
  where id = v_manual_id and status = 'pending'::public.calendar_event_status;

  select count(*) into v_generated_pending
  from public.calendar_events
  where contract_id = v_contract_id
    and source_kind = 'contract_generated'::public.calendar_event_source_kind
    and status = 'pending'::public.calendar_event_status
    and scheduled_date > current_date;

  if v_manual_pending <> 1 or v_generated_pending <> 0 then
    raise exception 'case8 failed: manual=% generated=%', v_manual_pending, v_generated_pending;
  end if;
end $$;
rollback;

-- 6. Tenant isolation for read and batch sync.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_a uuid;
begin
  v_contract_a := pg_temp.p6m12_create_rental(v_fixture);
  perform set_config('test.p6m12.contract_a', v_contract_a::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_tenant_b_tu uuid := '00000000-0000-0000-0000-000000000304';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_b, v_tenant_b_tu, 'calendar.edit', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_contract_a uuid := current_setting('test.p6m12.contract_a')::uuid;
begin
  begin
    perform public.get_contract_detail(v_contract_a);
    raise exception 'case6 failed: tenant B read tenant A contract';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
set local role postgres;
do $$
declare
  v_contract_a uuid := current_setting('test.p6m12.contract_a')::uuid;
  v_before int;
begin
  select count(*) into v_before
  from public.calendar_events
  where contract_id = v_contract_a
    and source_kind = 'contract_generated'::public.calendar_event_source_kind;

  perform set_config('test.p6m12.before_count', v_before::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
begin
  perform public.sync_tenant_contract_calendar_events(30);
end $$;
set local role postgres;
do $$
declare
  v_contract_a uuid := current_setting('test.p6m12.contract_a')::uuid;
  v_before int := current_setting('test.p6m12.before_count')::int;
  v_after int;
begin
  select count(*) into v_after
  from public.calendar_events
  where contract_id = v_contract_a
    and source_kind = 'contract_generated'::public.calendar_event_source_kind;

  if v_after <> v_before then
    raise exception 'case6 failed: tenant B sync changed tenant A events before=% after=%',
      v_before, v_after;
  end if;
end $$;
rollback;

-- 7. extend_trial_contract reschedules trial_ending.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_trial_id uuid;
  v_before date;
  v_after date;
  v_new_end date := current_date + 25;
begin
v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'trial_days', 5,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      )
    ),
    gen_random_uuid()
  );
  perform set_config('test.p6m12.ctx.v_trial_id', v_trial_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_trial_id uuid;
  v_before date;
  v_after date;
  v_new_end date := current_date + 25;
begin
  v_trial_id := nullif(current_setting('test.p6m12.ctx.v_trial_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
select ce.scheduled_date into v_before
  from public.calendar_events ce
  where ce.contract_id = v_trial_id
    and ce.type = 'trial_ending'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;
  perform set_config('test.p6m12.ctx.v_before', v_before::text, true);
  perform set_config('test.p6m12.ctx.v_trial_id', v_trial_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_trial_id uuid;
  v_before date;
  v_after date;
  v_new_end date := current_date + 25;
begin
  v_trial_id := nullif(current_setting('test.p6m12.ctx.v_trial_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_before := nullif(current_setting('test.p6m12.ctx.v_before', true), '')::date;
perform public.extend_trial_contract(
    jsonb_build_object(
      'trial_contract_id', v_trial_id,
      'new_trial_end_date', v_new_end,
      'reason', 'M12 extend trial schedule'
    ),
    gen_random_uuid()
  );
  perform set_config('test.p6m12.ctx.v_trial_id', v_trial_id::text, true);
  perform set_config('test.p6m12.ctx.v_new_end', v_new_end::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_trial_id uuid;
  v_before date;
  v_after date;
  v_new_end date := current_date + 25;
begin
  v_trial_id := nullif(current_setting('test.p6m12.ctx.v_trial_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_before := nullif(current_setting('test.p6m12.ctx.v_before', true), '')::date;
  v_new_end := nullif(current_setting('test.p6m12.ctx.v_new_end', true), '')::date;
select ce.scheduled_date into v_after
  from public.calendar_events ce
  where ce.contract_id = v_trial_id
    and ce.type = 'trial_ending'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;
if v_before is null or v_after <> v_new_end then
    raise exception 'case7 failed: before=% after=% expected=%', v_before, v_after, v_new_end;
end if;
  perform set_config('test.p6m12.ctx.v_after', v_after::text, true);
  perform set_config('test.p6m12.ctx.v_trial_id', v_trial_id::text, true);
  perform set_config('test.p6m12.ctx.v_before', v_before::text, true);
  perform set_config('test.p6m12.ctx.v_new_end', v_new_end::text, true);
end $$;
rollback;

-- 10. Tenant/contract/contract_line mismatch is rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_a uuid;
  v_contract_b uuid;
  v_line_b uuid;
begin
  v_contract_a := pg_temp.p6m12_create_rental(v_fixture);
  v_contract_b := pg_temp.p6m12_create_rental(
    v_fixture, current_date, (current_date + 90)::date, 6, 8, 1, 'unit_b'
  );

  select cl.id into v_line_b
  from public.contract_lines cl
  where cl.contract_id = v_contract_b
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;

  perform set_config('test.p6m12.contract_a', v_contract_a::text, true);
  perform set_config('test.p6m12.line_b', v_line_b::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_a uuid := current_setting('test.p6m12.contract_a')::uuid;
  v_line_b uuid := current_setting('test.p6m12.line_b')::uuid;
  v_contract public.contracts%rowtype;
begin
  select * into v_contract from public.contracts where id = v_contract_a;

  begin
    perform public.upsert_contract_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      v_contract.customer_id,
      v_contract.service_location_id,
      v_line_b,
      'refill_due'::public.calendar_event_type,
      current_date + 14,
      public.build_contract_calendar_source_key(
        v_contract.id, 'refill', v_line_b, current_date + 14, null
      ),
      jsonb_build_object('action_kind', 'refill'),
      'تعبئة', 'Refill', array[1440, 60]
    );
    raise exception 'case10 failed: cross-contract line accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;

  begin
    perform public.upsert_contract_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      gen_random_uuid(),
      v_contract.service_location_id,
      null,
      'billing_due'::public.calendar_event_type,
      current_date + 14,
      public.build_contract_calendar_source_key(
        v_contract.id, 'billing', null, null, date_trunc('month', current_date + 14)::date
      ),
      jsonb_build_object(
        'coverage_month_key', to_char(date_trunc('month', current_date + 14)::date, 'YYYY-MM-DD'),
        'billing_day', v_contract.billing_day
      ),
      'فوترة', 'Billing', array[1440, 60]
    );
    raise exception 'case10 failed: mismatched customer accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise;
    end if;
  end;
end $$;
rollback;

-- 11. first_billing_day uses first valid billing_day on or after start.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.tenant_settings
  set first_rental_invoice_policy = 'first_billing_day'::public.first_rental_invoice_policy
  where tenant_id = v_tenant;
  perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_start date;
  v_billing_day int := 5;
  v_first date;
  v_expected date;
begin
v_start := make_date(
    extract(year from current_date)::int,
    extract(month from current_date)::int,
    20
  );
if v_start < current_date then
    v_start := (v_start + interval '1 month')::date;
end if;
v_contract_id := pg_temp.p6m12_create_rental(
    v_fixture,
    v_start,
    (v_start + interval '12 months')::date,
    v_billing_day,
    7,
    1
  );
  perform set_config('test.p6m12.ctx.v_start', v_start::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
  perform set_config('test.p6m12.ctx.v_billing_day', v_billing_day::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_start date;
  v_billing_day int := 5;
  v_first date;
  v_expected date;
begin
  v_start := nullif(current_setting('test.p6m12.ctx.v_start', true), '')::date;
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_billing_day := nullif(current_setting('test.p6m12.ctx.v_billing_day', true), '')::int;
select min(ce.scheduled_date) into v_first
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type;
  perform set_config('test.p6m12.ctx.v_first', v_first::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_start date;
  v_billing_day int := 5;
  v_first date;
  v_expected date;
begin
  v_start := nullif(current_setting('test.p6m12.ctx.v_start', true), '')::date;
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_billing_day := nullif(current_setting('test.p6m12.ctx.v_billing_day', true), '')::int;
  v_first := nullif(current_setting('test.p6m12.ctx.v_first', true), '')::date;
v_expected := public.calendar_make_day_in_month(
    (date_trunc('month', v_start) + interval '1 month')::date,
    v_billing_day
  );
if v_first is null or v_first <> v_expected then
    raise exception 'case11 failed: first=% expected=% start=%', v_first, v_expected, v_start;
end if;
  perform set_config('test.p6m12.ctx.v_expected', v_expected::text, true);
  perform set_config('test.p6m12.ctx.v_start', v_start::text, true);
  perform set_config('test.p6m12.ctx.v_billing_day', v_billing_day::text, true);
  perform set_config('test.p6m12.ctx.v_first', v_first::text, true);
end $$;
rollback;

-- 12. on_activation bills on start_date then billing_day in later months.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.tenant_settings
  set first_rental_invoice_policy = 'on_activation'::public.first_rental_invoice_policy
  where tenant_id = v_tenant;
  perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_start date := current_date + 3;
  v_billing_day int := 5;
  v_first date;
  v_second date;
  v_expected_second date;
begin
v_contract_id := pg_temp.p6m12_create_rental(
    v_fixture,
    v_start,
    (v_start + interval '12 months')::date,
    v_billing_day,
    7,
    1
  );
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
  perform set_config('test.p6m12.ctx.v_start', v_start::text, true);
  perform set_config('test.p6m12.ctx.v_billing_day', v_billing_day::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_start date := current_date + 3;
  v_billing_day int := 5;
  v_first date;
  v_second date;
  v_expected_second date;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_start := nullif(current_setting('test.p6m12.ctx.v_start', true), '')::date;
  v_billing_day := nullif(current_setting('test.p6m12.ctx.v_billing_day', true), '')::int;
select ce.scheduled_date into v_first
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type
  order by ce.scheduled_date
  limit 1;
  perform set_config('test.p6m12.ctx.v_first', v_first::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_start date := current_date + 3;
  v_billing_day int := 5;
  v_first date;
  v_second date;
  v_expected_second date;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_start := nullif(current_setting('test.p6m12.ctx.v_start', true), '')::date;
  v_billing_day := nullif(current_setting('test.p6m12.ctx.v_billing_day', true), '')::int;
  v_first := nullif(current_setting('test.p6m12.ctx.v_first', true), '')::date;
select ce.scheduled_date into v_second
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type
  order by ce.scheduled_date
  offset 1
  limit 1;
  perform set_config('test.p6m12.ctx.v_second', v_second::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_start date := current_date + 3;
  v_billing_day int := 5;
  v_first date;
  v_second date;
  v_expected_second date;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_start := nullif(current_setting('test.p6m12.ctx.v_start', true), '')::date;
  v_billing_day := nullif(current_setting('test.p6m12.ctx.v_billing_day', true), '')::int;
  v_first := nullif(current_setting('test.p6m12.ctx.v_first', true), '')::date;
  v_second := nullif(current_setting('test.p6m12.ctx.v_second', true), '')::date;
v_expected_second := public.calendar_make_day_in_month(
    (date_trunc('month', v_start) + interval '1 month')::date,
    v_billing_day
  );
if v_first <> v_start or v_second <> v_expected_second then
    raise exception 'case12 failed: first=% second=% expected_second=% start=%',
      v_first, v_second, v_expected_second, v_start;
end if;
  perform set_config('test.p6m12.ctx.v_expected_second', v_expected_second::text, true);
  perform set_config('test.p6m12.ctx.v_start', v_start::text, true);
  perform set_config('test.p6m12.ctx.v_billing_day', v_billing_day::text, true);
  perform set_config('test.p6m12.ctx.v_first', v_first::text, true);
  perform set_config('test.p6m12.ctx.v_second', v_second::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.tenant_settings
  set first_rental_invoice_policy = 'first_billing_day'::public.first_rental_invoice_policy
  where tenant_id = v_tenant;
end $$;
rollback;

-- 15. Covered month becomes done and disappears from upcoming_schedule.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_coverage date;
  v_billing_id uuid;
  v_status public.calendar_event_status;
  v_schedule jsonb;
begin
v_contract_id := pg_temp.p6m12_create_rental(
    v_fixture,
    (current_date - interval '45 days')::date,
    (current_date + interval '12 months')::date,
    greatest(least(extract(day from current_date)::int, 28), 1),
    7,
    1
  );
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_coverage date;
  v_billing_id uuid;
  v_status public.calendar_event_status;
  v_schedule jsonb;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
select
    ce.id,
    ce.status,
    (ce.source_metadata ->> 'coverage_month_key')::date
  into v_billing_id, v_status, v_coverage
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  order by ce.scheduled_date, ce.id
  limit 1;
if v_billing_id is null then
    raise exception 'case15 failed: no pending billing event for contract %', v_contract_id;
end if;
  perform set_config('test.p6m12.ctx.v_billing_id', v_billing_id::text, true);
  perform set_config('test.p6m12.ctx.v_status', v_status::text, true);
  perform set_config('test.p6m12.ctx.v_coverage', v_coverage::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_coverage date;
  v_billing_id uuid;
  v_status public.calendar_event_status;
  v_schedule jsonb;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_billing_id := nullif(current_setting('test.p6m12.ctx.v_billing_id', true), '')::uuid;
  v_status := nullif(current_setting('test.p6m12.ctx.v_status', true), '')::public.calendar_event_status;
  v_coverage := nullif(current_setting('test.p6m12.ctx.v_coverage', true), '')::date;
perform public.collect_rental_payment(
    jsonb_build_object(
      'contract_id', v_contract_id,
      'date', current_date,
      'amount', 25.000,
      'payment_method', 'cash',
      'cash_account_id', pg_temp.p6m12_cash_account(),
      'coverage_months', jsonb_build_array(to_char(v_coverage, 'YYYY-MM-DD'))
    ),
    gen_random_uuid()
  );
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_coverage', v_coverage::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_coverage date;
  v_billing_id uuid;
  v_status public.calendar_event_status;
  v_schedule jsonb;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_billing_id := nullif(current_setting('test.p6m12.ctx.v_billing_id', true), '')::uuid;
  v_status := nullif(current_setting('test.p6m12.ctx.v_status', true), '')::public.calendar_event_status;
  v_coverage := nullif(current_setting('test.p6m12.ctx.v_coverage', true), '')::date;
select ce.status into v_status
  from public.calendar_events ce
  where ce.id = v_billing_id;
  perform set_config('test.p6m12.ctx.v_status', v_status::text, true);
  perform set_config('test.p6m12.ctx.v_billing_id', v_billing_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_coverage date;
  v_billing_id uuid;
  v_status public.calendar_event_status;
  v_schedule jsonb;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_billing_id := nullif(current_setting('test.p6m12.ctx.v_billing_id', true), '')::uuid;
  v_status := nullif(current_setting('test.p6m12.ctx.v_status', true), '')::public.calendar_event_status;
  v_coverage := nullif(current_setting('test.p6m12.ctx.v_coverage', true), '')::date;
v_schedule := coalesce(
    public.get_contract_detail(v_contract_id) -> 'upcoming_schedule',
    '[]'::jsonb
  );
if v_status <> 'done'::public.calendar_event_status
    or v_schedule @> jsonb_build_array(jsonb_build_object('id', v_billing_id::text)) then
    raise exception 'case15 failed: status=% schedule_contains=%', v_status, v_schedule;
end if;
  perform set_config('test.p6m12.ctx.v_schedule', v_schedule::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_status', v_status::text, true);
  perform set_config('test.p6m12.ctx.v_billing_id', v_billing_id::text, true);
end $$;
rollback;

-- 16. Horizon shrink does not cancel events outside the new horizon.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
begin
  v_contract_id := pg_temp.p6m12_create_rental(
    v_fixture,
    current_date,
    (current_date + 150)::date,
    5,
    7,
    1
  );
  perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_far_before int;
  v_far_after int;
begin
  perform public.sync_contract_calendar_events_internal(v_contract_id, 120);

  select count(*) into v_far_before
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.scheduled_date > current_date + 35;

  perform public.sync_contract_calendar_events_internal(v_contract_id, 30);

  select count(*) into v_far_after
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.scheduled_date > current_date + 35
    and ce.status <> 'cancelled'::public.calendar_event_status;

  if v_far_before < 1 or v_far_after <> v_far_before then
    raise exception 'case16 failed: before=% after=%', v_far_before, v_far_after;
  end if;
end $$;
rollback;

-- 17. Overdue pending generated events are preserved by sync.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
begin
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture);
  perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_contract public.contracts%rowtype;
  v_overdue date := current_date - 7;
  v_event_id uuid;
  v_status public.calendar_event_status;
begin
  select * into v_contract from public.contracts where id = v_contract_id;

  v_event_id := public.upsert_contract_calendar_event(
    v_contract.tenant_id,
    v_contract.id,
    v_contract.customer_id,
    v_contract.service_location_id,
    null,
    'billing_due'::public.calendar_event_type,
    v_overdue,
    public.build_contract_calendar_source_key(
      v_contract.id, 'billing', null, null, date_trunc('month', v_overdue)::date
    ),
    jsonb_build_object(
      'coverage_month_key', to_char(date_trunc('month', v_overdue)::date, 'YYYY-MM-DD'),
      'billing_day', v_contract.billing_day
    ),
    'فوترة متأخرة', 'Overdue billing', array[1440, 60]
  );

  update public.calendar_events
  set scheduled_date = v_overdue,
      status = 'pending'::public.calendar_event_status
  where id = v_event_id;

  perform public.sync_contract_calendar_events_internal(v_contract_id, 30);

  select status into v_status
  from public.calendar_events
  where id = v_event_id;

  if v_status <> 'pending'::public.calendar_event_status then
    raise exception 'case17 failed: overdue status=%', v_status;
  end if;
end $$;
rollback;

-- 18. done/missed/manual rows are unchanged by sync.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_done_id uuid;
  v_missed_id uuid;
  v_manual_id uuid;
begin
v_contract_id := pg_temp.p6m12_create_rental(v_fixture, current_date, (current_date + 60)::date);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_done_id uuid;
  v_missed_id uuid;
  v_manual_id uuid;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
select ce.id into v_done_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'billing_due'::public.calendar_event_type
  order by ce.scheduled_date
  limit 1;
  perform set_config('test.p6m12.ctx.v_done_id', v_done_id::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_done_id uuid;
  v_missed_id uuid;
  v_manual_id uuid;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_done_id := nullif(current_setting('test.p6m12.ctx.v_done_id', true), '')::uuid;
select ce.id into v_missed_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
  order by ce.scheduled_date
  limit 1;
  perform set_config('test.p6m12.ctx.v_missed_id', v_missed_id::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_done_id uuid;
  v_missed_id uuid;
  v_manual_id uuid;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_done_id := nullif(current_setting('test.p6m12.ctx.v_done_id', true), '')::uuid;
  v_missed_id := nullif(current_setting('test.p6m12.ctx.v_missed_id', true), '')::uuid;
perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
perform set_config('test.p6m12.done_id', v_done_id::text, true);
perform set_config('test.p6m12.missed_id', v_missed_id::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_done_id', v_done_id::text, true);
  perform set_config('test.p6m12.ctx.v_missed_id', v_missed_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_done_id uuid := current_setting('test.p6m12.done_id')::uuid;
  v_missed_id uuid := current_setting('test.p6m12.missed_id')::uuid;
begin
  update public.calendar_events
  set status = 'done'::public.calendar_event_status
  where id = v_done_id;

  update public.calendar_events
  set status = 'missed'::public.calendar_event_status
  where id = v_missed_id;

  insert into public.calendar_events (
    tenant_id, type, status, scheduled_date,
    contract_id, customer_id, service_location_id,
    title_en, source_kind, source_metadata
  )
  values (
    '00000000-0000-0000-0000-000000000101'::uuid,
    'custom'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    current_date + 12,
    v_contract_id,
    (v_fixture ->> 'customer_id')::uuid,
    (v_fixture ->> 'service_location_id')::uuid,
    'Manual untouched',
    'manual'::public.calendar_event_source_kind,
    '{}'::jsonb
  );
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_done_id uuid := current_setting('test.p6m12.done_id')::uuid;
  v_missed_id uuid := current_setting('test.p6m12.missed_id')::uuid;
  v_done_status public.calendar_event_status;
  v_missed_status public.calendar_event_status;
  v_manual_pending int;
begin
  perform public.sync_contract_calendar_events_internal(v_contract_id, 30);

  select status into v_done_status from public.calendar_events where id = v_done_id;
  select status into v_missed_status from public.calendar_events where id = v_missed_id;

  select count(*) into v_manual_pending
  from public.calendar_events
  where contract_id = v_contract_id
    and source_kind = 'manual'::public.calendar_event_source_kind
    and title_en = 'Manual untouched'
    and status = 'pending'::public.calendar_event_status;

  if v_done_status <> 'done'::public.calendar_event_status
    or v_missed_status <> 'missed'::public.calendar_event_status
    or v_manual_pending <> 1 then
    raise exception 'case18 failed: done=% missed=% manual=%',
      v_done_status, v_missed_status, v_manual_pending;
  end if;
end $$;
rollback;

-- 19. Suspended keeps trial_ending and contract_end.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_trial_id uuid;
  v_rental_id uuid;
begin
  v_trial_id := public.create_trial_contract(
    jsonb_build_object(
      'customer_id', v_fixture ->> 'customer_id',
      'service_location_id', v_fixture ->> 'service_location_id',
      'start_date', current_date,
      'trial_days', 7,
      'asset_lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', v_fixture ->> 'asset_product',
          'product_unit_id', v_fixture ->> 'unit_a'
        )
      )
    ),
    gen_random_uuid()
  );

  v_rental_id := pg_temp.p6m12_create_rental(
    v_fixture,
    current_date,
    (current_date + 25)::date,
    5,
    7,
    1,
    'unit_b'
  );

  perform set_config('test.p6m12.trial_id', v_trial_id::text, true);
  perform set_config('test.p6m12.rental_id', v_rental_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_trial_id uuid := current_setting('test.p6m12.trial_id')::uuid;
  v_rental_id uuid := current_setting('test.p6m12.rental_id')::uuid;
  v_trial_end int;
  v_contract_end int;
  v_billing int;
begin
  perform public.allow_contract_write();
  update public.contracts set status = 'suspended'::public.contract_status where id = v_trial_id;
  perform public.allow_contract_write();
  update public.contracts set status = 'suspended'::public.contract_status where id = v_rental_id;

  select count(*) into v_trial_end
  from public.calendar_events
  where contract_id = v_trial_id
    and type = 'trial_ending'::public.calendar_event_type
    and status = 'pending'::public.calendar_event_status;

  select count(*) into v_contract_end
  from public.calendar_events
  where contract_id = v_rental_id
    and type = 'contract_end'::public.calendar_event_type
    and status = 'pending'::public.calendar_event_status;

  select count(*) into v_billing
  from public.calendar_events
  where contract_id = v_rental_id
    and type = 'billing_due'::public.calendar_event_type
    and status = 'pending'::public.calendar_event_status
    and scheduled_date >= current_date;

  if v_trial_end <> 1 or v_contract_end <> 1 or v_billing <> 0 then
    raise exception 'case19 failed: trial_end=% contract_end=% billing=%',
      v_trial_end, v_contract_end, v_billing;
  end if;
end $$;
rollback;

-- 20. Consumable change merges into outstanding refill on the same date (M2 Rule 1).
-- Merge-date fixture = day 15 of next month so extract(day) is always in 1..28
-- (valid refill_day) independently of the suite execution date.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_merge_date date := (date_trunc('month', current_date) + interval '1 month' + interval '14 days')::date;
  v_outstanding_id uuid;
  v_count int;
  v_action text;
begin
v_contract_id := pg_temp.p6m12_create_rental(
    v_fixture,
    current_date,
    (current_date + interval '12 months')::date,
    5,
    extract(day from v_merge_date)::int,
    1
  );
select cl.id into v_line_id
  from public.contract_lines cl
  where cl.contract_id = v_contract_id
    and cl.line_type = 'consumable'::public.contract_line_type
  limit 1;
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
  perform set_config('test.p6m12.ctx.v_merge_date', v_merge_date::text, true);
  perform set_config('test.p6m12.ctx.v_line_id', v_line_id::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_merge_date date := (date_trunc('month', current_date) + interval '1 month' + interval '14 days')::date;
  v_outstanding_id uuid;
  v_count int;
  v_action text;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_merge_date := nullif(current_setting('test.p6m12.ctx.v_merge_date', true), '')::date;
  v_line_id := nullif(current_setting('test.p6m12.ctx.v_line_id', true), '')::uuid;
select ce.id into v_outstanding_id
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status
  limit 1;
  perform set_config('test.p6m12.ctx.v_outstanding_id', v_outstanding_id::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_line_id uuid;
  v_merge_date date := (date_trunc('month', current_date) + interval '1 month' + interval '14 days')::date;
  v_outstanding_id uuid;
  v_count int;
  v_action text;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_merge_date := nullif(current_setting('test.p6m12.ctx.v_merge_date', true), '')::date;
  v_line_id := nullif(current_setting('test.p6m12.ctx.v_line_id', true), '')::uuid;
  v_outstanding_id := nullif(current_setting('test.p6m12.ctx.v_outstanding_id', true), '')::uuid;
perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
perform set_config('test.p6m12.line_id', v_line_id::text, true);
perform set_config('test.p6m12.merge_date', v_merge_date::text, true);
perform set_config('test.p6m12.outstanding_id', v_outstanding_id::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_line_id', v_line_id::text, true);
  perform set_config('test.p6m12.ctx.v_merge_date', v_merge_date::text, true);
  perform set_config('test.p6m12.ctx.v_outstanding_id', v_outstanding_id::text, true);
end $$;
set local role postgres;
do $$
begin
  update public.calendar_events
  set scheduled_date = current_setting('test.p6m12.merge_date')::date
  where id = current_setting('test.p6m12.outstanding_id')::uuid;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_line_id uuid := current_setting('test.p6m12.line_id')::uuid;
  v_merge_date date := current_setting('test.p6m12.merge_date')::date;
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
      'reason', 'merge with regular refill'
    ),
    gen_random_uuid()
  );
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_line_id', v_line_id::text, true);
  perform set_config('test.p6m12.ctx.v_fixture', v_fixture::text, true);
  perform set_config('test.p6m12.ctx.v_merge_date', v_merge_date::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_line_id uuid := current_setting('test.p6m12.line_id')::uuid;
  v_merge_date date := current_setting('test.p6m12.merge_date')::date;
  v_count int;
  v_action text;
begin
  v_contract_id := nullif(current_setting('test.p6m12.ctx.v_contract_id', true), '')::uuid;
  v_line_id := nullif(current_setting('test.p6m12.ctx.v_line_id', true), '')::uuid;
  v_fixture := nullif(current_setting('test.p6m12.ctx.v_fixture', true), '')::jsonb;
  v_merge_date := nullif(current_setting('test.p6m12.ctx.v_merge_date', true), '')::date;
select count(*), max(ce.source_metadata ->> 'action_kind')
  into v_count, v_action
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.scheduled_date = v_merge_date
    and ce.status = 'pending'::public.calendar_event_status;
if v_count <> 1 or v_action <> 'refill_with_consumable_change' then
    raise exception 'case20 failed: count=% action=% date=%', v_count, v_action, v_merge_date;
end if;
  perform set_config('test.p6m12.ctx.v_count', v_count::text, true);
  perform set_config('test.p6m12.ctx.v_action', v_action::text, true);
  perform set_config('test.p6m12.ctx.v_contract_id', v_contract_id::text, true);
  perform set_config('test.p6m12.ctx.v_merge_date', v_merge_date::text, true);
end $$;
rollback;

-- 21. First refill cadence anchor after Rule 0 oil is already materialized (freq 1 and 3).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_start date := date '2026-07-01';
  v_refill_day int := 5;
  v_contract_f1 uuid;
  v_contract_f3 uuid;
begin
  v_contract_f1 := pg_temp.p6m12_create_rental(
    v_fixture,
    v_start,
    (v_start + interval '12 months')::date,
    10,
    v_refill_day,
    1
  );

  v_contract_f3 := pg_temp.p6m12_create_rental(
    v_fixture,
    v_start,
    (v_start + interval '12 months')::date,
    10,
    v_refill_day,
    3,
    'unit_b'
  );

  perform set_config('test.p6m12.contract_f1', v_contract_f1::text, true);
  perform set_config('test.p6m12.contract_f3', v_contract_f3::text, true);
end $$;
set local role postgres;
do $$
declare
  v_contract_id uuid;
begin
  foreach v_contract_id in array array[
    current_setting('test.p6m12.contract_f1')::uuid,
    current_setting('test.p6m12.contract_f3')::uuid
  ] loop
    update public.calendar_events ce
    set status = 'cancelled'::public.calendar_event_status
    where ce.contract_id = v_contract_id
      and ce.type = 'refill_due'::public.calendar_event_type
      and ce.status = 'pending'::public.calendar_event_status;

    update public.contract_oil_changes coc
    set
      calendar_materialization_status = 'materialized',
      calendar_event_id = (
        select ce.id
        from public.calendar_events ce
        where ce.contract_id = v_contract_id
          and ce.type = 'refill_due'::public.calendar_event_type
        order by ce.created_at desc
        limit 1
      )
    where coc.contract_id = v_contract_id;

    perform public.sync_contract_calendar_events_core_internal(v_contract_id, 60);
  end loop;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
set local role postgres;
do $$
declare
  v_contract_f1 uuid := current_setting('test.p6m12.contract_f1')::uuid;
  v_contract_f3 uuid := current_setting('test.p6m12.contract_f3')::uuid;
  v_first_f1 date;
  v_first_f3 date;
begin
  select min(ce.scheduled_date) into v_first_f1
  from public.calendar_events ce
  where ce.contract_id = v_contract_f1
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  select min(ce.scheduled_date) into v_first_f3
  from public.calendar_events ce
  where ce.contract_id = v_contract_f3
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.status = 'pending'::public.calendar_event_status;

  if v_first_f1 <> date '2026-08-05' or v_first_f3 <> date '2026-10-05' then
    raise exception 'case21 failed: f1=% f3=%', v_first_f1, v_first_f3;
  end if;
end $$;
rollback;

-- 22. Manual billing event is excluded from generated-only upcoming_schedule.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p6m12_configure_calendar(); end $$;
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
  v_manual_id uuid;
  v_schedule jsonb;
begin
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture);

  v_manual_id := gen_random_uuid();
  insert into public.calendar_events (
    id, tenant_id, type, status, scheduled_date,
    contract_id, customer_id, service_location_id,
    title_en, source_kind, source_metadata
  )
  values (
    v_manual_id,
    '00000000-0000-0000-0000-000000000101'::uuid,
    'billing_due'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    current_date + 9,
    v_contract_id,
    (v_fixture ->> 'customer_id')::uuid,
    (v_fixture ->> 'service_location_id')::uuid,
    'Manual billing follow-up',
    'manual'::public.calendar_event_source_kind,
    '{}'::jsonb
  );

  v_schedule := coalesce(
    public.get_contract_detail(v_contract_id) -> 'upcoming_schedule',
    '[]'::jsonb
  );

  if v_schedule @> jsonb_build_array(jsonb_build_object('id', v_manual_id::text)) then
    raise exception 'case22 failed: manual billing leaked into upcoming_schedule';
  end if;
end $$;
rollback;

-- 23. Schedule sync creates no visits/invoices/vouchers/journals/movements or stock drift.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform set_config('test.p6m12.customers', pg_temp.p6m12_customer_setup()::text, false); end $$;
set local role postgres;
do $$ begin perform set_config('test.p6m12.fixture', pg_temp.p6m12_inventory_setup(current_setting('test.p6m12.customers')::jsonb)::text, false); end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := current_setting('test.p6m12.fixture')::jsonb;
  v_contract_id uuid;
begin
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture);
  perform set_config('test.p6m12.contract_id', v_contract_id::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_contract_id uuid := current_setting('test.p6m12.contract_id')::uuid;
  v_product uuid := (current_setting('test.p6m12.fixture')::jsonb ->> 'asset_product')::uuid;
  v_warehouse uuid := (current_setting('test.p6m12.fixture')::jsonb ->> 'main_warehouse')::uuid;
  v_visits_before int;
  v_invoices_before int;
  v_vouchers_before int;
  v_journals_before int;
  v_movements_before int;
  v_stock_before numeric(15,3);
  v_visits_after int;
  v_invoices_after int;
  v_vouchers_after int;
  v_journals_after int;
  v_movements_after int;
  v_stock_after numeric(15,3);
begin
  select count(*) into v_visits_before from public.visits where tenant_id = v_tenant;
  select count(*) into v_invoices_before from public.invoices where tenant_id = v_tenant;
  select count(*) into v_vouchers_before from public.vouchers where tenant_id = v_tenant;
  select count(*) into v_journals_before from public.journal_entries where tenant_id = v_tenant;
  select count(*) into v_movements_before from public.inventory_movements where tenant_id = v_tenant;
  select qty_available into v_stock_before
  from public.inventory_balances
  where tenant_id = v_tenant
    and warehouse_id = v_warehouse
    and product_id = v_product;

  perform public.sync_contract_calendar_events_internal(v_contract_id, 30);

  select count(*) into v_visits_after from public.visits where tenant_id = v_tenant;
  select count(*) into v_invoices_after from public.invoices where tenant_id = v_tenant;
  select count(*) into v_vouchers_after from public.vouchers where tenant_id = v_tenant;
  select count(*) into v_journals_after from public.journal_entries where tenant_id = v_tenant;
  select count(*) into v_movements_after from public.inventory_movements where tenant_id = v_tenant;
  select qty_available into v_stock_after
  from public.inventory_balances
  where tenant_id = v_tenant
    and warehouse_id = v_warehouse
    and product_id = v_product;

  if v_visits_after <> v_visits_before
    or v_invoices_after <> v_invoices_before
    or v_vouchers_after <> v_vouchers_before
    or v_journals_after <> v_journals_before
    or v_movements_after <> v_movements_before
    or v_stock_after is distinct from v_stock_before then
    raise exception 'case23 failed: visits %->% invoices %->% vouchers %->% journals %->% movements %->% stock %->%',
      v_visits_before, v_visits_after,
      v_invoices_before, v_invoices_after,
      v_vouchers_before, v_vouchers_after,
      v_journals_before, v_journals_after,
      v_movements_before, v_movements_after,
      v_stock_before, v_stock_after;
  end if;
end $$;
rollback;


-- M12 regression after M4 ACL: authenticated cannot direct-read calendar_events.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p6m12_assert_no_direct_select_authenticated(); end $$;
set local role postgres;
do $$
declare
  v_fixture jsonb;
  v_contract_id uuid;
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_fixture := pg_temp.p6m12_inventory_setup(pg_temp.p6m12_customer_setup());
  v_contract_id := pg_temp.p6m12_create_rental(v_fixture);
  select count(*)::int into v_count
  from public.calendar_events ce
  where ce.contract_id = v_contract_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind;
  if v_count < 1 then
    raise exception 'm12 regression failed: trusted verification count=%', v_count;
  end if;
end $$;
rollback;

select 'phase_6_contract_calendar_handoff passed'::text as result;
