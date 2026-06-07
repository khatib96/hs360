-- Phase 5 M2: asset identity, serial settings, scan resolver, unit events, timeline.
-- Depends on 054_phase_5_finance_foundation.sql.

-- ---------------------------------------------------------------------------
-- 1. SKU sequence + auto-generation + immutability
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
    ('SKU', 'SKU')
) as v(sequence_key, prefix)
on conflict (tenant_id, sequence_key) do nothing;

create or replace function public.generate_product_sku_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.sku is null or btrim(new.sku) = '' then
    new.sku := public.next_document_number('SKU');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_generate_product_sku_on_insert on public.products;
create trigger trg_generate_product_sku_on_insert
  before insert on public.products
  for each row execute function public.generate_product_sku_on_insert();

create or replace function public.enforce_product_sku_immutability()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.sku is distinct from old.sku then
    raise exception 'immutable_column';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_product_sku_immutability on public.products;
create trigger trg_enforce_product_sku_immutability
  before update on public.products
  for each row execute function public.enforce_product_sku_immutability();

comment on function public.generate_product_sku_on_insert() is
  'M2: Auto-generate internal SKU via document_sequences when omitted on product insert.';

-- ---------------------------------------------------------------------------
-- 2. Serial settings + barcode uniqueness
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'serial_number_mode') then
    create type public.serial_number_mode as enum ('manual', 'automatic', 'mixed');
  end if;
end $$;

alter table public.tenant_settings
  add column if not exists serial_number_mode public.serial_number_mode not null default 'manual',
  add column if not exists serial_number_prefix text,
  add column if not exists serial_number_padding int not null default 6;

alter table public.tenant_settings
  drop constraint if exists chk_tenant_settings_serial_number_padding;

alter table public.tenant_settings
  add constraint chk_tenant_settings_serial_number_padding
    check (serial_number_padding >= 1);

create unique index if not exists ux_products_tenant_barcode
  on public.products (tenant_id, lower(btrim(barcode)))
  where barcode is not null and btrim(barcode) <> '';

create unique index if not exists ux_product_units_tenant_barcode
  on public.product_units (tenant_id, lower(btrim(barcode)))
  where barcode is not null and btrim(barcode) <> '';

-- ---------------------------------------------------------------------------
-- 3. Composite FK prerequisite for unit_events.service_location_id
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.customer_service_locations'::regclass
      and conname = 'ux_custloc_tenant_id'
  ) then
    alter table public.customer_service_locations
      add constraint ux_custloc_tenant_id unique (tenant_id, id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. unit_events table
-- ---------------------------------------------------------------------------
create table if not exists public.unit_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  product_unit_id uuid not null,
  event_type text not null,
  occurred_at timestamptz not null default now(),
  warehouse_id uuid,
  customer_id uuid,
  service_location_id uuid,
  contract_id uuid,
  reference_table text,
  reference_id uuid,
  notes text,
  metadata_json jsonb,
  created_by uuid references auth.users (id),
  created_at timestamptz default now(),
  constraint ux_unit_events_tenant_id unique (tenant_id, id),
  constraint fk_unit_events_product_unit
    foreign key (tenant_id, product_unit_id)
    references public.product_units (tenant_id, id) on delete cascade,
  constraint fk_unit_events_warehouse
    foreign key (tenant_id, warehouse_id)
    references public.warehouses (tenant_id, id),
  constraint fk_unit_events_customer
    foreign key (tenant_id, customer_id)
    references public.customers (tenant_id, id),
  constraint fk_unit_events_service_location
    foreign key (tenant_id, service_location_id)
    references public.customer_service_locations (tenant_id, id)
);

create index if not exists idx_unit_events_tenant_unit
  on public.unit_events (tenant_id, product_unit_id, occurred_at desc);

alter table public.unit_events enable row level security;

drop policy if exists unit_events_select on public.unit_events;
create policy unit_events_select on public.unit_events
  for select using (
    tenant_id = public.current_tenant_id()
    and public.user_has_permission('product_units.view')
  );

grant select on public.unit_events to authenticated;

