-- Phase 5 M5: purchase invoice engine (posting, drafts, reads).
-- Reuses M1 idempotency/finance write-gate and M4 calculate_invoice_totals_internal.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Internal: normalize purchase confirm payload for idempotency hash
-- ---------------------------------------------------------------------------
create or replace function public.normalize_purchase_invoice_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed_top text[] := array[
    'supplier_id', 'date', 'due_date', 'warehouse_id', 'notes', 'lines', 'invoice_id'
  ];
  v_allowed_line text[] := array[
    'product_id', 'qty', 'unit_price', 'discount_pct', 'line_order', 'units'
  ];
  v_allowed_unit text[] := array[
    'serial_number', 'barcode'
  ];
  v_key text;
  v_lines jsonb;
  v_line jsonb;
  v_line_order int;
  v_line_order_numeric numeric;
  v_product_id uuid;
  v_qty numeric(15, 3);
  v_unit_price numeric(15, 3);
  v_discount_pct numeric(5, 2);
  v_supplier_id uuid;
  v_warehouse_id uuid;
  v_invoice_date date;
  v_due_date date;
  v_invoice_id uuid;
  v_seen_orders int[] := '{}';
  v_norm_lines jsonb := '[]'::jsonb;
  v_norm_line jsonb;
  v_norm_units jsonb;
  v_norm_unit jsonb;
  v_unit_elem jsonb;
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

  if not (p_data ? 'supplier_id' and p_data ? 'date' and p_data ? 'warehouse_id' and p_data ? 'lines') then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'lines') <> 'array' or jsonb_array_length(p_data -> 'lines') < 1 then
    raise exception 'validation_failed';
  end if;

  if jsonb_array_length(p_data -> 'lines') > 500 then
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

    if not (v_line ? 'product_id' and v_line ? 'qty' and v_line ? 'unit_price'
      and v_line ? 'discount_pct' and v_line ? 'line_order') then
      raise exception 'validation_failed';
    end if;

    if jsonb_typeof(v_line -> 'product_id') <> 'string'
      or jsonb_typeof(v_line -> 'qty') <> 'number'
      or jsonb_typeof(v_line -> 'unit_price') <> 'number'
      or jsonb_typeof(v_line -> 'discount_pct') <> 'number'
      or jsonb_typeof(v_line -> 'line_order') <> 'number' then
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
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      v_unit_price := (v_line ->> 'unit_price')::numeric(15, 3);
      v_discount_pct := (v_line ->> 'discount_pct')::numeric(5, 2);
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if v_line_order < 1
      or v_line_order = any (v_seen_orders)
      or v_qty <= 0
      or v_unit_price < 0
      or v_discount_pct < 0
      or v_discount_pct > 100 then
      raise exception 'validation_failed';
    end if;

    v_seen_orders := array_append(v_seen_orders, v_line_order);

    v_norm_units := null;
    if v_line ? 'units' then
      if jsonb_typeof(v_line -> 'units') <> 'array' then
        raise exception 'validation_failed';
      end if;

      v_norm_units := '[]'::jsonb;
      for v_unit_elem in
        select u
        from jsonb_array_elements(v_line -> 'units') as u
        order by lower(btrim(u ->> 'serial_number')),
          lower(btrim(coalesce(u ->> 'barcode', '')))
      loop
        if jsonb_typeof(v_unit_elem) <> 'object' or not (v_unit_elem ? 'serial_number') then
          raise exception 'validation_failed';
        end if;

        for v_key in select jsonb_object_keys(v_unit_elem) loop
          if not (v_key = any (v_allowed_unit)) then
            raise exception 'validation_failed';
          end if;
        end loop;

        if jsonb_typeof(v_unit_elem -> 'serial_number') <> 'string'
          or (
            v_unit_elem ? 'barcode'
            and jsonb_typeof(v_unit_elem -> 'barcode') not in ('string', 'null')
          ) then
          raise exception 'validation_failed';
        end if;

        if btrim(v_unit_elem ->> 'serial_number') = '' then
          raise exception 'validation_failed';
        end if;
        v_norm_unit := jsonb_build_object(
          'serial_number', btrim(v_unit_elem ->> 'serial_number')
        );
        if v_unit_elem ? 'barcode' and btrim(coalesce(v_unit_elem ->> 'barcode', '')) <> '' then
          v_norm_unit := v_norm_unit || jsonb_build_object('barcode', btrim(v_unit_elem ->> 'barcode'));
        end if;
        v_norm_units := v_norm_units || jsonb_build_array(v_norm_unit);
      end loop;
    end if;

    v_norm_line := jsonb_build_object(
      'product_id', v_product_id::text,
      'qty', to_jsonb(v_qty),
      'unit_price', to_jsonb(v_unit_price),
      'discount_pct', to_jsonb(v_discount_pct),
      'line_order', v_line_order
    );
    if v_norm_units is not null then
      v_norm_line := v_norm_line || jsonb_build_object('units', v_norm_units);
    end if;

    v_norm_lines := v_norm_lines || jsonb_build_array(v_norm_line);
  end loop;

  select coalesce(
    jsonb_agg(value order by (value ->> 'line_order')::int),
    '[]'::jsonb
  )
  into v_norm_lines
  from jsonb_array_elements(v_norm_lines);

  if jsonb_typeof(p_data -> 'supplier_id') <> 'string'
    or jsonb_typeof(p_data -> 'date') <> 'string'
    or jsonb_typeof(p_data -> 'warehouse_id') <> 'string'
    or (
      p_data ? 'due_date'
      and jsonb_typeof(p_data -> 'due_date') not in ('string', 'null')
    )
    or (
      p_data ? 'notes'
      and jsonb_typeof(p_data -> 'notes') not in ('string', 'null')
    )
    or (
      p_data ? 'invoice_id'
      and jsonb_typeof(p_data -> 'invoice_id') not in ('string', 'null')
    ) then
    raise exception 'validation_failed';
  end if;

  begin
    v_supplier_id := (p_data ->> 'supplier_id')::uuid;
    v_warehouse_id := (p_data ->> 'warehouse_id')::uuid;
    v_invoice_date := (p_data ->> 'date')::date;
    if p_data ? 'due_date'
      and p_data ->> 'due_date' is not null
      and btrim(p_data ->> 'due_date') <> '' then
      v_due_date := (p_data ->> 'due_date')::date;
    end if;
    if p_data ? 'invoice_id'
      and p_data ->> 'invoice_id' is not null
      and btrim(p_data ->> 'invoice_id') <> '' then
      v_invoice_id := (p_data ->> 'invoice_id')::uuid;
    end if;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  v_result := jsonb_build_object(
    'supplier_id', v_supplier_id::text,
    'date', v_invoice_date::text,
    'warehouse_id', v_warehouse_id::text,
    'lines', v_norm_lines
  );

  if v_due_date is not null then
    v_result := v_result || jsonb_build_object('due_date', v_due_date::text);
  end if;

  if p_data ? 'notes' and btrim(coalesce(p_data ->> 'notes', '')) <> '' then
    v_result := v_result || jsonb_build_object('notes', btrim(p_data ->> 'notes'));
  end if;

  if v_invoice_id is not null then
    v_result := v_result || jsonb_build_object('invoice_id', v_invoice_id::text);
  end if;

  return v_result;
