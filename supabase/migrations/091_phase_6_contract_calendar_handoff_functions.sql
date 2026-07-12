-- Phase 6 M12: calendar handoff functions, sync engine, lifecycle hooks, read enrichment.

-- ---------------------------------------------------------------------------
-- Constants + date helpers
-- ---------------------------------------------------------------------------
create or replace function public.calendar_default_horizon_days()
returns int
language sql
immutable
as $$
  select 30;
$$;

create or replace function public.calendar_max_horizon_days()
returns int
language sql
immutable
as $$
  select 180;
$$;

create or replace function public.calendar_make_day_in_month(p_month_start date, p_day int)
returns date
language sql
immutable
as $$
  select make_date(
    extract(year from p_month_start)::int,
    extract(month from p_month_start)::int,
    least(
      p_day,
      extract(day from (date_trunc('month', p_month_start) + interval '1 month - 1 day'))::int
    )
  );
$$;

create or replace function public.resolve_contract_effective_end(p_contract public.contracts)
returns date
language sql
stable
as $$
  select coalesce(
    p_contract.closed_at::date,
    p_contract.returned_at::date,
    p_contract.end_date
  );
$$;

create or replace function public.build_contract_calendar_source_key(
  p_contract_id uuid,
  p_kind text,
  p_contract_line_id uuid default null,
  p_date date default null,
  p_coverage_month_key date default null
)
returns text
language sql
immutable
as $$
  select case p_kind
    when 'trial_ending' then format('contract:%s:trial_ending', p_contract_id)
    when 'contract_end' then format('contract:%s:contract_end', p_contract_id)
    when 'billing' then format(
      'contract:%s:billing:%s',
      p_contract_id,
      to_char(p_coverage_month_key, 'YYYY-MM-DD')
    )
    when 'refill' then format(
      'contract:%s:refill:%s:%s',
      p_contract_id,
      p_contract_line_id,
      to_char(p_date, 'YYYY-MM-DD')
    )
    else null
  end;
$$;

