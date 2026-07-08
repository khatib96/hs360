-- Phase 6 M3: trial and rental contract creation RPCs.
-- Atomic contract + lines + oil changes + inventory/unit updates + idempotency.
-- No rental invoices or journal entries (deferred to M5).

-- ---------------------------------------------------------------------------
-- Section A: enum + document sequences + contracts idempotency + audit
-- ---------------------------------------------------------------------------
alter type public.movement_type add value if not exists 'trial_out';

create or replace function public.initialize_tenant_document_sequences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
  values
    (new.id, 'SI', 'SI', 1, 6),
    (new.id, 'PI', 'PI', 1, 6),
    (new.id, 'SR', 'SR', 1, 6),
    (new.id, 'PR', 'PR', 1, 6),
    (new.id, 'RV', 'RV', 1, 6),
    (new.id, 'PV', 'PV', 1, 6),
    (new.id, 'JE', 'JE', 1, 6),
    (new.id, 'SKU', 'SKU', 1, 6),
    (new.id, 'OS', 'OS', 1, 6),
    (new.id, 'STI', 'STI', 1, 6),
    (new.id, 'STO', 'STO', 1, 6),
    (new.id, 'SC', 'SC', 1, 6),
    (new.id, 'CON', 'CON', 1, 6)
  on conflict (tenant_id, sequence_key) do nothing;
  return new;
end;
$$;

insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
select t.id, v.sequence_key, v.prefix, 1, 6
from public.tenants t
cross join (
  values ('CON', 'CON')
) as v(sequence_key, prefix)
on conflict (tenant_id, sequence_key) do nothing;

alter table public.contracts
  add column if not exists idempotency_key uuid,
  add column if not exists idempotency_payload_hash text;

create unique index if not exists ux_contracts_tenant_idempotency_key
  on public.contracts (tenant_id, idempotency_key)
  where idempotency_key is not null;

