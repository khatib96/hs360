-- Phase 5 M1: finance schema hardening, permissions, RLS/ACL, journal invariants,
-- document sequences, idempotency foundation, and posting RPC stubs.
-- Depends on 053_phase_5_journal_source_enum.sql for reversal journal_source values.

-- ---------------------------------------------------------------------------
-- 1B.1 Enums and tenant settings (AD-3)
-- ---------------------------------------------------------------------------
create type voucher_status as enum ('confirmed', 'cancelled');

alter table public.tenant_settings
  add column if not exists books_locked_through date;

comment on column public.tenant_settings.books_locked_through is
  'Phase 5 v1 lightweight accounting lock. Posting/cancellation RPCs reject dates on or before this value. Nullable = no lock. May be superseded by a full fiscal-period subsystem in a future phase.';

-- ---------------------------------------------------------------------------
-- 1B.2 Document sequences (AD-1, AD-5)
-- ---------------------------------------------------------------------------
create table public.document_sequences (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  sequence_key text not null,
  prefix text not null,
  next_value bigint not null default 1,
  padding int not null default 6,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, sequence_key),
  constraint chk_document_sequences_next_value check (next_value >= 1),
  constraint chk_document_sequences_padding check (padding >= 1)
);

create index idx_document_sequences_tenant on public.document_sequences (tenant_id);

create or replace function public.initialize_tenant_document_sequences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
  values
    (new.id, 'SI', 'SI', 1, 6),
    (new.id, 'PI', 'PI', 1, 6),
    (new.id, 'RV', 'RV', 1, 6),
    (new.id, 'PV', 'PV', 1, 6),
    (new.id, 'JE', 'JE', 1, 6)
  on conflict (tenant_id, sequence_key) do nothing;
  return new;
end;
$$;

create trigger trg_initialize_tenant_document_sequences
  after insert on public.tenants
  for each row execute function public.initialize_tenant_document_sequences();

insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
select t.id, v.sequence_key, v.prefix, 1, 6
from public.tenants t
cross join (
  values
    ('SI', 'SI'),
    ('PI', 'PI'),
    ('RV', 'RV'),
    ('PV', 'PV'),
    ('JE', 'JE')
) as v(sequence_key, prefix)
on conflict (tenant_id, sequence_key) do nothing;

create or replace function public.next_document_number(p_sequence_key text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_prefix text;
  v_next bigint;
  v_padding int;
  v_formatted text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  select prefix, next_value, padding
  into v_prefix, v_next, v_padding
  from public.document_sequences
  where tenant_id = v_tenant_id
    and sequence_key = p_sequence_key
  for update;

  if not found then
    raise exception 'sequence_not_found';
  end if;

  v_formatted := v_prefix || '-' || lpad(v_next::text, v_padding, '0');

  update public.document_sequences
  set
    next_value = next_value + 1,
    updated_at = now()
  where tenant_id = v_tenant_id
    and sequence_key = p_sequence_key;

  return v_formatted;
end;
$$;

comment on function public.next_document_number(text) is
  'M1: Race-safe tenant document numbering. Internal-only; posting RPCs call this helper.';

-- ---------------------------------------------------------------------------
-- 1B.3 Parent unique keys (composite FK prerequisites)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.invoices'::regclass and conname = 'ux_invoices_tenant_id_id'
  ) then
    alter table public.invoices
      add constraint ux_invoices_tenant_id_id unique (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.vouchers'::regclass and conname = 'ux_vouchers_tenant_id_id'
  ) then
    alter table public.vouchers
      add constraint ux_vouchers_tenant_id_id unique (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.journal_entries'::regclass
      and conname = 'ux_journal_entries_tenant_id_id'
  ) then
    alter table public.journal_entries
      add constraint ux_journal_entries_tenant_id_id unique (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.suppliers'::regclass and conname = 'ux_suppliers_tenant_id_id'
  ) then
    alter table public.suppliers
      add constraint ux_suppliers_tenant_id_id unique (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.warehouses'::regclass and conname = 'ux_warehouses_tenant_id_id'
  ) then
    alter table public.warehouses
      add constraint ux_warehouses_tenant_id_id unique (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.products'::regclass and conname = 'ux_products_tenant_id_id'
  ) then
    alter table public.products
      add constraint ux_products_tenant_id_id unique (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.product_units'::regclass
      and conname = 'ux_product_units_tenant_id_id'
  ) then
    alter table public.product_units
      add constraint ux_product_units_tenant_id_id unique (tenant_id, id);
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 1B.4 Invoice hardening
-- ---------------------------------------------------------------------------
alter table public.invoices
  alter column invoice_number drop not null;

