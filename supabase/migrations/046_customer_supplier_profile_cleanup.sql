-- Phase 4 M5.5: customer/supplier profile cleanup.
-- Adds structured location fields, optional accounting account linkage,
-- removes low-value customer columns, and tightens account_id immutability.

-- ---------------------------------------------------------------------------
-- Schema: customers
-- ---------------------------------------------------------------------------
alter table customers
  add column if not exists governorate text,
  add column if not exists google_maps_url text,
  add column if not exists tax_number text;

update customers
set governorate = city
where governorate is null
  and city is not null;

alter table customers
  drop column if exists phone_secondary,
  drop column if exists whatsapp,
  drop column if exists contact_person_title,
  drop column if exists gps_lat,
  drop column if exists gps_lng,
  drop column if exists payment_terms_days,
  drop column if exists credit_limit,
  drop column if exists city;

alter table customers
  alter column account_id drop not null;

-- ---------------------------------------------------------------------------
-- Schema: suppliers
-- ---------------------------------------------------------------------------
alter table suppliers
  add column if not exists country text default 'Kuwait',
  add column if not exists governorate text,
  add column if not exists area text,
  add column if not exists address_line text,
  add column if not exists google_maps_url text,
  add column if not exists tax_number text,
  add column if not exists notes text;

update suppliers
set address_line = address
where address_line is null
  and address is not null;

alter table suppliers
  drop column if exists address;

alter table suppliers
  alter column account_id drop not null;

-- ---------------------------------------------------------------------------
-- create_customer: optional A/R subaccount (create_account, default false).
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

  return v_customer_id;
end;
$$;

comment on function create_customer(jsonb) is
  'M5.5: Creates a customer. Optional A/R subaccount when create_account=true (default false). Company-only fields cleared for individuals.';