end;
$$;

comment on function public.normalize_purchase_invoice_payload(jsonb) is
  'M5: Canonical purchase confirm payload for idempotency hashing. Sorts lines by line_order and units by serial/barcode.';

-- ---------------------------------------------------------------------------
-- Internal: purchase invoice payload hash
-- ---------------------------------------------------------------------------
create or replace function public.compute_purchase_invoice_payload_hash(p_data jsonb)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(public.normalize_purchase_invoice_payload(p_data)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_purchase_invoice_payload_hash(jsonb) is
  'M5: SHA-256 hex of the strict normalized purchase-invoice payload.';

-- ---------------------------------------------------------------------------
-- Internal: idempotency advisory lock
-- ---------------------------------------------------------------------------
create or replace function public.acquire_finance_idempotency_lock(p_idempotency_key uuid)
returns void
language plpgsql
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

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_tenant_id::text || ':finance_idem:' || p_idempotency_key::text, 0)
  );
end;
$$;

comment on function public.acquire_finance_idempotency_lock(uuid) is
  'M5: Tenant-scoped transaction advisory lock for finance idempotency serialization.';

-- ---------------------------------------------------------------------------
-- Internal: supplier A/P account validation (entity-linked leaf)
-- ---------------------------------------------------------------------------
create or replace function public.validate_supplier_ap_account(
  p_tenant_id uuid,
  p_supplier_id uuid,
  p_account_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_supplier public.suppliers%rowtype;
  v_acct public.chart_of_accounts%rowtype;
  v_child_count bigint;
begin
  select * into v_supplier
  from public.suppliers
  where id = p_supplier_id
    and tenant_id = p_tenant_id;

  if not found or not coalesce(v_supplier.is_active, false) then
    raise exception 'validation_failed';
  end if;

  if v_supplier.account_id is null then
    raise exception 'validation_failed';
  end if;

  if p_account_id is not null and v_supplier.account_id is distinct from p_account_id then
    raise exception 'validation_failed';
  end if;

  select * into v_acct
  from public.chart_of_accounts
  where id = coalesce(p_account_id, v_supplier.account_id);

  if not found or v_acct.tenant_id <> p_tenant_id then
    raise exception 'cross_tenant_reference';
  end if;

  if v_acct.type <> 'liability'
    or not v_acct.is_active
    or v_acct.related_entity_table is distinct from 'suppliers'
    or v_acct.related_entity_id is distinct from p_supplier_id then
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
end;
$$;

comment on function public.validate_supplier_ap_account(uuid, uuid, uuid) is
  'M5: Validates active supplier-linked A/P posting leaf for purchase posting.';

-- ---------------------------------------------------------------------------
-- Internal: system inventory account 1301
-- ---------------------------------------------------------------------------
create or replace function public.resolve_system_inventory_account(p_tenant_id uuid)
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
    and code = '1301';

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

comment on function public.resolve_system_inventory_account(uuid) is
  'M5: Resolves validated tenant system inventory account 1301 (asset leaf, not entity-linked).';

-- ---------------------------------------------------------------------------
-- Internal: capitalized acquisition value per line snapshot
-- ---------------------------------------------------------------------------
create or replace function public.purchase_line_capitalized_amount(
  p_tenant_id uuid,
  p_tax_enabled boolean,
  p_line_snapshot jsonb
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_before_tax numeric;
  v_tax_amount numeric;
  v_tax_rate_id uuid;
  v_is_recoverable boolean;
begin
  v_before_tax := coalesce((p_line_snapshot ->> 'before_tax_amount')::numeric, 0);
  v_tax_amount := coalesce((p_line_snapshot ->> 'tax_amount')::numeric, 0);

  if not coalesce(p_tax_enabled, false) or v_tax_amount = 0 then
    return v_before_tax;
  end if;

  v_tax_rate_id := nullif(p_line_snapshot ->> 'tax_rate_id', '')::uuid;
  if v_tax_rate_id is null then
    return v_before_tax;
  end if;

  select tr.is_recoverable
  into v_is_recoverable
  from public.tax_rates tr
  where tr.id = v_tax_rate_id
    and tr.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if coalesce(v_is_recoverable, true) then
    return v_before_tax;
  end if;

  return v_before_tax + v_tax_amount;
end;
$$;

comment on function public.purchase_line_capitalized_amount(uuid, boolean, jsonb) is
  'M5: Line acquisition value for inventory/WAC. Non-recoverable tax is capitalized.';

-- ---------------------------------------------------------------------------
-- Internal: WAC update after stock increment (isolated policy hook)
-- ---------------------------------------------------------------------------
create or replace function public.apply_purchase_wac_internal(
  p_tenant_id uuid,
  p_product_id uuid,
  p_incoming_qty numeric,
  p_incoming_total_acquisition_value numeric
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

  if p_incoming_total_acquisition_value is null or p_incoming_total_acquisition_value < 0 then
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
  v_unit_cost := p_incoming_total_acquisition_value / p_incoming_qty;

  if v_old_qty = 0 then
    v_new_avg := v_unit_cost;
  else
    v_new_avg := (
      (v_old_qty * v_old_avg_cost) + p_incoming_total_acquisition_value
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

comment on function public.apply_purchase_wac_internal(uuid, uuid, numeric, numeric) is
  'M5: Incremental WAC using sum(qty_available) after stock increment. Policy isolated for future M4.5.';

-- ---------------------------------------------------------------------------
-- Internal: serialized units without stock side effects
-- ---------------------------------------------------------------------------
create or replace function public.insert_purchase_product_units_internal(
  p_tenant_id uuid,
  p_invoice_id uuid,
  p_product_id uuid,
  p_warehouse_id uuid,
  p_invoice_date date,
  p_purchase_cost numeric,
  p_units jsonb
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_unit_count int;
  v_elem jsonb;
  v_serial text;
  v_serial_key text;
  v_barcode text;
  v_seen_serials text[] := '{}';
  v_seen_barcodes text[] := '{}';
  v_unit_id uuid;
  v_created_ids uuid[] := '{}';
  v_i int;
begin
  if p_units is null or jsonb_typeof(p_units) <> 'array' then
    raise exception 'validation_failed';
  end if;

  v_unit_count := jsonb_array_length(p_units);
  if v_unit_count < 1 or v_unit_count > 100 then
    raise exception 'validation_failed';
  end if;

  if p_purchase_cost is null or p_purchase_cost < 0 then
    raise exception 'validation_failed';
  end if;

  for v_i in 0 .. (v_unit_count - 1) loop
    v_elem := p_units -> v_i;
    v_serial := btrim(v_elem ->> 'serial_number');
    if v_serial is null or v_serial = '' then
      raise exception 'validation_failed';
    end if;

    v_serial_key := lower(v_serial);
    if v_serial_key = any (v_seen_serials) then
      raise exception 'duplicate_serial';
    end if;
    v_seen_serials := array_append(v_seen_serials, v_serial_key);

    if exists (
      select 1
      from public.product_units pu
      where pu.tenant_id = p_tenant_id
        and lower(btrim(pu.serial_number)) = v_serial_key
    ) then
      raise exception 'duplicate_serial';
    end if;

    v_barcode := nullif(btrim(v_elem ->> 'barcode'), '');
    if v_barcode is not null then
      if lower(v_barcode) = any (v_seen_barcodes) then
        raise exception 'validation_failed';
      end if;
      v_seen_barcodes := array_append(v_seen_barcodes, lower(v_barcode));

      if exists (
        select 1
        from public.product_units pu
        where pu.tenant_id = p_tenant_id
          and pu.barcode is not null
          and btrim(pu.barcode) <> ''
          and lower(btrim(pu.barcode)) = lower(v_barcode)
      ) then
        raise exception 'validation_failed';
      end if;
    end if;
  end loop;

  for v_i in 0 .. (v_unit_count - 1) loop
    v_elem := p_units -> v_i;
    v_serial := btrim(v_elem ->> 'serial_number');
    v_barcode := nullif(btrim(v_elem ->> 'barcode'), '');
    v_unit_id := gen_random_uuid();

    insert into public.product_units (
      id,
      tenant_id,
      product_id,
      serial_number,
      barcode,
      status,
      current_warehouse_id,
      purchase_cost,
      purchase_invoice_id,
      health_status,
      acquired_at
    )
    values (
      v_unit_id,
      p_tenant_id,
      p_product_id,
      v_serial,
      v_barcode,
      'available_new',
      p_warehouse_id,
      p_purchase_cost,
      p_invoice_id,
      'good',
      p_invoice_date
    );

    v_created_ids := array_append(v_created_ids, v_unit_id);
  end loop;

  return v_created_ids;
end;
$$;

comment on function public.insert_purchase_product_units_internal(uuid, uuid, uuid, uuid, date, numeric, jsonb) is
  'M5: Insert purchase product_units only. No inventory balance/movement/WAC side effects.';

-- ---------------------------------------------------------------------------
-- Internal: draft ownership guard
-- ---------------------------------------------------------------------------
create or replace function public.assert_purchase_draft_editable(p_invoice_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_draft public.invoices%rowtype;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  select * into v_draft
  from public.invoices
  where id = p_invoice_id
    and tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_draft.type <> 'purchase' or v_draft.status <> 'draft' then
    raise exception 'validation_failed';
  end if;

  if public.is_manager() then
    return;
  end if;

  if not public.user_has_permission('invoices.edit_draft') then
    raise exception 'permission_denied';
  end if;

  if v_draft.created_by is distinct from auth.uid() then
    raise exception 'permission_denied';
  end if;
end;
$$;

comment on function public.assert_purchase_draft_editable(uuid) is
  'M5: Locks purchase draft FOR UPDATE. Manager or creator with invoices.edit_draft may edit.';

-- ---------------------------------------------------------------------------
-- Internal: strip units for M4 totals helper
-- ---------------------------------------------------------------------------
create or replace function public.purchase_calc_lines_for_totals(p_lines jsonb)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      case
        when elem ? 'units' then elem - 'units'
        else elem
      end
      order by (elem ->> 'line_order')::int
    ),
    '[]'::jsonb
  )
  from jsonb_array_elements(p_lines) as elem;
$$;

comment on function public.purchase_calc_lines_for_totals(jsonb) is
  'M5: Removes units[] from purchase lines before calculate_invoice_totals_internal.';

-- ---------------------------------------------------------------------------
-- Internal: purchase invoice read permission
-- ---------------------------------------------------------------------------
create or replace function public.assert_purchase_invoice_view()
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
    public.user_has_permission('invoices.view_purchase')
    or public.user_has_permission('invoices.view')
  ) then
    raise exception 'permission_denied';
  end if;
end;
$$;

comment on function public.assert_purchase_invoice_view() is
  'M5: View permission for purchase invoice read RPCs.';

-- ---------------------------------------------------------------------------
-- Public: record confirmed purchase invoice
-- ---------------------------------------------------------------------------
create or replace function public.record_purchase_invoice(
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
  v_supplier_id uuid;
  v_warehouse_id uuid;
  v_invoice_id uuid;
  v_confirm_draft boolean := false;
  v_date date;
  v_due_date date;
  v_notes text;
  v_books_locked_through date;
  v_tax_enabled boolean;
  v_ap_account_id uuid;
  v_inventory_account uuid;
  v_calc_lines jsonb;
  v_totals jsonb;
  v_total numeric(15, 3);
  v_invoice_number text;
  v_journal_entry_id uuid;
  v_journal_number text;
  v_line_input jsonb;
  v_line_snap jsonb;
  v_line_order int;
  v_line_qty numeric(15, 3);
  v_line_capitalized numeric(15, 3);
  v_line_unit_cost numeric(15, 3);
  v_product_id uuid;
  v_is_serialized boolean;
  v_serialized_product_ids uuid[] := '{}';
  v_seen_serials text[] := '{}';
  v_serial_key text;
  v_unit_elem jsonb;
  v_lock_rec record;
  v_wac_qty_map jsonb := '{}'::jsonb;
  v_wac_value_map jsonb := '{}'::jsonb;
  v_stock_qty_map jsonb := '{}'::jsonb;
  v_inventory_debit numeric(15, 3) := 0;
  v_recoverable_tax numeric(15, 3) := 0;
  v_input_tax_account uuid;
  v_tax_rate_id uuid;
  v_is_recoverable boolean;
  v_je_line_order int := 0;
  v_movement_id uuid;
  v_unit_purchase_cost numeric(15, 3);
  v_agg_qty numeric(15, 3);
  v_agg_value numeric(15, 3);
  v_dist_product_id text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('invoices.create_purchase') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_purchase_invoice_payload(p_data);
  v_hash := public.compute_purchase_invoice_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.invoices'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  v_supplier_id := (v_normalized ->> 'supplier_id')::uuid;
  v_warehouse_id := (v_normalized ->> 'warehouse_id')::uuid;
  v_date := (v_normalized ->> 'date')::date;

  if v_normalized ? 'due_date' then
    v_due_date := (v_normalized ->> 'due_date')::date;
  end if;

  if v_normalized ? 'notes' then
    v_notes := v_normalized ->> 'notes';
  end if;

  if v_normalized ? 'invoice_id' then
    v_invoice_id := (v_normalized ->> 'invoice_id')::uuid;
    v_confirm_draft := true;
    perform public.assert_purchase_draft_editable(v_invoice_id);
  end if;

  if v_date is null then
    raise exception 'validation_failed';
  end if;

  if v_due_date is not null and v_due_date < v_date then
    raise exception 'validation_failed';
  end if;

  select ts.books_locked_through, ts.tax_enabled
  into v_books_locked_through, v_tax_enabled
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1
    from public.warehouses w
    where w.id = v_warehouse_id
      and w.tenant_id = v_tenant_id
      and coalesce(w.is_active, false)
  ) then
    raise exception 'validation_failed';
  end if;

  perform public.validate_supplier_ap_account(v_tenant_id, v_supplier_id, null);

  select s.account_id
  into v_ap_account_id
  from public.suppliers s
  where s.id = v_supplier_id
    and s.tenant_id = v_tenant_id;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line_input ->> 'line_order')::int;
    v_product_id := (v_line_input ->> 'product_id')::uuid;
    v_line_qty := (v_line_input ->> 'qty')::numeric(15, 3);

    if v_line_qty is null or v_line_qty <= 0 then
      raise exception 'validation_failed';
    end if;

    if coalesce((v_line_input ->> 'unit_price')::numeric, -1) < 0 then
      raise exception 'validation_failed';
    end if;

    if coalesce((v_line_input ->> 'discount_pct')::numeric, 0) < 0
      or coalesce((v_line_input ->> 'discount_pct')::numeric, 0) > 100 then
      raise exception 'validation_failed';
    end if;

    select p.is_serialized
    into v_is_serialized
    from public.products p
    where p.id = v_product_id
      and p.tenant_id = v_tenant_id
      and coalesce(p.is_active, false);

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_is_serialized then
      if v_line_qty <> trunc(v_line_qty) then
        raise exception 'validation_failed';
      end if;

      if not (v_line_input ? 'units')
        or jsonb_typeof(v_line_input -> 'units') <> 'array'
        or jsonb_array_length(v_line_input -> 'units') <> v_line_qty::int then
        raise exception 'validation_failed';
      end if;

      if v_product_id = any (v_serialized_product_ids) then
        raise exception 'validation_failed';
      end if;
      v_serialized_product_ids := array_append(v_serialized_product_ids, v_product_id);

      for v_unit_elem in
        select u from jsonb_array_elements(v_line_input -> 'units') as u
      loop
        v_serial_key := lower(btrim(v_unit_elem ->> 'serial_number'));
        if v_serial_key is null or v_serial_key = '' then
          raise exception 'validation_failed';
        end if;
        if v_serial_key = any (v_seen_serials) then
          raise exception 'duplicate_serial';
        end if;
        v_seen_serials := array_append(v_seen_serials, v_serial_key);
      end loop;
    elsif v_line_input ? 'units' then
      raise exception 'validation_failed';
    end if;
  end loop;

  for v_lock_rec in
    select distinct (elem ->> 'product_id')::uuid as product_id
    from jsonb_array_elements(v_normalized -> 'lines') as elem
    order by 1
  loop
    perform 1
    from public.products p
    where p.id = v_lock_rec.product_id
      and p.tenant_id = v_tenant_id
    for update;

    perform 1
    from public.inventory_balances ib
    where ib.tenant_id = v_tenant_id
      and ib.product_id = v_lock_rec.product_id
      and ib.warehouse_id = v_warehouse_id
    for update;
  end loop;

  v_calc_lines := public.purchase_calc_lines_for_totals(v_normalized -> 'lines');
  v_totals := public.calculate_invoice_totals_internal(
    v_tenant_id,
    'purchase',
    v_date,
    v_calc_lines
  );
  v_total := (v_totals ->> 'total')::numeric(15, 3);

  if v_total is null or v_total <= 0 then
    raise exception 'validation_failed';
  end if;

  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);

  for v_line_snap in
    select value
    from jsonb_array_elements(v_totals -> 'lines')
  loop
    v_tax_rate_id := nullif(v_line_snap ->> 'tax_rate_id', '')::uuid;
    if coalesce(v_tax_enabled, false)
      and coalesce((v_line_snap ->> 'tax_amount')::numeric, 0) > 0
      and v_tax_rate_id is not null then
      select tr.is_recoverable, tr.input_account_id
      into v_is_recoverable, v_input_tax_account
      from public.tax_rates tr
      where tr.id = v_tax_rate_id
        and tr.tenant_id = v_tenant_id;

      if not found then
        raise exception 'validation_failed';
      end if;

      if coalesce(v_is_recoverable, true) then
        perform public.validate_tax_posting_account(
          v_tenant_id, v_input_tax_account, 'asset', true
        );
      end if;
    end if;
  end loop;

  perform public.allow_finance_write();

  v_invoice_number := public.next_document_number('PI');

  if v_confirm_draft then
    update public.invoices
    set
      supplier_id = v_supplier_id,
      warehouse_id = v_warehouse_id,
      date = v_date,
      due_date = v_due_date,
      notes = v_notes,
      invoice_number = v_invoice_number,
      status = 'confirmed',
      subtotal = (v_totals ->> 'subtotal')::numeric(15, 3),
      discount_amount = (v_totals ->> 'discount_amount')::numeric(15, 3),
      tax_amount = (v_totals ->> 'tax_amount')::numeric(15, 3),
      total = v_total,
      paid_amount = 0,
      idempotency_key = p_idempotency_key,
      idempotency_payload_hash = v_hash,
      confirmed_at = now(),
      confirmed_by = auth.uid(),
      updated_at = now()
    where id = v_invoice_id
      and tenant_id = v_tenant_id
      and type = 'purchase'
      and status = 'draft';

    if not found then
      raise exception 'validation_failed';
    end if;

    delete from public.invoice_lines
    where invoice_id = v_invoice_id
      and tenant_id = v_tenant_id;
  else
    insert into public.invoices (
      tenant_id, type, status, supplier_id, warehouse_id,
      date, due_date, notes, invoice_number,
      subtotal, discount_amount, tax_amount, total, paid_amount,
      idempotency_key, idempotency_payload_hash,
      created_by, confirmed_at, confirmed_by
    )
    values (
      v_tenant_id, 'purchase', 'confirmed', v_supplier_id, v_warehouse_id,
      v_date, v_due_date, v_notes, v_invoice_number,
      (v_totals ->> 'subtotal')::numeric(15, 3),
      (v_totals ->> 'discount_amount')::numeric(15, 3),
      (v_totals ->> 'tax_amount')::numeric(15, 3),
      v_total, 0,
      p_idempotency_key, v_hash,
      auth.uid(), now(), auth.uid()
    )
    returning id into v_invoice_id;
  end if;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line_input ->> 'line_order')::int;

    select snap.value
    into v_line_snap
    from jsonb_array_elements(v_totals -> 'lines') as snap(value)
    where (snap.value ->> 'line_order')::int = v_line_order;

    if not found then
      raise exception 'validation_failed';
    end if;

    v_product_id := (v_line_input ->> 'product_id')::uuid;
    v_line_qty := (v_line_input ->> 'qty')::numeric(15, 3);
    v_line_capitalized := public.purchase_line_capitalized_amount(
      v_tenant_id, v_tax_enabled, v_line_snap
    );
    v_line_unit_cost := v_line_capitalized / v_line_qty;

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id,
      qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, cost_price, line_order
    )
    values (
      v_tenant_id, v_invoice_id, v_product_id,
      v_line_qty,
      (v_line_input ->> 'unit_price')::numeric(15, 3),
      coalesce((v_line_input ->> 'discount_pct')::numeric(5, 2), 0),
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
      v_line_unit_cost,
      v_line_order
    );

    v_inventory_debit := v_inventory_debit + v_line_capitalized;

    if coalesce(v_tax_enabled, false)
      and coalesce((v_line_snap ->> 'tax_amount')::numeric, 0) > 0
      and nullif(v_line_snap ->> 'tax_rate_id', '') is not null then
      select tr.is_recoverable
      into v_is_recoverable
      from public.tax_rates tr
      where tr.id = (v_line_snap ->> 'tax_rate_id')::uuid
        and tr.tenant_id = v_tenant_id;

      if coalesce(v_is_recoverable, true) then
        v_recoverable_tax := v_recoverable_tax + (v_line_snap ->> 'tax_amount')::numeric(15, 3);
      end if;
    end if;

    v_dist_product_id := v_product_id::text;
    v_agg_qty := coalesce((v_wac_qty_map ->> v_dist_product_id)::numeric, 0) + v_line_qty;
    v_agg_value := coalesce((v_wac_value_map ->> v_dist_product_id)::numeric, 0) + v_line_capitalized;
    v_wac_qty_map := v_wac_qty_map || jsonb_build_object(v_dist_product_id, v_agg_qty);
    v_wac_value_map := v_wac_value_map || jsonb_build_object(v_dist_product_id, v_agg_value);

    v_agg_qty := coalesce((v_stock_qty_map ->> v_dist_product_id)::numeric, 0) + v_line_qty;
    v_stock_qty_map := v_stock_qty_map || jsonb_build_object(v_dist_product_id, v_agg_qty);
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_stock_qty_map)
  loop
    v_agg_qty := (v_stock_qty_map ->> v_dist_product_id)::numeric(15, 3);

    insert into public.inventory_balances (
      tenant_id, warehouse_id, product_id, qty_available
    )
    values (
      v_tenant_id, v_warehouse_id, v_dist_product_id::uuid, v_agg_qty
    )
    on conflict (warehouse_id, product_id) do update
    set qty_available = public.inventory_balances.qty_available + excluded.qty_available;
  end loop;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line_input ->> 'line_order')::int;

    select snap.value
    into v_line_snap
    from jsonb_array_elements(v_totals -> 'lines') as snap(value)
    where (snap.value ->> 'line_order')::int = v_line_order;

    if not found then
      raise exception 'validation_failed';
    end if;

    v_product_id := (v_line_input ->> 'product_id')::uuid;
    v_line_qty := (v_line_input ->> 'qty')::numeric(15, 3);
    v_line_capitalized := public.purchase_line_capitalized_amount(
      v_tenant_id, v_tax_enabled, v_line_snap
    );
    v_line_unit_cost := v_line_capitalized / v_line_qty;

    v_movement_id := gen_random_uuid();
    insert into public.inventory_movements (
      id, tenant_id, movement_type, warehouse_id, product_id,
      qty, unit_cost, reference_table, reference_id, notes, created_by
    )
    values (
      v_movement_id, v_tenant_id, 'purchase', v_warehouse_id, v_product_id,
      v_line_qty, v_line_unit_cost, 'purchase_invoice', v_invoice_id,
      'Purchase invoice ' || v_invoice_number, auth.uid()
    );
  end loop;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line_input ->> 'line_order')::int;

    select snap.value
    into v_line_snap
    from jsonb_array_elements(v_totals -> 'lines') as snap(value)
    where (snap.value ->> 'line_order')::int = v_line_order;

    if not found then
      raise exception 'validation_failed';
    end if;

    v_product_id := (v_line_input ->> 'product_id')::uuid;
    v_line_qty := (v_line_input ->> 'qty')::numeric(15, 3);
    v_line_capitalized := public.purchase_line_capitalized_amount(
      v_tenant_id, v_tax_enabled, v_line_snap
    );

    select p.is_serialized
    into v_is_serialized
    from public.products p
    where p.id = v_product_id;

    if v_is_serialized then
      v_unit_purchase_cost := v_line_capitalized / v_line_qty;
      perform public.insert_purchase_product_units_internal(
        v_tenant_id,
        v_invoice_id,
        v_product_id,
        v_warehouse_id,
        v_date,
        v_unit_purchase_cost,
        v_line_input -> 'units'
      );
    end if;
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_wac_qty_map)
  loop
    v_agg_qty := (v_wac_qty_map ->> v_dist_product_id)::numeric(15, 3);
    v_agg_value := (v_wac_value_map ->> v_dist_product_id)::numeric(15, 3);

    perform public.apply_purchase_wac_internal(
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
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'purchase_invoice', v_invoice_id,
    'Purchase invoice ' || v_invoice_number, false, auth.uid()
  );

  if v_inventory_debit > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_inventory_account,
      v_inventory_debit, 0, v_je_line_order, 'Inventory'
    );
  end if;

  if v_recoverable_tax > 0 then
    select tr.input_account_id
    into v_input_tax_account
    from public.tax_rates tr
    where tr.tenant_id = v_tenant_id
      and tr.id = (
        select nullif(snap.value ->> 'tax_rate_id', '')::uuid
        from jsonb_array_elements(v_totals -> 'lines') as snap(value)
        where coalesce((snap.value ->> 'tax_amount')::numeric, 0) > 0
          and nullif(snap.value ->> 'tax_rate_id', '') is not null
        limit 1
      );

    if v_input_tax_account is null then
      raise exception 'validation_failed';
    end if;

    perform public.validate_tax_posting_account(
      v_tenant_id, v_input_tax_account, 'asset', true
    );

    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_input_tax_account,
      v_recoverable_tax, 0, v_je_line_order, 'Input tax recoverable'
    );
  end if;

  v_je_line_order := v_je_line_order + 1;
  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    v_tenant_id, v_journal_entry_id, v_ap_account_id,
    0, v_total, v_je_line_order, 'Supplier A/P'
  );

  update public.journal_entries
  set
    is_posted = true,
    posted_at = now(),
    posted_by = auth.uid()
  where id = v_journal_entry_id
    and tenant_id = v_tenant_id;

  update public.invoices
  set journal_entry_id = v_journal_entry_id
  where id = v_invoice_id
    and tenant_id = v_tenant_id;

  return v_invoice_id;
