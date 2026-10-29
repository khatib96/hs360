-- Rental collection correction and rental arrears (owner decisions 2026-10-27).
--
-- Rental billing stays payment-confirmed: collect_rental_payment creates the
-- invoice, receipt voucher, journal entries, and covered months together.
--
-- 1. cancel_rental_collection fully reverses a wrong collection: it cancels
--    the receipt voucher (existing cancel_voucher engine), posts a reversal
--    of the rental invoice journal, marks the invoice cancelled, releases the
--    covered months so the correct payment can be collected, reopens the
--    matching billing calendar events, and writes an audit row with the
--    mandatory reason. Nothing is deleted from the books.
-- 2. list_rental_arrears reports rental months whose billing day has passed
--    and that no collection covers yet, without creating invoices.

alter type public.journal_source add value if not exists 'rental_invoice_reversal';

-- ---------------------------------------------------------------------------
-- 1. cancel_rental_collection
-- ---------------------------------------------------------------------------
create or replace function public.cancel_rental_collection(
  p_invoice_id uuid,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_reason text := nullif(btrim(p_reason), '');
  v_hash text;
  v_invoice public.invoices%rowtype;
  v_voucher_id uuid;
  v_voucher_status text;
  v_books_locked_through date;
  v_paid numeric(15, 3);
  v_reversal_je_id uuid := gen_random_uuid();
  v_reversal_number text;
  v_line_order int := 0;
  v_jl record;
  v_released date[];
  v_month date;
begin
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('invoices.cancel')
     or not public.user_has_permission('vouchers.cancel') then
    raise exception 'permission_denied';
  end if;
  if p_invoice_id is null or v_reason is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_hash := md5('cancel_rental_collection:' || p_invoice_id::text || ':' || v_reason);
  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  -- Replay: the same key already cancelled this collection.
  select * into v_invoice
  from public.invoices i
  where i.id = p_invoice_id
    and i.tenant_id = v_tenant_id
  for update;

  if not found or v_invoice.type <> 'rental_monthly' then
    raise exception 'validation_failed';
  end if;

  if v_invoice.status = 'cancelled' then
    if exists (
      select 1 from public.journal_entries je
      where je.id = v_invoice.reversal_journal_entry_id
        and je.idempotency_key = p_idempotency_key
    ) then
      if (select je.idempotency_payload_hash from public.journal_entries je
          where je.id = v_invoice.reversal_journal_entry_id) is distinct from v_hash then
        raise exception 'idempotency_payload_mismatch';
      end if;
      select rco.voucher_id into v_voucher_id
      from public.rental_collection_operations rco
      where rco.tenant_id = v_tenant_id and rco.invoice_id = p_invoice_id;
      return jsonb_build_object(
        'invoice_id', p_invoice_id,
        'voucher_id', v_voucher_id,
        'released_months', '[]'::jsonb
      );
    end if;
    raise exception 'validation_failed';
  end if;

  if v_invoice.journal_entry_id is null then
    raise exception 'validation_failed';
  end if;

  select ts.books_locked_through into v_books_locked_through
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;
  if v_books_locked_through is not null and v_invoice.date <= v_books_locked_through then
    raise exception 'books_locked';
  end if;

  select rco.voucher_id into v_voucher_id
  from public.rental_collection_operations rco
  where rco.tenant_id = v_tenant_id
    and rco.invoice_id = p_invoice_id;
  if v_voucher_id is null then
    raise exception 'validation_failed';
  end if;

  select v.status::text into v_voucher_status
  from public.vouchers v
  where v.id = v_voucher_id and v.tenant_id = v_tenant_id;

  -- Reverse the receipt first; this releases its allocation to the invoice.
  if v_voucher_status is distinct from 'cancelled' then
    perform public.cancel_voucher(
      v_voucher_id,
      v_reason,
      md5('cancel_rental_collection_voucher:' || p_idempotency_key::text)::uuid
    );
  end if;

  select i.paid_amount into v_paid
  from public.invoices i
  where i.id = p_invoice_id and i.tenant_id = v_tenant_id;
  -- Another receipt is still allocated to this invoice: cancel it first.
  if coalesce(v_paid, 0) <> 0 then
    raise exception 'invoice_has_payments';
  end if;

  if not coalesce(current_setting('hs360.finance_write', true), '') = '1' then
    perform public.allow_finance_write();
  end if;

  perform 1 from public.journal_entries je
  where je.id = v_invoice.journal_entry_id and je.tenant_id = v_tenant_id
  for update;

  v_reversal_number := public.next_document_number('JE');
  insert into public.journal_entries (
    id, tenant_id, entry_number, date, source, source_id,
    description_en, is_posted, created_by,
    reversal_of_entry_id, idempotency_key, idempotency_payload_hash
  )
  values (
    v_reversal_je_id, v_tenant_id, v_reversal_number, v_invoice.date,
    'rental_invoice_reversal'::public.journal_source, p_invoice_id,
    'Cancellation ' || coalesce(v_invoice.invoice_number, p_invoice_id::text),
    false, auth.uid(),
    v_invoice.journal_entry_id, p_idempotency_key, v_hash
  );

  for v_jl in
    select jl.*
    from public.journal_lines jl
    where jl.journal_entry_id = v_invoice.journal_entry_id
      and jl.tenant_id = v_tenant_id
    order by jl.line_order
  loop
    v_line_order := v_line_order + 1;
    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values (
      v_tenant_id, v_reversal_je_id, v_jl.account_id,
      v_jl.credit, v_jl.debit, v_line_order,
      'Reversal: ' || coalesce(v_jl.description, '')
    );
  end loop;

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = v_reversal_je_id and tenant_id = v_tenant_id;

  update public.invoices
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancelled_by = auth.uid(),
    cancellation_reason = v_reason,
    reversal_journal_entry_id = v_reversal_je_id
  where id = p_invoice_id and tenant_id = v_tenant_id;

  -- Release the covered months so the correct payment can be collected.
  with released as (
    delete from public.rental_invoice_coverages ric
    where ric.tenant_id = v_tenant_id
      and ric.invoice_id = p_invoice_id
    returning ric.coverage_month_key
  )
  select coalesce(array_agg(coverage_month_key order by coverage_month_key), '{}')
  into v_released
  from released;

  -- Billing reminders for those months become pending again.
  foreach v_month in array v_released loop
    update public.calendar_events ce
    set status = 'pending'::public.calendar_event_status
    where ce.tenant_id = v_tenant_id
      and ce.contract_id = v_invoice.contract_id
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.type = 'billing_due'::public.calendar_event_type
      and ce.source_key = public.build_contract_calendar_source_key(
        v_invoice.contract_id, 'billing', null, null, v_month
      )
      and ce.status = 'done'::public.calendar_event_status;
  end loop;

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json, reason
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'rental_collection_cancel', 'invoices', p_invoice_id,
    jsonb_build_object('status', v_invoice.status, 'voucher_id', v_voucher_id),
    jsonb_build_object('status', 'cancelled', 'released_months', to_jsonb(v_released)),
    v_reason
  );

  return jsonb_build_object(
    'invoice_id', p_invoice_id,
    'voucher_id', v_voucher_id,
    'released_months', to_jsonb(v_released)
  );