alter table public.invoices
  drop constraint if exists invoices_tenant_id_invoice_number_key;

alter table public.invoices
  drop constraint if exists chk_party;

alter table public.invoices
  add column if not exists idempotency_key uuid,
  add column if not exists idempotency_payload_hash text,
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancelled_by uuid references auth.users (id),
  add column if not exists cancellation_reason text,
  add column if not exists reversal_journal_entry_id uuid,
  add column if not exists updated_at timestamptz;

alter table public.invoices
  drop constraint if exists invoices_customer_id_fkey,
  drop constraint if exists invoices_supplier_id_fkey,
  drop constraint if exists invoices_warehouse_id_fkey,
  drop constraint if exists fk_invoices_journal_entry;

alter table public.invoices
  add constraint chk_invoices_party_type check (
    (
      type in ('sales', 'sales_return', 'rental_monthly', 'opening_balance_customer')
      and customer_id is not null
      and supplier_id is null
    )
    or (
      type in ('purchase', 'purchase_return', 'opening_balance_supplier')
      and supplier_id is not null
      and customer_id is null
    )
  ),
  add constraint chk_invoices_amounts_non_negative check (
    subtotal >= 0
    and discount_amount >= 0
    and tax_amount >= 0
    and total >= 0
    and paid_amount >= 0
  ),
  add constraint chk_invoices_paid_lte_total check (paid_amount <= total),
  add constraint chk_invoices_status_invoice_number check (
    status = 'draft'
    or (
      status in ('confirmed', 'partially_paid', 'paid', 'cancelled')
      and invoice_number is not null
    )
  ),
  add constraint chk_invoices_confirmed_metadata check (
    (status in ('confirmed', 'partially_paid', 'paid') and confirmed_at is not null)
    or status not in ('confirmed', 'partially_paid', 'paid')
  ),
  add constraint chk_invoices_cancelled_metadata check (
    (status = 'cancelled' and cancelled_at is not null)
    or status <> 'cancelled'
  );

create unique index if not exists ux_invoices_tenant_idempotency_key
  on public.invoices (tenant_id, idempotency_key)
  where idempotency_key is not null;

create unique index if not exists ux_invoices_tenant_invoice_number
  on public.invoices (tenant_id, invoice_number)
  where invoice_number is not null;

alter table public.invoices
  add constraint fk_invoices_customer_tenant
    foreign key (tenant_id, customer_id)
    references public.customers (tenant_id, id),
  add constraint fk_invoices_supplier_tenant
    foreign key (tenant_id, supplier_id)
    references public.suppliers (tenant_id, id),
  add constraint fk_invoices_warehouse_tenant
    foreign key (tenant_id, warehouse_id)
    references public.warehouses (tenant_id, id),
  add constraint fk_invoices_journal_entry_tenant
    foreign key (tenant_id, journal_entry_id)
    references public.journal_entries (tenant_id, id),
  add constraint fk_invoices_reversal_journal_entry_tenant
    foreign key (tenant_id, reversal_journal_entry_id)
    references public.journal_entries (tenant_id, id);

alter table public.invoice_lines
  add column if not exists gross_amount numeric(15, 3) not null default 0,
  add column if not exists discount_amount numeric(15, 3) not null default 0,
  add column if not exists before_tax_amount numeric(15, 3) not null default 0,
  add column if not exists after_tax_amount numeric(15, 3) not null default 0;

