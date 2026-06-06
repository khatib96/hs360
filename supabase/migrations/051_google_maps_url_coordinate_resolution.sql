-- Phase 4 M5.7: resolve Google Maps links before persistence and keep the
-- customer's primary service location synchronized with profile edits.

create or replace function insert_primary_service_location_from_customer(
  p_tenant_id uuid,
  p_customer_id uuid,
  p_data jsonb default null
)
returns uuid
language plpgsql
as $$
declare
  v_cust customers%rowtype;
  v_loc_id uuid := gen_random_uuid();
  v_code text;
  v_address_line text;
  v_area text;
  v_governorate text;
  v_country text;
  v_maps text;
  v_latitude numeric(10, 7);
  v_longitude numeric(10, 7);
  v_resolution_source text;
  v_resolved_at timestamptz;
  v_coordinate_accuracy_m numeric(10, 2);
  v_resolution_status text;
  v_resolution_error text;
  v_contact_name text;
  v_contact_phone text;
  v_contact_email text;
begin
  select * into v_cust
  from customers
  where id = p_customer_id and tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_address_line := coalesce(
    nullif(btrim(p_data->>'address_line'), ''),
    nullif(btrim(v_cust.address_line), '')
  );
  v_area := coalesce(
    nullif(btrim(p_data->>'area'), ''),
    nullif(btrim(v_cust.area), '')
  );
  v_governorate := coalesce(
    nullif(btrim(p_data->>'governorate'), ''),
    nullif(btrim(v_cust.governorate), '')
  );
  v_maps := coalesce(
    nullif(btrim(p_data->>'google_maps_url'), ''),
    nullif(btrim(v_cust.google_maps_url), '')
  );
  v_latitude := nullif(btrim(p_data->>'latitude'), '')::numeric(10, 7);
  v_longitude := nullif(btrim(p_data->>'longitude'), '')::numeric(10, 7);
  v_resolution_source := nullif(btrim(p_data->>'resolution_source'), '');
  v_resolved_at := nullif(btrim(p_data->>'resolved_at'), '')::timestamptz;
  v_coordinate_accuracy_m :=
    nullif(btrim(p_data->>'coordinate_accuracy_m'), '')::numeric(10, 2);
  v_resolution_status := nullif(btrim(p_data->>'resolution_status'), '');
  v_resolution_error := nullif(btrim(p_data->>'resolution_error'), '');

  if v_address_line is null
    and v_area is null
    and v_governorate is null
    and v_maps is null
    and v_latitude is null
    and v_longitude is null
  then
    return null;
  end if;

  if exists (
    select 1 from customer_service_locations
    where tenant_id = p_tenant_id and customer_id = p_customer_id
  ) then
    return null;
  end if;

  v_code := generate_service_location_code(p_tenant_id, p_customer_id);
  v_country := coalesce(
    nullif(btrim(p_data->>'country'), ''),
    nullif(btrim(v_cust.country), ''),
    'Kuwait'
  );
  v_contact_name := coalesce(
    nullif(btrim(p_data->>'contact_person_name'), ''),
    nullif(btrim(v_cust.contact_person_name), '')
  );
  v_contact_phone := coalesce(
    nullif(btrim(p_data->>'contact_person_phone'), ''),
    nullif(btrim(v_cust.contact_person_phone), '')
  );
  v_contact_email := coalesce(
    nullif(btrim(p_data->>'email'), ''),
    nullif(btrim(v_cust.email), '')
  );

  insert into customer_service_locations (
    id, tenant_id, customer_id, code, name, location_type,
    is_primary, is_active,
    country, governorate, area, address_line, google_maps_url,
    latitude, longitude,
    resolution_source, resolved_at, coordinate_accuracy_m,
    resolution_status, resolution_error,
    contact_person_name, contact_person_phone, contact_person_email,
    created_by
  )
  values (
    v_loc_id, p_tenant_id, p_customer_id, v_code, 'Primary location', 'branch',
    true, true,
    v_country, v_governorate, v_area, v_address_line, v_maps,
    v_latitude, v_longitude,
    v_resolution_source, v_resolved_at, v_coordinate_accuracy_m,
    v_resolution_status, v_resolution_error,
    v_contact_name, v_contact_phone, v_contact_email,
    auth.uid()
  );

  return v_loc_id;
end;
$$;