end;
$$;

comment on function public.record_purchase_invoice(jsonb, uuid) is
  'M5: Atomic confirmed purchase invoice with stock, units, WAC, and balanced A/P journal.';

-- ---------------------------------------------------------------------------
-- Public: save purchase invoice draft
-- ---------------------------------------------------------------------------
create or replace function public.save_invoice_draft(p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_invoice_id uuid;
  v_is_update boolean := false;
  v_supplier_id uuid;
  v_warehouse_id uuid;
  v_date date;
  v_due_date date;
  v_notes text;
  v_lines jsonb;
  v_line jsonb;
  v_line_order int;
  v_line_order_numeric numeric;
  v_product_id uuid;
  v_qty numeric(15, 3);
  v_unit_price numeric(15, 3);
  v_discount_pct numeric(5, 2);
  v_seen_orders int[] := '{}';
  v_allowed_top text[] := array[
    'type', 'invoice_id', 'supplier_id', 'date', 'due_date',
    'warehouse_id', 'notes', 'lines'
  ];
  v_allowed_line text[] := array[
    'product_id', 'qty', 'unit_price', 'discount_pct', 'line_order'
  ];
  v_key text;
  v_calc_lines jsonb;
  v_totals jsonb;
  v_line_snap jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if not (v_key = any (v_allowed_top)) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if jsonb_typeof(p_data -> 'type') <> 'string'
    or p_data ->> 'type' <> 'purchase' then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'invoice_id' and p_data ->> 'invoice_id' is not null and btrim(p_data ->> 'invoice_id') <> '' then
    if jsonb_typeof(p_data -> 'invoice_id') <> 'string' then
      raise exception 'validation_failed';
    end if;
    begin
      v_invoice_id := (p_data ->> 'invoice_id')::uuid;
    exception
      when others then
        raise exception 'validation_failed';
    end;
    v_is_update := true;
    perform public.assert_purchase_draft_editable(v_invoice_id);
  else
    if not public.user_has_permission('invoices.edit_draft') then
      raise exception 'permission_denied';
    end if;
  end if;

  if not (p_data ? 'supplier_id' and p_data ? 'date' and p_data ? 'warehouse_id' and p_data ? 'lines') then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'lines') <> 'array' or jsonb_array_length(p_data -> 'lines') < 1 then
    raise exception 'validation_failed';
  end if;

  if jsonb_array_length(p_data -> 'lines') > 500 then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'supplier_id') <> 'string'
    or jsonb_typeof(p_data -> 'date') <> 'string'
    or jsonb_typeof(p_data -> 'warehouse_id') <> 'string'
    or (
      p_data ? 'due_date'
      and jsonb_typeof(p_data -> 'due_date') not in ('string', 'null')
    )
    or (
      p_data ? 'notes'
      and jsonb_typeof(p_data -> 'notes') not in ('string', 'null')
    ) then
    raise exception 'validation_failed';
  end if;

  begin
    v_supplier_id := (p_data ->> 'supplier_id')::uuid;
    v_warehouse_id := (p_data ->> 'warehouse_id')::uuid;
    v_date := (p_data ->> 'date')::date;

    if p_data ? 'due_date'
      and p_data ->> 'due_date' is not null
      and btrim(p_data ->> 'due_date') <> '' then
      v_due_date := (p_data ->> 'due_date')::date;
    end if;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  v_notes := nullif(btrim(coalesce(p_data ->> 'notes', '')), '');

  if v_date is null then
    raise exception 'validation_failed';
  end if;

  if v_due_date is not null and v_due_date < v_date then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1 from public.suppliers s
    where s.id = v_supplier_id and s.tenant_id = v_tenant_id and coalesce(s.is_active, false)
  ) then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1 from public.warehouses w
    where w.id = v_warehouse_id and w.tenant_id = v_tenant_id and coalesce(w.is_active, false)
  ) then
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

    if not (v_line ? 'product_id' and v_line ? 'qty' and v_line ? 'unit_price'
      and v_line ? 'discount_pct' and v_line ? 'line_order') then
      raise exception 'validation_failed';
    end if;

    if jsonb_typeof(v_line -> 'product_id') <> 'string'
      or jsonb_typeof(v_line -> 'qty') <> 'number'
      or jsonb_typeof(v_line -> 'unit_price') <> 'number'
      or jsonb_typeof(v_line -> 'discount_pct') <> 'number'
      or jsonb_typeof(v_line -> 'line_order') <> 'number' then
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
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      v_unit_price := (v_line ->> 'unit_price')::numeric(15, 3);
      v_discount_pct := (v_line ->> 'discount_pct')::numeric(5, 2);
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if v_line_order < 1
      or v_line_order = any (v_seen_orders)
      or v_qty <= 0
      or v_unit_price < 0
      or v_discount_pct < 0
      or v_discount_pct > 100 then
      raise exception 'validation_failed';
    end if;

    v_seen_orders := array_append(v_seen_orders, v_line_order);

    if not exists (
      select 1 from public.products p
      where p.id = v_product_id
        and p.tenant_id = v_tenant_id
        and coalesce(p.is_active, false)
    ) then
      raise exception 'validation_failed';
    end if;
  end loop;

  v_calc_lines := public.purchase_calc_lines_for_totals(v_lines);
  v_totals := public.calculate_invoice_totals_internal(
    v_tenant_id, 'purchase', v_date, v_calc_lines
  );

  perform public.allow_finance_write();

  if v_is_update then
    update public.invoices
    set
      supplier_id = v_supplier_id,
      warehouse_id = v_warehouse_id,
      date = v_date,
      due_date = v_due_date,
      notes = v_notes,
      subtotal = (v_totals ->> 'subtotal')::numeric(15, 3),
      discount_amount = (v_totals ->> 'discount_amount')::numeric(15, 3),
      tax_amount = (v_totals ->> 'tax_amount')::numeric(15, 3),
      total = (v_totals ->> 'total')::numeric(15, 3),
      updated_at = now()
    where id = v_invoice_id
      and tenant_id = v_tenant_id;

    delete from public.invoice_lines
    where invoice_id = v_invoice_id
      and tenant_id = v_tenant_id;
  else
    insert into public.invoices (
      tenant_id, type, status, supplier_id, warehouse_id,
      date, due_date, notes,
      subtotal, discount_amount, tax_amount, total,
      created_by, updated_at
    )
    values (
      v_tenant_id, 'purchase', 'draft', v_supplier_id, v_warehouse_id,
      v_date, v_due_date, v_notes,
      (v_totals ->> 'subtotal')::numeric(15, 3),
      (v_totals ->> 'discount_amount')::numeric(15, 3),
      (v_totals ->> 'tax_amount')::numeric(15, 3),
      (v_totals ->> 'total')::numeric(15, 3),
      auth.uid(), now()
    )
    returning id into v_invoice_id;
  end if;

  for v_line in
    select value
    from jsonb_array_elements(v_lines)
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line ->> 'line_order')::int;

    select snap.value
    into v_line_snap
    from jsonb_array_elements(v_totals -> 'lines') as snap(value)
    where (snap.value ->> 'line_order')::int = v_line_order;

    if not found then
      raise exception 'validation_failed';
    end if;

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id,
      qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, line_order
    )
    values (
      v_tenant_id, v_invoice_id, (v_line ->> 'product_id')::uuid,
      (v_line ->> 'qty')::numeric(15, 3),
      (v_line ->> 'unit_price')::numeric(15, 3),
      coalesce((v_line ->> 'discount_pct')::numeric(5, 2), 0),
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
      v_line_order
    );
  end loop;

  return v_invoice_id;
