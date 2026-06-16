-- Phase 5 M7.5: sales/purchase return and credit engine.
-- Depends on 063_phase_5_return_journal_source_enum.sql (journal_source values).
-- Reuses M5/M6/M7 idempotency, WAC, cancellation, and voucher patterns.

create extension if not exists pgcrypto;

-- ===========================================================================
-- Section 1: Schema
-- ===========================================================================

alter table public.invoices
  add column if not exists original_invoice_id uuid,
  add column if not exists return_reason text;

alter table public.invoice_lines
  add column if not exists original_invoice_line_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.invoice_lines'::regclass
      and conname = 'ux_invoice_lines_tenant_id_id'
  ) then
    alter table public.invoice_lines
      add constraint ux_invoice_lines_tenant_id_id unique (tenant_id, id);
  end if;
end $$;

alter table public.invoices
  drop constraint if exists chk_invoices_return_linkage;

alter table public.invoices
  add constraint chk_invoices_return_linkage check (
    (
      type in ('sales_return', 'purchase_return')
      and original_invoice_id is not null
      and return_reason is not null
      and btrim(return_reason) <> ''
    )
    or (
      type not in ('sales_return', 'purchase_return')
      and original_invoice_id is null
      and return_reason is null
    )
  );

alter table public.invoices
  drop constraint if exists fk_invoices_original_invoice_tenant;

alter table public.invoices
  add constraint fk_invoices_original_invoice_tenant
    foreign key (tenant_id, original_invoice_id)
    references public.invoices (tenant_id, id);

alter table public.invoice_lines
  drop constraint if exists fk_invoice_lines_original_line_tenant;

alter table public.invoice_lines
  add constraint fk_invoice_lines_original_line_tenant
    foreign key (tenant_id, original_invoice_line_id)
    references public.invoice_lines (tenant_id, id);

do $$
begin
  if not exists (select 1 from pg_type where typname = 'invoice_credit_allocation_kind') then
    create type public.invoice_credit_allocation_kind as enum (
      'original_settlement',
      'future_invoice',
      'cash_refund'
    );
  end if;
end $$;

create table if not exists public.invoice_credit_allocations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  source_invoice_id uuid not null,
  target_invoice_id uuid,
  voucher_id uuid,
  allocation_kind public.invoice_credit_allocation_kind not null,
  allocated_amount numeric(15, 3) not null check (allocated_amount > 0),
  idempotency_key uuid,
  idempotency_payload_hash text,
  is_reversed boolean not null default false,
  reversed_at timestamptz,
  reversed_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  constraint ux_invoice_credit_allocations_tenant_id unique (tenant_id, id),
  constraint fk_invoice_credit_alloc_source_tenant
    foreign key (tenant_id, source_invoice_id)
    references public.invoices (tenant_id, id),
  constraint fk_invoice_credit_alloc_target_tenant
    foreign key (tenant_id, target_invoice_id)
    references public.invoices (tenant_id, id),
  constraint fk_invoice_credit_alloc_voucher_tenant
    foreign key (tenant_id, voucher_id)
    references public.vouchers (tenant_id, id),
  constraint chk_invoice_credit_alloc_shape check (
    (
      allocation_kind in ('original_settlement', 'future_invoice')
      and target_invoice_id is not null
      and voucher_id is null
    )
    or (
      allocation_kind = 'cash_refund'
      and target_invoice_id is null
      and voucher_id is not null
    )
  )
);

drop index if exists public.ux_invoice_credit_alloc_tenant_idempotency_key;
create unique index ux_invoice_credit_alloc_tenant_idempotency_key
  on public.invoice_credit_allocations (tenant_id, idempotency_key)
  where idempotency_key is not null;

drop index if exists public.uq_credit_alloc_original_settlement;
create unique index uq_credit_alloc_original_settlement
  on public.invoice_credit_allocations (tenant_id, source_invoice_id, target_invoice_id)
  where is_reversed = false and allocation_kind = 'original_settlement';

drop index if exists public.uq_credit_alloc_future_invoice;
create unique index uq_credit_alloc_future_invoice
  on public.invoice_credit_allocations (tenant_id, source_invoice_id, target_invoice_id)
  where is_reversed = false and allocation_kind = 'future_invoice';

drop index if exists public.uq_credit_alloc_cash_refund;
create unique index uq_credit_alloc_cash_refund
  on public.invoice_credit_allocations (tenant_id, source_invoice_id, voucher_id)
  where is_reversed = false and allocation_kind = 'cash_refund';

create index if not exists idx_invoice_credit_alloc_source
  on public.invoice_credit_allocations (tenant_id, source_invoice_id)
  where is_reversed = false;

create index if not exists idx_invoice_credit_alloc_target
  on public.invoice_credit_allocations (tenant_id, target_invoice_id)
  where is_reversed = false;

create or replace function public.enforce_return_line_linkage()
returns trigger
language plpgsql
as $$
declare
  v_invoice_type public.invoice_type;
begin
  select i.type
  into v_invoice_type
  from public.invoices i
  where i.id = new.invoice_id
    and i.tenant_id = new.tenant_id;

  if v_invoice_type in ('sales_return', 'purchase_return') then
    if new.original_invoice_line_id is null then
      raise exception 'validation_failed';
    end if;
  elsif new.original_invoice_line_id is not null then
    raise exception 'validation_failed';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_return_line_linkage on public.invoice_lines;
create trigger trg_enforce_return_line_linkage
  before insert or update on public.invoice_lines
  for each row execute function public.enforce_return_line_linkage();

drop trigger if exists trg_finance_direct_write_gate_invoice_credit_allocations
  on public.invoice_credit_allocations;
create trigger trg_finance_direct_write_gate_invoice_credit_allocations
  before insert or update or delete on public.invoice_credit_allocations
  for each row execute function public.enforce_finance_direct_write_gate();

alter table public.invoice_credit_allocations enable row level security;

drop policy if exists invoice_credit_allocations_select on public.invoice_credit_allocations;
create policy invoice_credit_allocations_select on public.invoice_credit_allocations
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      public.user_has_permission('invoices.view_returns')
      or public.user_has_permission('invoices.view_sales')
      or public.user_has_permission('invoices.view_purchase')
      or public.user_has_permission('invoices.view')
    )
  );

revoke insert, update, delete on public.invoice_credit_allocations from authenticated;

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
  'M1/M7.5: Phase 5 idempotency resolver. invoice_credit_allocations branch returns allocation.id.';

-- ===========================================================================
-- Section 2: Sequences, permissions, COA
-- ===========================================================================

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
    (new.id, 'SKU', 'SKU', 1, 6)
  on conflict (tenant_id, sequence_key) do nothing;
  return new;
end;
$$;

insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
select t.id, v.sequence_key, v.prefix, 1, 6
from public.tenants t
cross join (
  values
    ('SR', 'SR'),
    ('PR', 'PR')
) as v(sequence_key, prefix)
on conflict (tenant_id, sequence_key) do nothing;

insert into public.permissions (
  id, module, action, scope, field_name, label_ar, label_en, is_sensitive, category, sort_order
)
values
  (
    'invoices.create_sales_return', 'invoices', 'create_sales_return', 'action', null,
    'invoices.create_sales_return', 'Create sales returns', false, 'finance', 101
  ),
  (
    'invoices.create_purchase_return', 'invoices', 'create_purchase_return', 'action', null,
    'invoices.create_purchase_return', 'Create purchase returns', false, 'finance', 102
  ),
  (
    'invoices.view_returns', 'invoices', 'view_returns', 'action', null,
    'invoices.view_returns', 'View return invoices', false, 'finance', 103
  )
on conflict (id) do nothing;

drop policy if exists invoices_select on public.invoices;
create policy invoices_select on public.invoices
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      (
        type in ('sales', 'sales_return', 'rental_monthly', 'opening_balance_customer')
        and (
          public.user_has_permission('invoices.view_sales')
          or public.user_has_permission('invoices.view_returns')
          or public.user_has_permission('invoices.view')
        )
      )
      or (
        type in ('purchase', 'purchase_return', 'opening_balance_supplier')
        and (
          public.user_has_permission('invoices.view_purchase')
          or public.user_has_permission('invoices.view_returns')
          or public.user_has_permission('invoices.view')
        )
      )
    )
  );

alter table public.chart_of_accounts disable trigger trg_enforce_chart_account_protection;

insert into public.chart_of_accounts (
  id, tenant_id, code, name_ar, name_en, type, is_system, is_active
)
select
  gen_random_uuid(),
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
    (
      '4102',
      U&'\0645\0631\062A\062C\0639\0627\062A \0627\0644\0645\0628\064A\0639\0627\062A' UESCAPE '\',
      'Sales returns',
      'income'
    ),
    (
      '2150',
      U&'\0627\0626\062A\0645\0627\0646\0627\062A \0627\0644\0639\0645\0644\0627\0621' UESCAPE '\',
      'Customer credits',
      'liability'
    ),
    (
      '1160',
      U&'\0630\0645\0645 \0645\0631\062A\062C\0639\0627\062A \0627\0644\0645\0648\0631\062F\064A\0646' UESCAPE '\',
      'Supplier credits receivable',
      'asset'
    )
) as v(code, name_ar, name_en, type)
on conflict (tenant_id, code) do nothing;

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
  and root.code = '2000'
  and leaf.code = '2150'
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

update public.chart_of_accounts leaf
set parent_id = root.id
from public.chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '1000'
  and leaf.code = '1160'
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

alter table public.chart_of_accounts enable trigger trg_enforce_chart_account_protection;

-- ===========================================================================
-- Section 3: Internal helpers
-- ===========================================================================

