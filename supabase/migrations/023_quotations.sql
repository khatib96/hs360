-- Phase 1B: quotations and quotation lines (section 15).

create table quotations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  quotation_number text not null,
  customer_id uuid not null references customers (id),
  date date not null,
  valid_until date,
  subtotal numeric(15, 3) not null default 0,
  discount_amount numeric(15, 3) default 0,
  total numeric(15, 3) not null default 0,
  status quotation_status default 'draft',
  notes text,
  converted_to_invoice_id uuid references invoices (id),
  converted_to_contract_id uuid references contracts (id),
  pdf_url text,
  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  unique (tenant_id, quotation_number)
);

create table quotation_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  quotation_id uuid not null references quotations (id) on delete cascade,
  product_id uuid not null references products (id),
  description text,
  qty numeric(15, 3) not null,
  unit_price numeric(15, 3) not null,
  line_total numeric(15, 3) not null,
  line_order int not null
);
