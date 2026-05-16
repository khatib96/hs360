-- Phase 1B: invoices and invoice lines (section 12). contract_id/visit_id FKs deferred to 021/022.

create table invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  invoice_number text not null,
  type invoice_type not null,
  status invoice_status not null default 'draft',

  customer_id uuid references customers (id),
  supplier_id uuid references suppliers (id),
  contract_id uuid,
  visit_id uuid,

  date date not null,
  due_date date,

  subtotal numeric(15, 3) not null default 0,
  discount_amount numeric(15, 3) not null default 0,
  tax_amount numeric(15, 3) not null default 0,
  total numeric(15, 3) not null default 0,
  paid_amount numeric(15, 3) not null default 0,

  warehouse_id uuid references warehouses (id),
  notes text,

  journal_entry_id uuid,
  pdf_url text,
  sent_at timestamptz,
  sent_channels text[],

  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users (id),

  unique (tenant_id, invoice_number),
  constraint chk_party check (
    (customer_id is not null and supplier_id is null)
    or (customer_id is null and supplier_id is not null)
  )
);

create index idx_invoices_tenant on invoices (tenant_id);
create index idx_invoices_customer on invoices (customer_id);
create index idx_invoices_contract on invoices (contract_id);
create index idx_invoices_status on invoices (status);
create index idx_invoices_date on invoices (date);

create table invoice_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  invoice_id uuid not null references invoices (id) on delete cascade,
  product_id uuid not null references products (id),
  product_unit_id uuid references product_units (id),
  description text,
  qty numeric(15, 3) not null,
  unit_price numeric(15, 3) not null,
  discount_pct numeric(5, 2) default 0,
  cost_price numeric(15, 3),
  line_total numeric(15, 3) not null,
  line_order int not null
);

create index idx_invlines_invoice on invoice_lines (invoice_id);

alter table invoices
  add constraint fk_invoices_journal_entry
  foreign key (journal_entry_id) references journal_entries (id);

alter table product_units
  add constraint fk_product_units_purchase_invoice
  foreign key (purchase_invoice_id) references invoices (id);
