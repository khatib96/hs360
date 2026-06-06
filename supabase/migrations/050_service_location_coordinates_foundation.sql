-- Phase 4 M5.7: reliable service-location coordinates and capture metadata.

alter table customer_service_locations
  add column if not exists resolution_source text,
  add column if not exists resolved_at timestamptz,
  add column if not exists coordinate_accuracy_m numeric(10, 2),
  add column if not exists resolution_status text,
  add column if not exists resolution_error text;

do $$
begin
  if exists (
    select 1
    from customer_service_locations
    where (latitude is null) <> (longitude is null)
      or latitude not between -90 and 90
      or longitude not between -180 and 180
  ) then
    raise exception 'invalid_existing_service_location_coordinates';
  end if;
end $$;

create or replace function normalize_service_location_coordinates()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if (new.latitude is null) <> (new.longitude is null) then
    raise exception 'validation_failed';
  end if;

  if new.latitude is not null then
    if new.latitude not between -90 and 90
      or new.longitude not between -180 and 180
      or coalesce(new.coordinate_accuracy_m, 0) < 0
    then
      raise exception 'validation_failed';
    end if;

    new.resolution_source := coalesce(
      nullif(btrim(new.resolution_source), ''),
      'manual'
    );
    if new.resolution_source not in ('map_pick', 'device_gps', 'url', 'manual') then
      raise exception 'validation_failed';
    end if;

    new.resolved_at := coalesce(new.resolved_at, now());
    new.resolution_status := 'resolved';
    new.resolution_error := null;
    return new;
  end if;

  if new.resolution_status is null
    or nullif(btrim(new.resolution_status), '') is null
  then
    new.resolution_source := null;
    new.resolved_at := null;
    new.coordinate_accuracy_m := null;
    new.resolution_status := null;
    new.resolution_error := null;
    return new;
  end if;

  new.resolution_source := nullif(btrim(new.resolution_source), '');
  new.resolution_status := nullif(btrim(new.resolution_status), '');
  new.resolution_error := nullif(btrim(new.resolution_error), '');

  if new.resolution_status not in ('pending', 'failed')
    or new.resolution_source is null
    or new.resolution_source not in ('map_pick', 'device_gps', 'url', 'manual')
    or new.resolved_at is not null
    or new.coordinate_accuracy_m is not null
  then
    raise exception 'validation_failed';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_normalize_service_location_coordinates
  on customer_service_locations;
create trigger trg_normalize_service_location_coordinates
  before insert or update of
    latitude,
    longitude,
    resolution_source,
    resolved_at,
    coordinate_accuracy_m,
    resolution_status,
    resolution_error
  on customer_service_locations
  for each row execute function normalize_service_location_coordinates();

update customer_service_locations
set
  resolution_source = coalesce(resolution_source, 'manual'),
  resolved_at = coalesce(resolved_at, updated_at, created_at, now()),
  resolution_status = 'resolved',
  resolution_error = null
