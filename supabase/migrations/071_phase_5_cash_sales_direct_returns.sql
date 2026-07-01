-- Phase 5 M9 UX closure: POS-style cash sales and direct returns.
-- Enables invoices UI workflows without requiring a party or an original invoice
-- when cash/bank settlement is selected explicitly.

create extension if not exists pgcrypto;

alter table public.invoices
  drop constraint if exists chk_invoices_party_type;

alter table public.invoices
  add constraint chk_invoices_party_type check (
    (
      type in ('sales', 'sales_return', 'rental_monthly', 'opening_balance_customer')
      and supplier_id is null
    )
    or (
      type in ('purchase', 'purchase_return', 'opening_balance_supplier')
      and customer_id is null
    )
  );

alter table public.invoices
  drop constraint if exists chk_invoices_return_linkage;

alter table public.invoices
  add constraint chk_invoices_return_linkage check (
    (
      type in ('sales_return', 'purchase_return')
      and return_reason is not null
      and btrim(return_reason) <> ''
    )
    or (
      type not in ('sales_return', 'purchase_return')
      and original_invoice_id is null
      and return_reason is null
    )
  );

create or replace function public.enforce_return_line_linkage()
returns trigger
language plpgsql
as $$
declare
  v_invoice_type public.invoice_type;
  v_original_invoice_id uuid;
begin
  select i.type, i.original_invoice_id
  into v_invoice_type, v_original_invoice_id
  from public.invoices i
  where i.id = new.invoice_id
    and i.tenant_id = new.tenant_id;

  if v_invoice_type in ('sales_return', 'purchase_return') then
    if v_original_invoice_id is not null and new.original_invoice_line_id is null then
      raise exception 'validation_failed';
    end if;
  elsif new.original_invoice_line_id is not null then
    raise exception 'validation_failed';
  end if;

  return new;
end;
$$;

create or replace function public.normalize_cash_invoice_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_key text;
  v_line jsonb;
  v_line_order int;
  v_seen_orders int[] := '{}';
  v_norm_lines jsonb := '[]'::jsonb;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_qty numeric(15, 3);
  v_unit_price numeric(15, 3);
  v_discount_pct numeric(5, 2);
  v_result jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if v_key not in (
      'customer_id', 'supplier_id', 'cash_account_id', 'date',
      'warehouse_id', 'reason', 'notes', 'lines'
    ) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (p_data ? 'cash_account_id' and p_data ? 'date'
    and p_data ? 'warehouse_id' and p_data ? 'lines') then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'lines') <> 'array'
    or jsonb_array_length(p_data -> 'lines') < 1
    or jsonb_array_length(p_data -> 'lines') > 500 then
    raise exception 'validation_failed';
  end if;

  for v_line in select value from jsonb_array_elements(p_data -> 'lines') loop
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'validation_failed';
    end if;

    if not (v_line ? 'product_id' and v_line ? 'qty'
      and v_line ? 'unit_price' and v_line ? 'discount_pct'
      and v_line ? 'line_order') then
      raise exception 'validation_failed';
    end if;

    begin
      v_line_order := (v_line ->> 'line_order')::int;
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_qty := (v_line ->> 'qty')::numeric(15, 3);
      v_unit_price := (v_line ->> 'unit_price')::numeric(15, 3);
      v_discount_pct := (v_line ->> 'discount_pct')::numeric(5, 2);
      v_product_unit_id := nullif(v_line ->> 'product_unit_id', '')::uuid;
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
    v_norm_lines := v_norm_lines || jsonb_build_array(
      jsonb_strip_nulls(
        jsonb_build_object(
          'line_order', v_line_order,
          'product_id', v_product_id::text,
          'qty', to_jsonb(v_qty),
          'unit_price', to_jsonb(v_unit_price),
          'discount_pct', to_jsonb(v_discount_pct),
          'product_unit_id', v_product_unit_id::text
        )
      )
    );
  end loop;

  select coalesce(jsonb_agg(value order by (value ->> 'line_order')::int), '[]'::jsonb)
  into v_norm_lines
  from jsonb_array_elements(v_norm_lines);

  v_result := jsonb_build_object(
    'cash_account_id', ((p_data ->> 'cash_account_id')::uuid)::text,
    'date', ((p_data ->> 'date')::date)::text,
    'warehouse_id', ((p_data ->> 'warehouse_id')::uuid)::text,
    'lines', v_norm_lines
  );

  if p_data ? 'customer_id' and btrim(coalesce(p_data ->> 'customer_id', '')) <> '' then
    v_result := v_result || jsonb_build_object('customer_id', ((p_data ->> 'customer_id')::uuid)::text);
  end if;
  if p_data ? 'supplier_id' and btrim(coalesce(p_data ->> 'supplier_id', '')) <> '' then
    v_result := v_result || jsonb_build_object('supplier_id', ((p_data ->> 'supplier_id')::uuid)::text);
  end if;
  if p_data ? 'reason' and btrim(coalesce(p_data ->> 'reason', '')) <> '' then
    v_result := v_result || jsonb_build_object('reason', btrim(p_data ->> 'reason'));
  end if;
  if p_data ? 'notes' and btrim(coalesce(p_data ->> 'notes', '')) <> '' then
    v_result := v_result || jsonb_build_object('notes', btrim(p_data ->> 'notes'));
  end if;

  return v_result;
