-- Phase 5 M4.5: inventory accounting internal helpers and posting engine.
-- Depends on 066_phase_5_inventory_accounting_schema.sql and 065 enum migration.

-- ---------------------------------------------------------------------------
-- Account provisioning (strict conflict detection)
-- ---------------------------------------------------------------------------
create or replace function public.resolve_or_insert_inventory_system_account(
  p_tenant_id uuid,
  p_code text,
  p_name_ar text,
  p_name_en text,
  p_type public.account_type,
  p_parent_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.chart_of_accounts%rowtype;
  v_parent_id uuid;
  v_id uuid;
  v_child_count bigint;
begin
  select * into v_existing
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = p_code;

  if found then
    select id into v_parent_id
    from public.chart_of_accounts
    where tenant_id = p_tenant_id
      and code = p_parent_code;

    select count(*) into v_child_count
    from public.chart_of_accounts c
    where c.tenant_id = p_tenant_id
      and c.parent_id = v_existing.id
      and c.is_active = true;

    if v_existing.type <> p_type
      or v_existing.is_system is distinct from true
      or not v_existing.is_active
      or v_existing.related_entity_id is not null
      or v_existing.parent_id is distinct from v_parent_id
      or v_child_count > 0 then
      raise exception 'validation_failed';
    end if;

    return v_existing.id;
  end if;

  select id into v_parent_id
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = p_parent_code;

  if v_parent_id is null then
    raise exception 'validation_failed';
  end if;

  insert into public.chart_of_accounts (
    tenant_id, code, name_ar, name_en, type, parent_id, is_system, is_active
  )
  values (
    p_tenant_id, p_code, p_name_ar, p_name_en, p_type, v_parent_id, true, true
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.resolve_opening_balance_equity_account(p_tenant_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return public.resolve_or_insert_inventory_system_account(
    p_tenant_id,
    '3101',
    'Opening Balance Equity',
    'Opening Balance Equity',
    'equity',
    '3000'
  );
end;
$$;

create or replace function public.provision_tenant_inventory_accounts(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '3101',
    'Opening Balance Equity',
    'Opening Balance Equity', 'equity', '3000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '3102',
    '',
    'Owner''s Capital', 'equity', '3000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '3201',
    '',
    'Owner''s Drawings', 'equity', '3000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '4102',
    '',
    'Inventory Gain', 'income', '4000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '5152',
    '',
    'Inventory Loss / Adjustment', 'expense', '5000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '5901',
    '',
    'Internal Consumption Expense', 'expense', '5000'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Seed system adjustment reasons per tenant
-- ---------------------------------------------------------------------------
create or replace function public.seed_tenant_inventory_adjustment_reasons(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_capital uuid;
  v_gain uuid;
  v_loss uuid;
  v_drawings uuid;
  v_consumption uuid;
begin
  perform public.provision_tenant_inventory_accounts(p_tenant_id);

  select id into v_capital from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '3102';
  select id into v_gain from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '4102';
  select id into v_loss from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '5152';
  select id into v_drawings from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '3201';
  select id into v_consumption from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '5901';

  insert into public.inventory_adjustment_reasons (
    tenant_id, code, name_ar, name_en, direction, account_id,
    requires_cost, allows_wac_fallback, is_system, is_active, allowed_document_types
  )
  values
    (
      p_tenant_id, 'owner_contribution',
      'Owner contribution',
      'Owner contribution', 'stock_in', v_capital,
      true, false, true, true, array['stock_in']
    ),
    (
      p_tenant_id, 'found_surplus',
      'Found surplus',
      'Found surplus', 'stock_in', v_gain,
      false, true, true, true, array['stock_in', 'stock_count']
    ),
    (
      p_tenant_id, 'shrinkage',
      'Shrinkage',
      'Shrinkage', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'damage',
      'Damage',
      'Damage', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'expiry',
      'Expiry',
      'Expiry', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'write_off',
      'Write-off',
      'Write-off', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'owner_withdrawal',
      'Owner withdrawal',
      'Owner withdrawal', 'stock_out', v_drawings,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'internal_consumption',
      'Internal consumption',
      'Internal consumption', 'stock_out', v_consumption,
      false, false, true, true, array['stock_out', 'stock_count']
    )
  on conflict (tenant_id, code) do nothing;
end;
$$;

do $$
declare
  v_tenant_id uuid;
begin
  for v_tenant_id in select id from public.tenants loop
    perform public.seed_tenant_inventory_adjustment_reasons(v_tenant_id);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- WAC helpers (all owned buckets — isolated from purchase WAC)
-- ---------------------------------------------------------------------------
create or replace function public.sum_owned_inventory_qty(
  p_tenant_id uuid,
  p_product_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(
    ib.qty_available + ib.qty_rented + ib.qty_trial + ib.qty_maintenance + ib.qty_damaged
  ), 0)
  from public.inventory_balances ib
  where ib.tenant_id = p_tenant_id
    and ib.product_id = p_product_id;
$$;

create or replace function public.apply_inventory_wac_internal(
  p_tenant_id uuid,
  p_product_id uuid,
  p_incoming_qty numeric,
  p_incoming_total_value numeric
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
  v_unit_cost numeric(15, 3);
  v_new_avg numeric(15, 3);
begin
  if p_incoming_qty is null or p_incoming_qty <= 0 then
    raise exception 'validation_failed';
  end if;

  if p_incoming_total_value is null or p_incoming_total_value < 0 then
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

  v_post_qty := public.sum_owned_inventory_qty(p_tenant_id, p_product_id);
  v_old_qty := v_post_qty - p_incoming_qty;
  v_unit_cost := p_incoming_total_value / p_incoming_qty;

  if v_old_qty <= 0 then
    v_new_avg := v_unit_cost;
  else
    v_new_avg := (
      (v_old_qty * coalesce(v_old_avg_cost, 0)) + p_incoming_total_value
    ) / v_post_qty;
  end if;

  update public.products
  set
    avg_cost = v_new_avg,
    last_purchase_cost = v_unit_cost,
    updated_at = now(),
    updated_by = auth.uid()
  where id = p_product_id
    and tenant_id = p_tenant_id;
end;
$$;

comment on function public.apply_inventory_wac_internal(uuid, uuid, numeric, numeric) is
  'M4.5: WAC using all owned inventory buckets. Isolated from apply_purchase_wac_internal.';

create or replace function public.revert_inventory_wac_internal(
  p_tenant_id uuid,
  p_product_id uuid,
  p_removed_qty numeric,
  p_removed_total_value numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_avg_cost numeric(15, 3);
  v_post_qty numeric(15, 3);
  v_new_avg numeric(15, 3);
begin
  if p_removed_qty is null or p_removed_qty <= 0 then
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

  v_post_qty := public.sum_owned_inventory_qty(p_tenant_id, p_product_id);

  if v_post_qty <= 0 then
    v_new_avg := 0;
  else
    v_new_avg := (
      (v_post_qty * coalesce(v_old_avg_cost, 0)) - p_removed_total_value
    ) / v_post_qty;
    if v_new_avg < 0 then
      v_new_avg := 0;
    end if;
  end if;

  update public.products
  set avg_cost = v_new_avg, updated_at = now(), updated_by = auth.uid()
  where id = p_product_id and tenant_id = p_tenant_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reason resolution
-- ---------------------------------------------------------------------------
create or replace function public.resolve_inventory_reason(
  p_tenant_id uuid,
  p_code text,
  p_direction public.inventory_reason_direction,
  p_document_type text
)
returns public.inventory_adjustment_reasons
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_reason public.inventory_adjustment_reasons%rowtype;
begin
  if p_code is null or btrim(p_code) = '' then
    raise exception 'validation_failed';
  end if;

  select * into v_reason
  from public.inventory_adjustment_reasons r
  where r.tenant_id = p_tenant_id
    and r.code = p_code
    and r.direction = p_direction
    and r.is_active = true;

  if not found then
    raise exception 'validation_failed';
  end if;

  if not (p_document_type = any (v_reason.allowed_document_types)) then
    raise exception 'validation_failed';
  end if;

  return v_reason;
end;
$$;

-- ---------------------------------------------------------------------------
-- Payload guards and normalization helpers
-- ---------------------------------------------------------------------------
create or replace function public.assert_inventory_line_no_client_accounts(p_line jsonb)
returns void
language plpgsql
immutable
as $$
begin
  if p_line ? 'counter_account_id'
    or p_line ? 'account_id'
    or p_line ? 'posting_account_id' then
    raise exception 'validation_failed';
  end if;
end;
$$;

create or replace function public.inventory_doc_sequence_key(p_type public.inventory_document_type)
returns text
language sql
immutable
as $$
  select case p_type
    when 'opening_stock' then 'OS'
    when 'stock_in' then 'STI'
    when 'stock_out' then 'STO'
    when 'stock_count' then 'SC'
  end;
$$;

create or replace function public.inventory_doc_journal_source(p_type public.inventory_document_type)
returns text
language sql
immutable
as $$
  select case p_type
    when 'opening_stock' then 'opening_stock'
    when 'stock_in' then 'inventory_stock_in'
    when 'stock_out' then 'inventory_stock_out'
    when 'stock_count' then 'stock_count'
  end;
$$;

create or replace function public.assert_books_open_for_date(p_tenant_id uuid, p_date date)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_lock date;
begin
  select books_locked_through into v_lock
  from public.tenant_settings
  where tenant_id = p_tenant_id;

  if v_lock is not null and p_date <= v_lock then
    raise exception 'validation_failed';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Core confirm engine
-- ---------------------------------------------------------------------------
create or replace function public.confirm_inventory_document_internal(
  p_document_type public.inventory_document_type,
  p_normalized jsonb,
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
  v_warehouse_id uuid;
  v_document_date date;
  v_notes text;
  v_reason_code text;
  v_gain_reason_code text;
  v_loss_reason_code text;
  v_import_key text;
  v_existing_id uuid;
  v_document_id uuid;
  v_document_number text;
  v_inventory_account uuid;
  v_opening_equity_account uuid;
  v_journal_source text;
  v_sequence_key text;
  v_je_id uuid;
  v_je_number text;
  v_inv_net numeric(15, 3) := 0;
  v_has_financial_effect boolean := false;
  v_line_reason_code text;
  v_line jsonb;
  v_line_order int;
  v_product_id uuid;
  v_qty numeric(15, 3);
  v_counted_qty numeric(15, 3);
  v_system_qty numeric(15, 3);
  v_delta numeric(15, 3);
  v_unit_cost numeric(15, 3);
  v_total_value numeric(15, 3);
  v_avg_cost numeric(15, 3);
  v_is_serialized boolean;
  v_reason public.inventory_adjustment_reasons%rowtype;
  v_counter_account_id uuid;
  v_movement_id uuid;
  v_movement_type public.movement_type;
  v_line_id uuid;
  v_qty_available numeric(15, 3);
  v_unit_elem jsonb;
  v_unit_id uuid;
  v_serial_key text;
  v_seen_serials text[] := '{}';
  v_unit_ids uuid[];
  v_journal_lines jsonb := '[]'::jsonb;
  v_acct_key text;
  v_acct_map jsonb := '{}'::jsonb;
  v_acct_id uuid;
  v_acct_amount numeric(15, 3);
  v_jl_order int := 0;
  v_dist_key text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  v_warehouse_id := (p_normalized ->> 'warehouse_id')::uuid;
  v_document_date := (p_normalized ->> 'date')::date;
  v_notes := nullif(btrim(p_normalized ->> 'notes'), '');
  v_reason_code := nullif(btrim(p_normalized ->> 'reason_code'), '');
  v_gain_reason_code := nullif(btrim(p_normalized ->> 'gain_reason_code'), '');
  v_loss_reason_code := nullif(btrim(p_normalized ->> 'loss_reason_code'), '');
  v_import_key := nullif(btrim(p_normalized ->> 'import_key'), '');

  if v_warehouse_id is null or v_document_date is null or v_notes is null then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_normalized -> 'lines') <> 'array'
    or jsonb_array_length(p_normalized -> 'lines') = 0 then
    raise exception 'validation_failed';
  end if;

  perform public.assert_books_open_for_date(v_tenant_id, v_document_date);

  if not exists (
    select 1 from public.warehouses w
    where w.id = v_warehouse_id and w.tenant_id = v_tenant_id and w.is_active = true
  ) then
    raise exception 'validation_failed';
  end if;

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_finance_idempotency(
    'public.inventory_documents'::regclass,
    p_idempotency_key,
    p_payload_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  if p_document_type = 'opening_stock' and v_import_key is not null then
    if exists (
      select 1 from public.inventory_documents d
      where d.tenant_id = v_tenant_id and d.import_key = v_import_key
    ) then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_document_type = 'stock_count' then
    if v_gain_reason_code is null or v_loss_reason_code is null then
      raise exception 'validation_failed';
    end if;
  elsif p_document_type in ('stock_in', 'stock_out') then
    if v_reason_code is null then
      raise exception 'validation_failed';
    end if;
  end if;

  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);
  v_opening_equity_account := public.resolve_opening_balance_equity_account(v_tenant_id);
  v_sequence_key := public.inventory_doc_sequence_key(p_document_type);
  v_journal_source := public.inventory_doc_journal_source(p_document_type);

  for v_line in
    select value from jsonb_array_elements(p_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    perform public.assert_inventory_line_no_client_accounts(v_line);
    v_product_id := (v_line ->> 'product_id')::uuid;
    if v_product_id is null then
      raise exception 'validation_failed';
    end if;

    perform 1
    from public.products p
    where p.id = v_product_id and p.tenant_id = v_tenant_id and p.is_active = true
    for update;

    if not found then
      raise exception 'validation_failed';
    end if;

    perform 1
    from public.inventory_balances ib
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_warehouse_id
      and ib.product_id = v_product_id
    for update;
  end loop;

  v_document_id := gen_random_uuid();
  v_document_number := public.next_document_number(v_sequence_key);

  perform public.allow_finance_write();

  insert into public.inventory_documents (
    id, tenant_id, document_type, status, document_number, document_date,
    warehouse_id, reason_code, gain_reason_code, loss_reason_code,
    notes, import_key, idempotency_key, idempotency_payload_hash,
    confirmed_by, created_by
  )
  values (
    v_document_id, v_tenant_id, p_document_type, 'confirmed', v_document_number,
    v_document_date, v_warehouse_id, v_reason_code, v_gain_reason_code,
    v_loss_reason_code, v_notes, v_import_key, p_idempotency_key, p_payload_hash,
    auth.uid(), auth.uid()
  );

  for v_line in
    select value from jsonb_array_elements(p_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line ->> 'line_order')::int;
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_counted_qty := null;
    v_reason := null;
    v_line_reason_code := null;
    v_unit_ids := null;

    select p.is_serialized, p.avg_cost
    into v_is_serialized, v_avg_cost
    from public.products p
    where p.id = v_product_id and p.tenant_id = v_tenant_id
    for update;

    select coalesce(ib.qty_available, 0)
    into v_system_qty
    from public.inventory_balances ib
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_warehouse_id
      and ib.product_id = v_product_id;

    if p_document_type = 'stock_count' then
      v_counted_qty := (v_line ->> 'counted_qty')::numeric(15, 3);
      if v_counted_qty is null or v_counted_qty < 0 then
        raise exception 'validation_failed';
      end if;
      v_delta := v_counted_qty - coalesce(v_system_qty, 0);
      v_qty := abs(v_delta);
      if v_delta > 0 then
        v_reason := public.resolve_inventory_reason(
          v_tenant_id, v_gain_reason_code, 'stock_in', 'stock_count'
        );
        v_movement_type := 'adjustment_in';
        v_unit_cost := coalesce(v_avg_cost, 0);
        if v_unit_cost <= 0 then
          raise exception 'validation_failed';
        end if;
      elsif v_delta < 0 then
        v_reason := public.resolve_inventory_reason(
          v_tenant_id, v_loss_reason_code, 'stock_out', 'stock_count'
        );
        v_movement_type := 'adjustment_out';
        v_unit_cost := coalesce(v_avg_cost, 0);
        if v_unit_cost <= 0 then
          raise exception 'validation_failed';
        end if;
      else
        v_movement_type := null;
        v_unit_cost := coalesce(v_avg_cost, 0);
        v_qty := 0;
        v_counter_account_id := v_inventory_account;
      end if;
      if v_delta <> 0 then
        v_counter_account_id := v_reason.account_id;
        v_line_reason_code := v_reason.code;
      end if;
    elsif p_document_type = 'opening_stock' then
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      v_unit_cost := (v_line ->> 'unit_cost')::numeric(15, 3);
      if v_qty is null or v_qty <= 0 or v_unit_cost is null or v_unit_cost < 0 then
        raise exception 'validation_failed';
      end if;
      if exists (
        select 1 from public.inventory_movements m
        where m.tenant_id = v_tenant_id
          and m.warehouse_id = v_warehouse_id
          and m.product_id = v_product_id
      ) then
        raise exception 'validation_failed';
      end if;
      v_delta := v_qty;
      v_system_qty := coalesce(v_system_qty, 0);
      v_movement_type := 'adjustment_in';
      v_counter_account_id := v_opening_equity_account;
      v_line_reason_code := null;
    elsif p_document_type = 'stock_in' then
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      if v_qty is null or v_qty <= 0 then
        raise exception 'validation_failed';
      end if;
      v_reason := public.resolve_inventory_reason(
        v_tenant_id, v_reason_code, 'stock_in', 'stock_in'
      );
      v_counter_account_id := v_reason.account_id;
      v_line_reason_code := v_reason.code;
      if v_line ? 'unit_cost' then
        v_unit_cost := (v_line ->> 'unit_cost')::numeric(15, 3);
      else
        v_unit_cost := null;
      end if;
      if v_reason.requires_cost then
        if v_unit_cost is null or v_unit_cost < 0 then
          raise exception 'validation_failed';
        end if;
      elsif v_reason.allows_wac_fallback then
        if v_unit_cost is null then
          if coalesce(v_avg_cost, 0) <= 0 then
            raise exception 'validation_failed';
          end if;
          v_unit_cost := v_avg_cost;
        elsif v_unit_cost < 0 then
          raise exception 'validation_failed';
        end if;
      else
        if v_unit_cost is null or v_unit_cost < 0 then
          raise exception 'validation_failed';
        end if;
      end if;
      v_delta := v_qty;
      v_movement_type := 'adjustment_in';
    else
      -- stock_out
      if v_line ? 'unit_cost' then
        raise exception 'validation_failed';
      end if;
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      if v_qty is null or v_qty <= 0 then
        raise exception 'validation_failed';
      end if;
      v_reason := public.resolve_inventory_reason(
        v_tenant_id, v_reason_code, 'stock_out', 'stock_out'
      );
      v_counter_account_id := v_reason.account_id;
      v_line_reason_code := v_reason.code;
      v_unit_cost := greatest(coalesce(v_avg_cost, 0), 0);
      v_delta := -v_qty;
      v_movement_type := 'adjustment_out';
      if coalesce(v_system_qty, 0) < v_qty then
        raise exception 'insufficient_stock';
      end if;
    end if;

    if v_delta = 0 then
      v_total_value := 0;
    else
      v_total_value := v_qty * v_unit_cost;
    end if;

    v_unit_ids := null;
    if v_is_serialized and v_delta <> 0 then
      if v_delta > 0 then
        if not (v_line ? 'units')
          or jsonb_typeof(v_line -> 'units') <> 'array'
          or jsonb_array_length(v_line -> 'units') <> v_qty::int then
          raise exception 'validation_failed';
        end if;
        v_unit_ids := '{}'::uuid[];
        for v_unit_elem in select u from jsonb_array_elements(v_line -> 'units') as u loop
          v_serial_key := lower(btrim(v_unit_elem ->> 'serial_number'));
          if v_serial_key is null or v_serial_key = '' then
            raise exception 'validation_failed';
          end if;
          if v_serial_key = any (v_seen_serials) then
            raise exception 'duplicate_serial';
          end if;
          v_seen_serials := array_append(v_seen_serials, v_serial_key);
          v_unit_id := gen_random_uuid();
          insert into public.product_units (
            id, tenant_id, product_id, serial_number, barcode, status,
            current_warehouse_id, purchase_cost, acquired_at
          )
          values (
            v_unit_id, v_tenant_id, v_product_id,
            btrim(v_unit_elem ->> 'serial_number'),
            nullif(btrim(v_unit_elem ->> 'barcode'), ''),
            'available_new', v_warehouse_id, v_unit_cost, v_document_date
          );
          v_unit_ids := array_append(v_unit_ids, v_unit_id);
        end loop;
      else
        if not (v_line ? 'unit_ids')
          or jsonb_typeof(v_line -> 'unit_ids') <> 'array'
          or jsonb_array_length(v_line -> 'unit_ids') <> v_qty::int then
          raise exception 'validation_failed';
        end if;
        v_unit_ids := '{}'::uuid[];
        for v_unit_id in
          select (jsonb_array_elements_text(v_line -> 'unit_ids'))::uuid
        loop
          if not exists (
            select 1 from public.product_units pu
            where pu.id = v_unit_id
              and pu.tenant_id = v_tenant_id
              and pu.product_id = v_product_id
              and pu.current_warehouse_id = v_warehouse_id
              and pu.status in ('available_new', 'available_used')
          ) then
            raise exception 'validation_failed';
          end if;
          update public.product_units
          set status = 'retired', current_warehouse_id = null, updated_at = now()
          where id = v_unit_id and tenant_id = v_tenant_id;
          v_unit_ids := array_append(v_unit_ids, v_unit_id);
        end loop;
      end if;
    elsif v_is_serialized and p_document_type in ('stock_in', 'stock_out', 'opening_stock') then
      raise exception 'validation_failed';
    end if;

    v_line_id := gen_random_uuid();
    insert into public.inventory_document_lines (
      id, tenant_id, document_id, product_id, system_qty, input_qty, delta_qty,
      unit_cost_snapshot, total_value, reason_code, counter_account_id,
      product_unit_ids, line_order
    )
    values (
      v_line_id, v_tenant_id, v_document_id, v_product_id, v_system_qty,
      coalesce(v_counted_qty, v_qty), v_delta, v_unit_cost, v_total_value,
      coalesce(v_line_reason_code, v_reason_code), v_counter_account_id,
      v_unit_ids, v_line_order
    );

    if v_delta = 0 then
      continue;
    end if;

    if v_total_value > 0 then
      v_has_financial_effect := true;
    end if;

    v_movement_id := gen_random_uuid();
    insert into public.inventory_movements (
      id, tenant_id, movement_type, warehouse_id, product_id,
      qty, unit_cost, reference_table, reference_id, notes, created_by, occurred_at
    )
    values (
      v_movement_id, v_tenant_id, v_movement_type, v_warehouse_id, v_product_id,
      v_qty,
      case when v_movement_type = 'adjustment_out' then null else v_unit_cost end,
      'inventory_document', v_document_id, v_notes,
      auth.uid(), v_document_date::timestamptz
    );

    if v_delta > 0 then
      insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
      values (v_tenant_id, v_warehouse_id, v_product_id, v_qty)
      on conflict (warehouse_id, product_id) do update
      set qty_available = public.inventory_balances.qty_available + excluded.qty_available;

      if v_total_value > 0 then
        perform public.apply_inventory_wac_internal(
          v_tenant_id, v_product_id, v_qty, v_total_value
        );

        v_inv_net := v_inv_net + v_total_value;
        v_acct_key := v_counter_account_id::text;
        v_acct_map := v_acct_map || jsonb_build_object(
          v_acct_key,
          coalesce((v_acct_map ->> v_acct_key)::numeric, 0) + v_total_value
        );
      end if;
    else
      update public.inventory_balances
      set qty_available = qty_available - v_qty
      where tenant_id = v_tenant_id
        and warehouse_id = v_warehouse_id
        and product_id = v_product_id;

      if v_total_value > 0 then
        v_inv_net := v_inv_net - v_total_value;
        v_acct_key := v_counter_account_id::text;
        v_acct_map := v_acct_map || jsonb_build_object(
          v_acct_key,
          coalesce((v_acct_map ->> v_acct_key)::numeric, 0) - v_total_value
        );
      end if;
    end if;
  end loop;

  if not v_has_financial_effect then
    return v_document_id;
  end if;

  v_je_number := public.next_document_number('JE');
  v_je_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_je_id, v_tenant_id, v_je_number, v_document_date,
    v_journal_source::public.journal_source, v_document_id,
    v_document_number || ' inventory document', false, auth.uid()
  );

  v_jl_order := 0;
  if v_inv_net > 0 then
    v_jl_order := v_jl_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order
    )
    values (
      v_tenant_id, v_je_id, v_inventory_account, v_inv_net, 0, v_jl_order
    );
  elsif v_inv_net < 0 then
    v_jl_order := v_jl_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order
    )
    values (
      v_tenant_id, v_je_id, v_inventory_account, 0, abs(v_inv_net), v_jl_order
    );
  end if;

  for v_dist_key in select jsonb_object_keys(v_acct_map) loop
    v_acct_amount := (v_acct_map ->> v_dist_key)::numeric(15, 3);
    if v_acct_amount = 0 then
      continue;
    end if;
    v_acct_id := v_dist_key::uuid;
    v_jl_order := v_jl_order + 1;
    if v_acct_amount > 0 then
      insert into public.journal_lines (
        tenant_id, journal_entry_id, account_id, debit, credit, line_order
      )
      values (v_tenant_id, v_je_id, v_acct_id, 0, v_acct_amount, v_jl_order);
    else
      insert into public.journal_lines (
        tenant_id, journal_entry_id, account_id, debit, credit, line_order
      )
      values (v_tenant_id, v_je_id, v_acct_id, abs(v_acct_amount), 0, v_jl_order);
    end if;
  end loop;

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_je_id and tenant_id = v_tenant_id;

  update public.inventory_documents
  set journal_entry_id = v_je_id
  where id = v_document_id and tenant_id = v_tenant_id;

  return v_document_id;
end;
$$;

-- Revoke internal helpers
revoke all on function public.resolve_or_insert_inventory_system_account(uuid, text, text, text, public.account_type, text) from public, anon, authenticated;
revoke all on function public.resolve_opening_balance_equity_account(uuid) from public, anon, authenticated;
revoke all on function public.provision_tenant_inventory_accounts(uuid) from public, anon, authenticated;
revoke all on function public.seed_tenant_inventory_adjustment_reasons(uuid) from public, anon, authenticated;
revoke all on function public.sum_owned_inventory_qty(uuid, uuid) from public, anon, authenticated;
revoke all on function public.apply_inventory_wac_internal(uuid, uuid, numeric, numeric) from public, anon, authenticated;
revoke all on function public.resolve_inventory_reason(uuid, text, public.inventory_reason_direction, text) from public, anon, authenticated;
revoke all on function public.assert_inventory_line_no_client_accounts(jsonb) from public, anon, authenticated;
revoke all on function public.inventory_doc_sequence_key(public.inventory_document_type) from public, anon, authenticated;
revoke all on function public.inventory_doc_journal_source(public.inventory_document_type) from public, anon, authenticated;
revoke all on function public.assert_books_open_for_date(uuid, date) from public, anon, authenticated;
revoke all on function public.revert_inventory_wac_internal(uuid, uuid, numeric, numeric) from public, anon, authenticated;
revoke all on function public.confirm_inventory_document_internal(public.inventory_document_type, jsonb, uuid, text) from public, anon, authenticated;
