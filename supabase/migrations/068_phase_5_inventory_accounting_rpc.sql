-- Phase 5 M4.5: public inventory accounting RPCs and legacy wrapper.
-- Depends on 067_phase_5_inventory_accounting_helpers.sql.

-- ---------------------------------------------------------------------------
-- Payload normalization
-- ---------------------------------------------------------------------------
create or replace function public.normalize_inventory_financial_payload(
  p_data jsonb,
  p_allowed_keys text[],
  p_required_document_type text default null
)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_key text;
  v_line jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_norm jsonb := '{}'::jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if v_key = any (p_allowed_keys) then
      continue;
    end if;
    if v_key in ('counter_account_id', 'account_id', 'posting_account_id') then
      raise exception 'validation_failed';
    end if;
    raise exception 'validation_failed';
  end loop;

  if p_required_document_type is not null then
    if coalesce(p_data ->> 'document_type', '') <> p_required_document_type then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_data ? 'lines' then
    if jsonb_typeof(p_data -> 'lines') <> 'array' then
      raise exception 'validation_failed';
    end if;
    for v_line in select value from jsonb_array_elements(p_data -> 'lines') loop
      perform public.assert_inventory_line_no_client_accounts(v_line);
      v_lines := v_lines || jsonb_build_array(v_line);
    end loop;
    v_lines := (
      select coalesce(jsonb_agg(elem order by (elem ->> 'line_order')::int), '[]'::jsonb)
      from jsonb_array_elements(v_lines) as elem
    );
  end if;

  v_norm := jsonb_strip_nulls(jsonb_build_object(
    'warehouse_id', p_data ->> 'warehouse_id',
    'date', p_data ->> 'date',
    'notes', p_data ->> 'notes',
    'document_type', p_data ->> 'document_type',
    'reason_code', p_data ->> 'reason_code',
    'gain_reason_code', p_data ->> 'gain_reason_code',
    'loss_reason_code', p_data ->> 'loss_reason_code',
    'import_key', p_data ->> 'import_key',
    'lines', v_lines
  ));

  return v_norm;
end;
$$;

create or replace function public.compute_inventory_financial_payload_hash(p_data jsonb)
returns text
language sql
immutable
security definer
set search_path = public, extensions
as $$
  select encode(
    digest(convert_to(p_data::text, 'UTF8'), 'sha256'),
    'hex'
  );
$$;

