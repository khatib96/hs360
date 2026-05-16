-- Phase 1B: warehouses (section 5).

create table warehouses (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  name_ar text not null,
  name_en text not null,
  type warehouse_type not null default 'main',
  agent_id uuid references employees (id),
  location_address text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create index idx_warehouses_tenant on warehouses (tenant_id);
create unique index idx_warehouses_van_agent
  on warehouses (tenant_id, agent_id)
  where type = 'van';