end;
$$;

comment on function public.cancel_rental_collection(uuid, text, uuid) is
  'Reverses a rental collection (voucher, invoice journal) and releases its covered months.';

-- Collections of one rental contract, newest first, for the contract page.
create or replace function public.list_contract_rental_collections(p_contract_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
begin
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not (
    public.user_has_permission('invoices.view')
    or public.user_has_permission('invoices.view_sales')
    or public.user_has_permission('vouchers.view')
  ) then
    raise exception 'permission_denied';
  end if;
  if not exists (
    select 1 from public.contracts c
    where c.id = p_contract_id and c.tenant_id = v_tenant_id
  ) then
    raise exception 'validation_failed';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'invoice_id', i.id,
        'invoice_number', i.invoice_number,
        'date', i.date,
        'total', i.total,
        'status', i.status::text,
        'voucher_id', v.id,
        'voucher_number', v.voucher_number,
        'voucher_status', v.status::text,
        'coverage_months', coalesce(rco.result_payload -> 'coverage_months', '[]'::jsonb),
        'cancelled_at', i.cancelled_at,
        'cancellation_reason', i.cancellation_reason
      )
      order by i.date desc, i.created_at desc
    )
    from public.rental_collection_operations rco
    join public.invoices i on i.id = rco.invoice_id and i.tenant_id = v_tenant_id
    left join public.vouchers v on v.id = rco.voucher_id and v.tenant_id = v_tenant_id
    where rco.tenant_id = v_tenant_id
      and i.contract_id = p_contract_id
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Rental arrears
-- ---------------------------------------------------------------------------
-- One row per uncovered rental month whose billing day is on or before
-- p_as_of. The billing day is clamped to the month length (e.g. 31 -> 28/29/30).
create or replace function public.rental_arrears_rows(p_tenant_id uuid, p_as_of date)
returns table (
  contract_id uuid,
  month_key date,
  due_date date,
  amount numeric(15, 3)
)
language sql
stable
security definer
set search_path = public
as $$
  with contracts_in_scope as (
    select
      c.id,
      c.monthly_rental_value,
      coalesce(c.billing_day, 1) as billing_day,
      date_trunc('month', c.start_date)::date as first_month,
      case
        when c.status in ('completed', 'terminated_early', 'expired')
          then date_trunc(
            'month',
            coalesce(c.closed_at::date, c.returned_at::date, c.end_date, p_as_of)
          )::date
        when c.end_date is not null then date_trunc('month', c.end_date)::date
        else date_trunc('month', p_as_of)::date
      end as last_month
    from public.contracts c
    where c.tenant_id = p_tenant_id
      and c.type = 'rental'
      and c.status in ('active', 'suspended', 'completed', 'terminated_early', 'expired')
      and c.monthly_rental_value > 0
      and c.start_date is not null
  ),
  months as (
    select
      cis.id as contract_id,
      gs::date as month_key,
      make_date(
        extract(year from gs)::int,
        extract(month from gs)::int,
        least(
          greatest(cis.billing_day, 1),
          extract(day from (gs + interval '1 month - 1 day'))::int
        )
      ) as due_date,
      cis.monthly_rental_value as amount
    from contracts_in_scope cis
    cross join lateral generate_series(
      cis.first_month,
      least(cis.last_month, date_trunc('month', p_as_of)::date),
      interval '1 month'
    ) gs
  )
  select m.contract_id, m.month_key, m.due_date, m.amount
  from months m
  where m.due_date <= p_as_of
    and not exists (
      select 1 from public.rental_invoice_coverages ric
      where ric.tenant_id = p_tenant_id
        and ric.contract_id = m.contract_id
        and ric.coverage_month_key = m.month_key
    );