create or replace function public.resolve_finance_idempotency(
  p_table regclass,
  p_idempotency_key uuid,
  p_payload_hash text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_existing_id uuid;
  v_existing_hash text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_idempotency_key is null then
    return null;
  end if;

  if p_table = 'public.invoices'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.invoices
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.vouchers'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.vouchers
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.journal_entries'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.journal_entries
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.invoice_credit_allocations'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.invoice_credit_allocations
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.inventory_documents'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.inventory_documents
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  elsif p_table = 'public.contracts'::regclass then
    select id, idempotency_payload_hash
    into v_existing_id, v_existing_hash
    from public.contracts
    where tenant_id = v_tenant_id
      and idempotency_key = p_idempotency_key;
  else
    raise exception 'validation_failed';
  end if;

  if v_existing_id is null then
    return null;
  end if;

  if v_existing_hash is distinct from p_payload_hash then
    raise exception 'idempotency_payload_mismatch';
  end if;

  return v_existing_id;
end;
$$;

comment on function public.resolve_finance_idempotency(regclass, uuid, text) is
  'Phase 5/6: idempotency resolver including contracts.';

drop trigger if exists trg_audit_contract_oil_changes on public.contract_oil_changes;

create trigger trg_audit_contract_oil_changes
  after insert or update or delete on public.contract_oil_changes
  for each row execute function public.audit_log_row();

-- ---------------------------------------------------------------------------
-- Section B: contract direct-write gate
-- ---------------------------------------------------------------------------
create or replace function public.allow_contract_write()
returns void
language sql
security definer
set search_path = public
as $$
  select set_config('hs360.contract_write', '1', true);
$$;

comment on function public.allow_contract_write() is
  'M3: Session gate for trusted contract RPC writes. Internal-only.';

create or replace function public.enforce_contract_direct_write_gate()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('postgres', 'supabase_admin') then
    return coalesce(new, old);
  end if;

  if coalesce(current_setting('hs360.contract_write', true), '') = '1' then
    return coalesce(new, old);
  end if;

  raise exception 'direct_write_forbidden';
end;
$$;

drop trigger if exists trg_contract_direct_write_gate_contracts on public.contracts;
create trigger trg_contract_direct_write_gate_contracts
  before insert or update or delete on public.contracts
  for each row execute function public.enforce_contract_direct_write_gate();

drop trigger if exists trg_contract_direct_write_gate_contract_lines on public.contract_lines;
create trigger trg_contract_direct_write_gate_contract_lines
  before insert or update or delete on public.contract_lines
  for each row execute function public.enforce_contract_direct_write_gate();

drop trigger if exists trg_contract_direct_write_gate_contract_oil_changes on public.contract_oil_changes;
create trigger trg_contract_direct_write_gate_contract_oil_changes
  before insert or update or delete on public.contract_oil_changes
  for each row execute function public.enforce_contract_direct_write_gate();

-- ---------------------------------------------------------------------------
-- Section C: payload normalization + idempotency hash
-- ---------------------------------------------------------------------------
create or replace function public.normalize_contract_creation_payload(
  p_contract_type public.contract_type,
  p_data jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed_top text[];
  v_key text;
  v_asset_lines jsonb;
  v_consumable_lines jsonb;
  v_line jsonb;
  v_norm_assets jsonb := '[]'::jsonb;
  v_norm_consumables jsonb := '[]'::jsonb;
  v_norm_line jsonb;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_qty_per_refill numeric(15, 3);
  v_refill_frequency int;
  v_monthly_rental_value numeric(15, 3);
  v_customer_id uuid;
  v_service_location_id uuid;
  v_start_date date;
  v_end_date date;
  v_billing_day int;
  v_refill_day int;
  v_trial_days int;
  v_request_override boolean;
  v_override_reason text;
  v_notes text;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if p_contract_type = 'trial'::public.contract_type then
    v_allowed_top := array[
      'customer_id', 'service_location_id', 'start_date', 'end_date',
      'billing_day', 'refill_day', 'notes', 'trial_days',
      'asset_lines', 'consumable_lines'
    ];
  else
    v_allowed_top := array[
      'customer_id', 'service_location_id', 'start_date', 'end_date',
      'billing_day', 'refill_day', 'notes', 'monthly_rental_value',
      'request_override', 'override_reason', 'asset_lines', 'consumable_lines'
    ];
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if not (v_key = any (v_allowed_top)) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (p_data ? 'customer_id' and p_data ? 'service_location_id' and p_data ? 'start_date') then
    raise exception 'validation_failed';
  end if;

  begin
    v_customer_id := (p_data ->> 'customer_id')::uuid;
    v_service_location_id := (p_data ->> 'service_location_id')::uuid;
    v_start_date := (p_data ->> 'start_date')::date;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if p_data ? 'end_date' then
    begin
      v_end_date := (p_data ->> 'end_date')::date;
    exception
      when others then
        raise exception 'validation_failed';
    end;
  end if;

  if p_data ? 'billing_day' then
    begin
      v_billing_day := (p_data ->> 'billing_day')::int;
      if v_billing_day < 1 or v_billing_day > 28 then
        raise exception 'validation_failed';
      end if;
    exception
      when others then
        raise exception 'validation_failed';
    end;
  end if;

  if p_data ? 'refill_day' then
    begin
      v_refill_day := (p_data ->> 'refill_day')::int;
      if v_refill_day < 1 or v_refill_day > 28 then
        raise exception 'validation_failed';
      end if;
    exception
      when others then
        raise exception 'validation_failed';
    end;
  end if;

  if p_data ? 'trial_days' then
    begin
      v_trial_days := (p_data ->> 'trial_days')::int;
      if v_trial_days < 1 then
        raise exception 'validation_failed';
      end if;
    exception
      when others then
        raise exception 'validation_failed';
    end;
  end if;

  v_notes := nullif(btrim(p_data ->> 'notes'), '');

  v_asset_lines := coalesce(p_data -> 'asset_lines', '[]'::jsonb);
  v_consumable_lines := coalesce(p_data -> 'consumable_lines', '[]'::jsonb);

  if jsonb_typeof(v_asset_lines) <> 'array' or jsonb_typeof(v_consumable_lines) <> 'array' then
    raise exception 'validation_failed';
  end if;

  if jsonb_array_length(v_asset_lines) < 1 then
    raise exception 'validation_failed';
  end if;

  for v_line in
    select value
    from jsonb_array_elements(v_asset_lines)
    order by (value ->> 'product_id'), coalesce(value ->> 'product_unit_id', '')
  loop
    if jsonb_typeof(v_line) <> 'object' or not (v_line ? 'product_id') then
      raise exception 'validation_failed';
    end if;

    begin
      v_product_id := (v_line ->> 'product_id')::uuid;
      if not (v_line ? 'product_unit_id') then
        raise exception 'validation_failed';
      end if;
      v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    v_norm_line := jsonb_build_object(
      'product_id', v_product_id,
      'product_unit_id', v_product_unit_id
    );
    v_norm_assets := v_norm_assets || jsonb_build_array(v_norm_line);
  end loop;

  for v_line in
    select value
    from jsonb_array_elements(v_consumable_lines)
    order by (value ->> 'product_id')
  loop
    if jsonb_typeof(v_line) <> 'object'
      or not (v_line ? 'product_id' and v_line ? 'qty_per_refill') then
      raise exception 'validation_failed';
    end if;

    begin
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_qty_per_refill := (v_line ->> 'qty_per_refill')::numeric(15, 3);
      v_refill_frequency := coalesce((v_line ->> 'refill_frequency_months')::int, 1);
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if v_qty_per_refill <= 0 or v_refill_frequency < 1 then
      raise exception 'validation_failed';
    end if;

    v_norm_line := jsonb_build_object(
      'product_id', v_product_id,
      'qty_per_refill', v_qty_per_refill,
      'refill_frequency_months', v_refill_frequency
    );
    v_norm_consumables := v_norm_consumables || jsonb_build_array(v_norm_line);
  end loop;

  if p_contract_type = 'trial'::public.contract_type then
    v_monthly_rental_value := 0;
    v_request_override := false;
    v_override_reason := null;
  else
    if not (p_data ? 'monthly_rental_value') then
      raise exception 'validation_failed';
    end if;

    begin
      v_monthly_rental_value := (p_data ->> 'monthly_rental_value')::numeric(15, 3);
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if v_monthly_rental_value <= 0 then
      raise exception 'validation_failed';
    end if;

    v_request_override := coalesce((p_data ->> 'request_override')::boolean, false);
    v_override_reason := nullif(btrim(p_data ->> 'override_reason'), '');
  end if;

  return jsonb_strip_nulls(
    jsonb_build_object(
      'contract_type', p_contract_type::text,
      'customer_id', v_customer_id,
      'service_location_id', v_service_location_id,
      'start_date', v_start_date,
      'end_date', v_end_date,
      'billing_day', v_billing_day,
      'refill_day', v_refill_day,
      'trial_days', v_trial_days,
      'notes', v_notes,
      'monthly_rental_value', v_monthly_rental_value,
      'request_override', case when p_contract_type = 'rental' then v_request_override end,
      'override_reason', case when p_contract_type = 'rental' then v_override_reason end,
      'asset_lines', v_norm_assets,
      'consumable_lines', v_norm_consumables
    )
  );
end;
$$;

create or replace function public.compute_contract_creation_payload_hash(
  p_contract_type public.contract_type,
  p_data jsonb
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
        public.normalize_contract_creation_payload(p_contract_type, p_data)::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

-- ---------------------------------------------------------------------------
-- Section D: internal contract creation
-- ---------------------------------------------------------------------------
create or replace function public.create_contract_internal(
  p_contract_type public.contract_type,
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
  v_service_location_id uuid;
  v_customer public.customers%rowtype;
  v_location public.customer_service_locations%rowtype;
  v_settings public.tenant_settings%rowtype;
  v_start_date date;
  v_end_date date;
  v_trial_days int;
  v_trial_end_date date;
  v_billing_day int;
  v_refill_day int;
  v_monthly_rental_value numeric(15, 3);
  v_pricing_payload jsonb;
  v_pricing jsonb;
  v_contract_id uuid := gen_random_uuid();
  v_contract_number text;
  v_contact_phone text;
  v_contact_person_name text;
  v_contact_email text;
  v_asset_lines jsonb;
  v_consumable_lines jsonb;
  v_pricing_assets jsonb;
  v_pricing_consumables jsonb;
  v_line jsonb;
  v_pricing_line jsonb;
  v_line_idx int;
  v_line_id uuid;
  v_product_id uuid;
  v_product_unit_id uuid;
  v_unit_status public.unit_status;
  v_unit_warehouse_id uuid;
  v_prev_status public.unit_status;
  v_qty_per_refill numeric(15, 3);
  v_refill_frequency int;
  v_source_cost numeric(15, 3);
  v_line_monthly_cost numeric(15, 3);
  v_cost_basis text;
  v_snapshot_refill_cost numeric(15, 3);
  v_movement_type public.movement_type;
  v_unit_target_status public.unit_status;
  v_event_type text;
  v_seen_units uuid[] := '{}';
  v_min_overridden boolean := false;
  v_override_reason text;
begin
  perform public.allow_contract_write();

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('contracts.create') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_normalized := public.normalize_contract_creation_payload(p_contract_type, p_data);
  v_hash := public.compute_contract_creation_payload_hash(p_contract_type, p_data);

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);
  v_existing_id := public.resolve_finance_idempotency(
    'public.contracts'::regclass,
    p_idempotency_key,
    v_hash
  );
  if v_existing_id is not null then
    return v_existing_id;
  end if;

  v_customer_id := (v_normalized ->> 'customer_id')::uuid;
  v_service_location_id := (v_normalized ->> 'service_location_id')::uuid;
  v_start_date := (v_normalized ->> 'start_date')::date;
  v_asset_lines := v_normalized -> 'asset_lines';
  v_consumable_lines := v_normalized -> 'consumable_lines';

  select * into v_customer
  from public.customers c
  where c.id = v_customer_id
    and c.tenant_id = v_tenant_id;

  if not found or not coalesce(v_customer.is_active, false) then
    raise exception 'validation_failed';
  end if;

  select * into v_location
  from public.customer_service_locations csl
  where csl.id = v_service_location_id
    and csl.tenant_id = v_tenant_id
    and csl.customer_id = v_customer_id;

  if not found or not coalesce(v_location.is_active, false) then
    raise exception 'validation_failed';
  end if;

  select * into v_settings
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_contact_phone := coalesce(
    nullif(btrim(v_location.contact_person_phone), ''),
    nullif(btrim(v_customer.phone_primary), '')
  );
  if v_contact_phone is null then
    raise exception 'validation_failed';
  end if;

  v_contact_person_name := coalesce(
    nullif(btrim(v_location.contact_person_name), ''),
    nullif(btrim(v_customer.name_ar), '')
  );
  v_contact_email := coalesce(
    nullif(btrim(v_location.contact_person_email), ''),
    nullif(btrim(v_customer.email), '')
  );

  if v_normalized ? 'billing_day' then
    v_billing_day := (v_normalized ->> 'billing_day')::int;
  end if;

  if v_normalized ? 'refill_day' then
    v_refill_day := (v_normalized ->> 'refill_day')::int;
  end if;

  for v_line in select value from jsonb_array_elements(v_asset_lines) loop
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;

    if v_product_unit_id = any (v_seen_units) then
      raise exception 'validation_failed';
    end if;
    v_seen_units := array_append(v_seen_units, v_product_unit_id);

    if not exists (
      select 1
      from public.products p
      where p.id = v_product_id
        and p.tenant_id = v_tenant_id
        and p.product_type = 'asset_rental'::public.product_type
        and coalesce(p.is_active, true)
    ) then
      raise exception 'validation_failed';
    end if;

    select pu.status, pu.current_warehouse_id
    into v_unit_status, v_unit_warehouse_id
    from public.product_units pu
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id
      and pu.product_id = v_product_id
    for update;

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_unit_status not in ('available_new'::public.unit_status, 'available_used'::public.unit_status) then
      raise exception 'validation_failed';
    end if;

    if exists (
      select 1
      from public.product_units pu
      where pu.id = v_product_unit_id
        and pu.current_contract_id is not null
    ) then
      raise exception 'validation_failed';
    end if;

    if v_unit_warehouse_id is null then
      raise exception 'validation_failed';
    end if;
  end loop;

  for v_line in select value from jsonb_array_elements(v_consumable_lines) loop
    v_product_id := (v_line ->> 'product_id')::uuid;

    if not exists (
      select 1
      from public.products p
      where p.id = v_product_id
        and p.tenant_id = v_tenant_id
        and p.product_type = 'consumable_rental'::public.product_type
        and coalesce(p.is_active, true)
    ) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if p_contract_type = 'trial'::public.contract_type then
    v_monthly_rental_value := 0;
    v_trial_days := coalesce(
      (v_normalized ->> 'trial_days')::int,
      v_settings.default_trial_days,
      30
    );
    v_trial_end_date := v_start_date + v_trial_days;
    v_end_date := coalesce((v_normalized ->> 'end_date')::date, v_trial_end_date);
    v_movement_type := 'trial_out'::public.movement_type;
    v_unit_target_status := 'trial'::public.unit_status;
    v_event_type := 'contract_trial';

    v_pricing_payload := jsonb_build_object(
      'monthly_rental_value', 0,
      'asset_lines', v_asset_lines,
      'consumable_lines', v_consumable_lines
    );
  else
    v_monthly_rental_value := (v_normalized ->> 'monthly_rental_value')::numeric(15, 3);
    v_end_date := coalesce(
      (v_normalized ->> 'end_date')::date,
      (v_start_date + (coalesce(v_settings.default_contract_term_months, 12)::text || ' months')::interval)::date
    );
    v_movement_type := 'rental_out'::public.movement_type;
    v_unit_target_status := 'rented'::public.unit_status;
    v_event_type := 'contract_rental';

    v_pricing_payload := jsonb_build_object(
      'monthly_rental_value', v_monthly_rental_value,
      'asset_lines', v_asset_lines,
      'consumable_lines', v_consumable_lines,
      'request_override', coalesce((v_normalized ->> 'request_override')::boolean, false),
      'override_reason', v_normalized ->> 'override_reason'
    );
  end if;

  v_pricing := public.compute_contract_pricing_internal(v_tenant_id, v_pricing_payload);
  v_pricing_assets := coalesce(v_pricing -> 'asset_lines', '[]'::jsonb);
  v_pricing_consumables := coalesce(v_pricing -> 'consumable_lines', '[]'::jsonb);

  if p_contract_type = 'rental'::public.contract_type then
    if coalesce((v_pricing ->> 'passes_min_profit')::boolean, false) is not true then
      raise exception 'below_min_profit';
    end if;

    v_min_overridden := coalesce((v_pricing ->> 'min_profit_overridden')::boolean, false);
    if v_min_overridden then
      v_override_reason := nullif(btrim(v_normalized ->> 'override_reason'), '');
      if v_override_reason is null then
        raise exception 'validation_failed';
      end if;
    end if;
  end if;

  v_contract_number := public.next_document_number('CON');

  insert into public.contracts (
    id, tenant_id, contract_number, type, status,
    customer_id, service_location_id,
    contact_person_name, contact_phone, contact_email,
    start_date, end_date, trial_days, trial_end_date,
    billing_day, refill_day,
    monthly_rental_value,
    snapshot_device_monthly_cost,
    snapshot_oil_monthly_cost,
    snapshot_total_monthly_cost,
    snapshot_monthly_profit,
    snapshot_min_profit_threshold,
    snapshot_asset_cost_basis,
    snapshot_consumable_cost_basis,
    snapshot_asset_lifespan_months,
    location_name, location_country, location_governorate, location_area,
    location_lat, location_lng, location_address, location_google_maps_url,
    min_profit_overridden, override_approved_by, override_approved_at, override_reason,
    notes,
    idempotency_key, idempotency_payload_hash,
    created_by
  )
  values (
    v_contract_id, v_tenant_id, v_contract_number, p_contract_type, 'active'::public.contract_status,
    v_customer_id, v_service_location_id,
    v_contact_person_name, v_contact_phone, v_contact_email,
    v_start_date, v_end_date,
    case when p_contract_type = 'trial' then v_trial_days end,
    case when p_contract_type = 'trial' then v_trial_end_date end,
    v_billing_day, v_refill_day,
    v_monthly_rental_value,
    coalesce((v_pricing ->> 'asset_monthly_cost')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'consumable_monthly_cost')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'total_monthly_cost')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'expected_monthly_profit')::numeric(15, 3), 0),
    coalesce((v_pricing ->> 'min_monthly_profit_threshold')::numeric(15, 3), 0),
    (v_pricing ->> 'asset_cost_basis')::public.rental_asset_cost_basis,
    (v_pricing ->> 'consumable_cost_basis')::public.rental_consumable_cost_basis,
    nullif(v_pricing ->> 'asset_lifespan_months', '')::int,
    v_location.name, v_location.country, v_location.governorate, v_location.area,
    v_location.latitude, v_location.longitude, v_location.address_line, v_location.google_maps_url,
    case when p_contract_type = 'rental' and v_min_overridden then true else false end,
    case when p_contract_type = 'rental' and v_min_overridden then auth.uid() end,
    case when p_contract_type = 'rental' and v_min_overridden then now() end,
    case when p_contract_type = 'rental' and v_min_overridden then v_override_reason end,
    v_normalized ->> 'notes',
    p_idempotency_key, v_hash,
    auth.uid()
  );

  v_line_idx := 0;
  for v_line in select value from jsonb_array_elements(v_asset_lines) loop
    v_line_idx := v_line_idx + 1;
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_product_unit_id := (v_line ->> 'product_unit_id')::uuid;

    v_pricing_line := v_pricing_assets -> (v_line_idx - 1);
    if v_pricing_line is null then
      raise exception 'validation_failed';
    end if;

    v_source_cost := (v_pricing_line ->> 'source_unit_cost')::numeric(15, 3);
    v_line_monthly_cost := (v_pricing_line ->> 'monthly_cost')::numeric(15, 3);
    v_cost_basis := v_pricing_line ->> 'cost_basis';

    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id, product_unit_id,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, v_tenant_id, v_contract_id, 'asset'::public.contract_line_type,
      v_product_id, v_product_unit_id,
      v_source_cost, v_line_monthly_cost,
      v_cost_basis::public.contract_line_cost_basis,
      v_line_idx
    );

    select pu.status, pu.current_warehouse_id
    into v_prev_status, v_unit_warehouse_id
    from public.product_units pu
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id
    for update;

    update public.inventory_balances ib
    set
      qty_available = ib.qty_available - 1,
      qty_trial = ib.qty_trial + case when p_contract_type = 'trial' then 1 else 0 end,
      qty_rented = ib.qty_rented + case when p_contract_type = 'rental' then 1 else 0 end,
      updated_at = now()
    where ib.tenant_id = v_tenant_id
      and ib.warehouse_id = v_unit_warehouse_id
      and ib.product_id = v_product_id
      and ib.qty_available >= 1;

    if not found then
      raise exception 'insufficient_stock';
    end if;

    insert into public.inventory_movements (
      tenant_id, movement_type, warehouse_id, product_id, product_unit_id,
      qty, reference_table, reference_id, notes, created_by
    )
    values (
      v_tenant_id, v_movement_type, v_unit_warehouse_id, v_product_id, v_product_unit_id,
      1, 'contracts', v_contract_id,
      'Contract ' || v_contract_number, auth.uid()
    );

    insert into public.unit_events (
      tenant_id, product_unit_id, event_type, occurred_at,
      warehouse_id, customer_id, service_location_id, contract_id,
      reference_table, reference_id, notes, metadata_json, created_by
    )
    values (
      v_tenant_id, v_product_unit_id, v_event_type, now(),
      v_unit_warehouse_id, v_customer_id, v_service_location_id, v_contract_id,
      'contracts', v_contract_id,
      'Contract ' || v_contract_number,
      jsonb_build_object(
        'previous_status', v_prev_status::text,
        'contract_type', p_contract_type::text,
        'contract_number', v_contract_number
      ),
      auth.uid()
    );

    update public.product_units pu
    set
      status = v_unit_target_status,
      current_contract_id = v_contract_id,
      current_customer_id = v_customer_id,
      current_service_location_id = v_service_location_id,
      updated_at = now()
    where pu.id = v_product_unit_id
      and pu.tenant_id = v_tenant_id;
  end loop;

  v_line_idx := 0;
  for v_line in select value from jsonb_array_elements(v_consumable_lines) loop
    v_line_idx := v_line_idx + 1;
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_qty_per_refill := (v_line ->> 'qty_per_refill')::numeric(15, 3);
    v_refill_frequency := (v_line ->> 'refill_frequency_months')::int;

    v_pricing_line := v_pricing_consumables -> (v_line_idx - 1);
    if v_pricing_line is null then
      raise exception 'validation_failed';
    end if;

    v_source_cost := (v_pricing_line ->> 'source_unit_cost')::numeric(15, 3);
    v_line_monthly_cost := (v_pricing_line ->> 'monthly_cost')::numeric(15, 3);
    v_cost_basis := v_pricing_line ->> 'cost_basis';
    v_snapshot_refill_cost := public.round_money(
      v_qty_per_refill * v_source_cost,
      public.resolve_tenant_money_precision(v_tenant_id)
    );

    v_line_id := gen_random_uuid();
    insert into public.contract_lines (
      id, tenant_id, contract_id, line_type, product_id,
      qty_per_refill, refill_frequency_months,
      snapshot_unit_cost, snapshot_monthly_cost, snapshot_cost_basis, line_order
    )
    values (
      v_line_id, v_tenant_id, v_contract_id, 'consumable'::public.contract_line_type,
      v_product_id, v_qty_per_refill, v_refill_frequency,
      v_source_cost, v_line_monthly_cost,
      v_cost_basis::public.contract_line_cost_basis,
      jsonb_array_length(v_asset_lines) + v_line_idx
    );

    insert into public.contract_oil_changes (
      tenant_id, contract_id, contract_line_id,
      effective_from, effective_to,
      oil_product_id, qty_per_refill,
      snapshot_unit_cost, snapshot_refill_cost
    )
    values (
      v_tenant_id, v_contract_id, v_line_id,
      v_start_date, null,
      v_product_id, v_qty_per_refill,
      v_source_cost, v_snapshot_refill_cost
    );
  end loop;

  return v_contract_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section E: public RPCs + grants
