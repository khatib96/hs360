-- Phase 1B: maintenance records (section 7.4). contract_id FK deferred to 021.

create table maintenance_records (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  product_unit_id uuid not null references product_units (id),
  reported_at timestamptz default now(),
  reported_by uuid references auth.users (id),
  reported_via text,
  contract_id uuid,

  status maintenance_status not null default 'reported',

  problem_description text not null,
  diagnosis text,
  resolution text,

  cost numeric(15, 3) default 0,
  parts_cost numeric(15, 3) default 0,
  labor_cost numeric(15, 3) default 0,

  started_at timestamptz,
  completed_at timestamptz,
  technician_id uuid references employees (id),

  notes text,
  created_at timestamptz default now()
);

create index idx_maint_tenant on maintenance_records (tenant_id);
create index idx_maint_unit on maintenance_records (product_unit_id);
create index idx_maint_status on maintenance_records (status);
