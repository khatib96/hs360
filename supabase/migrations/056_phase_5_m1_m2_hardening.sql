-- Phase 5 M1/M2 hardening: ACL, journal immutability, audit, reconcile, metadata, scan.

-- ---------------------------------------------------------------------------
-- 1. Secure document_sequences and unit_events
-- ---------------------------------------------------------------------------
revoke all on table public.document_sequences from public, anon, authenticated;

alter table public.document_sequences enable row level security;

revoke all on table public.unit_events from public, anon, authenticated;
grant select on table public.unit_events to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Journal immutability, posting invariants, and concurrency protection
-- ---------------------------------------------------------------------------
create or replace function public.validate_journal_entry_posting()
returns trigger
language plpgsql
as $$
declare
  v_line_count int;
  v_bad_side_count int;
  v_bad_tenant_count int;
  v_bad_account_tenant_count int;
  v_total_debit numeric(15, 3);
  v_total_credit numeric(15, 3);
begin
  if tg_op = 'INSERT' and coalesce(new.is_posted, false) = true then
    raise exception 'journal_entry_cannot_be_created_posted';
  end if;

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

    select coalesce(sum(jl.debit), 0), coalesce(sum(jl.credit), 0)
    into v_total_debit, v_total_credit
    from public.journal_lines jl
    where jl.journal_entry_id = new.id;

    if v_total_debit <> v_total_credit then
      raise exception 'journal_entry_not_balanced';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_journal_entry_posting on public.journal_entries;

create trigger trg_validate_journal_entry_posting
  before insert or update on public.journal_entries
  for each row execute function public.validate_journal_entry_posting();

create or replace function public.enforce_posted_journal_line_immutability()
returns trigger
language plpgsql
as $$
declare
  v_entry_ids uuid[];
  v_is_posted boolean;
  v_entry_id uuid;
begin
  if tg_op = 'INSERT' then
    v_entry_ids := array[new.journal_entry_id];
  elsif tg_op = 'DELETE' then
    v_entry_ids := array[old.journal_entry_id];
  else
    if old.journal_entry_id = new.journal_entry_id then
      v_entry_ids := array[new.journal_entry_id];
    elsif old.journal_entry_id < new.journal_entry_id then
      v_entry_ids := array[old.journal_entry_id, new.journal_entry_id];
    else
      v_entry_ids := array[new.journal_entry_id, old.journal_entry_id];
    end if;
  end if;

  for v_entry_id in
    select je.id
    from public.journal_entries je
    where je.id = any (v_entry_ids)
    order by je.id
    for update
  loop
    select coalesce(je.is_posted, false)
    into v_is_posted
    from public.journal_entries je
    where je.id = v_entry_id;

    if v_is_posted then
      raise exception 'posted_journal_line_immutable';
    end if;
  end loop;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_enforce_posted_journal_line_immutability on public.journal_lines;

create trigger trg_enforce_posted_journal_line_immutability
  before insert or update or delete on public.journal_lines
  for each row execute function public.enforce_posted_journal_line_immutability();

-- ---------------------------------------------------------------------------
-- 3. Repair audit_log_row() with JSONB extraction
-- ---------------------------------------------------------------------------
create or replace function public.audit_log_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_entity_id uuid;
  v_action text;
  v_before jsonb;
  v_after jsonb;
  v_row jsonb;