where latitude is not null
  and longitude is not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_custloc_coordinate_pair'
      and conrelid = 'customer_service_locations'::regclass
  ) then
    alter table customer_service_locations
      add constraint ck_custloc_coordinate_pair
      check ((latitude is null) = (longitude is null));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_custloc_latitude_range'
      and conrelid = 'customer_service_locations'::regclass
  ) then
    alter table customer_service_locations
      add constraint ck_custloc_latitude_range
      check (latitude is null or latitude between -90 and 90);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_custloc_longitude_range'
      and conrelid = 'customer_service_locations'::regclass
  ) then
    alter table customer_service_locations
      add constraint ck_custloc_longitude_range
      check (longitude is null or longitude between -180 and 180);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_custloc_resolution_source'
      and conrelid = 'customer_service_locations'::regclass
  ) then
    alter table customer_service_locations
      add constraint ck_custloc_resolution_source
      check (
        resolution_source is null
        or resolution_source in ('map_pick', 'device_gps', 'url', 'manual')
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_custloc_resolution_status'
      and conrelid = 'customer_service_locations'::regclass
  ) then
    alter table customer_service_locations
      add constraint ck_custloc_resolution_status
      check (
        resolution_status is null
        or resolution_status in ('resolved', 'pending', 'failed')
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_custloc_coordinate_accuracy'
      and conrelid = 'customer_service_locations'::regclass
  ) then
    alter table customer_service_locations
      add constraint ck_custloc_coordinate_accuracy
      check (
        coordinate_accuracy_m is null
        or coordinate_accuracy_m >= 0
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ck_custloc_coordinate_resolution_state'
      and conrelid = 'customer_service_locations'::regclass
  ) then
    alter table customer_service_locations
      add constraint ck_custloc_coordinate_resolution_state
      check (
        (
          latitude is not null
          and longitude is not null
          and resolution_source is not null
          and resolved_at is not null
          and resolution_status = 'resolved'
          and resolution_error is null
        )
        or (
          latitude is null
          and longitude is null
          and (
            (
              resolution_source is null
              and resolved_at is null
              and coordinate_accuracy_m is null
              and resolution_status is null
              and resolution_error is null
            )
            or (
              resolution_source is not null
              and resolved_at is null
              and coordinate_accuracy_m is null
              and resolution_status in ('pending', 'failed')
            )
          )
        )
      );
  end if;
end $$;

create or replace function create_customer_service_location(
  p_customer_id uuid,
  p_data jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_loc_id uuid := gen_random_uuid();
  v_code text;
  v_name text;
  v_type service_location_type;
  v_is_active boolean;
  v_is_primary boolean;
  v_active_count int;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('customers.edit') then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1 from customers
    where id = p_customer_id and tenant_id = v_tenant_id
  ) then
    raise exception 'validation_failed';
  end if;

  v_name := nullif(btrim(p_data->>'name'), '');
  if v_name is null then
    raise exception 'validation_failed';
  end if;

  v_type := coalesce(
    (p_data->>'location_type')::service_location_type,
    'branch'
  );
  v_code := coalesce(
    nullif(btrim(p_data->>'code'), ''),
    generate_service_location_code(v_tenant_id, p_customer_id)
  );

  select count(*)::int into v_active_count
  from customer_service_locations
  where tenant_id = v_tenant_id
    and customer_id = p_customer_id
    and is_active;

  v_is_active := coalesce((p_data->>'is_active')::boolean, true);
  v_is_primary := case
    when not v_is_active then false
    when v_active_count = 0 then true
    else coalesce((p_data->>'is_primary')::boolean, false)
  end;

  if v_is_primary then
    update customer_service_locations
    set is_primary = false, updated_by = auth.uid()
    where tenant_id = v_tenant_id
      and customer_id = p_customer_id
      and is_active
      and is_primary;
  end if;

  insert into customer_service_locations (
    id, tenant_id, customer_id, code, name, location_type,
    is_primary, is_active,
    country, governorate, area, address_line, google_maps_url,
    latitude, longitude,
    resolution_source, resolved_at, coordinate_accuracy_m,
    resolution_status, resolution_error,
    contact_person_name, contact_person_phone, contact_person_email,
    notes, created_by
  )
  values (
    v_loc_id, v_tenant_id, p_customer_id, v_code, v_name, v_type,
    v_is_primary,
    v_is_active,
    coalesce(nullif(btrim(p_data->>'country'), ''), 'Kuwait'),
    nullif(btrim(p_data->>'governorate'), ''),
    nullif(btrim(p_data->>'area'), ''),
    nullif(btrim(p_data->>'address_line'), ''),
    nullif(btrim(p_data->>'google_maps_url'), ''),
    (p_data->>'latitude')::numeric(10, 7),
    (p_data->>'longitude')::numeric(10, 7),
    nullif(btrim(p_data->>'resolution_source'), ''),
    nullif(btrim(p_data->>'resolved_at'), '')::timestamptz,
    nullif(btrim(p_data->>'coordinate_accuracy_m'), '')::numeric(10, 2),
    nullif(btrim(p_data->>'resolution_status'), ''),
    nullif(btrim(p_data->>'resolution_error'), ''),
    nullif(btrim(p_data->>'contact_person_name'), ''),
    nullif(btrim(p_data->>'contact_person_phone'), ''),
    nullif(btrim(p_data->>'contact_person_email'), ''),
    nullif(btrim(p_data->>'notes'), ''),
    auth.uid()
  );

  return v_loc_id;
