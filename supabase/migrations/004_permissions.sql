-- Phase 1A: permission catalog and user grants (no RLS in this phase).

create table permissions (
  id text primary key,
  module text not null,
  action text not null,
  scope text not null default 'action',
  field_name text,
  label_ar text not null,
  label_en text not null,
  description_ar text,
  description_en text,
  is_sensitive boolean default false,
  category text not null,
  sort_order int default 0,
  constraint chk_permissions_scope check (scope in ('action', 'field')),
  constraint chk_permissions_field check (
    (scope = 'field' and field_name is not null)
    or (scope = 'action' and field_name is null)
  )
);

create table user_permissions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  tenant_user_id uuid not null references tenant_users (id) on delete cascade,
  permission_id text not null references permissions (id),
  granted_at timestamptz default now(),
  granted_by uuid references auth.users (id),
  unique (tenant_user_id, permission_id)
);

create index idx_userperms_tenant on user_permissions (tenant_id);
create index idx_userperms_user on user_permissions (tenant_user_id);
create index idx_userperms_perm on user_permissions (permission_id);

create or replace function user_has_permission(p_permission_id text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if is_manager() then
    return true;
  end if;

  return exists (
    select 1
    from user_permissions up
    join tenant_users tu on tu.id = up.tenant_user_id
    where tu.user_id = auth.uid()
      and tu.tenant_id = current_tenant_id()
      and tu.is_active = true
      and up.permission_id = p_permission_id
  );
end;
$$;