end;
$$;

comment on function public.save_invoice_draft(jsonb) is
  'M5: Save or update a purchase invoice draft with server-calculated snapshots.';

-- ---------------------------------------------------------------------------
-- Public: discard purchase invoice draft
-- ---------------------------------------------------------------------------
create or replace function public.discard_invoice_draft(p_invoice_id uuid)
returns uuid
language plpgsql
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

  perform public.assert_purchase_draft_editable(p_invoice_id);
  perform public.allow_finance_write();

  delete from public.invoice_lines
  where invoice_id = p_invoice_id
    and tenant_id = v_tenant_id;

  delete from public.invoices
  where id = p_invoice_id
    and tenant_id = v_tenant_id
    and type = 'purchase'
    and status = 'draft';

  if not found then
    raise exception 'validation_failed';
  end if;

  return p_invoice_id;
end;
$$;

comment on function public.discard_invoice_draft(uuid) is
  'M5: Hard-delete a purchase draft and its lines after ownership checks.';

-- ---------------------------------------------------------------------------
-- Public: list purchase invoices
-- ---------------------------------------------------------------------------
create or replace function public.list_purchase_invoices(
  p_supplier_id uuid default null,
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
  supplier_id uuid,
  supplier_name_ar text,
  supplier_name_en text,
  status public.invoice_status,
  date date,
  due_date date,
  subtotal numeric(15, 3),
  discount_amount numeric(15, 3),
  tax_amount numeric(15, 3),
  total numeric(15, 3),
  paid_amount numeric(15, 3),
  outstanding numeric(15, 3),
  currency_code text,
  currency_symbol text,
  currency_decimal_places integer,
  cancelled_at timestamptz
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

  perform public.assert_purchase_invoice_view();

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    i.id,
    i.invoice_number,
    i.supplier_id,
    s.name_ar as supplier_name_ar,
    s.name_en as supplier_name_en,
    i.status,
    i.date,
    i.due_date,
    i.subtotal,
    i.discount_amount,
    i.tax_amount,
    i.total,
    i.paid_amount,
    (i.total - i.paid_amount) as outstanding,
    c.iso_code as currency_code,
    coalesce(c.major_symbol_ar, c.major_symbol_en) as currency_symbol,
    coalesce(c.decimal_places, 3) as currency_decimal_places,
    i.cancelled_at
  from public.invoices i
  join public.suppliers s
    on s.id = i.supplier_id
    and s.tenant_id = i.tenant_id
  join public.tenants t on t.id = i.tenant_id
  left join public.currencies c on c.id = t.default_currency_id
  where i.tenant_id = v_tenant_id
    and i.type = 'purchase'
    and (p_supplier_id is null or i.supplier_id = p_supplier_id)
    and (p_status is null or i.status::text = p_status)
    and (p_date_from is null or i.date >= p_date_from)
    and (p_date_to is null or i.date <= p_date_to)
    and (
      v_search is null
      or lower(coalesce(i.invoice_number, '')) like '%' || v_search || '%'
      or lower(coalesce(s.name_ar, '')) like '%' || v_search || '%'
      or lower(coalesce(s.name_en, '')) like '%' || v_search || '%'
    )
  order by i.date desc nulls last, i.invoice_number desc nulls last, i.id desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

comment on function public.list_purchase_invoices(uuid, text, date, date, text, integer, integer) is
  'M5: Bounded purchase invoice list with supplier labels and currency metadata.';

-- ---------------------------------------------------------------------------
-- Public: purchase invoice detail
-- ---------------------------------------------------------------------------
create or replace function public.get_purchase_invoice_detail(p_invoice_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_invoice public.invoices%rowtype;
  v_supplier public.suppliers%rowtype;
  v_warehouse public.warehouses%rowtype;
  v_currency_code text;
  v_currency_symbol text;
  v_currency_places integer;
  v_lines jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_purchase_invoice_view();

  select * into v_invoice
  from public.invoices i
  where i.id = p_invoice_id
    and i.tenant_id = v_tenant_id
    and i.type = 'purchase';

  if not found then
    raise exception 'validation_failed';
  end if;

  select * into v_supplier
  from public.suppliers s
  where s.id = v_invoice.supplier_id
    and s.tenant_id = v_tenant_id;

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
      'description', il.description,
      'qty', il.qty,
      'unit_price', il.unit_price,
      'discount_pct', il.discount_pct,
      'gross_amount', il.gross_amount,
      'discount_amount', il.discount_amount,
      'before_tax_amount', il.before_tax_amount,
      'tax_rate_id', il.tax_rate_id,
      'tax_rate', il.tax_rate,
      'tax_class', il.tax_class,
      'taxable_amount', il.taxable_amount,
      'tax_amount', il.tax_amount,
      'after_tax_amount', il.after_tax_amount,
      'line_total', il.line_total,
      'cost_price', il.cost_price,
      'product_unit_ids', coalesce((
        select jsonb_agg(pu.id order by pu.serial_number)
        from public.product_units pu
        where pu.tenant_id = v_tenant_id
          and pu.purchase_invoice_id = v_invoice.id
          and pu.product_id = il.product_id
      ), '[]'::jsonb)
    )
    order by il.line_order
  ), '[]'::jsonb)
  into v_lines
  from public.invoice_lines il
  where il.invoice_id = v_invoice.id
    and il.tenant_id = v_tenant_id;

  return jsonb_build_object(
    'id', v_invoice.id,
    'invoice_number', v_invoice.invoice_number,
    'status', v_invoice.status,
    'supplier', jsonb_build_object(
      'id', v_supplier.id,
      'code', v_supplier.code,
      'name_ar', v_supplier.name_ar,
      'name_en', v_supplier.name_en,
      'account_id', v_supplier.account_id
    ),
    'warehouse', case
      when v_warehouse.id is null then null
      else jsonb_build_object(
        'id', v_warehouse.id,
        'name_ar', v_warehouse.name_ar,
        'name_en', v_warehouse.name_en
      )
    end,
    'date', v_invoice.date,
    'due_date', v_invoice.due_date,
    'notes', v_invoice.notes,
    'subtotal', v_invoice.subtotal,
    'discount_amount', v_invoice.discount_amount,
    'tax_amount', v_invoice.tax_amount,
    'total', v_invoice.total,
    'paid_amount', v_invoice.paid_amount,
    'outstanding', v_invoice.total - v_invoice.paid_amount,
    'currency', jsonb_build_object(
      'code', v_currency_code,
      'symbol', v_currency_symbol,
      'decimal_places', v_currency_places
    ),
    'journal_entry_id', v_invoice.journal_entry_id,
    'confirmed_at', v_invoice.confirmed_at,
    'cancelled_at', v_invoice.cancelled_at,
    'lines', v_lines
  );