begin
  v_action := lower(tg_op);

  v_before := case
    when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old)
    else null
  end;

  v_after := case
    when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new)
    else null
  end;

  v_row := coalesce(v_after, v_before);
  v_tenant_id := (v_row ->> 'tenant_id')::uuid;

  v_entity_id := case
    when tg_table_name = 'tenant_settings' then v_tenant_id
    else (v_row ->> 'id')::uuid
  end;

  insert into public.audit_log (
    tenant_id,
    actor_id,
    actor_account_type,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    v_tenant_id,
    auth.uid(),
    public.current_account_type()::text,
    v_action,
    tg_table_name,
    v_entity_id,
    v_before,
    v_after
  );

  return coalesce(new, old);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Harden reconciliation RPCs
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
  v_qty_rented numeric(15, 3);
  v_qty_trial numeric(15, 3);
  v_qty_maintenance numeric(15, 3);
  v_qty_damaged numeric(15, 3);
  v_count bigint;
  v_difference bigint;
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

  if not exists (
    select 1
    from public.products p
    where p.id = p_product_id
      and p.tenant_id = v_tenant_id
      and p.is_active = true
      and p.is_serialized = true
  ) then
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

  select
    coalesce(ib.qty_available, 0),
    coalesce(ib.qty_rented, 0),
    coalesce(ib.qty_trial, 0),
    coalesce(ib.qty_maintenance, 0),
    coalesce(ib.qty_damaged, 0)
  into
    v_qty,
    v_qty_rented,
    v_qty_trial,
    v_qty_maintenance,
    v_qty_damaged
  from public.inventory_balances ib
  where ib.tenant_id = v_tenant_id
    and ib.product_id = p_product_id
    and ib.warehouse_id = p_warehouse_id;

  if not found then
    v_qty := 0;
    v_qty_rented := 0;
    v_qty_trial := 0;
    v_qty_maintenance := 0;
    v_qty_damaged := 0;
  end if;

  if v_qty < 0 then
    raise exception 'serialized_qty_cannot_be_negative';
  end if;

  if v_qty <> trunc(v_qty) then
    raise exception 'serialized_qty_must_be_whole';
  end if;

  if v_qty_rented <> 0
    or v_qty_trial <> 0
    or v_qty_maintenance <> 0
    or v_qty_damaged <> 0
  then
    raise exception 'serialized_reconciliation_non_available_buckets';
  end if;

  select count(*)
  into v_count
  from public.product_units pu
  where pu.tenant_id = v_tenant_id
    and pu.product_id = p_product_id
    and pu.current_warehouse_id = p_warehouse_id
    and pu.status in ('available_new', 'available_used');

  if v_count > trunc(v_qty)::bigint then
    raise exception 'serialized_unit_count_exceeds_balance';
  end if;

  v_difference := trunc(v_qty)::bigint - v_count;

  qty_available := v_qty;
  physical_units_count := v_count;
  difference := v_difference;
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
  v_qty_rented numeric(15, 3);
  v_qty_trial numeric(15, 3);
  v_qty_maintenance numeric(15, 3);
  v_qty_damaged numeric(15, 3);
  v_count bigint;
  v_count_before bigint;
  v_difference bigint;
  v_serial_count int;
  v_elem jsonb;
  v_serial text;
  v_serial_key text;
  v_seen text[] := array[]::text[];
  v_unit_id uuid;
  v_created_ids uuid[] := array[]::uuid[];
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

  select
    coalesce(ib.qty_available, 0),
    coalesce(ib.qty_rented, 0),
    coalesce(ib.qty_trial, 0),
    coalesce(ib.qty_maintenance, 0),
    coalesce(ib.qty_damaged, 0)
  into
    v_qty,
    v_qty_rented,
    v_qty_trial,
    v_qty_maintenance,
    v_qty_damaged
  from public.inventory_balances ib
  where ib.tenant_id = v_tenant_id
    and ib.product_id = p_product_id
    and ib.warehouse_id = p_warehouse_id
  for update;

  if not found then
    v_qty := 0;
    v_qty_rented := 0;
    v_qty_trial := 0;
    v_qty_maintenance := 0;
    v_qty_damaged := 0;
  end if;

  if v_qty < 0 then
    raise exception 'serialized_qty_cannot_be_negative';
  end if;

  if v_qty <> trunc(v_qty) then
    raise exception 'serialized_qty_must_be_whole';
  end if;

  if v_qty_rented <> 0
    or v_qty_trial <> 0
    or v_qty_maintenance <> 0
    or v_qty_damaged <> 0
  then
    raise exception 'serialized_reconciliation_non_available_buckets';
  end if;

  select count(*)
  into v_count
  from public.product_units pu
  where pu.tenant_id = v_tenant_id
    and pu.product_id = p_product_id
    and pu.current_warehouse_id = p_warehouse_id
    and pu.status in ('available_new', 'available_used');

  v_count_before := v_count;

  if v_count > trunc(v_qty)::bigint then
    raise exception 'serialized_unit_count_exceeds_balance';
  end if;

  v_difference := trunc(v_qty)::bigint - v_count;

  if v_difference = 0 then
    raise exception 'serialized_reconciliation_not_needed';
  end if;

  v_serial_count := jsonb_array_length(p_serials);

  if v_serial_count <> v_difference then
    raise exception 'validation_failed';
  end if;

  for v_serial_idx in 0 .. (v_serial_count - 1) loop
    v_elem := p_serials -> v_serial_idx;
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

  for v_create_idx in 0 .. (v_serial_count - 1) loop
    v_serial := btrim((p_serials -> v_create_idx) #>> '{}');
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
        'reconciliation_reason', btrim(p_reason),
        'qty_available', v_qty,
        'physical_count_before', v_count_before,
        'physical_count_after', v_count_before + v_serial_count,
        'difference', v_difference
      ),
      auth.uid()
    );

    v_created_ids := array_append(v_created_ids, v_unit_id);
  end loop;

  return v_created_ids;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Confirmation metadata constraints