-- ---------------------------------------------------------------------------
-- Upsert generated calendar event (trusted writer only)
-- ---------------------------------------------------------------------------
create or replace function public.upsert_contract_calendar_event(
  p_tenant_id uuid,
  p_contract_id uuid,
  p_customer_id uuid,
  p_service_location_id uuid,
  p_contract_line_id uuid,
  p_type public.calendar_event_type,
  p_scheduled_date date,
  p_source_key text,
  p_source_metadata jsonb,
  p_title_ar text,
  p_title_en text,
  p_reminder_offsets_minutes int[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
  v_existing public.calendar_events%rowtype;
begin
  select *
  into v_existing
  from public.calendar_events ce
  where ce.tenant_id = p_tenant_id
    and ce.source_key = p_source_key
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
  for update;

  if found then
    if v_existing.status = 'pending'::public.calendar_event_status then
      update public.calendar_events ce
      set
        scheduled_date = p_scheduled_date,
        type = p_type,
        contract_line_id = p_contract_line_id,
        customer_id = p_customer_id,
        service_location_id = p_service_location_id,
        source_metadata = p_source_metadata,
        title_ar = p_title_ar,
        title_en = p_title_en,
        reminder_offsets_minutes = p_reminder_offsets_minutes
      where ce.id = v_existing.id;
    end if;
    return v_existing.id;
  end if;

  insert into public.calendar_events (
    tenant_id,
    type,
    status,
    scheduled_date,
    reminder_offsets_minutes,
    contract_id,
    customer_id,
    service_location_id,
    contract_line_id,
    title_ar,
    title_en,
    source_kind,
    source_key,
    source_metadata
  )
  values (
    p_tenant_id,
    p_type,
    'pending'::public.calendar_event_status,
    p_scheduled_date,
    p_reminder_offsets_minutes,
    p_contract_id,
    p_customer_id,
    p_service_location_id,
    p_contract_line_id,
    p_title_ar,
    p_title_en,
    'contract_generated'::public.calendar_event_source_kind,
    p_source_key,
    coalesce(p_source_metadata, '{}'::jsonb)
  )
  returning id into v_event_id;

  return v_event_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Terminal cancel + suspension purge + coverage done
-- ---------------------------------------------------------------------------
create or replace function public.cancel_contract_generated_events_terminal(
  p_contract_id uuid,
  p_after_date date,
  p_reason text
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.calendar_events ce
  set
    status = 'cancelled'::public.calendar_event_status,
    source_metadata = ce.source_metadata || jsonb_build_object('cancellation_reason', p_reason)
  where ce.contract_id = p_contract_id
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.status = 'pending'::public.calendar_event_status
    and ce.scheduled_date > p_after_date;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.purge_suspended_contract_billing_refill_events(
  p_contract_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  delete from public.calendar_events ce
  where ce.contract_id = p_contract_id
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.type in (
      'billing_due'::public.calendar_event_type,
      'refill_due'::public.calendar_event_type
    )
    and ce.status = 'pending'::public.calendar_event_status
    and ce.scheduled_date >= current_date;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.mark_contract_billing_events_done_for_coverage(
  p_contract_id uuid,
  p_coverage_month_key date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_key text;
begin
  v_key := public.build_contract_calendar_source_key(
    p_contract_id,
    'billing',
    null,
    null,
    date_trunc('month', p_coverage_month_key)::date
  );

  update public.calendar_events ce
  set status = 'done'::public.calendar_event_status
  where ce.contract_id = p_contract_id
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.type = 'billing_due'::public.calendar_event_type
    and ce.source_key = v_key
    and ce.status = 'pending'::public.calendar_event_status;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.mark_contract_billing_events_done_for_collection(
  p_contract_id uuid,
  p_coverage_months jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date;
begin
  if p_coverage_months is null or jsonb_typeof(p_coverage_months) <> 'array' then
    return;
  end if;

  for v_month in
    select (elem.value #>> '{}')::date
    from jsonb_array_elements(p_coverage_months) elem(value)
  loop
    perform public.mark_contract_billing_events_done_for_coverage(p_contract_id, v_month);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Billing + refill planners (internal)
-- ---------------------------------------------------------------------------
create or replace function public.sync_contract_billing_events_internal(
  p_contract public.contracts,
  p_policy public.first_rental_invoice_policy,
  p_horizon_end date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_effective_end date;
  v_month_start date;
  v_scheduled date;
  v_coverage_month_key date;
  v_billing_day int;
  v_first_month_done boolean := false;
begin
  if p_contract.type <> 'rental'::public.contract_type
    or p_contract.status <> 'active'::public.contract_status
    or p_contract.billing_day is null
    or p_policy = 'manual'::public.first_rental_invoice_policy then
    return 0;
  end if;

  v_effective_end := public.resolve_contract_effective_end(p_contract);
  v_billing_day := p_contract.billing_day;

  if p_policy = 'on_activation'::public.first_rental_invoice_policy then
    if p_contract.start_date >= current_date
      and p_contract.start_date <= p_horizon_end
      and (v_effective_end is null or p_contract.start_date <= v_effective_end)
      and not exists (
        select 1
        from public.rental_invoice_coverages ric
        where ric.tenant_id = p_contract.tenant_id
          and ric.contract_id = p_contract.id
          and ric.coverage_month_key = date_trunc('month', p_contract.start_date)::date
      ) then
      v_coverage_month_key := date_trunc('month', p_contract.start_date)::date;
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'billing_due'::public.calendar_event_type,
        p_contract.start_date,
        public.build_contract_calendar_source_key(
          p_contract.id, 'billing', null, null, v_coverage_month_key
        ),
        jsonb_build_object(
          'coverage_month_key', to_char(v_coverage_month_key, 'YYYY-MM-DD'),
          'billing_day', v_billing_day
        ),
        'استحقاق فوترة — ' || p_contract.contract_number,
        'Billing due — ' || p_contract.contract_number,
        array[1440, 60]
      );
      v_count := v_count + 1;
    end if;
    v_first_month_done := true;
    v_month_start := (date_trunc('month', p_contract.start_date) + interval '1 month')::date;
  else
    v_month_start := date_trunc('month', p_contract.start_date)::date;
  end if;

  while v_month_start <= p_horizon_end loop
    v_coverage_month_key := date_trunc('month', v_month_start)::date;
    v_scheduled := public.calendar_make_day_in_month(v_month_start, v_billing_day);

    if (not v_first_month_done or p_policy <> 'on_activation'::public.first_rental_invoice_policy)
      and v_scheduled >= p_contract.start_date
      and v_scheduled >= current_date
      and v_scheduled <= p_horizon_end
      and (v_effective_end is null or v_scheduled <= v_effective_end)
      and not exists (
        select 1
        from public.rental_invoice_coverages ric
        where ric.tenant_id = p_contract.tenant_id
          and ric.contract_id = p_contract.id
          and ric.coverage_month_key = v_coverage_month_key
      ) then
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'billing_due'::public.calendar_event_type,
        v_scheduled,
        public.build_contract_calendar_source_key(
          p_contract.id, 'billing', null, null, v_coverage_month_key
        ),
        jsonb_build_object(
          'coverage_month_key', to_char(v_coverage_month_key, 'YYYY-MM-DD'),
          'billing_day', v_billing_day
        ),
        'استحقاق فوترة — ' || p_contract.contract_number,
        'Billing due — ' || p_contract.contract_number,
        array[1440, 60]
      );
      v_count := v_count + 1;
    end if;

    v_month_start := (v_month_start + interval '1 month')::date;
  end loop;

  return v_count;
end;
$$;

create or replace function public.sync_contract_refill_events_internal(
  p_contract public.contracts,
  p_horizon_end date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_line public.contract_lines%rowtype;
  v_effective_end date;
  v_month_start date;
  v_scheduled date;
  v_freq int;
  v_refill_day int;
  v_candidate date;
  v_oil_change record;
  v_regular_dates date[] := '{}';
  v_oil_dates date[] := '{}';
  v_metadata jsonb;
  v_title_ar text;
  v_title_en text;
  v_product_name_ar text;
  v_product_name_en text;
  v_prev_product_id uuid;
begin
  if p_contract.type <> 'rental'::public.contract_type
    or p_contract.status <> 'active'::public.contract_status
    or p_contract.refill_day is null then
    return 0;
  end if;

  v_effective_end := public.resolve_contract_effective_end(p_contract);
  v_refill_day := p_contract.refill_day;

  for v_line in
    select *
    from public.contract_lines cl
    where cl.contract_id = p_contract.id
      and cl.tenant_id = p_contract.tenant_id
      and cl.line_type = 'consumable'::public.contract_line_type
    order by cl.line_order, cl.id
  loop
    v_regular_dates := '{}';
    v_oil_dates := '{}';
    v_freq := greatest(coalesce(v_line.refill_frequency_months, 1), 1);

    v_month_start := (
      date_trunc('month', p_contract.start_date)
      + (v_freq * interval '1 month')
    )::date;

    while v_month_start <= p_horizon_end loop
      v_scheduled := public.calendar_make_day_in_month(v_month_start, v_refill_day);
      if v_scheduled >= p_contract.start_date
        and v_scheduled >= current_date
        and v_scheduled <= p_horizon_end
        and (v_effective_end is null or v_scheduled <= v_effective_end) then
        v_regular_dates := array_append(v_regular_dates, v_scheduled);
      end if;
      v_month_start := (v_month_start + (v_freq * interval '1 month'))::date;
    end loop;

    for v_oil_change in
      select
        coc.id,
        coc.effective_from,
        coc.oil_product_id,
        coc.qty_per_refill,
        p.name_ar,
        p.name_en
      from public.contract_oil_changes coc
      join public.products p
        on p.id = coc.oil_product_id
        and p.tenant_id = coc.tenant_id
      where coc.contract_line_id = v_line.id
        and coc.tenant_id = p_contract.tenant_id
        and coc.effective_from >= current_date
        and coc.effective_from <= p_horizon_end
        and (v_effective_end is null or coc.effective_from <= v_effective_end)
    loop
      v_oil_dates := array_append(v_oil_dates, v_oil_change.effective_from);
    end loop;

    for v_candidate in
      select distinct d
      from unnest(v_regular_dates || v_oil_dates) as d
      order by d
    loop
      select coc.id, coc.oil_product_id, coc.qty_per_refill, p.name_ar, p.name_en
      into v_oil_change
      from public.contract_oil_changes coc
      join public.products p on p.id = coc.oil_product_id and p.tenant_id = coc.tenant_id
      where coc.contract_line_id = v_line.id
        and coc.tenant_id = p_contract.tenant_id
        and coc.effective_from = v_candidate
      limit 1;

      if v_candidate = any (v_regular_dates)
        and v_oil_change.id is not null then
        select coc.oil_product_id
        into v_prev_product_id
        from public.contract_oil_changes coc
        where coc.contract_line_id = v_line.id
          and coc.tenant_id = p_contract.tenant_id
          and coc.effective_from < v_candidate
        order by coc.effective_from desc, coc.created_at desc, coc.id desc
        limit 1;

        v_metadata := jsonb_build_object(
          'action_kind', 'refill_with_consumable_change',
          'contract_oil_change_id', v_oil_change.id,
          'oil_product_id', v_oil_change.oil_product_id,
          'previous_oil_product_id', v_prev_product_id,
          'qty_per_refill', v_oil_change.qty_per_refill::text
        );
        v_title_ar := 'تعبئة مع تغيير مستهلك — ' || coalesce(v_oil_change.name_ar, '');
        v_title_en := 'Refill with consumable change — ' || coalesce(v_oil_change.name_en, '');
      elsif v_oil_change.id is not null then
        v_metadata := jsonb_build_object(
          'action_kind', 'consumable_change',
          'contract_oil_change_id', v_oil_change.id,
          'oil_product_id', v_oil_change.oil_product_id,
          'qty_per_refill', v_oil_change.qty_per_refill::text
        );
        v_title_ar := 'تغيير مستهلك — ' || coalesce(v_oil_change.name_ar, '');
        v_title_en := 'Consumable change — ' || coalesce(v_oil_change.name_en, '');
      else
        select p.name_ar, p.name_en
        into v_product_name_ar, v_product_name_en
        from public.contract_oil_changes coc
        join public.products p on p.id = coc.oil_product_id and p.tenant_id = coc.tenant_id
        where coc.contract_line_id = v_line.id
          and coc.tenant_id = p_contract.tenant_id
          and coc.effective_from <= v_candidate
          and (coc.effective_to is null or coc.effective_to >= v_candidate)
        order by coc.effective_from desc, coc.created_at desc, coc.id desc
        limit 1;

        select coc.oil_product_id
        into v_prev_product_id
        from public.contract_oil_changes coc
        where coc.contract_line_id = v_line.id
          and coc.tenant_id = p_contract.tenant_id
          and coc.effective_from <= v_candidate
          and (coc.effective_to is null or coc.effective_to >= v_candidate)
        order by coc.effective_from desc, coc.created_at desc, coc.id desc
        limit 1;

        v_metadata := jsonb_build_object('action_kind', 'refill');
        v_title_ar := 'تعبئة — ' || coalesce(v_product_name_ar, '');
        v_title_en := 'Refill — ' || coalesce(v_product_name_en, '');
      end if;

      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        v_line.id,
        'refill_due'::public.calendar_event_type,
        v_candidate,
        public.build_contract_calendar_source_key(
          p_contract.id, 'refill', v_line.id, v_candidate, null
        ),
        v_metadata,
        v_title_ar,
        v_title_en,
        array[1440, 60]
      );
      v_count := v_count + 1;
    end loop;
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Orchestrator + read + batch + contract status trigger
-- ---------------------------------------------------------------------------
create or replace function public.sync_contract_calendar_events_internal(
  p_contract_id uuid,
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract public.contracts%rowtype;
  v_policy public.first_rental_invoice_policy;
  v_horizon_days int;
  v_horizon_end date;
  v_billing int := 0;
  v_refill int := 0;
  v_effective_end date;
begin
  v_horizon_days := coalesce(
    p_horizon_days,
    public.calendar_default_horizon_days()
  );
  if v_horizon_days < 1 or v_horizon_days > public.calendar_max_horizon_days() then
    raise exception 'validation_failed';
  end if;
  v_horizon_end := current_date + v_horizon_days;

  select *
  into v_contract
  from public.contracts c
  where c.id = p_contract_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_contract.status not in (
    'active'::public.contract_status,
    'suspended'::public.contract_status
  ) then
    return jsonb_build_object('skipped', true, 'reason', 'inactive_status');
  end if;

  v_effective_end := public.resolve_contract_effective_end(v_contract);
  if v_effective_end is not null and v_effective_end < current_date then
    return jsonb_build_object('skipped', true, 'reason', 'past_effective_end');
  end if;

  select ts.first_rental_invoice_policy
  into v_policy
  from public.tenant_settings ts
  where ts.tenant_id = v_contract.tenant_id;

  v_policy := coalesce(v_policy, 'first_billing_day'::public.first_rental_invoice_policy);

  if v_contract.type = 'trial'::public.contract_type
    and v_contract.status in ('active'::public.contract_status, 'suspended'::public.contract_status)
    and v_contract.trial_end_date is not null
    and v_contract.returned_at is null
    and v_contract.closed_at is null
    and v_contract.converted_to_contract_id is null
    and v_contract.trial_end_date >= current_date
    and v_contract.trial_end_date <= v_horizon_end then
    perform public.upsert_contract_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      v_contract.customer_id,
      v_contract.service_location_id,
      null,
      'trial_ending'::public.calendar_event_type,
      v_contract.trial_end_date,
      public.build_contract_calendar_source_key(v_contract.id, 'trial_ending', null, null, null),
      '{}'::jsonb,
      'انتهاء التجربة — ' || v_contract.contract_number,
      'Trial ending — ' || v_contract.contract_number,
      array[10080, 1440, 60]
    );
  end if;

  if v_contract.type = 'rental'::public.contract_type
    and v_contract.status = 'active'::public.contract_status then
    v_billing := public.sync_contract_billing_events_internal(
      v_contract,
      v_policy,
      v_horizon_end
    );
    v_refill := public.sync_contract_refill_events_internal(v_contract, v_horizon_end);
  end if;

  if v_contract.type = 'rental'::public.contract_type
    and v_contract.end_date is not null
    and v_contract.status in ('active'::public.contract_status, 'suspended'::public.contract_status)
    and v_contract.end_date >= current_date
    and v_contract.end_date <= v_horizon_end
    and (v_effective_end is null or v_contract.end_date <= v_effective_end) then
    perform public.upsert_contract_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      v_contract.customer_id,
      v_contract.service_location_id,
      null,
      'contract_end'::public.calendar_event_type,
      v_contract.end_date,
      public.build_contract_calendar_source_key(v_contract.id, 'contract_end', null, null, null),
      '{}'::jsonb,
      'انتهاء العقد — ' || v_contract.contract_number,
      'Contract end — ' || v_contract.contract_number,
      array[10080, 1440, 60]
    );
  end if;

  return jsonb_build_object(
    'contract_id', v_contract.id,
    'horizon_days', v_horizon_days,
    'billing_upserts', v_billing,
    'refill_upserts', v_refill
  );
end;
$$;

create or replace function public.list_contract_upcoming_events_json(
  p_contract_id uuid,
  p_limit int default 10
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

  return coalesce((
    select jsonb_agg(row_data order by (row_data ->> 'scheduled_date')::date)
    from (
      select jsonb_build_object(
        'id', ce.id,
        'type', ce.type,
        'status', ce.status,
        'scheduled_date', ce.scheduled_date,
        'title_ar', ce.title_ar,
        'title_en', ce.title_en,
        'contract_line_id', ce.contract_line_id,
        'product_name_ar', p.name_ar,
        'product_name_en', p.name_en,
        'action_kind', ce.source_metadata ->> 'action_kind',
        'coverage_month_key', ce.source_metadata ->> 'coverage_month_key',
        'days_remaining', (ce.scheduled_date - current_date)
      ) as row_data
      from public.calendar_events ce
      left join public.contract_lines cl
        on cl.id = ce.contract_line_id
        and cl.tenant_id = ce.tenant_id
      left join public.products p
        on p.id = cl.product_id
        and p.tenant_id = ce.tenant_id
      where ce.tenant_id = v_tenant_id
        and ce.contract_id = p_contract_id
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status
        and ce.scheduled_date >= current_date
        and not exists (
          select 1
          from public.rental_invoice_coverages ric
          where ric.tenant_id = ce.tenant_id
            and ric.contract_id = ce.contract_id
            and ric.coverage_month_key = nullif(
              ce.source_metadata ->> 'coverage_month_key',
              ''
            )::date
        )
      order by ce.scheduled_date, ce.id
      limit greatest(coalesce(p_limit, 10), 1)
    ) sub
  ), '[]'::jsonb);
end;
$$;

create or replace function public.sync_tenant_contract_calendar_events(
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_horizon int;
  v_contract_id uuid;
  v_synced int := 0;
  v_results jsonb := '[]'::jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('calendar.edit') then
    raise exception 'permission_denied';
  end if;

  v_horizon := coalesce(p_horizon_days, public.calendar_default_horizon_days());
  if v_horizon < 1 or v_horizon > public.calendar_max_horizon_days() then
    raise exception 'validation_failed';
  end if;

  for v_contract_id in
    select c.id
    from public.contracts c
    where c.tenant_id = v_tenant_id
      and c.status in ('active'::public.contract_status, 'suspended'::public.contract_status)
      and c.closed_at is null
      and c.returned_at is null
  loop
    v_results := v_results || public.sync_contract_calendar_events_internal(v_contract_id, v_horizon);
    v_synced := v_synced + 1;
  end loop;

  return jsonb_build_object(
    'tenant_id', v_tenant_id,
    'horizon_days', v_horizon,
    'contracts_synced', v_synced,
    'results', v_results
  );
end;
$$;

create or replace function public.handle_contract_status_calendar_handoff()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'suspended'::public.contract_status then
    perform public.purge_suspended_contract_billing_refill_events(new.id);
  elsif old.status = 'suspended'::public.contract_status
    and new.status = 'active'::public.contract_status then
    perform public.sync_contract_calendar_events_internal(
      new.id,
      public.calendar_default_horizon_days()
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_contracts_status_calendar_handoff on public.contracts;
create trigger trg_contracts_status_calendar_handoff
  after update of status on public.contracts
  for each row
  when (old.status is distinct from new.status)
  execute function public.handle_contract_status_calendar_handoff();

-- ---------------------------------------------------------------------------
-- Dynamic lifecycle hooks (fail-fast anchors)
-- ---------------------------------------------------------------------------
create or replace function public.m12_assert_single_anchor(
  p_sql text,
  p_anchor text,
  p_label text
)
returns void
language plpgsql
as $$
declare
  v_count int;
begin
  v_count := (
    length(p_sql) - length(replace(p_sql, p_anchor, ''))
  ) / nullif(length(p_anchor), 0);
  if v_count <> 1 then
    raise exception 'M12 patch anchor mismatch (%): expected 1 occurrence, found %',
      p_label, coalesce(v_count, 0);
  end if;
end;
$$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.create_contract_internal(public.contract_type, jsonb, uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(v_sql, E'  return v_contract_id;\n', 'create_contract_internal');
  v_sql := replace(
    v_sql,
    E'  return v_contract_id;\n',
    E'  perform public.sync_contract_calendar_events_internal(v_contract_id, public.calendar_default_horizon_days());\n  return v_contract_id;\n'
  );
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.extend_trial_contract(jsonb, uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''extend_trial'',\n',
    'extend_trial_contract'
  );
  v_sql := replace(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''extend_trial'',\n',
    E'  perform public.sync_contract_calendar_events_internal(v_trial.id, public.calendar_default_horizon_days());\n  perform public.record_contract_lifecycle_operation(\n    ''extend_trial'',\n'
  );
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.return_trial_contract(jsonb, uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''return_trial'',\n',
    'return_trial_contract'
  );
  v_sql := replace(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''return_trial'',\n',
    E'  perform public.cancel_contract_generated_events_terminal(v_trial.id, current_date, ''return'');\n  perform public.record_contract_lifecycle_operation(\n    ''return_trial'',\n'
  );
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.convert_trial_to_rental(jsonb, uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''convert_trial_to_rental'',\n',
    'convert_trial_to_rental'
  );
  v_sql := replace(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''convert_trial_to_rental'',\n',
    E'  perform public.cancel_contract_generated_events_terminal(v_trial.id, current_date, ''convert'');\n  perform public.sync_contract_calendar_events_internal(v_rental_id, public.calendar_default_horizon_days());\n  perform public.record_contract_lifecycle_operation(\n    ''convert_trial_to_rental'',\n'
  );
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
  v_old text := $old$
  update public.calendar_events ce
  set status = 'cancelled'::public.calendar_event_status
  where ce.tenant_id = v_tenant_id
    and ce.contract_id = v_contract.id
    and ce.status = 'pending'::public.calendar_event_status
    and ce.scheduled_date > v_close_date;
$old$;
  v_new text := $new$
  perform public.cancel_contract_generated_events_terminal(v_contract.id, v_close_date, 'close');
$new$;
begin
  select pg_get_functiondef('public.close_contract(jsonb, uuid)'::regprocedure) into v_sql;
  perform public.m12_assert_single_anchor(v_sql, v_old, 'close_contract');
  v_sql := replace(v_sql, v_old, v_new);
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.schedule_contract_consumable_change(jsonb, uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''schedule_consumable_change'',\n',
    'schedule_contract_consumable_change'
  );
  v_sql := replace(
    v_sql,
    E'  perform public.record_contract_lifecycle_operation(\n    ''schedule_consumable_change'',\n',
    E'  perform public.sync_contract_calendar_events_internal(v_contract.id, public.calendar_default_horizon_days());\n  perform public.record_contract_lifecycle_operation(\n    ''schedule_consumable_change'',\n'
  );
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.collect_rental_payment(jsonb, uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(v_sql, E'  return v_result;\n', 'collect_rental_payment');
  v_sql := replace(
    v_sql,
    E'  return v_result;\n',
    E'  perform public.mark_contract_billing_events_done_for_collection(\n    v_contract.id,\n    v_normalized -> ''coverage_months''\n  );\n  return v_result;\n'
  );
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.build_contract_detail_json(uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(
    v_sql,
    E'    ''consumable_lines'', v_consumable_lines\n  );\n',
    'build_contract_detail_json'
  );
  v_sql := replace(
    v_sql,
    E'    ''consumable_lines'', v_consumable_lines\n  );\n',
    E'    ''consumable_lines'', v_consumable_lines,\n    ''upcoming_schedule'', public.list_contract_upcoming_events_json(p_contract_id, 10)\n  );\n'
  );
  execute v_sql;
end $$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.mask_contract_read_json(jsonb)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(
    v_sql,
    E'      ''consumable_lines'', v_consumable_lines\n    )\n  );\n',
    'mask_contract_read_json'
  );
  v_sql := replace(
    v_sql,
    E'      ''consumable_lines'', v_consumable_lines\n    )\n  );\n',
    E'      ''consumable_lines'', v_consumable_lines,\n      ''upcoming_schedule'', coalesce(p_json -> ''upcoming_schedule'', ''[]''::jsonb)\n    )\n  );\n'
  );
  execute v_sql;
end $$;

-- ---------------------------------------------------------------------------
-- Grants / revokes
-- ---------------------------------------------------------------------------
revoke all on function public.sync_contract_calendar_events_internal(uuid, int)
  from public, anon, authenticated;
revoke all on function public.upsert_contract_calendar_event(
  uuid, uuid, uuid, uuid, uuid, public.calendar_event_type, date, text, jsonb, text, text, int[]
) from public, anon, authenticated;
revoke all on function public.cancel_contract_generated_events_terminal(uuid, date, text)
  from public, anon, authenticated;
revoke all on function public.purge_suspended_contract_billing_refill_events(uuid)
  from public, anon, authenticated;
revoke all on function public.mark_contract_billing_events_done_for_coverage(uuid, date)
  from public, anon, authenticated;
revoke all on function public.mark_contract_billing_events_done_for_collection(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.sync_contract_billing_events_internal(
  public.contracts, public.first_rental_invoice_policy, date
) from public, anon, authenticated;
revoke all on function public.sync_contract_refill_events_internal(public.contracts, date)
  from public, anon, authenticated;
revoke all on function public.m12_assert_single_anchor(text, text, text)
  from public, anon, authenticated;

grant execute on function public.sync_tenant_contract_calendar_events(int) to authenticated;
grant execute on function public.list_contract_upcoming_events_json(uuid, int) to authenticated;