alter table public.invoice_lines
  drop constraint if exists invoice_lines_invoice_id_fkey,
  drop constraint if exists invoice_lines_product_id_fkey,
  drop constraint if exists invoice_lines_product_unit_id_fkey;

alter table public.invoice_lines
  add constraint chk_invoice_lines_snapshot_amounts check (
    gross_amount >= 0
    and discount_amount >= 0
    and before_tax_amount >= 0
    and after_tax_amount >= 0
  ),
  add constraint fk_invoice_lines_invoice_tenant
    foreign key (tenant_id, invoice_id)
    references public.invoices (tenant_id, id)
    on delete cascade,
  add constraint fk_invoice_lines_product_tenant
    foreign key (tenant_id, product_id)
    references public.products (tenant_id, id),
  add constraint fk_invoice_lines_product_unit_tenant
    foreign key (tenant_id, product_unit_id)
    references public.product_units (tenant_id, id);

alter table public.product_units
  drop constraint if exists fk_product_units_purchase_invoice;

alter table public.product_units
  add constraint fk_product_units_purchase_invoice_tenant
    foreign key (tenant_id, purchase_invoice_id)
    references public.invoices (tenant_id, id);

-- ---------------------------------------------------------------------------
-- 1B.5 Voucher and allocation hardening
-- ---------------------------------------------------------------------------
alter table public.vouchers
  add column if not exists status public.voucher_status not null default 'confirmed',
  add column if not exists idempotency_key uuid,
  add column if not exists idempotency_payload_hash text,
  add column if not exists confirmed_at timestamptz,
  add column if not exists confirmed_by uuid references auth.users (id),
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancelled_by uuid references auth.users (id),
  add column if not exists cancellation_reason text,
  add column if not exists reversal_journal_entry_id uuid;

alter table public.vouchers
  drop constraint if exists vouchers_customer_id_fkey,
  drop constraint if exists vouchers_supplier_id_fkey,
  drop constraint if exists vouchers_employee_id_fkey,
  drop constraint if exists vouchers_account_id_fkey,
  drop constraint if exists vouchers_cash_account_id_fkey,
  drop constraint if exists fk_vouchers_journal_entry;

alter table public.vouchers
  add constraint chk_vouchers_amount_positive check (amount > 0),
  add constraint chk_vouchers_party_direction check (
    (type = 'receipt' and customer_id is not null and supplier_id is null)
    or (type = 'payment' and supplier_id is not null and customer_id is null)
  ),
  add constraint chk_vouchers_cancelled_metadata check (
    (status = 'cancelled' and cancelled_at is not null)
    or status <> 'cancelled'
  );

create unique index if not exists ux_vouchers_tenant_idempotency_key
  on public.vouchers (tenant_id, idempotency_key)
  where idempotency_key is not null;

alter table public.vouchers
  add constraint fk_vouchers_customer_tenant
    foreign key (tenant_id, customer_id)
    references public.customers (tenant_id, id),
  add constraint fk_vouchers_supplier_tenant
    foreign key (tenant_id, supplier_id)
    references public.suppliers (tenant_id, id),
  add constraint fk_vouchers_employee_fkey
    foreign key (employee_id) references public.employees (id),
  add constraint fk_vouchers_account_tenant
    foreign key (tenant_id, account_id)
    references public.chart_of_accounts (tenant_id, id),
  add constraint fk_vouchers_cash_account_tenant
    foreign key (tenant_id, cash_account_id)
    references public.chart_of_accounts (tenant_id, id),
  add constraint fk_vouchers_journal_entry_tenant
    foreign key (tenant_id, journal_entry_id)
    references public.journal_entries (tenant_id, id),
  add constraint fk_vouchers_reversal_journal_entry_tenant
    foreign key (tenant_id, reversal_journal_entry_id)
    references public.journal_entries (tenant_id, id);

alter table public.voucher_invoice_allocations
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists created_by uuid references auth.users (id),
  add column if not exists is_reversed boolean not null default false,
  add column if not exists reversed_at timestamptz,
  add column if not exists reversed_by uuid references auth.users (id);

