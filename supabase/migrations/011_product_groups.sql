-- Phase 1B: product groups (section 7.1).

create table product_groups (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  name_ar text not null,
  name_en text not null,
  parent_id uuid references product_groups (id),
  sort_order int default 0,
  is_active boolean default true,
  created_at timestamptz default now(),
  created_by uuid references auth.users (id)
);

create index idx_pgroups_tenant on product_groups (tenant_id);
