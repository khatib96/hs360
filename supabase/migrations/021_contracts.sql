-- Phase 1B: contracts, lines, oil changes (section 10).

create table contracts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  contract_number text not null,

  type contract_type not null default 'rental',
  status contract_status not null default 'draft',

  customer_id uuid not null references customers (id),

  contact_person_name text,
  contact_phone text not null,
  contact_email text,

  start_date date not null,
  end_date date,
  trial_days int,
  trial_end_date date,
  trial_outcome text,

  billing_day int check (billing_day between 1 and 28),
  refill_day int check (refill_day between 1 and 28),

  monthly_rental_value numeric(15, 3) not null,

  total_contract_value numeric(15, 3),

  snapshot_device_monthly_cost numeric(15, 3) not null default 0,
  snapshot_oil_monthly_cost numeric(15, 3) not null default 0,
  snapshot_total_monthly_cost numeric(15, 3) not null default 0,
  snapshot_monthly_profit numeric(15, 3) not null default 0,
  snapshot_min_profit_threshold numeric(15, 3) not null default 0,

  location_lat numeric(10, 7),
  location_lng numeric(10, 7),
  location_address text,

  signed_by_customer_at timestamptz,
  signature_url text,

  created_by_agent_id uuid references employees (id),

  min_profit_overridden boolean default false,
  override_approved_by uuid references auth.users (id),
  override_approved_at timestamptz,
  override_reason text,

  closed_at timestamptz,
  closed_by uuid references auth.users (id),
  closure_reason text,

  notes text,

  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz,
  updated_by uuid references auth.users (id),

  unique (tenant_id, contract_number)
);

create index idx_contracts_tenant on contracts (tenant_id);
create index idx_contracts_customer on contracts (customer_id);
create index idx_contracts_status on contracts (status);
create index idx_contracts_refill_day on contracts (refill_day);
create index idx_contracts_trial_end on contracts (trial_end_date);

create table contract_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  contract_id uuid not null references contracts (id) on delete cascade,
  line_type contract_line_type not null,
  product_id uuid not null references products (id),
  product_unit_id uuid references product_units (id),

  qty_per_refill numeric(15, 3),
  refill_frequency_months int default 1,

  snapshot_unit_cost numeric(15, 3) not null,
  snapshot_monthly_cost numeric(15, 3) not null,

  line_order int not null,
  created_at timestamptz default now()
);

create index idx_clines_tenant on contract_lines (tenant_id);
create index idx_clines_contract on contract_lines (contract_id);
create index idx_clines_unit on contract_lines (product_unit_id);

create table contract_oil_changes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  contract_id uuid not null references contracts (id) on delete cascade,
  contract_line_id uuid not null references contract_lines (id),

  effective_from date not null,
  effective_to date,

  oil_product_id uuid not null references products (id),
  qty_per_refill numeric(15, 3) not null,
  snapshot_unit_cost numeric(15, 3) not null,
  snapshot_refill_cost numeric(15, 3) not null,

  changed_by_agent_id uuid references employees (id),
  reason text,

  created_at timestamptz default now()
);

create index idx_oilchg_tenant on contract_oil_changes (tenant_id);
create index idx_oilchg_contract on contract_oil_changes (contract_id);
create index idx_oilchg_active on contract_oil_changes (contract_line_id, effective_to);

alter table product_units
  add constraint fk_product_units_current_contract
  foreign key (current_contract_id) references contracts (id);

alter table maintenance_records
  add constraint fk_maintenance_records_contract
  foreign key (contract_id) references contracts (id);

alter table invoices
  add constraint fk_invoices_contract
  foreign key (contract_id) references contracts (id);
