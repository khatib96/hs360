-- Phase 1B: visits (section 11). visit/voucher circular FKs resolved here.

create table visits (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  visit_number text not null,
  type visit_type not null,
  status visit_status not null default 'scheduled',

  contract_id uuid references contracts (id),
  customer_id uuid references customers (id),
  agent_id uuid not null references employees (id),

  scheduled_date date not null,
  scheduled_time time,
  started_at timestamptz,
  completed_at timestamptz,

  check_in_lat numeric(10, 7),
  check_in_lng numeric(10, 7),
  check_in_accuracy_m numeric(8, 2),
  check_out_lat numeric(10, 7),
  check_out_lng numeric(10, 7),
  location_match boolean,

  photo_url text,
  photo_taken_at timestamptz,

  oil_product_id uuid references products (id),
  oil_qty_ml numeric(15, 3),

  payment_collected boolean default false,
  payment_amount numeric(15, 3),
  payment_method text,
  voucher_id uuid,

  notes text,
  customer_signature_url text,

  client_id text,
  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  synced_at timestamptz,

  unique (tenant_id, visit_number),
  unique (client_id) deferrable initially deferred
);

create index idx_visits_tenant on visits (tenant_id);
create index idx_visits_agent on visits (agent_id);
create index idx_visits_contract on visits (contract_id);
create index idx_visits_date on visits (scheduled_date);
create index idx_visits_status on visits (status);

alter table visits
  add constraint fk_visits_voucher
  foreign key (voucher_id) references vouchers (id);

alter table vouchers
  add constraint fk_vouchers_visit
  foreign key (visit_id) references visits (id);

alter table invoices
  add constraint fk_invoices_visit
  foreign key (visit_id) references visits (id);
