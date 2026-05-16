-- Phase 1B: suppliers (section 9.2).

create table suppliers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  code text not null,
  name_ar text not null,
  name_en text,
  phone text,
  email text,
  address text,
  account_id uuid not null references chart_of_accounts (id),
  is_active boolean default true,
  created_at timestamptz default now(),
  unique (tenant_id, code)
);
