-- Phase 5 M6: sales invoice engine + shared cancellation.
-- Reuses M1 idempotency, M4 tax math, M5 purchase helpers/patterns.

-- ---------------------------------------------------------------------------
-- Internal: normalize sales confirm payload for idempotency hash
-- ---------------------------------------------------------------------------
create or replace function public.normalize_sales_invoice_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed_top text[] := array[
    'customer_id', 'date', 'due_date', 'warehouse_id', 'notes', 'lines'
  ];
  v_allowed_line text[] := array[
    'product_id', 'qty', 'unit_price', 'discount_pct', 'line_order', 'product_unit_id'
  ];
  v_key text;
  v_lines jsonb;
  v_line jsonb;
  v_line_order int;
  v_line_order_numeric numeric;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_qty numeric(15, 3);
  v_unit_price numeric(15, 3);
  v_discount_pct numeric(5, 2);
  v_customer_id uuid;
  v_warehouse_id uuid;
  v_invoice_date date;
  v_due_date date;
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

  if not (p_data ? 'customer_id' and p_data ? 'date' and p_data ? 'warehouse_id' and p_data ? 'lines') then
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
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      v_unit_price := (v_line ->> 'unit_price')::numeric(15, 3);
      v_discount_pct := (v_line ->> 'discount_pct')::numeric(5, 2);
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
      or v_qty <= 0
      or v_unit_price < 0
      or v_discount_pct < 0
      or v_discount_pct > 100 then
      raise exception 'validation_failed';
    end if;

    v_seen_orders := array_append(v_seen_orders, v_line_order);

    v_norm_line := jsonb_build_object(
      'product_id', v_product_id::text,
      'qty', to_jsonb(v_qty),
      'unit_price', to_jsonb(v_unit_price),
      'discount_pct', to_jsonb(v_discount_pct),
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
        coalesce(value ->> 'product_unit_id', '')
    ),
    '[]'::jsonb
  )
  into v_norm_lines
  from jsonb_array_elements(v_norm_lines);

  if jsonb_typeof(p_data -> 'customer_id') <> 'string'
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
    v_customer_id := (p_data ->> 'customer_id')::uuid;
    v_warehouse_id := (p_data ->> 'warehouse_id')::uuid;
    v_invoice_date := (p_data ->> 'date')::date;
    if p_data ? 'due_date'
      and p_data ->> 'due_date' is not null
      and btrim(p_data ->> 'due_date') <> '' then
      v_due_date := (p_data ->> 'due_date')::date;
    end if;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  v_result := jsonb_build_object(
    'customer_id', v_customer_id::text,
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

  return v_result;
end;
$$;

comment on function public.normalize_sales_invoice_payload(jsonb) is
  'M6: Canonical sales confirm payload. Unique line_order; secondary product_unit_id sort for hash stability.';

-- ---------------------------------------------------------------------------
-- Internal: sales invoice payload hash
-- ---------------------------------------------------------------------------
create or replace function public.compute_sales_invoice_payload_hash(p_data jsonb)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(public.normalize_sales_invoice_payload(p_data)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_sales_invoice_payload_hash(jsonb) is
  'M6: SHA-256 hex of the strict normalized sales-invoice payload.';

-- ---------------------------------------------------------------------------
-- Internal: customer A/R account validation (entity-linked leaf)
-- ---------------------------------------------------------------------------
create or replace function public.validate_customer_ar_account(
  p_tenant_id uuid,
  p_customer_id uuid,
  p_account_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_customer public.customers%rowtype;
  v_acct public.chart_of_accounts%rowtype;
  v_ar_parent uuid;
  v_child_count bigint;
begin
  select * into v_customer
  from public.customers
  where id = p_customer_id
    and tenant_id = p_tenant_id;

  if not found or not coalesce(v_customer.is_active, false) then
    raise exception 'validation_failed';
  end if;

  if v_customer.account_id is null then
    raise exception 'validation_failed';
  end if;

  if p_account_id is not null and v_customer.account_id is distinct from p_account_id then
    raise exception 'validation_failed';
  end if;

  select * into v_acct
  from public.chart_of_accounts
  where id = coalesce(p_account_id, v_customer.account_id);

  if not found or v_acct.tenant_id <> p_tenant_id then
    raise exception 'cross_tenant_reference';
  end if;

  select id into v_ar_parent
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = '1201';

  if v_acct.type <> 'asset'
    or not v_acct.is_active
    or v_acct.parent_id is distinct from v_ar_parent
    or v_acct.related_entity_table is distinct from 'customers'
    or v_acct.related_entity_id is distinct from p_customer_id then
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

comment on function public.validate_customer_ar_account(uuid, uuid, uuid) is
  'M6: Validates active customer-linked A/R posting leaf for sales posting.';

-- ---------------------------------------------------------------------------
-- Internal: system sales revenue account 4101 (income)
-- ---------------------------------------------------------------------------
create or replace function public.resolve_system_sales_revenue_account(p_tenant_id uuid)
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
    and code = '4101';

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

comment on function public.resolve_system_sales_revenue_account(uuid) is
  'M6: Resolves validated tenant system sales revenue account 4101 (income leaf, not entity-linked).';

-- ---------------------------------------------------------------------------
-- Internal: system COGS account 5101 (expense)
-- ---------------------------------------------------------------------------
create or replace function public.resolve_system_cogs_account(p_tenant_id uuid)
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
    and code = '5101';

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_acct.type <> 'expense'
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

comment on function public.resolve_system_cogs_account(uuid) is
  'M6: Resolves validated tenant system COGS account 5101 (expense leaf, not entity-linked).';

-- ---------------------------------------------------------------------------
-- Internal: strip product_unit_id before tax totals
-- ---------------------------------------------------------------------------
create or replace function public.sales_calc_lines_for_totals(p_lines jsonb)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      case
        when elem ? 'product_unit_id' then elem - 'product_unit_id'
        else elem
      end
      order by (elem ->> 'line_order')::int
    ),
    '[]'::jsonb
  )
  from jsonb_array_elements(p_lines) as elem;
$$;

comment on function public.sales_calc_lines_for_totals(jsonb) is
  'M6: Removes product_unit_id from sales lines before calculate_invoice_totals_internal.';

-- ---------------------------------------------------------------------------
-- Internal: sales invoice read permission
-- ---------------------------------------------------------------------------
create or replace function public.assert_sales_invoice_view()
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
    public.user_has_permission('invoices.view_sales')
    or public.user_has_permission('invoices.view')
  ) then
    raise exception 'permission_denied';
  end if;
