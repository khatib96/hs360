-- Phase 1C: helper functions for RLS, views, and triggers (existing helpers remain in 002/004/005).

create or replace function current_tenant_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from tenant_users
  where user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

create or replace function current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from employees
  where user_id = auth.uid()
    and tenant_id = current_tenant_id()
    and is_active = true
  limit 1;
$$;

create or replace function get_my_permissions()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_is_manager boolean;
  v_permissions text[];
begin
  select account_type = 'manager'
  into v_is_manager
  from tenant_users
  where user_id = auth.uid()
    and is_active = true
  limit 1;

  if v_is_manager then
    return json_build_object('is_manager', true, 'permissions', '[]'::json);
  end if;

  select array_agg(up.permission_id)
  into v_permissions
  from user_permissions up
  join tenant_users tu on tu.id = up.tenant_user_id
  where tu.user_id = auth.uid()
    and tu.is_active = true;

  return json_build_object(
    'is_manager', false,
    'permissions', coalesce(v_permissions, '{}'::text[])
  );
end;
$$;

comment on function get_my_permissions() is
  'Managers: is_manager=true, permissions=[]. Clients must treat is_manager as full access via user_has_permission().';

create or replace function touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

grant execute on function current_tenant_user_id() to authenticated;
grant execute on function current_employee_id() to authenticated;
grant execute on function get_my_permissions() to authenticated;
