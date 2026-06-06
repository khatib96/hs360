-- Phase 4 M5.7: Google Maps URL coordinate verification.
-- Apply migrations 050 and 051 before running this file.

\set ON_ERROR_STOP on

-- 1. Customer creation stores resolved URL coordinates on the primary location.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_row customer_service_locations%rowtype;
begin
  v_customer_id := create_customer(
    '{
      "name_ar":"M57 URL Create",
      "phone_primary":"+96550005701",
      "google_maps_url":"https://maps.app.goo.gl/create",
      "latitude":29.3759,
      "longitude":47.9774,
      "resolution_source":"url",
      "resolved_at":"2026-06-06T08:30:00Z",
      "resolution_status":"resolved"
    }'::jsonb
  );

  select * into v_row
  from customer_service_locations
  where customer_id = v_customer_id and is_primary and is_active;

  if v_row.id is null
    or v_row.google_maps_url <> 'https://maps.app.goo.gl/create'
    or v_row.latitude <> 29.3759
    or v_row.longitude <> 47.9774
    or v_row.resolution_source <> 'url'
    or v_row.resolution_status <> 'resolved'
    or v_row.resolved_at is null
  then
    raise exception 'case1 failed: primary location URL coordinates missing';
  end if;
end $$;
rollback;

-- 2. A service location stores coordinates resolved from its pasted link.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_location_id uuid;
  v_row customer_service_locations%rowtype;
begin
  v_customer_id := create_customer(
    '{"name_ar":"M57 URL Site","phone_primary":"+96550005702"}'::jsonb
  );
  v_location_id := create_customer_service_location(
    v_customer_id,
    '{
      "name":"Resolved Site",
      "google_maps_url":"https://www.google.com/maps/@29.31,48.01,17z",
      "latitude":29.31,
      "longitude":48.01,
      "resolution_source":"url",
      "resolved_at":"2026-06-06T09:00:00Z",
      "resolution_status":"resolved"
    }'::jsonb
  );

  select * into v_row
  from customer_service_locations
  where id = v_location_id;

  if v_row.latitude <> 29.31
    or v_row.longitude <> 48.01
    or v_row.resolution_source <> 'url'
    or v_row.resolution_status <> 'resolved'
  then
    raise exception 'case2 failed: service-location URL coordinates missing';
  end if;
end $$;
rollback;

-- 3. Customer edits synchronize a new link and coordinates to the primary location.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_row customer_service_locations%rowtype;
begin
  v_customer_id := create_customer(
    '{
      "name_ar":"M57 URL Update",
      "phone_primary":"+96550005703",
      "google_maps_url":"https://maps.app.goo.gl/old",
      "latitude":29.30,
      "longitude":48.00,
      "resolution_source":"url",
      "resolution_status":"resolved"
    }'::jsonb
  );

  perform update_customer(
    v_customer_id,
    '{
      "google_maps_url":"https://maps.app.goo.gl/new",
      "latitude":29.40,
      "longitude":48.10,
      "resolution_source":"url",
      "resolved_at":"2026-06-06T10:00:00Z",
      "coordinate_accuracy_m":null,
      "resolution_status":"resolved",
      "resolution_error":null
    }'::jsonb
  );

  select * into v_row
  from customer_service_locations
  where customer_id = v_customer_id and is_primary and is_active;

  if v_row.google_maps_url <> 'https://maps.app.goo.gl/new'
    or v_row.latitude <> 29.40
    or v_row.longitude <> 48.10
    or v_row.resolution_source <> 'url'
  then
    raise exception 'case3 failed: primary location was not synchronized';
  end if;
end $$;
rollback;

