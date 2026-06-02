-- Phase 4 M5.6: customer service locations, composite FKs, location RPCs.

-- ---------------------------------------------------------------------------
-- customers: composite unique for child FKs
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ux_customers_tenant_id_id'
      and conrelid = 'public.customers'::regclass
  ) then
    alter table customers
      add constraint ux_customers_tenant_id_id unique (tenant_id, id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- service_location_type enum
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'service_location_type') then
    create type service_location_type as enum (
      'branch', 'office', 'warehouse', 'home', 'installation_site', 'other'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- customer_service_locations
-- ---------------------------------------------------------------------------
create table if not exists customer_service_locations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  customer_id uuid not null,

  code text not null,
  name text not null,
  location_type service_location_type not null default 'branch',
  is_primary boolean not null default false,
  is_active boolean not null default true,

  country text default 'Kuwait',
  governorate text,
  area text,
  address_line text,
  google_maps_url text,
  latitude numeric(10, 7),
  longitude numeric(10, 7),

  contact_person_name text,
  contact_person_phone text,
  contact_person_email text,
  notes text,

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz,
  updated_by uuid references auth.users (id),

  constraint ux_custloc_tenant_customer_code unique (tenant_id, customer_id, code),
  constraint ux_custloc_tenant_customer_id unique (tenant_id, customer_id, id),
  constraint fk_custloc_customer foreign key (tenant_id, customer_id)
    references customers (tenant_id, id) on delete cascade
);

create index if not exists idx_custloc_tenant
  on customer_service_locations (tenant_id);
create index if not exists idx_custloc_customer
  on customer_service_locations (tenant_id, customer_id);
create index if not exists idx_custloc_active
  on customer_service_locations (tenant_id, is_active);

create unique index if not exists idx_custloc_one_primary
  on customer_service_locations (tenant_id, customer_id)
  where is_primary = true and is_active = true;

-- ---------------------------------------------------------------------------
-- Internal: location code per customer
-- ---------------------------------------------------------------------------
create or replace function generate_service_location_code(
  p_tenant_id uuid,
  p_customer_id uuid
)
returns text
language plpgsql
as $$
declare
  v_next int;
begin
  perform pg_advisory_xact_lock(
    hashtext(p_tenant_id::text || ':loc:' || p_customer_id::text)
  );

  select coalesce(max((substring(code from 5))::int), 0) + 1
  into v_next
  from customer_service_locations
  where tenant_id = p_tenant_id
    and customer_id = p_customer_id
    and code ~ '^LOC-[0-9]+$';

  return 'LOC-' || lpad(v_next::text, 4, '0');
end;
$$;

revoke all on function generate_service_location_code(uuid, uuid) from public;
revoke all on function generate_service_location_code(uuid, uuid) from authenticated;

-- ---------------------------------------------------------------------------
-- Internal: primary location from customer payload or row
-- ---------------------------------------------------------------------------
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

  if v_address_line is null
    and v_area is null
    and v_governorate is null
    and v_maps is null
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
    contact_person_name, contact_person_phone, contact_person_email,
    created_by
  )
  values (
    v_loc_id, p_tenant_id, p_customer_id, v_code, 'Primary location', 'branch',
    true, true,
    v_country, v_governorate, v_area, v_address_line, v_maps,
    v_contact_name, v_contact_phone, v_contact_email,
    auth.uid()
  );

  return v_loc_id;
end;
$$;

revoke all on function insert_primary_service_location_from_customer(uuid, uuid, jsonb) from public;
revoke all on function insert_primary_service_location_from_customer(uuid, uuid, jsonb) from authenticated;

