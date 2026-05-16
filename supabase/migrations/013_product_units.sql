-- Phase 1B: product units (section 7.3). Deferred FKs on current_contract_id, current_customer_id, purchase_invoice_id.

create table product_units (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  product_id uuid not null references products (id),
  serial_number text not null,
  barcode text,
  status unit_status not null default 'available_new',

  current_contract_id uuid,
  current_customer_id uuid,
  current_warehouse_id uuid references warehouses (id),

  purchase_cost numeric(15, 3),
  purchase_invoice_id uuid,

  health_status text default 'good',
  total_maintenance_count int default 0,
  last_maintenance_at timestamptz,

  notes text,
  acquired_at date not null,
  retired_at date,

  created_at timestamptz default now(),
  updated_at timestamptz,
  unique (tenant_id, serial_number)
);

create index idx_units_tenant on product_units (tenant_id);
create index idx_units_product on product_units (product_id);
create index idx_units_status on product_units (status);
