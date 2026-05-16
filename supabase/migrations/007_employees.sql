-- Phase 1B: employees (section 4.1).

create table employees (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  user_id uuid unique references auth.users (id),
  code text not null,
  name_ar text not null,
  name_en text,
  job_type employee_job_type not null default 'other',
  phone text,
  email text,
  base_salary numeric(15, 3) not null default 0,
  hire_date date not null,
  termination_date date,
  is_active boolean default true,
  notes text,
  created_at timestamptz default now(),
  unique (tenant_id, code)
);

create index idx_employees_tenant on employees (tenant_id);
create index idx_employees_job_type on employees (job_type);
