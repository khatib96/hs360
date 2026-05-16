-- Phase 1B: chart of accounts (section 6).

create table chart_of_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  code text not null,
  name_ar text not null,
  name_en text not null,
  type account_type not null,
  parent_id uuid references chart_of_accounts (id),
  is_subaccount boolean default false,
  related_entity_table text,
  related_entity_id uuid,
  is_active boolean default true,
  is_system boolean default false,
  created_at timestamptz default now(),
  unique (tenant_id, code)
);

create index idx_coa_tenant on chart_of_accounts (tenant_id);
create index idx_coa_parent on chart_of_accounts (parent_id);