-- ---------------------------------------------------------------------------
-- Backfill primary locations from existing customer addresses
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select c.tenant_id, c.id
    from customers c
    where (
      nullif(btrim(c.address_line), '') is not null
      or nullif(btrim(c.area), '') is not null
      or nullif(btrim(c.governorate), '') is not null
      or nullif(btrim(c.google_maps_url), '') is not null
    )
    and not exists (
      select 1 from customer_service_locations l
      where l.tenant_id = c.tenant_id and l.customer_id = c.id
    )
  loop
    perform insert_primary_service_location_from_customer(
      r.tenant_id, r.id, null::jsonb
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Child columns (uuid only — no simple FK)
-- ---------------------------------------------------------------------------
alter table contracts
  add column if not exists service_location_id uuid;

alter table visits
  add column if not exists service_location_id uuid;

alter table calendar_events
  add column if not exists service_location_id uuid;

alter table product_units
  add column if not exists current_service_location_id uuid;

alter table contracts
  add column if not exists location_name text,
  add column if not exists location_country text,
  add column if not exists location_governorate text,
  add column if not exists location_area text,
  add column if not exists location_google_maps_url text;

-- ---------------------------------------------------------------------------
-- Composite FKs + CHECKs (idempotent)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'fk_contracts_service_location'
  ) then
    alter table contracts
      add constraint fk_contracts_service_location
      foreign key (tenant_id, customer_id, service_location_id)
      references customer_service_locations (tenant_id, customer_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'fk_visits_service_location'
  ) then
    alter table visits
      add constraint fk_visits_service_location
      foreign key (tenant_id, customer_id, service_location_id)
      references customer_service_locations (tenant_id, customer_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'fk_calendar_events_service_location'
  ) then
    alter table calendar_events
      add constraint fk_calendar_events_service_location
      foreign key (tenant_id, customer_id, service_location_id)
      references customer_service_locations (tenant_id, customer_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'fk_product_units_service_location'
  ) then
    alter table product_units
      add constraint fk_product_units_service_location
      foreign key (tenant_id, current_customer_id, current_service_location_id)
      references customer_service_locations (tenant_id, customer_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_contracts_service_location_customer'
  ) then
    alter table contracts
      add constraint chk_contracts_service_location_customer
      check (service_location_id is null or customer_id is not null);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_visits_service_location_customer'
  ) then
    alter table visits
      add constraint chk_visits_service_location_customer
      check (service_location_id is null or customer_id is not null);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_calendar_events_service_location_customer'
  ) then
    alter table calendar_events
      add constraint chk_calendar_events_service_location_customer
      check (service_location_id is null or customer_id is not null);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_product_units_service_location_customer'
  ) then
    alter table product_units
      add constraint chk_product_units_service_location_customer
      check (current_service_location_id is null or current_customer_id is not null);
  end if;
end $$;

create index if not exists idx_contracts_service_location
  on contracts (service_location_id);
create index if not exists idx_visits_service_location
  on visits (service_location_id);
create index if not exists idx_calevents_service_location
  on calendar_events (service_location_id);
create index if not exists idx_units_current_service_location
  on product_units (current_service_location_id);

-- ---------------------------------------------------------------------------
-- Immutable columns on service locations
-- ---------------------------------------------------------------------------
create or replace function enforce_customer_service_location_immutable_columns()
returns trigger
language plpgsql
as $$
begin
  if new.tenant_id is distinct from old.tenant_id
    or new.customer_id is distinct from old.customer_id
    or new.code is distinct from old.code
  then
    raise exception 'immutable_column';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_customer_service_location_immutable
  on customer_service_locations;
create trigger trg_enforce_customer_service_location_immutable
  before update on customer_service_locations
  for each row execute function enforce_customer_service_location_immutable_columns();

drop trigger if exists trg_touch_customer_service_locations
  on customer_service_locations;
create trigger trg_touch_customer_service_locations
  before update on customer_service_locations
  for each row execute function touch_updated_at();

-- ---------------------------------------------------------------------------
-- set_primary_customer_service_location (before update uses it)
-- ---------------------------------------------------------------------------
create or replace function set_primary_customer_service_location(p_id uuid)
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

  select * into v_row
  from customer_service_locations
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found or not v_row.is_active then
    raise exception 'validation_failed';
  end if;

  update customer_service_locations
  set is_primary = false, updated_by = auth.uid()
  where tenant_id = v_tenant_id
    and customer_id = v_row.customer_id
    and is_active
    and id <> p_id;

  update customer_service_locations
  set is_primary = true, updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_customer_service_locations