alter table public.voucher_invoice_allocations
  drop constraint if exists voucher_invoice_allocations_voucher_id_fkey,
  drop constraint if exists voucher_invoice_allocations_invoice_id_fkey;

alter table public.voucher_invoice_allocations
  add constraint chk_voucher_allocations_amount_positive check (allocated_amount > 0),
  add constraint ux_voucher_allocations_tenant_voucher_invoice
    unique (tenant_id, voucher_id, invoice_id),
  add constraint fk_voucher_allocations_voucher_tenant
    foreign key (tenant_id, voucher_id)
    references public.vouchers (tenant_id, id)
    on delete cascade,
  add constraint fk_voucher_allocations_invoice_tenant
    foreign key (tenant_id, invoice_id)
    references public.invoices (tenant_id, id);

-- ---------------------------------------------------------------------------
-- 1B.6 Journal hardening
-- ---------------------------------------------------------------------------
alter table public.journal_entries
  add column if not exists idempotency_key uuid,
  add column if not exists idempotency_payload_hash text,
  add column if not exists reversal_of_entry_id uuid,
  add column if not exists reversed_by_entry_id uuid;

alter table public.journal_entries
  drop constraint if exists journal_entries_reversal_of_entry_id_fkey,
  drop constraint if exists journal_entries_reversed_by_entry_id_fkey;

alter table public.journal_entries
  add constraint fk_journal_entries_reversal_of_tenant
    foreign key (tenant_id, reversal_of_entry_id)
    references public.journal_entries (tenant_id, id),
  add constraint fk_journal_entries_reversed_by_tenant
    foreign key (tenant_id, reversed_by_entry_id)
    references public.journal_entries (tenant_id, id),
  add constraint chk_journal_entries_posted_metadata check (
    (is_posted = true and posted_at is not null and posted_by is not null)
    or coalesce(is_posted, false) = false
  );