create or replace function public.resolve_system_sales_returns_account(p_tenant_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_acct public.chart_of_accounts%rowtype;
  v_child_count bigint;
begin
  select * into v_acct
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = '4102';

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_acct.type <> 'income'
    or coalesce(v_acct.is_system, false) is distinct from true
    or not v_acct.is_active
    or v_acct.related_entity_id is not null then
    raise exception 'validation_failed';
  end if;

  select count(*) into v_child_count
  from public.chart_of_accounts c
  where c.tenant_id = p_tenant_id
    and c.parent_id = v_acct.id
    and c.is_active = true;

  if v_child_count > 0 then
    raise exception 'validation_failed';
  end if;

  return v_acct.id;
end;
$$;

comment on function public.resolve_system_sales_returns_account(uuid) is
  'M7.5: Resolves tenant system sales returns contra-revenue account 4102.';

create or replace function public.resolve_system_customer_credit_account(p_tenant_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_acct public.chart_of_accounts%rowtype;
  v_child_count bigint;
begin
  select * into v_acct
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = '2150';

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_acct.type <> 'liability'
    or coalesce(v_acct.is_system, false) is distinct from true
    or not v_acct.is_active
    or v_acct.related_entity_id is not null then
    raise exception 'validation_failed';
  end if;

  select count(*) into v_child_count
  from public.chart_of_accounts c
  where c.tenant_id = p_tenant_id
    and c.parent_id = v_acct.id
    and c.is_active = true;

  if v_child_count > 0 then
    raise exception 'validation_failed';
  end if;

  return v_acct.id;
end;
$$;

comment on function public.resolve_system_customer_credit_account(uuid) is
  'M7.5: Resolves tenant system customer credit liability account 2150.';

create or replace function public.resolve_system_supplier_credit_receivable_account(p_tenant_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_acct public.chart_of_accounts%rowtype;
  v_child_count bigint;
begin
  select * into v_acct
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = '1160';

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_acct.type <> 'asset'
    or coalesce(v_acct.is_system, false) is distinct from true
    or not v_acct.is_active
    or v_acct.related_entity_id is not null then
    raise exception 'validation_failed';
  end if;

  select count(*) into v_child_count
  from public.chart_of_accounts c
  where c.tenant_id = p_tenant_id
    and c.parent_id = v_acct.id
    and c.is_active = true;

  if v_child_count > 0 then
    raise exception 'validation_failed';
  end if;

  return v_acct.id;
end;
$$;

comment on function public.resolve_system_supplier_credit_receivable_account(uuid) is
  'M7.5: Resolves tenant system supplier credits receivable asset account 1160.';

create or replace function public.assert_return_invoice_view()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;

  if not (
    public.user_has_permission('invoices.view_returns')
    or public.user_has_permission('invoices.view_sales')
    or public.user_has_permission('invoices.view_purchase')
    or public.user_has_permission('invoices.view')
  ) then
    raise exception 'permission_denied';
  end if;
end;
$$;

comment on function public.assert_return_invoice_view() is
  'M7.5: View permission for return invoice read RPCs.';

create or replace function public.normalize_return_invoice_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed_top text[] := array[
    'original_invoice_id', 'date', 'warehouse_id', 'reason', 'notes', 'lines'
  ];
  v_allowed_line text[] := array[
    'original_invoice_line_id', 'qty', 'line_order', 'product_unit_id'
  ];
  v_key text;
  v_lines jsonb;
  v_line jsonb;
  v_line_order int;
  v_line_order_numeric numeric;
  v_orig_line_id uuid;
  v_qty numeric(15, 3);
  v_product_unit_id uuid;
  v_original_invoice_id uuid;
  v_warehouse_id uuid;
  v_return_date date;
  v_reason text;
  v_seen_orders int[] := '{}';
  v_norm_lines jsonb := '[]'::jsonb;
  v_norm_line jsonb;
  v_result jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if not (v_key = any (v_allowed_top)) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (
    p_data ? 'original_invoice_id'
    and p_data ? 'date'
    and p_data ? 'warehouse_id'
    and p_data ? 'reason'
    and p_data ? 'lines'
  ) then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'lines') <> 'array'
    or jsonb_array_length(p_data -> 'lines') < 1
    or jsonb_array_length(p_data -> 'lines') > 500 then
    raise exception 'validation_failed';
  end if;

  v_lines := p_data -> 'lines';

  for v_line in select value from jsonb_array_elements(v_lines) loop
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'validation_failed';
    end if;

    for v_key in select jsonb_object_keys(v_line) loop
      if not (v_key = any (v_allowed_line)) then
        raise exception 'validation_failed';
      end if;
    end loop;

    if not (
      v_line ? 'original_invoice_line_id'
      and v_line ? 'qty'
      and v_line ? 'line_order'
    ) then
      raise exception 'validation_failed';
    end if;

    if jsonb_typeof(v_line -> 'original_invoice_line_id') <> 'string'
      or jsonb_typeof(v_line -> 'qty') <> 'number'
      or jsonb_typeof(v_line -> 'line_order') <> 'number'
      or (
        v_line ? 'product_unit_id'
        and jsonb_typeof(v_line -> 'product_unit_id') <> 'string'
      ) then
      raise exception 'validation_failed';
    end if;

    begin
      v_line_order_numeric := (v_line ->> 'line_order')::numeric;
      if v_line_order_numeric <> trunc(v_line_order_numeric)
        or v_line_order_numeric < 1
        or v_line_order_numeric > 2147483647 then
        raise exception 'validation_failed';
      end if;
      v_line_order := v_line_order_numeric::int;
      v_orig_line_id := (v_line ->> 'original_invoice_line_id')::uuid;
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      if v_line ? 'product_unit_id' then
        v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;
      else
        v_product_unit_id := null;
      end if;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if v_line_order < 1
      or v_line_order = any (v_seen_orders)
      or v_qty <= 0 then
      raise exception 'validation_failed';
    end if;

    v_seen_orders := array_append(v_seen_orders, v_line_order);

    v_norm_line := jsonb_build_object(
      'original_invoice_line_id', v_orig_line_id::text,
      'qty', to_jsonb(v_qty),
      'line_order', v_line_order
    );
    if v_product_unit_id is not null then
      v_norm_line := v_norm_line || jsonb_build_object('product_unit_id', v_product_unit_id::text);
    end if;

    v_norm_lines := v_norm_lines || jsonb_build_array(v_norm_line);
  end loop;

  select coalesce(
    jsonb_agg(
      value
      order by (value ->> 'line_order')::int,
        value ->> 'original_invoice_line_id'
    ),
    '[]'::jsonb
  )
  into v_norm_lines
  from jsonb_array_elements(v_norm_lines);

  if jsonb_typeof(p_data -> 'original_invoice_id') <> 'string'
    or jsonb_typeof(p_data -> 'date') <> 'string'
    or jsonb_typeof(p_data -> 'warehouse_id') <> 'string'
    or jsonb_typeof(p_data -> 'reason') <> 'string'
    or (
      p_data ? 'notes'
      and jsonb_typeof(p_data -> 'notes') not in ('string', 'null')
    ) then
    raise exception 'validation_failed';
  end if;

  begin
    v_original_invoice_id := (p_data ->> 'original_invoice_id')::uuid;
    v_warehouse_id := (p_data ->> 'warehouse_id')::uuid;
    v_return_date := (p_data ->> 'date')::date;
    v_reason := btrim(p_data ->> 'reason');
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if v_reason = '' then
    raise exception 'validation_failed';
  end if;

  v_result := jsonb_build_object(
    'original_invoice_id', v_original_invoice_id::text,
    'date', v_return_date::text,
    'warehouse_id', v_warehouse_id::text,
    'reason', v_reason,
    'lines', v_norm_lines
  );

  if p_data ? 'notes' and btrim(coalesce(p_data ->> 'notes', '')) <> '' then
    v_result := v_result || jsonb_build_object('notes', btrim(p_data ->> 'notes'));
  end if;

  return v_result;
end;
$$;

comment on function public.normalize_return_invoice_payload(jsonb) is
  'M7.5: Canonical sales/purchase return payload for idempotency hashing.';

create or replace function public.compute_return_invoice_payload_hash(p_data jsonb)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(public.normalize_return_invoice_payload(p_data)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_return_invoice_payload_hash(jsonb) is
  'M7.5: SHA-256 hex of canonical return-invoice payload.';

create or replace function public.normalize_cancel_return_invoice_payload(
  p_return_invoice_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_reason text;
begin
  if p_return_invoice_id is null then
    raise exception 'validation_failed';
  end if;

  v_reason := btrim(coalesce(p_reason, ''));
  if v_reason = '' then
    raise exception 'validation_failed';
  end if;

  return jsonb_build_object(
    'return_invoice_id', p_return_invoice_id::text,
    'reason', v_reason
  );
end;
$$;

comment on function public.normalize_cancel_return_invoice_payload(uuid, text) is
  'M7.5: Canonical cancel-return payload for idempotency hashing.';

create or replace function public.compute_cancel_return_invoice_payload_hash(
  p_return_invoice_id uuid,
  p_reason text
)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(
        public.normalize_cancel_return_invoice_payload(p_return_invoice_id, p_reason)::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_cancel_return_invoice_payload_hash(uuid, text) is
  'M7.5: SHA-256 hex of canonical cancel-return payload.';

create or replace function public.normalize_apply_return_credit_payload(
  p_return_invoice_id uuid,
  p_target_invoice_id uuid,
  p_amount numeric
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_return_invoice_id is null
    or p_target_invoice_id is null
    or p_amount is null
    or p_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  return jsonb_build_object(
    'return_invoice_id', p_return_invoice_id::text,
    'target_invoice_id', p_target_invoice_id::text,
    'amount', to_jsonb(p_amount)
  );
end;
$$;

comment on function public.normalize_apply_return_credit_payload(uuid, uuid, numeric) is
  'M7.5: Canonical apply-return-credit payload for idempotency hashing.';

create or replace function public.compute_apply_return_credit_payload_hash(
  p_return_invoice_id uuid,
  p_target_invoice_id uuid,
  p_amount numeric
)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(
        public.normalize_apply_return_credit_payload(
          p_return_invoice_id, p_target_invoice_id, p_amount
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_apply_return_credit_payload_hash(uuid, uuid, numeric) is
  'M7.5: SHA-256 hex of canonical apply-return-credit payload.';

create or replace function public.get_line_returned_qty(
  p_tenant_id uuid,
  p_original_line_id uuid
)
returns numeric(15, 3)
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(il.qty), 0)::numeric(15, 3)
  from public.invoice_lines il
  join public.invoices i
    on i.id = il.invoice_id
    and i.tenant_id = il.tenant_id
  where il.tenant_id = p_tenant_id
    and il.original_invoice_line_id = p_original_line_id
    and i.status <> 'cancelled';
$$;

comment on function public.get_line_returned_qty(uuid, uuid) is
  'M7.5: Sum of confirmed non-cancelled return qty for an original invoice line.';

create or replace function public.assert_return_qty_allowed(
  p_tenant_id uuid,
  p_original_line_id uuid,
  p_requested_qty numeric
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_orig_qty numeric(15, 3);
  v_returned_qty numeric(15, 3);
begin
  if p_requested_qty is null or p_requested_qty <= 0 then
    raise exception 'validation_failed';
  end if;

  select il.qty
  into v_orig_qty
  from public.invoice_lines il
  where il.id = p_original_line_id
    and il.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_returned_qty := public.get_line_returned_qty(p_tenant_id, p_original_line_id);

  if v_returned_qty + p_requested_qty > v_orig_qty then
    raise exception 'validation_failed';
  end if;
end;
$$;

comment on function public.assert_return_qty_allowed(uuid, uuid, numeric) is
  'M7.5: Rejects cumulative return qty exceeding original confirmed qty.';

create or replace function public.get_invoice_credit_allocated_amount(
  p_tenant_id uuid,
  p_invoice_id uuid
)
returns numeric(15, 3)
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(ica.allocated_amount), 0)::numeric(15, 3)
  from public.invoice_credit_allocations ica
  where ica.tenant_id = p_tenant_id
    and ica.target_invoice_id = p_invoice_id
    and coalesce(ica.is_reversed, false) = false
    and ica.allocation_kind in ('original_settlement', 'future_invoice');
$$;

comment on function public.get_invoice_credit_allocated_amount(uuid, uuid) is
  'M7.5: Active credit allocations reducing target invoice effective outstanding.';

create or replace function public.get_invoice_effective_outstanding(
  p_tenant_id uuid,
  p_invoice_id uuid
)
returns numeric(15, 3)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_total numeric(15, 3);
  v_voucher_paid numeric(15, 3);
  v_credit_allocated numeric(15, 3);
begin
  select i.total
  into v_total
  from public.invoices i
  where i.id = p_invoice_id
    and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_voucher_paid := public.get_invoice_allocation_paid_amount(p_tenant_id, p_invoice_id);
  v_credit_allocated := public.get_invoice_credit_allocated_amount(p_tenant_id, p_invoice_id);

  return greatest(v_total - v_voucher_paid - v_credit_allocated, 0)::numeric(15, 3);
end;
$$;

comment on function public.get_invoice_effective_outstanding(uuid, uuid) is
  'M7.5: Invoice total minus voucher payments and credit allocations.';

create or replace function public.get_return_credit_remaining(
  p_tenant_id uuid,
  p_return_invoice_id uuid
)
returns numeric(15, 3)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_total numeric(15, 3);
  v_allocated numeric(15, 3);
begin
  select i.total
  into v_total
  from public.invoices i
  where i.id = p_return_invoice_id
    and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  select coalesce(sum(ica.allocated_amount), 0)
  into v_allocated
  from public.invoice_credit_allocations ica
  where ica.tenant_id = p_tenant_id
    and ica.source_invoice_id = p_return_invoice_id
    and coalesce(ica.is_reversed, false) = false;

  return greatest(v_total - v_allocated, 0)::numeric(15, 3);
end;
$$;

comment on function public.get_return_credit_remaining(uuid, uuid) is
  'M7.5: Return invoice total minus all active credit/refund allocations.';

create or replace function public.apply_inventory_restore_wac_internal(
  p_tenant_id uuid,
  p_product_id uuid,
  p_incoming_qty numeric,
  p_incoming_value numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_avg_cost numeric(15, 3);
  v_post_qty numeric(15, 3);
  v_old_qty numeric(15, 3);
  v_new_avg numeric(15, 3);
begin
  if p_incoming_qty is null or p_incoming_qty <= 0 then
    raise exception 'validation_failed';
  end if;

  if p_incoming_value is null or p_incoming_value < 0 then
    raise exception 'validation_failed';
  end if;

  select p.avg_cost
  into v_old_avg_cost
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  select coalesce(sum(ib.qty_available), 0)
  into v_post_qty
  from public.inventory_balances ib
  where ib.tenant_id = p_tenant_id
    and ib.product_id = p_product_id;

  v_old_qty := v_post_qty - p_incoming_qty;

  if v_old_qty = 0 then
    v_new_avg := p_incoming_value / p_incoming_qty;
  else
    v_new_avg := (
      (v_old_qty * v_old_avg_cost) + p_incoming_value
    ) / v_post_qty;
  end if;

  update public.products
  set
    avg_cost = v_new_avg,
    updated_at = now(),
    updated_by = auth.uid()
  where id = p_product_id
    and tenant_id = p_tenant_id;
end;
$$;

comment on function public.apply_inventory_restore_wac_internal(uuid, uuid, numeric, numeric) is
  'M7.5: WAC restore on sales return stock-in without updating last_purchase_cost.';

create or replace function public.calc_return_line_snapshots(
  p_tenant_id uuid,
  p_original_invoice_id uuid,
  p_return_lines jsonb,
  p_tax_enabled boolean
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_line_input jsonb;
  v_orig_line public.invoice_lines%rowtype;
  v_ratio numeric;
  v_snap jsonb;
  v_snaps jsonb := '[]'::jsonb;
  v_last_idx int := 0;
  v_idx int := 0;
  v_sum_before_tax numeric(15, 3) := 0;
  v_sum_tax numeric(15, 3) := 0;
  v_sum_total numeric(15, 3) := 0;
  v_intended_before_tax numeric(15, 3) := 0;
  v_intended_tax numeric(15, 3) := 0;
  v_intended_total numeric(15, 3) := 0;
  v_last_snap jsonb;
  v_subtotal numeric(15, 3) := 0;
  v_discount numeric(15, 3) := 0;
  v_tax numeric(15, 3) := 0;
  v_total numeric(15, 3) := 0;
begin
  for v_line_input in
    select value
    from jsonb_array_elements(p_return_lines)
    order by (value ->> 'line_order')::int
  loop
    select * into v_orig_line
    from public.invoice_lines il
    where il.id = (v_line_input ->> 'original_invoice_line_id')::uuid
      and il.tenant_id = p_tenant_id
      and il.invoice_id = p_original_invoice_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    v_ratio := (v_line_input ->> 'qty')::numeric(15, 3) / v_orig_line.qty;

    v_intended_before_tax := v_intended_before_tax + round(v_orig_line.before_tax_amount * v_ratio, 3);
    v_intended_tax := v_intended_tax + round(v_orig_line.tax_amount * v_ratio, 3);
    v_intended_total := v_intended_total + round(v_orig_line.line_total * v_ratio, 3);

    v_snap := jsonb_build_object(
      'line_order', (v_line_input ->> 'line_order')::int,
      'original_invoice_line_id', v_orig_line.id::text,
      'product_id', v_orig_line.product_id::text,
      'product_unit_id', v_orig_line.product_unit_id::text,
      'qty', (v_line_input ->> 'qty')::numeric,
      'unit_price', v_orig_line.unit_price,
      'discount_pct', v_orig_line.discount_pct,
      'gross_amount', round(v_orig_line.gross_amount * v_ratio, 3),
      'discount_amount', round(v_orig_line.discount_amount * v_ratio, 3),
      'before_tax_amount', round(v_orig_line.before_tax_amount * v_ratio, 3),
      'after_tax_amount', round(v_orig_line.after_tax_amount * v_ratio, 3),
      'tax_rate_id', v_orig_line.tax_rate_id::text,
      'tax_rate', v_orig_line.tax_rate,
      'tax_class', v_orig_line.tax_class::text,
      'taxable_amount', round(v_orig_line.taxable_amount * v_ratio, 3),
      'tax_amount', round(v_orig_line.tax_amount * v_ratio, 3),
      'line_total', round(v_orig_line.line_total * v_ratio, 3),
      'cost_price', v_orig_line.cost_price
    );

    if v_line_input ? 'product_unit_id' then
      v_snap := v_snap || jsonb_build_object(
        'product_unit_id', (v_line_input ->> 'product_unit_id')
      );
    end if;

    v_snaps := v_snaps || jsonb_build_array(v_snap);
    v_last_idx := v_idx;
    v_idx := v_idx + 1;
  end loop;

  for v_snap in
    select value from jsonb_array_elements(v_snaps)
  loop
    v_sum_before_tax := v_sum_before_tax + (v_snap ->> 'before_tax_amount')::numeric(15, 3);
    v_sum_tax := v_sum_tax + (v_snap ->> 'tax_amount')::numeric(15, 3);
    v_sum_total := v_sum_total + (v_snap ->> 'line_total')::numeric(15, 3);
  end loop;

  if jsonb_array_length(v_snaps) > 0 then
    v_last_snap := v_snaps -> v_last_idx;
    v_last_snap := v_last_snap
      || jsonb_build_object(
        'before_tax_amount',
        (v_last_snap ->> 'before_tax_amount')::numeric(15, 3)
          + (v_intended_before_tax - v_sum_before_tax),
        'tax_amount',
        (v_last_snap ->> 'tax_amount')::numeric(15, 3)
          + (v_intended_tax - v_sum_tax),
        'line_total',
        (v_last_snap ->> 'line_total')::numeric(15, 3)
          + (v_intended_total - v_sum_total)
      );

    v_snaps := jsonb_set(v_snaps, array[v_last_idx::text], v_last_snap);
  end if;

  for v_snap in
    select value from jsonb_array_elements(v_snaps)
  loop
    v_subtotal := v_subtotal + (v_snap ->> 'before_tax_amount')::numeric(15, 3);
    v_discount := v_discount + (v_snap ->> 'discount_amount')::numeric(15, 3);
    v_tax := v_tax + (v_snap ->> 'tax_amount')::numeric(15, 3);
    v_total := v_total + (v_snap ->> 'line_total')::numeric(15, 3);
  end loop;

  return jsonb_build_object(
    'lines', v_snaps,
    'subtotal', v_subtotal,
    'discount_amount', v_discount,
    'tax_amount', v_tax,
    'total', v_total
  );
end;
$$;

comment on function public.calc_return_line_snapshots(uuid, uuid, jsonb, boolean) is
  'M7.5: Proportional return line snapshots with last-line residual rounding.';

-- ===========================================================================
-- Section 4: Write RPCs
-- ===========================================================================

create or replace function public.record_sales_return(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_original_invoice public.invoices%rowtype;
  v_original_invoice_id uuid;
  v_warehouse_id uuid;
  v_return_date date;
  v_reason text;
  v_notes text;
  v_return_invoice_id uuid;
  v_return_number text;
  v_books_locked_through date;
  v_tax_enabled boolean;
  v_snapshots jsonb;
  v_total numeric(15, 3);
  v_subtotal numeric(15, 3);
  v_discount_amount numeric(15, 3);
  v_tax_amount numeric(15, 3);
  v_line_input jsonb;
  v_line_snap jsonb;
  v_orig_line public.invoice_lines%rowtype;
  v_product_unit_id uuid;
  v_is_serialized boolean;
  v_returns_account uuid;
  v_ar_account_id uuid;
  v_credit_account uuid;
  v_cogs_account uuid;
  v_inventory_account uuid;
  v_journal_entry_id uuid;
  v_journal_number text;
  v_je_line_order int := 0;
  v_cogs_total numeric(15, 3) := 0;
  v_orig_outstanding numeric(15, 3);
  v_settlement_amount numeric(15, 3);
  v_credit_amount numeric(15, 3);
  v_stock_map jsonb := '{}'::jsonb;
  v_wac_qty_map jsonb := '{}'::jsonb;
  v_wac_value_map jsonb := '{}'::jsonb;
  v_agg_qty numeric(15, 3);
  v_agg_value numeric(15, 3);
  v_dist_product_id text;
  v_output_account_id uuid;
  v_prev_status text;
  v_prev_warehouse_id uuid;
  v_cost_price numeric(15, 3);
  v_line_qty numeric(15, 3);
  v_product_id uuid;
  v_lock_line_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('invoices.create_sales_return') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_return_invoice_payload(p_data);
  v_hash := public.compute_return_invoice_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.invoices'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  v_original_invoice_id := (v_normalized ->> 'original_invoice_id')::uuid;
  v_warehouse_id := (v_normalized ->> 'warehouse_id')::uuid;
  v_return_date := (v_normalized ->> 'date')::date;
  v_reason := v_normalized ->> 'reason';

  if v_normalized ? 'notes' then
    v_notes := v_normalized ->> 'notes';
  end if;

  select * into v_original_invoice
  from public.invoices i
  where i.id = v_original_invoice_id
    and i.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_original_invoice.type <> 'sales'
    or v_original_invoice.status not in ('confirmed', 'partially_paid', 'paid') then
    raise exception 'validation_failed';
  end if;

  if v_original_invoice.warehouse_id is distinct from v_warehouse_id then
    raise exception 'validation_failed';
  end if;

  select ts.books_locked_through, ts.tax_enabled
  into v_books_locked_through, v_tax_enabled
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_return_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  for v_lock_line_id in
    select distinct (elem ->> 'original_invoice_line_id')::uuid
    from jsonb_array_elements(v_normalized -> 'lines') as elem
    order by 1
  loop
    perform 1
    from public.invoice_lines il
    where il.id = v_lock_line_id
      and il.tenant_id = v_tenant_id
    for update;
  end loop;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    perform public.assert_return_qty_allowed(
      v_tenant_id,
      (v_line_input ->> 'original_invoice_line_id')::uuid,
      (v_line_input ->> 'qty')::numeric(15, 3)
    );

    select * into v_orig_line
    from public.invoice_lines il
    where il.id = (v_line_input ->> 'original_invoice_line_id')::uuid
      and il.tenant_id = v_tenant_id
      and il.invoice_id = v_original_invoice_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    select p.is_serialized
    into v_is_serialized
    from public.products p
    where p.id = v_orig_line.product_id
      and p.tenant_id = v_tenant_id;

    if v_is_serialized then
      if (v_line_input ->> 'qty')::numeric <> 1
        or not (v_line_input ? 'product_unit_id')
        or (v_line_input ->> 'product_unit_id')::uuid is distinct from v_orig_line.product_unit_id then
        raise exception 'validation_failed';
      end if;

      perform public.assert_sales_unit_reversal_safe(
        v_tenant_id,
        v_orig_line.product_unit_id,
        v_original_invoice_id
      );

      perform 1
      from public.product_units pu
      where pu.id = v_orig_line.product_unit_id
        and pu.tenant_id = v_tenant_id
      for update;
    elsif v_line_input ? 'product_unit_id' then
      raise exception 'validation_failed';
    end if;

    perform 1
    from public.products p
    where p.id = v_orig_line.product_id
      and p.tenant_id = v_tenant_id
    for update;

    perform 1
    from public.inventory_balances ib
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_warehouse_id
      and ib.product_id = v_orig_line.product_id
    for update;
  end loop;

  v_snapshots := public.calc_return_line_snapshots(
    v_tenant_id,
    v_original_invoice_id,
    v_normalized -> 'lines',
    v_tax_enabled
  );

  v_subtotal := (v_snapshots ->> 'subtotal')::numeric(15, 3);
  v_discount_amount := (v_snapshots ->> 'discount_amount')::numeric(15, 3);
  v_tax_amount := (v_snapshots ->> 'tax_amount')::numeric(15, 3);
  v_total := (v_snapshots ->> 'total')::numeric(15, 3);

  if v_total is null or v_total <= 0 then
    raise exception 'validation_failed';
  end if;

  v_returns_account := public.resolve_system_sales_returns_account(v_tenant_id);
  v_credit_account := public.resolve_system_customer_credit_account(v_tenant_id);
  v_cogs_account := public.resolve_system_cogs_account(v_tenant_id);
  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);

  select c.account_id
  into v_ar_account_id
  from public.customers c
  where c.id = v_original_invoice.customer_id
    and c.tenant_id = v_tenant_id;

  v_orig_outstanding := public.get_invoice_effective_outstanding(
    v_tenant_id,
    v_original_invoice_id
  );
  v_settlement_amount := least(v_total, v_orig_outstanding);
  v_credit_amount := v_total - v_settlement_amount;

  for v_line_snap in
    select value from jsonb_array_elements(v_snapshots -> 'lines')
  loop
    v_product_id := (v_line_snap ->> 'product_id')::uuid;
    v_line_qty := (v_line_snap ->> 'qty')::numeric(15, 3);
    v_cost_price := (v_line_snap ->> 'cost_price')::numeric(15, 3);
    v_cogs_total := v_cogs_total + (v_line_qty * v_cost_price);

    v_dist_product_id := v_product_id::text;
    v_agg_qty := coalesce((v_stock_map ->> v_dist_product_id)::numeric, 0) + v_line_qty;
    v_stock_map := v_stock_map || jsonb_build_object(v_dist_product_id, v_agg_qty);

    v_agg_value := coalesce((v_wac_value_map ->> v_dist_product_id)::numeric, 0)
      + (v_line_qty * v_cost_price);
    v_wac_value_map := v_wac_value_map || jsonb_build_object(v_dist_product_id, v_agg_value);
    v_agg_qty := coalesce((v_wac_qty_map ->> v_dist_product_id)::numeric, 0) + v_line_qty;
    v_wac_qty_map := v_wac_qty_map || jsonb_build_object(v_dist_product_id, v_agg_qty);
  end loop;

  perform public.allow_finance_write();

  v_return_number := public.next_document_number('SR');
  v_return_invoice_id := gen_random_uuid();

  insert into public.invoices (
    id, tenant_id, type, status, customer_id, warehouse_id,
    date, notes, invoice_number,
    subtotal, discount_amount, tax_amount, total, paid_amount,
    original_invoice_id, return_reason,
    idempotency_key, idempotency_payload_hash,
    created_by, confirmed_at, confirmed_by
  )
  values (
    v_return_invoice_id, v_tenant_id, 'sales_return', 'confirmed',
    v_original_invoice.customer_id, v_warehouse_id,
    v_return_date, v_notes, v_return_number,
    v_subtotal, v_discount_amount, v_tax_amount, v_total, 0,
    v_original_invoice_id, v_reason,
    p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

  for v_line_snap in
    select value
    from jsonb_array_elements(v_snapshots -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_product_unit_id := nullif(v_line_snap ->> 'product_unit_id', '')::uuid;

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id, product_unit_id,
      qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, cost_price, line_order, original_invoice_line_id
    )
    values (
      v_tenant_id, v_return_invoice_id,
      (v_line_snap ->> 'product_id')::uuid,
      v_product_unit_id,
      (v_line_snap ->> 'qty')::numeric(15, 3),
      (v_line_snap ->> 'unit_price')::numeric(15, 3),
      (v_line_snap ->> 'discount_pct')::numeric(5, 2),
      (v_line_snap ->> 'gross_amount')::numeric(15, 3),
      (v_line_snap ->> 'discount_amount')::numeric(15, 3),
      (v_line_snap ->> 'before_tax_amount')::numeric(15, 3),
      (v_line_snap ->> 'after_tax_amount')::numeric(15, 3),
      nullif(v_line_snap ->> 'tax_rate_id', '')::uuid,
      coalesce((v_line_snap ->> 'tax_rate')::numeric(9, 6), 0),
      (v_line_snap ->> 'tax_class')::public.product_tax_class,
      (v_line_snap ->> 'taxable_amount')::numeric(15, 3),
      (v_line_snap ->> 'tax_amount')::numeric(15, 3),
      (v_line_snap ->> 'line_total')::numeric(15, 3),
      (v_line_snap ->> 'cost_price')::numeric(15, 3),
      (v_line_snap ->> 'line_order')::int,
      (v_line_snap ->> 'original_invoice_line_id')::uuid
    );
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_stock_map)
  loop
    v_agg_qty := (v_stock_map ->> v_dist_product_id)::numeric(15, 3);

    update public.inventory_balances
    set qty_available = qty_available + v_agg_qty
    where tenant_id = v_tenant_id
      and warehouse_id = v_warehouse_id
      and product_id = v_dist_product_id::uuid;

    if not found then
      insert into public.inventory_balances (
        tenant_id, warehouse_id, product_id, qty_available
      )
      values (
        v_tenant_id, v_warehouse_id, v_dist_product_id::uuid, v_agg_qty
      );
    end if;
  end loop;

  for v_line_snap in
    select value
    from jsonb_array_elements(v_snapshots -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_product_id := (v_line_snap ->> 'product_id')::uuid;
    v_line_qty := (v_line_snap ->> 'qty')::numeric(15, 3);
    v_cost_price := (v_line_snap ->> 'cost_price')::numeric(15, 3);
    v_product_unit_id := nullif(v_line_snap ->> 'product_unit_id', '')::uuid;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, unit_cost, reference_table, reference_id, notes, created_by
    )
    values (
      v_tenant_id, 'sale_return', v_warehouse_id, v_product_id, v_product_unit_id,
      v_line_qty, v_cost_price, 'sales_return_invoice', v_return_invoice_id,
      'Sales return ' || v_return_number, auth.uid()
    );

    if v_product_unit_id is not null then
      select ue.metadata_json ->> 'previous_status', ue.metadata_json ->> 'previous_warehouse_id'
      into v_prev_status, v_prev_warehouse_id
      from public.unit_events ue
      where ue.tenant_id = v_tenant_id
        and ue.product_unit_id = v_product_unit_id
        and ue.reference_table = 'sales_invoice'
        and ue.reference_id = v_original_invoice_id
        and ue.event_type = 'sales_invoice'
      order by ue.occurred_at desc, ue.id desc
      limit 1;

      update public.product_units
      set
        status = v_prev_status::public.unit_status,
        current_warehouse_id = v_prev_warehouse_id::uuid,
        current_customer_id = null,
        updated_at = now()
      where id = v_product_unit_id
        and tenant_id = v_tenant_id;

      insert into public.unit_events (
        tenant_id, product_unit_id, event_type, occurred_at,
        warehouse_id, reference_table, reference_id, notes, metadata_json, created_by
      )
      values (
        v_tenant_id, v_product_unit_id, 'sales_return', now(),
        v_warehouse_id, 'sales_return_invoice', v_return_invoice_id,
        v_reason,
        jsonb_build_object(
          'original_invoice_id', v_original_invoice_id::text,
          'restored_status', v_prev_status,
          'restored_warehouse_id', v_prev_warehouse_id
        ),
        auth.uid()
      );
    end if;
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_wac_qty_map)
  loop
    v_agg_qty := (v_wac_qty_map ->> v_dist_product_id)::numeric(15, 3);
    v_agg_value := (v_wac_value_map ->> v_dist_product_id)::numeric(15, 3);

    perform public.apply_inventory_restore_wac_internal(
      v_tenant_id,
      v_dist_product_id::uuid,
      v_agg_qty,
      v_agg_value
    );
  end loop;

  v_journal_number := public.next_document_number('JE');
  v_journal_entry_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_return_date,
    'sales_return', v_return_invoice_id,
    'Sales return ' || v_return_number, false, auth.uid()
  );

  if v_subtotal > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_returns_account,
      v_subtotal, 0, v_je_line_order, 'Sales returns contra-revenue'
    );
  end if;

  for v_output_account_id, v_agg_qty in
    select tr.output_account_id, sum((snap.value ->> 'tax_amount')::numeric(15, 3))
    from jsonb_array_elements(v_snapshots -> 'lines') as snap(value)
    join public.tax_rates tr
      on tr.id = nullif(snap.value ->> 'tax_rate_id', '')::uuid
      and tr.tenant_id = v_tenant_id
    where coalesce(v_tax_enabled, false)
      and coalesce((snap.value ->> 'tax_amount')::numeric, 0) > 0
    group by tr.output_account_id
    order by tr.output_account_id
  loop
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_output_account_id,
      v_agg_qty, 0, v_je_line_order, 'Output tax reversal'
    );
  end loop;

  if v_settlement_amount > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_ar_account_id,
      0, v_settlement_amount, v_je_line_order, 'Customer A/R settlement'
    );
  end if;

  if v_credit_amount > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_credit_account,
      0, v_credit_amount, v_je_line_order, 'Customer credit'
    );
  end if;

  if v_cogs_total > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_inventory_account,
      v_cogs_total, 0, v_je_line_order, 'Inventory restore'
    );

    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_cogs_account,
      0, v_cogs_total, v_je_line_order, 'COGS reversal'
    );
  end if;

  update public.journal_entries
  set
    is_posted = true,
    posted_at = now(),
    posted_by = auth.uid()
  where id = v_journal_entry_id
    and tenant_id = v_tenant_id;

  update public.invoices
  set journal_entry_id = v_journal_entry_id
  where id = v_return_invoice_id
    and tenant_id = v_tenant_id;

  if v_settlement_amount > 0 then
    insert into public.invoice_credit_allocations (
      tenant_id, source_invoice_id, target_invoice_id,
      allocation_kind, allocated_amount, created_by
    )
    values (
      v_tenant_id, v_return_invoice_id, v_original_invoice_id,
      'original_settlement', v_settlement_amount, auth.uid()
    );
  end if;

  return v_return_invoice_id;
end;
$$;

comment on function public.record_sales_return(jsonb, uuid) is
  'M7.5: Atomic sales return with stock restore, settlement split, and balanced journal.';

create or replace function public.record_purchase_return(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_original_invoice public.invoices%rowtype;
  v_original_invoice_id uuid;
  v_warehouse_id uuid;
  v_return_date date;
  v_reason text;
  v_notes text;
  v_return_invoice_id uuid;
  v_return_number text;
  v_books_locked_through date;
  v_tax_enabled boolean;
  v_snapshots jsonb;
  v_total numeric(15, 3);
  v_subtotal numeric(15, 3);
  v_discount_amount numeric(15, 3);
  v_tax_amount numeric(15, 3);
  v_line_snap jsonb;
  v_orig_line public.invoice_lines%rowtype;
  v_is_serialized boolean;
  v_ap_account_id uuid;
  v_credit_account uuid;
  v_inventory_account uuid;
  v_journal_entry_id uuid;
  v_journal_number text;
  v_je_line_order int := 0;
  v_inventory_credit numeric(15, 3) := 0;
  v_recoverable_tax numeric(15, 3) := 0;
  v_orig_outstanding numeric(15, 3);
  v_settlement_amount numeric(15, 3);
  v_credit_amount numeric(15, 3);
  v_stock_map jsonb := '{}'::jsonb;
  v_wac_qty_map jsonb := '{}'::jsonb;
  v_wac_value_map jsonb := '{}'::jsonb;
  v_agg_qty numeric(15, 3);
  v_agg_value numeric(15, 3);
  v_available_qty numeric(15, 3);
  v_dist_product_id text;
  v_input_tax_account uuid;
  v_is_recoverable boolean;
  v_line_capitalized numeric(15, 3);
  v_line_qty numeric(15, 3);
  v_product_id uuid;
  v_product_unit_id uuid;
  v_lock_line_id uuid;
  v_line_input jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('invoices.create_purchase_return') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_return_invoice_payload(p_data);
  v_hash := public.compute_return_invoice_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.invoices'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  v_original_invoice_id := (v_normalized ->> 'original_invoice_id')::uuid;
  v_warehouse_id := (v_normalized ->> 'warehouse_id')::uuid;
  v_return_date := (v_normalized ->> 'date')::date;
  v_reason := v_normalized ->> 'reason';

  if v_normalized ? 'notes' then
    v_notes := v_normalized ->> 'notes';
  end if;

  select * into v_original_invoice
  from public.invoices i
  where i.id = v_original_invoice_id
    and i.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_original_invoice.type <> 'purchase'
    or v_original_invoice.status not in ('confirmed', 'partially_paid', 'paid') then
    raise exception 'validation_failed';
  end if;

  if v_original_invoice.warehouse_id is distinct from v_warehouse_id then
    raise exception 'validation_failed';
  end if;

  select ts.books_locked_through, ts.tax_enabled
  into v_books_locked_through, v_tax_enabled
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_return_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  for v_lock_line_id in
    select distinct (elem ->> 'original_invoice_line_id')::uuid
    from jsonb_array_elements(v_normalized -> 'lines') as elem
    order by 1
  loop
    perform 1
    from public.invoice_lines il
    where il.id = v_lock_line_id
      and il.tenant_id = v_tenant_id
    for update;
  end loop;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    perform public.assert_return_qty_allowed(
      v_tenant_id,
      (v_line_input ->> 'original_invoice_line_id')::uuid,
      (v_line_input ->> 'qty')::numeric(15, 3)
    );

    select * into v_orig_line
    from public.invoice_lines il
    where il.id = (v_line_input ->> 'original_invoice_line_id')::uuid
      and il.tenant_id = v_tenant_id
      and il.invoice_id = v_original_invoice_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    select p.is_serialized
    into v_is_serialized
    from public.products p
    where p.id = v_orig_line.product_id
      and p.tenant_id = v_tenant_id;

    if v_is_serialized then
      if (v_line_input ->> 'qty')::numeric <> 1
        or not (v_line_input ? 'product_unit_id')
        or (v_line_input ->> 'product_unit_id')::uuid is distinct from v_orig_line.product_unit_id then
        raise exception 'validation_failed';
      end if;

      perform 1
      from public.product_units pu
      where pu.id = v_orig_line.product_unit_id
        and pu.tenant_id = v_tenant_id
        and pu.purchase_invoice_id = v_original_invoice_id
        and pu.status in ('available_new', 'available_used')
        and pu.current_warehouse_id = v_warehouse_id
      for update;
    elsif v_line_input ? 'product_unit_id' then
      raise exception 'validation_failed';
    end if;

    perform 1
    from public.products p
    where p.id = v_orig_line.product_id
      and p.tenant_id = v_tenant_id
    for update;

    perform 1
    from public.inventory_balances ib
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_warehouse_id
      and ib.product_id = v_orig_line.product_id
    for update;
  end loop;

  v_snapshots := public.calc_return_line_snapshots(
    v_tenant_id,
    v_original_invoice_id,
    v_normalized -> 'lines',
    v_tax_enabled
  );

  v_subtotal := (v_snapshots ->> 'subtotal')::numeric(15, 3);
  v_discount_amount := (v_snapshots ->> 'discount_amount')::numeric(15, 3);
  v_tax_amount := (v_snapshots ->> 'tax_amount')::numeric(15, 3);
  v_total := (v_snapshots ->> 'total')::numeric(15, 3);

  if v_total is null or v_total <= 0 then
    raise exception 'validation_failed';
  end if;

  v_credit_account := public.resolve_system_supplier_credit_receivable_account(v_tenant_id);
  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);

  select s.account_id
  into v_ap_account_id
  from public.suppliers s
  where s.id = v_original_invoice.supplier_id
    and s.tenant_id = v_tenant_id;

  v_orig_outstanding := public.get_invoice_effective_outstanding(
    v_tenant_id,
    v_original_invoice_id
  );
  v_settlement_amount := least(v_total, v_orig_outstanding);
  v_credit_amount := v_total - v_settlement_amount;

  for v_line_snap in
    select value from jsonb_array_elements(v_snapshots -> 'lines')
  loop
    v_line_capitalized := public.purchase_line_capitalized_amount(
      v_tenant_id,
      v_tax_enabled,
      v_line_snap
    );
    v_inventory_credit := v_inventory_credit + v_line_capitalized;

    v_product_id := (v_line_snap ->> 'product_id')::uuid;
    v_line_qty := (v_line_snap ->> 'qty')::numeric(15, 3);
    v_dist_product_id := v_product_id::text;

    v_agg_qty := coalesce((v_stock_map ->> v_dist_product_id)::numeric, 0) + v_line_qty;
    v_stock_map := v_stock_map || jsonb_build_object(v_dist_product_id, v_agg_qty);

    v_agg_value := coalesce((v_wac_value_map ->> v_dist_product_id)::numeric, 0) + v_line_capitalized;
    v_wac_value_map := v_wac_value_map || jsonb_build_object(v_dist_product_id, v_agg_value);
    v_agg_qty := coalesce((v_wac_qty_map ->> v_dist_product_id)::numeric, 0) + v_line_qty;
    v_wac_qty_map := v_wac_qty_map || jsonb_build_object(v_dist_product_id, v_agg_qty);

    if coalesce(v_tax_enabled, false)
      and coalesce((v_line_snap ->> 'tax_amount')::numeric, 0) > 0
      and nullif(v_line_snap ->> 'tax_rate_id', '') is not null then
      select tr.is_recoverable, tr.input_account_id
      into v_is_recoverable, v_input_tax_account
      from public.tax_rates tr
      where tr.id = (v_line_snap ->> 'tax_rate_id')::uuid
        and tr.tenant_id = v_tenant_id;

      if coalesce(v_is_recoverable, true) then
        v_recoverable_tax := v_recoverable_tax + (v_line_snap ->> 'tax_amount')::numeric(15, 3);
      end if;
    end if;
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_stock_map)
  loop
    v_agg_qty := (v_stock_map ->> v_dist_product_id)::numeric(15, 3);

    select coalesce(ib.qty_available, 0)
    into v_available_qty
    from public.inventory_balances ib
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_warehouse_id
      and ib.product_id = v_dist_product_id::uuid;

    if coalesce(v_available_qty, 0) < v_agg_qty then
      raise exception 'insufficient_stock';
    end if;
  end loop;

  perform public.allow_finance_write();

  v_return_number := public.next_document_number('PR');
  v_return_invoice_id := gen_random_uuid();

  insert into public.invoices (
    id, tenant_id, type, status, supplier_id, warehouse_id,
    date, notes, invoice_number,
    subtotal, discount_amount, tax_amount, total, paid_amount,
    original_invoice_id, return_reason,
    idempotency_key, idempotency_payload_hash,
    created_by, confirmed_at, confirmed_by
  )
  values (
    v_return_invoice_id, v_tenant_id, 'purchase_return', 'confirmed',
    v_original_invoice.supplier_id, v_warehouse_id,
    v_return_date, v_notes, v_return_number,
    v_subtotal, v_discount_amount, v_tax_amount, v_total, 0,
    v_original_invoice_id, v_reason,
    p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

  for v_line_snap in
    select value
    from jsonb_array_elements(v_snapshots -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_product_unit_id := nullif(v_line_snap ->> 'product_unit_id', '')::uuid;
    v_line_capitalized := public.purchase_line_capitalized_amount(
      v_tenant_id,
      v_tax_enabled,
      v_line_snap
    );

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id, product_unit_id,
      qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, cost_price, line_order, original_invoice_line_id
    )
    values (
      v_tenant_id, v_return_invoice_id,
      (v_line_snap ->> 'product_id')::uuid,
      v_product_unit_id,
      (v_line_snap ->> 'qty')::numeric(15, 3),
      (v_line_snap ->> 'unit_price')::numeric(15, 3),
      (v_line_snap ->> 'discount_pct')::numeric(5, 2),
      (v_line_snap ->> 'gross_amount')::numeric(15, 3),
      (v_line_snap ->> 'discount_amount')::numeric(15, 3),
      (v_line_snap ->> 'before_tax_amount')::numeric(15, 3),
      (v_line_snap ->> 'after_tax_amount')::numeric(15, 3),
      nullif(v_line_snap ->> 'tax_rate_id', '')::uuid,
      coalesce((v_line_snap ->> 'tax_rate')::numeric(9, 6), 0),
      (v_line_snap ->> 'tax_class')::public.product_tax_class,
      (v_line_snap ->> 'taxable_amount')::numeric(15, 3),
      (v_line_snap ->> 'tax_amount')::numeric(15, 3),
      (v_line_snap ->> 'line_total')::numeric(15, 3),
      v_line_capitalized / (v_line_snap ->> 'qty')::numeric(15, 3),
      (v_line_snap ->> 'line_order')::int,
      (v_line_snap ->> 'original_invoice_line_id')::uuid
    );
  end loop;

  for v_line_snap in
    select value
    from jsonb_array_elements(v_snapshots -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_product_id := (v_line_snap ->> 'product_id')::uuid;
    v_line_qty := (v_line_snap ->> 'qty')::numeric(15, 3);
    v_product_unit_id := nullif(v_line_snap ->> 'product_unit_id', '')::uuid;
    v_line_capitalized := public.purchase_line_capitalized_amount(
      v_tenant_id,
      v_tax_enabled,
      v_line_snap
    );

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, unit_cost, reference_table, reference_id, notes, created_by
    )
    values (
      v_tenant_id, 'purchase_return', v_warehouse_id, v_product_id, v_product_unit_id,
      -v_line_qty, v_line_capitalized / v_line_qty, 'purchase_return_invoice', v_return_invoice_id,
      'Purchase return ' || v_return_number, auth.uid()
    );

    if v_product_unit_id is not null then
      insert into public.unit_events (
        tenant_id, product_unit_id, event_type, occurred_at,
        warehouse_id, reference_table, reference_id, notes, metadata_json, created_by
      )
      values (
        v_tenant_id, v_product_unit_id, 'purchase_return', now(),
        null, 'purchase_return_invoice', v_return_invoice_id,
        v_reason,
        jsonb_build_object(
          'original_invoice_id', v_original_invoice_id::text,
          'previous_status', (
            select pu.status::text
            from public.product_units pu
            where pu.id = v_product_unit_id
          ),
          'previous_warehouse_id', v_warehouse_id::text
        ),
        auth.uid()
      );

      update public.product_units
      set
        status = 'retired',
        current_warehouse_id = null,
        updated_at = now()
      where id = v_product_unit_id
        and tenant_id = v_tenant_id;
    end if;
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_stock_map)
  loop
    v_agg_qty := (v_stock_map ->> v_dist_product_id)::numeric(15, 3);

    update public.inventory_balances
    set qty_available = qty_available - v_agg_qty
    where tenant_id = v_tenant_id
      and warehouse_id = v_warehouse_id
      and product_id = v_dist_product_id::uuid;

    if not found then
      raise exception 'insufficient_stock';
    end if;
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_wac_qty_map)
  loop
    v_agg_qty := (v_wac_qty_map ->> v_dist_product_id)::numeric(15, 3);
    v_agg_value := (v_wac_value_map ->> v_dist_product_id)::numeric(15, 3);

    begin
      perform public.reverse_purchase_wac_internal(
        v_tenant_id,
        v_dist_product_id::uuid,
        v_agg_qty,
        v_agg_value
      );
    exception
      when others then
        if SQLERRM like '%return_document_required%' then
          raise exception 'return_not_safely_reversible';
        end if;
        raise;
    end;
  end loop;

  v_journal_number := public.next_document_number('JE');
  v_journal_entry_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_return_date,
    'purchase_return', v_return_invoice_id,
    'Purchase return ' || v_return_number, false, auth.uid()
  );

  if v_settlement_amount > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_ap_account_id,
      v_settlement_amount, 0, v_je_line_order, 'Supplier A/P settlement'
    );
  end if;

  if v_credit_amount > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_credit_account,
      v_credit_amount, 0, v_je_line_order, 'Supplier credit receivable'
    );
  end if;

  if v_inventory_credit > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_inventory_account,
      0, v_inventory_credit, v_je_line_order, 'Inventory reduction'
    );
  end if;

  if v_recoverable_tax > 0 and v_input_tax_account is not null then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_input_tax_account,
      0, v_recoverable_tax, v_je_line_order, 'Input tax reversal'
    );
  end if;

  update public.journal_entries
  set
    is_posted = true,
    posted_at = now(),
    posted_by = auth.uid()
  where id = v_journal_entry_id
    and tenant_id = v_tenant_id;

  update public.invoices
  set journal_entry_id = v_journal_entry_id
  where id = v_return_invoice_id
    and tenant_id = v_tenant_id;

  if v_settlement_amount > 0 then
    insert into public.invoice_credit_allocations (
      tenant_id, source_invoice_id, target_invoice_id,
      allocation_kind, allocated_amount, created_by
    )
    values (
      v_tenant_id, v_return_invoice_id, v_original_invoice_id,
      'original_settlement', v_settlement_amount, auth.uid()
    );
  end if;

  return v_return_invoice_id;
