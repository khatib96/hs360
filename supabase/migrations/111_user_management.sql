-- Users & Permissions management (Manager/User model, no roles).
--
-- Logins are created by the admin-users Edge Function (Auth admin API) with an
-- initial password; the employee must change it at first sign-in and an admin
-- can reset it. No e-mail is sent. All membership and permission writes go
-- through the RPCs below:
--
-- * Direct INSERT/UPDATE/DELETE on tenant_users and user_permissions is now
--   limited to managers (who hold every permission anyway). The old policies
--   let a non-manager holding settings.users.edit promote any account to
--   manager or grant any permission directly through the REST API; delegated
--   (non-manager) administrators must use the RPCs below.
-- * Non-managers may only grant or revoke permissions they hold themselves,
--   and only managers may create, reset, or (de)activate manager accounts.
-- * Nobody can change their own membership or permissions here.

alter table public.tenant_users
  add column if not exists must_change_password boolean not null default false;

drop policy if exists tenant_users_insert on public.tenant_users;
drop policy if exists tenant_users_update on public.tenant_users;
drop policy if exists tenant_users_delete on public.tenant_users;

create policy tenant_users_insert on public.tenant_users
  for insert with check (tenant_id = public.current_tenant_id() and public.is_manager());
create policy tenant_users_update on public.tenant_users
  for update using (tenant_id = public.current_tenant_id() and public.is_manager());
create policy tenant_users_delete on public.tenant_users
  for delete using (tenant_id = public.current_tenant_id() and public.is_manager());

drop policy if exists user_permissions_insert on public.user_permissions;
drop policy if exists user_permissions_update on public.user_permissions;
drop policy if exists user_permissions_delete on public.user_permissions;

create policy user_permissions_insert on public.user_permissions
  for insert with check (
    tenant_id = public.current_tenant_id()
    and public.is_manager()
    and tenant_user_id <> public.current_tenant_user_id()
  );
create policy user_permissions_update on public.user_permissions
  for update using (
    tenant_id = public.current_tenant_id()
    and public.is_manager()
    and tenant_user_id <> public.current_tenant_user_id()
  );
create policy user_permissions_delete on public.user_permissions
  for delete using (
    tenant_id = public.current_tenant_id()
    and public.is_manager()
    and tenant_user_id <> public.current_tenant_user_id()
  );

-- ---------------------------------------------------------------------------
-- Internal: target account in the caller's company that the caller may manage
-- ---------------------------------------------------------------------------
create or replace function public.resolve_managed_tenant_user(p_tenant_user_id uuid)
returns public.tenant_users
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_target public.tenant_users%rowtype;
begin
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  select * into v_target
  from public.tenant_users
  where id = p_tenant_user_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'user_not_found';
  end if;

  if v_target.user_id = auth.uid() then
    raise exception 'cannot_modify_self';
  end if;

  if v_target.account_type = 'manager' and not public.is_manager() then
    raise exception 'manager_required';
  end if;

  return v_target;
end;
$$;