create unique index if not exists ux_journal_entries_tenant_idempotency_key
  on public.journal_entries (tenant_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists idx_journal_entries_tenant_source
  on public.journal_entries (tenant_id, source, source_id);

create index if not exists idx_journal_entries_tenant_date
  on public.journal_entries (tenant_id, date);

alter table public.journal_lines
  drop constraint if exists journal_lines_journal_entry_id_fkey,
  drop constraint if exists journal_lines_account_id_fkey;

alter table public.journal_lines
  add constraint fk_journal_lines_entry_tenant
    foreign key (tenant_id, journal_entry_id)
    references public.journal_entries (tenant_id, id)
    on delete cascade,
  add constraint fk_journal_lines_account_tenant
    foreign key (tenant_id, account_id)
    references public.chart_of_accounts (tenant_id, id);

create or replace function public.validate_journal_entry_posting()
returns trigger
language plpgsql
as $$
declare
  v_line_count int;
  v_bad_side_count int;
  v_bad_tenant_count int;
  v_bad_account_tenant_count int;
begin
  if tg_op = 'UPDATE'
    and coalesce(old.is_posted, false) = false
    and coalesce(new.is_posted, false) = true
  then
    select count(*)
    into v_line_count
    from public.journal_lines jl
    where jl.journal_entry_id = new.id;

    if v_line_count < 2 then
      raise exception 'journal_entry_requires_two_lines';
    end if;

    select count(*)
    into v_bad_side_count
    from public.journal_lines jl
    where jl.journal_entry_id = new.id
      and not (
        (jl.debit > 0 and jl.credit = 0)
        or (jl.credit > 0 and jl.debit = 0)
      );

    if v_bad_side_count > 0 then
      raise exception 'journal_line_invalid_side';
    end if;

    select count(*)
    into v_bad_tenant_count
    from public.journal_lines jl
    where jl.journal_entry_id = new.id
      and jl.tenant_id is distinct from new.tenant_id;

    if v_bad_tenant_count > 0 then
      raise exception 'journal_line_tenant_mismatch';
    end if;

    select count(*)
    into v_bad_account_tenant_count
    from public.journal_lines jl
    join public.chart_of_accounts coa on coa.id = jl.account_id
    where jl.journal_entry_id = new.id
      and coa.tenant_id is distinct from new.tenant_id;

    if v_bad_account_tenant_count > 0 then
      raise exception 'journal_line_account_tenant_mismatch';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_validate_journal_entry_posting
  before update on public.journal_entries
  for each row execute function public.validate_journal_entry_posting();

create or replace function public.enforce_posted_journal_entry_immutability()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if coalesce(old.is_posted, false) = true then
      raise exception 'posted_journal_entry_immutable';
    end if;
    if coalesce(old.is_posted, false) = true and coalesce(new.is_posted, false) = false then
      raise exception 'posted_journal_entry_immutable';
    end if;
  elsif tg_op = 'DELETE' then
    if coalesce(old.is_posted, false) = true then
      raise exception 'posted_journal_entry_immutable';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger trg_enforce_posted_journal_entry_immutability
  before update or delete on public.journal_entries
  for each row execute function public.enforce_posted_journal_entry_immutability();

create or replace function public.enforce_posted_journal_line_immutability()
returns trigger
language plpgsql
as $$
declare
  v_is_posted boolean;
  v_entry_id uuid;
begin
  v_entry_id := coalesce(new.journal_entry_id, old.journal_entry_id);

  select je.is_posted
  into v_is_posted
  from public.journal_entries je
  where je.id = v_entry_id;

  if coalesce(v_is_posted, false) = true then
    raise exception 'posted_journal_line_immutable';
  end if;

  return coalesce(new, old);
end;
$$;

create trigger trg_enforce_posted_journal_line_immutability
  before update or delete on public.journal_lines
  for each row execute function public.enforce_posted_journal_line_immutability();

-- ---------------------------------------------------------------------------
-- 1B.2b Idempotency helper (AD-2)
-- ---------------------------------------------------------------------------
create or replace function public.resolve_finance_idempotency(
  p_table regclass,
  p_idempotency_key uuid,
  p_payload_hash text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_existing_id uuid;
  v_existing_hash text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_idempotency_key is null then
    return null;
  end if;

  if p_table = 'public.invoices'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.invoices
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.vouchers'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.vouchers
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.journal_entries'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.journal_entries
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  else
    raise exception 'validation_failed';
  end if;

  if v_existing_id is null then
    return null;
  end if;

  if v_existing_hash is distinct from p_payload_hash then
    raise exception 'idempotency_payload_mismatch';
  end if;

  return v_existing_id;
end;
$$;

comment on function public.resolve_finance_idempotency(regclass, uuid, text) is
  'M1: Phase 5 idempotency resolver. Same tenant+key+hash returns existing id; same key different hash raises idempotency_payload_mismatch. Canonical payload hash defined by posting RPCs in M5-M7.';

-- ---------------------------------------------------------------------------
-- 1B.7 Permissions catalog
-- ---------------------------------------------------------------------------
insert into public.permissions (
  id, module, action, scope, field_name, label_ar, label_en, is_sensitive, category, sort_order
)
values
  ('invoices.create_sales', 'invoices', 'create_sales', 'action', null, 'invoices.create_sales', 'Create sales invoices', false, 'finance', 94),
  ('invoices.create_purchase', 'invoices', 'create_purchase', 'action', null, 'invoices.create_purchase', 'Create purchase invoices', false, 'finance', 95),
  ('invoices.view_sales', 'invoices', 'view_sales', 'action', null, 'invoices.view_sales', 'View sales invoices', false, 'finance', 96),
  ('invoices.view_purchase', 'invoices', 'view_purchase', 'action', null, 'invoices.view_purchase', 'View purchase invoices', true, 'finance', 97),
  ('invoices.edit_draft', 'invoices', 'edit_draft', 'action', null, 'invoices.edit_draft', 'Edit draft invoices', false, 'finance', 98),
  ('invoices.print', 'invoices', 'print', 'action', null, 'invoices.print', 'Print invoices', false, 'finance', 99),
  ('invoices.override_min_price', 'invoices', 'override_min_price', 'action', null, 'invoices.override_min_price', 'Override minimum sale price', true, 'finance', 100),
  ('vouchers.print', 'vouchers', 'print', 'action', null, 'vouchers.print', 'Print vouchers', false, 'finance', 205),
  ('cash_bank.view', 'accounting', 'view', 'action', null, 'cash_bank.view', 'View cash and bank activity', false, 'accounting', 101),
  ('suppliers.view_ledger', 'purchasing', 'view_ledger', 'action', null, 'suppliers.view_ledger', 'View supplier ledger', true, 'purchasing', 184),
  ('product_units.correct_serial', 'inventory', 'correct_serial', 'action', null, 'product_units.correct_serial', 'Correct product unit serial', true, 'inventory', 144),
  ('product_units.reconcile_serials', 'inventory', 'reconcile_serials', 'action', null, 'product_units.reconcile_serials', 'Reconcile product unit serials', true, 'inventory', 145),
  ('product_units.print_label', 'inventory', 'print_label', 'action', null, 'product_units.print_label', 'Print product unit labels', false, 'inventory', 146),
  ('settings.templates.view', 'settings', 'view', 'action', null, 'settings.templates.view', 'View document templates', false, 'settings', 177),
  ('settings.templates.edit', 'settings', 'edit', 'action', null, 'settings.templates.edit', 'Edit document templates', true, 'settings', 178),
  ('settings.tax.view', 'settings', 'view', 'action', null, 'settings.tax.view', 'View tax settings', false, 'settings', 179),
  ('settings.tax.edit', 'settings', 'edit', 'action', null, 'settings.tax.edit', 'Edit tax settings', true, 'settings', 180)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 1B.8 RLS: RPC-only finance writes
-- ---------------------------------------------------------------------------
drop policy if exists invoices_insert on public.invoices;
drop policy if exists invoices_update on public.invoices;
drop policy if exists invoices_delete on public.invoices;
drop policy if exists invoice_lines_insert on public.invoice_lines;
drop policy if exists invoice_lines_update on public.invoice_lines;
drop policy if exists vouchers_insert on public.vouchers;
drop policy if exists vouchers_update on public.vouchers;
drop policy if exists vouchers_delete on public.vouchers;
drop policy if exists voucher_invoice_allocations_delete on public.voucher_invoice_allocations;

drop policy if exists invoices_select on public.invoices;

create policy invoices_select on public.invoices
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      (
        type in ('sales', 'sales_return', 'rental_monthly', 'opening_balance_customer')
        and (
          public.user_has_permission('invoices.view_sales')
          or public.user_has_permission('invoices.view')
        )
      )
      or (
        type in ('purchase', 'purchase_return', 'opening_balance_supplier')
        and (
          public.user_has_permission('invoices.view_purchase')
          or public.user_has_permission('invoices.view')
        )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 1B.9 Write-gate triggers (AD-6)
-- ---------------------------------------------------------------------------
create or replace function public.allow_finance_write()
returns void
language sql
security definer
set search_path = public
as $$
  select set_config('hs360.finance_write', '1', true);
$$;

comment on function public.allow_finance_write() is
  'M1: Session gate for trusted finance RPC writes. Call at start of posting RPC transactions.';

create or replace function public.enforce_finance_direct_write_gate()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('postgres', 'supabase_admin') then
    return coalesce(new, old);
  end if;

  if coalesce(current_setting('hs360.finance_write', true), '') = '1' then
    return coalesce(new, old);
  end if;

  raise exception 'direct_write_forbidden';
end;
$$;

create trigger trg_finance_direct_write_gate_invoices
  before insert or update or delete on public.invoices
  for each row execute function public.enforce_finance_direct_write_gate();

create trigger trg_finance_direct_write_gate_invoice_lines
  before insert or update or delete on public.invoice_lines
  for each row execute function public.enforce_finance_direct_write_gate();

create trigger trg_finance_direct_write_gate_vouchers
  before insert or update or delete on public.vouchers
  for each row execute function public.enforce_finance_direct_write_gate();

create trigger trg_finance_direct_write_gate_voucher_allocations
  before insert or update or delete on public.voucher_invoice_allocations
  for each row execute function public.enforce_finance_direct_write_gate();

-- ---------------------------------------------------------------------------
-- Internal test helper (write-path smoke; postgres-only)
-- ---------------------------------------------------------------------------
create or replace function public._test_finance_write_smoke()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_customer_id uuid;
  v_invoice_id uuid;
begin
  perform public.allow_finance_write();

  select id into v_tenant_id from public.tenants order by created_at limit 1;
  if v_tenant_id is null then
    raise exception 'validation_failed';
  end if;

  select id into v_customer_id
  from public.customers
  where tenant_id = v_tenant_id
  limit 1;

  if v_customer_id is null then
    raise exception 'validation_failed';
  end if;

  insert into public.invoices (
    tenant_id, type, status, customer_id, date, subtotal, total
  )
  values (
    v_tenant_id, 'sales', 'draft', v_customer_id, current_date, 0, 0
  )
  returning id into v_invoice_id;

  return v_invoice_id;
end;
$$;

comment on function public._test_finance_write_smoke() is
  'M1 internal: verifies finance write-gate allows SECURITY DEFINER writes. Not granted to authenticated.';

-- ---------------------------------------------------------------------------
-- 1B.10 RPC skeletons
-- ---------------------------------------------------------------------------
create or replace function public.save_invoice_draft(p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('invoices.edit_draft') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

create or replace function public.discard_invoice_draft(p_invoice_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('invoices.edit_draft') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

create or replace function public.record_purchase_invoice(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('invoices.create_purchase') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

create or replace function public.record_sales_invoice(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('invoices.create_sales') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

create or replace function public.cancel_invoice(
  p_invoice_id uuid,
  p_reason text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('invoices.cancel') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

create or replace function public.record_receipt_voucher(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('vouchers.create_receipt') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

create or replace function public.record_payment_voucher(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('vouchers.create_payment') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

create or replace function public.cancel_voucher(
  p_voucher_id uuid,
  p_reason text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('vouchers.cancel') then
    raise exception 'permission_denied';
  end if;
  raise exception 'feature_not_implemented';
end;
$$;

-- ---------------------------------------------------------------------------
-- ACL hygiene
-- ---------------------------------------------------------------------------
revoke all on function public.next_document_number(text)
  from public, anon, authenticated;
revoke all on function public.resolve_finance_idempotency(regclass, uuid, text)
  from public, anon, authenticated;
revoke all on function public.allow_finance_write()
  from public, anon, authenticated;
revoke all on function public._test_finance_write_smoke()
  from public, anon, authenticated;

revoke all on function public.save_invoice_draft(jsonb)
  from public, anon, authenticated;
revoke all on function public.discard_invoice_draft(uuid)
  from public, anon, authenticated;
revoke all on function public.record_purchase_invoice(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.record_sales_invoice(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.cancel_invoice(uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.record_receipt_voucher(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.record_payment_voucher(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.cancel_voucher(uuid, text, uuid)
  from public, anon, authenticated;

grant execute on function public.save_invoice_draft(jsonb) to authenticated;
grant execute on function public.discard_invoice_draft(uuid) to authenticated;
grant execute on function public.record_purchase_invoice(jsonb, uuid) to authenticated;
grant execute on function public.record_sales_invoice(jsonb, uuid) to authenticated;
grant execute on function public.cancel_invoice(uuid, text, uuid) to authenticated;
grant execute on function public.record_receipt_voucher(jsonb, uuid) to authenticated;
grant execute on function public.record_payment_voucher(jsonb, uuid) to authenticated;
grant execute on function public.cancel_voucher(uuid, text, uuid) to authenticated;

revoke insert, update, delete on public.invoices from authenticated;
revoke insert, update, delete on public.invoice_lines from authenticated;
revoke insert, update, delete on public.vouchers from authenticated;
revoke insert, update, delete on public.voucher_invoice_allocations from authenticated;
