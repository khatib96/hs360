-- Phase 4 M5.6: customer service locations verification.
-- Apply migration 047 first:
-- docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/migrations/047_customer_service_locations.sql

\set ON_ERROR_STOP on

-- 1. Manager creates a service location -> LOC-0001.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_id uuid;
  v_loc_id uuid;
  v_code text;
begin
  v_customer_id := create_customer(
    '{"name_ar":"عميل مواقع","phone_primary":"+96550001001"}'::jsonb
  );
  v_loc_id := create_customer_service_location(
    v_customer_id,
    '{"name":"فرع السالمية","location_type":"branch","governorate":"Hawalli","area":"Salmiya"}'::jsonb
  );
  select code into v_code
  from customer_service_locations
  where id = v_loc_id and tenant_id = v_tenant_a;
  if v_code <> 'LOC-0001' then
    raise exception 'case1 failed: expected LOC-0001 got %', v_code;
  end if;
end $$;
rollback;

-- 1b. First active location from UI payload is still primary.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_loc_id uuid;
  v_primary_count int;
begin
  v_customer_id := create_customer(
    '{"name_ar":"first ui location","phone_primary":"+96550001013"}'::jsonb
  );
  v_loc_id := create_customer_service_location(
    v_customer_id,
    '{"name":"First UI location","is_primary":false}'::jsonb
  );

  select count(*)::int into v_primary_count
  from customer_service_locations
  where customer_id = v_customer_id
    and id = v_loc_id
    and is_active
    and is_primary;

  if v_primary_count <> 1 then
    raise exception 'case1b failed: first active location should be primary';
  end if;
end $$;
rollback;

-- 2. User with customers.view can list but not create (no customers.edit).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_customer_id uuid;
  v_rows int;
