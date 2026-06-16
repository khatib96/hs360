-- Phase 5 M7: voucher, allocation, and payment engine.
-- Reuses M1 idempotency, M5/M6 party account validators, M6 cancellation patterns.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Schema hardening
-- ---------------------------------------------------------------------------
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
  );

drop trigger if exists trg_audit_vouchers_status on public.vouchers;

create trigger trg_audit_vouchers_status
  after update on public.vouchers
  for each row
  when (old.status is distinct from new.status)
  execute function public.audit_log_row();

-- ---------------------------------------------------------------------------
-- Internal: posting leaf check
-- ---------------------------------------------------------------------------
create or replace function public.assert_account_is_posting_leaf(
  p_tenant_id uuid,
  p_account_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_child_count bigint;
begin
  select count(*) into v_child_count
  from public.chart_of_accounts c
  where c.tenant_id = p_tenant_id
    and c.parent_id = p_account_id
    and c.is_active = true;

  if v_child_count > 0 then
    raise exception 'validation_failed';
  end if;
end;
$$;

comment on function public.assert_account_is_posting_leaf(uuid, uuid) is
  'M7: Rejects non-leaf chart accounts for voucher posting.';

-- ---------------------------------------------------------------------------
-- Internal: cash/bank account validation (structural, no code-prefix rule)
-- ---------------------------------------------------------------------------
create or replace function public.validate_cash_bank_account(
  p_tenant_id uuid,
  p_account_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_acct public.chart_of_accounts%rowtype;
begin
  if p_account_id is null then
    raise exception 'validation_failed';
  end if;

  select * into v_acct
  from public.chart_of_accounts
  where id = p_account_id;

  if not found or v_acct.tenant_id <> p_tenant_id then
    raise exception 'cross_tenant_reference';
  end if;

  if v_acct.type <> 'asset'
    or not v_acct.is_active
    or v_acct.related_entity_id is not null then
    raise exception 'validation_failed';
  end if;

  perform public.assert_account_is_posting_leaf(p_tenant_id, p_account_id);
end;
$$;

comment on function public.validate_cash_bank_account(uuid, uuid) is
  'M7: Validates tenant cash/bank posting leaf (asset, active, not entity-linked).';

-- ---------------------------------------------------------------------------
-- Internal: direct payment debit account validation
-- ---------------------------------------------------------------------------
create or replace function public.validate_direct_payment_account(
  p_tenant_id uuid,
  p_account_id uuid,
  p_cash_account_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_acct public.chart_of_accounts%rowtype;
  v_inventory_id uuid;
  v_revenue_id uuid;
  v_cogs_id uuid;
begin
  if p_account_id is null or p_cash_account_id is null then
    raise exception 'validation_failed';
  end if;

  if p_account_id = p_cash_account_id then
    raise exception 'validation_failed';
  end if;

  select * into v_acct
  from public.chart_of_accounts
  where id = p_account_id;

  if not found or v_acct.tenant_id <> p_tenant_id then
    raise exception 'cross_tenant_reference';
  end if;

  if not v_acct.is_active
    or v_acct.related_entity_id is not null
    or v_acct.type not in ('expense', 'liability', 'asset') then
    raise exception 'validation_failed';
  end if;

  perform public.assert_account_is_posting_leaf(p_tenant_id, p_account_id);

  v_inventory_id := public.resolve_system_inventory_account(p_tenant_id);
  if p_account_id = v_inventory_id then
    raise exception 'validation_failed';
  end if;

  begin
    v_revenue_id := public.resolve_system_sales_revenue_account(p_tenant_id);
    if p_account_id = v_revenue_id then
      raise exception 'validation_failed';
    end if;
  exception
    when others then
      null;
  end;

  begin
    v_cogs_id := public.resolve_system_cogs_account(p_tenant_id);
    if p_account_id = v_cogs_id then
      raise exception 'validation_failed';
    end if;
  exception
    when others then
      null;
  end;

  if public.is_reserved_tax_account_code(v_acct.code) then
    raise exception 'validation_failed';
  end if;

  if exists (
    select 1
    from public.chart_of_accounts c
    where c.tenant_id = p_tenant_id
      and c.id = p_account_id
      and c.code in ('1201', '2101', '4101', '5101', '1301')
  ) then
    raise exception 'validation_failed';
  end if;

  if exists (
    select 1
    from public.chart_of_accounts c
    where c.tenant_id = p_tenant_id
      and c.id = p_account_id
      and c.type = 'asset'
      and c.is_active = true
      and c.related_entity_id is null
      and c.code in ('1101', '1102')
  ) then
    raise exception 'validation_failed';
  end if;
end;
$$;

comment on function public.validate_direct_payment_account(uuid, uuid, uuid) is
  'M7: Validates direct payment debit account with explicit deny-list.';

-- ---------------------------------------------------------------------------
-- Internal: receipt voucher payload normalization
-- ---------------------------------------------------------------------------
create or replace function public.normalize_receipt_voucher_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed_top text[] := array[
    'customer_id', 'date', 'amount', 'payment_method', 'cash_account_id',
    'reference_no', 'notes', 'allocation_mode', 'allocations'
  ];
  v_allowed_alloc text[] := array['invoice_id', 'allocated_amount'];
  v_key text;
  v_alloc jsonb;
  v_alloc_elem jsonb;
  v_norm_allocs jsonb := '[]'::jsonb;
  v_customer_id uuid;
  v_voucher_date date;
  v_amount numeric(15, 3);
  v_cash_account_id uuid;
  v_allocation_mode text;
  v_invoice_id uuid;
  v_allocated_amount numeric(15, 3);
  v_seen_invoice_ids uuid[] := '{}';
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
    p_data ? 'customer_id'
    and p_data ? 'date'
    and p_data ? 'amount'
    and p_data ? 'payment_method'
    and p_data ? 'cash_account_id'
    and p_data ? 'allocation_mode'
  ) then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'customer_id') <> 'string'
    or jsonb_typeof(p_data -> 'date') <> 'string'
    or jsonb_typeof(p_data -> 'amount') <> 'number'
    or jsonb_typeof(p_data -> 'payment_method') <> 'string'
    or jsonb_typeof(p_data -> 'cash_account_id') <> 'string'
    or jsonb_typeof(p_data -> 'allocation_mode') <> 'string'
    or (
      p_data ? 'reference_no'
      and jsonb_typeof(p_data -> 'reference_no') not in ('string', 'null')
    )
    or (
      p_data ? 'notes'
      and jsonb_typeof(p_data -> 'notes') not in ('string', 'null')
    )
    or (
      p_data ? 'allocations'
      and jsonb_typeof(p_data -> 'allocations') <> 'array'
    ) then
    raise exception 'validation_failed';
  end if;

  v_allocation_mode := lower(btrim(p_data ->> 'allocation_mode'));
  if v_allocation_mode not in ('fifo', 'manual', 'unallocated') then
    raise exception 'validation_failed';
  end if;

  begin
    v_customer_id := (p_data ->> 'customer_id')::uuid;
    v_voucher_date := (p_data ->> 'date')::date;
    v_amount := (p_data ->> 'amount')::numeric(15, 3);
    v_cash_account_id := (p_data ->> 'cash_account_id')::uuid;
    perform (p_data ->> 'payment_method')::public.payment_method;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if v_amount is null or v_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  if v_allocation_mode = 'manual' then
    if not p_data ? 'allocations'
      or jsonb_typeof(p_data -> 'allocations') <> 'array'
      or jsonb_array_length(p_data -> 'allocations') < 1 then
      raise exception 'validation_failed';
    end if;
  elsif p_data ? 'allocations'
    and jsonb_typeof(p_data -> 'allocations') = 'array'
    and jsonb_array_length(p_data -> 'allocations') > 0 then
    raise exception 'validation_failed';
  end if;

  if v_allocation_mode = 'manual' then
    for v_alloc_elem in select value from jsonb_array_elements(p_data -> 'allocations') loop
      if jsonb_typeof(v_alloc_elem) <> 'object' then
        raise exception 'validation_failed';
      end if;

      for v_key in select jsonb_object_keys(v_alloc_elem) loop
        if not (v_key = any (v_allowed_alloc)) then
          raise exception 'validation_failed';
        end if;
      end loop;

      if not (v_alloc_elem ? 'invoice_id' and v_alloc_elem ? 'allocated_amount')
        or jsonb_typeof(v_alloc_elem -> 'invoice_id') <> 'string'
        or jsonb_typeof(v_alloc_elem -> 'allocated_amount') <> 'number' then
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
      v_norm_allocs := v_norm_allocs || jsonb_build_array(
        jsonb_build_object(
          'invoice_id', v_invoice_id::text,
          'allocated_amount', to_jsonb(v_allocated_amount)
        )
      );
    end loop;

    select coalesce(jsonb_agg(value order by value ->> 'invoice_id'), '[]'::jsonb)
    into v_norm_allocs
    from jsonb_array_elements(v_norm_allocs);
  end if;

  v_result := jsonb_build_object(
    'customer_id', v_customer_id::text,
    'date', v_voucher_date::text,
    'amount', to_jsonb(v_amount),
    'payment_method', p_data ->> 'payment_method',
    'cash_account_id', v_cash_account_id::text,
    'allocation_mode', v_allocation_mode
  );

  if p_data ? 'reference_no' and btrim(coalesce(p_data ->> 'reference_no', '')) <> '' then
    v_result := v_result || jsonb_build_object('reference_no', btrim(p_data ->> 'reference_no'));
  end if;

  if p_data ? 'notes' and btrim(coalesce(p_data ->> 'notes', '')) <> '' then
    v_result := v_result || jsonb_build_object('notes', btrim(p_data ->> 'notes'));
  end if;

  if v_allocation_mode = 'manual' then
    v_result := v_result || jsonb_build_object('allocations', v_norm_allocs);
  end if;

  return v_result;
end;
$$;

comment on function public.normalize_receipt_voucher_payload(jsonb) is
  'M7: Canonical receipt voucher payload. Manual allocations sorted by invoice_id for hash stability.';

create or replace function public.compute_receipt_voucher_payload_hash(p_data jsonb)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(public.normalize_receipt_voucher_payload(p_data)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_receipt_voucher_payload_hash(jsonb) is
  'M7: SHA-256 hex of canonical receipt-voucher payload.';

-- ---------------------------------------------------------------------------
-- Internal: payment voucher payload normalization
-- ---------------------------------------------------------------------------
create or replace function public.normalize_payment_voucher_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed_top text[] := array[
    'payment_destination', 'date', 'amount', 'payment_method', 'cash_account_id',
    'reference_no', 'notes', 'supplier_id', 'allocation_mode', 'allocations',
    'account_id'
  ];
  v_allowed_alloc text[] := array['invoice_id', 'allocated_amount'];
  v_key text;
  v_alloc_elem jsonb;
  v_norm_allocs jsonb := '[]'::jsonb;
  v_destination text;
  v_allocation_mode text;
  v_voucher_date date;
  v_amount numeric(15, 3);
  v_cash_account_id uuid;
  v_supplier_id uuid;
  v_account_id uuid;
  v_invoice_id uuid;
  v_allocated_amount numeric(15, 3);
  v_seen_invoice_ids uuid[] := '{}';
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
    p_data ? 'payment_destination'
    and p_data ? 'date'
    and p_data ? 'amount'
    and p_data ? 'payment_method'
    and p_data ? 'cash_account_id'
  ) then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'payment_destination') <> 'string'
    or jsonb_typeof(p_data -> 'date') <> 'string'
    or jsonb_typeof(p_data -> 'amount') <> 'number'
    or jsonb_typeof(p_data -> 'payment_method') <> 'string'
    or jsonb_typeof(p_data -> 'cash_account_id') <> 'string'
    or (
      p_data ? 'reference_no'
      and jsonb_typeof(p_data -> 'reference_no') not in ('string', 'null')
    )
    or (
      p_data ? 'notes'
      and jsonb_typeof(p_data -> 'notes') not in ('string', 'null')
    )
    or (
      p_data ? 'supplier_id'
      and jsonb_typeof(p_data -> 'supplier_id') not in ('string', 'null')
    )
    or (
      p_data ? 'account_id'
      and jsonb_typeof(p_data -> 'account_id') not in ('string', 'null')
    )
    or (
      p_data ? 'allocation_mode'
      and jsonb_typeof(p_data -> 'allocation_mode') not in ('string', 'null')
    )
    or (
      p_data ? 'allocations'
      and jsonb_typeof(p_data -> 'allocations') <> 'array'
    ) then
    raise exception 'validation_failed';
  end if;

  v_destination := lower(btrim(p_data ->> 'payment_destination'));
  if v_destination not in ('supplier', 'account') then
    raise exception 'validation_failed';
  end if;

  begin
    v_voucher_date := (p_data ->> 'date')::date;
    v_amount := (p_data ->> 'amount')::numeric(15, 3);
    v_cash_account_id := (p_data ->> 'cash_account_id')::uuid;
    perform (p_data ->> 'payment_method')::public.payment_method;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if v_amount is null or v_amount <= 0 then
    raise exception 'validation_failed';
  end if;

  if v_destination = 'supplier' then
    if not p_data ? 'supplier_id' or not p_data ? 'allocation_mode' then
      raise exception 'validation_failed';
    end if;

    if jsonb_typeof(p_data -> 'supplier_id') <> 'string' then
      raise exception 'validation_failed';
    end if;

    v_allocation_mode := lower(btrim(p_data ->> 'allocation_mode'));
    if v_allocation_mode not in ('fifo', 'manual') then
      raise exception 'validation_failed';
    end if;

    if p_data ? 'account_id' then
      raise exception 'validation_failed';
    end if;

    begin
      v_supplier_id := (p_data ->> 'supplier_id')::uuid;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if v_allocation_mode = 'manual' then
      if not p_data ? 'allocations'
        or jsonb_typeof(p_data -> 'allocations') <> 'array'
        or jsonb_array_length(p_data -> 'allocations') < 1 then
        raise exception 'validation_failed';
      end if;

      for v_alloc_elem in select value from jsonb_array_elements(p_data -> 'allocations') loop
        if jsonb_typeof(v_alloc_elem) <> 'object' then
          raise exception 'validation_failed';
        end if;

        for v_key in select jsonb_object_keys(v_alloc_elem) loop
          if not (v_key = any (v_allowed_alloc)) then
            raise exception 'validation_failed';
          end if;
        end loop;

        if not (v_alloc_elem ? 'invoice_id' and v_alloc_elem ? 'allocated_amount')
          or jsonb_typeof(v_alloc_elem -> 'invoice_id') <> 'string'
          or jsonb_typeof(v_alloc_elem -> 'allocated_amount') <> 'number' then
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
        v_norm_allocs := v_norm_allocs || jsonb_build_array(
          jsonb_build_object(
            'invoice_id', v_invoice_id::text,
            'allocated_amount', to_jsonb(v_allocated_amount)
          )
        );
      end loop;

      select coalesce(jsonb_agg(value order by value ->> 'invoice_id'), '[]'::jsonb)
      into v_norm_allocs
      from jsonb_array_elements(v_norm_allocs);
    elsif p_data ? 'allocations'
      and jsonb_typeof(p_data -> 'allocations') = 'array'
      and jsonb_array_length(p_data -> 'allocations') > 0 then
      raise exception 'validation_failed';
    end if;

    v_result := jsonb_build_object(
      'payment_destination', 'supplier',
      'supplier_id', v_supplier_id::text,
      'date', v_voucher_date::text,
      'amount', to_jsonb(v_amount),
      'payment_method', p_data ->> 'payment_method',
      'cash_account_id', v_cash_account_id::text,
      'allocation_mode', v_allocation_mode
    );

    if v_allocation_mode = 'manual' then
      v_result := v_result || jsonb_build_object('allocations', v_norm_allocs);
    end if;
  else
    if not p_data ? 'account_id' then
      raise exception 'validation_failed';
    end if;

    if jsonb_typeof(p_data -> 'account_id') <> 'string' then
      raise exception 'validation_failed';
    end if;

    if p_data ? 'supplier_id'
      or p_data ? 'allocation_mode'
      or (
        p_data ? 'allocations'
        and jsonb_typeof(p_data -> 'allocations') = 'array'
        and jsonb_array_length(p_data -> 'allocations') > 0
      ) then
      raise exception 'validation_failed';
    end if;

    begin
      v_account_id := (p_data ->> 'account_id')::uuid;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    v_result := jsonb_build_object(
      'payment_destination', 'account',
      'account_id', v_account_id::text,
      'date', v_voucher_date::text,
      'amount', to_jsonb(v_amount),
      'payment_method', p_data ->> 'payment_method',
      'cash_account_id', v_cash_account_id::text
    );
  end if;

  if p_data ? 'reference_no' and btrim(coalesce(p_data ->> 'reference_no', '')) <> '' then
    v_result := v_result || jsonb_build_object('reference_no', btrim(p_data ->> 'reference_no'));
  end if;

  if p_data ? 'notes' and btrim(coalesce(p_data ->> 'notes', '')) <> '' then
    v_result := v_result || jsonb_build_object('notes', btrim(p_data ->> 'notes'));
  end if;

  return v_result;