end;
$$;

create or replace function update_customer_service_location(
  p_id uuid,
  p_data jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_row customer_service_locations%rowtype;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('customers.edit') then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  select * into v_row
  from customer_service_locations
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'is_active'
    and coalesce((p_data->>'is_active')::boolean, v_row.is_active)
      is distinct from v_row.is_active
  then
    raise exception 'validation_failed';
  end if;

  update customer_service_locations
  set
    name = coalesce(nullif(btrim(p_data->>'name'), ''), name),
    location_type = coalesce(
      (p_data->>'location_type')::service_location_type,
      location_type
    ),
    country = coalesce(nullif(btrim(p_data->>'country'), ''), country),
    governorate = case when p_data ? 'governorate' then nullif(btrim(p_data->>'governorate'), '') else governorate end,
    area = case when p_data ? 'area' then nullif(btrim(p_data->>'area'), '') else area end,
    address_line = case when p_data ? 'address_line' then nullif(btrim(p_data->>'address_line'), '') else address_line end,
    google_maps_url = case when p_data ? 'google_maps_url' then nullif(btrim(p_data->>'google_maps_url'), '') else google_maps_url end,
    latitude = case when p_data ? 'latitude' then (p_data->>'latitude')::numeric(10, 7) else latitude end,
    longitude = case when p_data ? 'longitude' then (p_data->>'longitude')::numeric(10, 7) else longitude end,
    resolution_source = case when p_data ? 'resolution_source' then nullif(btrim(p_data->>'resolution_source'), '') else resolution_source end,
    resolved_at = case when p_data ? 'resolved_at' then nullif(btrim(p_data->>'resolved_at'), '')::timestamptz else resolved_at end,
    coordinate_accuracy_m = case when p_data ? 'coordinate_accuracy_m' then nullif(btrim(p_data->>'coordinate_accuracy_m'), '')::numeric(10, 2) else coordinate_accuracy_m end,
    resolution_status = case when p_data ? 'resolution_status' then nullif(btrim(p_data->>'resolution_status'), '') else resolution_status end,
    resolution_error = case when p_data ? 'resolution_error' then nullif(btrim(p_data->>'resolution_error'), '') else resolution_error end,
    contact_person_name = case when p_data ? 'contact_person_name' then nullif(btrim(p_data->>'contact_person_name'), '') else contact_person_name end,
    contact_person_phone = case when p_data ? 'contact_person_phone' then nullif(btrim(p_data->>'contact_person_phone'), '') else contact_person_phone end,
    contact_person_email = case when p_data ? 'contact_person_email' then nullif(btrim(p_data->>'contact_person_email'), '') else contact_person_email end,
    notes = case when p_data ? 'notes' then nullif(btrim(p_data->>'notes'), '') else notes end,
    updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  if coalesce((p_data->>'is_primary')::boolean, false) then
    perform set_primary_customer_service_location(p_id);
  end if;

  return p_id;
end;
$$;

comment on column customer_service_locations.latitude is
  'M5.7 operational latitude truth; google_maps_url remains a source/link only.';
comment on column customer_service_locations.longitude is
  'M5.7 operational longitude truth; google_maps_url remains a source/link only.';
comment on column customer_service_locations.resolution_source is
  'Coordinate source: map_pick, device_gps, url, or manual.';
comment on column customer_service_locations.coordinate_accuracy_m is
  'Capture accuracy in meters when supplied by the device or resolver.';
comment on function normalize_service_location_coordinates() is
  'M5.7 enforces coordinate pairs, ranges, source, status, timestamp, and accuracy.';
