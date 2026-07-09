-- Phase 6 M5: Rental Collection & Billing Engine.
-- Payment-confirmed rental billing only (no automatic periodic invoice issuance).

-- ---------------------------------------------------------------------------
-- Schema: rental coverage + collection idempotency/result ledger
-- ---------------------------------------------------------------------------
create table if not exists public.rental_invoice_coverages (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  contract_id uuid not null references public.contracts (id) on delete restrict,
  invoice_id uuid not null references public.invoices (id) on delete restrict,
  coverage_month_key date not null,
  coverage_start date not null,
  coverage_end date not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  constraint chk_rental_coverages_window check (
    coverage_start <= coverage_end
    and coverage_start = date_trunc('month', coverage_start)::date
    and coverage_end = (coverage_start + interval '1 month - 1 day')::date
    and coverage_month_key = coverage_start
  )
);

create unique index if not exists ux_rental_invoice_coverages_unique_month
  on public.rental_invoice_coverages (tenant_id, contract_id, coverage_month_key);

create index if not exists idx_rental_invoice_coverages_invoice
  on public.rental_invoice_coverages (tenant_id, invoice_id);

comment on table public.rental_invoice_coverages is
  'M5 v1: Permanent billed rental coverage month ledger. Coverage remains blocked even if invoice is cancelled.';

create table if not exists public.rental_collection_operations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  idempotency_key uuid not null,
  payload_hash text not null,
  result_payload jsonb not null,
  invoice_id uuid not null references public.invoices (id) on delete restrict,
  voucher_id uuid not null references public.vouchers (id) on delete restrict,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  constraint ux_rental_collection_ops_key unique (tenant_id, idempotency_key),
  constraint ux_rental_collection_ops_invoice unique (tenant_id, invoice_id),
  constraint ux_rental_collection_ops_voucher unique (tenant_id, voucher_id)
);

comment on table public.rental_collection_operations is
  'M5 v1: Idempotency and stable replay payloads for collect_rental_payment.';

-- ---------------------------------------------------------------------------
-- RLS and write-gates
-- ---------------------------------------------------------------------------
alter table public.rental_invoice_coverages enable row level security;
alter table public.rental_collection_operations enable row level security;

drop policy if exists rental_invoice_coverages_select on public.rental_invoice_coverages;
create policy rental_invoice_coverages_select on public.rental_invoice_coverages
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      public.user_has_permission('invoices.view_sales')
      or public.user_has_permission('invoices.view')
      or public.user_has_permission('vouchers.view')
    )
  );

drop policy if exists rental_collection_operations_select on public.rental_collection_operations;
create policy rental_collection_operations_select on public.rental_collection_operations
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      public.user_has_permission('vouchers.view')
      or public.user_has_permission('invoices.view_sales')
      or public.user_has_permission('invoices.view')
    )
  );

create trigger trg_finance_direct_write_gate_rental_coverages
  before insert or update or delete on public.rental_invoice_coverages
  for each row execute function public.enforce_finance_direct_write_gate();

create trigger trg_finance_direct_write_gate_rental_collection_ops
  before insert or update or delete on public.rental_collection_operations
  for each row execute function public.enforce_finance_direct_write_gate();

revoke all on public.rental_invoice_coverages from public, anon, authenticated;
revoke all on public.rental_collection_operations from public, anon, authenticated;
grant select on public.rental_invoice_coverages to authenticated;
grant select on public.rental_collection_operations to authenticated;