-- 4. Clearing the customer map link also clears primary coordinates.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_row customer_service_locations%rowtype;
begin
  v_customer_id := create_customer(
    '{
      "name_ar":"M57 URL Clear",
      "phone_primary":"+96550005704",
      "google_maps_url":"https://maps.app.goo.gl/clear",
      "latitude":29.30,
      "longitude":48.00,
      "resolution_source":"url",
      "resolution_status":"resolved"
    }'::jsonb
  );

  perform update_customer(
    v_customer_id,
    '{
      "google_maps_url":null,
      "latitude":null,
      "longitude":null,
      "resolution_source":null,
      "resolved_at":null,
      "coordinate_accuracy_m":null,
      "resolution_status":null,
      "resolution_error":null
    }'::jsonb
  );

  select * into v_row
  from customer_service_locations
  where customer_id = v_customer_id and is_primary and is_active;

  if v_row.google_maps_url is not null
    or v_row.latitude is not null
    or v_row.longitude is not null
    or v_row.resolution_source is not null
    or v_row.resolution_status is not null
  then
    raise exception 'case4 failed: URL coordinate metadata was not cleared';
  end if;
end $$;
rollback;

-- 5. Partial and out-of-range coordinates remain rejected.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
begin
  v_customer_id := create_customer(
    '{"name_ar":"M57 Invalid","phone_primary":"+96550005705"}'::jsonb
  );

  begin
    perform create_customer_service_location(
      v_customer_id,
      '{"name":"Partial","latitude":29.3,"resolution_source":"url"}'::jsonb
    );
    raise exception 'case5 failed: partial coordinates succeeded';
  exception
    when others then
      if position('validation_failed' in sqlerrm) = 0 then
        raise;
      end if;
  end;

  begin
    perform create_customer_service_location(
      v_customer_id,
      '{"name":"Invalid","latitude":91,"longitude":48,"resolution_source":"url"}'::jsonb
    );
    raise exception 'case5 failed: invalid latitude succeeded';
  exception
    when others then
      if position('validation_failed' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end $$;
rollback;

-- 6. Primary and additional locations keep independent map coordinates.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer_id uuid;
  v_secondary_id uuid;
  v_primary customer_service_locations%rowtype;
  v_secondary customer_service_locations%rowtype;
begin
  v_customer_id := create_customer(
    '{
      "name_ar":"M57 Primary And Secondary",
      "phone_primary":"+96550005706",
      "google_maps_url":"https://maps.app.goo.gl/primary",
      "latitude":25.7800955,
      "longitude":55.9693682,
      "resolution_source":"url",
      "resolved_at":"2026-06-06T17:12:40Z",
      "resolution_status":"resolved"
    }'::jsonb
  );

  v_secondary_id := create_customer_service_location(
    v_customer_id,
    '{
      "name":"Secondary Site",
      "google_maps_url":"https://maps.app.goo.gl/secondary-old",
      "latitude":29.3000000,
      "longitude":48.0000000,
      "resolution_source":"url",
      "resolved_at":"2026-06-06T18:00:00Z",
      "resolution_status":"resolved",
      "is_primary":false
    }'::jsonb
  );

  perform update_customer_service_location(
    v_secondary_id,
    '{
      "name":"Secondary Site",
      "google_maps_url":"https://maps.app.goo.gl/secondary-new",
      "latitude":29.4000000,
      "longitude":48.1000000,
      "resolution_source":"url",
      "resolved_at":"2026-06-06T19:00:00Z",
      "coordinate_accuracy_m":null,
      "resolution_status":"resolved",
      "resolution_error":null
    }'::jsonb
  );

  select * into v_primary
  from customer_service_locations
  where customer_id = v_customer_id and is_primary and is_active;

  select * into v_secondary
  from customer_service_locations
  where id = v_secondary_id;

  if v_primary.google_maps_url <> 'https://maps.app.goo.gl/primary'
    or v_primary.latitude <> 25.7800955
    or v_primary.longitude <> 55.9693682
    or v_primary.resolution_source <> 'url'
  then
    raise exception 'case6 failed: primary location coordinates changed';
  end if;

  if v_secondary.is_primary
    or v_secondary.google_maps_url <> 'https://maps.app.goo.gl/secondary-new'
    or v_secondary.latitude <> 29.4000000
    or v_secondary.longitude <> 48.1000000
    or v_secondary.resolution_source <> 'url'
    or v_secondary.resolution_status <> 'resolved'
  then
    raise exception 'case6 failed: secondary location coordinates were not independent';
  end if;
end $$;
rollback;

select 'phase_4_service_location_coordinates: all cases passed' as result;
