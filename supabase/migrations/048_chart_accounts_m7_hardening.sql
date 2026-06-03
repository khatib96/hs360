-- M7: Chart of accounts RPC + trigger hardening (immutable payload keys,
-- entity-linked parent guard, parent type mismatch, active children on deactivate).

-- ---------------------------------------------------------------------------
-- create_chart_account: reject entity-linked parents.
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
  v_parent_related_entity_id uuid;
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

    select type, is_active, related_entity_id
    into v_parent_type, v_parent_active, v_parent_related_entity_id
    from chart_of_accounts
    where id = v_parent_id and tenant_id = v_tenant_id;

    if v_parent_type is null then
      raise exception 'validation_failed';
    end if;
    if v_parent_active is not true then
      raise exception 'validation_failed';
    end if;
    if v_parent_related_entity_id is not null then
      raise exception 'validation_failed';
    end if;
    if v_parent_type <> v_type then
      raise exception 'parent_type_mismatch';
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
  'M7: Creates manual account; parent must be active, same type, not entity-linked.';

-- ---------------------------------------------------------------------------
-- update_chart_account: reject immutable payload keys; parent type on type change.
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
  v_parent_id uuid;
  v_current_type account_type;
  v_new_type account_type;
  v_parent_type account_type;
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

  if p_data ? 'code'
    or p_data ? 'parent_id'
    or p_data ? 'tenant_id'
    or p_data ? 'related_entity_table'
    or p_data ? 'related_entity_id'
    or p_data ? 'is_system'
    or p_data ? 'is_active'
  then
    raise exception 'immutable_column';
  end if;

  select is_system, related_entity_id, parent_id, type
  into v_is_system, v_related_entity_id, v_parent_id, v_current_type
  from chart_of_accounts
  where id = p_id and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_is_system or v_related_entity_id is not null then
    raise exception 'account_protected';
  end if;

  if p_data ? 'type' and nullif(btrim(p_data->>'type'), '') is not null then
    v_new_type := (p_data->>'type')::account_type;
    if v_new_type is distinct from v_current_type and v_parent_id is not null then
      select type into v_parent_type
      from chart_of_accounts
      where id = v_parent_id and tenant_id = v_tenant_id;

      if v_parent_type is null then
        raise exception 'validation_failed';
      end if;
      if v_parent_type <> v_new_type then
        raise exception 'parent_type_mismatch';
      end if;
    end if;
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
  'M7: Edits manual account names/type; rejects immutable payload keys; parent type guard on type change.';

-- ---------------------------------------------------------------------------
-- deactivate_chart_account: reject when active children exist.
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

  if exists (
    select 1 from chart_of_accounts c
    where c.parent_id = p_id
      and c.tenant_id = v_tenant_id
      and c.is_active is true
  ) then
    raise exception 'account_has_active_children';
  end if;

  update chart_of_accounts
  set is_active = false
  where id = p_id and tenant_id = v_tenant_id;

  return p_id;
end;
$$;

comment on function deactivate_chart_account(uuid) is
  'M7: Soft-deactivates manual account; rejects when active children exist.';

-- ---------------------------------------------------------------------------
-- Guard trigger: block deactivation when active children exist.
-- ---------------------------------------------------------------------------
create or replace function enforce_chart_account_protection()
returns trigger
language plpgsql
as $$
begin
  if old.is_system then
    raise exception 'account_protected';
  end if;

  if new.is_system and not old.is_system then
    raise exception 'account_protected';
  end if;

  if new.tenant_id is distinct from old.tenant_id
    or new.related_entity_table is distinct from old.related_entity_table
    or new.related_entity_id is distinct from old.related_entity_id
  then
    raise exception 'immutable_column';
  end if;

  if new.code is distinct from old.code then
    raise exception 'immutable_column';
  end if;

  if old.related_entity_id is not null then
    if new.is_active is distinct from old.is_active then
      raise exception 'account_protected';
    end if;
  end if;

  -- M7: cannot deactivate parent while active children exist.
  if old.is_active is true and new.is_active is false then
    if exists (
      select 1 from chart_of_accounts c
      where c.parent_id = old.id
        and c.tenant_id = old.tenant_id
        and c.is_active is true
    ) then
      raise exception 'account_has_active_children';
    end if;
  end if;

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
