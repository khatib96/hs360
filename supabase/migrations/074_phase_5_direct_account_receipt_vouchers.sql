-- Phase 5 M9 voucher UX closure: direct-account receipt vouchers.
-- Keeps customer receipt allocation support, and adds the simple accounting
-- entry path used by the desktop voucher form: Dr cash/bank, Cr account.

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
      type = 'receipt'
      and customer_id is null
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

create or replace function public.normalize_receipt_voucher_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed_top text[] := array[
    'receipt_source', 'customer_id', 'account_id', 'date', 'amount',
    'payment_method', 'cash_account_id', 'reference_no', 'notes',
    'allocation_mode', 'allocations'
  ];
  v_allowed_alloc text[] := array['invoice_id', 'allocated_amount'];
  v_key text;
  v_alloc_elem jsonb;
  v_norm_allocs jsonb := '[]'::jsonb;
  v_source text;
  v_customer_id uuid;
  v_account_id uuid;
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
    p_data ? 'date'
    and p_data ? 'amount'
    and p_data ? 'payment_method'
    and p_data ? 'cash_account_id'
  ) then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'date') <> 'string'
    or jsonb_typeof(p_data -> 'amount') not in ('number', 'string')
    or jsonb_typeof(p_data -> 'payment_method') <> 'string'
    or jsonb_typeof(p_data -> 'cash_account_id') <> 'string'
    or (
      p_data ? 'receipt_source'
      and jsonb_typeof(p_data -> 'receipt_source') <> 'string'
    )
    or (
      p_data ? 'customer_id'
      and jsonb_typeof(p_data -> 'customer_id') not in ('string', 'null')
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

  v_source := lower(btrim(coalesce(p_data ->> 'receipt_source', '')));
  if v_source = '' then
    v_source := case
      when nullif(btrim(coalesce(p_data ->> 'account_id', '')), '') is not null
        then 'account'
      else 'customer'
    end;
  end if;
  if v_source not in ('customer', 'account') then
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

  if v_source = 'customer' then
    if not p_data ? 'customer_id'
      or nullif(btrim(coalesce(p_data ->> 'customer_id', '')), '') is null
      or not p_data ? 'allocation_mode' then
      raise exception 'validation_failed';
    end if;

    begin
      v_customer_id := (p_data ->> 'customer_id')::uuid;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    v_allocation_mode := lower(btrim(p_data ->> 'allocation_mode'));
    if v_allocation_mode not in ('fifo', 'manual', 'unallocated') then
      raise exception 'validation_failed';
    end if;
  else
    if not p_data ? 'account_id'
      or nullif(btrim(coalesce(p_data ->> 'account_id', '')), '') is null then
      raise exception 'validation_failed';
    end if;

    begin
      v_account_id := (p_data ->> 'account_id')::uuid;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    v_allocation_mode := 'unallocated';
    if p_data ? 'allocations'
      and jsonb_typeof(p_data -> 'allocations') = 'array'
      and jsonb_array_length(p_data -> 'allocations') > 0 then
      raise exception 'validation_failed';
    end if;
  end if;

  if v_source = 'customer' then
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
          or jsonb_typeof(v_alloc_elem -> 'allocated_amount') not in ('number', 'string') then
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
  end if;

  v_result := jsonb_build_object(
    'receipt_source', v_source,
    'date', v_voucher_date::text,
    'amount', to_jsonb(v_amount),
    'payment_method', p_data ->> 'payment_method',
    'cash_account_id', v_cash_account_id::text,
    'allocation_mode', v_allocation_mode
  );

  if v_source = 'customer' then
    v_result := v_result || jsonb_build_object('customer_id', v_customer_id::text);
  else
    v_result := v_result || jsonb_build_object('account_id', v_account_id::text);
  end if;

  if p_data ? 'reference_no' and btrim(coalesce(p_data ->> 'reference_no', '')) <> '' then
    v_result := v_result || jsonb_build_object('reference_no', btrim(p_data ->> 'reference_no'));
  end if;

  if p_data ? 'notes' and btrim(coalesce(p_data ->> 'notes', '')) <> '' then
    v_result := v_result || jsonb_build_object('notes', btrim(p_data ->> 'notes'));
  end if;

  if v_source = 'customer' and v_allocation_mode = 'manual' then
    v_result := v_result || jsonb_build_object('allocations', v_norm_allocs);
  end if;

  return v_result;
end;
$$;

comment on function public.normalize_receipt_voucher_payload(jsonb) is
  'M9: Canonical receipt voucher payload; supports customer allocation and direct account receipt.';

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
  v_source text;
  v_customer_id uuid;
  v_account_id uuid;
  v_date date;
  v_amount numeric(15, 3);
  v_payment_method public.payment_method;
  v_cash_account_id uuid;
  v_credit_account_id uuid;
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

  v_source := v_normalized ->> 'receipt_source';
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

  perform public.validate_cash_bank_account(v_tenant_id, v_cash_account_id);

  if v_source = 'customer' then
    v_customer_id := (v_normalized ->> 'customer_id')::uuid;
    perform public.validate_customer_ar_account(v_tenant_id, v_customer_id, null);

    select c.account_id
    into v_credit_account_id
    from public.customers c
    where c.id = v_customer_id
      and c.tenant_id = v_tenant_id;

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
  else
    v_account_id := (v_normalized ->> 'account_id')::uuid;
    perform public.validate_direct_payment_account(
      v_tenant_id,
      v_account_id,
      v_cash_account_id
    );
    v_credit_account_id := v_account_id;
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
    (v_tenant_id, v_journal_entry_id, v_credit_account_id, 0, v_amount, 2, 'Receipt credit');

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
    v_customer_id, null, null, v_credit_account_id, v_cash_account_id,
    v_notes, auth.uid(), v_journal_entry_id,
    'confirmed', p_idempotency_key, v_hash,
    auth.uid(), now(), auth.uid()
  );

  if v_source = 'customer' then
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
  end if;

  return v_voucher_id;
end;
$$;

comment on function public.record_receipt_voucher(jsonb, uuid) is
  'M9: Atomic customer or direct-account receipt voucher with Dr cash / Cr account journal.';
