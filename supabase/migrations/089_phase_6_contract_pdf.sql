-- Phase 6 M11: contract PDF template, snapshot unit on lines, detail read enrichment.

-- ---------------------------------------------------------------------------
-- Section A: snapshot_unit_primary on contract_lines
-- ---------------------------------------------------------------------------
alter table public.contract_lines
  add column if not exists snapshot_unit_primary public.unit_of_measure;

update public.contract_lines cl
set snapshot_unit_primary = p.unit_primary
from public.products p
where p.id = cl.product_id
  and p.tenant_id = cl.tenant_id
  and cl.snapshot_unit_primary is null;

alter table public.contract_lines
  alter column snapshot_unit_primary set not null;

create or replace function public.trg_contract_lines_snapshot_unit_primary()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.snapshot_unit_primary is null then
    select p.unit_primary
    into new.snapshot_unit_primary
    from public.products p
    where p.id = new.product_id
      and p.tenant_id = new.tenant_id;

    if new.snapshot_unit_primary is null then
      raise exception 'validation_failed';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_contract_lines_snapshot_unit_primary on public.contract_lines;
create trigger trg_contract_lines_snapshot_unit_primary
  before insert on public.contract_lines
  for each row execute function public.trg_contract_lines_snapshot_unit_primary();

-- ---------------------------------------------------------------------------
-- Section B: copy trial lines preserve snapshot_unit_primary
-- ---------------------------------------------------------------------------
create or replace function public.copy_trial_lines_to_rental_internal(
  p_tenant_id uuid,
  p_trial_id uuid,
  p_rental_id uuid,
  p_rental_start date,
  p_pricing jsonb,
  p_asset_count int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_line record;
  v_line_id uuid;
  v_pricing_assets jsonb := coalesce(p_pricing -> 'asset_lines', '[]'::jsonb);
  v_pricing_consumables jsonb := coalesce(p_pricing -> 'consumable_lines', '[]'::jsonb);
  v_asset_idx int := 0;
  v_consumable_idx int := 0;
  v_pricing_line jsonb;
  v_source_cost numeric(15, 3);
  v_line_monthly_cost numeric(15, 3);
  v_snapshot_refill_cost numeric(15, 3);
begin
  for v_line in
    select *
    from public.contract_lines cl
    where cl.tenant_id = p_tenant_id
      and cl.contract_id = p_trial_id
      and cl.line_type = 'asset'::public.contract_line_type
    order by cl.line_order
  loop
    v_asset_idx := v_asset_idx + 1;
    v_pricing_line := v_pricing_assets -> (v_asset_idx - 1);
    if v_pricing_line is null then
      raise exception 'validation_failed';
    end if;

    v_source_cost := (v_pricing_line ->> 'source_unit_cost')::numeric(15, 3);
    v_line_monthly_cost := (v_pricing_line ->> 'monthly_cost')::numeric(15, 3);

    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id, product_unit_id,
      source_warehouse_id, snapshot_unit_primary,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, p_tenant_id, p_rental_id, 'asset'::public.contract_line_type,
      v_line.product_id, v_line.product_unit_id,
      v_line.source_warehouse_id, v_line.snapshot_unit_primary,
      v_source_cost, v_line_monthly_cost,
      (v_pricing_line ->> 'cost_basis')::public.contract_line_cost_basis,
      v_line.line_order
    );
  end loop;

  for v_line in
    select *
    from public.contract_lines cl
    where cl.tenant_id = p_tenant_id
      and cl.contract_id = p_trial_id
      and cl.line_type = 'consumable'::public.contract_line_type
    order by cl.line_order
  loop
    v_consumable_idx := v_consumable_idx + 1;
    v_pricing_line := v_pricing_consumables -> (v_consumable_idx - 1);
    if v_pricing_line is null then
      raise exception 'validation_failed';
    end if;

    v_source_cost := (v_pricing_line ->> 'source_unit_cost')::numeric(15, 3);
    v_line_monthly_cost := (v_pricing_line ->> 'monthly_cost')::numeric(15, 3);
    v_snapshot_refill_cost := public.round_money(
      v_line.qty_per_refill * v_source_cost,
      public.resolve_tenant_money_precision(p_tenant_id)
    );

    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id,
      qty_per_refill, refill_frequency_months, snapshot_unit_primary,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, p_tenant_id, p_rental_id, 'consumable'::public.contract_line_type,
      v_line.product_id, v_line.qty_per_refill, v_line.refill_frequency_months,
      v_line.snapshot_unit_primary,
      v_source_cost, v_line_monthly_cost,
      (v_pricing_line ->> 'cost_basis')::public.contract_line_cost_basis,
      p_asset_count + v_consumable_idx
    );

    insert into public.contract_oil_changes (
      tenant_id, contract_id, contract_line_id,
      effective_from, effective_to,
      oil_product_id, qty_per_refill,
      snapshot_unit_cost, snapshot_refill_cost
    )
    values (
      p_tenant_id, p_rental_id, v_line_id,
      p_rental_start, null,
      v_line.product_id, v_line.qty_per_refill,
      v_source_cost, v_snapshot_refill_cost
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section C: contract detail JSON + mask (M11 enrichment)
-- ---------------------------------------------------------------------------
create or replace function public.build_contract_detail_json(p_contract_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_contract public.contracts%rowtype;
  v_customer public.customers%rowtype;
  v_location_name text;
  v_asset_lines jsonb;
  v_consumable_lines jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  select * into v_contract
  from public.contracts c
  where c.id = p_contract_id
    and c.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  select * into v_customer
  from public.customers cu
  where cu.id = v_contract.customer_id
    and cu.tenant_id = v_tenant_id;

  select coalesce(nullif(btrim(csl.name), ''), nullif(btrim(v_contract.location_name), ''))
  into v_location_name
  from public.customer_service_locations csl
  where csl.id = v_contract.service_location_id
    and csl.tenant_id = v_tenant_id
  limit 1;

  if v_location_name is null then
    v_location_name := nullif(btrim(v_contract.location_name), '');
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cl.id,
      'product_id', cl.product_id,
      'product_unit_id', cl.product_unit_id,
      'line_order', cl.line_order,
      'snapshot_unit_primary', cl.snapshot_unit_primary,
      'snapshot_unit_cost', cl.snapshot_unit_cost,
      'snapshot_monthly_cost', cl.snapshot_monthly_cost,
      'serial_number', pu.serial_number,
      'product_sku', p.sku,
      'product_name_ar', p.name_ar,
      'product_name_en', p.name_en,
      'product_group_name_ar', pg.name_ar,
      'product_group_name_en', pg.name_en
    )
    order by cl.line_order, cl.id
  ), '[]'::jsonb)
  into v_asset_lines
  from public.contract_lines cl
  join public.products p
    on p.id = cl.product_id
    and p.tenant_id = cl.tenant_id
  join public.product_groups pg
    on pg.id = p.group_id
    and pg.tenant_id = p.tenant_id
  left join public.product_units pu
    on pu.id = cl.product_unit_id
    and pu.tenant_id = cl.tenant_id
  where cl.contract_id = p_contract_id
    and cl.tenant_id = v_tenant_id
    and cl.line_type = 'asset';

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cl.id,
      'product_id', cl.product_id,
      'line_order', cl.line_order,
      'qty_per_refill', cl.qty_per_refill,
      'refill_frequency_months', cl.refill_frequency_months,
      'snapshot_unit_primary', cl.snapshot_unit_primary,
      'snapshot_unit_cost', cl.snapshot_unit_cost,
      'snapshot_monthly_cost', cl.snapshot_monthly_cost,
      'product_sku', p.sku,
      'product_name_ar', p.name_ar,
      'product_name_en', p.name_en,
      'product_group_name_ar', pg.name_ar,
      'product_group_name_en', pg.name_en,
      'current_oil_product_id', cur.oil_product_id,
      'current_oil_product_name_ar', cur.product_name_ar,
      'current_oil_product_name_en', cur.product_name_en,
      'current_qty_per_refill', cur.qty_per_refill,
      'current_effective_from', cur.effective_from,
      'scheduled_oil_product_id', sch.oil_product_id,
      'scheduled_oil_product_name_ar', sch.product_name_ar,
      'scheduled_oil_product_name_en', sch.product_name_en,
      'scheduled_qty_per_refill', sch.qty_per_refill,
      'scheduled_effective_from', sch.effective_from
    )
    order by cl.line_order, cl.id
  ), '[]'::jsonb)
  into v_consumable_lines
  from public.contract_lines cl
  join public.products p
    on p.id = cl.product_id
    and p.tenant_id = cl.tenant_id
  join public.product_groups pg
    on pg.id = p.group_id
    and pg.tenant_id = p.tenant_id
  left join lateral (
    select coc.oil_product_id, coc.qty_per_refill, coc.effective_from,
      op.name_ar as product_name_ar, op.name_en as product_name_en
    from public.contract_oil_changes coc
    join public.products op on op.id = coc.oil_product_id and op.tenant_id = coc.tenant_id
    where coc.tenant_id = cl.tenant_id
      and coc.contract_line_id = cl.id
      and coc.effective_from <= current_date
      and (coc.effective_to is null or coc.effective_to >= current_date)
    order by coc.effective_from desc, coc.created_at desc, coc.id desc
    limit 1
  ) cur on true
  left join lateral (
    select coc.oil_product_id, coc.qty_per_refill, coc.effective_from,
      op.name_ar as product_name_ar, op.name_en as product_name_en
    from public.contract_oil_changes coc
    join public.products op on op.id = coc.oil_product_id and op.tenant_id = coc.tenant_id
    where coc.tenant_id = cl.tenant_id
      and coc.contract_line_id = cl.id
      and coc.effective_from > current_date
    order by coc.effective_from asc, coc.created_at asc, coc.id asc
    limit 1
  ) sch on true
  where cl.contract_id = p_contract_id
    and cl.tenant_id = v_tenant_id
    and cl.line_type = 'consumable';

  return jsonb_build_object(
    'id', v_contract.id,
    'contract_number', v_contract.contract_number,
    'type', v_contract.type,
    'status', v_contract.status,
    'customer_id', v_contract.customer_id,
    'customer_name_ar', v_customer.name_ar,
    'customer_name_en', v_customer.name_en,
    'contact_person_name', v_contract.contact_person_name,
    'contact_phone', v_contract.contact_phone,
    'contact_email', v_contract.contact_email,
    'service_location_id', v_contract.service_location_id,
    'service_location_name', v_location_name,
    'location_governorate', v_contract.location_governorate,
    'location_area', v_contract.location_area,
    'signature_url', v_contract.signature_url,
    'start_date', v_contract.start_date,
    'end_date', v_contract.end_date,
    'trial_days', v_contract.trial_days,
    'trial_end_date', v_contract.trial_end_date,
    'trial_outcome', v_contract.trial_outcome,
    'billing_day', v_contract.billing_day,
    'refill_day', v_contract.refill_day,
    'monthly_rental_value', v_contract.monthly_rental_value,
    'total_contract_value', v_contract.total_contract_value,
    'snapshot_device_monthly_cost', v_contract.snapshot_device_monthly_cost,
    'snapshot_oil_monthly_cost', v_contract.snapshot_oil_monthly_cost,
    'snapshot_total_monthly_cost', v_contract.snapshot_total_monthly_cost,
    'snapshot_monthly_profit', v_contract.snapshot_monthly_profit,
    'snapshot_min_profit_threshold', v_contract.snapshot_min_profit_threshold,
    'snapshot_asset_cost_basis', v_contract.snapshot_asset_cost_basis,
    'snapshot_consumable_cost_basis', v_contract.snapshot_consumable_cost_basis,
    'snapshot_asset_lifespan_months', v_contract.snapshot_asset_lifespan_months,
    'min_profit_overridden', v_contract.min_profit_overridden,
    'override_reason', v_contract.override_reason,
    'converted_from_contract_id', v_contract.converted_from_contract_id,
    'converted_to_contract_id', v_contract.converted_to_contract_id,
    'renewed_from_contract_id', v_contract.renewed_from_contract_id,
    'renewed_to_contract_id', v_contract.renewed_to_contract_id,
    'extension_reason', v_contract.extension_reason,
    'returned_at', v_contract.returned_at,
    'returned_by', v_contract.returned_by,
    'return_reason', v_contract.return_reason,
    'return_condition', v_contract.return_condition,
    'closed_at', v_contract.closed_at,
    'closed_by', v_contract.closed_by,
    'closure_reason', v_contract.closure_reason,
    'notes', v_contract.notes,
    'asset_lines', v_asset_lines,
    'consumable_lines', v_consumable_lines
  );
