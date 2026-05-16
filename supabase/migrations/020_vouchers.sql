-- Phase 1B: vouchers and allocations (section 13). visit_id FK deferred to 022.

create table vouchers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  voucher_number text not null,
  type voucher_type not null,
  date date not null,

  amount numeric(15, 3) not null,
  payment_method payment_method not null,
  reference_no text,

  customer_id uuid references customers (id),
  supplier_id uuid references suppliers (id),
  employee_id uuid references employees (id),

  account_id uuid not null references chart_of_accounts (id),
  cash_account_id uuid not null references chart_of_accounts (id),

  notes text,
  collected_by uuid references auth.users (id),
  visit_id uuid,

  journal_entry_id uuid,
  pdf_url text,
  sent_at timestamptz,
  sent_channels text[],

  created_at timestamptz default now(),
  created_by uuid references auth.users (id),

  unique (tenant_id, voucher_number)
);

create index idx_vouchers_tenant on vouchers (tenant_id);
create index idx_vouchers_customer on vouchers (customer_id);
create index idx_vouchers_date on vouchers (date);

create table voucher_invoice_allocations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  voucher_id uuid not null references vouchers (id) on delete cascade,
  invoice_id uuid not null references invoices (id),
  allocated_amount numeric(15, 3) not null
);

create index idx_vallocs_voucher on voucher_invoice_allocations (voucher_id);
create index idx_vallocs_invoice on voucher_invoice_allocations (invoice_id);

alter table vouchers
  add constraint fk_vouchers_journal_entry
  foreign key (journal_entry_id) references journal_entries (id);

alter table salaries
  add constraint fk_salaries_voucher
  foreign key (voucher_id) references vouchers (id);

alter table advances
  add constraint fk_advances_voucher
  foreign key (voucher_id) references vouchers (id);