-- ---------------------------------------------------------------------------
-- update_customer
-- ---------------------------------------------------------------------------
create or replace function update_customer(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_customer_type customer_type;
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

  return p_id;
end;
$$;

comment on function update_customer(uuid, jsonb) is
  'M5.5: Updates mutable customer profile fields. Clears company-only fields when type is individual.';

-- ---------------------------------------------------------------------------
-- ensure_customer_account: link A/R when account_id is null.
-- ---------------------------------------------------------------------------
create or replace function ensure_customer_account(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_parent_id uuid;
  v_parent_code text;
  v_name_ar text;
  v_name_en text;
  v_account_id uuid;
  v_sub_code text;
  v_existing uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('customers.edit') then
    raise exception 'permission_denied';
  end if;

  select account_id, name_ar, name_en
  into v_existing, v_name_ar, v_name_en
  from customers
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_existing is not null then
    raise exception 'account_already_linked';
  end if;

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
    v_name_ar, coalesce(nullif(btrim(v_name_en), ''), v_name_ar),
    'asset', v_parent_id,
    true, 'customers', p_id,
    true, false
  );

  update customers
  set account_id = v_account_id, updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function ensure_customer_account(uuid) is
  'M5.5: Creates and links an A/R subaccount when customer.account_id is null. Raises account_already_linked otherwise.';

-- ---------------------------------------------------------------------------
-- create_supplier
-- ---------------------------------------------------------------------------
create or replace function create_supplier(p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_parent_id uuid;
  v_parent_code text;
  v_supplier_id uuid := gen_random_uuid();
  v_account_id uuid;
  v_sub_code text;
  v_sup_code text;
  v_name_ar text;
  v_create_account boolean;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('suppliers.create') then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_name_ar := nullif(btrim(p_data->>'name_ar'), '');
  if v_name_ar is null then
    raise exception 'validation_failed';
  end if;

  v_create_account := coalesce((p_data->>'create_account')::boolean, false);
  v_account_id := null;

  if v_create_account then
    v_account_id := gen_random_uuid();
    v_parent_id := get_entity_parent_account('ap');
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
      'liability', v_parent_id,
      true, 'suppliers', v_supplier_id,
      true, false
    );
  end if;

  v_sup_code := generate_entity_code('SUP');

  insert into suppliers (
    id, tenant_id, code, name_ar, name_en, phone, email,
    country, governorate, area, address_line, google_maps_url,
    tax_number, notes, account_id, is_active
  )
  values (
    v_supplier_id, v_tenant_id, v_sup_code,
    v_name_ar, nullif(btrim(p_data->>'name_en'), ''),
    nullif(btrim(p_data->>'phone'), ''),
    nullif(btrim(p_data->>'email'), ''),
    coalesce(nullif(btrim(p_data->>'country'), ''), 'Kuwait'),
    nullif(btrim(p_data->>'governorate'), ''),
    nullif(btrim(p_data->>'area'), ''),
    nullif(btrim(p_data->>'address_line'), ''),
    nullif(btrim(p_data->>'google_maps_url'), ''),
    nullif(btrim(p_data->>'tax_number'), ''),
    nullif(btrim(p_data->>'notes'), ''),
    v_account_id, true
  );

  return v_supplier_id;
end;
$$;

comment on function create_supplier(jsonb) is
  'M5.5: Creates a supplier. Optional A/P subaccount when create_account=true (default false).';

-- ---------------------------------------------------------------------------
-- update_supplier
-- ---------------------------------------------------------------------------
create or replace function update_supplier(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('suppliers.edit') then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1 from suppliers
    where id = p_id and tenant_id = v_tenant_id
    for update
  ) then
    raise exception 'validation_failed';
  end if;

  update suppliers
  set
    name_ar = coalesce(nullif(btrim(p_data->>'name_ar'), ''), name_ar),
    name_en = case when p_data ? 'name_en' then nullif(btrim(p_data->>'name_en'), '') else name_en end,
    phone = case when p_data ? 'phone' then nullif(btrim(p_data->>'phone'), '') else phone end,
    email = case when p_data ? 'email' then nullif(btrim(p_data->>'email'), '') else email end,
    country = coalesce(nullif(btrim(p_data->>'country'), ''), country),
    governorate = case when p_data ? 'governorate' then nullif(btrim(p_data->>'governorate'), '') else governorate end,
    area = case when p_data ? 'area' then nullif(btrim(p_data->>'area'), '') else area end,
    address_line = case when p_data ? 'address_line' then nullif(btrim(p_data->>'address_line'), '') else address_line end,
    google_maps_url = case when p_data ? 'google_maps_url' then nullif(btrim(p_data->>'google_maps_url'), '') else google_maps_url end,
    tax_number = case when p_data ? 'tax_number' then nullif(btrim(p_data->>'tax_number'), '') else tax_number end,
    notes = case when p_data ? 'notes' then nullif(btrim(p_data->>'notes'), '') else notes end
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function update_supplier(uuid, jsonb) is
  'M5.5: Updates mutable supplier profile fields.';

-- ---------------------------------------------------------------------------
-- ensure_supplier_account
-- ---------------------------------------------------------------------------
create or replace function ensure_supplier_account(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_parent_id uuid;
  v_parent_code text;
  v_name_ar text;
  v_name_en text;
  v_account_id uuid;
  v_sub_code text;
  v_existing uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('suppliers.edit') then
    raise exception 'permission_denied';
  end if;

  select account_id, name_ar, name_en
  into v_existing, v_name_ar, v_name_en
  from suppliers
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_existing is not null then
    raise exception 'account_already_linked';
  end if;

  v_account_id := gen_random_uuid();
  v_parent_id := get_entity_parent_account('ap');
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
    v_name_ar, coalesce(nullif(btrim(v_name_en), ''), v_name_ar),
    'liability', v_parent_id,
    true, 'suppliers', p_id,
    true, false
  );

  update suppliers
  set account_id = v_account_id
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function ensure_supplier_account(uuid) is
  'M5.5: Creates and links an A/P subaccount when supplier.account_id is null.';

-- ---------------------------------------------------------------------------
-- Ledger RPCs: zero-safe when account_id is null.
-- ---------------------------------------------------------------------------
create or replace function get_customer_balance_summary(p_customer_id uuid)
returns table (
  debit_total numeric(15, 3),
  credit_total numeric(15, 3),
  balance numeric(15, 3)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_account_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('customers.view_ledger') then
    raise exception 'permission_denied';
  end if;

  select account_id
  into v_account_id
  from customers
  where id = p_customer_id and tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_account_id is null then
    return query
    select
      0::numeric(15, 3),
      0::numeric(15, 3),
      0::numeric(15, 3);
    return;
  end if;

  return query
  select
    coalesce(sum(jl.debit), 0)::numeric(15, 3),
    coalesce(sum(jl.credit), 0)::numeric(15, 3),
    coalesce(sum(jl.debit - jl.credit), 0)::numeric(15, 3)
  from journal_lines jl
  join journal_entries je on je.id = jl.journal_entry_id
  where jl.tenant_id = v_tenant_id
    and jl.account_id = v_account_id
    and je.is_posted = true;
end;
$$;

create or replace function get_customer_statement(
  p_customer_id uuid,
  p_from date default null,
  p_to date default null
)
returns table (
  entry_date date,
  entry_number text,
  source journal_source,
  description text,
  debit numeric(15, 3),
  credit numeric(15, 3),
  running_balance numeric(15, 3)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_account_id uuid;
  v_opening numeric(15, 3);
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('customers.view_ledger') then
    raise exception 'permission_denied';
  end if;

  select account_id
  into v_account_id
  from customers
  where id = p_customer_id and tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_account_id is null then
    return;
  end if;

  select coalesce(sum(jl.debit - jl.credit), 0)::numeric(15, 3)
  into v_opening
  from journal_lines jl
  join journal_entries je on je.id = jl.journal_entry_id
  where jl.tenant_id = v_tenant_id
    and jl.account_id = v_account_id
    and je.is_posted = true
    and p_from is not null
    and je.date < p_from;

  return query
  with in_range as (
    select
      je.date as entry_date,
      je.entry_number,
      je.source,
      jl.description,
      jl.debit,
      jl.credit
    from journal_lines jl
    join journal_entries je on je.id = jl.journal_entry_id
    where jl.tenant_id = v_tenant_id
      and jl.account_id = v_account_id
      and je.is_posted = true
      and (p_from is null or je.date >= p_from)
      and (p_to is null or je.date <= p_to)
  )
  select
    r.entry_date,
    r.entry_number,
    r.source,
    r.description,
    r.debit::numeric(15, 3),
    r.credit::numeric(15, 3),
    (v_opening + sum(r.debit - r.credit) over (
      order by r.entry_date, r.entry_number
      rows between unbounded preceding and current row
    ))::numeric(15, 3)
  from in_range r
  order by r.entry_date, r.entry_number;
end;
$$;

-- ---------------------------------------------------------------------------
-- Immutable triggers: allow null -> linked account only when valid.
-- ---------------------------------------------------------------------------
create or replace function enforce_customer_immutable_columns()
returns trigger
language plpgsql
as $$
declare
  v_acct record;
  v_ar_parent uuid;
begin
  if new.tenant_id is distinct from old.tenant_id
    or new.code is distinct from old.code
  then
    raise exception 'immutable_column';
  end if;

  if new.account_id is distinct from old.account_id then
    if old.account_id is not null then
      raise exception 'immutable_column';
    end if;
    if new.account_id is null then
      return new;
    end if;

    select * into v_acct
    from chart_of_accounts
    where id = new.account_id;

    if v_acct is null then
      raise exception 'validation_failed';
    end if;

    if v_acct.tenant_id is distinct from new.tenant_id then
      raise exception 'immutable_column';
    end if;

    if v_acct.related_entity_table is distinct from 'customers'
       or v_acct.related_entity_id is distinct from new.id
    then
      raise exception 'immutable_column';
    end if;

    select id into v_ar_parent
    from chart_of_accounts
    where tenant_id = new.tenant_id and code = '1201';

    if v_acct.type <> 'asset'
       or v_acct.parent_id is distinct from v_ar_parent
    then
      raise exception 'immutable_column';
    end if;
  end if;

  return new;
end;
$$;

create or replace function enforce_supplier_immutable_columns()
returns trigger
language plpgsql
as $$
declare
  v_acct record;
  v_ap_parent uuid;
begin
  if new.tenant_id is distinct from old.tenant_id
    or new.code is distinct from old.code
  then
    raise exception 'immutable_column';
  end if;

  if new.account_id is distinct from old.account_id then
    if old.account_id is not null then
      raise exception 'immutable_column';
    end if;
    if new.account_id is null then
      return new;
    end if;

    select * into v_acct
    from chart_of_accounts
    where id = new.account_id;

    if v_acct is null then
      raise exception 'validation_failed';
    end if;

    if v_acct.tenant_id is distinct from new.tenant_id then
      raise exception 'immutable_column';
    end if;

    if v_acct.related_entity_table is distinct from 'suppliers'
       or v_acct.related_entity_id is distinct from new.id
    then
      raise exception 'immutable_column';
    end if;

    select id into v_ap_parent
    from chart_of_accounts
    where tenant_id = new.tenant_id and code = '2101';

    if v_acct.type <> 'liability'
       or v_acct.parent_id is distinct from v_ap_parent
    then
      raise exception 'immutable_column';
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
revoke all on function ensure_customer_account(uuid) from public;
revoke all on function ensure_supplier_account(uuid) from public;

grant execute on function ensure_customer_account(uuid) to authenticated;
grant execute on function ensure_supplier_account(uuid) to authenticated;