end;
$$;

comment on function public.get_purchase_invoice_detail(uuid) is
  'M5: Purchase invoice detail JSON with line snapshots and serialized unit ids.';

-- ---------------------------------------------------------------------------
-- ACL hygiene
-- ---------------------------------------------------------------------------
revoke all on function public.normalize_purchase_invoice_payload(jsonb)
  from public, anon, authenticated;
revoke all on function public.compute_purchase_invoice_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function public.acquire_finance_idempotency_lock(uuid)
  from public, anon, authenticated;
revoke all on function public.validate_supplier_ap_account(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.resolve_system_inventory_account(uuid)
  from public, anon, authenticated;
revoke all on function public.purchase_line_capitalized_amount(uuid, boolean, jsonb)
  from public, anon, authenticated;
revoke all on function public.apply_purchase_wac_internal(uuid, uuid, numeric, numeric)
  from public, anon, authenticated;
revoke all on function public.insert_purchase_product_units_internal(uuid, uuid, uuid, uuid, date, numeric, jsonb)
  from public, anon, authenticated;
revoke all on function public.assert_purchase_draft_editable(uuid)
  from public, anon, authenticated;
revoke all on function public.purchase_calc_lines_for_totals(jsonb)
  from public, anon, authenticated;
revoke all on function public.assert_purchase_invoice_view()
  from public, anon, authenticated;

grant execute on function public.list_purchase_invoices(uuid, text, date, date, text, integer, integer)
  to authenticated;
grant execute on function public.get_purchase_invoice_detail(uuid)
  to authenticated;
