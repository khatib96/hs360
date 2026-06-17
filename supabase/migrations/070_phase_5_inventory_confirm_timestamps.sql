-- Phase 5 M4.5 corrective pass: monotonic document timestamps for safe-cancel ordering.

create or replace function public.set_inventory_document_confirm_timestamps()
returns trigger
language plpgsql
as $$
begin
  new.confirmed_at := clock_timestamp();
  new.created_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists trg_inventory_documents_confirm_timestamps
  on public.inventory_documents;

create trigger trg_inventory_documents_confirm_timestamps
  before insert on public.inventory_documents
  for each row
  execute function public.set_inventory_document_confirm_timestamps();

-- Re-apply cancel unsafe check using monotonic confirmed_at ordering.
create or replace function public.cancel_inventory_document(
  p_document_id uuid,
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
  v_replay_doc_id uuid;
  v_doc public.inventory_documents%rowtype;
  v_line public.inventory_document_lines%rowtype;
  v_reversal_je_id uuid;
  v_reversal_number text;
  v_jl record;
  v_line_order int := 0;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('inventory_documents.cancel') then
    raise exception 'permission_denied';
  end if;

  if p_document_id is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  perform public.normalize_cancel_inventory_document_payload(p_document_id, p_reason);
  v_hash := public.compute_cancel_inventory_document_payload_hash(p_document_id, p_reason);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_existing_je_id := public.resolve_finance_idempotency(
    'public.journal_entries'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_je_id is not null then
    select d.id
    into v_replay_doc_id
    from public.inventory_documents d
    where d.tenant_id = v_tenant_id
      and d.reversal_journal_entry_id = v_existing_je_id;

    if v_replay_doc_id is null then
      select je.source_id
      into v_replay_doc_id
      from public.journal_entries je
      where je.id = v_existing_je_id
        and je.tenant_id = v_tenant_id;
    end if;

    return coalesce(v_replay_doc_id, p_document_id);
  end if;

  select d.id
  into v_replay_doc_id
  from public.inventory_documents d
  where d.tenant_id = v_tenant_id
    and d.cancellation_idempotency_key = p_idempotency_key
    and d.cancellation_idempotency_payload_hash = v_hash;

  if v_replay_doc_id is not null then
    return v_replay_doc_id;
  end if;

  select * into v_doc
  from public.inventory_documents d
  where d.id = p_document_id and d.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_doc.status <> 'confirmed' then
    raise exception 'validation_failed';
  end if;

  perform public.assert_books_open_for_date(v_tenant_id, v_doc.document_date);

  if exists (
    select 1
    from public.inventory_document_lines l
    where l.document_id = p_document_id
      and l.tenant_id = v_tenant_id
      and l.product_unit_ids is not null
      and coalesce(array_length(l.product_unit_ids, 1), 0) > 0
  ) then
    raise exception 'correction_document_required';
  end if;

  for v_line in
    select * from public.inventory_document_lines l
    where l.document_id = p_document_id and l.tenant_id = v_tenant_id
  loop
    if v_line.delta_qty = 0 then
      continue;
    end if;

    if exists (
      select 1
      from public.inventory_document_lines l2
      join public.inventory_documents d2
        on d2.id = l2.document_id
       and d2.tenant_id = l2.tenant_id
      where l2.tenant_id = v_tenant_id
        and l2.product_id = v_line.product_id
        and d2.warehouse_id = v_doc.warehouse_id
        and d2.id <> p_document_id
        and d2.status = 'confirmed'
        and d2.confirmed_at > v_doc.confirmed_at
        and l2.delta_qty <> 0
    ) then
      raise exception 'correction_document_required';
    end if;
  end loop;

  if v_doc.journal_entry_id is not null then
    v_reversal_number := public.next_document_number('JE');
    v_reversal_je_id := gen_random_uuid();

    perform public.allow_finance_write();

    insert into public.journal_entries (
      id, tenant_id, entry_number, date, source, source_id,
      description_en, is_posted, created_by,
      reversal_of_entry_id, idempotency_key, idempotency_payload_hash
    )
    values (
      v_reversal_je_id, v_tenant_id, v_reversal_number, v_doc.document_date,
      'inventory_document_reversal', p_document_id,
      'Reversal ' || v_doc.document_number, false, auth.uid(),
      v_doc.journal_entry_id, p_idempotency_key, v_hash
    );

    for v_jl in
      select jl.account_id, jl.debit, jl.credit
      from public.journal_lines jl
      where jl.journal_entry_id = v_doc.journal_entry_id
        and jl.tenant_id = v_tenant_id
      order by jl.line_order
    loop
      v_line_order := v_line_order + 1;
      insert into public.journal_lines (
        tenant_id, journal_entry_id, account_id, debit, credit, line_order
      )
      values (
        v_tenant_id, v_reversal_je_id, v_jl.account_id,
        v_jl.credit, v_jl.debit, v_line_order
      );
    end loop;

    update public.journal_entries
    set is_posted = true, posted_at = now(), posted_by = auth.uid()
    where id = v_reversal_je_id and tenant_id = v_tenant_id;
  end if;

  perform public.allow_finance_write();

  for v_line in
    select * from public.inventory_document_lines l
    where l.document_id = p_document_id and l.tenant_id = v_tenant_id
    order by l.line_order
  loop
    if v_line.delta_qty = 0 then
      continue;
    end if;

    if v_line.delta_qty > 0 then
      update public.inventory_balances
      set qty_available = qty_available - abs(v_line.delta_qty)
      where tenant_id = v_tenant_id
        and warehouse_id = v_doc.warehouse_id
        and product_id = v_line.product_id;

      perform public.revert_inventory_wac_internal(
        v_tenant_id,
        v_line.product_id,
        abs(v_line.delta_qty),
        v_line.total_value
      );
    else
      insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
      values (
        v_tenant_id, v_doc.warehouse_id, v_line.product_id, abs(v_line.delta_qty)
      )
      on conflict (warehouse_id, product_id) do update
      set qty_available = public.inventory_balances.qty_available + excluded.qty_available;
    end if;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, qty, unit_cost,
      reference_table, reference_id, notes, created_by, occurred_at
    )
    values (
      v_tenant_id,
      case when v_line.delta_qty > 0 then 'adjustment_out'::public.movement_type
           else 'adjustment_in'::public.movement_type end,
      v_doc.warehouse_id,
      v_line.product_id,
      abs(v_line.delta_qty),
      v_line.unit_cost_snapshot,
      'inventory_document',
      p_document_id,
      'Cancellation reversal: ' || p_reason,
      auth.uid(),
      now()
    );
  end loop;

  update public.inventory_documents
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancelled_by = auth.uid(),
    cancellation_reason = p_reason,
    reversal_journal_entry_id = v_reversal_je_id,
    cancellation_idempotency_key = p_idempotency_key,
    cancellation_idempotency_payload_hash = v_hash
  where id = p_document_id and tenant_id = v_tenant_id;

  return p_document_id;
end;
$$;

grant execute on function public.cancel_inventory_document(uuid, text, uuid) to authenticated;
