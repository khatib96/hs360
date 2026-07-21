-- Phase 7 M12 Gate E manual fixtures (tag P7M12).
-- Local/test DB only. Idempotent enough to re-run after cleanup.
\set ON_ERROR_STOP on

select set_config('p7m12.tag', 'P7M12', false);

-- Grant assigned-only calendar view to seed field agent (EMP-002 / field@).
-- Does not grant calendar.edit / calendar.view (manager-wide).
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101'::uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201'::uuid;
  v_field_tu uuid;
  v_perm_id text := 'calendar.view_assigned';
begin
  select tu.id into v_field_tu
  from public.tenant_users tu
  join auth.users u on u.id = tu.user_id
  where tu.tenant_id = v_tenant
    and u.email = 'field@hayat-secret.test'
  limit 1;

  if v_field_tu is null then
    raise exception 'P7M12 fixture: field tenant_user not found';
  end if;

  insert into public.user_permissions (
    tenant_id, tenant_user_id, permission_id, granted_by
  )
  values (v_tenant, v_field_tu, v_perm_id, v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_tag text := 'P7M12';
  v_customer_id uuid;
  v_loc_mapped uuid;
  v_loc_unmapped uuid;
begin
  v_customer_id := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل ' || v_tag || ' قبول',
      'name_en', v_tag || ' Acceptance Customer',
      'phone_primary', '+96550009401',
      'create_account', true
    )
  );

  v_loc_mapped := public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', v_tag || ' Mapped Branch',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550009401',
      'latitude', 29.3390,
      'longitude', 48.0750
    )
  );

  v_loc_unmapped := public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', v_tag || ' Unmapped Branch',
      'location_type', 'branch',
      'governorate', 'Farwaniya',
      'area', 'Khaitan',
      'contact_person_phone', '+96550009402'
      -- no coordinates → safe degrade / missing location evidence
    )
  );

  perform set_config('p7m12.customer_id', v_customer_id::text, false);
  perform set_config('p7m12.loc_mapped_id', v_loc_mapped::text, false);
  perform set_config('p7m12.loc_unmapped_id', v_loc_unmapped::text, false);

  raise notice 'P7M12 fixture customer=% mapped=% unmapped=%',
    v_customer_id, v_loc_mapped, v_loc_unmapped;
end $$;

set role postgres;

do $$
declare
  v_tag text := 'P7M12';
  v_tenant uuid := '00000000-0000-0000-0000-000000000101'::uuid;
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801'::uuid;
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701'::uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201'::uuid;
  v_product_id uuid := gen_random_uuid();
  v_unit_id uuid := gen_random_uuid();
  v_serial text := v_tag || '-SN001';
  v_sku text := v_tag || '-AST';
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_product_id, v_tenant, v_sku,
    'جهاز ' || v_tag, v_tag || ' Asset', v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_unit_id, v_tenant, v_product_id, v_serial,
    'available_new', v_main_warehouse, 60.000, current_date
  );

  insert into public.inventory_balances (
    tenant_id, warehouse_id, product_id, qty_available
  )
  values (v_tenant, v_main_warehouse, v_product_id, 1.000)
  on conflict (tenant_id, warehouse_id, product_id)
  do update set qty_available = public.inventory_balances.qty_available + 1.000;

  raise notice 'P7M12 fixture serial=% sku=%', v_serial, v_sku;
end $$;

-- Live UI fixtures: overdue-outside-range + missing-coords route event.
-- Titles tagged P7M12 so cleanup is deterministic.
do $$
declare
  v_tag text := 'P7M12';
  v_tenant uuid := '00000000-0000-0000-0000-000000000101'::uuid;
  v_agent uuid := '00000000-0000-0000-0000-000000000602'::uuid;
  v_customer uuid;
  v_loc_unmapped uuid;
  v_overdue_id uuid := '00000000-0000-7000-8000-00000000e015'::uuid;
  v_route_id uuid := '00000000-0000-7000-8000-00000000e020'::uuid;
begin
  select c.id into v_customer
  from public.customers c
  where c.tenant_id = v_tenant
    and c.name_en like v_tag || ' Acceptance Customer'
  order by c.created_at desc
  limit 1;

  select csl.id into v_loc_unmapped
  from public.customer_service_locations csl
  where csl.tenant_id = v_tenant
    and csl.name = v_tag || ' Unmapped Branch'
  order by csl.created_at desc
  limit 1;

  if v_customer is null or v_loc_unmapped is null then
    raise exception 'P7M12 fixture: customer/unmapped location missing for event seeds';
  end if;

  delete from public.calendar_reminder_plans
  where calendar_event_id in (v_overdue_id, v_route_id);
  delete from public.calendar_event_participants
  where event_id in (v_overdue_id, v_route_id);
  delete from public.calendar_events
  where id in (v_overdue_id, v_route_id);

  insert into public.calendar_events (
    id, tenant_id, type, status, source_kind,
    scheduled_date, original_due_date,
    title_ar, title_en, assigned_agent_id
  ) values (
    v_overdue_id, v_tenant, 'custom', 'pending', 'manual',
    (current_date - 40), (current_date - 55),
    'مهمة متأخرة ' || v_tag,
    v_tag || ' Overdue Pending',
    v_agent
  );

  -- Route missing-coords event is created via RPC after configure
  -- (see p7m12_gate_e_seed_route_event.sql) so Flutter mappers see a
  -- fully shaped customer_visit row.

  raise notice 'P7M12 fixture overdue=% (route event seeded post-configure)',
    v_overdue_id;
end $$;