end;
$$;

comment on function public.assert_sales_invoice_view() is
  'M6: View permission for sales invoice read RPCs.';

-- ---------------------------------------------------------------------------
-- Internal: min sale price gate
-- ---------------------------------------------------------------------------
create or replace function public.assert_sales_line_min_price(
  p_tenant_id uuid,
  p_product_id uuid,
  p_unit_price numeric
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_min_sale_price numeric(15, 3);
begin
  if public.user_has_permission('invoices.override_min_price') then
    return;
  end if;

  select p.min_sale_price
  into v_min_sale_price
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_min_sale_price is not null and p_unit_price < v_min_sale_price then
    raise exception 'validation_failed';
  end if;
end;
$$;

comment on function public.assert_sales_line_min_price(uuid, uuid, numeric) is
  'M6: Enforces min_sale_price unless invoices.override_min_price.';

-- ---------------------------------------------------------------------------
-- Internal: reverse purchase WAC on cancellation (global qty basis)
-- ---------------------------------------------------------------------------
create or replace function public.reverse_purchase_wac_internal(
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
  v_current_avg numeric(15, 3);
  v_post_qty numeric(15, 3);
  v_pre_qty numeric(15, 3);
  v_post_qty_at_purchase numeric(15, 3);
  v_pre_avg numeric(15, 3);
begin
  if p_incoming_qty is null or p_incoming_qty <= 0 then
    raise exception 'validation_failed';
  end if;

  if p_incoming_value is null or p_incoming_value < 0 then
    raise exception 'validation_failed';
  end if;

  select p.avg_cost
  into v_current_avg
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

  -- Called after stock reversal: v_post_qty is qty before the cancelled purchase.
  v_pre_qty := v_post_qty;
  v_post_qty_at_purchase := v_post_qty + p_incoming_qty;

  if v_post_qty_at_purchase < p_incoming_qty then
    raise exception 'return_document_required';
  end if;

  if v_pre_qty = 0 then
    v_pre_avg := 0;
  else
    v_pre_avg := (
      (v_current_avg * v_post_qty_at_purchase) - p_incoming_value
    ) / v_pre_qty;

    if v_pre_avg < 0 then
      raise exception 'return_document_required';
    end if;
  end if;

  update public.products
  set
    avg_cost = v_pre_avg,
    updated_at = now(),
    updated_by = auth.uid()
  where id = p_product_id
    and tenant_id = p_tenant_id;
end;
$$;

comment on function public.reverse_purchase_wac_internal(uuid, uuid, numeric, numeric) is
  'M6: Deterministic WAC undo using sum(qty_available) across warehouses (inverse of apply_purchase_wac_internal).';

-- ---------------------------------------------------------------------------
-- Internal: block purchase cancel when later movements exist
-- ---------------------------------------------------------------------------
create or replace function public.assert_no_post_purchase_movements(
  p_tenant_id uuid,
  p_invoice_id uuid,
  p_product_ids uuid[]
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_product_id uuid;
begin
  if p_product_ids is null or array_length(p_product_ids, 1) is null then
    return;
  end if;

  foreach v_product_id in array p_product_ids loop
    if exists (
      select 1
      from public.inventory_movements m
      where m.tenant_id = p_tenant_id
        and m.product_id = v_product_id
        and not (
          m.reference_table = 'purchase_invoice'
          and m.reference_id = p_invoice_id
        )
        and exists (
          select 1
          from public.inventory_movements o
          where o.tenant_id = p_tenant_id
            and o.product_id = v_product_id
            and o.reference_table = 'purchase_invoice'
            and o.reference_id = p_invoice_id
            and (
              m.occurred_at > o.occurred_at
              or (m.occurred_at = o.occurred_at and m.id <> o.id)
            )
        )
    ) then
      raise exception 'return_document_required';
    end if;
  end loop;
end;
$$;

comment on function public.assert_no_post_purchase_movements(uuid, uuid, uuid[]) is
  'M6: Conservative post-purchase movement guard using occurred_at and id-at-same-timestamp.';

-- ---------------------------------------------------------------------------
-- Internal: cancel invoice payload normalization
-- ---------------------------------------------------------------------------
create or replace function public.normalize_cancel_invoice_payload(
  p_invoice_id uuid,
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
  if p_invoice_id is null then
    raise exception 'validation_failed';
  end if;

  v_reason := btrim(coalesce(p_reason, ''));
  if v_reason = '' then
    raise exception 'validation_failed';
  end if;

  return jsonb_build_object(
    'invoice_id', p_invoice_id::text,
    'reason', v_reason
  );
end;
$$;

comment on function public.normalize_cancel_invoice_payload(uuid, text) is
  'M6: Canonical cancel-invoice payload for idempotency hashing.';

create or replace function public.compute_cancel_invoice_payload_hash(
  p_invoice_id uuid,
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
        public.normalize_cancel_invoice_payload(p_invoice_id, p_reason)::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_cancel_invoice_payload_hash(uuid, text) is
  'M6: SHA-256 hex of canonical cancel-invoice payload.';

-- ---------------------------------------------------------------------------
-- Internal: invoice payment/allocation cancellation guards
-- ---------------------------------------------------------------------------
create or replace function public.assert_invoice_cancellable_no_payments(
  p_tenant_id uuid,
  p_invoice_id uuid,
  p_paid_amount numeric
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(p_paid_amount, 0) > 0 then
    raise exception 'validation_failed';
  end if;

  if exists (
    select 1
    from public.voucher_invoice_allocations via
    where via.tenant_id = p_tenant_id
      and via.invoice_id = p_invoice_id
      and coalesce(via.is_reversed, false) = false
  ) then
    raise exception 'validation_failed';
  end if;
end;
$$;

comment on function public.assert_invoice_cancellable_no_payments(uuid, uuid, numeric) is
  'M6: Rejects cancellation when paid_amount > 0 or active voucher allocations exist.';

-- ---------------------------------------------------------------------------
-- Internal: sales unit reversal safety
-- ---------------------------------------------------------------------------
create or replace function public.assert_sales_unit_reversal_safe(
  p_tenant_id uuid,
  p_unit_id uuid,
  p_invoice_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_unit public.product_units%rowtype;
  v_sale_event_id uuid;
  v_sale_occurred_at timestamptz;
begin
  select * into v_unit
  from public.product_units pu
  where pu.id = p_unit_id
    and pu.tenant_id = p_tenant_id
  for update;

  if not found or v_unit.status is distinct from 'sold' then
    raise exception 'return_document_required';
  end if;

  select ue.id, ue.occurred_at
  into v_sale_event_id, v_sale_occurred_at
  from public.unit_events ue
  where ue.tenant_id = p_tenant_id
    and ue.product_unit_id = p_unit_id
    and ue.reference_table = 'sales_invoice'
    and ue.reference_id = p_invoice_id
    and ue.event_type = 'sales_invoice'
  order by ue.occurred_at desc, ue.id desc
  limit 1;

  if v_sale_event_id is null then
    raise exception 'validation_failed';
  end if;

  if exists (
    select 1
    from public.unit_events ue
    where ue.tenant_id = p_tenant_id
      and ue.product_unit_id = p_unit_id
      and ue.id <> v_sale_event_id
      and (
        ue.occurred_at > v_sale_occurred_at
        or (ue.occurred_at = v_sale_occurred_at and ue.id <> v_sale_event_id)
      )
  ) then
    raise exception 'return_document_required';
  end if;
end;
$$;

comment on function public.assert_sales_unit_reversal_safe(uuid, uuid, uuid) is
  'M6: Ensures serialized unit can be safely restored on sales invoice cancellation.';

-- ---------------------------------------------------------------------------
-- Internal: purchase cancellation safety
-- ---------------------------------------------------------------------------
create or replace function public.assert_purchase_cancellation_safe(
  p_tenant_id uuid,
  p_invoice_id uuid,
  p_warehouse_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_product_ids uuid[] := '{}';
begin
  select coalesce(array_agg(distinct il.product_id), '{}')
  into v_product_ids
  from public.invoice_lines il
  where il.tenant_id = p_tenant_id
    and il.invoice_id = p_invoice_id;

  perform public.assert_no_post_purchase_movements(
    p_tenant_id,
    p_invoice_id,
    v_product_ids
  );

  if exists (
    select 1
    from public.product_units pu
    where pu.tenant_id = p_tenant_id
      and pu.purchase_invoice_id = p_invoice_id
      and (
        pu.status not in ('available_new', 'available_used')
        or pu.current_warehouse_id is distinct from p_warehouse_id
      )
  ) then
    raise exception 'return_document_required';
  end if;
end;
$$;

comment on function public.assert_purchase_cancellation_safe(uuid, uuid, uuid) is
  'M6: Purchase invoice cancellation safety (units + movement guard).';

-- ---------------------------------------------------------------------------
-- Public: record confirmed sales invoice
-- ---------------------------------------------------------------------------
create or replace function public.record_sales_invoice(
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
  v_customer_id uuid;
  v_warehouse_id uuid;
  v_invoice_id uuid;
  v_date date;
  v_due_date date;
  v_notes text;
  v_books_locked_through date;
  v_tax_enabled boolean;
  v_ar_account_id uuid;
  v_revenue_account uuid;
  v_cogs_account uuid;
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
  v_line_unit_price numeric(15, 3);
  v_product_id uuid;
  v_product_unit_id uuid;
  v_is_serialized boolean;
  v_can_be_sold boolean;
  v_seen_unit_ids uuid[] := '{}';
  v_lock_rec record;
  v_stock_qty_map jsonb := '{}'::jsonb;
  v_agg_qty numeric(15, 3);
  v_available_qty numeric(15, 3);
  v_dist_product_id text;
  v_cost_price numeric(15, 3);
  v_cogs_total numeric(15, 3) := 0;
  v_revenue_total numeric(15, 3) := 0;
  v_tax_rate_id uuid;
  v_output_account_id uuid;
  v_je_line_order int := 0;
  v_movement_id uuid;
  v_unit_product_id uuid;
  v_unit_status public.unit_status;
  v_unit_warehouse_id uuid;
  v_prev_status text;
  v_prev_warehouse_id uuid;
  v_validated_output_accounts uuid[] := '{}';
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('invoices.create_sales') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_sales_invoice_payload(p_data);
  v_hash := public.compute_sales_invoice_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_id := public.resolve_finance_idempotency(
    'public.invoices'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  v_customer_id := (v_normalized ->> 'customer_id')::uuid;
  v_warehouse_id := (v_normalized ->> 'warehouse_id')::uuid;
  v_date := (v_normalized ->> 'date')::date;

  if v_normalized ? 'due_date' then
    v_due_date := (v_normalized ->> 'due_date')::date;
  end if;

  if v_normalized ? 'notes' then
    v_notes := v_normalized ->> 'notes';
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

  perform public.validate_customer_ar_account(v_tenant_id, v_customer_id, null);

  select c.account_id
  into v_ar_account_id
  from public.customers c
  where c.id = v_customer_id
    and c.tenant_id = v_tenant_id;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line_input ->> 'line_order')::int;
    v_product_id := (v_line_input ->> 'product_id')::uuid;
    v_line_qty := (v_line_input ->> 'qty')::numeric(15, 3);
    v_line_unit_price := (v_line_input ->> 'unit_price')::numeric(15, 3);

    if v_line_qty is null or v_line_qty <= 0 then
      raise exception 'validation_failed';
    end if;

    if v_line_unit_price is null or v_line_unit_price < 0 then
      raise exception 'validation_failed';
    end if;

    perform public.assert_sales_line_min_price(v_tenant_id, v_product_id, v_line_unit_price);

    select p.is_serialized, p.can_be_sold
    into v_is_serialized, v_can_be_sold
    from public.products p
    where p.id = v_product_id
      and p.tenant_id = v_tenant_id
      and coalesce(p.is_active, false);

    if not found or not coalesce(v_can_be_sold, false) then
      raise exception 'validation_failed';
    end if;

    if v_is_serialized then
      if v_line_qty <> 1
        or not (v_line_input ? 'product_unit_id')
        or btrim(coalesce(v_line_input ->> 'product_unit_id', '')) = '' then
        raise exception 'validation_failed';
      end if;

      v_product_unit_id := (v_line_input ->> 'product_unit_id')::uuid;
      if v_product_unit_id = any (v_seen_unit_ids) then
        raise exception 'validation_failed';
      end if;
      v_seen_unit_ids := array_append(v_seen_unit_ids, v_product_unit_id);
    elsif v_line_input ? 'product_unit_id' then
      raise exception 'validation_failed';
    end if;

    v_dist_product_id := v_product_id::text;
    v_agg_qty := coalesce((v_stock_qty_map ->> v_dist_product_id)::numeric, 0) + v_line_qty;
    v_stock_qty_map := v_stock_qty_map || jsonb_build_object(v_dist_product_id, v_agg_qty);
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

  for v_product_unit_id in
    select distinct (elem ->> 'product_unit_id')::uuid
    from jsonb_array_elements(v_normalized -> 'lines') as elem
    where elem ? 'product_unit_id'
    order by 1
  loop
    perform 1
    from public.product_units pu
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id
    for update;
  end loop;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    if (v_line_input ->> 'product_unit_id') is not null then
      v_product_unit_id := (v_line_input ->> 'product_unit_id')::uuid;
      v_product_id := (v_line_input ->> 'product_id')::uuid;

      select pu.product_id, pu.status, pu.current_warehouse_id
      into v_unit_product_id, v_unit_status, v_unit_warehouse_id
      from public.product_units pu
      where pu.id = v_product_unit_id
        and pu.tenant_id = v_tenant_id;

      if not found
        or v_unit_product_id is distinct from v_product_id
        or v_unit_status not in ('available_new', 'available_used')
        or v_unit_warehouse_id is distinct from v_warehouse_id then
        raise exception 'validation_failed';
      end if;
    end if;
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_stock_qty_map)
  loop
    v_agg_qty := (v_stock_qty_map ->> v_dist_product_id)::numeric(15, 3);

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

  v_calc_lines := public.sales_calc_lines_for_totals(v_normalized -> 'lines');
  v_totals := public.calculate_invoice_totals_internal(
    v_tenant_id,
    'sales',
    v_date,
    v_calc_lines
  );
  v_total := (v_totals ->> 'total')::numeric(15, 3);

  if v_total is null or v_total <= 0 then
    raise exception 'validation_failed';
  end if;

  v_revenue_account := public.resolve_system_sales_revenue_account(v_tenant_id);
  v_cogs_account := public.resolve_system_cogs_account(v_tenant_id);
  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);

  perform public.validate_tax_posting_account(
    v_tenant_id, v_revenue_account, 'income', true
  );

  for v_line_snap in
    select value
    from jsonb_array_elements(v_totals -> 'lines') as snap(value)
  loop
    v_tax_rate_id := nullif(v_line_snap ->> 'tax_rate_id', '')::uuid;
    if coalesce(v_tax_enabled, false)
      and coalesce((v_line_snap ->> 'tax_amount')::numeric, 0) > 0
      and v_tax_rate_id is not null then
      select tr.output_account_id
      into v_output_account_id
      from public.tax_rates tr
      where tr.id = v_tax_rate_id
        and tr.tenant_id = v_tenant_id;

      if not found or v_output_account_id is null then
        raise exception 'validation_failed';
      end if;

      if not (v_output_account_id = any (v_validated_output_accounts)) then
        perform public.validate_tax_posting_account(
          v_tenant_id, v_output_account_id, 'liability', true
        );
        v_validated_output_accounts := array_append(
          v_validated_output_accounts,
          v_output_account_id
        );
      end if;
    end if;
  end loop;

  perform public.allow_finance_write();

  v_invoice_number := public.next_document_number('SI');
  v_invoice_id := gen_random_uuid();

  insert into public.invoices (
    id, tenant_id, type, status, customer_id, warehouse_id,
    date, due_date, notes, invoice_number,
    subtotal, discount_amount, tax_amount, total, paid_amount,
    idempotency_key, idempotency_payload_hash,
    created_by, confirmed_at, confirmed_by
  )
  values (
    v_invoice_id, v_tenant_id, 'sales', 'confirmed', v_customer_id, v_warehouse_id,
    v_date, v_due_date, v_notes, v_invoice_number,
    (v_totals ->> 'subtotal')::numeric(15, 3),
    (v_totals ->> 'discount_amount')::numeric(15, 3),
    (v_totals ->> 'tax_amount')::numeric(15, 3),
    v_total, 0,
    p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

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
    v_product_unit_id := nullif(v_line_input ->> 'product_unit_id', '')::uuid;

    select p.is_serialized, p.avg_cost
    into v_is_serialized, v_cost_price
    from public.products p
    where p.id = v_product_id
      and p.tenant_id = v_tenant_id;

    if v_is_serialized then
      select pu.purchase_cost
      into v_cost_price
      from public.product_units pu
      where pu.id = v_product_unit_id
        and pu.tenant_id = v_tenant_id;

      if v_cost_price is null then
        raise exception 'validation_failed';
      end if;
    end if;

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id, product_unit_id,
      qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, cost_price, line_order
    )
    values (
      v_tenant_id, v_invoice_id, v_product_id, v_product_unit_id,
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
      v_cost_price,
      v_line_order
    );

    v_revenue_total := v_revenue_total + (v_line_snap ->> 'before_tax_amount')::numeric(15, 3);
    v_cogs_total := v_cogs_total + (v_line_qty * v_cost_price);
  end loop;

  for v_dist_product_id in
    select jsonb_object_keys(v_stock_qty_map)
  loop
    v_agg_qty := (v_stock_qty_map ->> v_dist_product_id)::numeric(15, 3);

    update public.inventory_balances
    set qty_available = qty_available - v_agg_qty
    where tenant_id = v_tenant_id
      and warehouse_id = v_warehouse_id
      and product_id = v_dist_product_id::uuid;

    if not found then
      raise exception 'insufficient_stock';
    end if;
  end loop;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_line_order := (v_line_input ->> 'line_order')::int;
    v_product_id := (v_line_input ->> 'product_id')::uuid;
    v_line_qty := (v_line_input ->> 'qty')::numeric(15, 3);
    v_product_unit_id := nullif(v_line_input ->> 'product_unit_id', '')::uuid;

    select il.cost_price
    into v_cost_price
    from public.invoice_lines il
    where il.invoice_id = v_invoice_id
      and il.tenant_id = v_tenant_id
      and il.line_order = v_line_order;

    v_movement_id := gen_random_uuid();
    insert into public.inventory_movements (
      id, tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, unit_cost, reference_table, reference_id, notes, created_by
    )
    values (
      v_movement_id, v_tenant_id, 'sale', v_warehouse_id, v_product_id, v_product_unit_id,
      v_line_qty, v_cost_price, 'sales_invoice', v_invoice_id,
      'Sales invoice ' || v_invoice_number, auth.uid()
    );
  end loop;

  for v_line_input in
    select value
    from jsonb_array_elements(v_normalized -> 'lines')
    order by (value ->> 'line_order')::int
  loop
    v_product_unit_id := nullif(v_line_input ->> 'product_unit_id', '')::uuid;
    if v_product_unit_id is null then
      continue;
    end if;

    select pu.status, pu.current_warehouse_id
    into v_prev_status, v_prev_warehouse_id
    from public.product_units pu
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id;

    insert into public.unit_events (
      tenant_id, product_unit_id, event_type, occurred_at,
      warehouse_id, customer_id,
      reference_table, reference_id, notes, metadata_json, created_by
    )
    values (
      v_tenant_id, v_product_unit_id, 'sales_invoice', now(),
      v_prev_warehouse_id, v_customer_id,
      'sales_invoice', v_invoice_id,
      'Sales invoice ' || v_invoice_number,
      jsonb_build_object(
        'previous_status', v_prev_status::text,
        'previous_warehouse_id', v_prev_warehouse_id::text
      ),
      auth.uid()
    );

    update public.product_units
    set
      status = 'sold',
      current_warehouse_id = null,
      current_customer_id = v_customer_id,
      updated_at = now()
    where id = v_product_unit_id
      and tenant_id = v_tenant_id;
  end loop;

  v_journal_number := public.next_document_number('JE');
  v_journal_entry_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'sales_invoice', v_invoice_id,
    'Sales invoice ' || v_invoice_number, false, auth.uid()
  );

  v_je_line_order := v_je_line_order + 1;
  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    v_tenant_id, v_journal_entry_id, v_ar_account_id,
    v_total, 0, v_je_line_order, 'Customer A/R'
  );

  if v_revenue_total > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_revenue_account,
      0, v_revenue_total, v_je_line_order, 'Sales revenue'
    );
  end if;

  for v_output_account_id, v_agg_qty in
    select tr.output_account_id, sum((snap.value ->> 'tax_amount')::numeric(15, 3))
    from jsonb_array_elements(v_totals -> 'lines') as snap(value)
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
      0, v_agg_qty, v_je_line_order, 'Output tax payable'
    );
  end loop;

  if v_cogs_total > 0 then
    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_cogs_account,
      v_cogs_total, 0, v_je_line_order, 'Cost of goods sold'
    );

    v_je_line_order := v_je_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_inventory_account,
      0, v_cogs_total, v_je_line_order, 'Inventory'
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
  where id = v_invoice_id
    and tenant_id = v_tenant_id;

  return v_invoice_id;
end;
$$;

comment on function public.record_sales_invoice(jsonb, uuid) is
  'M6: Atomic confirmed sales invoice with stock-out, frozen COGS, balanced A/R/revenue/tax journal.';

-- ---------------------------------------------------------------------------
-- Public: cancel invoice (sales or purchase)
-- ---------------------------------------------------------------------------
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
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_je_id uuid;
  v_invoice public.invoices%rowtype;
  v_reversal_je_id uuid;
  v_reversal_number text;
  v_jl record;
  v_je_line_order int := 0;
  v_line record;
  v_wac_line record;
  v_stock_map jsonb := '{}'::jsonb;
  v_agg_qty numeric(15, 3);
  v_available_qty numeric(15, 3);
  v_dist_product_id text;
  v_wac_qty numeric(15, 3);
  v_wac_value numeric(15, 3);
  v_tax_enabled boolean;
  v_line_snap jsonb;
  v_prev_status text;
  v_prev_warehouse_id uuid;
  v_product_id_loop uuid;
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

  perform public.normalize_cancel_invoice_payload(p_invoice_id, p_reason);
  v_hash := public.compute_cancel_invoice_payload_hash(p_invoice_id, p_reason);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_je_id := public.resolve_finance_idempotency(
    'public.journal_entries'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_je_id is not null then
    select i.id
    into p_invoice_id
    from public.invoices i
    where i.tenant_id = v_tenant_id
      and i.reversal_journal_entry_id = v_existing_je_id;

    if not found then
      select je.source_id
      into p_invoice_id
      from public.journal_entries je
      where je.id = v_existing_je_id
        and je.tenant_id = v_tenant_id;
    end if;

    if p_invoice_id is null then
      raise exception 'validation_failed';
    end if;

    return p_invoice_id;
  end if;

  select * into v_invoice
  from public.invoices i
  where i.id = p_invoice_id
    and i.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_invoice.status = 'cancelled' then
    raise exception 'validation_failed';
  end if;

  if v_invoice.type not in ('sales', 'purchase') then
    raise exception 'validation_failed';
  end if;

  if v_invoice.journal_entry_id is null then
    raise exception 'validation_failed';
  end if;

  perform public.assert_invoice_cancellable_no_payments(
    v_tenant_id,
    p_invoice_id,
    v_invoice.paid_amount
  );

  select ts.tax_enabled
  into v_tax_enabled
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  perform 1
  from public.journal_entries je
  where je.id = v_invoice.journal_entry_id
    and je.tenant_id = v_tenant_id
  for update;

  for v_dist_product_id in
    select distinct il.product_id::text
    from public.invoice_lines il
    where il.invoice_id = p_invoice_id
      and il.tenant_id = v_tenant_id
    order by 1
  loop
    perform 1
    from public.products p
    where p.id = v_dist_product_id::uuid
      and p.tenant_id = v_tenant_id
    for update;
  end loop;

  if v_invoice.type = 'sales' then
    for v_line in
      select il.*
      from public.invoice_lines il
      where il.invoice_id = p_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      if v_line.product_unit_id is not null then
        perform public.assert_sales_unit_reversal_safe(
          v_tenant_id,
          v_line.product_unit_id,
          p_invoice_id
        );
        perform 1
        from public.product_units pu
        where pu.id = v_line.product_unit_id
          and pu.tenant_id = v_tenant_id
        for update;
      end if;

      v_agg_qty := coalesce((v_stock_map ->> v_line.product_id::text)::numeric, 0) + v_line.qty;
      v_stock_map := v_stock_map || jsonb_build_object(v_line.product_id::text, v_agg_qty);
    end loop;

    for v_dist_product_id in
      select jsonb_object_keys(v_stock_map)
    loop
      perform 1
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.warehouse_id = v_invoice.warehouse_id
        and ib.product_id = v_dist_product_id::uuid
      for update;
    end loop;

    perform public.allow_finance_write();

    for v_line in
      select il.*
      from public.invoice_lines il
      where il.invoice_id = p_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      insert into public.inventory_movements (
        tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
        qty, unit_cost, reference_table, reference_id, notes, created_by
      )
      values (
        v_tenant_id, 'sale', v_invoice.warehouse_id, v_line.product_id, v_line.product_unit_id,
        -v_line.qty, v_line.cost_price, 'sales_invoice', p_invoice_id,
        'Sales invoice cancellation reversal ' || coalesce(v_invoice.invoice_number, p_invoice_id::text),
        auth.uid()
      );

      if v_line.product_unit_id is not null then
        select ue.metadata_json ->> 'previous_status', ue.metadata_json ->> 'previous_warehouse_id'
        into v_prev_status, v_prev_warehouse_id
        from public.unit_events ue
        where ue.tenant_id = v_tenant_id
          and ue.product_unit_id = v_line.product_unit_id
          and ue.reference_table = 'sales_invoice'
          and ue.reference_id = p_invoice_id
          and ue.event_type = 'sales_invoice'
        order by ue.occurred_at desc, ue.id desc
        limit 1;

        if v_prev_status is null or v_prev_warehouse_id is null then
          raise exception 'validation_failed';
        end if;

        update public.product_units
        set
          status = v_prev_status::public.unit_status,
          current_warehouse_id = v_prev_warehouse_id::uuid,
          current_customer_id = null,
          updated_at = now()
        where id = v_line.product_unit_id
          and tenant_id = v_tenant_id;

        insert into public.unit_events (
          tenant_id, product_unit_id, event_type, occurred_at,
          warehouse_id, reference_table, reference_id, notes, metadata_json, created_by
        )
        values (
          v_tenant_id, v_line.product_unit_id, 'sales_invoice_cancellation', now(),
          v_prev_warehouse_id::uuid, 'sales_invoice', p_invoice_id,
          btrim(p_reason),
          jsonb_build_object(
            'restored_status', v_prev_status,
            'restored_warehouse_id', v_prev_warehouse_id
          ),
          auth.uid()
        );
      end if;
    end loop;

    for v_dist_product_id in
      select jsonb_object_keys(v_stock_map)
    loop
      v_agg_qty := (v_stock_map ->> v_dist_product_id)::numeric(15, 3);

      update public.inventory_balances
      set qty_available = qty_available + v_agg_qty
      where tenant_id = v_tenant_id
        and warehouse_id = v_invoice.warehouse_id
        and product_id = v_dist_product_id::uuid;

      if not found then
        insert into public.inventory_balances (
          tenant_id, warehouse_id, product_id, qty_available
        )
        values (
          v_tenant_id, v_invoice.warehouse_id, v_dist_product_id::uuid, v_agg_qty
        );
      end if;
    end loop;

  elsif v_invoice.type = 'purchase' then
    perform public.assert_purchase_cancellation_safe(
      v_tenant_id,
      p_invoice_id,
      v_invoice.warehouse_id
    );

    for v_line in
      select il.*
      from public.invoice_lines il
      where il.invoice_id = p_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      perform 1
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.warehouse_id = v_invoice.warehouse_id
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
      where il.invoice_id = p_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.line_order
    loop
      insert into public.inventory_movements (
        tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
        qty, unit_cost, reference_table, reference_id, notes, created_by
      )
      values (
        v_tenant_id, 'purchase', v_invoice.warehouse_id, v_line.product_id, v_line.product_unit_id,
        -v_line.qty, v_line.cost_price, 'purchase_invoice', p_invoice_id,
        'Purchase invoice cancellation reversal ' || coalesce(v_invoice.invoice_number, p_invoice_id::text),
        auth.uid()
      );
    end loop;

    for v_dist_product_id in
      select jsonb_object_keys(v_stock_map)
    loop
      v_agg_qty := (v_stock_map ->> v_dist_product_id)::numeric(15, 3);

      update public.inventory_balances
      set qty_available = qty_available - v_agg_qty
      where tenant_id = v_tenant_id
        and warehouse_id = v_invoice.warehouse_id
        and product_id = v_dist_product_id::uuid;

      if not found then
        raise exception 'return_document_required';
      end if;

      select ib.qty_available
      into v_available_qty
      from public.inventory_balances ib
      where ib.tenant_id = v_tenant_id
        and ib.warehouse_id = v_invoice.warehouse_id
        and ib.product_id = v_dist_product_id::uuid;

      if coalesce(v_available_qty, 0) < 0 then
        raise exception 'return_document_required';
      end if;
    end loop;

    for v_line in
      select pu.*
      from public.product_units pu
      where pu.tenant_id = v_tenant_id
        and pu.purchase_invoice_id = p_invoice_id
      order by pu.id
    loop
      insert into public.unit_events (
        tenant_id, product_unit_id, event_type, occurred_at,
        warehouse_id, reference_table, reference_id, notes, metadata_json, created_by
      )
      values (
        v_tenant_id, v_line.id, 'purchase_invoice_cancellation', now(),
        v_line.current_warehouse_id, 'purchase_invoice', p_invoice_id,
        btrim(p_reason),
        jsonb_build_object(
          'previous_status', v_line.status::text,
          'previous_warehouse_id', v_line.current_warehouse_id::text
        ),
        auth.uid()
      );

      update public.product_units
      set
        status = 'retired',
        current_warehouse_id = null,
        updated_at = now()
      where id = v_line.id
        and tenant_id = v_tenant_id;
    end loop;

    for v_product_id_loop in
      select distinct il.product_id
      from public.invoice_lines il
      where il.invoice_id = p_invoice_id
        and il.tenant_id = v_tenant_id
      order by il.product_id
    loop
      select coalesce(sum(il.qty), 0)
      into v_wac_qty
      from public.invoice_lines il
      where il.invoice_id = p_invoice_id
        and il.tenant_id = v_tenant_id
        and il.product_id = v_product_id_loop;

      v_wac_value := 0;
      for v_wac_line in
        select il.tax_rate_id, il.tax_amount, il.before_tax_amount
        from public.invoice_lines il
        where il.invoice_id = p_invoice_id
          and il.tenant_id = v_tenant_id
          and il.product_id = v_product_id_loop
      loop
        v_line_snap := jsonb_build_object(
          'tax_rate_id', v_wac_line.tax_rate_id::text,
          'tax_amount', v_wac_line.tax_amount,
          'before_tax_amount', v_wac_line.before_tax_amount
        );
        v_wac_value := v_wac_value + public.purchase_line_capitalized_amount(
          v_tenant_id,
          v_tax_enabled,
          v_line_snap
        );
      end loop;

      perform public.reverse_purchase_wac_internal(
        v_tenant_id,
        v_product_id_loop,
        v_wac_qty,
        v_wac_value
      );
    end loop;
  end if;

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
    v_reversal_je_id, v_tenant_id, v_reversal_number, v_invoice.date,
    (case
      when v_invoice.type = 'sales' then 'sales_invoice_reversal'
      else 'purchase_invoice_reversal'
    end)::public.journal_source,
    p_invoice_id,
    'Cancellation ' || coalesce(v_invoice.invoice_number, p_invoice_id::text),
    false,
    auth.uid(),
    v_invoice.journal_entry_id,
    p_idempotency_key,
    v_hash
  );

  for v_jl in
    select jl.*
    from public.journal_lines jl
    where jl.journal_entry_id = v_invoice.journal_entry_id
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
  where id = p_invoice_id
    and tenant_id = v_tenant_id;

  return p_invoice_id;
end;
$$;

comment on function public.cancel_invoice(uuid, text, uuid) is
  'M6: Safe sales or purchase invoice cancellation with reversal movements and journal.';

-- ---------------------------------------------------------------------------
-- Public: list sales invoices
-- ---------------------------------------------------------------------------
create or replace function public.list_sales_invoices(
  p_customer_id uuid default null,
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
  customer_id uuid,
  customer_name_ar text,
  customer_name_en text,
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

  perform public.assert_sales_invoice_view();

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    i.id,
    i.invoice_number,
    i.customer_id,
    c.name_ar as customer_name_ar,
    c.name_en as customer_name_en,
    i.status,
    i.date,
    i.due_date,
    i.subtotal,
    i.discount_amount,
    i.tax_amount,
    i.total,
    i.paid_amount,
    (i.total - i.paid_amount) as outstanding,
    cur.iso_code as currency_code,
    coalesce(cur.major_symbol_ar, cur.major_symbol_en) as currency_symbol,
    coalesce(cur.decimal_places, 3) as currency_decimal_places,
    i.cancelled_at
  from public.invoices i
  join public.customers c
    on c.id = i.customer_id
    and c.tenant_id = i.tenant_id
  join public.tenants t on t.id = i.tenant_id
  left join public.currencies cur on cur.id = t.default_currency_id
  where i.tenant_id = v_tenant_id
    and i.type = 'sales'
    and (p_customer_id is null or i.customer_id = p_customer_id)
    and (p_status is null or i.status::text = p_status)
    and (p_date_from is null or i.date >= p_date_from)
    and (p_date_to is null or i.date <= p_date_to)
    and (
      v_search is null
      or lower(coalesce(i.invoice_number, '')) like '%' || v_search || '%'
      or lower(coalesce(c.name_ar, '')) like '%' || v_search || '%'
      or lower(coalesce(c.name_en, '')) like '%' || v_search || '%'
    )
  order by i.date desc nulls last, i.invoice_number desc nulls last, i.id desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

comment on function public.list_sales_invoices(uuid, text, date, date, text, integer, integer) is
  'M6: Bounded sales invoice list with customer labels and currency metadata.';

-- ---------------------------------------------------------------------------
-- Public: sales invoice detail
-- ---------------------------------------------------------------------------
create or replace function public.get_sales_invoice_detail(p_invoice_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_invoice public.invoices%rowtype;
  v_customer public.customers%rowtype;
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

  perform public.assert_sales_invoice_view();

  select * into v_invoice
  from public.invoices i
  where i.id = p_invoice_id
    and i.tenant_id = v_tenant_id
    and i.type = 'sales';

  if not found then
    raise exception 'validation_failed';
  end if;

  select * into v_customer
  from public.customers c
  where c.id = v_invoice.customer_id
    and c.tenant_id = v_tenant_id;

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
      'serial_number', pu.serial_number,
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
      'cost_price', il.cost_price
    )
    order by il.line_order
  ), '[]'::jsonb)
  into v_lines
  from public.invoice_lines il
  left join public.product_units pu
    on pu.id = il.product_unit_id
    and pu.tenant_id = il.tenant_id
  where il.invoice_id = v_invoice.id
    and il.tenant_id = v_tenant_id;

  return jsonb_build_object(
    'id', v_invoice.id,
    'invoice_number', v_invoice.invoice_number,
    'status', v_invoice.status,
    'customer', jsonb_build_object(
      'id', v_customer.id,
      'code', v_customer.code,
      'name_ar', v_customer.name_ar,
      'name_en', v_customer.name_en,
      'account_id', v_customer.account_id
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
    'reversal_journal_entry_id', v_invoice.reversal_journal_entry_id,
    'confirmed_at', v_invoice.confirmed_at,
    'cancelled_at', v_invoice.cancelled_at,
    'lines', v_lines
  );
end;
$$;

comment on function public.get_sales_invoice_detail(uuid) is
  'M6: Sales invoice detail JSON with line snapshots and serialized unit metadata.';

-- ---------------------------------------------------------------------------
-- ACL hygiene
-- ---------------------------------------------------------------------------
revoke all on function public.normalize_sales_invoice_payload(jsonb)
  from public, anon, authenticated;
revoke all on function public.compute_sales_invoice_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function public.validate_customer_ar_account(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.resolve_system_sales_revenue_account(uuid)
  from public, anon, authenticated;
revoke all on function public.resolve_system_cogs_account(uuid)
  from public, anon, authenticated;
revoke all on function public.sales_calc_lines_for_totals(jsonb)
  from public, anon, authenticated;
revoke all on function public.assert_sales_invoice_view()
  from public, anon, authenticated;
revoke all on function public.assert_sales_line_min_price(uuid, uuid, numeric)
  from public, anon, authenticated;
revoke all on function public.reverse_purchase_wac_internal(uuid, uuid, numeric, numeric)
  from public, anon, authenticated;
revoke all on function public.assert_no_post_purchase_movements(uuid, uuid, uuid[])
  from public, anon, authenticated;
revoke all on function public.normalize_cancel_invoice_payload(uuid, text)
  from public, anon, authenticated;
revoke all on function public.compute_cancel_invoice_payload_hash(uuid, text)
  from public, anon, authenticated;
revoke all on function public.assert_invoice_cancellable_no_payments(uuid, uuid, numeric)
  from public, anon, authenticated;
revoke all on function public.assert_sales_unit_reversal_safe(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.assert_purchase_cancellation_safe(uuid, uuid, uuid)
  from public, anon, authenticated;

grant execute on function public.record_sales_invoice(jsonb, uuid) to authenticated;
grant execute on function public.cancel_invoice(uuid, text, uuid) to authenticated;
grant execute on function public.list_sales_invoices(uuid, text, date, date, text, integer, integer)
  to authenticated;
grant execute on function public.get_sales_invoice_detail(uuid) to authenticated;
