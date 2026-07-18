\set ON_ERROR_STOP on

-- Phase 7 M10: Route View + directions (migration 102).
-- Seed: tenant_a ...101, manager ...201, zero ...202, field ...205/emp ...602,
-- owner_emp ...601, field tu ...305, tenant_b user ...204.

create or replace function pg_temp.m10_standard_days()
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

create or replace function pg_temp.m10_configure(p_tz text default 'Asia/Kuwait')
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', p_tz,
    'remind_event_workday_start', true,
    'remind_previous_workday_start', false,
    'days', pg_temp.m10_standard_days()
  ));
end; $$;

create or replace function pg_temp.m10_grant_perm(p_tu uuid, p_perm text)
returns void language plpgsql as $$
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (
    '00000000-0000-0000-0000-000000000101',
    p_tu, p_perm, '00000000-0000-0000-0000-000000000201'
  )
  on conflict (tenant_user_id, permission_id) do nothing;
end; $$;

create or replace function pg_temp.m10_expect_error(p_sql text, p_code text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'm10_expect_error: expected % for %', p_code, p_sql;
  exception when others then
    if sqlerrm not like '%' || p_code || '%' then
      raise exception 'm10_expect_error: got % for %', sqlerrm, p_sql;
    end if;
  end;
end; $$;

create or replace function pg_temp.m10_next_weekday(p_iso int, p_from date default current_date)
returns date language sql immutable as $$
  select (p_from + ((p_iso - extract(isodow from p_from)::int + 7) % 7))::date;
$$;

create or replace function pg_temp.m10_create_and_assign(
  p_day date,
  p_title text,
  p_customer uuid,
  p_location uuid,
  p_agent uuid
)
returns uuid language plpgsql as $$
declare
  v_res jsonb;
  v_id uuid;
  v_ver int;
begin
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', to_char(p_day, 'YYYY-MM-DD'),
      'title_ar', p_title,
      'title_en', p_title,
      'customer_id', p_customer::text,
      'service_location_id', p_location::text
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' is distinct from 'ok' then
    raise exception 'm10_create_failed: %', v_res;
  end if;
  v_id := (v_res #>> '{event,id}')::uuid;
  if p_agent is not null then
    v_ver := coalesce((v_res #>> '{event,schedule_version}')::int, 1);
    v_res := public.assign_calendar_event(
      v_id, v_ver,
      jsonb_build_object('assigned_agent_id', p_agent::text),
      gen_random_uuid()
    );
    if v_res ->> 'status' is distinct from 'ok' then
      raise exception 'm10_assign_failed: %', v_res;
    end if;
  end if;
  return v_id;
end; $$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
do $$
begin
  if has_function_privilege(
    'anon', 'public.get_calendar_route_day(date, uuid)', 'EXECUTE'
  ) then
    raise exception 'm10 fail: anon execute';
  end if;
  if not has_function_privilege(
    'authenticated', 'public.get_calendar_event_directions(uuid)', 'EXECUTE'
  ) then
    raise exception 'm10 fail: directions grant';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Main behavioral suite
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m10_configure();
select pg_temp.m10_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.view_assigned');

do $$
declare
  v_cust uuid;
  v_loc_mapped uuid;
  v_loc_url uuid;
  v_loc_bad uuid;
  v_loc_miss uuid;
  v_day date := pg_temp.m10_next_weekday(2);
  v_assignee uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_evt_mapped uuid;
  v_evt_url uuid;
  v_evt_bad_url uuid;
  v_evt_miss uuid;
  v_evt_unassigned uuid;
  v_evt_creator uuid;
  v_evt_part uuid;
  v_route jsonb;
  v_list jsonb;
  v_dir jsonb;
  v_point jsonb;
  v_ver int;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform set_config('role', 'authenticated', true);

  v_cust := public.create_customer(jsonb_build_object(
    'name_ar', 'عميل مسار', 'name_en', 'Route Cust', 'phone_primary', '+96550029101'
  ));
  v_loc_mapped := public.create_customer_service_location(v_cust, jsonb_build_object(
    'name', 'Mapped', 'location_type', 'branch', 'governorate', 'Capital', 'area', 'Kuwait City',
    'latitude', 29.3759, 'longitude', 47.9774
  ));
  v_loc_url := public.create_customer_service_location(v_cust, jsonb_build_object(
    'name', 'UrlOnly', 'location_type', 'branch', 'governorate', 'Capital', 'area', 'Sharq',
    'google_maps_url', 'https://maps.app.goo.gl/m10urlonly'
  ));
  v_loc_bad := public.create_customer_service_location(v_cust, jsonb_build_object(
    'name', 'BadUrl', 'location_type', 'branch', 'governorate', 'Hawalli', 'area', 'Salmiya',
    'google_maps_url', 'https://www.google.com/maps/@29.3,48.0,17z'
  ));
  -- Incomplete coordinate pair cannot be persisted (normalize trigger).
  -- Resolution order for invalid coords + allowlisted URL is asserted via helpers.

  v_loc_miss := public.create_customer_service_location(v_cust, jsonb_build_object(
    'name', 'Missing', 'location_type', 'branch', 'governorate', 'Farwaniya', 'area', 'Khaitan'
  ));

  v_evt_mapped := pg_temp.m10_create_and_assign(v_day, 'mapped', v_cust, v_loc_mapped, v_assignee);
  v_evt_url := pg_temp.m10_create_and_assign(v_day, 'url', v_cust, v_loc_url, v_assignee);
  v_evt_bad_url := pg_temp.m10_create_and_assign(v_day, 'badurl', v_cust, v_loc_bad, v_assignee);
  v_evt_miss := pg_temp.m10_create_and_assign(v_day, 'miss', v_cust, v_loc_miss, v_assignee);
  v_evt_unassigned := pg_temp.m10_create_and_assign(v_day, 'unassigned', v_cust, v_loc_mapped, null);
  v_evt_creator := pg_temp.m10_create_and_assign(v_day, 'creator', v_cust, v_loc_mapped, v_owner_emp);

  v_evt_part := pg_temp.m10_create_and_assign(v_day, 'participant', v_cust, v_loc_mapped, v_owner_emp);
  v_list := public.list_calendar_events(v_day, v_day, '{}'::jsonb, null, null, 100, false);
  select (e ->> 'schedule_version')::int into v_ver
  from jsonb_array_elements(v_list -> 'in_range' -> 'rows') e
  where e ->> 'id' = v_evt_part::text;
  if v_ver is null then
    raise exception 'm10 fail: participant event version';
  end if;
  perform public.update_manual_calendar_event(
    v_evt_part, v_ver,
    jsonb_build_object(
      'participant_employee_ids', jsonb_build_array(v_assignee::text)
    ),
    gen_random_uuid()
  );

  -- No permission (zero-perm user)
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000202', true);
  perform pg_temp.m10_expect_error(
    format($q$select public.get_calendar_route_day(%L::date, %L::uuid)$q$, v_day, v_assignee),
    'permission_denied'
  );

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  v_route := public.get_calendar_route_day(v_day, v_assignee);
  if (v_route ->> 'has_more')::boolean then
    raise exception 'm10 fail: unexpected has_more';
  end if;
  if v_route ->> 'employee_id' is distinct from v_assignee::text then
    raise exception 'm10 fail: employee echo';
  end if;
  if v_route ? 'bounds' or v_route ? 'total_count' then
    raise exception 'm10 fail: leaked bounds/total';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_route -> 'points') p
    where p -> 'event' ->> 'id' = v_evt_mapped::text
      and p ->> 'location_state' = 'mapped'
      and p ? 'latitude' and p ? 'longitude'
      and not (p ? 'google_maps_url')
      and not ((p -> 'event') ? 'latitude')
      and not ((p -> 'event') ? 'google_maps_url')
  ) then
    raise exception 'm10 fail: mapped point';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_route -> 'points') p
    where p -> 'event' ->> 'id' = v_evt_url::text
      and p ->> 'location_state' = 'url_only'
      and p ->> 'latitude' is null
  ) then
    raise exception 'm10 fail: url_only';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_route -> 'points') p
    where p -> 'event' ->> 'id' = v_evt_bad_url::text
      and p ->> 'location_state' = 'url_only'
      and p ->> 'latitude' is null
  ) then
    raise exception 'm10 fail: URL-only location state';
  end if;

  -- Helper resolution order (helpers revoked from authenticated; use elevated role)
  reset role;
  if public.calendar_location_state(29.3, 48.0, null) is distinct from 'mapped'
    or public.calendar_location_state(999, 47, 'https://www.google.com/maps/@29.3,48.0,17z')
         is distinct from 'url_only'
    or public.calendar_location_state(999, 47, null) is distinct from 'invalid'
    or public.calendar_location_state(null, null, null) is distinct from 'missing'
    or public.calendar_directions_available_from_location(
         999, 47, 'https://maps.app.goo.gl/x'
       ) is not true then
    raise exception 'm10 fail: location_state resolution order';
  end if;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  if not exists (
    select 1 from jsonb_array_elements(v_route -> 'points') p
    where p -> 'event' ->> 'id' = v_evt_miss::text
      and p ->> 'location_state' = 'missing'
  ) then
    raise exception 'm10 fail: missing';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v_route -> 'points') p
    where p -> 'event' ->> 'id' in (v_evt_unassigned::text, v_evt_creator::text)
  ) then
    raise exception 'm10 fail: unassigned/creator-only leaked';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_route -> 'points') p
    where p -> 'event' ->> 'id' = v_evt_part::text
  ) then
    raise exception 'm10 fail: participant missing';
  end if;

  -- list_calendar_events url_only flags, no coords/url
  v_list := public.list_calendar_events(v_day, v_day, '{}'::jsonb, null, null, 100, false);
  select e into v_point
  from jsonb_array_elements(v_list -> 'in_range' -> 'rows') e
  where e ->> 'id' = v_evt_url::text;
  if v_point is null
    or (v_point ->> 'directions_available')::boolean is not true
    or (v_point -> 'available_actions' ->> 'can_open_directions')::boolean is not true
    or v_point ? 'latitude' or v_point ? 'google_maps_url' then
    raise exception 'm10 fail: list url_only flags/leak';
  end if;

  v_dir := public.get_calendar_event_directions(v_evt_mapped);
  if v_dir ->> 'location_state' is distinct from 'mapped'
    or v_dir ->> 'maps_url' not like 'https://www.google.com/maps/dir/%' then
    raise exception 'm10 fail: directions mapped';
  end if;

  v_dir := public.get_calendar_event_directions(v_evt_url);
  if v_dir ->> 'location_state' is distinct from 'url_only'
    or v_dir ->> 'maps_url' is distinct from 'https://maps.app.goo.gl/m10urlonly'
    or v_dir ? 'latitude' then
    raise exception 'm10 fail: directions url_only';
  end if;

  v_dir := public.get_calendar_event_directions(v_evt_bad_url);
  if v_dir ->> 'location_state' is distinct from 'url_only' then
    raise exception 'm10 fail: directions bad+url';
  end if;

  perform pg_temp.m10_expect_error(
    format($q$select public.get_calendar_event_directions(%L)$q$, v_evt_miss),
    'validation_failed'
  );

  reset role;
  update public.customer_service_locations
  set google_maps_url = 'https://goo.gl/maps/x', latitude = null, longitude = null
  where id = v_loc_miss;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform pg_temp.m10_expect_error(
    format($q$select public.get_calendar_event_directions(%L)$q$, v_evt_miss),
    'validation_failed'
  );

  v_list := public.list_calendar_route_employees(null, 1);
  if (v_list ->> 'has_more')::boolean is not true
    or jsonb_array_length(v_list -> 'rows') <> 1 then
    raise exception 'm10 fail: employees has_more';
  end if;

  -- Assigned-only
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000205', true);
  v_route := public.get_calendar_route_day(v_day, null);
  if v_route ->> 'employee_id' is distinct from v_assignee::text then
    raise exception 'm10 fail: assigned self';
  end if;
  perform pg_temp.m10_expect_error(
    format($q$select public.get_calendar_route_day(%L::date, %L::uuid)$q$, v_day, v_owner_emp),
    'permission_denied'
  );
  perform pg_temp.m10_expect_error(
    $q$select public.list_calendar_route_employees(null, 10)$q$,
    'permission_denied'
  );
  v_dir := public.get_calendar_event_directions(v_evt_mapped);
  if v_dir ->> 'location_state' is distinct from 'mapped' then
    raise exception 'm10 fail: assigned directions';
  end if;

  -- Tenant isolation
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000204', true);
  perform pg_temp.m10_expect_error(
    format($q$select public.get_calendar_event_directions(%L)$q$, v_evt_mapped),
    'not_found'
  );