-- ---------------------------------------------------------------------------
do $$
declare
  v_invoice_confirmed_missing int;
  v_invoice_cancelled_missing int;
  v_voucher_confirmed_missing int;
  v_voucher_cancelled_missing int;
begin
  select count(*)
  into v_invoice_confirmed_missing
  from public.invoices i
  where i.status in ('confirmed', 'partially_paid', 'paid')
    and (i.confirmed_at is null or i.confirmed_by is null);

  if v_invoice_confirmed_missing > 0 then
    raise exception
      'invoice confirmed metadata invalid: % rows missing confirmed_at/confirmed_by',
      v_invoice_confirmed_missing;
  end if;

  select count(*)
  into v_invoice_cancelled_missing
  from public.invoices i
  where i.status = 'cancelled'
    and (
      i.cancelled_at is null
      or i.cancelled_by is null
      or btrim(coalesce(i.cancellation_reason, '')) = ''
    );

  if v_invoice_cancelled_missing > 0 then
    raise exception
      'invoice cancelled metadata invalid: % rows missing actor/reason',
      v_invoice_cancelled_missing;
  end if;

  select count(*)
  into v_voucher_confirmed_missing
  from public.vouchers v
  where v.status = 'confirmed'
    and (v.confirmed_at is null or v.confirmed_by is null);

  if v_voucher_confirmed_missing > 0 then
    raise exception
      'voucher confirmed metadata invalid: % rows missing confirmed_at/confirmed_by',
      v_voucher_confirmed_missing;
  end if;

  select count(*)
  into v_voucher_cancelled_missing
  from public.vouchers v
  where v.status = 'cancelled'
    and (
      v.cancelled_at is null
      or v.cancelled_by is null
      or btrim(coalesce(v.cancellation_reason, '')) = ''
    );

  if v_voucher_cancelled_missing > 0 then
    raise exception
      'voucher cancelled metadata invalid: % rows missing actor/reason',
      v_voucher_cancelled_missing;
  end if;
end $$;

alter table public.invoices
  drop constraint if exists chk_invoices_confirmed_metadata,
  drop constraint if exists chk_invoices_cancelled_metadata;

alter table public.invoices
  add constraint chk_invoices_confirmed_metadata check (
    (
      status in ('confirmed', 'partially_paid', 'paid')
      and confirmed_at is not null
      and confirmed_by is not null
    )
    or status not in ('confirmed', 'partially_paid', 'paid')
  ),
  add constraint chk_invoices_cancelled_metadata check (
    (
      status = 'cancelled'
      and cancelled_at is not null
      and cancelled_by is not null
      and btrim(coalesce(cancellation_reason, '')) <> ''
    )
    or status <> 'cancelled'
  );

alter table public.vouchers
  drop constraint if exists chk_vouchers_cancelled_metadata;

alter table public.vouchers
  add constraint chk_vouchers_confirmed_metadata check (
    (
      status = 'confirmed'
      and confirmed_at is not null
      and confirmed_by is not null
    )
    or status <> 'confirmed'
  ),
  add constraint chk_vouchers_cancelled_metadata check (
    (
      status = 'cancelled'
      and cancelled_at is not null
      and cancelled_by is not null
      and btrim(coalesce(cancellation_reason, '')) <> ''
    )
    or status <> 'cancelled'
  );

-- ---------------------------------------------------------------------------
-- 6. Scan permission policy
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
  v_has_products_view boolean;
  v_has_units_view boolean;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  v_code := btrim(p_code);
  if v_code = '' then
    raise exception 'validation_failed';
  end if;

  v_has_products_view := public.user_has_permission('products.view');
  v_has_units_view := public.user_has_permission('product_units.view');

  if not v_has_products_view and not v_has_units_view then
    raise exception 'permission_denied';
  end if;

  if v_has_units_view then
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
  end if;

  if v_has_products_view then
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
  end if;

  if v_has_units_view then
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
  end if;

  raise exception 'scan_not_found';
end;
$$;