end;
$$;

comment on function public.normalize_payment_voucher_payload(jsonb) is
  'M7: Canonical payment voucher payload for supplier FIFO/manual or direct account debit.';

create or replace function public.compute_payment_voucher_payload_hash(p_data jsonb)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(
      convert_to(public.normalize_payment_voucher_payload(p_data)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_payment_voucher_payload_hash(jsonb) is
  'M7: SHA-256 hex of canonical payment-voucher payload.';

-- ---------------------------------------------------------------------------
-- Internal: cancel voucher payload normalization
-- ---------------------------------------------------------------------------
create or replace function public.normalize_cancel_voucher_payload(
  p_voucher_id uuid,
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
  if p_voucher_id is null then
    raise exception 'validation_failed';
  end if;

  v_reason := btrim(coalesce(p_reason, ''));
  if v_reason = '' then
    raise exception 'validation_failed';
  end if;

  return jsonb_build_object(
    'voucher_id', p_voucher_id::text,
    'reason', v_reason
  );
end;
$$;

comment on function public.normalize_cancel_voucher_payload(uuid, text) is
  'M7: Canonical cancel-voucher payload for idempotency hashing.';

create or replace function public.compute_cancel_voucher_payload_hash(
  p_voucher_id uuid,
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
        public.normalize_cancel_voucher_payload(p_voucher_id, p_reason)::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function public.compute_cancel_voucher_payload_hash(uuid, text) is
  'M7: SHA-256 hex of canonical cancel-voucher payload.';

-- ---------------------------------------------------------------------------
-- Internal: active allocation paid amount for an invoice
-- ---------------------------------------------------------------------------
create or replace function public.get_invoice_allocation_paid_amount(
  p_tenant_id uuid,
  p_invoice_id uuid
)
returns numeric(15, 3)
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(via.allocated_amount), 0)::numeric(15, 3)
  from public.voucher_invoice_allocations via
  join public.vouchers v
    on v.id = via.voucher_id
    and v.tenant_id = via.tenant_id
  where via.tenant_id = p_tenant_id
    and via.invoice_id = p_invoice_id
    and coalesce(via.is_reversed, false) = false
    and v.status = 'confirmed';
$$;

comment on function public.get_invoice_allocation_paid_amount(uuid, uuid) is
  'M7: Sum of active voucher allocations for an invoice.';

-- ---------------------------------------------------------------------------
-- Internal: manual allocation validation with invoice row locks
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
  v_invoice_type text;
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

comment on function public.validate_manual_allocations(uuid, numeric, uuid, text, jsonb, boolean) is
  'M7: Validates manual voucher allocations with invoice locks, party/direction/outstanding checks.';

-- ---------------------------------------------------------------------------
-- Internal: FIFO receipt allocation (partial OK)
-- ---------------------------------------------------------------------------
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

comment on function public.allocate_receipt_fifo(uuid, uuid, numeric) is
  'M7: FIFO receipt allocation across open sales invoices. Partial allocation is allowed.';

-- ---------------------------------------------------------------------------
-- Internal: FIFO payment allocation
-- ---------------------------------------------------------------------------
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
  v_paid numeric(15, 3);
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

comment on function public.allocate_payment_fifo(uuid, uuid, numeric, boolean) is
  'M7: FIFO payment allocation across open purchase invoices.';

-- ---------------------------------------------------------------------------
-- Internal: recompute invoice paid amount and status
-- ---------------------------------------------------------------------------
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
    or v_invoice.type not in ('sales', 'purchase') then
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

comment on function public.recompute_invoice_payment_state(uuid, uuid) is
  'M7: Recomputes invoice paid_amount and status from active voucher allocations.';

create or replace function public.recompute_invoices_for_voucher(
  p_tenant_id uuid,
  p_voucher_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_id uuid;
begin
  for v_invoice_id in
    select distinct via.invoice_id
    from public.voucher_invoice_allocations via
    where via.tenant_id = p_tenant_id
      and via.voucher_id = p_voucher_id
    order by via.invoice_id
  loop
    perform public.recompute_invoice_payment_state(p_tenant_id, v_invoice_id);
  end loop;
end;
$$;

comment on function public.recompute_invoices_for_voucher(uuid, uuid) is
  'M7: Recomputes payment state for all invoices linked to a voucher.';

-- ---------------------------------------------------------------------------
-- Public: record receipt voucher
-- ---------------------------------------------------------------------------
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

comment on function public.record_receipt_voucher(jsonb, uuid) is
  'M7: Atomic receipt voucher with FIFO/manual/unallocated allocation and Dr cash / Cr A/R journal.';

-- ---------------------------------------------------------------------------
-- Public: record payment voucher
-- ---------------------------------------------------------------------------
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
        v_tenant_id,
        v_supplier_id,
        v_amount,
        true
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
    else
      raise exception 'validation_failed';
    end if;
  else
    if not public.is_manager() then
      raise exception 'permission_denied';
    end if;

    v_account_id := (v_normalized ->> 'account_id')::uuid;
    perform public.validate_direct_payment_account(
      v_tenant_id,
      v_account_id,
      v_cash_account_id
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

comment on function public.record_payment_voucher(jsonb, uuid) is
  'M7: Atomic supplier or direct-account payment voucher with Dr debit account / Cr cash journal.';

-- ---------------------------------------------------------------------------
-- Public: cancel voucher
-- ---------------------------------------------------------------------------
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
declare
  v_tenant_id uuid;
  v_hash text;
  v_existing_je_id uuid;
  v_voucher public.vouchers%rowtype;
  v_reversal_je_id uuid;
  v_reversal_number text;
  v_jl record;
  v_invoice_lock record;
  v_je_line_order int := 0;
  v_books_locked_through date;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('vouchers.cancel') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  perform public.normalize_cancel_voucher_payload(p_voucher_id, p_reason);
  v_hash := public.compute_cancel_voucher_payload_hash(p_voucher_id, p_reason);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_je_id := public.resolve_finance_idempotency(
    'public.journal_entries'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_je_id is not null then
    select v.id
    into p_voucher_id
    from public.vouchers v
    where v.tenant_id = v_tenant_id
      and v.reversal_journal_entry_id = v_existing_je_id;

    if not found then
      select je.source_id
      into p_voucher_id
      from public.journal_entries je
      where je.id = v_existing_je_id
        and je.tenant_id = v_tenant_id;
    end if;

    if p_voucher_id is null then
      raise exception 'validation_failed';
    end if;

    return p_voucher_id;
  end if;

  select * into v_voucher
  from public.vouchers v
  where v.id = p_voucher_id
    and v.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_voucher.status = 'cancelled' then
    raise exception 'validation_failed';
  end if;

  if v_voucher.journal_entry_id is null then
    raise exception 'validation_failed';
  end if;

  select ts.books_locked_through
  into v_books_locked_through
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if v_books_locked_through is not null and v_voucher.date <= v_books_locked_through then
    raise exception 'validation_failed';
  end if;

  perform 1
  from public.journal_entries je
  where je.id = v_voucher.journal_entry_id
    and je.tenant_id = v_tenant_id
  for update;

  for v_invoice_lock in
    select distinct via.invoice_id as invoice_id
    from public.voucher_invoice_allocations via
    where via.tenant_id = v_tenant_id
      and via.voucher_id = p_voucher_id
      and coalesce(via.is_reversed, false) = false
    order by via.invoice_id
  loop
    perform 1
    from public.invoices i
    where i.id = v_invoice_lock.invoice_id
      and i.tenant_id = v_tenant_id
    for update;
  end loop;

  perform public.allow_finance_write();

  update public.voucher_invoice_allocations
  set
    is_reversed = true,
    reversed_at = now(),
    reversed_by = auth.uid()
  where tenant_id = v_tenant_id
    and voucher_id = p_voucher_id
    and coalesce(is_reversed, false) = false;

  perform public.recompute_invoices_for_voucher(v_tenant_id, p_voucher_id);

  v_reversal_number := public.next_document_number('JE');
  v_reversal_je_id := gen_random_uuid();

  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by,
    reversal_of_entry_id, idempotency_key, idempotency_payload_hash
  )
  values (
    v_reversal_je_id, v_tenant_id, v_reversal_number, v_voucher.date,
    (case
      when v_voucher.type = 'receipt' then 'receipt_voucher_reversal'
      else 'payment_voucher_reversal'
    end)::public.journal_source,
    p_voucher_id,
    'Cancellation ' || coalesce(v_voucher.voucher_number, p_voucher_id::text),
    false,
    auth.uid(),
    v_voucher.journal_entry_id,
    p_idempotency_key,
    v_hash
  );

  for v_jl in
    select jl.*
    from public.journal_lines jl
    where jl.journal_entry_id = v_voucher.journal_entry_id
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

  update public.vouchers
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancelled_by = auth.uid(),
    cancellation_reason = btrim(p_reason),
    reversal_journal_entry_id = v_reversal_je_id
  where id = p_voucher_id
    and tenant_id = v_tenant_id;

  return p_voucher_id;
end;
$$;

comment on function public.cancel_voucher(uuid, text, uuid) is
  'M7: Safe voucher cancellation with allocation reversal and balanced reversal journal.';

-- ---------------------------------------------------------------------------
-- Public: list vouchers
-- ---------------------------------------------------------------------------
create or replace function public.list_vouchers(
  p_customer_or_supplier_id uuid default null,
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
  voucher_number text,
  type public.voucher_type,
  status public.voucher_status,
  date date,
  amount numeric(15, 3),
  payment_method public.payment_method,
  reference_no text,
  customer_id uuid,
  supplier_id uuid,
  customer_name_ar text,
  customer_name_en text,
  supplier_name_ar text,
  supplier_name_en text,
  account_id uuid,
  cash_account_id uuid,
  allocated_amount numeric(15, 3),
  unallocated_amount numeric(15, 3),
  journal_entry_id uuid,
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

  if not public.user_has_permission('vouchers.view') then
    raise exception 'permission_denied';
  end if;

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    v.id,
    v.voucher_number,
    v.type,
    v.status,
    v.date,
    v.amount,
    v.payment_method,
    v.reference_no,
    v.customer_id,
    v.supplier_id,
    c.name_ar as customer_name_ar,
    c.name_en as customer_name_en,
    s.name_ar as supplier_name_ar,
    s.name_en as supplier_name_en,
    v.account_id,
    v.cash_account_id,
    coalesce(alloc.allocated_amount, 0)::numeric(15, 3) as allocated_amount,
    (v.amount - coalesce(alloc.allocated_amount, 0))::numeric(15, 3) as unallocated_amount,
    v.journal_entry_id,
    v.cancelled_at
  from public.vouchers v
  left join public.customers c
    on c.id = v.customer_id
    and c.tenant_id = v.tenant_id
  left join public.suppliers s
    on s.id = v.supplier_id
    and s.tenant_id = v.tenant_id
  left join lateral (
    select coalesce(sum(via.allocated_amount), 0) as allocated_amount
    from public.voucher_invoice_allocations via
    where via.tenant_id = v.tenant_id
      and via.voucher_id = v.id
      and coalesce(via.is_reversed, false) = false
  ) alloc on true
  where v.tenant_id = v_tenant_id
    and (p_type is null or v.type::text = p_type)
    and (p_status is null or v.status::text = p_status)
    and (p_date_from is null or v.date >= p_date_from)
    and (p_date_to is null or v.date <= p_date_to)
    and (
      p_customer_or_supplier_id is null
      or v.customer_id = p_customer_or_supplier_id
      or v.supplier_id = p_customer_or_supplier_id
    )
    and (
      v_search is null
      or lower(coalesce(v.voucher_number, '')) like '%' || v_search || '%'
      or lower(coalesce(v.reference_no, '')) like '%' || v_search || '%'
      or lower(coalesce(c.name_ar, '')) like '%' || v_search || '%'
      or lower(coalesce(c.name_en, '')) like '%' || v_search || '%'
      or lower(coalesce(s.name_ar, '')) like '%' || v_search || '%'
      or lower(coalesce(s.name_en, '')) like '%' || v_search || '%'
    )
  order by v.date desc nulls last, v.voucher_number desc nulls last, v.id desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

comment on function public.list_vouchers(uuid, text, text, date, date, text, integer, integer) is
  'M7: Bounded voucher list with party labels and allocation totals.';

-- ---------------------------------------------------------------------------
-- Public: voucher detail
-- ---------------------------------------------------------------------------
create or replace function public.get_voucher_detail(p_voucher_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_voucher public.vouchers%rowtype;
  v_customer public.customers%rowtype;
  v_supplier public.suppliers%rowtype;
  v_account public.chart_of_accounts%rowtype;
  v_cash_account public.chart_of_accounts%rowtype;
  v_allocations jsonb;
  v_allocated numeric(15, 3);
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('vouchers.view') then
    raise exception 'permission_denied';
  end if;

  select * into v_voucher
  from public.vouchers v
  where v.id = p_voucher_id
    and v.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_voucher.customer_id is not null then
    select * into v_customer
    from public.customers c
    where c.id = v_voucher.customer_id
      and c.tenant_id = v_tenant_id;
  end if;

  if v_voucher.supplier_id is not null then
    select * into v_supplier
    from public.suppliers s
    where s.id = v_voucher.supplier_id
      and s.tenant_id = v_tenant_id;
  end if;

  select * into v_account
  from public.chart_of_accounts coa
  where coa.id = v_voucher.account_id
    and coa.tenant_id = v_tenant_id;

  select * into v_cash_account
  from public.chart_of_accounts coa
  where coa.id = v_voucher.cash_account_id
    and coa.tenant_id = v_tenant_id;

  select
    coalesce(jsonb_agg(
      jsonb_build_object(
        'id', via.id,
        'invoice_id', via.invoice_id,
        'invoice_number', i.invoice_number,
        'invoice_date', i.date,
        'invoice_due_date', i.due_date,
        'invoice_total', i.total,
        'allocated_amount', via.allocated_amount,
        'is_reversed', via.is_reversed,
        'reversed_at', via.reversed_at
      )
      order by via.created_at, via.id
    ), '[]'::jsonb),
    coalesce(sum(
      case when coalesce(via.is_reversed, false) then 0 else via.allocated_amount end
    ), 0)
  into v_allocations, v_allocated
  from public.voucher_invoice_allocations via
  join public.invoices i
    on i.id = via.invoice_id
    and i.tenant_id = via.tenant_id
  where via.tenant_id = v_tenant_id
    and via.voucher_id = p_voucher_id;

  return jsonb_build_object(
    'id', v_voucher.id,
    'voucher_number', v_voucher.voucher_number,
    'type', v_voucher.type,
    'status', v_voucher.status,
    'date', v_voucher.date,
    'amount', v_voucher.amount,
    'payment_method', v_voucher.payment_method,
    'reference_no', v_voucher.reference_no,
    'notes', v_voucher.notes,
    'collected_by', v_voucher.collected_by,
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
    'account', jsonb_build_object(
      'id', v_account.id,
      'code', v_account.code,
      'name_ar', v_account.name_ar,
      'name_en', v_account.name_en
    ),
    'cash_account', jsonb_build_object(
      'id', v_cash_account.id,
      'code', v_cash_account.code,
      'name_ar', v_cash_account.name_ar,
      'name_en', v_cash_account.name_en
    ),
    'journal_entry_id', v_voucher.journal_entry_id,
    'reversal_journal_entry_id', v_voucher.reversal_journal_entry_id,
    'confirmed_at', v_voucher.confirmed_at,
    'confirmed_by', v_voucher.confirmed_by,
    'cancelled_at', v_voucher.cancelled_at,
    'cancelled_by', v_voucher.cancelled_by,
    'cancellation_reason', v_voucher.cancellation_reason,
    'allocations', v_allocations,
    'allocated_amount', v_allocated,
    'unallocated_amount', (v_voucher.amount - v_allocated)
  );
end;
$$;

comment on function public.get_voucher_detail(uuid) is
  'M7: Voucher detail with allocations and unallocated amount.';

-- ---------------------------------------------------------------------------
-- Public: open customer invoices for allocation
-- ---------------------------------------------------------------------------
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
    (i.total - i.paid_amount)::numeric(15, 3) as outstanding
  from public.invoices i
  where i.tenant_id = v_tenant_id
    and i.customer_id = p_customer_id
    and i.type = 'sales'
    and i.status in ('confirmed', 'partially_paid')
    and (i.total - i.paid_amount) > 0
  order by
    i.due_date nulls last,
    i.date,
    i.invoice_number,
    i.id;
end;
$$;

comment on function public.list_open_customer_invoices(uuid) is
  'M7: Open sales invoices for a customer in FIFO allocation order.';

-- ---------------------------------------------------------------------------
-- Public: open supplier invoices for allocation
-- ---------------------------------------------------------------------------
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
    (i.total - i.paid_amount)::numeric(15, 3) as outstanding
  from public.invoices i
  where i.tenant_id = v_tenant_id
    and i.supplier_id = p_supplier_id
    and i.type = 'purchase'
    and i.status in ('confirmed', 'partially_paid')
    and (i.total - i.paid_amount) > 0
  order by
    i.due_date nulls last,
    i.date,
    i.invoice_number,
    i.id;
end;
$$;

comment on function public.list_open_supplier_invoices(uuid) is
  'M7: Open purchase invoices for a supplier in FIFO allocation order.';

-- ---------------------------------------------------------------------------
-- Public: cash/bank account activity
-- ---------------------------------------------------------------------------
create or replace function public.get_cash_bank_activity(
  p_account_id uuid,
  p_date_from date default null,
  p_date_to date default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_account public.chart_of_accounts%rowtype;
  v_opening numeric(15, 3) := 0;
  v_rows jsonb;
  v_limit integer;
  v_offset integer;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('cash_bank.view') then
    raise exception 'permission_denied';
  end if;

  if p_account_id is null then
    raise exception 'validation_failed';
  end if;

  select * into v_account
  from public.chart_of_accounts coa
  where coa.id = p_account_id
    and coa.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  perform public.validate_cash_bank_account(v_tenant_id, p_account_id);

  v_limit := greatest(least(coalesce(p_limit, 50), 100), 1);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  if p_date_from is not null then
    select coalesce(sum(jl.debit - jl.credit), 0)::numeric(15, 3)
    into v_opening
    from public.journal_lines jl
    join public.journal_entries je on je.id = jl.journal_entry_id
    where jl.tenant_id = v_tenant_id
      and jl.account_id = p_account_id
      and je.is_posted = true
      and je.date < p_date_from;
  end if;

  with filtered as (
    select
      je.date as entry_date,
      je.entry_number,
      je.source,
      je.source_id,
      jl.description,
      jl.debit,
      jl.credit,
      je.id as journal_entry_id,
      jl.id as journal_line_id
    from public.journal_lines jl
    join public.journal_entries je on je.id = jl.journal_entry_id
    where jl.tenant_id = v_tenant_id
      and jl.account_id = p_account_id
      and je.is_posted = true
      and (p_date_from is null or je.date >= p_date_from)
      and (p_date_to is null or je.date <= p_date_to)
  ),
  numbered as (
    select
      f.*,
      (v_opening + sum(f.debit - f.credit) over (
        order by f.entry_date, f.entry_number, f.journal_entry_id, f.journal_line_id
        rows between unbounded preceding and current row
      ))::numeric(15, 3) as running_balance
    from filtered f
  ),
  paged as (
    select *
    from numbered
    order by entry_date, entry_number, journal_entry_id, journal_line_id
    limit v_limit
    offset v_offset
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'entry_date', p.entry_date,
      'entry_number', p.entry_number,
      'source', p.source,
      'source_id', p.source_id,
      'description', p.description,
      'debit', p.debit,
      'credit', p.credit,
      'running_balance', p.running_balance
    )
    order by p.entry_date, p.entry_number, p.journal_entry_id, p.journal_line_id
  ), '[]'::jsonb)
  into v_rows
  from paged p;

  return jsonb_build_object(
    'account_id', p_account_id,
    'account_code', v_account.code,
    'account_name_ar', v_account.name_ar,
    'account_name_en', v_account.name_en,
    'date_from', p_date_from,
    'date_to', p_date_to,
    'opening_balance', v_opening,
    'limit', v_limit,
    'offset', v_offset,
    'rows', v_rows
  );
end;
$$;

comment on function public.get_cash_bank_activity(uuid, date, date, integer, integer) is
  'M7: Cash/bank activity with opening balance and running balance rows.';

-- ---------------------------------------------------------------------------
-- ACL: internal helpers revoked; public RPCs granted
-- ---------------------------------------------------------------------------
revoke all on function public.assert_account_is_posting_leaf(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.validate_cash_bank_account(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.validate_direct_payment_account(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.normalize_receipt_voucher_payload(jsonb)
  from public, anon, authenticated;
revoke all on function public.compute_receipt_voucher_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function public.normalize_payment_voucher_payload(jsonb)
  from public, anon, authenticated;
revoke all on function public.compute_payment_voucher_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function public.normalize_cancel_voucher_payload(uuid, text)
  from public, anon, authenticated;
revoke all on function public.compute_cancel_voucher_payload_hash(uuid, text)
  from public, anon, authenticated;
revoke all on function public.get_invoice_allocation_paid_amount(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.validate_manual_allocations(uuid, numeric, uuid, text, jsonb, boolean)
  from public, anon, authenticated;
revoke all on function public.allocate_receipt_fifo(uuid, uuid, numeric)
  from public, anon, authenticated;
revoke all on function public.allocate_payment_fifo(uuid, uuid, numeric, boolean)
  from public, anon, authenticated;
revoke all on function public.recompute_invoice_payment_state(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.recompute_invoices_for_voucher(uuid, uuid)
  from public, anon, authenticated;

grant execute on function public.record_receipt_voucher(jsonb, uuid) to authenticated;
grant execute on function public.record_payment_voucher(jsonb, uuid) to authenticated;
grant execute on function public.cancel_voucher(uuid, text, uuid) to authenticated;
grant execute on function public.list_vouchers(uuid, text, text, date, date, text, integer, integer)
  to authenticated;
grant execute on function public.get_voucher_detail(uuid) to authenticated;
grant execute on function public.list_open_customer_invoices(uuid) to authenticated;
grant execute on function public.list_open_supplier_invoices(uuid) to authenticated;
grant execute on function public.get_cash_bank_activity(uuid, date, date, integer, integer)
  to authenticated;