end $$;
rollback;

-- has_more day page
begin;
select pg_temp.m10_configure();
do $$
declare
  v_cust uuid;
  v_loc uuid;
  v_day date := pg_temp.m10_next_weekday(3);
  v_agent uuid := '00000000-0000-0000-0000-000000000602';
  v_i int;
  v_route jsonb;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform set_config('role', 'authenticated', true);
  v_cust := public.create_customer(jsonb_build_object(
    'name_ar', 'كثير', 'name_en', 'Many', 'phone_primary', '+96550029102'
  ));
  v_loc := public.create_customer_service_location(v_cust, jsonb_build_object(
    'name', 'ManyLoc', 'location_type', 'branch', 'governorate', 'Capital', 'area', 'Qibla',
    'latitude', 29.3, 'longitude', 48.0
  ));
  for v_i in 1..105 loop
    perform pg_temp.m10_create_and_assign(
      v_day, 'bulk' || v_i::text, v_cust, v_loc, v_agent
    );
  end loop;
  v_route := public.get_calendar_route_day(v_day, v_agent);
  if jsonb_array_length(v_route -> 'points') <> 100
    or (v_route ->> 'has_more')::boolean is not true then
    raise exception 'm10 fail: day has_more page';
  end if;
end $$;
rollback;

\echo 'phase_7_calendar_route_view.sql passed'