end;
$$;

comment on function public.record_purchase_return(jsonb, uuid) is
  'M7.5: Atomic purchase return with stock removal, WAC reversal, settlement split, and journal.';

create or replace function public.cancel_return_invoice(
  p_return_invoice_id uuid,
  p_reason text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_je_id uuid;
  v_return_invoice public.invoices%rowtype;
  v_original_invoice_id uuid;
  v_reversal_je_id uuid;
  v_reversal_number text;
  v_jl record;
  v_je_line_order int := 0;
  v_line record;
  v_stock_map jsonb := '{}'::jsonb;
  v_wac_qty_map jsonb := '{}'::jsonb;
  v_wac_value_map jsonb := '{}'::jsonb;
  v_agg_qty numeric(15, 3);
  v_agg_value numeric(15, 3);
  v_available_qty numeric(15, 3);
  v_dist_product_id text;
  v_tax_enabled boolean;
  v_line_snap jsonb;
  v_prev_status text;
  v_prev_warehouse_id uuid;
  v_product_id_loop uuid;
  v_wac_qty numeric(15, 3);
  v_wac_value numeric(15, 3);
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('invoices.cancel') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  perform public.normalize_cancel_return_invoice_payload(p_return_invoice_id, p_reason);
  v_hash := public.compute_cancel_return_invoice_payload_hash(p_return_invoice_id, p_reason);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_je_id := public.resolve_finance_idempotency(
    'public.journal_entries'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_je_id is not null then
    select i.id
    into p_return_invoice_id
    from public.invoices i
    where i.tenant_id = v_tenant_id
      and i.reversal_journal_entry_id = v_existing_je_id;

    if not found then
      select je.source_id
      into p_return_invoice_id
      from public.journal_entries je
      where je.id = v_existing_je_id
        and je.tenant_id = v_tenant_id;
    end if;

    return p_return_invoice_id;
  end if;

  select * into v_return_invoice
  from public.invoices i
  where i.id = p_return_invoice_id
    and i.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_return_invoice.status = 'cancelled' then
    raise exception 'validation_failed';
  end if;

  if v_return_invoice.type not in ('sales_return', 'purchase_return') then
    raise exception 'validation_failed';
  end if;

  if v_return_invoice.journal_entry_id is null then
    raise exception 'validation_failed';
  end if;

  if exists (
    select 1
    from public.invoice_credit_allocations ica
    where ica.tenant_id = v_tenant_id
      and ica.source_invoice_id = p_return_invoice_id
      and coalesce(ica.is_reversed, false) = false
      and ica.allocation_kind in ('future_invoice', 'cash_refund')
  ) then
    raise exception 'validation_failed';
  end if;

  v_original_invoice_id := v_return_invoice.original_invoice_id;

  select ts.tax_enabled
  into v_tax_enabled
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  perform 1
  from public.journal_entries je
  where je.id = v_return_invoice.journal_entry_id
    and je.tenant_id = v_tenant_id
  for update;

  if v_original_invoice_id is not null then
    perform 1
    from public.invoices i
    where i.id = v_original_invoice_id
      and i.tenant_id = v_tenant_id
    for update;
  end if;

  for v_dist_product_id in
    select distinct il.product_id::text
    from public.invoice_lines il
    where il.invoice_id = p_return_invoice_id
      and il.tenant_id = v_tenant_id
    order by 1
  loop
    perform 1
    from public.products p
    where p.id = v_dist_product_id::uuid
      and p.tenant_id = v_tenant_id
    for update;
  end loop;

  if v_return_invoice.type = 'sales_return' then
    for v_line in
      select il.*
      from public.invoice_lines il
      where il.invoice_id = p_return_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      if v_line.product_unit_id is not null then
        perform 1
        from public.product_units pu
        where pu.id = v_line.product_unit_id
          and pu.tenant_id = v_tenant_id
        for update;
      end if;

      v_agg_qty := coalesce((v_stock_map ->> v_line.product_id::text)::numeric, 0) + v_line.qty;
      v_stock_map := v_stock_map || jsonb_build_object(v_line.product_id::text, v_agg_qty);

      v_agg_value := coalesce((v_wac_value_map ->> v_line.product_id::text)::numeric, 0)
        + (v_line.qty * v_line.cost_price);
      v_wac_value_map := v_wac_value_map || jsonb_build_object(v_line.product_id::text, v_agg_value);
      v_agg_qty := coalesce((v_wac_qty_map ->> v_line.product_id::text)::numeric, 0) + v_line.qty;
      v_wac_qty_map := v_wac_qty_map || jsonb_build_object(v_line.product_id::text, v_agg_qty);
    end loop;

    for v_dist_product_id in
      select jsonb_object_keys(v_stock_map)
    loop
      perform 1
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.warehouse_id = v_return_invoice.warehouse_id
        and ib.product_id = v_dist_product_id::uuid
      for update;
    end loop;

    perform public.allow_finance_write();

    for v_line in
      select il.*
      from public.invoice_lines il
      where il.invoice_id = p_return_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      insert into public.inventory_movements (
        tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
        qty, unit_cost, reference_table, reference_id, notes, created_by
      )
      values (
        v_tenant_id, 'sale', v_return_invoice.warehouse_id, v_line.product_id, v_line.product_unit_id,
        -v_line.qty, v_line.cost_price, 'sales_return_invoice', p_return_invoice_id,
        'Sales return cancellation ' || coalesce(v_return_invoice.invoice_number, p_return_invoice_id::text),
        auth.uid()
      );

      if v_line.product_unit_id is not null then
        select ue.metadata_json ->> 'restored_status', ue.metadata_json ->> 'restored_warehouse_id'
        into v_prev_status, v_prev_warehouse_id
        from public.unit_events ue
        where ue.tenant_id = v_tenant_id
          and ue.product_unit_id = v_line.product_unit_id
          and ue.reference_table = 'sales_return_invoice'
          and ue.reference_id = p_return_invoice_id
          and ue.event_type = 'sales_return'
        order by ue.occurred_at desc, ue.id desc
        limit 1;

        update public.product_units
        set
          status = 'sold',
          current_warehouse_id = null,
          current_customer_id = v_return_invoice.customer_id,
          updated_at = now()
        where id = v_line.product_unit_id
          and tenant_id = v_tenant_id;

        insert into public.unit_events (
          tenant_id, product_unit_id, event_type, occurred_at,
          customer_id, reference_table, reference_id, notes, created_by
        )
        values (
          v_tenant_id, v_line.product_unit_id, 'sales_return_cancellation', now(),
          v_return_invoice.customer_id, 'sales_return_invoice', p_return_invoice_id,
          btrim(p_reason), auth.uid()
        );
      end if;
    end loop;

    for v_dist_product_id in
      select jsonb_object_keys(v_stock_map)
    loop
      v_agg_qty := (v_stock_map ->> v_dist_product_id)::numeric(15, 3);

      update public.inventory_balances
      set qty_available = qty_available - v_agg_qty
      where tenant_id = v_tenant_id
        and warehouse_id = v_return_invoice.warehouse_id
        and product_id = v_dist_product_id::uuid;

      if not found then
        raise exception 'validation_failed';
      end if;
    end loop;

    for v_dist_product_id in
      select jsonb_object_keys(v_wac_qty_map)
    loop
      v_agg_qty := (v_wac_qty_map ->> v_dist_product_id)::numeric(15, 3);
      v_agg_value := (v_wac_value_map ->> v_dist_product_id)::numeric(15, 3);

      perform public.reverse_purchase_wac_internal(
        v_tenant_id,
        v_dist_product_id::uuid,
        v_agg_qty,
        v_agg_value
      );
    end loop;

  elsif v_return_invoice.type = 'purchase_return' then
    for v_line in
      select il.*
      from public.invoice_lines il
      where il.invoice_id = p_return_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      perform 1
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.warehouse_id = v_return_invoice.warehouse_id
        and ib.product_id = v_line.product_id
      for update;

      if v_line.product_unit_id is not null then
        perform 1
        from public.product_units pu
        where pu.id = v_line.product_unit_id
          and pu.tenant_id = v_tenant_id
        for update;
      end if;

      v_agg_qty := coalesce((v_stock_map ->> v_line.product_id::text)::numeric, 0) + v_line.qty;
      v_stock_map := v_stock_map || jsonb_build_object(v_line.product_id::text, v_agg_qty);
    end loop;

    perform public.allow_finance_write();

    for v_line in
      select il.*
      from public.invoice_lines il
      where il.invoice_id = p_return_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      insert into public.inventory_movements (
        tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
        qty, unit_cost, reference_table, reference_id, notes, created_by
      )
      values (
        v_tenant_id, 'purchase', v_return_invoice.warehouse_id, v_line.product_id, v_line.product_unit_id,
        v_line.qty, v_line.cost_price, 'purchase_return_invoice', p_return_invoice_id,
        'Purchase return cancellation ' || coalesce(v_return_invoice.invoice_number, p_return_invoice_id::text),
        auth.uid()
      );

      if v_line.product_unit_id is not null then
        select ue.metadata_json ->> 'previous_status', ue.metadata_json ->> 'previous_warehouse_id'
        into v_prev_status, v_prev_warehouse_id
        from public.unit_events ue
        where ue.tenant_id = v_tenant_id
          and ue.product_unit_id = v_line.product_unit_id
          and ue.reference_table = 'purchase_return_invoice'
          and ue.reference_id = p_return_invoice_id
          and ue.event_type = 'purchase_return'
        order by ue.occurred_at desc, ue.id desc
        limit 1;

        update public.product_units
        set
          status = coalesce(v_prev_status, 'available_new')::public.unit_status,
          current_warehouse_id = coalesce(v_prev_warehouse_id::uuid, v_return_invoice.warehouse_id),
          updated_at = now()
        where id = v_line.product_unit_id
          and tenant_id = v_tenant_id;
      end if;
    end loop;

    for v_dist_product_id in
      select jsonb_object_keys(v_stock_map)
    loop
      v_agg_qty := (v_stock_map ->> v_dist_product_id)::numeric(15, 3);

      update public.inventory_balances
      set qty_available = qty_available + v_agg_qty
      where tenant_id = v_tenant_id
        and warehouse_id = v_return_invoice.warehouse_id
        and product_id = v_dist_product_id::uuid;

      if not found then
        insert into public.inventory_balances (
          tenant_id, warehouse_id, product_id, qty_available
        )
        values (
          v_tenant_id, v_return_invoice.warehouse_id, v_dist_product_id::uuid, v_agg_qty
        );
      end if;
    end loop;

    for v_product_id_loop in
      select distinct il.product_id
      from public.invoice_lines il
      where il.invoice_id = p_return_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.product_id
    loop
      select coalesce(sum(il.qty), 0)
      into v_wac_qty
      from public.invoice_lines il
      where il.invoice_id = p_return_invoice_id
        and il.tenant_id = v_tenant_id
        and il.product_id = v_product_id_loop;

      v_wac_value := 0;
      for v_line in
        select il.tax_rate_id, il.tax_amount, il.before_tax_amount, il.qty, il.cost_price
        from public.invoice_lines il
        where il.invoice_id = p_return_invoice_id
          and il.tenant_id = v_tenant_id
          and il.product_id = v_product_id_loop
      loop
        v_line_snap := jsonb_build_object(
          'tax_rate_id', v_line.tax_rate_id::text,
          'tax_amount', v_line.tax_amount,
          'before_tax_amount', v_line.before_tax_amount,
          'qty', v_line.qty,
          'cost_price', v_line.cost_price
        );
        v_wac_value := v_wac_value + public.purchase_line_capitalized_amount(
          v_tenant_id,
          v_tax_enabled,
          v_line_snap
        );
      end loop;

      perform public.apply_purchase_wac_internal(
        v_tenant_id,
        v_product_id_loop,
        v_wac_qty,
        v_wac_value
      );
    end loop;
  end if;

  update public.invoice_credit_allocations
  set
    is_reversed = true,
    reversed_at = now(),
    reversed_by = auth.uid()
  where tenant_id = v_tenant_id
    and source_invoice_id = p_return_invoice_id
    and coalesce(is_reversed, false) = false;

  if not coalesce(current_setting('hs360.finance_write', true), '') = '1' then
    perform public.allow_finance_write();
  end if;

  v_reversal_number := public.next_document_number('JE');
  v_reversal_je_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by,
    reversal_of_entry_id, idempotency_key, idempotency_payload_hash
  )
  values (
    v_reversal_je_id, v_tenant_id, v_reversal_number, v_return_invoice.date,
    (case
      when v_return_invoice.type = 'sales_return' then 'sales_return_reversal'
      else 'purchase_return_reversal'
    end)::public.journal_source,
    p_return_invoice_id,
    'Return cancellation ' || coalesce(v_return_invoice.invoice_number, p_return_invoice_id::text),
    false, auth.uid(),
    v_return_invoice.journal_entry_id, p_idempotency_key, v_hash
  );

  for v_jl in
    select jl.*
    from public.journal_lines jl
    where jl.journal_entry_id = v_return_invoice.journal_entry_id
      and jl.tenant_id = v_tenant_id
    order by jl.line_order
  loop
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_reversal_je_id, v_jl.account_id,
      v_jl.credit, v_jl.debit, v_je_line_order,
      'Reversal: ' || coalesce(v_jl.description, '')
    );
  end loop;

  update public.journal_entries
  set
    is_posted = true,
    posted_at = now(),
    posted_by = auth.uid()
  where id = v_reversal_je_id
    and tenant_id = v_tenant_id;

  update public.invoices
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancelled_by = auth.uid(),
    cancellation_reason = btrim(p_reason),
    reversal_journal_entry_id = v_reversal_je_id
  where id = p_return_invoice_id
    and tenant_id = v_tenant_id;

  return p_return_invoice_id;