-- ---------------------------------------------------------------------------
-- record_opening_stock
-- ---------------------------------------------------------------------------
create or replace function public.record_opening_stock(
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
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('inventory_documents.create_opening') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_inventory_financial_payload(
    p_data,
    array['warehouse_id', 'date', 'notes', 'import_key', 'lines']
  );
  v_hash := public.compute_inventory_financial_payload_hash(v_normalized);

  return public.confirm_inventory_document_internal(
    'opening_stock', v_normalized, p_idempotency_key, v_hash
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- record_inventory_document (stock_in | stock_out)
-- ---------------------------------------------------------------------------
create or replace function public.record_inventory_document(
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
  v_doc_type text;
  v_normalized jsonb;
  v_hash text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('inventory_documents.create_adjustment') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_doc_type := coalesce(p_data ->> 'document_type', '');
  if v_doc_type not in ('stock_in', 'stock_out') then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_inventory_financial_payload(
    p_data,
    array['document_type', 'warehouse_id', 'date', 'notes', 'reason_code', 'lines']
  );
  v_hash := public.compute_inventory_financial_payload_hash(v_normalized);

  return public.confirm_inventory_document_internal(
    v_doc_type::public.inventory_document_type,
    v_normalized,
    p_idempotency_key,
    v_hash
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- record_stock_count
-- ---------------------------------------------------------------------------
create or replace function public.record_stock_count(
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
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('inventory_documents.create_stock_count') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_inventory_financial_payload(
    p_data,
    array['warehouse_id', 'date', 'notes', 'gain_reason_code', 'loss_reason_code', 'lines']
  );
  v_hash := public.compute_inventory_financial_payload_hash(v_normalized);

  return public.confirm_inventory_document_internal(
    'stock_count', v_normalized, p_idempotency_key, v_hash
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- cancel_inventory_document (safe reversal only)
-- ---------------------------------------------------------------------------
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
  v_doc public.inventory_documents%rowtype;
  v_line public.inventory_document_lines%rowtype;
  v_reversal_je_id uuid;
  v_reversal_number text;
  v_jl record;
  v_line_order int := 0;
  v_latest_movement timestamptz;
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

  if nullif(btrim(p_reason), '') is null then
    raise exception 'validation_failed';
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

  select max(m.occurred_at) into v_latest_movement
  from public.inventory_movements m
  where m.reference_table = 'inventory_document'
    and m.reference_id = p_document_id
    and m.tenant_id = v_tenant_id;

  for v_line in
    select * from public.inventory_document_lines l
    where l.document_id = p_document_id and l.tenant_id = v_tenant_id
  loop
    if v_line.delta_qty = 0 then
      continue;
    end if;

    if exists (
      select 1
      from public.inventory_movements m
      where m.tenant_id = v_tenant_id
        and m.warehouse_id = v_doc.warehouse_id
        and m.product_id = v_line.product_id
        and m.occurred_at > coalesce(v_latest_movement, v_doc.confirmed_at)
    ) then
      raise exception 'correction_document_required';
    end if;
  end loop;

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  if v_doc.journal_entry_id is not null then
    v_reversal_number := public.next_document_number('JE');
    v_reversal_je_id := gen_random_uuid();

    perform public.allow_finance_write();

    insert into public.journal_entries (
      id, tenant_id, entry_number, date, source, source_id,
      description_en, is_posted, created_by
    )
    values (
      v_reversal_je_id, v_tenant_id, v_reversal_number, v_doc.document_date,
      'inventory_document_reversal', p_document_id,
      'Reversal ' || v_doc.document_number, false, auth.uid()
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
      case when v_line.delta_qty > 0 then 'adjustment_out' else 'adjustment_in' end,
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
    reversal_journal_entry_id = v_reversal_je_id
  where id = p_document_id and tenant_id = v_tenant_id;

  return p_document_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_inventory_adjustment_reasons
-- ---------------------------------------------------------------------------
create or replace function public.list_inventory_adjustment_reasons(
  p_direction text default null,
  p_document_type text default null
)
returns jsonb
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
    public.user_has_permission('inventory_documents.view')
    or public.user_has_permission('inventory_documents.create_adjustment')
    or public.user_has_permission('inventory_documents.create_stock_count')
  ) then
    raise exception 'permission_denied';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'code', r.code,
        'name_ar', r.name_ar,
        'name_en', r.name_en,
        'direction', r.direction::text,
        'requires_cost', r.requires_cost,
        'allows_wac_fallback', r.allows_wac_fallback,
        'allowed_document_types', to_jsonb(r.allowed_document_types)
      )
      order by r.code
    )
    from public.inventory_adjustment_reasons r
    where r.tenant_id = v_tenant_id
      and r.is_active = true
      and (p_direction is null or r.direction::text = p_direction)
      and (p_document_type is null or p_document_type = any (r.allowed_document_types))
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- list_inventory_documents
-- ---------------------------------------------------------------------------
create or replace function public.list_inventory_documents(
  p_document_type text default null,
  p_warehouse_id uuid default null,
  p_date_from date default null,
  p_date_to date default null,
  p_limit int default 50,
  p_offset int default 0
)
returns jsonb
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

  if not public.user_has_permission('inventory_documents.view') then
    raise exception 'permission_denied';
  end if;

  return coalesce((
    select jsonb_agg(row_data order by doc_date desc, doc_number desc)
    from (
      select jsonb_build_object(
        'id', d.id,
        'document_number', d.document_number,
        'document_type', d.document_type::text,
        'status', d.status::text,
        'date', d.document_date,
        'warehouse_id', d.warehouse_id,
        'warehouse_name_ar', w.name_ar,
        'warehouse_name_en', w.name_en,
        'journal_entry_id', d.journal_entry_id
      ) as row_data,
      d.document_date as doc_date,
      d.document_number as doc_number
      from public.inventory_documents d
      join public.warehouses w
        on w.id = d.warehouse_id and w.tenant_id = d.tenant_id
      where d.tenant_id = v_tenant_id
        and (p_document_type is null or d.document_type::text = p_document_type)
        and (p_warehouse_id is null or d.warehouse_id = p_warehouse_id)
        and (p_date_from is null or d.document_date >= p_date_from)
        and (p_date_to is null or d.document_date <= p_date_to)
      order by d.document_date desc, d.document_number desc
      limit greatest(coalesce(p_limit, 50), 1)
      offset greatest(coalesce(p_offset, 0), 0)
    ) sub
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- get_inventory_document_detail
-- ---------------------------------------------------------------------------
create or replace function public.get_inventory_document_detail(p_document_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_doc public.inventory_documents%rowtype;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('inventory_documents.view') then
    raise exception 'permission_denied';
  end if;

  select * into v_doc
  from public.inventory_documents d
  where d.id = p_document_id and d.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  return jsonb_build_object(
    'id', v_doc.id,
    'document_number', v_doc.document_number,
    'document_type', v_doc.document_type::text,
    'status', v_doc.status::text,
    'date', v_doc.document_date,
    'warehouse_id', v_doc.warehouse_id,
    'reason_code', v_doc.reason_code,
    'gain_reason_code', v_doc.gain_reason_code,
    'loss_reason_code', v_doc.loss_reason_code,
    'notes', v_doc.notes,
    'import_key', v_doc.import_key,
    'journal_entry_id', v_doc.journal_entry_id,
    'reversal_journal_entry_id', v_doc.reversal_journal_entry_id,
    'lines', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', l.id,
          'product_id', l.product_id,
          'system_qty', l.system_qty,
          'input_qty', l.input_qty,
          'delta_qty', l.delta_qty,
          'unit_cost_snapshot', l.unit_cost_snapshot,
          'total_value', l.total_value,
          'reason_code', l.reason_code,
          'product_unit_ids', l.product_unit_ids,
          'line_order', l.line_order
        )
        order by l.line_order
      )
      from public.inventory_document_lines l
      where l.document_id = p_document_id and l.tenant_id = v_tenant_id
    ), '[]'::jsonb),
    'movements', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'movement_type', m.movement_type::text,
          'product_id', m.product_id,
          'qty', m.qty,
          'unit_cost', m.unit_cost
        )
        order by m.occurred_at
      )
      from public.inventory_movements m
      where m.reference_table = 'inventory_document'
        and m.reference_id = p_document_id
        and m.tenant_id = v_tenant_id
    ), '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Legacy wrapper: record_inventory_adjustment
-- ---------------------------------------------------------------------------
create or replace function public.record_inventory_adjustment(
  p_warehouse_id uuid,
  p_product_id uuid,
  p_qty numeric,
  p_movement_type movement_type,
  p_unit_cost numeric default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_is_serialized boolean;
  v_document_id uuid;
  v_movement_id uuid;
  v_payload jsonb;
  v_reason text;
  v_doc_type text;
  v_normalized jsonb;
  v_hash text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_movement_type = 'adjustment_in' then
    if not public.user_has_permission('inventory_movements.create')
       or not public.user_has_full_product_cost_access() then
      raise exception 'permission_denied';
    end if;
  elsif p_movement_type = 'adjustment_out' then
    if not public.user_has_permission('inventory_movements.create') then
      raise exception 'permission_denied';
    end if;
  else
    raise exception 'validation_failed';
  end if;

  if p_qty is null or p_qty <= 0 then
    raise exception 'validation_failed';
  end if;

  if nullif(btrim(p_notes), '') is null then
    raise exception 'validation_failed';
  end if;

  select p.is_serialized into v_is_serialized
  from public.products p
  where p.id = p_product_id and p.tenant_id = v_tenant_id and p.is_active = true;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_is_serialized then
    raise exception 'serialized_adjustment_not_supported';
  end if;

  if p_movement_type = 'adjustment_in' then
    v_doc_type := 'stock_in';
    v_reason := 'found_surplus';
    if p_unit_cost is null or p_unit_cost < 0 then
      raise exception 'validation_failed';
    end if;
    v_payload := jsonb_build_object(
      'document_type', v_doc_type,
      'warehouse_id', p_warehouse_id,
      'date', current_date,
      'notes', p_notes,
      'reason_code', v_reason,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_product_id,
          'qty', p_qty,
          'unit_cost', p_unit_cost,
          'line_order', 1
        )
      )
    );
  else
    v_doc_type := 'stock_out';
    v_reason := 'shrinkage';
    v_payload := jsonb_build_object(
      'document_type', v_doc_type,
      'warehouse_id', p_warehouse_id,
      'date', current_date,
      'notes', p_notes,
      'reason_code', v_reason,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'product_id', p_product_id,
          'qty', p_qty,
          'line_order', 1
        )
      )
    );
  end if;

  v_normalized := public.normalize_inventory_financial_payload(
    v_payload,
    array['document_type', 'warehouse_id', 'date', 'notes', 'reason_code', 'lines']
  );
  v_hash := public.compute_inventory_financial_payload_hash(v_normalized);

  v_document_id := public.confirm_inventory_document_internal(
    v_doc_type::public.inventory_document_type,
    v_normalized,
    gen_random_uuid(),
    v_hash
  );

  select m.id into v_movement_id
  from public.inventory_movements m
  where m.tenant_id = v_tenant_id
    and m.reference_table = 'inventory_document'
    and m.reference_id = v_document_id
    and m.product_id = p_product_id
  order by m.created_at
  limit 1;

  if v_movement_id is null then
    raise exception 'validation_failed';
  end if;

  return v_movement_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
grant execute on function public.record_opening_stock(jsonb, uuid) to authenticated;
grant execute on function public.record_inventory_document(jsonb, uuid) to authenticated;
grant execute on function public.record_stock_count(jsonb, uuid) to authenticated;
grant execute on function public.cancel_inventory_document(uuid, text, uuid) to authenticated;
grant execute on function public.list_inventory_adjustment_reasons(text, text) to authenticated;
grant execute on function public.list_inventory_documents(text, uuid, date, date, int, int) to authenticated;
grant execute on function public.get_inventory_document_detail(uuid) to authenticated;

revoke all on function public.normalize_inventory_financial_payload(jsonb, text[], text) from public, anon, authenticated;
revoke all on function public.compute_inventory_financial_payload_hash(jsonb) from public, anon, authenticated;

grant execute on function public.record_inventory_adjustment(
  uuid, uuid, numeric, movement_type, numeric, text
) to authenticated;