begin
  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'customers.view', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  v_customer_id := create_customer(
    '{"name_ar":"عميل عرض","phone_primary":"+96550001002","address_line":"عنوان"}'::jsonb
  );

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000203', true);

  select count(*)::int into v_rows
  from list_customer_service_locations(v_customer_id);
  if v_rows < 1 then
    raise exception 'case2 failed: list should return rows';
  end if;

  begin
    perform create_customer_service_location(
      v_customer_id,
      '{"name":"ممنوع"}'::jsonb
    );
    raise exception 'case2 failed: create should be denied';
  exception
    when others then
      if position('permission_denied' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 3. Tenant isolation on p_customer_id.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_a uuid;
begin
  v_customer_a := create_customer(
    '{"name_ar":"عميل عزل","phone_primary":"+96550001012"}'::jsonb
  );
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000204', true);
  begin
    perform list_customer_service_locations(v_customer_a);
    raise exception 'case3 failed: cross-tenant list succeeded';
  exception
    when others then
      if position('validation_failed' in sqlerrm) = 0
        and position('permission_denied' in sqlerrm) = 0
        and position('tenant_not_found' in sqlerrm) = 0
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 4. set_primary leaves one active primary.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_loc_a uuid;
  v_loc_b uuid;
  v_primary_count int;
begin
  v_customer_id := create_customer(
    '{"name_ar":"عميل primary","phone_primary":"+96550001003"}'::jsonb
  );
  v_loc_a := create_customer_service_location(
    v_customer_id,
    '{"name":"موقع أ","is_primary":true}'::jsonb
  );
  v_loc_b := create_customer_service_location(
    v_customer_id,
    '{"name":"موقع ب"}'::jsonb
  );
  perform set_primary_customer_service_location(v_loc_b);
  select count(*)::int into v_primary_count
  from customer_service_locations
  where customer_id = v_customer_id
    and is_active
    and is_primary;
  if v_primary_count <> 1 then
    raise exception 'case4 failed: expected 1 primary got %', v_primary_count;
  end if;
end $$;
rollback;

-- 5. create_customer with address creates primary location.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_loc_count int;
begin
  v_customer_id := create_customer(
    '{"name_ar":"عميل عنوان","phone_primary":"+96550001004","address_line":"شارع 1","governorate":"Capital"}'::jsonb
  );
  select count(*)::int into v_loc_count
  from customer_service_locations
  where customer_id = v_customer_id and is_primary and is_active;
  if v_loc_count <> 1 then
    raise exception 'case5 failed: expected 1 primary location got %', v_loc_count;
  end if;
end $$;
rollback;

-- 6. create_customer without address creates no location.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_loc_count int;
begin
  v_customer_id := create_customer(
    '{"name_ar":"بدون عنوان","phone_primary":"+96550001005"}'::jsonb
  );
  select count(*)::int into v_loc_count
  from customer_service_locations where customer_id = v_customer_id;
  if v_loc_count <> 0 then
    raise exception 'case6 failed: expected 0 locations got %', v_loc_count;
  end if;
end $$;
rollback;

-- 7. create_customer still returns uuid only (regression shape).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_id uuid;
begin
  v_id := create_customer(
    '{"name_ar":"شكل uuid","phone_primary":"+96550001006"}'::jsonb
  );
  if v_id is null then
    raise exception 'case7 failed: create_customer returned null';
  end if;
end $$;
rollback;

-- 8. Composite FK: visit cannot use another customer''s location.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_agent uuid := '00000000-0000-0000-0000-000000000601';
  v_cust_a uuid;
  v_cust_b uuid;
  v_loc_b uuid;
begin
  v_cust_a := create_customer(
    '{"name_ar":"زبون أ","phone_primary":"+96550001007"}'::jsonb
  );
  v_cust_b := create_customer(
    '{"name_ar":"زبون ب","phone_primary":"+96550001008","address_line":"فرع"}'::jsonb
  );
  select id into v_loc_b
  from customer_service_locations
  where customer_id = v_cust_b and tenant_id = v_tenant_a
  limit 1;

  begin
    insert into visits (
      tenant_id, visit_number, type, status,
      customer_id, service_location_id, agent_id, scheduled_date
    )
    values (
      v_tenant_a, 'VST-M56-001', 'refill', 'scheduled',
      v_cust_a, v_loc_b, v_agent, current_date
    );
    raise exception 'case8 failed: cross-customer location visit insert succeeded';
  exception
    when foreign_key_violation then
      null;
  end;
end $$;
rollback;

-- 9. deactivate blocked when visit scheduled.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_agent uuid := '00000000-0000-0000-0000-000000000601';
  v_customer_id uuid;
  v_loc_id uuid;
begin
  v_customer_id := create_customer(
    '{"name_ar":"زيارة","phone_primary":"+96550001009","address_line":"عنوان"}'::jsonb
  );
  select id into v_loc_id
  from customer_service_locations
  where customer_id = v_customer_id and tenant_id = v_tenant_a
  limit 1;

  insert into visits (
    tenant_id, visit_number, type, status,
    customer_id, service_location_id, agent_id, scheduled_date
  )
  values (
    v_tenant_a, 'VST-M56-002', 'refill', 'scheduled',
    v_customer_id, v_loc_id, v_agent, current_date
  );

  begin
    perform deactivate_customer_service_location(v_loc_id);
    raise exception 'case9 failed: deactivate with scheduled visit succeeded';
  exception
    when others then
      if position('location_in_use' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 10. deactivate blocked when calendar event pending.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_id uuid;
  v_loc_id uuid;
begin
  v_customer_id := create_customer(
    '{"name_ar":"تقويم","phone_primary":"+96550001010","governorate":"Capital"}'::jsonb
  );
  select id into v_loc_id
  from customer_service_locations
  where customer_id = v_customer_id and tenant_id = v_tenant_a
  limit 1;

  insert into calendar_events (
    tenant_id, type, status, scheduled_date,
    customer_id, service_location_id
  )
  values (
    v_tenant_a, 'refill_due', 'pending', current_date,
    v_customer_id, v_loc_id
  );

  begin
    perform deactivate_customer_service_location(v_loc_id);
    raise exception 'case10 failed: deactivate with pending calendar succeeded';
  exception
    when others then
      if position('location_in_use' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 11. Snapshot columns exist on contracts.
do $$
declare
  v_count int;
begin
  select count(*)::int into v_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'contracts'
    and column_name in (
      'location_name',
      'location_country',
      'location_governorate',
      'location_area',
      'location_google_maps_url'
    );
  if v_count <> 5 then
    raise exception 'case11 failed: expected 5 snapshot columns got %', v_count;
  end if;
end $$;

-- 12. deactivate primary with other active locations -> primary_required.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_loc_primary uuid;
  v_loc_other uuid;
begin
  v_customer_id := create_customer(
    '{"name_ar":"primary block","phone_primary":"+96550001011"}'::jsonb
  );
  v_loc_primary := create_customer_service_location(
    v_customer_id,
    '{"name":"أساسي","is_primary":true}'::jsonb
  );
  v_loc_other := create_customer_service_location(
    v_customer_id,
    '{"name":"ثانوي"}'::jsonb
  );
  perform set_primary_customer_service_location(v_loc_primary);
  begin
    perform deactivate_customer_service_location(v_loc_primary);
    raise exception 'case12 failed: deactivate primary with alternates succeeded';
  exception
    when others then
      if position('primary_required' in sqlerrm) = 0 then
        raise;
      end if;
  end;
  perform deactivate_customer_service_location(v_loc_other);
end $$;
rollback;

-- 13. update RPC cannot deactivate; use deactivate RPC instead.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_loc_id uuid;
  v_is_active boolean;
begin
  v_customer_id := create_customer(
    '{"name_ar":"update active guard","phone_primary":"+96550001014"}'::jsonb
  );
  v_loc_id := create_customer_service_location(
    v_customer_id,
    '{"name":"Guarded location"}'::jsonb
  );

  begin
    perform update_customer_service_location(
      v_loc_id,
      '{"name":"Guarded location","is_active":false}'::jsonb
    );
    raise exception 'case13 failed: update changed is_active';
  exception
    when others then
      if position('validation_failed' in sqlerrm) = 0 then
        raise;
      end if;
  end;

  select is_active into v_is_active
  from customer_service_locations
  where id = v_loc_id;

  if v_is_active is distinct from true then
    raise exception 'case13 failed: location should remain active';
  end if;
end $$;
rollback;

select 'phase_4_customer_service_locations: all cases passed' as result;