-- ---------------------------------------------------------------------------
create or replace function list_customer_service_locations(p_customer_id uuid)
returns setof customer_service_locations
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('customers.view') then
    raise exception 'permission_denied';
  end if;

  if not exists (
    select 1 from customers
    where id = p_customer_id and tenant_id = v_tenant_id
  ) then
    raise exception 'validation_failed';
  end if;

  return query
  select l.*
  from customer_service_locations l
  where l.tenant_id = v_tenant_id
    and l.customer_id = p_customer_id
  order by l.is_primary desc, l.is_active desc, l.code;
end;
$$;

-- ---------------------------------------------------------------------------
-- create_customer_service_location
-- ---------------------------------------------------------------------------
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
    nullif(btrim(p_data->>'contact_person_name'), ''),
    nullif(btrim(p_data->>'contact_person_phone'), ''),
    nullif(btrim(p_data->>'contact_person_email'), ''),
    nullif(btrim(p_data->>'notes'), ''),
    auth.uid()
  );

  return v_loc_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- update_customer_service_location
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- deactivate_customer_service_location
-- ---------------------------------------------------------------------------
create or replace function deactivate_customer_service_location(p_id uuid)
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

  select * into v_row
  from customer_service_locations
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_row.is_primary and v_row.is_active then
    if exists (
      select 1 from customer_service_locations
      where tenant_id = v_tenant_id
        and customer_id = v_row.customer_id
        and is_active
        and id <> p_id
    ) then
      raise exception 'primary_required';
    end if;
  end if;

  if exists (
    select 1 from contracts c
    where c.service_location_id = p_id
      and c.tenant_id = v_tenant_id
      and c.status in ('draft', 'active', 'suspended')
  ) then
    raise exception 'location_in_use';
  end if;

  if exists (
    select 1 from visits v
    where v.service_location_id = p_id
      and v.tenant_id = v_tenant_id
      and v.status in ('scheduled', 'in_progress')
  ) then
    raise exception 'location_in_use';
  end if;

  if exists (
    select 1 from calendar_events ce
    where ce.service_location_id = p_id
      and ce.tenant_id = v_tenant_id
      and ce.status = 'pending'
  ) then
    raise exception 'location_in_use';
  end if;

  if exists (
    select 1 from product_units u
    where u.current_service_location_id = p_id
      and u.tenant_id = v_tenant_id
      and u.status in ('rented', 'trial', 'maintenance')
  ) then
    raise exception 'location_in_use';
  end if;

  update customer_service_locations
  set is_active = false, is_primary = false, updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- create_customer: optional primary location when address present (M5.6)