-- ---------------------------------------------------------------------------
-- Internal helpers: product provisioning + normalization
-- ---------------------------------------------------------------------------
create or replace function public.ensure_rental_service_product(p_tenant_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sku constant text := 'SYS-RENTAL-MONTHLY';
  v_product public.products%rowtype;
  v_group_id uuid;
begin
  if p_tenant_id is null then
    raise exception 'validation_failed';
  end if;

  select p.* into v_product
  from public.products p
  where p.tenant_id = p_tenant_id
    and p.sku = v_sku
  for update;

  if found then
    if v_product.product_type <> 'sale_only'::public.product_type
      or coalesce(v_product.can_be_sold, false) <> true
      or coalesce(v_product.can_be_rented, false) <> false
      or coalesce(v_product.is_serialized, false) <> false
      or coalesce(v_product.tax_class, 'non_taxable'::public.product_tax_class) <> 'non_taxable'::public.product_tax_class
      or coalesce(v_product.sale_price, 0) <> 0
      or coalesce(v_product.avg_cost, 0) <> 0 then
      raise exception 'validation_failed';
    end if;
    return v_product.id;
  end if;

  select pg.id into v_group_id
  from public.product_groups pg
  where pg.tenant_id = p_tenant_id
    and pg.name_en = 'System Services'
    and pg.name_ar = U&'\062E\062F\0645\0627\062A \0627\0644\0646\0638\0627\0645' UESCAPE '\'
  order by pg.created_at, pg.id
  limit 1
  for update;

  if v_group_id is null then
    insert into public.product_groups (
      tenant_id, name_ar, name_en, sort_order, is_active, created_by
    )
    values (
      p_tenant_id,
      U&'\062E\062F\0645\0627\062A \0627\0644\0646\0638\0627\0645' UESCAPE '\',
      'System Services',
      9000,
      true,
      auth.uid()
    )
    returning id into v_group_id;
  end if;

  insert into public.products (
    tenant_id,
    sku,
    name_ar,
    name_en,
    description_ar,
    description_en,
    group_id,
    product_type,
    can_be_sold,
    can_be_rented,
    unit_primary,
    unit_secondary,
    conversion_factor,
    sale_price,
    rental_price_monthly,
    avg_cost,
    last_purchase_cost,
    expected_lifespan_months,
    default_oil_ml_per_month,
    is_serialized,
    trackable_for_maintenance,
    reorder_point,
    is_active,
    tax_class,
    created_by
  )
  values (
    p_tenant_id,
    v_sku,
    U&'\0627\064A\062C\0627\0631 \0634\0647\0631\064A \0646\0638\0627\0645\064A' UESCAPE '\',
    'System Monthly Rental Service',
    U&'\0645\0646\062A\062C \0646\0638\0627\0645\064A \0644\0641\0648\062A\0631\0629 \0627\0644\062A\062D\0635\064A\0644 \0627\0644\0634\0647\0631\064A \0644\0644\0625\064A\062C\0627\0631' UESCAPE '\',
    'System billing product for rental monthly collection invoices',
    v_group_id,
    'sale_only',
    true,
    false,
    'piece',
    null,
    1,
    0,
    null,
    0,
    null,
    0,
    null,
    false,
    false,
    null,
    true,
    'non_taxable',
    auth.uid()
  )
  returning * into v_product;

  return v_product.id;
end;
$$;

comment on function public.ensure_rental_service_product(uuid) is
  'M5 v1: Ensures tenant-scoped SYS-RENTAL-MONTHLY product exists with explicit non_taxable tax_class.';

create or replace function public.expand_rental_coverage_months(
  p_coverage_months jsonb,
  p_coverage_start date,
  p_coverage_end date
)
returns table (
  coverage_month_key date,
  coverage_start date,
  coverage_end date
)
language plpgsql
immutable
set search_path = public
as $$
declare
  v_elem jsonb;
  v_month_input date;
  v_month_key date;
  v_month date;
  v_month_start date;
  v_month_end date;
  v_seen_month_keys date[] := '{}';
begin
  if p_coverage_months is not null then
    if jsonb_typeof(p_coverage_months) <> 'array'
      or jsonb_array_length(p_coverage_months) = 0 then
      raise exception 'validation_failed';
    end if;

    for v_elem in
      select value
      from jsonb_array_elements(p_coverage_months)
    loop
      begin
        v_month_input := (v_elem #>> '{}')::date;
      exception
        when others then
          raise exception 'validation_failed';
      end;

      if v_month_input is null then
        raise exception 'validation_failed';
      end if;

      v_month_key := date_trunc('month', v_month_input)::date;

      if v_month_key = any (v_seen_month_keys) then
        raise exception 'validation_failed';
      end if;

      v_seen_month_keys := array_append(v_seen_month_keys, v_month_key);
      coverage_month_key := v_month_key;
      coverage_start := v_month_key;
      coverage_end := (v_month_key + interval '1 month - 1 day')::date;
      return next;
    end loop;

    return;
  end if;

  if p_coverage_start is null or p_coverage_end is null then
    raise exception 'validation_failed';
  end if;

  v_month_start := date_trunc('month', p_coverage_start)::date;
  v_month_end := date_trunc('month', p_coverage_end)::date;

  if p_coverage_start <> v_month_start
    or p_coverage_end <> (v_month_end + interval '1 month - 1 day')::date
    or v_month_end < v_month_start then
    raise exception 'validation_failed';
  end if;

  v_month := v_month_start;
  while v_month <= v_month_end loop
    coverage_month_key := v_month;
    coverage_start := v_month;
    coverage_end := (v_month + interval '1 month - 1 day')::date;
    return next;
    v_month := (v_month + interval '1 month')::date;
  end loop;
end;
$$;

create or replace function public.normalize_collect_rental_payment_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_contract_id uuid;
  v_date date;
  v_amount numeric(15, 3);
  v_payment_method public.payment_method;
  v_cash_account_id uuid;
  v_notes text;
  v_reference_no text;
  v_coverage_months jsonb;
  v_coverage_start date;
  v_coverage_end date;
begin
  if p_data is null
    or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if not (
    p_data ? 'contract_id'
    and p_data ? 'date'
    and p_data ? 'amount'
    and p_data ? 'payment_method'
    and p_data ? 'cash_account_id'
  ) then
    raise exception 'validation_failed';
  end if;

  begin
    v_contract_id := (p_data ->> 'contract_id')::uuid;
    v_date := (p_data ->> 'date')::date;
    v_amount := (p_data ->> 'amount')::numeric(15, 3);
    v_payment_method := (p_data ->> 'payment_method')::public.payment_method;
    v_cash_account_id := (p_data ->> 'cash_account_id')::uuid;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if v_contract_id is null
    or v_date is null
    or v_amount is null
    or v_amount <= 0
    or v_payment_method is null
    or v_cash_account_id is null then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'notes' then
    v_notes := nullif(btrim(p_data ->> 'notes'), '');
  end if;
  if p_data ? 'reference_no' then
    v_reference_no := nullif(btrim(p_data ->> 'reference_no'), '');
  end if;

  if p_data ? 'coverage_months' then
    v_coverage_months := p_data -> 'coverage_months';
  elsif p_data ? 'coverage_start' or p_data ? 'coverage_end' then
    begin
      v_coverage_start := (p_data ->> 'coverage_start')::date;
      v_coverage_end := (p_data ->> 'coverage_end')::date;
    exception
      when others then
        raise exception 'validation_failed';
    end;
  else
    raise exception 'validation_failed';
  end if;

  return jsonb_strip_nulls(
    jsonb_build_object(
      'contract_id', v_contract_id::text,
      'date', v_date::text,
      'amount', to_jsonb(v_amount),
      'payment_method', v_payment_method::text,
      'cash_account_id', v_cash_account_id::text,
      'reference_no', v_reference_no,
      'notes', v_notes,
      'coverage_months', (
        select coalesce(jsonb_agg(to_jsonb(c.coverage_month_key::text) order by c.coverage_month_key), '[]'::jsonb)
        from public.expand_rental_coverage_months(v_coverage_months, v_coverage_start, v_coverage_end) c
      )
    )
  );
end;
$$;

create or replace function public.compute_collect_rental_payment_payload_hash(p_data jsonb)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(public.normalize_collect_rental_payment_payload(p_data)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

-- ---------------------------------------------------------------------------
-- Public RPCs
-- ---------------------------------------------------------------------------
create or replace function public.preview_rental_collection(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_normalized jsonb;
  v_contract public.contracts%rowtype;
  v_monthly numeric(15, 3);
  v_line_count integer;
  v_decimal_places integer;
  v_subtotal numeric(15, 3) := 0;
  v_line_total numeric(15, 3);
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not (
    public.user_has_permission('vouchers.create_receipt')
    or public.user_has_permission('invoices.create_sales')
    or public.user_has_permission('invoices.view_sales')
  ) then
    raise exception 'permission_denied';
  end if;

  v_normalized := public.normalize_collect_rental_payment_payload(p_data);

  select * into v_contract
  from public.contracts c
  where c.id = (v_normalized ->> 'contract_id')::uuid
    and c.tenant_id = v_tenant_id;

  if not found or v_contract.type <> 'rental'::public.contract_type then
    raise exception 'validation_failed';
  end if;

  if v_contract.monthly_rental_value is null or v_contract.monthly_rental_value <= 0 then
    raise exception 'validation_failed';
  end if;
  v_monthly := v_contract.monthly_rental_value;
  v_line_count := jsonb_array_length(v_normalized -> 'coverage_months');
  v_decimal_places := public.resolve_tenant_money_precision(v_tenant_id);

  -- Preview is read-only: M5 v1 rental billing uses non_taxable system product semantics
  -- without provisioning SYS-RENTAL-MONTHLY or any product_group rows.
  v_line_total := public.round_money(v_monthly, v_decimal_places);
  v_subtotal := public.round_money(v_line_total * v_line_count, v_decimal_places);

  return jsonb_build_object(
    'contract_id', v_contract.id,
    'contract_number', v_contract.contract_number,
    'coverage_months', v_normalized -> 'coverage_months',
    'line_count', v_line_count,
    'subtotal', v_subtotal,
    'tax_amount', 0::numeric(15, 3),
    'invoice_total', v_subtotal,
    'expected_collected_amount', v_subtotal,
    'tax_policy', 'non_taxable_v1'
  );
end;
$$;

comment on function public.preview_rental_collection(jsonb) is
  'M5 v1: Read-only rental collection preview. Does not provision products or post finance rows.';

create or replace function public.collect_rental_payment(
  p_data jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_normalized jsonb;
  v_payload_hash text;
  v_existing public.rental_collection_operations%rowtype;
  v_contract public.contracts%rowtype;
  v_books_locked_through date;
  v_service_product_id uuid;
  v_invoice_date date;
  v_collected_amount numeric(15, 3);
  v_monthly numeric(15, 3);
  v_lines jsonb := '[]'::jsonb;
  v_month record;
  v_totals jsonb;
  v_invoice_total numeric(15, 3);
  v_invoice_id uuid := gen_random_uuid();
  v_invoice_number text;
  v_je_id uuid := gen_random_uuid();
  v_je_number text;
  v_ar_account_id uuid;
  v_revenue_account_id uuid;
  v_je_line_order integer := 0;
  v_tax_enabled boolean;
  v_notes text;
  v_reference_no text;
  v_due_date date;
  v_voucher_payload jsonb;
  v_voucher_id uuid;
  v_operation_id uuid := gen_random_uuid();
  v_result jsonb;
begin
  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('vouchers.create_receipt')
    or not public.user_has_permission('invoices.create_sales') then
    raise exception 'permission_denied';
  end if;

  v_normalized := public.normalize_collect_rental_payment_payload(p_data);
  v_payload_hash := public.compute_collect_rental_payment_payload_hash(p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  select * into v_existing
  from public.rental_collection_operations rco
  where rco.tenant_id = v_tenant_id
    and rco.idempotency_key = p_idempotency_key;

  if found then
    if v_existing.payload_hash is distinct from v_payload_hash then
      raise exception 'idempotency_payload_mismatch';
    end if;
    return v_existing.result_payload;
  end if;

  v_invoice_date := (v_normalized ->> 'date')::date;
  v_collected_amount := (v_normalized ->> 'amount')::numeric(15, 3);
  v_notes := nullif(v_normalized ->> 'notes', '');
  v_reference_no := nullif(v_normalized ->> 'reference_no', '');

  select c.* into v_contract
  from public.contracts c
  where c.id = (v_normalized ->> 'contract_id')::uuid
    and c.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_contract.type <> 'rental'::public.contract_type then
    raise exception 'validation_failed';
  end if;

  if v_contract.status not in (
    'active'::public.contract_status,
    'suspended'::public.contract_status,
    'completed'::public.contract_status,
    'terminated_early'::public.contract_status,
    'expired'::public.contract_status
  ) then
    raise exception 'validation_failed';
  end if;

  if v_contract.monthly_rental_value is null or v_contract.monthly_rental_value <= 0 then
    raise exception 'validation_failed';
  end if;
  v_monthly := v_contract.monthly_rental_value;

  select ts.books_locked_through, ts.tax_enabled
  into v_books_locked_through, v_tax_enabled
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_invoice_date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  if v_contract.status in (
    'completed'::public.contract_status,
    'terminated_early'::public.contract_status,
    'expired'::public.contract_status
  ) then
    for v_month in
      select (elem.value #>> '{}')::date as month_key
      from jsonb_array_elements(v_normalized -> 'coverage_months') elem(value)
    loop
      if coalesce(v_contract.closed_at::date, v_contract.returned_at::date, v_contract.end_date) is null
        or v_month.month_key > date_trunc(
          'month',
          coalesce(v_contract.closed_at::date, v_contract.returned_at::date, v_contract.end_date)
        )::date then
        raise exception 'validation_failed';
      end if;
    end loop;
  end if;

  perform public.validate_customer_ar_account(v_tenant_id, v_contract.customer_id, null);
  perform public.validate_cash_bank_account(v_tenant_id, (v_normalized ->> 'cash_account_id')::uuid);
  v_service_product_id := public.ensure_rental_service_product(v_tenant_id);

  v_due_date := (v_invoice_date + interval '30 day')::date;
  v_revenue_account_id := public.resolve_system_sales_revenue_account(v_tenant_id);
  perform public.validate_tax_posting_account(v_tenant_id, v_revenue_account_id, 'income', true);

  select c.account_id into v_ar_account_id
  from public.customers c
  where c.id = v_contract.customer_id
    and c.tenant_id = v_tenant_id;

  if v_ar_account_id is null then
    raise exception 'validation_failed';
  end if;

  for v_month in
    select (elem.value #>> '{}')::date as month_key, row_number() over (order by (elem.value #>> '{}')::date) as ord
    from jsonb_array_elements(v_normalized -> 'coverage_months') elem(value)
    order by (elem.value #>> '{}')::date
  loop
    if exists (
      select 1
      from public.rental_invoice_coverages ric
      where ric.tenant_id = v_tenant_id
        and ric.contract_id = v_contract.id
        and ric.coverage_month_key = v_month.month_key
    ) then
      raise exception 'validation_failed';
    end if;

    v_lines := v_lines || jsonb_build_array(
      jsonb_build_object(
        'product_id', v_service_product_id::text,
        'qty', to_jsonb(1::numeric),
        'unit_price', to_jsonb(v_monthly),
        'discount_pct', to_jsonb(0::numeric),
        'line_order', v_month.ord
      )
    );
  end loop;

  v_totals := public.calculate_invoice_totals_internal(v_tenant_id, 'sales', v_invoice_date, v_lines);
  v_invoice_total := (v_totals ->> 'total')::numeric(15, 3);

  if v_invoice_total <= 0 or v_collected_amount <> v_invoice_total then
    raise exception 'validation_failed';
  end if;

  perform public.allow_finance_write();

  v_invoice_number := public.next_document_number('SI');
  v_je_number := public.next_document_number('JE');

  insert into public.invoices (
    id,
    tenant_id,
    invoice_number,
    type,
    status,
    customer_id,
    contract_id,
    date,
    due_date,
    notes,
    subtotal,
    discount_amount,
    tax_amount,
    total,
    paid_amount,
    billing_period_start,
    billing_period_end,
    idempotency_key,
    idempotency_payload_hash,
    created_by,
    confirmed_at,
    confirmed_by
  )
  values (
    v_invoice_id,
    v_tenant_id,
    v_invoice_number,
    'rental_monthly',
    'confirmed',
    v_contract.customer_id,
    v_contract.id,
    v_invoice_date,
    v_due_date,
    v_notes,
    (v_totals ->> 'subtotal')::numeric(15, 3),
    (v_totals ->> 'discount_amount')::numeric(15, 3),
    (v_totals ->> 'tax_amount')::numeric(15, 3),
    v_invoice_total,
    0,
    (
      select min((elem.value #>> '{}')::date)
      from jsonb_array_elements(v_normalized -> 'coverage_months') elem(value)
    ),
    (
      select max(((elem.value #>> '{}')::date + interval '1 month - 1 day')::date)
      from jsonb_array_elements(v_normalized -> 'coverage_months') elem(value)
    ),
    null,
    null,
    auth.uid(),
    now(),
    auth.uid()
  );

  for v_month in
    select (elem.value #>> '{}')::date as month_key, row_number() over (order by (elem.value #>> '{}')::date) as ord
    from jsonb_array_elements(v_normalized -> 'coverage_months') elem(value)
    order by (elem.value #>> '{}')::date
  loop
    insert into public.invoice_lines (
      tenant_id,
      invoice_id,
      product_id,
      product_unit_id,
      description,
      qty,
      unit_price,
      discount_pct,
      gross_amount,
      discount_amount,
      before_tax_amount,
      after_tax_amount,
      tax_rate_id,
      tax_rate,
      tax_class,
      taxable_amount,
      tax_amount,
      line_total,
      cost_price,
      line_order
    )
    select
      v_tenant_id,
      v_invoice_id,
      v_service_product_id,
      null,
      'Rental coverage ' || v_contract.contract_number || ' - ' || to_char(v_month.month_key, 'YYYY-MM'),
      1,
      v_monthly,
      0,
      (snap.value ->> 'gross_amount')::numeric(15, 3),
      (snap.value ->> 'discount_amount')::numeric(15, 3),
      (snap.value ->> 'before_tax_amount')::numeric(15, 3),
      (snap.value ->> 'after_tax_amount')::numeric(15, 3),
      nullif(snap.value ->> 'tax_rate_id', '')::uuid,
      coalesce((snap.value ->> 'tax_rate')::numeric(9, 6), 0),
      (snap.value ->> 'tax_class')::public.product_tax_class,
      (snap.value ->> 'taxable_amount')::numeric(15, 3),
      (snap.value ->> 'tax_amount')::numeric(15, 3),
      (snap.value ->> 'line_total')::numeric(15, 3),
      0,
      v_month.ord
    from jsonb_array_elements(v_totals -> 'lines') snap(value)
    where (snap.value ->> 'line_order')::int = v_month.ord;

    insert into public.rental_invoice_coverages (
      tenant_id,
      contract_id,
      invoice_id,
      coverage_month_key,
      coverage_start,
      coverage_end,
      created_by
    )
    values (
      v_tenant_id,
      v_contract.id,
      v_invoice_id,
      v_month.month_key,
      v_month.month_key,
      (v_month.month_key + interval '1 month - 1 day')::date,
      auth.uid()
    );
  end loop;

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id, description_en, is_posted, created_by
  )
  values (
    v_je_id,
    v_tenant_id,
    v_je_number,
    v_invoice_date,
    'rental_invoice',
    v_invoice_id,
    'Rental invoice ' || v_invoice_number,
    false,
    auth.uid()
  );

  v_je_line_order := v_je_line_order + 1;
  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    v_tenant_id, v_je_id, v_ar_account_id, v_invoice_total, 0, v_je_line_order, 'Customer A/R'
  );

  v_je_line_order := v_je_line_order + 1;
  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    v_tenant_id, v_je_id, v_revenue_account_id,
    0, ((v_totals ->> 'subtotal')::numeric(15, 3) - (v_totals ->> 'discount_amount')::numeric(15, 3)),
    v_je_line_order, 'Rental revenue'
  );

  if coalesce((v_totals ->> 'tax_amount')::numeric(15, 3), 0) > 0 then
    for v_month in
      select tr.output_account_id as account_id, sum((snap.value ->> 'tax_amount')::numeric(15, 3)) as tax_total
      from jsonb_array_elements(v_totals -> 'lines') snap(value)
      join public.tax_rates tr
        on tr.id = nullif(snap.value ->> 'tax_rate_id', '')::uuid
        and tr.tenant_id = v_tenant_id
      where coalesce((snap.value ->> 'tax_amount')::numeric, 0) > 0
      group by tr.output_account_id
      order by tr.output_account_id
    loop
      perform public.validate_tax_posting_account(v_tenant_id, v_month.account_id, 'liability', true);
      v_je_line_order := v_je_line_order + 1;
      insert into public.journal_lines (
        tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
      )
      values (
        v_tenant_id, v_je_id, v_month.account_id, 0, v_month.tax_total, v_je_line_order, 'Output tax payable'
      );
    end loop;
  end if;

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_je_id
    and tenant_id = v_tenant_id;

  update public.invoices
  set journal_entry_id = v_je_id
  where id = v_invoice_id
    and tenant_id = v_tenant_id;

  v_voucher_payload := jsonb_strip_nulls(
    jsonb_build_object(
      'date', v_invoice_date::text,
      'amount', to_jsonb(v_collected_amount),
      'payment_method', (v_normalized ->> 'payment_method'),
      'cash_account_id', v_normalized ->> 'cash_account_id',
      'customer_id', v_contract.customer_id::text,
      'receipt_source', 'customer',
      'allocation_mode', 'manual',
      'allocations', jsonb_build_array(
        jsonb_build_object(
          'invoice_id', v_invoice_id::text,
          'allocated_amount', to_jsonb(v_collected_amount)
        )
      ),
      'reference_no', v_reference_no,
      'notes', v_notes
    )
  );

  v_voucher_id := public.record_receipt_voucher(v_voucher_payload, p_idempotency_key);

  v_result := jsonb_build_object(
    'invoice_id', v_invoice_id,
    'voucher_id', v_voucher_id,
    'coverage_months', v_normalized -> 'coverage_months',
    'invoice_total', v_invoice_total,
    'collected_amount', v_collected_amount
  );

  insert into public.rental_collection_operations (
    id,
    tenant_id,
    idempotency_key,
    payload_hash,
    result_payload,
    invoice_id,
    voucher_id,
    created_by
  )
  values (
    v_operation_id,
    v_tenant_id,
    p_idempotency_key,
    v_payload_hash,
    v_result,
    v_invoice_id,
    v_voucher_id,
    auth.uid()
  );

  return v_result;
exception
  when unique_violation then
    raise exception 'validation_failed';
end;
$$;

-- ---------------------------------------------------------------------------
-- Extend voucher allocation helpers to support rental_monthly
-- ---------------------------------------------------------------------------
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
  v_alloc_elem jsonb;
  v_invoice_id uuid;
  v_allocated_amount numeric(15, 3);
  v_invoice public.invoices%rowtype;
  v_paid numeric(15, 3);
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

    if not found or v_invoice.status not in ('confirmed', 'partially_paid') then
      raise exception 'validation_failed';
    end if;

    if p_direction = 'sales' then
      if v_invoice.type not in ('sales', 'rental_monthly') then
        raise exception 'validation_failed';
      end if;
      if v_invoice.customer_id is distinct from p_party_id then
        raise exception 'validation_failed';
      end if;
    else
      if v_invoice.type <> 'purchase' then
        raise exception 'validation_failed';
      end if;
      if v_invoice.supplier_id is distinct from p_party_id then
        raise exception 'validation_failed';
      end if;
    end if;

    v_paid := public.get_invoice_allocation_paid_amount(p_tenant_id, v_invoice_id);
    v_outstanding := v_invoice.total - v_paid;

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
  v_paid numeric(15, 3);
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
      and i.type in ('sales', 'rental_monthly')
      and i.status in ('confirmed', 'partially_paid')
    order by i.due_date nulls last, i.date, i.invoice_number, i.id
    for update
  loop
    exit when v_remaining <= 0;
    v_paid := public.get_invoice_allocation_paid_amount(p_tenant_id, v_invoice.id);
    v_outstanding := v_invoice.total - v_paid;
    if v_outstanding <= 0 then
      continue;
    end if;
    v_alloc := least(v_remaining, v_outstanding);
    if v_alloc <= 0 then
      continue;
    end if;
    v_result := v_result || jsonb_build_array(
      jsonb_build_object('invoice_id', v_invoice.id::text, 'allocated_amount', to_jsonb(v_alloc))
    );
    v_remaining := v_remaining - v_alloc;
  end loop;

  return v_result;
end;
$$;

create or replace function public.recompute_invoice_payment_state(
  p_tenant_id uuid,
  p_invoice_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.invoices%rowtype;
  v_paid numeric(15, 3);
begin
  select * into v_invoice
  from public.invoices i
  where i.id = p_invoice_id
    and i.tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_invoice.status = 'cancelled'
    or v_invoice.type not in ('sales', 'purchase', 'rental_monthly') then
    return;
  end if;

  v_paid := public.get_invoice_allocation_paid_amount(p_tenant_id, p_invoice_id);
  if v_paid > v_invoice.total then
    raise exception 'validation_failed';
  end if;

  update public.invoices
  set
    paid_amount = v_paid,
    status = case
      when v_paid >= total then 'paid'::public.invoice_status
      when v_paid > 0 then 'partially_paid'::public.invoice_status
      else 'confirmed'::public.invoice_status
    end
  where id = p_invoice_id
    and tenant_id = p_tenant_id;
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
    select 1 from public.customers c
    where c.id = p_customer_id and c.tenant_id = v_tenant_id
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
    (i.total - i.paid_amount)::numeric(15, 3) as outstanding
  from public.invoices i
  where i.tenant_id = v_tenant_id
    and i.customer_id = p_customer_id
    and i.type in ('sales', 'rental_monthly')
    and i.status in ('confirmed', 'partially_paid')
    and (i.total - i.paid_amount) > 0
  order by i.due_date nulls last, i.date, i.invoice_number, i.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- ACLs
-- ---------------------------------------------------------------------------
revoke all on function public.ensure_rental_service_product(uuid) from public, anon, authenticated;
revoke all on function public.expand_rental_coverage_months(jsonb, date, date) from public, anon, authenticated;
revoke all on function public.normalize_collect_rental_payment_payload(jsonb) from public, anon, authenticated;
revoke all on function public.compute_collect_rental_payment_payload_hash(jsonb) from public, anon, authenticated;

grant execute on function public.preview_rental_collection(jsonb) to authenticated;
grant execute on function public.collect_rental_payment(jsonb, uuid) to authenticated;