end;
$$;

create or replace function public.mask_contract_read_json(p_json jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_has_device boolean;
  v_has_oil boolean;
  v_has_total boolean;
  v_has_profit boolean;
  v_has_print boolean;
  v_asset_lines jsonb := '[]'::jsonb;
  v_consumable_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_masked_line jsonb;
begin
  v_has_device := public.user_has_permission('contracts.field.snapshot_device_cost');
  v_has_oil := public.user_has_permission('contracts.field.snapshot_oil_cost');
  v_has_total := public.user_has_permission('contracts.field.snapshot_total_cost');
  v_has_profit := public.user_has_permission('contracts.field.snapshot_profit');
  v_has_print := public.user_has_permission('contracts.print');

  for v_line in
    select value
    from jsonb_array_elements(coalesce(p_json -> 'asset_lines', '[]'::jsonb))
  loop
    v_masked_line := jsonb_build_object(
      'id', v_line -> 'id',
      'product_id', v_line -> 'product_id',
      'product_unit_id', v_line -> 'product_unit_id',
      'line_order', v_line -> 'line_order',
      'snapshot_unit_primary', v_line -> 'snapshot_unit_primary',
      'serial_number', v_line -> 'serial_number',
      'product_sku', v_line -> 'product_sku',
      'product_name_ar', v_line -> 'product_name_ar',
      'product_name_en', v_line -> 'product_name_en',
      'product_group_name_ar', v_line -> 'product_group_name_ar',
      'product_group_name_en', v_line -> 'product_group_name_en'
    );

    if v_has_device then
      v_masked_line := v_masked_line || jsonb_build_object(
        'snapshot_unit_cost', v_line -> 'snapshot_unit_cost',
        'snapshot_monthly_cost', v_line -> 'snapshot_monthly_cost'
      );
    end if;

    v_asset_lines := v_asset_lines || jsonb_build_array(v_masked_line);
  end loop;

  for v_line in
    select value
    from jsonb_array_elements(coalesce(p_json -> 'consumable_lines', '[]'::jsonb))
  loop
    v_masked_line := jsonb_build_object(
      'id', v_line -> 'id',
      'product_id', v_line -> 'product_id',
      'line_order', v_line -> 'line_order',
      'qty_per_refill', v_line -> 'qty_per_refill',
      'refill_frequency_months', v_line -> 'refill_frequency_months',
      'snapshot_unit_primary', v_line -> 'snapshot_unit_primary',
      'product_sku', v_line -> 'product_sku',
      'product_name_ar', v_line -> 'product_name_ar',
      'product_name_en', v_line -> 'product_name_en',
      'product_group_name_ar', v_line -> 'product_group_name_ar',
      'product_group_name_en', v_line -> 'product_group_name_en',
      'current_oil_product_id', v_line -> 'current_oil_product_id',
      'current_oil_product_name_ar', v_line -> 'current_oil_product_name_ar',
      'current_oil_product_name_en', v_line -> 'current_oil_product_name_en',
      'current_qty_per_refill', v_line -> 'current_qty_per_refill',
      'current_effective_from', v_line -> 'current_effective_from',
      'scheduled_oil_product_id', v_line -> 'scheduled_oil_product_id',
      'scheduled_oil_product_name_ar', v_line -> 'scheduled_oil_product_name_ar',
      'scheduled_oil_product_name_en', v_line -> 'scheduled_oil_product_name_en',
      'scheduled_qty_per_refill', v_line -> 'scheduled_qty_per_refill',
      'scheduled_effective_from', v_line -> 'scheduled_effective_from'
    );

    if v_has_oil then
      v_masked_line := v_masked_line || jsonb_build_object(
        'snapshot_unit_cost', v_line -> 'snapshot_unit_cost',
        'snapshot_monthly_cost', v_line -> 'snapshot_monthly_cost'
      );
    end if;

    v_consumable_lines := v_consumable_lines || jsonb_build_array(v_masked_line);
  end loop;

  return jsonb_strip_nulls(
    jsonb_build_object(
      'id', p_json -> 'id',
      'contract_number', p_json -> 'contract_number',
      'type', p_json -> 'type',
      'status', p_json -> 'status',
      'customer_id', p_json -> 'customer_id',
      'customer_name_ar', p_json -> 'customer_name_ar',
      'customer_name_en', p_json -> 'customer_name_en',
      'contact_person_name', p_json -> 'contact_person_name',
      'contact_phone', p_json -> 'contact_phone',
      'contact_email', p_json -> 'contact_email',
      'service_location_id', p_json -> 'service_location_id',
      'service_location_name', p_json -> 'service_location_name',
      'location_governorate', p_json -> 'location_governorate',
      'location_area', p_json -> 'location_area',
      'signature_url', case when v_has_print then p_json -> 'signature_url' end,
      'start_date', p_json -> 'start_date',
      'end_date', p_json -> 'end_date',
      'trial_days', p_json -> 'trial_days',
      'trial_end_date', p_json -> 'trial_end_date',
      'trial_outcome', p_json -> 'trial_outcome',
      'billing_day', p_json -> 'billing_day',
      'refill_day', p_json -> 'refill_day',
      'monthly_rental_value', p_json -> 'monthly_rental_value',
      'total_contract_value', p_json -> 'total_contract_value',
      'min_profit_overridden', p_json -> 'min_profit_overridden',
      'override_reason', p_json -> 'override_reason',
      'converted_from_contract_id', p_json -> 'converted_from_contract_id',
      'converted_to_contract_id', p_json -> 'converted_to_contract_id',
      'renewed_from_contract_id', p_json -> 'renewed_from_contract_id',
      'renewed_to_contract_id', p_json -> 'renewed_to_contract_id',
      'extension_reason', p_json -> 'extension_reason',
      'returned_at', p_json -> 'returned_at',
      'returned_by', p_json -> 'returned_by',
      'return_reason', p_json -> 'return_reason',
      'return_condition', p_json -> 'return_condition',
      'closed_at', p_json -> 'closed_at',
      'closed_by', p_json -> 'closed_by',
      'closure_reason', p_json -> 'closure_reason',
      'notes', p_json -> 'notes',
      'snapshot_device_monthly_cost',
        case when v_has_device then p_json -> 'snapshot_device_monthly_cost' end,
      'snapshot_oil_monthly_cost',
        case when v_has_oil then p_json -> 'snapshot_oil_monthly_cost' end,
      'snapshot_total_monthly_cost',
        case when v_has_total then p_json -> 'snapshot_total_monthly_cost' end,
      'snapshot_monthly_profit',
        case when v_has_profit then p_json -> 'snapshot_monthly_profit' end,
      'snapshot_min_profit_threshold',
        case when v_has_profit then p_json -> 'snapshot_min_profit_threshold' end,
      'snapshot_asset_cost_basis',
        case when v_has_profit then p_json -> 'snapshot_asset_cost_basis' end,
      'snapshot_consumable_cost_basis',
        case when v_has_profit then p_json -> 'snapshot_consumable_cost_basis' end,
      'snapshot_asset_lifespan_months',
        case when v_has_profit then p_json -> 'snapshot_asset_lifespan_months' end,
      'asset_lines', v_asset_lines,
      'consumable_lines', v_consumable_lines
    )
  );
end;
$$;

comment on function public.build_contract_detail_json(uuid) is
  'Phase 6 M11: contract detail includes contact/location snapshots and line snapshot_unit_primary.';

comment on function public.mask_contract_read_json(jsonb) is
  'Phase 6 M11: signature_url only for contracts.print; snapshot_unit_primary always passed.';

-- ---------------------------------------------------------------------------
-- Section D: document template support for contract_a4
-- ---------------------------------------------------------------------------
alter table public.document_templates
  drop constraint if exists chk_document_templates_type;

alter table public.document_templates
  add constraint chk_document_templates_type check (
    document_type in (
      'sales_invoice', 'purchase_invoice', 'receipt_voucher',
      'payment_voucher', 'customer_statement', 'asset_tag_label', 'contract'
    )
  );

create or replace function public.m3_allowed_block_types(
  p_document_type text,
  p_paper_kind text
)
returns text[]
language sql
immutable
set search_path = public
as $$
  select case
    when p_document_type in ('sales_invoice', 'purchase_invoice') and p_paper_kind = 'a4' then
      array[
        'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then
      array[
        'tenant_header', 'document_meta', 'party_details', 'payment_details',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'receipt_voucher' and p_paper_kind = 'thermal_80mm' then
      array[
        'tenant_header', 'document_meta', 'payment_details',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'customer_statement' and p_paper_kind = 'a4' then
      array[
        'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'contract' and p_paper_kind = 'a4' then
      array[
        'tenant_header', 'document_meta', 'party_details', 'contract_terms',
        'line_table', 'contract_totals', 'notes', 'signature', 'footer',
        'spacer', 'divider'
      ]
    when p_document_type = 'asset_tag_label' and p_paper_kind = 'label_sheet' then
      array['tenant_header', 'asset_identity', 'qr_code', 'spacer', 'divider']
    else array[]::text[]
  end;
$$;

create or replace function public.m3_required_party_role(
  p_document_type text,
  p_paper_kind text
)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_document_type = 'sales_invoice' then 'customer'
    when p_document_type = 'purchase_invoice' then 'supplier'
    when p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then 'customer'
    when p_document_type = 'customer_statement' then 'customer'
    when p_document_type = 'contract' and p_paper_kind = 'a4' then 'customer'
    else null
  end;
$$;

create or replace function public.m3_block_field_allowlist(
  p_document_type text,
  p_paper_kind text,
  p_block_type text
)
returns text[]
language sql
immutable
set search_path = public
as $$
  select case
    when p_block_type = 'document_meta' and p_document_type in ('sales_invoice', 'purchase_invoice') then
      array['document.number', 'document.date', 'document.due_date']
    when p_block_type = 'document_meta' and p_document_type = 'receipt_voucher' then
      array['document.number', 'document.date']
    when p_block_type = 'document_meta' and p_document_type = 'customer_statement' then
      array['document.from_date', 'document.to_date', 'document.generated_at']
    when p_block_type = 'document_meta' and p_document_type = 'contract' and p_paper_kind = 'a4' then
      array[
        'document.number', 'document.type', 'document.status', 'document.printed_at'
      ]
    when p_block_type = 'party_details'
      and p_document_type in ('sales_invoice', 'purchase_invoice', 'customer_statement') then
      array['party.name_ar', 'party.name_en', 'party.code']
    when p_block_type = 'party_details'
      and p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then
      array['party.name_ar', 'party.name_en']
    when p_block_type = 'party_details'
      and p_document_type = 'contract' and p_paper_kind = 'a4' then
      array[
        'party.name_ar', 'party.name_en', 'party.contact_person',
        'party.phone', 'party.email', 'location.name', 'location.governorate', 'location.area'
      ]
    when p_block_type = 'contract_terms'
      and p_document_type = 'contract' and p_paper_kind = 'a4' then
      array[
        'document.start_date', 'document.end_date', 'document.trial_days',
        'document.trial_end_date', 'document.duration_months',
        'document.billing_day', 'document.refill_day'
      ]
    when p_block_type = 'line_table' and p_document_type in ('sales_invoice', 'purchase_invoice') then
      array['line.description', 'line.qty', 'line.unit_price', 'line.total']
    when p_block_type = 'line_table' and p_document_type = 'customer_statement' then
      array['line.date', 'line.description', 'line.debit', 'line.credit', 'line.balance']
    when p_block_type = 'line_table' and p_document_type = 'contract' and p_paper_kind = 'a4' then
      array['line.product_name', 'line.serial', 'line.qty', 'line.unit']
    when p_block_type = 'totals' and p_document_type in ('sales_invoice', 'purchase_invoice') then
      array['totals.subtotal', 'totals.discount', 'totals.tax', 'totals.total']
    when p_block_type = 'totals' and p_document_type = 'customer_statement' then
      array[
        'summary.opening_balance', 'summary.total_debit',
        'summary.total_credit', 'summary.closing_balance'
      ]
    when p_block_type = 'contract_totals'
      and p_document_type = 'contract' and p_paper_kind = 'a4' then
      array['totals.monthly_rental', 'totals.total_value', 'totals.is_trial']
    when p_block_type = 'payment_details'
      and p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then
      array['payment.amount', 'payment.method', 'payment.reference', 'payment.collected_by']
    when p_block_type = 'payment_details'
      and p_document_type = 'receipt_voucher' and p_paper_kind = 'thermal_80mm' then
      array['payment.amount', 'payment.method', 'payment.reference']
    when p_block_type = 'notes' then
      array['document.notes']
    when p_block_type = 'asset_identity' and p_document_type = 'asset_tag_label' then
      array['tenant.company_name_ar', 'product.name_ar', 'product.name_en', 'unit.serial']
    else array[]::text[]
  end;
$$;

-- Patch m3_default_template_body to add contract_a4
do $$
declare
  v_sql text;
  v_contract_case text := $body$
    when 'contract_a4' then jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr'),
      jsonb_build_object('type', 'document_meta', 'id', 'meta', 'fields', jsonb_build_array(
        'document.number', 'document.type', 'document.status', 'document.printed_at'
      )),
      jsonb_build_object('type', 'party_details', 'id', 'party', 'party_role', 'customer', 'fields', jsonb_build_array(
        'party.name_ar', 'party.name_en', 'party.contact_person',
        'party.phone', 'party.email', 'location.name', 'location.governorate', 'location.area'
      )),
      jsonb_build_object('type', 'contract_terms', 'id', 'terms', 'fields', jsonb_build_array(
        'document.start_date', 'document.end_date', 'document.trial_days',
        'document.trial_end_date', 'document.duration_months',
        'document.billing_day', 'document.refill_day'
      )),
      jsonb_build_object('type', 'line_table', 'id', 'lines', 'columns', jsonb_build_array(
        jsonb_build_object(
          'field', 'line.product_name', 'label_key', 'col.product',
          'label_ar', 'المنتج', 'label_en', 'Product', 'width_pct', 40, 'align', 'start'
        ),
        jsonb_build_object(
          'field', 'line.serial', 'label_key', 'col.serial',
          'label_ar', 'التسلسلي', 'label_en', 'Serial', 'width_pct', 20, 'align', 'start'
        ),
        jsonb_build_object(
          'field', 'line.qty', 'label_key', 'col.qty',
          'label_ar', 'الكمية', 'label_en', 'Qty', 'width_pct', 15, 'align', 'end'
        ),
        jsonb_build_object(
          'field', 'line.unit', 'label_key', 'col.unit',
          'label_ar', 'الوحدة', 'label_en', 'Unit', 'width_pct', 25, 'align', 'end'
        )
      ), 'fields', jsonb_build_array(
        'line.product_name', 'line.serial', 'line.qty', 'line.unit'
      )),
      jsonb_build_object('type', 'contract_totals', 'id', 'totals', 'fields', jsonb_build_array(
        'totals.monthly_rental', 'totals.total_value', 'totals.is_trial'
      )),
      jsonb_build_object('type', 'notes', 'id', 'nts', 'fields', jsonb_build_array('document.notes')),
      jsonb_build_object('type', 'signature', 'id', 'sig'),
      jsonb_build_object('type', 'footer', 'id', 'ftr', 'source', 'tenant_footer')
    )
$body$;
begin
  select pg_get_functiondef('public.m3_default_template_body(text)'::regprocedure)
  into v_sql;

  if v_sql not like '%contract_a4%' then
    v_sql := replace(
      v_sql,
      $marker$    when 'asset_tag_label' then jsonb_build_array($marker$,
      v_contract_case || $marker$
    when 'asset_tag_label' then jsonb_build_array($marker$
    );
    execute v_sql;
  end if;
end $$;

-- Patch validate_document_template_body for contract blocks (before template inserts).
do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.validate_document_template_body(text, jsonb, text, integer)'::regprocedure
  )
  into v_sql;

  if v_sql not like '%contract_terms%' then
    v_sql := replace(
      v_sql,
      $s$'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals',
    'payment_details', 'notes', 'footer', 'asset_identity', 'qr_code'$s$,
      $s$'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals',
    'payment_details', 'notes', 'footer', 'asset_identity', 'qr_code',
    'contract_terms', 'contract_totals', 'signature'$s$
    );

    v_sql := replace(
      v_sql,
      $k$      when 'qr_code' then array['type', 'id', 'payload_field', 'caption_field']
      else array[]::text[]
    end;$k$,
      $k$      when 'qr_code' then array['type', 'id', 'payload_field', 'caption_field']
      when 'contract_terms' then array['type', 'id', 'fields']
      when 'contract_totals' then array['type', 'id', 'fields']
      when 'signature' then array['type', 'id']
      else array[]::text[]
    end;$k$
    );

    v_sql := replace(
      v_sql,
      $f$if v_type in ('document_meta', 'party_details', 'totals', 'payment_details', 'asset_identity') then$f$,
      $f$if v_type in (
        'document_meta', 'party_details', 'totals', 'payment_details', 'asset_identity',
        'contract_terms', 'contract_totals'
      ) then$f$
    );

    v_sql := replace(
      v_sql,
      $lt$        for v_field in select value::text from jsonb_array_elements_text(v_block -> 'fields') loop
          if not v_field = any (v_col_fields) then
            raise exception 'invalid_document_template: line_table field not in columns';
          end if;
        end loop;
      end if;
    end if;$lt$,
      $lt$        for v_field in select value::text from jsonb_array_elements_text(v_block -> 'fields') loop
          if not v_field = any (v_col_fields) then
            raise exception 'invalid_document_template: line_table field not in columns';
          end if;
        end loop;
      end if;

      v_allowlist := public.m3_block_field_allowlist(p_document_type, p_paper_kind, v_type);
      if cardinality(v_allowlist) > 0 then
        foreach v_field in array v_col_fields loop
          if not v_field = any (v_allowlist) then
            raise exception 'invalid_document_template: field % not allowed in line_table', v_field;
          end if;
        end loop;
      end if;
    end if;$lt$
    );

    execute v_sql;
  end if;
end $$;

create or replace function public.initialize_tenant_document_templates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tenant_document_settings (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;

  insert into public.document_templates (
    tenant_id, template_key, document_type, name_ar, name_en,
    language_mode, paper_kind, schema_version, body_json, is_default, is_active
  )
  values
    (new.id, 'sales_invoice_a4', 'sales_invoice', 'فاتورة مبيعات A4', 'Sales Invoice A4', 'bilingual', 'a4', 1, public.m3_default_template_body('sales_invoice_a4'), true, true),
    (new.id, 'purchase_invoice_a4', 'purchase_invoice', 'فاتورة مشتريات A4', 'Purchase Invoice A4', 'bilingual', 'a4', 1, public.m3_default_template_body('purchase_invoice_a4'), true, true),
    (new.id, 'receipt_voucher_a4', 'receipt_voucher', 'سند قبض A4', 'Receipt Voucher A4', 'bilingual', 'a4', 1, public.m3_default_template_body('receipt_voucher_a4'), true, true),
    (new.id, 'receipt_voucher_80mm', 'receipt_voucher', 'سند قبض 80mm', 'Receipt Voucher 80mm', 'bilingual', 'thermal_80mm', 1, public.m3_default_template_body('receipt_voucher_80mm'), true, true),
    (new.id, 'customer_statement_a4', 'customer_statement', 'كشف حساب A4', 'Customer Statement A4', 'bilingual', 'a4', 1, public.m3_default_template_body('customer_statement_a4'), true, true),
    (new.id, 'contract_a4', 'contract', 'عقد A4', 'Contract A4', 'bilingual', 'a4', 1, public.m3_default_template_body('contract_a4'), true, true),
    (new.id, 'asset_tag_label', 'asset_tag_label', 'ملصق أصل', 'Asset Tag Label', 'bilingual', 'label_sheet', 1, public.m3_default_template_body('asset_tag_label'), true, true)
  on conflict (tenant_id, template_key) do nothing;

  return new;
end;
$$;

insert into public.document_templates (
  tenant_id, template_key, document_type, name_ar, name_en,
  language_mode, paper_kind, schema_version, body_json, is_default, is_active
)
select
  t.id,
  'contract_a4',
  'contract',
  'عقد A4',
  'Contract A4',
  'bilingual',
  'a4',
  1,
  public.m3_default_template_body('contract_a4'),
  true,
  true
from public.tenants t
on conflict (tenant_id, template_key) do nothing;