create or replace function update_customer(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_customer_type customer_type;
  v_primary_location_id uuid;
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

  select customer_type
  into v_customer_type
  from customers
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_customer_type := coalesce(
    (p_data->>'customer_type')::customer_type,
    v_customer_type
  );

  update customers
  set
    customer_type = v_customer_type,
    name_ar = coalesce(nullif(btrim(p_data->>'name_ar'), ''), name_ar),
    name_en = case when p_data ? 'name_en' then nullif(btrim(p_data->>'name_en'), '') else name_en end,
    contact_person_name = case
      when v_customer_type = 'individual' then null
      when p_data ? 'contact_person_name' then nullif(btrim(p_data->>'contact_person_name'), '')
      else contact_person_name
    end,
    contact_person_phone = case
      when v_customer_type = 'individual' then null
      when p_data ? 'contact_person_phone' then nullif(btrim(p_data->>'contact_person_phone'), '')
      else contact_person_phone
    end,
    phone_primary = coalesce(nullif(btrim(p_data->>'phone_primary'), ''), phone_primary),
    email = case when p_data ? 'email' then nullif(btrim(p_data->>'email'), '') else email end,
    address_line = case when p_data ? 'address_line' then nullif(btrim(p_data->>'address_line'), '') else address_line end,
    area = case when p_data ? 'area' then nullif(btrim(p_data->>'area'), '') else area end,
    governorate = case when p_data ? 'governorate' then nullif(btrim(p_data->>'governorate'), '') else governorate end,
    country = coalesce(nullif(btrim(p_data->>'country'), ''), country),
    google_maps_url = case when p_data ? 'google_maps_url' then nullif(btrim(p_data->>'google_maps_url'), '') else google_maps_url end,
    tax_number = case
      when v_customer_type = 'individual' then null
      when p_data ? 'tax_number' then nullif(btrim(p_data->>'tax_number'), '')
      else tax_number
    end,
    is_vip = coalesce((p_data->>'is_vip')::boolean, is_vip),
    notes = case when p_data ? 'notes' then nullif(btrim(p_data->>'notes'), '') else notes end,
    updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  select id into v_primary_location_id
  from customer_service_locations
  where tenant_id = v_tenant_id
    and customer_id = p_id
    and is_active
    and is_primary
  order by created_at, id
  limit 1
  for update;

  if v_primary_location_id is null then
    perform insert_primary_service_location_from_customer(
      v_tenant_id, p_id, p_data
    );
  else
    update customer_service_locations
    set
      country = case when p_data ? 'country'
        then coalesce(nullif(btrim(p_data->>'country'), ''), country)
        else country
      end,
      governorate = case when p_data ? 'governorate'
        then nullif(btrim(p_data->>'governorate'), '')
        else governorate
      end,
      area = case when p_data ? 'area'
        then nullif(btrim(p_data->>'area'), '')
        else area
      end,
      address_line = case when p_data ? 'address_line'
        then nullif(btrim(p_data->>'address_line'), '')
        else address_line
      end,
      google_maps_url = case when p_data ? 'google_maps_url'
        then nullif(btrim(p_data->>'google_maps_url'), '')
        else google_maps_url
      end,
      latitude = case
        when p_data ? 'latitude'
          then nullif(btrim(p_data->>'latitude'), '')::numeric(10, 7)
        when p_data ? 'google_maps_url' then null
        else latitude
      end,
      longitude = case
        when p_data ? 'longitude'
          then nullif(btrim(p_data->>'longitude'), '')::numeric(10, 7)
        when p_data ? 'google_maps_url' then null
        else longitude
      end,
      resolution_source = case
        when p_data ? 'resolution_source'
          then nullif(btrim(p_data->>'resolution_source'), '')
        when p_data ? 'google_maps_url' then null
        else resolution_source
      end,
      resolved_at = case
        when p_data ? 'resolved_at'
          then nullif(btrim(p_data->>'resolved_at'), '')::timestamptz
        when p_data ? 'google_maps_url' then null
        else resolved_at
      end,
      coordinate_accuracy_m = case
        when p_data ? 'coordinate_accuracy_m'
          then nullif(btrim(p_data->>'coordinate_accuracy_m'), '')::numeric(10, 2)
        when p_data ? 'google_maps_url' then null
        else coordinate_accuracy_m
      end,
      resolution_status = case
        when p_data ? 'resolution_status'
          then nullif(btrim(p_data->>'resolution_status'), '')
        when p_data ? 'google_maps_url' then null
        else resolution_status
      end,
      resolution_error = case
        when p_data ? 'resolution_error'
          then nullif(btrim(p_data->>'resolution_error'), '')
        when p_data ? 'google_maps_url' then null
        else resolution_error
      end,
      updated_by = auth.uid()
    where id = v_primary_location_id
      and tenant_id = v_tenant_id;
  end if;

  return p_id;
end;
$$;

comment on function insert_primary_service_location_from_customer(uuid, uuid, jsonb) is
  'M5.7: Creates the primary service location with Google Maps URL coordinates and resolution metadata.';
comment on function update_customer(uuid, jsonb) is
  'M5.7: Updates customer profile and synchronizes the active primary service location, including resolved Google Maps coordinates.';
