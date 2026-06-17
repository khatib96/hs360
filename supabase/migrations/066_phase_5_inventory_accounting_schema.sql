-- Phase 5 M4.5: inventory financial document schema, accounts, permissions, RLS.
-- Depends on 065_phase_5_inventory_journal_source_enum.sql.

-- ---------------------------------------------------------------------------
-- Document type / status enums
-- ---------------------------------------------------------------------------
create type public.inventory_document_type as enum (
  'opening_stock',
  'stock_in',
  'stock_out',
  'stock_count'
);

create type public.inventory_document_status as enum (
  'confirmed',
  'cancelled'
);

create type public.inventory_reason_direction as enum (
  'stock_in',
  'stock_out'
);

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table public.inventory_documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  document_type public.inventory_document_type not null,
  status public.inventory_document_status not null default 'confirmed',
  document_number text not null,
  document_date date not null,
  warehouse_id uuid not null,
  reason_code text,
  gain_reason_code text,
  loss_reason_code text,
  notes text not null,
  import_key text,
  idempotency_key uuid,
  idempotency_payload_hash text,
  journal_entry_id uuid,
  reversal_journal_entry_id uuid,
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users (id),
  cancellation_reason text,
  confirmed_at timestamptz not null default now(),
  confirmed_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  constraint ux_inventory_documents_tenant_id_id unique (tenant_id, id),
  constraint fk_inventory_documents_warehouse
    foreign key (tenant_id, warehouse_id)
    references public.warehouses (tenant_id, id),
  constraint fk_inventory_documents_journal_entry
    foreign key (tenant_id, journal_entry_id)
    references public.journal_entries (tenant_id, id),
  constraint fk_inventory_documents_reversal_journal_entry
    foreign key (tenant_id, reversal_journal_entry_id)
    references public.journal_entries (tenant_id, id),
  constraint chk_inventory_documents_cancelled_metadata check (
    (status = 'cancelled' and cancelled_at is not null and cancellation_reason is not null)
    or status <> 'cancelled'
  )
);

create unique index ux_inventory_documents_tenant_idempotency_key
  on public.inventory_documents (tenant_id, idempotency_key)
  where idempotency_key is not null;

create unique index ux_inventory_documents_tenant_document_number
  on public.inventory_documents (tenant_id, document_number);

create unique index ux_inventory_documents_tenant_import_key
  on public.inventory_documents (tenant_id, import_key)
  where import_key is not null;

create index idx_inventory_documents_tenant_date
  on public.inventory_documents (tenant_id, document_date desc);

create index idx_inventory_documents_tenant_type
  on public.inventory_documents (tenant_id, document_type);

create table public.inventory_document_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  document_id uuid not null,
  product_id uuid not null,
  system_qty numeric(15, 3),
  input_qty numeric(15, 3) not null,
  delta_qty numeric(15, 3) not null,
  unit_cost_snapshot numeric(15, 3) not null default 0,
  total_value numeric(15, 3) not null default 0,
  reason_code text,
  counter_account_id uuid not null,
  product_unit_ids uuid[],
  line_order int not null,
  created_at timestamptz not null default now(),
  constraint fk_inventory_document_lines_document
    foreign key (tenant_id, document_id)
    references public.inventory_documents (tenant_id, id)
    on delete cascade,
  constraint fk_inventory_document_lines_product
    foreign key (tenant_id, product_id)
    references public.products (tenant_id, id),
  constraint fk_inventory_document_lines_counter_account
    foreign key (tenant_id, counter_account_id)
    references public.chart_of_accounts (tenant_id, id),
  constraint ux_inventory_document_lines_document_order
    unique (tenant_id, document_id, line_order)
);

create index idx_inventory_document_lines_document
  on public.inventory_document_lines (tenant_id, document_id);

create table public.inventory_adjustment_reasons (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  code text not null,
  name_ar text not null,
  name_en text not null,
  direction public.inventory_reason_direction not null,
  account_id uuid not null,
  requires_cost boolean not null default false,
  allows_wac_fallback boolean not null default false,
  is_system boolean not null default true,
  is_active boolean not null default true,
  allowed_document_types text[] not null,
  created_at timestamptz not null default now(),
  constraint ux_inventory_adjustment_reasons_tenant_code unique (tenant_id, code),
  constraint fk_inventory_adjustment_reasons_account
    foreign key (tenant_id, account_id)
    references public.chart_of_accounts (tenant_id, id)
);

create index idx_inventory_adjustment_reasons_tenant_direction
  on public.inventory_adjustment_reasons (tenant_id, direction)
  where is_active = true;

-- ---------------------------------------------------------------------------
-- Document sequences (OS, STI, STO, SC)
-- ---------------------------------------------------------------------------
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
    (new.id, 'SR', 'SR', 1, 6),
    (new.id, 'PR', 'PR', 1, 6),
    (new.id, 'RV', 'RV', 1, 6),
    (new.id, 'PV', 'PV', 1, 6),
    (new.id, 'JE', 'JE', 1, 6),
    (new.id, 'SKU', 'SKU', 1, 6),
    (new.id, 'OS', 'OS', 1, 6),
    (new.id, 'STI', 'STI', 1, 6),
    (new.id, 'STO', 'STO', 1, 6),
    (new.id, 'SC', 'SC', 1, 6)
  on conflict (tenant_id, sequence_key) do nothing;
  return new;
end;
$$;

insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
select t.id, v.sequence_key, v.prefix, 1, 6
from public.tenants t
cross join (
  values
    ('OS', 'OS'),
    ('STI', 'STI'),
    ('STO', 'STO'),
    ('SC', 'SC')
) as v(sequence_key, prefix)
on conflict (tenant_id, sequence_key) do nothing;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
insert into public.permissions (
  id, module, action, scope, field_name, label_ar, label_en, is_sensitive, category, sort_order
)
values
  (
    'inventory_documents.view', 'inventory_documents', 'view', 'action', null,
    'inventory_documents.view', 'View inventory financial documents', false, 'inventory', 147
  ),
  (
    'inventory_documents.create_opening', 'inventory_documents', 'create_opening', 'action', null,
    'inventory_documents.create_opening', 'Record opening stock', true, 'inventory', 148
  ),
  (
    'inventory_documents.create_adjustment', 'inventory_documents', 'create_adjustment', 'action', null,
    'inventory_documents.create_adjustment', 'Record financial stock adjustments', false, 'inventory', 149
  ),
  (
    'inventory_documents.create_stock_count', 'inventory_documents', 'create_stock_count', 'action', null,
    'inventory_documents.create_stock_count', 'Record stock counts', false, 'inventory', 150
  ),
  (
    'inventory_documents.cancel', 'inventory_documents', 'cancel', 'action', null,
    'inventory_documents.cancel', 'Cancel inventory financial documents', true, 'inventory', 151
  ),
  (
    'inventory_adjustment_reasons.manage', 'inventory_adjustment_reasons', 'manage', 'action', null,
    'inventory_adjustment_reasons.manage', 'Manage inventory adjustment reasons', true, 'inventory', 152
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Protected inventory posting accounts (3101, 3102, 3201, 4102, 5152, 5901)
-- ---------------------------------------------------------------------------
alter table public.chart_of_accounts disable trigger trg_enforce_chart_account_protection;

insert into public.chart_of_accounts (
  tenant_id, code, name_ar, name_en, type, is_system, is_active
)
select
  t.id,
  v.code,
  v.name_ar,
  v.name_en,
  v.type::public.account_type,
  true,
  true
from public.tenants t
cross join (
  values
    ('3101', 'Opening Balance Equity', 'Opening Balance Equity', 'equity'),
    ('3102', 'Owner Capital', 'Owner''s Capital', 'equity'),
    ('3201', 'Owner Drawings', 'Owner''s Drawings', 'equity'),
    ('4102', 'Inventory Gain', 'Inventory Gain', 'income'),
    ('5152', 'Inventory Loss', 'Inventory Loss / Adjustment', 'expense'),
    ('5901', 'Internal Consumption', 'Internal Consumption Expense', 'expense')
) as v(code, name_ar, name_en, type)
on conflict (tenant_id, code) do nothing;

update public.chart_of_accounts leaf
set parent_id = root.id
from public.chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '3000'
  and leaf.code in ('3101', '3102', '3201')
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

update public.chart_of_accounts leaf
set parent_id = root.id
from public.chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '4000'
  and leaf.code = '4102'
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

update public.chart_of_accounts leaf
set parent_id = root.id
from public.chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '5000'
  and leaf.code in ('5152', '5901')
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

alter table public.chart_of_accounts enable trigger trg_enforce_chart_account_protection;

-- ---------------------------------------------------------------------------
-- Idempotency resolver extension
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
  elsif p_table = 'public.invoice_credit_allocations'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.invoice_credit_allocations
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.inventory_documents'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.inventory_documents
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
  'M1/M4.5: Phase 5 idempotency resolver including inventory_documents.';

-- ---------------------------------------------------------------------------
-- Finance write gates on inventory document tables
-- ---------------------------------------------------------------------------
create trigger trg_finance_direct_write_gate_inventory_documents
  before insert or update or delete on public.inventory_documents
  for each row execute function public.enforce_finance_direct_write_gate();

create trigger trg_finance_direct_write_gate_inventory_document_lines
  before insert or update or delete on public.inventory_document_lines
  for each row execute function public.enforce_finance_direct_write_gate();

create trigger trg_finance_direct_write_gate_inventory_adjustment_reasons
  before insert or update or delete on public.inventory_adjustment_reasons
  for each row execute function public.enforce_finance_direct_write_gate();

-- ---------------------------------------------------------------------------
-- RLS: SELECT only via permission; no client writes
-- ---------------------------------------------------------------------------
alter table public.inventory_documents enable row level security;
alter table public.inventory_document_lines enable row level security;
alter table public.inventory_adjustment_reasons enable row level security;

create policy inventory_documents_select on public.inventory_documents
  for select using (
    tenant_id = public.current_tenant_id()
    and public.user_has_permission('inventory_documents.view')
  );

create policy inventory_document_lines_select on public.inventory_document_lines
  for select using (
    tenant_id = public.current_tenant_id()
    and public.user_has_permission('inventory_documents.view')
  );

create policy inventory_adjustment_reasons_select on public.inventory_adjustment_reasons
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      public.user_has_permission('inventory_documents.view')
      or public.user_has_permission('inventory_documents.create_adjustment')
      or public.user_has_permission('inventory_documents.create_stock_count')
    )
  );

revoke insert, update, delete on public.inventory_documents from authenticated;
revoke insert, update, delete on public.inventory_document_lines from authenticated;
revoke insert, update, delete on public.inventory_adjustment_reasons from authenticated;

grant select on public.inventory_documents to authenticated;
grant select on public.inventory_document_lines to authenticated;
grant select on public.inventory_adjustment_reasons to authenticated;
