-- Phase 4 M2: customers, suppliers, and chart-of-accounts RPCs.
-- Writes for these three tables are RPC-only. All direct insert/update/delete
-- RLS policies are dropped; only SELECT remains. Guard triggers stay as
-- defense-in-depth so a future re-added policy cannot bypass protection.
--
-- Accounting rules (DB-owned):
--   * Customer creation generates CUST-NNNN and an A/R subaccount under 1201.
--   * Supplier creation generates SUP-NNNN and an A/P subaccount under 2101.
--   * Subaccount code is <parent_code>.NNNN per tenant.
--   * tenant_id / account_id / generated codes are immutable after creation.
--   * is_active is changed only by deactivate_* RPCs (gated by *.delete).
--   * Customer ledger is read through view_ledger RPCs, never raw journal.view.

-- ---------------------------------------------------------------------------
-- Helper: resolve the tenant A/R (1201) or A/P (2101) parent account.
-- ---------------------------------------------------------------------------
create or replace function get_entity_parent_account(p_kind text)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_code text;
  v_account_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_kind = 'ar' then
    v_code := '1201';
  elsif p_kind = 'ap' then
    v_code := '2101';
  else
    raise exception 'validation_failed';
  end if;

  select id
  into v_account_id
  from chart_of_accounts
  where tenant_id = v_tenant_id
    and code = v_code;

  if v_account_id is null then
    if p_kind = 'ar' then
      raise exception 'ar_parent_missing';
    else
      raise exception 'ap_parent_missing';
    end if;
  end if;

  return v_account_id;
end;
$$;

comment on function get_entity_parent_account(text) is
  'Resolves the current tenant A/R (1201) or A/P (2101) parent account id. Raises ar_parent_missing / ap_parent_missing when absent.';

-- ---------------------------------------------------------------------------
-- Helper: next entity code (CUST-NNNN / SUP-NNNN) per tenant, race-safe.
-- ---------------------------------------------------------------------------
create or replace function generate_entity_code(p_prefix text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_next int;
  v_pattern text;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_prefix not in ('CUST', 'SUP') then
    raise exception 'validation_failed';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(v_tenant_id::text || ':entity_code:' || p_prefix)
  );

  v_pattern := '^' || p_prefix || '-[0-9]+$';

  if p_prefix = 'CUST' then
    select coalesce(max((split_part(code, '-', 2))::int), 0) + 1
    into v_next
    from customers
    where tenant_id = v_tenant_id
      and code ~ v_pattern;
  else
    select coalesce(max((split_part(code, '-', 2))::int), 0) + 1
    into v_next
    from suppliers
    where tenant_id = v_tenant_id
      and code ~ v_pattern;
  end if;

  return p_prefix || '-' || lpad(v_next::text, 4, '0');
end;
$$;

comment on function generate_entity_code(text) is
  'Next CUST-NNNN / SUP-NNNN per tenant. Advisory-locked; regex-filters matching codes before cast.';

-- ---------------------------------------------------------------------------
-- Helper: next linked subaccount code (<parent_code>.NNNN) per tenant.
-- ---------------------------------------------------------------------------
create or replace function generate_subaccount_code(
  p_parent_id uuid,
  p_parent_code text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_next int;
  v_pattern text;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(v_tenant_id::text || ':subaccount:' || p_parent_id::text)
  );

  -- Escape the dot so the parent code is matched literally.
  v_pattern := '^' || replace(p_parent_code, '.', '\.') || '\.[0-9]+$';

  select coalesce(max((split_part(code, '.', 2))::int), 0) + 1
  into v_next
  from chart_of_accounts
  where tenant_id = v_tenant_id
    and parent_id = p_parent_id
    and code ~ v_pattern;

  return p_parent_code || '.' || lpad(v_next::text, 4, '0');
end;
$$;

comment on function generate_subaccount_code(uuid, text) is
  'Next <parent_code>.NNNN per tenant for entity subaccounts. Advisory-locked; regex-filters children before cast.';

