-- Phase 1B: inventory balances and movements (section 8).

create table inventory_balances (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  warehouse_id uuid not null references warehouses (id),
  product_id uuid not null references products (id),
  qty_available numeric(15, 3) not null default 0,
  qty_rented numeric(15, 3) not null default 0,
  qty_trial numeric(15, 3) not null default 0,
  qty_maintenance numeric(15, 3) not null default 0,
  qty_damaged numeric(15, 3) not null default 0,
  updated_at timestamptz default now(),
  unique (warehouse_id, product_id)
);

create index idx_balances_tenant on inventory_balances (tenant_id);
create index idx_balances_warehouse on inventory_balances (warehouse_id);

create table inventory_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  movement_type movement_type not null,
  warehouse_id uuid not null references warehouses (id),
  product_id uuid not null references products (id),
  product_unit_id uuid references product_units (id),
  qty numeric(15, 3) not null,
  unit_cost numeric(15, 3),
  reference_table text,
  reference_id uuid,
  notes text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz default now(),
  created_by uuid references auth.users (id)
);

create index idx_movements_tenant on inventory_movements (tenant_id);
create index idx_movements_occurred on inventory_movements (occurred_at desc);
create index idx_movements_ref on inventory_movements (reference_table, reference_id);