$$;

create or replace function public.list_rental_arrears(p_as_of date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_as_of date;
begin
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('contracts.view')
     or not (
       public.user_has_permission('invoices.view')
       or public.user_has_permission('invoices.view_sales')
     ) then
    raise exception 'permission_denied';
  end if;

  v_as_of := coalesce(p_as_of, public.try_tenant_local_today(v_tenant_id), current_date);

  return (
    with per_contract as (
      select
        r.contract_id,
        count(*)::int as months_count,
        sum(r.amount) as amount,
        min(r.due_date) as oldest_due_date,
        jsonb_agg(to_char(r.month_key, 'YYYY-MM-DD') order by r.month_key) as months
      from public.rental_arrears_rows(v_tenant_id, v_as_of) r
      group by r.contract_id
    )
    select jsonb_build_object(
      'as_of', v_as_of,
      'currency_code', (
        select cur.iso_code from public.tenants t
        left join public.currencies cur on cur.id = t.default_currency_id
        where t.id = v_tenant_id
      ),
      'total_amount', coalesce(sum(pc.amount), 0),
      'total_months', coalesce(sum(pc.months_count), 0),
      'contracts_count', count(pc.contract_id),
      'items', coalesce(jsonb_agg(
        jsonb_build_object(
          'contract_id', c.id,
          'contract_number', c.contract_number,
          'status', c.status::text,
          'customer_id', c.customer_id,
          'customer_name_ar', cu.name_ar,
          'customer_name_en', cu.name_en,
          'monthly_rental_value', c.monthly_rental_value,
          'months', pc.months,
          'months_count', pc.months_count,
          'amount', pc.amount,
          'oldest_due_date', pc.oldest_due_date
        )
        order by pc.oldest_due_date, c.contract_number
      ) filter (where pc.contract_id is not null), '[]'::jsonb)
    )
    from per_contract pc
    join public.contracts c on c.id = pc.contract_id
    left join public.customers cu on cu.id = c.customer_id
  );
end;
$$;

revoke all on function public.cancel_rental_collection(uuid, text, uuid) from public, anon;
revoke all on function public.rental_arrears_rows(uuid, date) from public, anon, authenticated;
revoke all on function public.list_rental_arrears(date) from public, anon;
revoke all on function public.list_contract_rental_collections(uuid) from public, anon;

grant execute on function public.cancel_rental_collection(uuid, text, uuid) to authenticated;
grant execute on function public.list_rental_arrears(date) to authenticated;
grant execute on function public.list_contract_rental_collections(uuid) to authenticated;