end;
$$;

create or replace function public.compute_cash_invoice_payload_hash(p_data jsonb)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(convert_to(public.normalize_cash_invoice_payload(p_data)::text, 'UTF8'), 'sha256'),
    'hex'
  );
$$;

create or replace function public.record_cash_sales_invoice(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_customer_id uuid;
  v_cash_account_id uuid;
  v_warehouse_id uuid;
  v_date date;
  v_notes text;
  v_tax_enabled boolean;
  v_revenue_account uuid;
  v_cogs_account uuid;
  v_inventory_account uuid;
  v_totals jsonb;
  v_total numeric(15, 3);
  v_invoice_id uuid := gen_random_uuid();
  v_invoice_number text;
  v_journal_entry_id uuid := gen_random_uuid();
  v_journal_number text;
  v_line jsonb;
  v_snap jsonb;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_qty numeric(15, 3);
  v_cost numeric(15, 3);
  v_is_serialized boolean;
  v_stock_map jsonb := '{}'::jsonb;
  v_key text;
  v_agg numeric(15, 3);
  v_available numeric(15, 3);
  v_revenue_total numeric(15, 3) := 0;
  v_cogs_total numeric(15, 3) := 0;
  v_output_account_id uuid;
  v_tax_amount numeric(15, 3);
  v_order int;
begin
  if v_tenant_id is null then raise exception 'tenant_not_found'; end if;
  if not public.user_has_permission('invoices.create_sales') then raise exception 'permission_denied'; end if;
  if p_idempotency_key is null then raise exception 'validation_failed'; end if;

  v_normalized := public.normalize_cash_invoice_payload(p_data);
  v_hash := public.compute_cash_invoice_payload_hash(p_data);
  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_finance_idempotency('public.invoices'::regclass, p_idempotency_key, v_hash);
  if v_existing_id is not null then return v_existing_id; end if;

  v_customer_id := nullif(v_normalized ->> 'customer_id', '')::uuid;
  v_cash_account_id := (v_normalized ->> 'cash_account_id')::uuid;
  v_warehouse_id := (v_normalized ->> 'warehouse_id')::uuid;
  v_date := (v_normalized ->> 'date')::date;
  v_notes := nullif(v_normalized ->> 'notes', '');

  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);
  if v_customer_id is not null then
    perform public.validate_customer_ar_account(v_tenant_id, v_customer_id, null);
  end if;

  select tax_enabled into v_tax_enabled from public.tenant_settings where tenant_id = v_tenant_id;
  v_revenue_account := public.resolve_system_sales_revenue_account(v_tenant_id);
  v_cogs_account := public.resolve_system_cogs_account(v_tenant_id);
  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);

  for v_line in select value from jsonb_array_elements(v_normalized -> 'lines') loop
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(15, 3);
    v_product_unit_id := nullif(v_line ->> 'product_unit_id', '')::uuid;

    select p.is_serialized into v_is_serialized
    from public.products p
    where p.id = v_product_id and p.tenant_id = v_tenant_id and coalesce(p.is_active, false) and coalesce(p.can_be_sold, false);
    if not found then raise exception 'validation_failed'; end if;

    if v_is_serialized and v_product_unit_id is null then raise exception 'validation_failed'; end if;
    if not v_is_serialized and v_product_unit_id is not null then raise exception 'validation_failed'; end if;

    v_agg := coalesce((v_stock_map ->> v_product_id::text)::numeric, 0) + v_qty;
    v_stock_map := v_stock_map || jsonb_build_object(v_product_id::text, v_agg);
  end loop;

  for v_key in select jsonb_object_keys(v_stock_map) loop
    perform 1
    from public.inventory_balances
    where tenant_id = v_tenant_id and warehouse_id = v_warehouse_id and product_id = v_key::uuid
    for update;
  end loop;

  v_totals := public.calculate_invoice_totals_internal(
    v_tenant_id, 'sales', v_date, public.sales_calc_lines_for_totals(v_normalized -> 'lines')
  );
  v_total := (v_totals ->> 'total')::numeric(15, 3);
  if v_total <= 0 then raise exception 'validation_failed'; end if;

  perform public.allow_finance_write();
  v_invoice_number := public.next_document_number('SI');

  insert into public.invoices (
    id, tenant_id, type, status, customer_id, warehouse_id, date, notes,
    invoice_number, subtotal, discount_amount, tax_amount, total, paid_amount,
    idempotency_key, idempotency_payload_hash, created_by, confirmed_at, confirmed_by
  )
  values (
    v_invoice_id, v_tenant_id, 'sales', 'paid', v_customer_id, v_warehouse_id, v_date, v_notes,
    v_invoice_number, (v_totals ->> 'subtotal')::numeric(15, 3),
    (v_totals ->> 'discount_amount')::numeric(15, 3),
    (v_totals ->> 'tax_amount')::numeric(15, 3), v_total, v_total,
    p_idempotency_key, v_hash, auth.uid(), now(), auth.uid()
  );

  for v_line in select value from jsonb_array_elements(v_normalized -> 'lines') order by (value ->> 'line_order')::int loop
    v_order := (v_line ->> 'line_order')::int;
    select value into v_snap from jsonb_array_elements(v_totals -> 'lines') where (value ->> 'line_order')::int = v_order;
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_product_unit_id := nullif(v_line ->> 'product_unit_id', '')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(15, 3);

    select coalesce(case when v_product_unit_id is not null then pu.purchase_cost else p.avg_cost end, 0)
    into v_cost
    from public.products p
    left join public.product_units pu on pu.id = v_product_unit_id and pu.tenant_id = v_tenant_id
    where p.id = v_product_id and p.tenant_id = v_tenant_id;

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id, product_unit_id, qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, cost_price, line_order
    )
    values (
      v_tenant_id, v_invoice_id, v_product_id, v_product_unit_id, v_qty,
      (v_line ->> 'unit_price')::numeric(15, 3), coalesce((v_line ->> 'discount_pct')::numeric(5, 2), 0),
      (v_snap ->> 'gross_amount')::numeric(15, 3), (v_snap ->> 'discount_amount')::numeric(15, 3),
      (v_snap ->> 'before_tax_amount')::numeric(15, 3), (v_snap ->> 'after_tax_amount')::numeric(15, 3),
      nullif(v_snap ->> 'tax_rate_id', '')::uuid, coalesce((v_snap ->> 'tax_rate')::numeric(9, 6), 0),
      (v_snap ->> 'tax_class')::public.product_tax_class, (v_snap ->> 'taxable_amount')::numeric(15, 3),
      (v_snap ->> 'tax_amount')::numeric(15, 3), (v_snap ->> 'line_total')::numeric(15, 3),
      v_cost, v_order
    );

    v_revenue_total := v_revenue_total + (v_snap ->> 'before_tax_amount')::numeric(15, 3);
    v_cogs_total := v_cogs_total + (v_qty * v_cost);
  end loop;

  for v_key in select jsonb_object_keys(v_stock_map) loop
    insert into public.inventory_balances (
      tenant_id, warehouse_id, product_id, qty_available
    )
    values (
      v_tenant_id, v_warehouse_id, v_key::uuid,
      -((v_stock_map ->> v_key)::numeric(15, 3))
    )
    on conflict (warehouse_id, product_id)
    do update
    set qty_available = inventory_balances.qty_available + excluded.qty_available;
  end loop;

  insert into public.inventory_movements (
    tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
    qty, unit_cost, reference_table, reference_id, notes, created_by
  )
  select v_tenant_id, 'sale', v_warehouse_id, il.product_id, il.product_unit_id,
    il.qty, il.cost_price, 'sales_invoice', v_invoice_id,
    'Cash sales invoice ' || v_invoice_number, auth.uid()
  from public.invoice_lines il
  where il.tenant_id = v_tenant_id and il.invoice_id = v_invoice_id;

  update public.product_units pu
  set status = 'sold', current_warehouse_id = null, current_customer_id = v_customer_id, updated_at = now()
  from public.invoice_lines il
  where il.tenant_id = v_tenant_id and il.invoice_id = v_invoice_id
    and il.product_unit_id = pu.id and pu.tenant_id = v_tenant_id;

  v_journal_number := public.next_document_number('JE');
  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id, description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'sales_invoice', v_invoice_id, 'Cash sales invoice ' || v_invoice_number, false, auth.uid()
  );

  insert into public.journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order, description)
  values (v_tenant_id, v_journal_entry_id, v_cash_account_id, v_total, 0, 1, 'Cash/Bank');

  insert into public.journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order, description)
  values (v_tenant_id, v_journal_entry_id, v_revenue_account, 0, v_revenue_total, 2, 'Sales revenue');

  for v_output_account_id, v_tax_amount in
    select tr.output_account_id, sum((snap.value ->> 'tax_amount')::numeric(15, 3))
    from jsonb_array_elements(v_totals -> 'lines') snap(value)
    join public.tax_rates tr on tr.id = nullif(snap.value ->> 'tax_rate_id', '')::uuid and tr.tenant_id = v_tenant_id
    where coalesce(v_tax_enabled, false) and coalesce((snap.value ->> 'tax_amount')::numeric, 0) > 0
    group by tr.output_account_id
  loop
    insert into public.journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order, description)
    values (v_tenant_id, v_journal_entry_id, v_output_account_id, 0, v_tax_amount, 3, 'Output tax payable');
  end loop;

  if v_cogs_total > 0 then
    insert into public.journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order, description)
    values
      (v_tenant_id, v_journal_entry_id, v_cogs_account, v_cogs_total, 0, 10, 'Cost of goods sold'),
      (v_tenant_id, v_journal_entry_id, v_inventory_account, 0, v_cogs_total, 11, 'Inventory');
  end if;

  update public.journal_entries set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_journal_entry_id and tenant_id = v_tenant_id;

  update public.invoices set journal_entry_id = v_journal_entry_id
  where id = v_invoice_id and tenant_id = v_tenant_id;

  return v_invoice_id;
