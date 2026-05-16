-- Phase 1B: commission rules, salaries, advances (section 4.2).

create table commission_rules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  name text not null,
  basis commission_basis not null,
  rate numeric(8, 4),
  fixed_amount numeric(15, 3),
  job_type employee_job_type,
  employee_id uuid references employees (id),
  is_active boolean default true,
  effective_from date not null,
  effective_to date,
  created_at timestamptz default now()
);

create table salaries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  employee_id uuid not null references employees (id),
  period_year int not null,
  period_month int not null check (period_month between 1 and 12),
  base_amount numeric(15, 3) not null,
  commission_amount numeric(15, 3) default 0,
  advance_deductions numeric(15, 3) default 0,
  other_deductions numeric(15, 3) default 0,
  net_amount numeric(15, 3) not null,
  voucher_id uuid,
  status text default 'draft',
  notes text,
  created_at timestamptz default now(),
  unique (employee_id, period_year, period_month)
);

create table advances (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  employee_id uuid not null references employees (id),
  amount numeric(15, 3) not null,
  date date not null,
  reason text,
  remaining_balance numeric(15, 3) not null,
  voucher_id uuid,
  is_settled boolean default false,
  created_at timestamptz default now()
);