-- ---------------------------------------------------------------------------
create or replace function public.create_trial_contract(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.create_contract_internal('trial'::public.contract_type, p_data, p_idempotency_key);
$$;

create or replace function public.create_rental_contract(
  p_data jsonb,
  p_idempotency_key uuid
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.create_contract_internal('rental'::public.contract_type, p_data, p_idempotency_key);
$$;

comment on function public.create_trial_contract(jsonb, uuid) is
  'Phase 6 M3: create active trial contract (عقد تجريبي). Moves units to trial; cost snapshots only.';

comment on function public.create_rental_contract(jsonb, uuid) is
  'Phase 6 M3: create active rental contract (عقد إيجار). Enforces min-profit rules; moves units to rented.';

grant execute on function public.create_trial_contract(jsonb, uuid) to authenticated;
grant execute on function public.create_rental_contract(jsonb, uuid) to authenticated;

revoke all on function public.allow_contract_write() from public, anon, authenticated;
revoke all on function public.normalize_contract_creation_payload(public.contract_type, jsonb)
  from public, anon, authenticated;
revoke all on function public.compute_contract_creation_payload_hash(public.contract_type, jsonb)
  from public, anon, authenticated;
revoke all on function public.create_contract_internal(public.contract_type, jsonb, uuid)
  from public, anon, authenticated;