end;
$$;

comment on function public.cancel_return_invoice(uuid, text, uuid) is
  'M7.5: Cancel return invoice; reverses stock, WAC, journal, and all credit allocations.';

-- ===========================================================================
-- Section 5: Credit, settlement, and M7 extensions
-- ===========================================================================

alter table public.vouchers
  drop constraint if exists chk_vouchers_party_direction;

alter table public.vouchers
  add constraint chk_vouchers_party_direction check (
    (
      type = 'receipt'
      and customer_id is not null
      and supplier_id is null
      and employee_id is null
    )
    or (
      type = 'payment'
      and supplier_id is not null
      and customer_id is null
      and employee_id is null
    )
    or (
      type = 'payment'
      and supplier_id is null
      and customer_id is null
      and employee_id is null
    )
    or (
      type = 'payment'
      and customer_id is not null
      and supplier_id is null
      and employee_id is null
    )
    or (
      type = 'receipt'
      and supplier_id is not null
      and customer_id is null
      and employee_id is null
    )
  );

create or replace function public.apply_return_credit_to_invoice(
  p_return_invoice_id uuid,
  p_target_invoice_id uuid,
  p_amount numeric(15, 3),
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_id uuid;
  v_return_invoice public.invoices%rowtype;
  v_target_invoice public.invoices%rowtype;
  v_allocation_id uuid;
  v_remaining numeric(15, 3);
  v_target_outstanding numeric(15, 3);
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_idempotency_key is null or p_amount is null or p_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  v_hash := public.compute_apply_return_credit_payload_hash(
    p_return_invoice_id,
    p_target_invoice_id,
    p_amount
  );

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.invoice_credit_allocations'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  select * into v_return_invoice
  from public.invoices i
  where i.id = p_return_invoice_id
    and i.tenant_id = v_tenant_id
  for update;

  if not found
    or v_return_invoice.status <> 'confirmed'
    or v_return_invoice.type not in ('sales_return', 'purchase_return') then
    raise exception 'validation_failed';
  end if;

  if v_return_invoice.type = 'sales_return' then
    if not public.user_has_permission('invoices.create_sales_return') then
      raise exception 'permission_denied';
    end if;
  else
    if not public.user_has_permission('invoices.create_purchase_return') then
      raise exception 'permission_denied';
    end if;
  end if;

  select * into v_target_invoice
  from public.invoices i
  where i.id = p_target_invoice_id
    and i.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_return_invoice.type = 'sales_return' then
    if v_target_invoice.type <> 'sales'
      or v_target_invoice.customer_id is distinct from v_return_invoice.customer_id then
      raise exception 'validation_failed';
    end if;
  else
    if v_target_invoice.type <> 'purchase'
      or v_target_invoice.supplier_id is distinct from v_return_invoice.supplier_id then
      raise exception 'validation_failed';
    end if;
  end if;

  if v_target_invoice.status not in ('confirmed', 'partially_paid') then
    raise exception 'validation_failed';
  end if;

  v_remaining := public.get_return_credit_remaining(v_tenant_id, p_return_invoice_id);
  if p_amount > v_remaining then
    raise exception 'validation_failed';
  end if;

  v_target_outstanding := public.get_invoice_effective_outstanding(v_tenant_id, p_target_invoice_id);
  if p_amount > v_target_outstanding then
    raise exception 'validation_failed';
  end if;

  perform public.allow_finance_write();

  v_allocation_id := gen_random_uuid();

  insert into public.invoice_credit_allocations (
    id, tenant_id, source_invoice_id, target_invoice_id,
    allocation_kind, allocated_amount,
    idempotency_key, idempotency_payload_hash, created_by
  )
  values (
    v_allocation_id, v_tenant_id, p_return_invoice_id, p_target_invoice_id,
    'future_invoice', p_amount,
    p_idempotency_key, v_hash, auth.uid()
  );

  return v_allocation_id;
end;
$$;

comment on function public.apply_return_credit_to_invoice(uuid, uuid, numeric(15, 3), uuid) is
  'M7.5: Apply remaining return credit to a future invoice (future_invoice allocation).';

create or replace function public.record_customer_refund_voucher(
  p_return_invoice_id uuid,
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_id uuid;
  v_return_invoice public.invoices%rowtype;
  v_customer_id uuid;
  v_date date;
  v_amount numeric(15, 3);
  v_payment_method public.payment_method;
  v_cash_account_id uuid;
  v_credit_account uuid;
  v_reference_no text;
  v_notes text;
  v_remaining numeric(15, 3);
  v_allocations jsonb := '[]'::jsonb;
  v_alloc_elem jsonb;
  v_alloc_return_id uuid;
  v_alloc_amount numeric(15, 3);
  v_alloc_sum numeric(15, 3) := 0;
  v_seen_return_ids uuid[] := '{}';
  v_voucher_id uuid;
  v_voucher_number text;
  v_journal_entry_id uuid;
  v_journal_number text;
  v_books_locked_through date;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('vouchers.create_payment') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null or p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if not (p_data ? 'date' and p_data ? 'amount' and p_data ? 'payment_method' and p_data ? 'cash_account_id') then
    raise exception 'validation_failed';
  end if;

  v_date := (p_data ->> 'date')::date;
  v_amount := (p_data ->> 'amount')::numeric(15, 3);
  v_payment_method := (p_data ->> 'payment_method')::public.payment_method;
  v_cash_account_id := (p_data ->> 'cash_account_id')::uuid;

  if v_amount is null or v_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'reference_no' then
    v_reference_no := p_data ->> 'reference_no';
  end if;
  if p_data ? 'notes' then
    v_notes := p_data ->> 'notes';
  end if;

  if p_data ? 'allocations' then
    if p_return_invoice_id is not null
      or jsonb_typeof(p_data -> 'allocations') <> 'array'
      or jsonb_array_length(p_data -> 'allocations') < 1 then
      raise exception 'validation_failed';
    end if;

    for v_alloc_elem in
      select value
      from jsonb_array_elements(p_data -> 'allocations')
      order by value ->> 'return_invoice_id'
    loop
      if jsonb_typeof(v_alloc_elem) <> 'object'
        or not (v_alloc_elem ? 'return_invoice_id' and v_alloc_elem ? 'allocated_amount') then
        raise exception 'validation_failed';
      end if;

      begin
        v_alloc_return_id := (v_alloc_elem ->> 'return_invoice_id')::uuid;
        v_alloc_amount := (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3);
      exception
        when others then
          raise exception 'validation_failed';
      end;

      if v_alloc_amount is null or v_alloc_amount <= 0 then
        raise exception 'validation_failed';
      end if;

      if v_alloc_return_id = any (v_seen_return_ids) then
        raise exception 'validation_failed';
      end if;

      v_seen_return_ids := array_append(v_seen_return_ids, v_alloc_return_id);
      v_alloc_sum := v_alloc_sum + v_alloc_amount;
      v_allocations := v_allocations || jsonb_build_array(
        jsonb_build_object(
          'return_invoice_id', v_alloc_return_id::text,
          'allocated_amount', to_jsonb(v_alloc_amount)
        )
      );
    end loop;
  else
    if p_return_invoice_id is null then
      raise exception 'validation_failed';
    end if;

    v_alloc_sum := v_amount;
    v_allocations := jsonb_build_array(
      jsonb_build_object(
        'return_invoice_id', p_return_invoice_id::text,
        'allocated_amount', to_jsonb(v_amount)
      )
    );
  end if;

  select ts.books_locked_through
  into v_books_locked_through
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  if v_amount is null or v_amount <= 0 or v_alloc_sum <> v_amount then
    raise exception 'validation_failed';
  end if;

  v_hash := encode(
    digest(
      convert_to(
        jsonb_build_object(
          'date', v_date,
          'amount', v_amount,
          'payment_method', v_payment_method::text,
          'cash_account_id', v_cash_account_id::text,
          'reference_no', v_reference_no,
          'notes', v_notes,
          'allocations', v_allocations
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.vouchers'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  for v_alloc_elem in
    select value
    from jsonb_array_elements(v_allocations)
    order by value ->> 'return_invoice_id'
  loop
    v_alloc_return_id := (v_alloc_elem ->> 'return_invoice_id')::uuid;
    v_alloc_amount := (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3);

    select * into v_return_invoice
    from public.invoices i
    where i.id = v_alloc_return_id
      and i.tenant_id = v_tenant_id
    for update;

    if not found
      or v_return_invoice.type <> 'sales_return'
      or v_return_invoice.status <> 'confirmed' then
      raise exception 'validation_failed';
    end if;

    if v_customer_id is null then
      v_customer_id := v_return_invoice.customer_id;
    elsif v_customer_id is distinct from v_return_invoice.customer_id then
      raise exception 'validation_failed';
    end if;

    v_remaining := public.get_return_credit_remaining(v_tenant_id, v_alloc_return_id);
    if v_alloc_amount > v_remaining then
      raise exception 'validation_failed';
    end if;
  end loop;

  v_credit_account := public.resolve_system_customer_credit_account(v_tenant_id);
  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);

  perform public.allow_finance_write();

  v_voucher_number := public.next_document_number('PV');
  v_voucher_id := gen_random_uuid();
  v_journal_number := public.next_document_number('JE');
  v_journal_entry_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'customer_refund_voucher', v_voucher_id,
    'Customer refund ' || v_voucher_number, false, auth.uid()
  );

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values
    (v_tenant_id, v_journal_entry_id, v_credit_account, v_amount, 0, 1, 'Customer credit'),
    (v_tenant_id, v_journal_entry_id, v_cash_account_id, 0, v_amount, 2, 'Cash/Bank payment');

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_journal_entry_id and tenant_id = v_tenant_id;

  insert into public.vouchers (
    id, tenant_id, voucher_number, type, date, amount, payment_method, reference_no,
    customer_id, supplier_id, employee_id, account_id, cash_account_id,
    notes, collected_by, journal_entry_id,
    status, idempotency_key, idempotency_payload_hash,
    created_by, confirmed_at, confirmed_by
  )
  values (
    v_voucher_id, v_tenant_id, v_voucher_number, 'payment', v_date, v_amount, v_payment_method,
    v_reference_no,
    v_customer_id, null, null, v_credit_account, v_cash_account_id,
    v_notes, auth.uid(), v_journal_entry_id,
    'confirmed', p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

  for v_alloc_elem in
    select value
    from jsonb_array_elements(v_allocations)
    order by value ->> 'return_invoice_id'
  loop
    insert into public.invoice_credit_allocations (
      tenant_id, source_invoice_id, target_invoice_id, voucher_id,
      allocation_kind, allocated_amount, created_by
    )
    values (
      v_tenant_id,
      (v_alloc_elem ->> 'return_invoice_id')::uuid,
      null,
      v_voucher_id,
      'cash_refund',
      (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3),
      auth.uid()
    );
  end loop;

  return v_voucher_id;
end;
$$;

comment on function public.record_customer_refund_voucher(uuid, jsonb, uuid) is
  'M7.5: Customer refund voucher (payment+customer) linked to sales return credit.';

create or replace function public.record_supplier_refund_receipt(
  p_return_invoice_id uuid,
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_id uuid;
  v_return_invoice public.invoices%rowtype;
  v_supplier_id uuid;
  v_date date;
  v_amount numeric(15, 3);
  v_payment_method public.payment_method;
  v_cash_account_id uuid;
  v_credit_account uuid;
  v_reference_no text;
  v_notes text;
  v_remaining numeric(15, 3);
  v_allocations jsonb := '[]'::jsonb;
  v_alloc_elem jsonb;
  v_alloc_return_id uuid;
  v_alloc_amount numeric(15, 3);
  v_alloc_sum numeric(15, 3) := 0;
  v_seen_return_ids uuid[] := '{}';
  v_voucher_id uuid;
  v_voucher_number text;
  v_journal_entry_id uuid;
  v_journal_number text;
  v_books_locked_through date;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('vouchers.create_receipt') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null or p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if not (p_data ? 'date' and p_data ? 'amount' and p_data ? 'payment_method' and p_data ? 'cash_account_id') then
    raise exception 'validation_failed';
  end if;

  v_date := (p_data ->> 'date')::date;
  v_amount := (p_data ->> 'amount')::numeric(15, 3);
  v_payment_method := (p_data ->> 'payment_method')::public.payment_method;
  v_cash_account_id := (p_data ->> 'cash_account_id')::uuid;

  if v_amount is null or v_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'reference_no' then
    v_reference_no := p_data ->> 'reference_no';
  end if;
  if p_data ? 'notes' then
    v_notes := p_data ->> 'notes';
  end if;

  if p_data ? 'allocations' then
    if p_return_invoice_id is not null
      or jsonb_typeof(p_data -> 'allocations') <> 'array'
      or jsonb_array_length(p_data -> 'allocations') < 1 then
      raise exception 'validation_failed';
    end if;

    for v_alloc_elem in
      select value
      from jsonb_array_elements(p_data -> 'allocations')
      order by value ->> 'return_invoice_id'
    loop
      if jsonb_typeof(v_alloc_elem) <> 'object'
        or not (v_alloc_elem ? 'return_invoice_id' and v_alloc_elem ? 'allocated_amount') then
        raise exception 'validation_failed';
      end if;

      begin
        v_alloc_return_id := (v_alloc_elem ->> 'return_invoice_id')::uuid;
        v_alloc_amount := (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3);
      exception
        when others then
          raise exception 'validation_failed';
      end;

      if v_alloc_amount is null or v_alloc_amount <= 0 then
        raise exception 'validation_failed';
      end if;

      if v_alloc_return_id = any (v_seen_return_ids) then
        raise exception 'validation_failed';
      end if;

      v_seen_return_ids := array_append(v_seen_return_ids, v_alloc_return_id);
      v_alloc_sum := v_alloc_sum + v_alloc_amount;
      v_allocations := v_allocations || jsonb_build_array(
        jsonb_build_object(
          'return_invoice_id', v_alloc_return_id::text,
          'allocated_amount', to_jsonb(v_alloc_amount)
        )
      );
    end loop;
  else
    if p_return_invoice_id is null then
      raise exception 'validation_failed';
    end if;

    v_alloc_sum := v_amount;
    v_allocations := jsonb_build_array(
      jsonb_build_object(
        'return_invoice_id', p_return_invoice_id::text,
        'allocated_amount', to_jsonb(v_amount)
      )
    );
  end if;

  select ts.books_locked_through
  into v_books_locked_through
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  if v_amount is null or v_amount <= 0 or v_alloc_sum <> v_amount then
    raise exception 'validation_failed';
  end if;

  v_hash := encode(
    digest(
      convert_to(
        jsonb_build_object(
          'date', v_date,
          'amount', v_amount,
          'payment_method', v_payment_method::text,
          'cash_account_id', v_cash_account_id::text,
          'reference_no', v_reference_no,
          'notes', v_notes,
          'allocations', v_allocations
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.vouchers'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  for v_alloc_elem in
    select value
    from jsonb_array_elements(v_allocations)
    order by value ->> 'return_invoice_id'
  loop
    v_alloc_return_id := (v_alloc_elem ->> 'return_invoice_id')::uuid;
    v_alloc_amount := (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3);

    select * into v_return_invoice
    from public.invoices i
    where i.id = v_alloc_return_id
      and i.tenant_id = v_tenant_id
    for update;

    if not found
      or v_return_invoice.type <> 'purchase_return'
      or v_return_invoice.status <> 'confirmed' then
      raise exception 'validation_failed';
    end if;

    if v_supplier_id is null then
      v_supplier_id := v_return_invoice.supplier_id;
    elsif v_supplier_id is distinct from v_return_invoice.supplier_id then
      raise exception 'validation_failed';
    end if;

    v_remaining := public.get_return_credit_remaining(v_tenant_id, v_alloc_return_id);
    if v_alloc_amount > v_remaining then
      raise exception 'validation_failed';
    end if;
  end loop;

  v_credit_account := public.resolve_system_supplier_credit_receivable_account(v_tenant_id);
  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);

  perform public.allow_finance_write();

  v_voucher_number := public.next_document_number('RV');
  v_voucher_id := gen_random_uuid();
  v_journal_number := public.next_document_number('JE');
  v_journal_entry_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'supplier_refund_receipt', v_voucher_id,
    'Supplier refund receipt ' || v_voucher_number, false, auth.uid()
  );

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values
    (v_tenant_id, v_journal_entry_id, v_cash_account_id, v_amount, 0, 1, 'Cash/Bank receipt'),
    (v_tenant_id, v_journal_entry_id, v_credit_account, 0, v_amount, 2, 'Supplier credit receivable');

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_journal_entry_id and tenant_id = v_tenant_id;

  insert into public.vouchers (
    id, tenant_id, voucher_number, type, date, amount, payment_method, reference_no,
    customer_id, supplier_id, employee_id, account_id, cash_account_id,
    notes, collected_by, journal_entry_id,
    status, idempotency_key, idempotency_payload_hash,
    created_by, confirmed_at, confirmed_by
  )
  values (
    v_voucher_id, v_tenant_id, v_voucher_number, 'receipt', v_date, v_amount, v_payment_method,
    v_reference_no,
    null, v_supplier_id, null, v_credit_account, v_cash_account_id,
    v_notes, auth.uid(), v_journal_entry_id,
    'confirmed', p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

  for v_alloc_elem in
    select value
    from jsonb_array_elements(v_allocations)
    order by value ->> 'return_invoice_id'
  loop
    insert into public.invoice_credit_allocations (
      tenant_id, source_invoice_id, target_invoice_id, voucher_id,
      allocation_kind, allocated_amount, created_by
    )
    values (
      v_tenant_id,
      (v_alloc_elem ->> 'return_invoice_id')::uuid,
      null,
      v_voucher_id,
      'cash_refund',
      (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3),
      auth.uid()
    );
  end loop;

  return v_voucher_id;
end;
$$;

comment on function public.record_supplier_refund_receipt(uuid, jsonb, uuid) is
  'M7.5: Supplier refund receipt (receipt+supplier) linked to purchase return credit.';

create or replace function public.record_receipt_voucher(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_id uuid;
  v_normalized jsonb;
  v_customer_id uuid;
  v_date date;
  v_amount numeric(15, 3);
  v_payment_method public.payment_method;
  v_cash_account_id uuid;
  v_ar_account_id uuid;
  v_reference_no text;
  v_notes text;
  v_allocation_mode text;
  v_allocations jsonb := '[]'::jsonb;
  v_alloc_elem jsonb;
  v_voucher_id uuid;
  v_voucher_number text;
  v_journal_entry_id uuid;
  v_journal_number text;
  v_books_locked_through date;
begin
  if p_data ? 'supplier_id' then
    raise exception 'validation_failed';
  end if;

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('vouchers.create_receipt') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_receipt_voucher_payload(p_data);
  v_hash := public.compute_receipt_voucher_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.vouchers'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  v_customer_id := (v_normalized ->> 'customer_id')::uuid;
  v_date := (v_normalized ->> 'date')::date;
  v_amount := (v_normalized ->> 'amount')::numeric(15, 3);
  v_payment_method := (v_normalized ->> 'payment_method')::public.payment_method;
  v_cash_account_id := (v_normalized ->> 'cash_account_id')::uuid;
  v_allocation_mode := v_normalized ->> 'allocation_mode';

  if v_normalized ? 'reference_no' then
    v_reference_no := v_normalized ->> 'reference_no';
  end if;

  if v_normalized ? 'notes' then
    v_notes := v_normalized ->> 'notes';
  end if;

  select ts.books_locked_through
  into v_books_locked_through
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  perform public.validate_customer_ar_account(v_tenant_id, v_customer_id, null);

  select c.account_id
  into v_ar_account_id
  from public.customers c
  where c.id = v_customer_id
    and c.tenant_id = v_tenant_id;

  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);

  if v_allocation_mode = 'fifo' then
    v_allocations := public.allocate_receipt_fifo(v_tenant_id, v_customer_id, v_amount);
  elsif v_allocation_mode = 'manual' then
    v_allocations := public.validate_manual_allocations(
      v_tenant_id,
      v_amount,
      v_customer_id,
      'sales',
      v_normalized -> 'allocations',
      false
    );
  end if;

  perform public.allow_finance_write();

  v_voucher_number := public.next_document_number('RV');
  v_voucher_id := gen_random_uuid();
  v_journal_number := public.next_document_number('JE');
  v_journal_entry_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'receipt_voucher', v_voucher_id,
    'Receipt voucher ' || v_voucher_number, false, auth.uid()
  );

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values
    (v_tenant_id, v_journal_entry_id, v_cash_account_id, v_amount, 0, 1, 'Cash/Bank receipt'),
    (v_tenant_id, v_journal_entry_id, v_ar_account_id, 0, v_amount, 2, 'Customer A/R');

  update public.journal_entries
  set
    is_posted = true,
    posted_at = now(),
    posted_by = auth.uid()
  where id = v_journal_entry_id
    and tenant_id = v_tenant_id;

  insert into public.vouchers (
    id, tenant_id, voucher_number, type, date, amount, payment_method, reference_no,
    customer_id, supplier_id, employee_id, account_id, cash_account_id,
    notes, collected_by, journal_entry_id,
    status, idempotency_key, idempotency_payload_hash,
    created_by, confirmed_at, confirmed_by
  )
  values (
    v_voucher_id, v_tenant_id, v_voucher_number, 'receipt', v_date, v_amount, v_payment_method,
    v_reference_no,
    v_customer_id, null, null, v_ar_account_id, v_cash_account_id,
    v_notes, auth.uid(), v_journal_entry_id,
    'confirmed', p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

  for v_alloc_elem in
    select value
    from jsonb_array_elements(v_allocations)
    order by value ->> 'invoice_id'
  loop
    insert into public.voucher_invoice_allocations (
      tenant_id, voucher_id, invoice_id, allocated_amount, created_by
    )
    values (
      v_tenant_id,
      v_voucher_id,
      (v_alloc_elem ->> 'invoice_id')::uuid,
      (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3),
      auth.uid()
    );
  end loop;

  perform public.recompute_invoices_for_voucher(v_tenant_id, v_voucher_id);

  return v_voucher_id;
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
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_id uuid;
  v_normalized jsonb;
  v_destination text;
  v_supplier_id uuid;
  v_account_id uuid;
  v_debit_account_id uuid;
  v_date date;
  v_amount numeric(15, 3);
  v_payment_method public.payment_method;
  v_cash_account_id uuid;
  v_reference_no text;
  v_notes text;
  v_allocation_mode text;
  v_allocations jsonb := '[]'::jsonb;
  v_alloc_elem jsonb;
  v_voucher_id uuid;
  v_voucher_number text;
  v_journal_entry_id uuid;
  v_journal_number text;
  v_books_locked_through date;
begin
  if p_data ? 'customer_id' then
    raise exception 'validation_failed';
  end if;

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('vouchers.create_payment') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_payment_voucher_payload(p_data);
  v_hash := public.compute_payment_voucher_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.vouchers'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  v_destination := v_normalized ->> 'payment_destination';
  v_date := (v_normalized ->> 'date')::date;
  v_amount := (v_normalized ->> 'amount')::numeric(15, 3);
  v_payment_method := (v_normalized ->> 'payment_method')::public.payment_method;
  v_cash_account_id := (v_normalized ->> 'cash_account_id')::uuid;

  if v_normalized ? 'reference_no' then
    v_reference_no := v_normalized ->> 'reference_no';
  end if;

  if v_normalized ? 'notes' then
    v_notes := v_normalized ->> 'notes';
  end if;

  select ts.books_locked_through
  into v_books_locked_through
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);

  if v_destination = 'supplier' then
    v_supplier_id := (v_normalized ->> 'supplier_id')::uuid;
    v_allocation_mode := v_normalized ->> 'allocation_mode';

    perform public.validate_supplier_ap_account(v_tenant_id, v_supplier_id, null);

    select s.account_id
    into v_debit_account_id
    from public.suppliers s
    where s.id = v_supplier_id
      and s.tenant_id = v_tenant_id;

    if v_allocation_mode = 'fifo' then
      v_allocations := public.allocate_payment_fifo(
        v_tenant_id, v_supplier_id, v_amount, true
      );
    elsif v_allocation_mode = 'manual' then
      v_allocations := public.validate_manual_allocations(
        v_tenant_id,
        v_amount,
        v_supplier_id,
        'purchase',
        v_normalized -> 'allocations',
        true
      );
    end if;
  else
    v_account_id := (v_normalized ->> 'account_id')::uuid;
    perform public.validate_direct_payment_account(
      v_tenant_id, v_account_id, v_cash_account_id
    );
    v_debit_account_id := v_account_id;
  end if;

  perform public.allow_finance_write();

  v_voucher_number := public.next_document_number('PV');
  v_voucher_id := gen_random_uuid();
  v_journal_number := public.next_document_number('JE');
  v_journal_entry_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'payment_voucher', v_voucher_id,
    'Payment voucher ' || v_voucher_number, false, auth.uid()
  );

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values
    (v_tenant_id, v_journal_entry_id, v_debit_account_id, v_amount, 0, 1, 'Payment debit'),
    (v_tenant_id, v_journal_entry_id, v_cash_account_id, 0, v_amount, 2, 'Cash/Bank payment');

  update public.journal_entries
  set
    is_posted = true,
    posted_at = now(),
    posted_by = auth.uid()
  where id = v_journal_entry_id
    and tenant_id = v_tenant_id;

  insert into public.vouchers (
    id, tenant_id, voucher_number, type, date, amount, payment_method, reference_no,
    customer_id, supplier_id, employee_id, account_id, cash_account_id,
    notes, collected_by, journal_entry_id,
    status, idempotency_key, idempotency_payload_hash,
    created_by, confirmed_at, confirmed_by
  )
  values (
    v_voucher_id, v_tenant_id, v_voucher_number, 'payment', v_date, v_amount, v_payment_method,
    v_reference_no,
    null, v_supplier_id, null, v_debit_account_id, v_cash_account_id,
    v_notes, auth.uid(), v_journal_entry_id,
    'confirmed', p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

  for v_alloc_elem in
    select value
    from jsonb_array_elements(v_allocations)
    order by value ->> 'invoice_id'
  loop
    insert into public.voucher_invoice_allocations (
      tenant_id, voucher_id, invoice_id, allocated_amount, created_by
    )
    values (
      v_tenant_id,
      v_voucher_id,
      (v_alloc_elem ->> 'invoice_id')::uuid,
      (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3),
      auth.uid()
    );
  end loop;

  perform public.recompute_invoices_for_voucher(v_tenant_id, v_voucher_id);

  return v_voucher_id;
end;
$$;

create or replace function public.validate_manual_allocations(
  p_tenant_id uuid,
  p_voucher_amount numeric(15, 3),
  p_party_id uuid,
  p_direction text,
  p_allocations jsonb,
  p_require_full_match boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_type text;
  v_alloc_elem jsonb;
  v_invoice_id uuid;
  v_allocated_amount numeric(15, 3);
  v_invoice public.invoices%rowtype;
  v_outstanding numeric(15, 3);
  v_sum numeric(15, 3) := 0;
  v_norm_allocs jsonb := '[]'::jsonb;
  v_seen_invoice_ids uuid[] := '{}';
begin
  if p_tenant_id is null
    or p_party_id is null
    or p_voucher_amount is null
    or p_voucher_amount <= 0
    or p_direction not in ('sales', 'purchase') then
    raise exception 'validation_failed';
  end if;

  if p_allocations is null
    or jsonb_typeof(p_allocations) <> 'array'
    or jsonb_array_length(p_allocations) < 1 then
    raise exception 'validation_failed';
  end if;

  v_invoice_type := case when p_direction = 'sales' then 'sales' else 'purchase' end;

  for v_invoice_id in
    select distinct (elem.value ->> 'invoice_id')::uuid
    from jsonb_array_elements(p_allocations) as elem(value)
    order by 1
  loop
    perform 1
    from public.invoices i
    where i.id = v_invoice_id
      and i.tenant_id = p_tenant_id
    for update;
  end loop;

  for v_alloc_elem in
    select value
    from jsonb_array_elements(p_allocations)
    order by value ->> 'invoice_id'
  loop
    if jsonb_typeof(v_alloc_elem) <> 'object'
      or not (v_alloc_elem ? 'invoice_id' and v_alloc_elem ? 'allocated_amount') then
      raise exception 'validation_failed';
    end if;

    begin
      v_invoice_id := (v_alloc_elem ->> 'invoice_id')::uuid;
      v_allocated_amount := (v_alloc_elem ->> 'allocated_amount')::numeric(15, 3);
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if v_allocated_amount is null or v_allocated_amount <= 0 then
      raise exception 'validation_failed';
    end if;

    if v_invoice_id = any (v_seen_invoice_ids) then
      raise exception 'validation_failed';
    end if;

    v_seen_invoice_ids := array_append(v_seen_invoice_ids, v_invoice_id);

    select * into v_invoice
    from public.invoices i
    where i.id = v_invoice_id
      and i.tenant_id = p_tenant_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_invoice.type::text <> v_invoice_type
      or v_invoice.status not in ('confirmed', 'partially_paid') then
      raise exception 'validation_failed';
    end if;

    if p_direction = 'sales' then
      if v_invoice.customer_id is distinct from p_party_id then
        raise exception 'validation_failed';
      end if;
    else
      if v_invoice.supplier_id is distinct from p_party_id then
        raise exception 'validation_failed';
      end if;
    end if;

    v_outstanding := public.get_invoice_effective_outstanding(p_tenant_id, v_invoice_id);

    if v_outstanding <= 0 or v_allocated_amount > v_outstanding then
      raise exception 'validation_failed';
    end if;

    v_sum := v_sum + v_allocated_amount;
    v_norm_allocs := v_norm_allocs || jsonb_build_array(
      jsonb_build_object(
        'invoice_id', v_invoice_id::text,
        'allocated_amount', to_jsonb(v_allocated_amount)
      )
    );
  end loop;

  if v_sum <= 0 or v_sum > p_voucher_amount then
    raise exception 'validation_failed';
  end if;

  if p_require_full_match and v_sum <> p_voucher_amount then
    raise exception 'validation_failed';
  end if;

  select coalesce(jsonb_agg(value order by value ->> 'invoice_id'), '[]'::jsonb)
  into v_norm_allocs
  from jsonb_array_elements(v_norm_allocs);

  return v_norm_allocs;
end;
$$;

create or replace function public.allocate_receipt_fifo(
  p_tenant_id uuid,
  p_customer_id uuid,
  p_amount numeric(15, 3)
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining numeric(15, 3);
  v_invoice record;
  v_outstanding numeric(15, 3);
  v_alloc numeric(15, 3);
  v_result jsonb := '[]'::jsonb;
begin
  if p_tenant_id is null
    or p_customer_id is null
    or p_amount is null
    or p_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  v_remaining := p_amount;

  for v_invoice in
    select i.*
    from public.invoices i
    where i.tenant_id = p_tenant_id
      and i.customer_id = p_customer_id
      and i.type = 'sales'
      and i.status in ('confirmed', 'partially_paid')
    order by
      i.due_date nulls last,
      i.date,
      i.invoice_number,
      i.id
    for update
  loop
    exit when v_remaining <= 0;

    v_outstanding := public.get_invoice_effective_outstanding(p_tenant_id, v_invoice.id);

    if v_outstanding <= 0 then
      continue;
    end if;

    v_alloc := least(v_remaining, v_outstanding);
    if v_alloc <= 0 then
      continue;
    end if;

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'invoice_id', v_invoice.id::text,
        'allocated_amount', to_jsonb(v_alloc)
      )
    );
    v_remaining := v_remaining - v_alloc;
  end loop;

  return v_result;
end;
$$;

create or replace function public.allocate_payment_fifo(
  p_tenant_id uuid,
  p_supplier_id uuid,
  p_amount numeric(15, 3),
  p_require_full boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining numeric(15, 3);
  v_allocated numeric(15, 3) := 0;
  v_invoice record;
  v_outstanding numeric(15, 3);
  v_alloc numeric(15, 3);
  v_result jsonb := '[]'::jsonb;
begin
  if p_tenant_id is null
    or p_supplier_id is null
    or p_amount is null
    or p_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  v_remaining := p_amount;

  for v_invoice in
    select i.*
    from public.invoices i
    where i.tenant_id = p_tenant_id
      and i.supplier_id = p_supplier_id
      and i.type = 'purchase'
      and i.status in ('confirmed', 'partially_paid')
    order by
      i.due_date nulls last,
      i.date,
      i.invoice_number,
      i.id
    for update
  loop
    exit when v_remaining <= 0;

    v_outstanding := public.get_invoice_effective_outstanding(p_tenant_id, v_invoice.id);

    if v_outstanding <= 0 then
      continue;
    end if;

    v_alloc := least(v_remaining, v_outstanding);
    if v_alloc <= 0 then
      continue;
    end if;

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'invoice_id', v_invoice.id::text,
        'allocated_amount', to_jsonb(v_alloc)
      )
    );
    v_remaining := v_remaining - v_alloc;
    v_allocated := v_allocated + v_alloc;
  end loop;

  if p_require_full and v_allocated <> p_amount then
    raise exception 'validation_failed';
  end if;

  return v_result;
end;
$$;

create or replace function public.list_open_customer_invoices(p_customer_id uuid)
returns table (
  id uuid,
  invoice_number text,
  status public.invoice_status,
  date date,
  due_date date,
  total numeric(15, 3),
  paid_amount numeric(15, 3),
  outstanding numeric(15, 3)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not (
    public.user_has_permission('vouchers.create_receipt')
    or public.user_has_permission('vouchers.view')
    or public.user_has_permission('invoices.view_sales')
  ) then
    raise exception 'permission_denied';
  end if;

  if not exists (
    select 1
    from public.customers c
    where c.id = p_customer_id
      and c.tenant_id = v_tenant_id
  ) then
    raise exception 'validation_failed';
  end if;

  return query
  select
    i.id,
    i.invoice_number,
    i.status,
    i.date,
    i.due_date,
    i.total,
    i.paid_amount,
    public.get_invoice_effective_outstanding(v_tenant_id, i.id) as outstanding
  from public.invoices i
  where i.tenant_id = v_tenant_id
    and i.customer_id = p_customer_id
    and i.type = 'sales'
    and i.status in ('confirmed', 'partially_paid')
    and public.get_invoice_effective_outstanding(v_tenant_id, i.id) > 0
  order by
    i.due_date nulls last,
    i.date,
    i.invoice_number,
    i.id;
end;
$$;

create or replace function public.list_open_supplier_invoices(p_supplier_id uuid)
returns table (
  id uuid,
  invoice_number text,
  status public.invoice_status,
  date date,
  due_date date,
  total numeric(15, 3),
  paid_amount numeric(15, 3),
  outstanding numeric(15, 3)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not (
    public.user_has_permission('vouchers.create_payment')
    or public.user_has_permission('vouchers.view')
    or public.user_has_permission('invoices.view_purchase')
  ) then
    raise exception 'permission_denied';
  end if;

  if not exists (
    select 1
    from public.suppliers s
    where s.id = p_supplier_id
      and s.tenant_id = v_tenant_id
  ) then
    raise exception 'validation_failed';
  end if;

  return query
  select
    i.id,
    i.invoice_number,
    i.status,
    i.date,
    i.due_date,
    i.total,
    i.paid_amount,
    public.get_invoice_effective_outstanding(v_tenant_id, i.id) as outstanding
  from public.invoices i
  where i.tenant_id = v_tenant_id
    and i.supplier_id = p_supplier_id
    and i.type = 'purchase'
    and i.status in ('confirmed', 'partially_paid')
    and public.get_invoice_effective_outstanding(v_tenant_id, i.id) > 0
  order by
    i.due_date nulls last,
    i.date,
    i.invoice_number,
    i.id;
end;
$$;

-- ===========================================================================
-- Section 6: Read RPCs
-- ===========================================================================

create or replace function public.list_return_invoices(
  p_party_id uuid default null,
  p_type text default null,
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  invoice_number text,
  type public.invoice_type,
  status public.invoice_status,
  date date,
  original_invoice_id uuid,
  original_invoice_number text,
  customer_id uuid,
  supplier_id uuid,
  party_name_ar text,
  party_name_en text,
  total numeric(15, 3),
  credit_remaining numeric(15, 3),
  return_reason text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_search text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_return_invoice_view();

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    i.id,
    i.invoice_number,
    i.type,
    i.status,
    i.date,
    i.original_invoice_id,
    orig.invoice_number as original_invoice_number,
    i.customer_id,
    i.supplier_id,
    coalesce(c.name_ar, s.name_ar) as party_name_ar,
    coalesce(c.name_en, s.name_en) as party_name_en,
    i.total,
    public.get_return_credit_remaining(v_tenant_id, i.id) as credit_remaining,
    i.return_reason
  from public.invoices i
  left join public.invoices orig
    on orig.id = i.original_invoice_id
    and orig.tenant_id = i.tenant_id
  left join public.customers c
    on c.id = i.customer_id
    and c.tenant_id = i.tenant_id
  left join public.suppliers s
    on s.id = i.supplier_id
    and s.tenant_id = i.tenant_id
  where i.tenant_id = v_tenant_id
    and i.type in ('sales_return', 'purchase_return')
    and (p_type is null or i.type::text = p_type)
    and (p_status is null or i.status::text = p_status)
    and (p_date_from is null or i.date >= p_date_from)
    and (p_date_to is null or i.date <= p_date_to)
    and (
      p_party_id is null
      or i.customer_id = p_party_id
      or i.supplier_id = p_party_id
    )
    and (
      v_search is null
      or lower(coalesce(i.invoice_number, '')) like '%' || v_search || '%'
      or lower(coalesce(i.return_reason, '')) like '%' || v_search || '%'
      or lower(coalesce(orig.invoice_number, '')) like '%' || v_search || '%'
      or lower(coalesce(c.name_ar, s.name_ar, '')) like '%' || v_search || '%'
      or lower(coalesce(c.name_en, s.name_en, '')) like '%' || v_search || '%'
    )
  order by i.date desc nulls last, i.invoice_number desc nulls last, i.id desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

comment on function public.list_return_invoices(uuid, text, text, date, date, text, integer, integer) is
  'M7.5: Bounded return invoice list with original reference and credit remaining.';

create or replace function public.get_return_invoice_detail(p_invoice_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_invoice public.invoices%rowtype;
  v_original public.invoices%rowtype;
  v_customer public.customers%rowtype;
  v_supplier public.suppliers%rowtype;
  v_warehouse public.warehouses%rowtype;
  v_lines jsonb;
  v_allocations jsonb;
  v_currency_code text;
  v_currency_symbol text;
  v_currency_places int;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_return_invoice_view();

  select * into v_invoice
  from public.invoices i
  where i.id = p_invoice_id
    and i.tenant_id = v_tenant_id;

  if not found or v_invoice.type not in ('sales_return', 'purchase_return') then
    raise exception 'validation_failed';
  end if;

  if v_invoice.original_invoice_id is not null then
    select * into v_original
    from public.invoices i
    where i.id = v_invoice.original_invoice_id
      and i.tenant_id = v_tenant_id;
  end if;

  if v_invoice.customer_id is not null then
    select * into v_customer
    from public.customers c
    where c.id = v_invoice.customer_id
      and c.tenant_id = v_tenant_id;
  end if;

  if v_invoice.supplier_id is not null then
    select * into v_supplier
    from public.suppliers s
    where s.id = v_invoice.supplier_id
      and s.tenant_id = v_tenant_id;
  end if;

  if v_invoice.warehouse_id is not null then
    select * into v_warehouse
    from public.warehouses w
    where w.id = v_invoice.warehouse_id
      and w.tenant_id = v_tenant_id;
  end if;

  select c.iso_code, coalesce(c.major_symbol_ar, c.major_symbol_en), coalesce(c.decimal_places, 3)
  into v_currency_code, v_currency_symbol, v_currency_places
  from public.tenants t
  left join public.currencies c on c.id = t.default_currency_id
  where t.id = v_tenant_id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', il.id,
      'line_order', il.line_order,
      'product_id', il.product_id,
      'product_unit_id', il.product_unit_id,
      'original_invoice_line_id', il.original_invoice_line_id,
      'qty', il.qty,
      'unit_price', il.unit_price,
      'discount_pct', il.discount_pct,
      'gross_amount', il.gross_amount,
      'discount_amount', il.discount_amount,
      'before_tax_amount', il.before_tax_amount,
      'after_tax_amount', il.after_tax_amount,
      'tax_rate_id', il.tax_rate_id,
      'tax_rate', il.tax_rate,
      'tax_class', il.tax_class,
      'taxable_amount', il.taxable_amount,
      'tax_amount', il.tax_amount,
      'line_total', il.line_total,
      'cost_price', il.cost_price
    )
    order by il.line_order
  ), '[]'::jsonb)
  into v_lines
  from public.invoice_lines il
  where il.invoice_id = v_invoice.id
    and il.tenant_id = v_tenant_id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', ica.id,
      'allocation_kind', ica.allocation_kind,
      'target_invoice_id', ica.target_invoice_id,
      'target_invoice_number', ti.invoice_number,
      'voucher_id', ica.voucher_id,
      'voucher_number', v.voucher_number,
      'allocated_amount', ica.allocated_amount,
      'is_reversed', ica.is_reversed,
      'reversed_at', ica.reversed_at,
      'created_at', ica.created_at
    )
    order by ica.created_at, ica.id
  ), '[]'::jsonb)
  into v_allocations
  from public.invoice_credit_allocations ica
  left join public.invoices ti
    on ti.id = ica.target_invoice_id
    and ti.tenant_id = ica.tenant_id
  left join public.vouchers v
    on v.id = ica.voucher_id
    and v.tenant_id = ica.tenant_id
  where ica.tenant_id = v_tenant_id
    and ica.source_invoice_id = v_invoice.id;

  return jsonb_build_object(
    'id', v_invoice.id,
    'invoice_number', v_invoice.invoice_number,
    'type', v_invoice.type,
    'status', v_invoice.status,
    'date', v_invoice.date,
    'return_reason', v_invoice.return_reason,
    'notes', v_invoice.notes,
    'subtotal', v_invoice.subtotal,
    'discount_amount', v_invoice.discount_amount,
    'tax_amount', v_invoice.tax_amount,
    'total', v_invoice.total,
    'credit_remaining', public.get_return_credit_remaining(v_tenant_id, v_invoice.id),
    'original_invoice', case
      when v_original.id is null then null
      else jsonb_build_object(
        'id', v_original.id,
        'invoice_number', v_original.invoice_number,
        'date', v_original.date,
        'total', v_original.total
      )
    end,
    'customer', case
      when v_customer.id is null then null
      else jsonb_build_object(
        'id', v_customer.id,
        'code', v_customer.code,
        'name_ar', v_customer.name_ar,
        'name_en', v_customer.name_en
      )
    end,
    'supplier', case
      when v_supplier.id is null then null
      else jsonb_build_object(
        'id', v_supplier.id,
        'code', v_supplier.code,
        'name_ar', v_supplier.name_ar,
        'name_en', v_supplier.name_en
      )
    end,
    'warehouse', case
      when v_warehouse.id is null then null
      else jsonb_build_object(
        'id', v_warehouse.id,
        'name_ar', v_warehouse.name_ar,
        'name_en', v_warehouse.name_en
      )
    end,
    'currency', jsonb_build_object(
      'code', v_currency_code,
      'symbol', v_currency_symbol,
      'decimal_places', v_currency_places
    ),
    'journal_entry_id', v_invoice.journal_entry_id,
    'reversal_journal_entry_id', v_invoice.reversal_journal_entry_id,
    'confirmed_at', v_invoice.confirmed_at,
    'cancelled_at', v_invoice.cancelled_at,
    'lines', v_lines,
    'credit_allocations', v_allocations
  );
end;
$$;

comment on function public.get_return_invoice_detail(uuid) is
  'M7.5: Return invoice detail with lines, original reference, and credit allocations.';

create or replace function public.list_returnable_invoice_lines(p_original_invoice_id uuid)
returns table (
  original_line_id uuid,
  line_order int,
  product_id uuid,
  product_unit_id uuid,
  original_qty numeric(15, 3),
  returned_qty numeric(15, 3),
  returnable_qty numeric(15, 3),
  unit_price numeric(15, 3),
  discount_pct numeric(5, 2),
  cost_price numeric(15, 3),
  is_serialized boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_invoice public.invoices%rowtype;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_return_invoice_view();

  select * into v_invoice
  from public.invoices i
  where i.id = p_original_invoice_id
    and i.tenant_id = v_tenant_id;

  if not found
    or v_invoice.type not in ('sales', 'purchase')
    or v_invoice.status not in ('confirmed', 'partially_paid', 'paid') then
    raise exception 'validation_failed';
  end if;

  return query
  select
    il.id as original_line_id,
    il.line_order,
    il.product_id,
    il.product_unit_id,
    il.qty as original_qty,
    public.get_line_returned_qty(v_tenant_id, il.id) as returned_qty,
    (il.qty - public.get_line_returned_qty(v_tenant_id, il.id))::numeric(15, 3) as returnable_qty,
    il.unit_price,
    il.discount_pct,
    il.cost_price,
    coalesce(p.is_serialized, false) as is_serialized
  from public.invoice_lines il
  join public.products p
    on p.id = il.product_id
    and p.tenant_id = il.tenant_id
  where il.invoice_id = p_original_invoice_id
    and il.tenant_id = v_tenant_id
  order by il.line_order;
end;
$$;

comment on function public.list_returnable_invoice_lines(uuid) is
  'M7.5: Original invoice lines with returned and returnable quantities.';

create or replace function public.list_available_party_credits(
  p_party_id uuid,
  p_direction text
)
returns table (
  return_invoice_id uuid,
  return_invoice_number text,
  return_type public.invoice_type,
  return_date date,
  original_invoice_id uuid,
  original_invoice_number text,
  total numeric(15, 3),
  credit_remaining numeric(15, 3)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_return_type public.invoice_type;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_return_invoice_view();

  if p_direction not in ('sales', 'purchase') then
    raise exception 'validation_failed';
  end if;

  v_return_type := case
    when p_direction = 'sales' then 'sales_return'::public.invoice_type
    else 'purchase_return'::public.invoice_type
  end;

  return query
  select
    i.id as return_invoice_id,
    i.invoice_number as return_invoice_number,
    i.type as return_type,
    i.date as return_date,
    i.original_invoice_id,
    orig.invoice_number as original_invoice_number,
    i.total,
    public.get_return_credit_remaining(v_tenant_id, i.id) as credit_remaining
  from public.invoices i
  left join public.invoices orig
    on orig.id = i.original_invoice_id
    and orig.tenant_id = i.tenant_id
  where i.tenant_id = v_tenant_id
    and i.type = v_return_type
    and i.status = 'confirmed'
    and (
      (p_direction = 'sales' and i.customer_id = p_party_id)
      or (p_direction = 'purchase' and i.supplier_id = p_party_id)
    )
    and public.get_return_credit_remaining(v_tenant_id, i.id) > 0
  order by i.date, i.invoice_number, i.id;
end;
$$;

comment on function public.list_available_party_credits(uuid, text) is
  'M7.5: Confirmed return invoices with remaining party credit, FIFO order.';

-- ===========================================================================
-- Section 8: ACL
-- ===========================================================================

revoke all on function public.resolve_system_sales_returns_account(uuid)
  from public, anon, authenticated;
revoke all on function public.resolve_system_customer_credit_account(uuid)
  from public, anon, authenticated;
revoke all on function public.resolve_system_supplier_credit_receivable_account(uuid)
  from public, anon, authenticated;
revoke all on function public.assert_return_invoice_view()
  from public, anon, authenticated;
revoke all on function public.normalize_return_invoice_payload(jsonb)
  from public, anon, authenticated;
revoke all on function public.compute_return_invoice_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function public.normalize_cancel_return_invoice_payload(uuid, text)
  from public, anon, authenticated;
revoke all on function public.compute_cancel_return_invoice_payload_hash(uuid, text)
  from public, anon, authenticated;
revoke all on function public.normalize_apply_return_credit_payload(uuid, uuid, numeric)
  from public, anon, authenticated;
revoke all on function public.compute_apply_return_credit_payload_hash(uuid, uuid, numeric)
  from public, anon, authenticated;
revoke all on function public.get_line_returned_qty(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.assert_return_qty_allowed(uuid, uuid, numeric)
  from public, anon, authenticated;
revoke all on function public.get_invoice_credit_allocated_amount(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.get_invoice_effective_outstanding(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.get_return_credit_remaining(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.apply_inventory_restore_wac_internal(uuid, uuid, numeric, numeric)
  from public, anon, authenticated;
revoke all on function public.calc_return_line_snapshots(uuid, uuid, jsonb, boolean)
  from public, anon, authenticated;
revoke all on function public.enforce_return_line_linkage()
  from public, anon, authenticated;

grant execute on function public.record_sales_return(jsonb, uuid) to authenticated;
grant execute on function public.record_purchase_return(jsonb, uuid) to authenticated;
grant execute on function public.cancel_return_invoice(uuid, text, uuid) to authenticated;
grant execute on function public.apply_return_credit_to_invoice(uuid, uuid, numeric(15, 3), uuid)
  to authenticated;
grant execute on function public.record_customer_refund_voucher(uuid, jsonb, uuid) to authenticated;
grant execute on function public.record_supplier_refund_receipt(uuid, jsonb, uuid) to authenticated;
grant execute on function public.list_return_invoices(uuid, text, text, date, date, text, integer, integer)
  to authenticated;
grant execute on function public.get_return_invoice_detail(uuid) to authenticated;
grant execute on function public.list_returnable_invoice_lines(uuid) to authenticated;
grant execute on function public.list_available_party_credits(uuid, text) to authenticated;