end;
$$;

grant execute on function public.record_cash_sales_invoice(jsonb, uuid) to authenticated;

create or replace function public.record_direct_sales_return(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_customer_id uuid;
  v_cash_account_id uuid;
  v_warehouse_id uuid;
  v_date date;
  v_reason text;
  v_notes text;
  v_returns_account uuid;
  v_inventory_account uuid;
  v_cogs_account uuid;
  v_totals jsonb;
  v_total numeric(15, 3);
  v_invoice_id uuid := gen_random_uuid();
  v_invoice_number text;
  v_journal_entry_id uuid := gen_random_uuid();
  v_journal_number text;
  v_line jsonb;
  v_snap jsonb;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_qty numeric(15, 3);
  v_cost numeric(15, 3);
  v_return_total numeric(15, 3) := 0;
  v_inventory_total numeric(15, 3) := 0;
  v_output_account_id uuid;
  v_tax_amount numeric(15, 3);
  v_tax_enabled boolean;
  v_order int;
begin
  if v_tenant_id is null then raise exception 'tenant_not_found'; end if;
  if not public.user_has_permission('invoices.create_sales_return') then raise exception 'permission_denied'; end if;
  if p_idempotency_key is null then raise exception 'validation_failed'; end if;

  v_normalized := public.normalize_cash_invoice_payload(p_data);
  v_hash := public.compute_cash_invoice_payload_hash(p_data);
  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_finance_idempotency('public.invoices'::regclass, p_idempotency_key, v_hash);
  if v_existing_id is not null then return v_existing_id; end if;

  v_customer_id := nullif(v_normalized ->> 'customer_id', '')::uuid;
  v_cash_account_id := (v_normalized ->> 'cash_account_id')::uuid;
  v_warehouse_id := (v_normalized ->> 'warehouse_id')::uuid;
  v_date := (v_normalized ->> 'date')::date;
  v_reason := coalesce(nullif(v_normalized ->> 'reason', ''), 'direct_return');
  v_notes := nullif(v_normalized ->> 'notes', '');

  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);
  if v_customer_id is not null then
    perform public.validate_customer_ar_account(v_tenant_id, v_customer_id, null);
  end if;

  v_returns_account := public.resolve_system_sales_returns_account(v_tenant_id);
  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);
  v_cogs_account := public.resolve_system_cogs_account(v_tenant_id);
  select tax_enabled into v_tax_enabled from public.tenant_settings where tenant_id = v_tenant_id;
  v_totals := public.calculate_invoice_totals_internal(
    v_tenant_id, 'sales', v_date, public.sales_calc_lines_for_totals(v_normalized -> 'lines')
  );
  v_total := (v_totals ->> 'total')::numeric(15, 3);
  if v_total <= 0 then raise exception 'validation_failed'; end if;

  perform public.allow_finance_write();
  v_invoice_number := public.next_document_number('SR');

  insert into public.invoices (
    id, tenant_id, type, status, customer_id, warehouse_id, date, notes,
    original_invoice_id, return_reason, invoice_number,
    subtotal, discount_amount, tax_amount, total, paid_amount,
    idempotency_key, idempotency_payload_hash, created_by, confirmed_at, confirmed_by
  )
  values (
    v_invoice_id, v_tenant_id, 'sales_return', 'paid', v_customer_id, v_warehouse_id, v_date, v_notes,
    null, v_reason, v_invoice_number,
    (v_totals ->> 'subtotal')::numeric(15, 3),
    (v_totals ->> 'discount_amount')::numeric(15, 3),
    (v_totals ->> 'tax_amount')::numeric(15, 3), v_total, v_total,
    p_idempotency_key, v_hash, auth.uid(), now(), auth.uid()
  );

  for v_line in select value from jsonb_array_elements(v_normalized -> 'lines') order by (value ->> 'line_order')::int loop
    v_order := (v_line ->> 'line_order')::int;
    select value into v_snap from jsonb_array_elements(v_totals -> 'lines') where (value ->> 'line_order')::int = v_order;
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_product_unit_id := nullif(v_line ->> 'product_unit_id', '')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(15, 3);

    select coalesce(case when v_product_unit_id is not null then pu.purchase_cost else p.avg_cost end, 0)
    into v_cost
    from public.products p
    left join public.product_units pu on pu.id = v_product_unit_id and pu.tenant_id = v_tenant_id
    where p.id = v_product_id and p.tenant_id = v_tenant_id;
    if not found then raise exception 'validation_failed'; end if;

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id, product_unit_id, qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, cost_price, line_order
    )
    values (
      v_tenant_id, v_invoice_id, v_product_id, v_product_unit_id, v_qty,
      (v_line ->> 'unit_price')::numeric(15, 3), coalesce((v_line ->> 'discount_pct')::numeric(5, 2), 0),
      (v_snap ->> 'gross_amount')::numeric(15, 3), (v_snap ->> 'discount_amount')::numeric(15, 3),
      (v_snap ->> 'before_tax_amount')::numeric(15, 3), (v_snap ->> 'after_tax_amount')::numeric(15, 3),
      nullif(v_snap ->> 'tax_rate_id', '')::uuid, coalesce((v_snap ->> 'tax_rate')::numeric(9, 6), 0),
      (v_snap ->> 'tax_class')::public.product_tax_class, (v_snap ->> 'taxable_amount')::numeric(15, 3),
      (v_snap ->> 'tax_amount')::numeric(15, 3), (v_snap ->> 'line_total')::numeric(15, 3),
      v_cost, v_order
    );
    v_return_total := v_return_total + (v_snap ->> 'before_tax_amount')::numeric(15, 3);
    v_inventory_total := v_inventory_total + (v_cost * v_qty);

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, unit_cost, reference_table, reference_id, notes, created_by
    )
    values (
      v_tenant_id, 'sale_return', v_warehouse_id, v_product_id, v_product_unit_id,
      v_qty, v_cost, 'sales_return_invoice', v_invoice_id,
      'Direct sales return ' || v_invoice_number, auth.uid()
    );

    insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
    values (v_tenant_id, v_warehouse_id, v_product_id, v_qty)
    on conflict (warehouse_id, product_id)
    do update set qty_available = inventory_balances.qty_available + excluded.qty_available;

    if v_product_unit_id is not null then
      update public.product_units
      set status = 'available_used', current_warehouse_id = v_warehouse_id,
        current_customer_id = null, updated_at = now()
      where id = v_product_unit_id and tenant_id = v_tenant_id;
    end if;
  end loop;

  v_journal_number := public.next_document_number('JE');
  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id, description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'sales_return', v_invoice_id, 'Direct sales return ' || v_invoice_number, false, auth.uid()
  );

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    v_tenant_id, v_journal_entry_id, v_returns_account,
    v_return_total, 0, 1, 'Direct sales returns'
  );

  for v_output_account_id, v_tax_amount in
    select tr.output_account_id, sum((snap.value ->> 'tax_amount')::numeric(15, 3))
    from jsonb_array_elements(v_totals -> 'lines') snap(value)
    join public.tax_rates tr on tr.id = nullif(snap.value ->> 'tax_rate_id', '')::uuid and tr.tenant_id = v_tenant_id
    where coalesce(v_tax_enabled, false) and coalesce((snap.value ->> 'tax_amount')::numeric, 0) > 0
    group by tr.output_account_id
  loop
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_journal_entry_id, v_output_account_id,
      v_tax_amount, 0, 2, 'Output tax reversal'
    );
  end loop;

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    v_tenant_id, v_journal_entry_id, v_cash_account_id,
    0, v_total, 3, 'Cash/Bank refund'
  );

  if v_inventory_total > 0 then
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values
      (v_tenant_id, v_journal_entry_id, v_inventory_account, v_inventory_total, 0, 10, 'Inventory restore'),
      (v_tenant_id, v_journal_entry_id, v_cogs_account, 0, v_inventory_total, 11, 'COGS reversal');
  end if;

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_journal_entry_id and tenant_id = v_tenant_id;

  update public.invoices
  set journal_entry_id = v_journal_entry_id
  where id = v_invoice_id and tenant_id = v_tenant_id;

  return v_invoice_id;