revoke all on function public.resolve_managed_tenant_user(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- list_tenant_users
-- ---------------------------------------------------------------------------
create or replace function public.list_tenant_users()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
begin
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('settings.users.view') then
    raise exception 'permission_denied';
  end if;

  return coalesce((
    select jsonb_agg(row_data order by sort_manager, sort_name)
    from (
      select
        case when tu.account_type = 'manager' then 0 else 1 end as sort_manager,
        lower(coalesce(nullif(tu.display_name, ''), u.email, '')) as sort_name,
        jsonb_build_object(
          'tenant_user_id', tu.id,
          'user_id', tu.user_id,
          'display_name', coalesce(tu.display_name, ''),
          'login', coalesce(u.email, ''),
          'account_type', tu.account_type::text,
          'is_active', coalesce(tu.is_active, false),
          'must_change_password', tu.must_change_password,
          'is_self', tu.user_id = auth.uid(),
          'joined_at', tu.joined_at,
          'last_sign_in_at', u.last_sign_in_at,
          'permission_ids', coalesce((
            select jsonb_agg(up.permission_id order by up.permission_id)
            from public.user_permissions up
            where up.tenant_user_id = tu.id
          ), '[]'::jsonb)
        ) as row_data
      from public.tenant_users tu
      left join auth.users u on u.id = tu.user_id
      where tu.tenant_id = v_tenant_id
    ) rows
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- set_tenant_user_permissions: replace a user's explicit permission set
-- ---------------------------------------------------------------------------
create or replace function public.set_tenant_user_permissions(
  p_tenant_user_id uuid,
  p_permission_ids text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.tenant_users%rowtype;
  v_requested text[];
  v_current text[];
  v_added text[];
  v_removed text[];
begin
  if not public.user_has_permission('settings.users.edit') then
    raise exception 'permission_denied';
  end if;

  v_target := public.resolve_managed_tenant_user(p_tenant_user_id);

  if v_target.account_type = 'manager' then
    raise exception 'target_is_manager';
  end if;

  select coalesce(array_agg(distinct btrim(id) order by btrim(id)), '{}')
  into v_requested
  from unnest(coalesce(p_permission_ids, '{}')) as id
  where nullif(btrim(id), '') is not null;

  if exists (
    select 1 from unnest(v_requested) as requested(permission_id)
    where not exists (
      select 1 from public.permissions p where p.id = requested.permission_id
    )
  ) then
    raise exception 'validation_failed';
  end if;

  select coalesce(array_agg(permission_id order by permission_id), '{}')
  into v_current
  from public.user_permissions
  where tenant_user_id = v_target.id;

  select coalesce(array_agg(id order by id), '{}') into v_added
  from unnest(v_requested) as id
  where not (id = any(v_current));

  select coalesce(array_agg(id order by id), '{}') into v_removed
  from unnest(v_current) as id
  where not (id = any(v_requested));

  if not public.is_manager() and exists (
    select 1 from unnest(v_added || v_removed) as id
    where not public.user_has_permission(id)
  ) then
    raise exception 'permission_not_held';
  end if;

  delete from public.user_permissions
  where tenant_user_id = v_target.id
    and permission_id = any(v_removed);

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  select v_target.tenant_id, v_target.id, id, auth.uid()
  from unnest(v_added) as id;

  return jsonb_build_object('added', to_jsonb(v_added), 'removed', to_jsonb(v_removed));
end;
$$;

-- ---------------------------------------------------------------------------
-- set_tenant_user_active
-- ---------------------------------------------------------------------------
create or replace function public.set_tenant_user_active(
  p_tenant_user_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.tenant_users%rowtype;
begin
  if not public.user_has_permission('settings.users.deactivate') then
    raise exception 'permission_denied';
  end if;
  if p_is_active is null then
    raise exception 'validation_failed';
  end if;

  v_target := public.resolve_managed_tenant_user(p_tenant_user_id);

  if v_target.is_active = p_is_active then
    return;
  end if;

  if not p_is_active
     and v_target.account_type = 'manager'
     and not exists (
       select 1 from public.tenant_users
       where tenant_id = v_target.tenant_id
         and account_type = 'manager'
         and is_active
         and id <> v_target.id
     ) then
    raise exception 'last_manager';
  end if;

  update public.tenant_users
  set is_active = p_is_active
  where id = v_target.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- register_tenant_user: attach a login just created by admin-users
-- ---------------------------------------------------------------------------
create or replace function public.register_tenant_user(
  p_user_id uuid,
  p_display_name text,
  p_account_type text default 'user'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_display_name text := nullif(btrim(p_display_name), '');
  v_account_type text := coalesce(nullif(btrim(p_account_type), ''), 'user');
  v_created_at timestamptz;
  v_last_sign_in timestamptz;
  v_locale text;
  v_id uuid;
begin
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('settings.users.invite') then
    raise exception 'permission_denied';
  end if;
  if v_display_name is null or v_account_type not in ('user', 'manager') then
    raise exception 'validation_failed';
  end if;
  if v_account_type = 'manager' and not public.is_manager() then
    raise exception 'manager_required';
  end if;

  select created_at, last_sign_in_at
  into v_created_at, v_last_sign_in
  from auth.users
  where id = p_user_id;

  if not found then
    raise exception 'user_not_found';
  end if;

  -- Only a login created moments ago and never used can be attached, so an
  -- existing account (possibly someone else's) cannot be pulled in.
  if v_created_at < now() - interval '15 minutes' or v_last_sign_in is not null then
    raise exception 'login_not_fresh';
  end if;

  -- One login belongs to one company until company switching exists.
  if exists (select 1 from public.tenant_users where user_id = p_user_id) then
    raise exception 'login_already_member';
  end if;

  select coalesce(default_locale, 'ar') into v_locale
  from public.tenants where id = v_tenant_id;

  insert into public.tenant_users (
    tenant_id, user_id, account_type, display_name, preferred_locale,
    is_active, invited_by, must_change_password
  )
  values (
    v_tenant_id, p_user_id, v_account_type::public.user_account_type,
    v_display_name, v_locale, true, auth.uid(), true
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- prepare_tenant_user_password_reset: authorize a reset and force a change
-- ---------------------------------------------------------------------------
create or replace function public.prepare_tenant_user_password_reset(p_tenant_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.tenant_users%rowtype;
begin
  if not public.user_has_permission('settings.users.edit') then
    raise exception 'permission_denied';
  end if;

  v_target := public.resolve_managed_tenant_user(p_tenant_user_id);

  update public.tenant_users
  set must_change_password = true
  where id = v_target.id;

  -- The tenant_users audit trigger only watches account_type/is_active.
  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_target.tenant_id, auth.uid(), public.current_account_type()::text,
    'password_reset', 'tenant_users', v_target.id,
    jsonb_build_object('must_change_password', v_target.must_change_password),
    jsonb_build_object('must_change_password', true)
  );

  return v_target.user_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- complete_own_password_change: called by admin-users after the new password
-- is stored, so the flag cannot be cleared without actually changing it.
-- ---------------------------------------------------------------------------
create or replace function public.complete_own_password_change(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.tenant_users
  set must_change_password = false
  where user_id = p_user_id
    and must_change_password;
end;
$$;

revoke all on function public.list_tenant_users() from public, anon;
revoke all on function public.set_tenant_user_permissions(uuid, text[]) from public, anon;
revoke all on function public.set_tenant_user_active(uuid, boolean) from public, anon;
revoke all on function public.register_tenant_user(uuid, text, text) from public, anon;
revoke all on function public.prepare_tenant_user_password_reset(uuid) from public, anon;
revoke all on function public.complete_own_password_change(uuid) from public, anon, authenticated;

grant execute on function public.list_tenant_users() to authenticated;
grant execute on function public.set_tenant_user_permissions(uuid, text[]) to authenticated;
grant execute on function public.set_tenant_user_active(uuid, boolean) to authenticated;
grant execute on function public.register_tenant_user(uuid, text, text) to authenticated;
grant execute on function public.prepare_tenant_user_password_reset(uuid) to authenticated;
grant execute on function public.complete_own_password_change(uuid) to service_role;