-- ---------------------------------------------------------------------------
create or replace function create_customer(p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_parent_id uuid;
  v_parent_code text;
  v_customer_id uuid := gen_random_uuid();
  v_account_id uuid;
  v_sub_code text;
  v_cust_code text;
  v_name_ar text;
  v_phone_primary text;
  v_customer_type customer_type;
  v_create_account boolean;
  v_tax_number text;
  v_contact_person_name text;
  v_contact_person_phone text;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('customers.create') then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_name_ar := nullif(btrim(p_data->>'name_ar'), '');
  v_phone_primary := nullif(btrim(p_data->>'phone_primary'), '');
  if v_name_ar is null or v_phone_primary is null then
    raise exception 'validation_failed';
  end if;

  v_customer_type := coalesce(
    (p_data->>'customer_type')::customer_type,
    'individual'
  );
  v_create_account := coalesce((p_data->>'create_account')::boolean, false);

  if v_customer_type = 'individual' then
    v_tax_number := null;
    v_contact_person_name := null;
    v_contact_person_phone := null;
  else
    v_tax_number := nullif(btrim(p_data->>'tax_number'), '');
    v_contact_person_name := nullif(btrim(p_data->>'contact_person_name'), '');
    v_contact_person_phone := nullif(btrim(p_data->>'contact_person_phone'), '');
  end if;

  v_account_id := null;
  if v_create_account then
    v_account_id := gen_random_uuid();
    v_parent_id := get_entity_parent_account('ar');
    select code into v_parent_code
    from chart_of_accounts
    where id = v_parent_id;

    v_sub_code := generate_subaccount_code(v_parent_id, v_parent_code);

    insert into chart_of_accounts (
      id, tenant_id, code, name_ar, name_en, type, parent_id,
      is_subaccount, related_entity_table, related_entity_id,
      is_active, is_system
    )
    values (
      v_account_id, v_tenant_id, v_sub_code,
      v_name_ar, coalesce(nullif(btrim(p_data->>'name_en'), ''), v_name_ar),
      'asset', v_parent_id,
      true, 'customers', v_customer_id,
      true, false
    );
  end if;

  v_cust_code := generate_entity_code('CUST');

  insert into customers (
    id, tenant_id, code, customer_type,
    name_ar, name_en,
    contact_person_name, contact_person_phone,
    phone_primary, email,
    address_line, area, governorate, country, google_maps_url,
    tax_number, account_id,
    is_active, is_vip, notes, acquired_by, acquired_at, created_by
  )
  values (
    v_customer_id, v_tenant_id, v_cust_code, v_customer_type,
    v_name_ar, nullif(btrim(p_data->>'name_en'), ''),
    v_contact_person_name, v_contact_person_phone,
    v_phone_primary,
    nullif(btrim(p_data->>'email'), ''),
    nullif(btrim(p_data->>'address_line'), ''),
    nullif(btrim(p_data->>'area'), ''),
    nullif(btrim(p_data->>'governorate'), ''),
    coalesce(nullif(btrim(p_data->>'country'), ''), 'Kuwait'),
    nullif(btrim(p_data->>'google_maps_url'), ''),
    v_tax_number, v_account_id,
    true,
    coalesce((p_data->>'is_vip')::boolean, false),
    nullif(btrim(p_data->>'notes'), ''),
    (p_data->>'acquired_by')::uuid,
    (p_data->>'acquired_at')::date,
    auth.uid()
  );

  perform insert_primary_service_location_from_customer(
    v_tenant_id, v_customer_id, p_data
  );

  return v_customer_id;
end;
$$;

comment on function create_customer(jsonb) is
  'M5.6: Creates customer; optional A/R when create_account=true; primary service location when address fields present.';

-- ---------------------------------------------------------------------------
-- RLS: select only
-- ---------------------------------------------------------------------------
alter table customer_service_locations enable row level security;

drop policy if exists customer_service_locations_select on customer_service_locations;
create policy customer_service_locations_select on customer_service_locations
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('customers.view')
  );

-- ---------------------------------------------------------------------------
-- Audit triggers
-- ---------------------------------------------------------------------------
drop trigger if exists trg_audit_customer_service_locations_insert
  on customer_service_locations;
create trigger trg_audit_customer_service_locations_insert
  after insert on customer_service_locations
  for each row execute function audit_log_row();

drop trigger if exists trg_audit_customer_service_locations_update
  on customer_service_locations;
create trigger trg_audit_customer_service_locations_update
  after update on customer_service_locations
  for each row execute function audit_log_row();

drop trigger if exists trg_audit_customer_service_locations_delete
  on customer_service_locations;
create trigger trg_audit_customer_service_locations_delete
  after delete on customer_service_locations
  for each row execute function audit_log_row();

-- ---------------------------------------------------------------------------
-- Grants: public RPCs only
-- ---------------------------------------------------------------------------
revoke all on function list_customer_service_locations(uuid) from public;
revoke all on function create_customer_service_location(uuid, jsonb) from public;
revoke all on function update_customer_service_location(uuid, jsonb) from public;
revoke all on function deactivate_customer_service_location(uuid) from public;
revoke all on function set_primary_customer_service_location(uuid) from public;

grant execute on function list_customer_service_locations(uuid) to authenticated;
grant execute on function create_customer_service_location(uuid, jsonb) to authenticated;
grant execute on function update_customer_service_location(uuid, jsonb) to authenticated;
grant execute on function deactivate_customer_service_location(uuid) to authenticated;
grant execute on function set_primary_customer_service_location(uuid) to authenticated;