end;
$$;

create or replace function public.record_direct_purchase_return(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_normalized jsonb;
  v_hash text;
  v_existing_id uuid;
  v_supplier_id uuid;
  v_cash_account_id uuid;
  v_warehouse_id uuid;
  v_date date;
  v_reason text;
  v_notes text;
  v_inventory_account uuid;
  v_totals jsonb;
  v_total numeric(15, 3);
  v_invoice_id uuid := gen_random_uuid();
  v_invoice_number text;
  v_journal_entry_id uuid := gen_random_uuid();
  v_journal_number text;
  v_line jsonb;
  v_snap jsonb;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_qty numeric(15, 3);
  v_cost numeric(15, 3);
  v_inventory_credit numeric(15, 3) := 0;
  v_tax_enabled boolean;
  v_input_account_id uuid;
  v_tax_amount numeric(15, 3);
  v_order int;
begin
  if v_tenant_id is null then raise exception 'tenant_not_found'; end if;
  if not public.user_has_permission('invoices.create_purchase_return') then raise exception 'permission_denied'; end if;
  if p_idempotency_key is null then raise exception 'validation_failed'; end if;

  v_normalized := public.normalize_cash_invoice_payload(p_data);
  v_hash := public.compute_cash_invoice_payload_hash(p_data);
  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_finance_idempotency('public.invoices'::regclass, p_idempotency_key, v_hash);
  if v_existing_id is not null then return v_existing_id; end if;

  v_supplier_id := nullif(v_normalized ->> 'supplier_id', '')::uuid;
  v_cash_account_id := (v_normalized ->> 'cash_account_id')::uuid;
  v_warehouse_id := (v_normalized ->> 'warehouse_id')::uuid;
  v_date := (v_normalized ->> 'date')::date;
  v_reason := coalesce(nullif(v_normalized ->> 'reason', ''), 'direct_return');
  v_notes := nullif(v_normalized ->> 'notes', '');

  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);
  if v_supplier_id is not null then
    perform public.validate_supplier_ap_account(v_tenant_id, v_supplier_id, null);
  end if;

  v_inventory_account := public.resolve_system_inventory_account(v_tenant_id);
  select tax_enabled into v_tax_enabled from public.tenant_settings where tenant_id = v_tenant_id;
  v_totals := public.calculate_invoice_totals_internal(
    v_tenant_id, 'purchase', v_date, public.purchase_calc_lines_for_totals(v_normalized -> 'lines')
  );
  v_total := (v_totals ->> 'total')::numeric(15, 3);
  if v_total <= 0 then raise exception 'validation_failed'; end if;

  for v_line in select value from jsonb_array_elements(v_normalized -> 'lines') loop
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(15, 3);
    v_product_unit_id := nullif(v_line ->> 'product_unit_id', '')::uuid;

    perform 1
    from public.inventory_balances
    where tenant_id = v_tenant_id
      and warehouse_id = v_warehouse_id
      and product_id = v_product_id
      and qty_available >= v_qty
    for update;
    if not found then raise exception 'insufficient_stock'; end if;

    if v_product_unit_id is not null then
      perform 1
      from public.product_units
      where id = v_product_unit_id
        and tenant_id = v_tenant_id
        and product_id = v_product_id
        and current_warehouse_id = v_warehouse_id
        and status in ('available_new', 'available_used')
      for update;
      if not found then raise exception 'validation_failed'; end if;
    end if;
  end loop;

  perform public.allow_finance_write();
  v_invoice_number := public.next_document_number('PR');

  insert into public.invoices (
    id, tenant_id, type, status, supplier_id, warehouse_id, date, notes,
    original_invoice_id, return_reason, invoice_number,
    subtotal, discount_amount, tax_amount, total, paid_amount,
    idempotency_key, idempotency_payload_hash, created_by, confirmed_at, confirmed_by
  )
  values (
    v_invoice_id, v_tenant_id, 'purchase_return', 'paid', v_supplier_id, v_warehouse_id, v_date, v_notes,
    null, v_reason, v_invoice_number,
    (v_totals ->> 'subtotal')::numeric(15, 3),
    (v_totals ->> 'discount_amount')::numeric(15, 3),
    (v_totals ->> 'tax_amount')::numeric(15, 3), v_total, v_total,
    p_idempotency_key, v_hash, auth.uid(), now(), auth.uid()
  );

  for v_line in select value from jsonb_array_elements(v_normalized -> 'lines') order by (value ->> 'line_order')::int loop
    v_order := (v_line ->> 'line_order')::int;
    select value into v_snap from jsonb_array_elements(v_totals -> 'lines') where (value ->> 'line_order')::int = v_order;
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_product_unit_id := nullif(v_line ->> 'product_unit_id', '')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(15, 3);

    select coalesce(case when v_product_unit_id is not null then pu.purchase_cost else p.avg_cost end, 0)
    into v_cost
    from public.products p
    left join public.product_units pu on pu.id = v_product_unit_id and pu.tenant_id = v_tenant_id
    where p.id = v_product_id and p.tenant_id = v_tenant_id;
    if not found then raise exception 'validation_failed'; end if;

    insert into public.invoice_lines (
      tenant_id, invoice_id, product_id, product_unit_id, qty, unit_price, discount_pct,
      gross_amount, discount_amount, before_tax_amount, after_tax_amount,
      tax_rate_id, tax_rate, tax_class, taxable_amount, tax_amount,
      line_total, cost_price, line_order
    )
    values (
      v_tenant_id, v_invoice_id, v_product_id, v_product_unit_id, v_qty,
      (v_line ->> 'unit_price')::numeric(15, 3), coalesce((v_line ->> 'discount_pct')::numeric(5, 2), 0),
      (v_snap ->> 'gross_amount')::numeric(15, 3), (v_snap ->> 'discount_amount')::numeric(15, 3),
      (v_snap ->> 'before_tax_amount')::numeric(15, 3), (v_snap ->> 'after_tax_amount')::numeric(15, 3),
      nullif(v_snap ->> 'tax_rate_id', '')::uuid, coalesce((v_snap ->> 'tax_rate')::numeric(9, 6), 0),
      (v_snap ->> 'tax_class')::public.product_tax_class, (v_snap ->> 'taxable_amount')::numeric(15, 3),
      (v_snap ->> 'tax_amount')::numeric(15, 3), (v_snap ->> 'line_total')::numeric(15, 3),
      v_cost, v_order
    );

    update public.inventory_balances
    set qty_available = qty_available - v_qty
    where tenant_id = v_tenant_id
      and warehouse_id = v_warehouse_id
      and product_id = v_product_id;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, unit_cost, reference_table, reference_id, notes, created_by
    )
    values (
      v_tenant_id, 'purchase_return', v_warehouse_id, v_product_id, v_product_unit_id,
      v_qty, v_cost, 'purchase_return_invoice', v_invoice_id,
      'Direct purchase return ' || v_invoice_number, auth.uid()
    );

    if v_product_unit_id is not null then
      update public.product_units
      set status = 'retired', current_warehouse_id = null, updated_at = now()
      where id = v_product_unit_id and tenant_id = v_tenant_id;
    end if;

    v_inventory_credit := v_inventory_credit + (v_snap ->> 'before_tax_amount')::numeric(15, 3);
  end loop;

  v_journal_number := public.next_document_number('JE');
  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id, description_en, is_posted, created_by
  )
  values (
    v_journal_entry_id, v_tenant_id, v_journal_number, v_date,
    'purchase_return', v_invoice_id, 'Direct purchase return ' || v_invoice_number, false, auth.uid()
  );

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (v_tenant_id, v_journal_entry_id, v_cash_account_id, v_total, 0, 1, 'Cash/Bank refund');

  if v_inventory_credit > 0 then
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (v_tenant_id, v_journal_entry_id, v_inventory_account, 0, v_inventory_credit, 2, 'Inventory reduction');
  end if;

  for v_input_account_id, v_tax_amount in
    select tr.input_account_id, sum((snap.value ->> 'tax_amount')::numeric(15, 3))
    from jsonb_array_elements(v_totals -> 'lines') snap(value)
    join public.tax_rates tr on tr.id = nullif(snap.value ->> 'tax_rate_id', '')::uuid and tr.tenant_id = v_tenant_id
    where coalesce(v_tax_enabled, false) and coalesce((snap.value ->> 'tax_amount')::numeric, 0) > 0
    group by tr.input_account_id
  loop
    if v_input_account_id is not null then
      insert into public.journal_lines (
        tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
      )
      values (v_tenant_id, v_journal_entry_id, v_input_account_id, 0, v_tax_amount, 3, 'Input tax reversal');
    end if;
  end loop;

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_journal_entry_id and tenant_id = v_tenant_id;

  update public.invoices
  set journal_entry_id = v_journal_entry_id
  where id = v_invoice_id and tenant_id = v_tenant_id;

  return v_invoice_id;
end;
$$;

grant execute on function public.record_direct_sales_return(jsonb, uuid) to authenticated;
grant execute on function public.record_direct_purchase_return(jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';