-- ---------------------------------------------------------------------------
-- create_customer: atomic A/R subaccount + customer.
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
  v_account_id uuid := gen_random_uuid();
  v_sub_code text;
  v_cust_code text;
  v_name_ar text;
  v_phone_primary text;
  v_credit_limit numeric(15, 3);
  v_payment_terms int;
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

  v_credit_limit := coalesce((p_data->>'credit_limit')::numeric(15, 3), 0);
  v_payment_terms := coalesce((p_data->>'payment_terms_days')::int, 0);
  if v_credit_limit < 0 or v_payment_terms < 0 then
    raise exception 'validation_failed';
  end if;

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

  v_cust_code := generate_entity_code('CUST');

  insert into customers (
    id, tenant_id, code, customer_type,
    name_ar, name_en,
    contact_person_name, contact_person_title, contact_person_phone,
    phone_primary, phone_secondary, whatsapp, email,
    address_line, area, city, country, gps_lat, gps_lng,
    payment_terms_days, credit_limit, account_id,
    is_active, is_vip, notes, acquired_by, acquired_at, created_by
  )
  values (
    v_customer_id, v_tenant_id, v_cust_code,
    coalesce((p_data->>'customer_type')::customer_type, 'individual'),
    v_name_ar, nullif(btrim(p_data->>'name_en'), ''),
    nullif(btrim(p_data->>'contact_person_name'), ''),
    nullif(btrim(p_data->>'contact_person_title'), ''),
    nullif(btrim(p_data->>'contact_person_phone'), ''),
    v_phone_primary,
    nullif(btrim(p_data->>'phone_secondary'), ''),
    nullif(btrim(p_data->>'whatsapp'), ''),
    nullif(btrim(p_data->>'email'), ''),
    nullif(btrim(p_data->>'address_line'), ''),
    nullif(btrim(p_data->>'area'), ''),
    nullif(btrim(p_data->>'city'), ''),
    coalesce(nullif(btrim(p_data->>'country'), ''), 'Kuwait'),
    (p_data->>'gps_lat')::numeric(10, 7),
    (p_data->>'gps_lng')::numeric(10, 7),
    v_payment_terms, v_credit_limit, v_account_id,
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
  'M2: Creates an A/R subaccount under 1201 and the customer atomically. Server generates code and account_id; client tenant_id/account_id/code are ignored.';

-- ---------------------------------------------------------------------------
-- update_customer: mutable profile fields only (never is_active/code/account).
-- ---------------------------------------------------------------------------
create or replace function update_customer(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_credit_limit numeric(15, 3);
  v_payment_terms int;
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
    where id = p_id and tenant_id = v_tenant_id
    for update
  ) then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'credit_limit' then
    v_credit_limit := (p_data->>'credit_limit')::numeric(15, 3);
    if v_credit_limit is null or v_credit_limit < 0 then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_data ? 'payment_terms_days' then
    v_payment_terms := (p_data->>'payment_terms_days')::int;
    if v_payment_terms is null or v_payment_terms < 0 then
      raise exception 'validation_failed';
    end if;
  end if;

  update customers
  set
    customer_type = coalesce((p_data->>'customer_type')::customer_type, customer_type),
    name_ar = coalesce(nullif(btrim(p_data->>'name_ar'), ''), name_ar),
    name_en = case when p_data ? 'name_en' then nullif(btrim(p_data->>'name_en'), '') else name_en end,
    contact_person_name = case when p_data ? 'contact_person_name' then nullif(btrim(p_data->>'contact_person_name'), '') else contact_person_name end,
    contact_person_title = case when p_data ? 'contact_person_title' then nullif(btrim(p_data->>'contact_person_title'), '') else contact_person_title end,
    contact_person_phone = case when p_data ? 'contact_person_phone' then nullif(btrim(p_data->>'contact_person_phone'), '') else contact_person_phone end,
    phone_primary = coalesce(nullif(btrim(p_data->>'phone_primary'), ''), phone_primary),
    phone_secondary = case when p_data ? 'phone_secondary' then nullif(btrim(p_data->>'phone_secondary'), '') else phone_secondary end,
    whatsapp = case when p_data ? 'whatsapp' then nullif(btrim(p_data->>'whatsapp'), '') else whatsapp end,
    email = case when p_data ? 'email' then nullif(btrim(p_data->>'email'), '') else email end,
    address_line = case when p_data ? 'address_line' then nullif(btrim(p_data->>'address_line'), '') else address_line end,
    area = case when p_data ? 'area' then nullif(btrim(p_data->>'area'), '') else area end,
    city = case when p_data ? 'city' then nullif(btrim(p_data->>'city'), '') else city end,
    country = coalesce(nullif(btrim(p_data->>'country'), ''), country),
    gps_lat = case when p_data ? 'gps_lat' then (p_data->>'gps_lat')::numeric(10, 7) else gps_lat end,
    gps_lng = case when p_data ? 'gps_lng' then (p_data->>'gps_lng')::numeric(10, 7) else gps_lng end,
    payment_terms_days = coalesce(v_payment_terms, payment_terms_days),
    credit_limit = coalesce(v_credit_limit, credit_limit),
    is_vip = coalesce((p_data->>'is_vip')::boolean, is_vip),
    notes = case when p_data ? 'notes' then nullif(btrim(p_data->>'notes'), '') else notes end,
    updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function update_customer(uuid, jsonb) is
  'M2: Updates mutable customer profile fields only. Never changes tenant_id, code, account_id, or is_active.';

-- ---------------------------------------------------------------------------
-- deactivate_customer: is_active = false (gated by customers.delete).
-- ---------------------------------------------------------------------------
create or replace function deactivate_customer(p_id uuid)
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

  if not user_has_permission('customers.delete') then
    raise exception 'permission_denied';
  end if;

  update customers
  set is_active = false, updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  return p_id;
end;
$$;

comment on function deactivate_customer(uuid) is
  'M2: Soft-deactivates a customer. Leaves the linked A/R account intact.';

-- ---------------------------------------------------------------------------
-- create_supplier: atomic A/P subaccount + supplier.
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
  v_account_id uuid := gen_random_uuid();
  v_sub_code text;
  v_sup_code text;
  v_name_ar text;
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

  v_sup_code := generate_entity_code('SUP');

  insert into suppliers (
    id, tenant_id, code, name_ar, name_en, phone, email, address,
    account_id, is_active
  )
  values (
    v_supplier_id, v_tenant_id, v_sup_code,
    v_name_ar, nullif(btrim(p_data->>'name_en'), ''),
    nullif(btrim(p_data->>'phone'), ''),
    nullif(btrim(p_data->>'email'), ''),
    nullif(btrim(p_data->>'address'), ''),
    v_account_id, true
  );

  return v_supplier_id;
end;
$$;

comment on function create_supplier(jsonb) is
  'M2: Creates an A/P subaccount under 2101 and the supplier atomically. Server generates code and account_id; client tenant_id/account_id/code are ignored.';

-- ---------------------------------------------------------------------------
-- update_supplier: mutable profile fields only.
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
    address = case when p_data ? 'address' then nullif(btrim(p_data->>'address'), '') else address end
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function update_supplier(uuid, jsonb) is
  'M2: Updates mutable supplier profile fields only. Never changes tenant_id, code, account_id, or is_active.';

-- ---------------------------------------------------------------------------
-- deactivate_supplier: is_active = false (gated by suppliers.delete).
-- ---------------------------------------------------------------------------
create or replace function deactivate_supplier(p_id uuid)
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

  if not user_has_permission('suppliers.delete') then
    raise exception 'permission_denied';
  end if;

  update suppliers
  set is_active = false
  where id = p_id and tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  return p_id;
end;
$$;

comment on function deactivate_supplier(uuid) is
  'M2: Soft-deactivates a supplier. Leaves the linked A/P account intact.';

-- ---------------------------------------------------------------------------
-- create_chart_account: manual non-system, non-linked accounts only.
-- ---------------------------------------------------------------------------
create or replace function create_chart_account(p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_account_id uuid := gen_random_uuid();
  v_code text;
  v_name_ar text;
  v_name_en text;
  v_type account_type;
  v_parent_id uuid;
  v_parent_type account_type;
  v_parent_active boolean;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('chart_of_accounts.create') then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_code := nullif(btrim(p_data->>'code'), '');
  v_name_ar := nullif(btrim(p_data->>'name_ar'), '');
  v_name_en := nullif(btrim(p_data->>'name_en'), '');
  if v_code is null or v_name_ar is null or v_name_en is null
    or not (p_data ? 'type')
  then
    raise exception 'validation_failed';
  end if;

  v_type := (p_data->>'type')::account_type;

  if p_data ? 'parent_id' and nullif(btrim(p_data->>'parent_id'), '') is not null then
    v_parent_id := (p_data->>'parent_id')::uuid;

    select type, is_active
    into v_parent_type, v_parent_active
    from chart_of_accounts
    where id = v_parent_id and tenant_id = v_tenant_id;

    if v_parent_type is null then
      raise exception 'validation_failed';
    end if;
    if v_parent_active is not true then
      raise exception 'validation_failed';
    end if;
    if v_parent_type <> v_type then
      raise exception 'validation_failed';
    end if;
  end if;

  if exists (
    select 1 from chart_of_accounts
    where tenant_id = v_tenant_id and code = v_code
  ) then
    raise exception 'duplicate_code';
  end if;

  insert into chart_of_accounts (
    id, tenant_id, code, name_ar, name_en, type, parent_id,
    is_subaccount, related_entity_table, related_entity_id,
    is_active, is_system
  )
  values (
    v_account_id, v_tenant_id, v_code, v_name_ar, v_name_en, v_type, v_parent_id,
    false, null, null,
    true, false
  );

  return v_account_id;
end;
$$;

comment on function create_chart_account(jsonb) is
  'M2: Creates a manual non-system, non-linked account. Forces is_system=false and related_entity_* null regardless of payload.';

-- ---------------------------------------------------------------------------
-- update_chart_account: edit name_ar/name_en/type only. Never is_active/code.
-- ---------------------------------------------------------------------------
create or replace function update_chart_account(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_is_system boolean;
  v_related_entity_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('chart_of_accounts.edit') then
    raise exception 'permission_denied';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  -- is_active must never be changed here; deactivate_chart_account owns it.
  if p_data ? 'is_active' then
    raise exception 'validation_failed';
  end if;

  select is_system, related_entity_id
  into v_is_system, v_related_entity_id
  from chart_of_accounts
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_is_system or v_related_entity_id is not null then
    raise exception 'account_protected';
  end if;

  update chart_of_accounts
  set
    name_ar = coalesce(nullif(btrim(p_data->>'name_ar'), ''), name_ar),
    name_en = coalesce(nullif(btrim(p_data->>'name_en'), ''), name_en),
    type = coalesce((p_data->>'type')::account_type, type)
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function update_chart_account(uuid, jsonb) is
  'M2: Edits name_ar/name_en/type of a manual non-system, non-linked account. Rejects is_active changes; protection trigger backstops unsafe type changes.';

-- ---------------------------------------------------------------------------
-- deactivate_chart_account: the only RPC that sets CoA is_active=false.
-- ---------------------------------------------------------------------------
create or replace function deactivate_chart_account(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_is_system boolean;
  v_related_entity_id uuid;
begin
  v_tenant_id := current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('chart_of_accounts.delete') then
    raise exception 'permission_denied';
  end if;

  select is_system, related_entity_id
  into v_is_system, v_related_entity_id
  from chart_of_accounts
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_is_system or v_related_entity_id is not null then
    raise exception 'account_protected';
  end if;

  update chart_of_accounts
  set is_active = false
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function deactivate_chart_account(uuid) is
  'M2: Soft-deactivates a manual non-system, non-linked account. Only RPC path that changes CoA is_active.';

-- ---------------------------------------------------------------------------
-- get_customer_balance_summary: A/R totals from posted journal lines.
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

  if v_account_id is null then
    raise exception 'validation_failed';
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

comment on function get_customer_balance_summary(uuid) is
  'M2: Customer A/R debit/credit/balance from posted journal lines. Gated by customers.view_ledger; empty-safe.';

-- ---------------------------------------------------------------------------
-- get_customer_statement: posted A/R movements with true running balance.
-- running_balance includes opening balance of posted lines dated before p_from.
-- ---------------------------------------------------------------------------
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

  if v_account_id is null then
    raise exception 'validation_failed';
  end if;

  -- Opening balance: posted lines strictly before p_from.
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

comment on function get_customer_statement(uuid, date, date) is
  'M2: Customer A/R statement from posted journal lines. running_balance is the true account balance seeded by the opening balance before p_from. Gated by customers.view_ledger; empty-safe.';

-- ---------------------------------------------------------------------------
-- Guard trigger: customers immutable columns.
-- ---------------------------------------------------------------------------
create or replace function enforce_customer_immutable_columns()
returns trigger
language plpgsql
as $$
begin
  if new.tenant_id is distinct from old.tenant_id
    or new.code is distinct from old.code
    or new.account_id is distinct from old.account_id
  then
    raise exception 'immutable_column';
  end if;
  return new;
end;
$$;

create trigger trg_enforce_customer_immutable_columns
  before update on customers
  for each row execute function enforce_customer_immutable_columns();

-- ---------------------------------------------------------------------------
-- Guard trigger: suppliers immutable columns.
-- ---------------------------------------------------------------------------
create or replace function enforce_supplier_immutable_columns()
returns trigger
language plpgsql
as $$
begin
  if new.tenant_id is distinct from old.tenant_id
    or new.code is distinct from old.code
    or new.account_id is distinct from old.account_id
  then
    raise exception 'immutable_column';
  end if;
  return new;
end;
$$;

create trigger trg_enforce_supplier_immutable_columns
  before update on suppliers
  for each row execute function enforce_supplier_immutable_columns();

-- ---------------------------------------------------------------------------
-- Guard trigger: chart_of_accounts protection.
-- ---------------------------------------------------------------------------
create or replace function enforce_chart_account_protection()
returns trigger
language plpgsql
as $$
begin
  -- System rows are fully read-only.
  if old.is_system then
    raise exception 'account_protected';
  end if;

  -- No privilege escalation into a system row.
  if new.is_system and not old.is_system then
    raise exception 'account_protected';
  end if;

  -- Tenant and entity linkage are immutable.
  if new.tenant_id is distinct from old.tenant_id
    or new.related_entity_table is distinct from old.related_entity_table
    or new.related_entity_id is distinct from old.related_entity_id
  then
    raise exception 'immutable_column';
  end if;

  -- Account codes are generated/assigned at creation and immutable afterwards.
  if new.code is distinct from old.code then
    raise exception 'immutable_column';
  end if;

  -- Linked subaccounts cannot be deactivated manually.
  if old.related_entity_id is not null then
    if new.is_active is distinct from old.is_active then
      raise exception 'account_protected';
    end if;
  end if;

  -- Block type change when the account has children or journal lines.
  if new.type is distinct from old.type then
    if exists (
      select 1 from chart_of_accounts c
      where c.parent_id = old.id
    ) or exists (
      select 1 from journal_lines jl
      where jl.account_id = old.id
    ) then
      raise exception 'account_type_change_unsafe';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_enforce_chart_account_protection
  before update on chart_of_accounts
  for each row execute function enforce_chart_account_protection();

-- ---------------------------------------------------------------------------
-- RLS hardening: writes are RPC-only. Keep SELECT policies only.
-- ---------------------------------------------------------------------------
drop policy if exists customers_insert on customers;
drop policy if exists customers_update on customers;
drop policy if exists customers_delete on customers;

drop policy if exists suppliers_insert on suppliers;
drop policy if exists suppliers_update on suppliers;
drop policy if exists suppliers_delete on suppliers;

drop policy if exists chart_of_accounts_insert on chart_of_accounts;
drop policy if exists chart_of_accounts_update on chart_of_accounts;
drop policy if exists chart_of_accounts_delete on chart_of_accounts;

-- ---------------------------------------------------------------------------
-- Audit triggers (reuse audit_log_row()).
-- ---------------------------------------------------------------------------
create trigger trg_audit_customers_insert
  after insert on customers
  for each row execute function audit_log_row();

create trigger trg_audit_customers_update
  after update on customers
  for each row execute function audit_log_row();

create trigger trg_audit_customers_delete
  after delete on customers
  for each row execute function audit_log_row();

create trigger trg_audit_suppliers_insert
  after insert on suppliers
  for each row execute function audit_log_row();

create trigger trg_audit_suppliers_update
  after update on suppliers
  for each row execute function audit_log_row();

create trigger trg_audit_suppliers_delete
  after delete on suppliers
  for each row execute function audit_log_row();

create trigger trg_audit_chart_of_accounts_insert
  after insert on chart_of_accounts
  for each row execute function audit_log_row();

create trigger trg_audit_chart_of_accounts_update
  after update on chart_of_accounts
  for each row execute function audit_log_row();

create trigger trg_audit_chart_of_accounts_delete
  after delete on chart_of_accounts
  for each row execute function audit_log_row();

-- ---------------------------------------------------------------------------
-- Index for customer ledger lookups.
-- ---------------------------------------------------------------------------
create index if not exists idx_jlines_account
  on journal_lines (tenant_id, account_id);

-- ---------------------------------------------------------------------------
-- Grants: helpers revoked from public only; RPCs granted to authenticated.
-- ---------------------------------------------------------------------------
revoke all on function get_entity_parent_account(text) from public;
revoke all on function generate_entity_code(text) from public;
revoke all on function generate_subaccount_code(uuid, text) from public;

revoke all on function create_customer(jsonb) from public;
revoke all on function update_customer(uuid, jsonb) from public;
revoke all on function deactivate_customer(uuid) from public;
revoke all on function create_supplier(jsonb) from public;
revoke all on function update_supplier(uuid, jsonb) from public;
revoke all on function deactivate_supplier(uuid) from public;
revoke all on function create_chart_account(jsonb) from public;
revoke all on function update_chart_account(uuid, jsonb) from public;
revoke all on function deactivate_chart_account(uuid) from public;
revoke all on function get_customer_balance_summary(uuid) from public;
revoke all on function get_customer_statement(uuid, date, date) from public;

grant execute on function create_customer(jsonb) to authenticated;
grant execute on function update_customer(uuid, jsonb) to authenticated;
grant execute on function deactivate_customer(uuid) to authenticated;
grant execute on function create_supplier(jsonb) to authenticated;
grant execute on function update_supplier(uuid, jsonb) to authenticated;
grant execute on function deactivate_supplier(uuid) to authenticated;
grant execute on function create_chart_account(jsonb) to authenticated;
grant execute on function update_chart_account(uuid, jsonb) to authenticated;
grant execute on function deactivate_chart_account(uuid) to authenticated;
grant execute on function get_customer_balance_summary(uuid) to authenticated;
grant execute on function get_customer_statement(uuid, date, date) to authenticated;
