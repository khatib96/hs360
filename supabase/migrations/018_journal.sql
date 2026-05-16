-- Phase 1B: journal entries and lines (section 14).

create table journal_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  entry_number text not null,
  date date not null,
  source journal_source not null,
  source_id uuid,
  description_ar text,
  description_en text,
  is_posted boolean default false,
  posted_at timestamptz,
  posted_by uuid references auth.users (id),
  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  unique (tenant_id, entry_number)
);

create table journal_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  journal_entry_id uuid not null references journal_entries (id) on delete cascade,
  account_id uuid not null references chart_of_accounts (id),
  debit numeric(15, 3) not null default 0,
  credit numeric(15, 3) not null default 0,
  description text,
  line_order int not null,
  constraint chk_dr_cr check (
    (debit > 0 and credit = 0) or (credit > 0 and debit = 0)
  )
);

create index idx_journal_tenant on journal_entries (tenant_id);
create index idx_journal_date on journal_entries (date);
create index idx_jlines_entry on journal_lines (journal_entry_id);
