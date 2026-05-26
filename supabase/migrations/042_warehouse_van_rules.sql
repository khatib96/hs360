-- Phase 3 M7A: warehouse van rules and assignable employee lookup.

-- Replace all-van unique index with active-van-only uniqueness.
drop index if exists idx_warehouses_van_agent;

create unique index ux_warehouses_active_van_agent
  on warehouses (tenant_id, agent_id)
  where type = 'van' and is_active = true and agent_id is not null;

-- Van warehouses must always reference an employee.
-- If applying to a DB with legacy rows, cleanup van rows with null agent_id first.
alter table warehouses add constraint warehouses_van_requires_agent
  check (type <> 'van' or agent_id is not null);

-- Employee list for warehouse UI (avoids hr.employees.view RLS on direct select).
create or replace function list_warehouse_assignable_employees()
returns table (
  id uuid,
  code text,
  name_ar text,
  name_en text,
  is_active boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;

  if not user_has_permission('warehouses.view') then
    raise exception 'permission_denied';
  end if;

  return query
  select e.id, e.code, e.name_ar, e.name_en, e.is_active
  from employees e
  where e.tenant_id = current_tenant_id()
  order by e.is_active desc, e.name_en, e.code;
end;
$$;

grant execute on function list_warehouse_assignable_employees() to authenticated;