-- ---------------------------------------------------------------------------
-- 5. product_units composite FK hardening
-- ---------------------------------------------------------------------------
alter table public.product_units
  drop constraint if exists product_units_current_warehouse_id_fkey,
  drop constraint if exists fk_product_units_current_customer;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'fk_product_units_current_warehouse_tenant'
  ) then
    alter table public.product_units
      add constraint fk_product_units_current_warehouse_tenant
        foreign key (tenant_id, current_warehouse_id)
        references public.warehouses (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'fk_product_units_current_customer_tenant'
  ) then
    alter table public.product_units
      add constraint fk_product_units_current_customer_tenant
        foreign key (tenant_id, current_customer_id)
        references public.customers (tenant_id, id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Serialized stock reconciliation RPCs
-- ---------------------------------------------------------------------------
create or replace function public.preview_serialized_stock_reconciliation(
  p_product_id uuid,
  p_warehouse_id uuid
)
returns table (
  qty_available numeric,
  physical_units_count bigint,
  difference bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_qty numeric(15, 3);
  v_count bigint;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('product_units.view') then
    raise exception 'permission_denied';
  end if;

  select coalesce(ib.qty_available, 0)
  into v_qty
  from public.inventory_balances ib
  where ib.tenant_id = v_tenant_id
    and ib.product_id = p_product_id
    and ib.warehouse_id = p_warehouse_id;

  if not found then
    v_qty := 0;
  end if;

  select count(*)
  into v_count
  from public.product_units pu
  where pu.tenant_id = v_tenant_id
    and pu.product_id = p_product_id
    and pu.current_warehouse_id = p_warehouse_id
    and pu.status in ('available_new', 'available_used');

  qty_available := v_qty;
  physical_units_count := v_count;
  difference := (v_qty::bigint - v_count);
  return next;
end;
$$;

create or replace function public.reconcile_serialized_stock(
  p_product_id uuid,
  p_warehouse_id uuid,
  p_serials jsonb,
  p_reason text
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_is_serialized boolean;
  v_qty numeric(15, 3);
  v_count bigint;
  v_difference bigint;
  v_serial_count int;
  v_elem jsonb;
  v_serial text;
  v_serial_key text;
  v_seen text[] := '{}';
  v_unit_id uuid;
  v_created_ids uuid[] := '{}';
  v_i int;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not (
    public.is_manager()
    or public.user_has_permission('product_units.reconcile_serials')
  ) then
    raise exception 'permission_denied';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'validation_failed';
  end if;

  if p_serials is null or jsonb_typeof(p_serials) <> 'array' then
    raise exception 'validation_failed';
  end if;

  select p.is_serialized
  into v_is_serialized
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = v_tenant_id
    and p.is_active = true
  for update;

  if not found or not coalesce(v_is_serialized, false) then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1
    from public.warehouses w
    where w.id = p_warehouse_id
      and w.tenant_id = v_tenant_id
      and w.is_active = true
  ) then
    raise exception 'validation_failed';
  end if;

  select coalesce(ib.qty_available, 0)
  into v_qty
  from public.inventory_balances ib
  where ib.tenant_id = v_tenant_id
    and ib.product_id = p_product_id
    and ib.warehouse_id = p_warehouse_id;

  if not found then
    v_qty := 0;
  end if;

  select count(*)
  into v_count
  from public.product_units pu
  where pu.tenant_id = v_tenant_id
    and pu.product_id = p_product_id
    and pu.current_warehouse_id = p_warehouse_id
    and pu.status in ('available_new', 'available_used');

  v_difference := v_qty::bigint - v_count;
  v_serial_count := jsonb_array_length(p_serials);

  if v_difference <= 0 then
    raise exception 'validation_failed';
  end if;

  if v_serial_count <> v_difference then
    raise exception 'validation_failed';
  end if;

  for v_i in 0 .. (v_serial_count - 1) loop
    v_elem := p_serials -> v_i;
    if jsonb_typeof(v_elem) <> 'string' then
      raise exception 'validation_failed';
    end if;

    v_serial := btrim(v_elem #>> '{}');
    if v_serial = '' then
      raise exception 'validation_failed';
    end if;

    v_serial_key := lower(v_serial);
    if v_serial_key = any (v_seen) then
      raise exception 'duplicate_serial';
    end if;
    v_seen := array_append(v_seen, v_serial_key);

    if exists (
      select 1
      from public.product_units pu
      where pu.tenant_id = v_tenant_id
        and lower(btrim(pu.serial_number)) = v_serial_key
    ) then
      raise exception 'duplicate_serial';
    end if;
  end loop;

  for v_i in 0 .. (v_serial_count - 1) loop
    v_serial := btrim((p_serials -> v_i) #>> '{}');
    v_unit_id := gen_random_uuid();

    insert into public.product_units (
      id,
      tenant_id,
      product_id,
      serial_number,
      status,
      current_warehouse_id,
      health_status,
      acquired_at
    )
    values (
      v_unit_id,
      v_tenant_id,
      p_product_id,
      v_serial,
      'available_new',
      p_warehouse_id,
      'good',
      current_date
    );

    insert into public.unit_events (
      tenant_id,
      product_unit_id,
      event_type,
      occurred_at,
      warehouse_id,
      notes,
      metadata_json,
      created_by
    )
    values (
      v_tenant_id,
      v_unit_id,
      'reconciled',
      now(),
      p_warehouse_id,
      btrim(p_reason),
      jsonb_build_object(
        'serial_number', v_serial,
        'reconciliation_reason', btrim(p_reason)
      ),
      auth.uid()
    );

    v_created_ids := array_append(v_created_ids, v_unit_id);
  end loop;

  return v_created_ids;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Serial correction RPC
-- ---------------------------------------------------------------------------
create or replace function public.correct_product_unit_serial(
  p_unit_id uuid,
  p_new_serial text,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_old_serial text;
  v_product_id uuid;
  v_new_serial text;
  v_new_key text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('product_units.correct_serial') then
    raise exception 'permission_denied';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'validation_failed';
  end if;

  v_new_serial := btrim(p_new_serial);
  if v_new_serial = '' then
    raise exception 'validation_failed';
  end if;
  v_new_key := lower(v_new_serial);

  select pu.serial_number, pu.product_id
  into v_old_serial, v_product_id
  from public.product_units pu
  where pu.id = p_unit_id
    and pu.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if lower(btrim(v_old_serial)) = v_new_key then
    raise exception 'validation_failed';
  end if;

  if exists (
    select 1
    from public.product_units pu
    where pu.tenant_id = v_tenant_id
      and pu.id <> p_unit_id
      and lower(btrim(pu.serial_number)) = v_new_key
  ) then
    raise exception 'duplicate_serial';
  end if;

  update public.product_units
  set
    serial_number = v_new_serial,
    updated_at = now()
  where id = p_unit_id
    and tenant_id = v_tenant_id
    and product_id = v_product_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  insert into public.unit_events (
    tenant_id,
    product_unit_id,
    event_type,
    occurred_at,
    notes,
    metadata_json,
    created_by
  )
  values (
    v_tenant_id,
    p_unit_id,
    'serial_correction',
    now(),
    btrim(p_reason),
    jsonb_build_object(
      'old_serial', v_old_serial,
      'new_serial', v_new_serial,
      'reason', btrim(p_reason)
    ),
    auth.uid()
  );

  return p_unit_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Scan resolver RPC
-- ---------------------------------------------------------------------------
create or replace function public.resolve_scan_code(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_code text;
  v_match_count int;
  v_unit record;
  v_product record;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  v_code := btrim(p_code);
  if v_code = '' then
    raise exception 'validation_failed';
  end if;

  -- Priority 1: product unit barcode
  if not public.user_has_permission('product_units.view') then
    raise exception 'permission_denied';
  end if;

  select count(*)
  into v_match_count
  from public.product_units pu
  where pu.tenant_id = v_tenant_id
    and pu.barcode is not null
    and btrim(pu.barcode) <> ''
    and lower(btrim(pu.barcode)) = lower(v_code);

  if v_match_count > 1 then
    raise exception 'scan_ambiguous';
  end if;

  if v_match_count = 1 then
    select
      pu.id,
      pu.product_id,
      coalesce(nullif(btrim(pu.barcode), ''), pu.serial_number) as display_code,
      pu.status in ('available_new', 'available_used') as is_active_or_available
    into v_unit
    from public.product_units pu
    where pu.tenant_id = v_tenant_id
      and pu.barcode is not null
      and btrim(pu.barcode) <> ''
      and lower(btrim(pu.barcode)) = lower(v_code);

    return jsonb_build_object(
      'kind', 'product_unit',
      'id', v_unit.id,
      'product_id', v_unit.product_id,
      'matched_by', 'unit_barcode',
      'display_code', v_unit.display_code,
      'is_active_or_available', v_unit.is_active_or_available
    );
  end if;

  -- Priority 2: product barcode
  if not public.user_has_permission('products.view') then
    raise exception 'permission_denied';
  end if;

  select count(*)
  into v_match_count
  from public.products p
  where p.tenant_id = v_tenant_id
    and p.barcode is not null
    and btrim(p.barcode) <> ''
    and lower(btrim(p.barcode)) = lower(v_code);

  if v_match_count > 1 then
    raise exception 'scan_ambiguous';
  end if;

  if v_match_count = 1 then
    select
      p.id,
      p.id as product_id,
      coalesce(nullif(btrim(p.barcode), ''), p.sku) as display_code,
      coalesce(p.is_active, false) as is_active_or_available
    into v_product
    from public.products p
    where p.tenant_id = v_tenant_id
      and p.barcode is not null
      and btrim(p.barcode) <> ''
      and lower(btrim(p.barcode)) = lower(v_code);

    return jsonb_build_object(
      'kind', 'product',
      'id', v_product.id,
      'product_id', v_product.product_id,
      'matched_by', 'product_barcode',
      'display_code', v_product.display_code,
      'is_active_or_available', v_product.is_active_or_available
    );
  end if;

  -- Priority 3: product unit serial number
  select count(*)
  into v_match_count
  from public.product_units pu
  where pu.tenant_id = v_tenant_id
    and lower(btrim(pu.serial_number)) = lower(v_code);

  if v_match_count > 1 then
    raise exception 'scan_ambiguous';
  end if;

  if v_match_count = 1 then
    select
      pu.id,
      pu.product_id,
      pu.serial_number as display_code,
      pu.status in ('available_new', 'available_used') as is_active_or_available
    into v_unit
    from public.product_units pu
    where pu.tenant_id = v_tenant_id
      and lower(btrim(pu.serial_number)) = lower(v_code);

    return jsonb_build_object(
      'kind', 'product_unit',
      'id', v_unit.id,
      'product_id', v_unit.product_id,
      'matched_by', 'serial_number',
      'display_code', v_unit.display_code,
      'is_active_or_available', v_unit.is_active_or_available
    );
  end if;

  raise exception 'scan_not_found';
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Unit timeline view
-- ---------------------------------------------------------------------------
create or replace view public.v_unit_timeline
with (security_invoker = true) as
  -- Acquisition
  select
    pu.tenant_id,
    pu.id as product_unit_id,
    'acquisition'::text as event_type,
    coalesce(pu.acquired_at::timestamptz, pu.created_at, now()) as occurred_at,
    'product_units'::text as source_table,
    pu.id as source_id,
    pu.current_warehouse_id as warehouse_id,
    pu.current_customer_id as customer_id,
    pu.current_service_location_id as service_location_id,
    pu.current_contract_id as contract_id,
    'unit_timeline.acquisition'::text as title_key,
    pu.notes,
    null::jsonb as metadata_json
  from public.product_units pu

  union all

  -- Purchase invoice link
  select
    pu.tenant_id,
    pu.id as product_unit_id,
    'purchase_invoice'::text as event_type,
    coalesce(i.confirmed_at, i.date::timestamptz, pu.acquired_at::timestamptz) as occurred_at,
    'invoices'::text as source_table,
    i.id as source_id,
    i.warehouse_id,
    i.customer_id,
    null::uuid as service_location_id,
    null::uuid as contract_id,
    'unit_timeline.purchase_invoice'::text as title_key,
    i.notes,
    jsonb_build_object(
      'invoice_number', i.invoice_number,
      'invoice_type', i.type,
      'invoice_status', i.status
    ) as metadata_json
  from public.product_units pu
  join public.invoices i
    on i.tenant_id = pu.tenant_id
    and i.id = pu.purchase_invoice_id
  where pu.purchase_invoice_id is not null

  union all

  -- Inventory movements
  select
    im.tenant_id,
    im.product_unit_id,
    im.movement_type::text as event_type,
    im.occurred_at,
    'inventory_movements'::text as source_table,
    im.id as source_id,
    im.warehouse_id,
    null::uuid as customer_id,
    null::uuid as service_location_id,
    null::uuid as contract_id,
    'unit_timeline.inventory_movement'::text as title_key,
    im.notes,
    jsonb_build_object(
      'movement_type', im.movement_type,
      'qty', im.qty,
      'unit_cost', im.unit_cost
    ) as metadata_json
  from public.inventory_movements im
  where im.product_unit_id is not null

  union all

  -- Manual / system unit events
  select
    ue.tenant_id,
    ue.product_unit_id,
    ue.event_type,
    ue.occurred_at,
    'unit_events'::text as source_table,
    ue.id as source_id,
    ue.warehouse_id,
    ue.customer_id,
    ue.service_location_id,
    ue.contract_id,
    ('unit_timeline.' || ue.event_type)::text as title_key,
    ue.notes,
    ue.metadata_json
  from public.unit_events ue

  union all

  -- Future: contracts (placeholder structure, no rows until wired)
  select
    pu.tenant_id,
    pu.id as product_unit_id,
    'contract'::text as event_type,
    c.created_at as occurred_at,
    'contracts'::text as source_table,
    c.id as source_id,
    null::uuid as warehouse_id,
    c.customer_id,
    c.service_location_id,
    c.id as contract_id,
    'unit_timeline.contract'::text as title_key,
    c.notes,
    jsonb_build_object('contract_number', c.contract_number, 'status', c.status) as metadata_json
  from public.product_units pu
  join public.contracts c
    on c.tenant_id = pu.tenant_id
    and c.id = pu.current_contract_id
  where false

  union all

  -- Future: visits (placeholder)
  select
    pu.tenant_id,
    pu.id as product_unit_id,
    'visit'::text as event_type,
    coalesce(v.started_at, v.scheduled_date::timestamptz) as occurred_at,
    'visits'::text as source_table,
    v.id as source_id,
    null::uuid as warehouse_id,
    v.customer_id,
    v.service_location_id,
    v.contract_id,
    'unit_timeline.visit'::text as title_key,
    v.notes,
    jsonb_build_object('visit_type', v.type, 'status', v.status) as metadata_json
  from public.product_units pu
  join public.visits v on false
  where false

  union all

  -- Future: maintenance (placeholder)
  select
    pu.tenant_id,
    pu.id as product_unit_id,
    'maintenance'::text as event_type,
    mr.reported_at as occurred_at,
    'maintenance_records'::text as source_table,
    mr.id as source_id,
    null::uuid as warehouse_id,
    null::uuid as customer_id,
    null::uuid as service_location_id,
    null::uuid as contract_id,
    'unit_timeline.maintenance'::text as title_key,
    mr.notes,
    jsonb_build_object('status', mr.status) as metadata_json
  from public.product_units pu
  join public.maintenance_records mr on false
  where false;

grant select on public.v_unit_timeline to authenticated;

comment on view public.v_unit_timeline is
  'M2: Unified product unit history (acquisition, invoice, movements, unit events). Future modules use placeholder unions.';

-- ---------------------------------------------------------------------------
-- 10. ACL hygiene
-- ---------------------------------------------------------------------------
revoke all on function public.generate_product_sku_on_insert() from public, anon, authenticated;

revoke all on function public.preview_serialized_stock_reconciliation(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.reconcile_serialized_stock(uuid, uuid, jsonb, text)
  from public, anon, authenticated;
revoke all on function public.correct_product_unit_serial(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.resolve_scan_code(text)
  from public, anon, authenticated;

grant execute on function public.preview_serialized_stock_reconciliation(uuid, uuid) to authenticated;
grant execute on function public.reconcile_serialized_stock(uuid, uuid, jsonb, text) to authenticated;
grant execute on function public.correct_product_unit_serial(uuid, text, text) to authenticated;
grant execute on function public.resolve_scan_code(text) to authenticated;
