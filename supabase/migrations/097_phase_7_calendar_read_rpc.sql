-- Phase 7 M4: calendar read RPCs, filter/cursor contracts, ACL hardening.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Section A: constants and permission context
-- ---------------------------------------------------------------------------
create or replace function public.calendar_read_max_range_days()
returns int
language sql
immutable
as $$
  select 62;
$$;

create or replace function public.calendar_read_default_page_limit()
returns int
language sql
immutable
as $$
  select 50;
$$;

create or replace function public.calendar_read_max_page_limit()
returns int
language sql
immutable
as $$
  select 100;
$$;

create type public.calendar_read_filter_bundle as (
  event_types public.calendar_event_type[],
  statuses public.calendar_event_status[],
  assigned_agent_id uuid,
  unassigned_only boolean,
  customer_id uuid,
  contract_id uuid,
  service_location_id uuid,
  source_kind public.calendar_event_source_kind,
  working_day_conflict boolean,
  overdue_only boolean,
  search text
);

create type public.calendar_read_scope_context as (
  scope text,
  employee_id uuid
);

create or replace function public.assert_calendar_event_view()
returns public.calendar_read_scope_context
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ctx public.calendar_read_scope_context;
begin
  if public.current_tenant_id() is null then
    raise exception 'tenant_not_found';
  end if;

  if public.is_manager()
    or public.user_has_permission('calendar.view') then
    v_ctx.scope := 'tenant_wide';
    v_ctx.employee_id := null;
    return v_ctx;
  end if;

  if public.user_has_permission('calendar.view_assigned') then
    v_ctx.scope := 'assigned_only';
    v_ctx.employee_id := public.current_employee_id();
    return v_ctx;
  end if;

  raise exception 'permission_denied';
end;
$$;

-- ---------------------------------------------------------------------------
-- Section B: filter parse, normalize, hash
-- ---------------------------------------------------------------------------
create or replace function public.parse_calendar_read_json_boolean(
  p_filters jsonb,
  p_key text,
  p_default boolean default false
)
returns boolean
language plpgsql
immutable
as $$
declare
  v_value jsonb;
begin
  if not coalesce(p_filters ? p_key, false) then
    return p_default;
  end if;

  v_value := p_filters -> p_key;

  if jsonb_typeof(v_value) = 'null' then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(v_value) <> 'boolean' then
    raise exception 'validation_failed';
  end if;

  return v_value::boolean;
end;
$$;

create or replace function public.parse_calendar_read_json_uuid(
  p_filters jsonb,
  p_key text
)
returns uuid
language plpgsql
immutable
as $$
declare
  v_value jsonb;
  v_text text;
begin
  if not coalesce(p_filters ? p_key, false) then
    return null;
  end if;

  v_value := p_filters -> p_key;

  if jsonb_typeof(v_value) = 'null' then
    return null;
  end if;

  if jsonb_typeof(v_value) <> 'string' then
    raise exception 'validation_failed';
  end if;

  v_text := btrim(v_value #>> '{}');

  if v_text = '' then
    raise exception 'validation_failed';
  end if;

  begin
    return v_text::uuid;
  exception
    when others then
      raise exception 'validation_failed';
  end;
end;
$$;

create or replace function public.calendar_read_filters_canonical_json(
  p_filters public.calendar_read_filter_bundle
)
returns jsonb
language sql
immutable
as $$
  select jsonb_strip_nulls(
    jsonb_build_object(
      'event_types',
        case
          when p_filters.event_types is null then null
          else to_jsonb(p_filters.event_types)
        end,
      'statuses',
        case
          when p_filters.statuses is null then null
          else to_jsonb(p_filters.statuses)
        end,
      'assigned_agent_id', p_filters.assigned_agent_id,
      'unassigned_only', case when p_filters.unassigned_only then true else null end,
      'customer_id', p_filters.customer_id,
      'contract_id', p_filters.contract_id,
      'service_location_id', p_filters.service_location_id,
      'source_kind', p_filters.source_kind,
      'working_day_conflict',
        case when p_filters.working_day_conflict then true else null end,
      'overdue_only', case when p_filters.overdue_only then true else null end,
      'search', p_filters.search
    )
  );
$$;

create or replace function public.calendar_read_filters_hash(
  p_filters public.calendar_read_filter_bundle
)
returns text
language sql
stable
set search_path = public, extensions
as $$
  select encode(
    extensions.digest(
      convert_to(public.calendar_read_filters_canonical_json(p_filters)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

create or replace function public.parse_calendar_read_filters(
  p_filters jsonb,
  p_scope text,
  p_employee_id uuid
)
returns public.calendar_read_filter_bundle
language plpgsql
stable
set search_path = public
as $$
declare
  v_filters public.calendar_read_filter_bundle;
  v_key text;
  v_elem jsonb;
  v_elem_text text;
  v_types public.calendar_event_type[] := null;
  v_statuses public.calendar_event_status[] := null;
  v_has_event_types boolean := false;
  v_has_statuses boolean := false;
  v_pending_in_statuses boolean := false;
begin
  if p_filters is null then
    p_filters := '{}'::jsonb;
  end if;

  if jsonb_typeof(p_filters) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_filters) loop
    if v_key not in (
      'event_types',
      'statuses',
      'assigned_agent_id',
      'unassigned_only',
      'customer_id',
      'contract_id',
      'service_location_id',
      'source_kind',
      'working_day_conflict',
      'overdue_only',
      'search'
    ) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if p_filters ? 'event_types' then
    v_has_event_types := true;
    if jsonb_typeof(p_filters -> 'event_types') <> 'array'
      or jsonb_array_length(p_filters -> 'event_types') = 0 then
      raise exception 'validation_failed';
    end if;
    v_types := array[]::public.calendar_event_type[];
    for v_elem in
      select value from jsonb_array_elements(p_filters -> 'event_types')
    loop
      if jsonb_typeof(v_elem) <> 'string' then
        raise exception 'validation_failed';
      end if;
      v_elem_text := btrim(v_elem #>> '{}');
      if v_elem_text = '' then
        raise exception 'validation_failed';
      end if;
      begin
        v_types := v_types || v_elem_text::public.calendar_event_type;
      exception
        when others then
          raise exception 'validation_failed';
      end;
    end loop;
    select coalesce(array_agg(distinct x order by x), array[]::public.calendar_event_type[])
    into v_types
    from unnest(v_types) as x;
    v_filters.event_types := nullif(v_types, array[]::public.calendar_event_type[]);
  end if;

  if p_filters ? 'statuses' then
    v_has_statuses := true;
    if jsonb_typeof(p_filters -> 'statuses') <> 'array'
      or jsonb_array_length(p_filters -> 'statuses') = 0 then
      raise exception 'validation_failed';
    end if;
    v_statuses := array[]::public.calendar_event_status[];
    for v_elem in
      select value from jsonb_array_elements(p_filters -> 'statuses')
    loop
      if jsonb_typeof(v_elem) <> 'string' then
        raise exception 'validation_failed';
      end if;
      v_elem_text := btrim(v_elem #>> '{}');
      if v_elem_text = '' then
        raise exception 'validation_failed';
      end if;
      begin
        v_statuses := v_statuses || v_elem_text::public.calendar_event_status;
      exception
        when others then
          raise exception 'validation_failed';
      end;
    end loop;
    select coalesce(array_agg(distinct x order by x), array[]::public.calendar_event_status[])
    into v_statuses
    from unnest(v_statuses) as x;
    v_filters.statuses := nullif(v_statuses, array[]::public.calendar_event_status[]);
    v_pending_in_statuses := 'pending'::public.calendar_event_status = any (v_filters.statuses);
  end if;

  v_filters.unassigned_only :=
    public.parse_calendar_read_json_boolean(p_filters, 'unassigned_only', false);
  v_filters.working_day_conflict :=
    public.parse_calendar_read_json_boolean(p_filters, 'working_day_conflict', false);
  v_filters.overdue_only :=
    public.parse_calendar_read_json_boolean(p_filters, 'overdue_only', false);

  if p_filters ? 'assigned_agent_id' then
    v_filters.assigned_agent_id :=
      public.parse_calendar_read_json_uuid(p_filters, 'assigned_agent_id');
  end if;

  if p_filters ? 'customer_id' then
    v_filters.customer_id := public.parse_calendar_read_json_uuid(p_filters, 'customer_id');
  end if;

  if p_filters ? 'contract_id' then
    v_filters.contract_id := public.parse_calendar_read_json_uuid(p_filters, 'contract_id');
  end if;

  if p_filters ? 'service_location_id' then
    v_filters.service_location_id :=
      public.parse_calendar_read_json_uuid(p_filters, 'service_location_id');
  end if;

  if p_filters ? 'source_kind' then
    begin
      v_filters.source_kind := (p_filters ->> 'source_kind')::public.calendar_event_source_kind;
    exception
      when others then
        raise exception 'validation_failed';
    end;
  end if;

  if p_filters ? 'search' then
    v_filters.search := nullif(lower(btrim(p_filters ->> 'search')), '');
    if v_filters.search is not null and length(v_filters.search) < 2 then
      raise exception 'validation_failed';
    end if;
  end if;

  if v_filters.unassigned_only and v_filters.assigned_agent_id is not null then
    raise exception 'validation_failed';
  end if;

  if v_filters.overdue_only then
    if v_has_statuses and not v_pending_in_statuses then
      raise exception 'validation_failed';
    end if;
    if not v_has_statuses then
      v_filters.statuses := array['pending'::public.calendar_event_status];
    end if;
  end if;

  if p_scope = 'assigned_only' then
    if v_filters.unassigned_only then
      raise exception 'permission_denied';
    end if;
    if v_filters.assigned_agent_id is not null
      and v_filters.assigned_agent_id is distinct from p_employee_id then
      raise exception 'permission_denied';
    end if;
  end if;

  return v_filters;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section C: ordering and schedule_state helpers
-- ---------------------------------------------------------------------------
create or replace function public.calendar_event_type_sort_rank(
  p_type public.calendar_event_type
)
returns int
language sql
immutable
as $$
  select case p_type
    when 'refill_due' then 1
    when 'billing_due' then 2
    when 'payment_due' then 3
    when 'maintenance_due' then 4
    when 'follow_up' then 5
    when 'trial_ending' then 6
    when 'contract_start' then 7
    when 'contract_end' then 8
    when 'custom' then 9
    else 99
  end;
$$;

create or replace function public.calendar_event_schedule_state(
  p_schedule_configured boolean,
  p_day_mode public.tenant_working_day_mode,
  p_day_off_override_at timestamptz
)
returns text
language sql
immutable
as $$
  select case
    when not coalesce(p_schedule_configured, false)
      or p_day_mode is null then 'schedule_unconfigured'
    when p_day_mode = 'day_off'::public.tenant_working_day_mode
      and p_day_off_override_at is not null then 'day_off_overridden'
    when p_day_mode = 'day_off'::public.tenant_working_day_mode then 'non_working_day'
    else 'working_day'
  end;
$$;

create or replace function public.calendar_event_working_day_json(
  p_tenant_id uuid,
  p_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.resolve_tenant_working_window(p_tenant_id, p_date);
$$;

-- ---------------------------------------------------------------------------
-- Section D: cursor encode/decode and binding validation
-- ---------------------------------------------------------------------------
create or replace function public.decode_calendar_list_cursor(p_cursor text)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_raw text;
  v_json jsonb;
begin
  if p_cursor is null or btrim(p_cursor) = '' then
    raise exception 'validation_failed';
  end if;

  begin
    v_raw := convert_from(decode(p_cursor, 'base64'), 'UTF8');
    v_json := v_raw::jsonb;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if coalesce((v_json ->> 'version')::int, 0) <> 1 then
    raise exception 'validation_failed';
  end if;

  if v_json ->> 'bucket' not in ('in_range', 'overdue_outside_range') then
    raise exception 'validation_failed';
  end if;

  if v_json -> 'last' is null or jsonb_typeof(v_json -> 'last') <> 'object' then
    raise exception 'validation_failed';
  end if;

  return v_json;
end;
$$;

create or replace function public.validate_calendar_list_cursor_binding(
  p_cursor jsonb,
  p_tenant_id uuid,
  p_scope text,
  p_employee_id uuid,
  p_date_from date,
  p_date_to date,
  p_bucket text,
  p_filters_hash text
)
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if (p_cursor ->> 'tenant_id')::uuid is distinct from p_tenant_id then
    raise exception 'validation_failed';
  end if;
  if p_cursor ->> 'scope' is distinct from p_scope then
    raise exception 'validation_failed';
  end if;
  if p_scope = 'assigned_only' then
    if (p_cursor ->> 'employee_id')::uuid is distinct from p_employee_id then
      raise exception 'validation_failed';
    end if;
  elsif p_cursor ->> 'employee_id' is not null then
    raise exception 'validation_failed';
  end if;
  if (p_cursor ->> 'date_from')::date is distinct from p_date_from then
    raise exception 'validation_failed';
  end if;
  if (p_cursor ->> 'date_to')::date is distinct from p_date_to then
    raise exception 'validation_failed';
  end if;
  if p_cursor ->> 'bucket' is distinct from p_bucket then
    raise exception 'validation_failed';
  end if;
  if p_cursor ->> 'filters_hash' is distinct from p_filters_hash then
    raise exception 'validation_failed';
  end if;
end;
$$;

create or replace function public.encode_calendar_list_cursor(p_payload jsonb)
returns text
language sql
immutable
as $$
  select encode(convert_to(p_payload::text, 'UTF8'), 'base64');
$$;

-- ---------------------------------------------------------------------------
-- Section E: scoped events core (static SQL, set-based)
-- ---------------------------------------------------------------------------
create or replace function public.calendar_read_scoped_events(
  p_tenant_id uuid,
  p_scope text,
  p_employee_id uuid,
  p_filters public.calendar_read_filter_bundle,
  p_v_today date
)
returns table (
  event_id uuid,
  scheduled_date date,
  original_due_date date,
  assigned_agent_id uuid,
  event_status public.calendar_event_status,
  is_overdue boolean,
  overdue_days int,
  overdue_state text,
  schedule_state text,
  type_rank int,
  event_json jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  with settings as (
    select
      tcs.tenant_id,
      tcs.working_schedule_configured,
      tcs.timezone_name
    from public.tenant_calendar_settings tcs
    where tcs.tenant_id = p_tenant_id
  ),
  scoped as (
    select
      ce.id,
      ce.scheduled_date,
      ce.original_due_date,
      ce.assigned_agent_id,
      ce.status,
      ce.type,
      ce.source_kind,
      ce.title_ar,
      ce.title_en,
      ce.rescheduled_at,
      ce.customer_id,
      ce.service_location_id,
      ce.contract_id,
      ce.contract_line_id,
      ce.day_off_override_at,
      s.working_schedule_configured,
      twd.day_mode,
      e.name_ar as assigned_agent_name_ar,
      e.name_en as assigned_agent_name_en,
      cu.name_ar as customer_name_ar,
      cu.name_en as customer_name_en,
      csl.name as service_location_name,
      csl.governorate as location_governorate,
      csl.area as location_area,
      csl.latitude,
      csl.longitude,
      c.contract_number,
      cl.qty_per_refill,
      p.name_ar as product_name_ar,
      p.name_en as product_name_en,
      p.unit_primary as qty_unit,
      case
        when ce.status <> 'pending'::public.calendar_event_status then false
        when exists (
          select 1
          from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        ) then false
        when p_v_today is null then false
        when ce.original_due_date < p_v_today then true
        else false
      end as is_overdue_calc,
      case
        when ce.status <> 'pending'::public.calendar_event_status then 'not_applicable'
        when exists (
          select 1
          from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        ) then 'not_applicable'
        when p_v_today is null then 'schedule_unconfigured'
        when ce.original_due_date < p_v_today then 'overdue'
        else 'not_overdue'
      end as overdue_state_calc,
      public.calendar_event_schedule_state(
        s.working_schedule_configured,
        twd.day_mode,
        ce.day_off_override_at
      ) as schedule_state_calc,
      public.calendar_event_type_sort_rank(ce.type) as type_rank_calc,
      f.actual_completion_date,
      f.actual_quantity_delivered,
      f.quantity_unit,
      f.contracted_quantity_per_cycle,
      f.coverage_months,
      f.coverage_days,
      f.calculated_next_due_date,
      f.confirmed_next_due_date,
      f.next_due_overridden,
      ce.source_metadata,
      jsonb_build_object(
        'tenant_id', ce.tenant_id,
        'date', ce.scheduled_date,
        'iso_weekday', extract(isodow from ce.scheduled_date)::int,
        'schedule_configured', s.working_schedule_configured,
        'timezone_name', s.timezone_name,
        'day_mode', twd.day_mode,
        'work_start', to_char(twd.work_start, 'HH24:MI'),
        'work_end', to_char(twd.work_end, 'HH24:MI'),
        'is_unreviewed', twd.day_mode is null,
        'is_day_off', twd.day_mode = 'day_off'::public.tenant_working_day_mode,
        'is_24_hours', twd.day_mode = '24_hours'::public.tenant_working_day_mode,
        'is_working_hours', twd.day_mode = 'working_hours'::public.tenant_working_day_mode
      ) as working_day_json
    from public.calendar_events ce
    cross join settings s
    left join public.tenant_working_days twd
      on twd.tenant_id = ce.tenant_id
      and twd.iso_weekday = extract(isodow from ce.scheduled_date)::int
    left join public.employees e
      on e.id = ce.assigned_agent_id
      and e.tenant_id = ce.tenant_id
    left join public.customers cu
      on cu.id = ce.customer_id
      and cu.tenant_id = ce.tenant_id
    left join public.customer_service_locations csl
      on csl.id = ce.service_location_id
      and csl.tenant_id = ce.tenant_id
      and csl.customer_id = ce.customer_id
    left join public.contracts c
      on c.id = ce.contract_id
      and c.tenant_id = ce.tenant_id
    left join public.contract_lines cl
      on cl.id = ce.contract_line_id
      and cl.tenant_id = ce.tenant_id
    left join public.products p
      on p.id = cl.product_id
      and p.tenant_id = ce.tenant_id
    left join public.calendar_refill_execution_facts f
      on f.calendar_event_id = ce.id
      and f.tenant_id = ce.tenant_id
    where ce.tenant_id = p_tenant_id
      and (
        p_scope = 'tenant_wide'
        or (p_scope = 'assigned_only' and ce.assigned_agent_id = p_employee_id)
      )
      and (
        p_filters.event_types is null
        or ce.type = any (p_filters.event_types)
      )
      and (
        p_filters.statuses is null
        or ce.status = any (p_filters.statuses)
      )
      and (
        not coalesce(p_filters.unassigned_only, false)
        or ce.assigned_agent_id is null
      )
      and (
        p_filters.assigned_agent_id is null
        or ce.assigned_agent_id = p_filters.assigned_agent_id
      )
      and (
        p_filters.customer_id is null
        or (
          ce.customer_id = p_filters.customer_id
          and exists (
            select 1
            from public.customers cx
            where cx.id = p_filters.customer_id
              and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (
        p_filters.contract_id is null
        or (
          ce.contract_id = p_filters.contract_id
          and exists (
            select 1
            from public.contracts cx
            where cx.id = p_filters.contract_id
              and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (
        p_filters.service_location_id is null
        or (
          ce.service_location_id = p_filters.service_location_id
          and exists (
            select 1
            from public.customer_service_locations cx
            where cx.id = p_filters.service_location_id
              and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (
        p_filters.source_kind is null
        or ce.source_kind = p_filters.source_kind
      )
      and (
        not coalesce(p_filters.working_day_conflict, false)
        or public.calendar_event_schedule_state(
          s.working_schedule_configured,
          twd.day_mode,
          ce.day_off_override_at
        ) in ('non_working_day', 'day_off_overridden')
      )
      and (
        not coalesce(p_filters.overdue_only, false)
        or (
          ce.status = 'pending'::public.calendar_event_status
          and p_v_today is not null
          and ce.original_due_date < p_v_today
          and not exists (
            select 1
            from public.calendar_refill_execution_facts fx
            where fx.calendar_event_id = ce.id
          )
        )
      )
      and (
        p_filters.search is null
        or lower(coalesce(ce.title_ar, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(ce.title_en, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(cu.name_ar, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(cu.name_en, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(c.contract_number, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(csl.name, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(e.name_ar, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(e.name_en, '')) like '%' || p_filters.search || '%'
      )
  )
  select
    s.id,
    s.scheduled_date,
    s.original_due_date,
    s.assigned_agent_id,
    s.status,
    s.is_overdue_calc,
    case
      when s.is_overdue_calc and p_v_today is not null
        then (p_v_today - s.original_due_date)
      else 0
    end,
    s.overdue_state_calc,
    s.schedule_state_calc,
    s.type_rank_calc,
    jsonb_strip_nulls(
      jsonb_build_object(
        'id', s.id,
        'type', s.type,
        'status', s.status,
        'source_kind', s.source_kind,
        'scheduled_date', s.scheduled_date,
        'original_due_date', s.original_due_date,
        'title_ar', s.title_ar,
        'title_en', s.title_en,
        'is_rescheduled', s.rescheduled_at is not null,
        'assigned_agent_id', s.assigned_agent_id,
        'assigned_agent_name_ar', s.assigned_agent_name_ar,
        'assigned_agent_name_en', s.assigned_agent_name_en,
        'customer_id', s.customer_id,
        'customer_name_ar', s.customer_name_ar,
        'customer_name_en', s.customer_name_en,
        'service_location_id', s.service_location_id,
        'service_location_name', s.service_location_name,
        'location_governorate', s.location_governorate,
        'location_area', s.location_area,
        'contract_id', s.contract_id,
        'contract_number', s.contract_number,
        'contract_line_id', s.contract_line_id,
        'product_name_ar', s.product_name_ar,
        'product_name_en', s.product_name_en,
        'qty_per_refill', s.qty_per_refill,
        'qty_unit', s.qty_unit,
        'operational_metadata', jsonb_strip_nulls(
          jsonb_build_object(
            'action_kind', s.source_metadata ->> 'action_kind',
            'coverage_month_key', s.source_metadata ->> 'coverage_month_key'
          )
        ),
        'directions_available',
          s.latitude is not null and s.longitude is not null,
        'schedule_state', s.schedule_state_calc,
        'working_day', s.working_day_json,
        'is_overdue', s.is_overdue_calc,
        'overdue_days',
          case
            when s.is_overdue_calc and p_v_today is not null
              then (p_v_today - s.original_due_date)
            else 0
          end,
        'overdue_state', s.overdue_state_calc,
        'available_actions', jsonb_build_object(
          'can_view_customer', public.user_has_permission('customers.view'),
          'can_view_contract', public.user_has_permission('contracts.view'),
          'can_assign', public.user_has_permission('calendar.edit'),
          'can_reschedule', public.user_has_permission('calendar.edit'),
          'can_create_manual', public.user_has_permission('calendar.create'),
          'can_open_directions',
            s.latitude is not null and s.longitude is not null
        )
      )
    ) || jsonb_build_object(
      'execution_summary',
        case
          when s.actual_completion_date is null then null
          else jsonb_build_object(
            'actual_completion_date', s.actual_completion_date,
            'actual_quantity_delivered', s.actual_quantity_delivered,
            'quantity_unit', s.quantity_unit,
            'contracted_quantity_per_cycle', s.contracted_quantity_per_cycle,
            'coverage_months', s.coverage_months,
            'coverage_days', s.coverage_days,
            'calculated_next_due_date', s.calculated_next_due_date,
            'confirmed_next_due_date', s.confirmed_next_due_date,
            'next_due_overridden', s.next_due_overridden
          )
        end
    )
  from scoped s;
$$;

-- ---------------------------------------------------------------------------
-- Section F: get_calendar_range_summary
-- ---------------------------------------------------------------------------
create or replace function public.get_calendar_range_summary(
  p_date_from date,
  p_date_to date,
  p_filters jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ctx public.calendar_read_scope_context;
  v_tenant_id uuid;
  v_filters public.calendar_read_filter_bundle;
  v_filters_hash text;
  v_today date;
  v_settings public.tenant_calendar_settings%rowtype;
  v_days jsonb;
  v_overdue jsonb;
  v_span int;
begin
  v_ctx := public.assert_calendar_event_view();
  v_tenant_id := public.current_tenant_id();
  v_filters := public.parse_calendar_read_filters(
    p_filters,
    v_ctx.scope,
    v_ctx.employee_id
  );
  v_filters_hash := public.calendar_read_filters_hash(v_filters);

  if p_date_from is null or p_date_to is null or p_date_from > p_date_to then
    raise exception 'validation_failed';
  end if;

  v_span := (p_date_to - p_date_from + 1);
  if v_span < 1 or v_span > public.calendar_read_max_range_days() then
    raise exception 'validation_failed';
  end if;

  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = v_tenant_id;

  v_today := public.tenant_local_today(v_tenant_id);

  with scoped as (
    select *
    from public.calendar_read_scoped_events(
      v_tenant_id,
      v_ctx.scope,
      v_ctx.employee_id,
      v_filters,
      v_today
    )
  ),
  day_counts as (
    select
      s.scheduled_date as d,
      count(*)::int as event_count,
      count(*) filter (where s.assigned_agent_id is null)::int as unassigned_count,
      count(*) filter (where s.is_overdue)::int as overdue_count
    from scoped s
    where s.scheduled_date between p_date_from and p_date_to
    group by s.scheduled_date
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'date', gs.d::date,
        'iso_weekday', extract(isodow from gs.d)::int,
        'event_count', coalesce(dc.event_count, 0),
        'unassigned_count',
          case
            when v_ctx.scope = 'assigned_only' then null
            else coalesce(dc.unassigned_count, 0)
          end,
        'overdue_count', coalesce(dc.overdue_count, 0),
        'working_day', public.resolve_tenant_working_window(v_tenant_id, gs.d::date)
      )
      order by gs.d::date
    ),
    '[]'::jsonb
  )
  into v_days
  from generate_series(p_date_from, p_date_to, interval '1 day') as gs(d)
  left join day_counts dc on dc.d = gs.d::date;

  if v_today is null then
    v_overdue := jsonb_build_object(
      'state', 'schedule_unconfigured',
      'count', null,
      'oldest_original_due_date', null
    );
  else
    with scoped as (
      select *
      from public.calendar_read_scoped_events(
        v_tenant_id,
        v_ctx.scope,
        v_ctx.employee_id,
        v_filters,
        v_today
      )
    )
    select jsonb_build_object(
      'state', 'available',
      'count', coalesce(count(*) filter (where s.scheduled_date < p_date_from and s.is_overdue), 0),
      'oldest_original_due_date',
        min(s.original_due_date) filter (where s.scheduled_date < p_date_from and s.is_overdue)
    )
    into v_overdue
    from scoped s;
  end if;

  return jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'timezone_name', v_settings.timezone_name,
    'working_schedule_configured', coalesce(v_settings.working_schedule_configured, false),
    'tenant_local_today', v_today,
    'scope', v_ctx.scope,
    'filters_hash', v_filters_hash,
    'days', v_days,
    'overdue_outside_range', v_overdue,
    'filters_applied', public.calendar_read_filters_canonical_json(v_filters)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section G: list_calendar_events
-- ---------------------------------------------------------------------------
create or replace function public.list_calendar_events(
  p_date_from date,
  p_date_to date,
  p_filters jsonb default '{}'::jsonb,
  p_cursor_in_range text default null,
  p_cursor_overdue text default null,
  p_limit int default null,
  p_include_overdue_outside_range boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ctx public.calendar_read_scope_context;
  v_tenant_id uuid;
  v_filters public.calendar_read_filter_bundle;
  v_filters_hash text;
  v_today date;
  v_limit int;
  v_in_rows jsonb := '[]'::jsonb;
  v_overdue_rows jsonb := '[]'::jsonb;
  v_in_next text := null;
  v_overdue_next text := null;
  v_in_has_more boolean := false;
  v_overdue_has_more boolean := false;
  v_last record;
  v_span int;
  v_cursor_in jsonb;
  v_cursor_overdue jsonb;
begin
  v_ctx := public.assert_calendar_event_view();
  v_tenant_id := public.current_tenant_id();
  v_filters := public.parse_calendar_read_filters(
    p_filters,
    v_ctx.scope,
    v_ctx.employee_id
  );
  v_filters_hash := public.calendar_read_filters_hash(v_filters);

  if p_date_from is null or p_date_to is null or p_date_from > p_date_to then
    raise exception 'validation_failed';
  end if;

  v_span := (p_date_to - p_date_from + 1);
  if v_span < 1 or v_span > public.calendar_read_max_range_days() then
    raise exception 'validation_failed';
  end if;

  v_limit := greatest(
    least(coalesce(p_limit, public.calendar_read_default_page_limit()), public.calendar_read_max_page_limit()),
    1
  );

  if p_cursor_overdue is not null and not coalesce(p_include_overdue_outside_range, false) then
    raise exception 'validation_failed';
  end if;

  v_today := public.tenant_local_today(v_tenant_id);

  if p_cursor_in_range is not null then
    v_cursor_in := public.decode_calendar_list_cursor(p_cursor_in_range);
    perform public.validate_calendar_list_cursor_binding(
      v_cursor_in,
      v_tenant_id,
      v_ctx.scope,
      v_ctx.employee_id,
      p_date_from,
      p_date_to,
      'in_range',
      v_filters_hash
    );
  end if;

  if p_cursor_overdue is not null then
    v_cursor_overdue := public.decode_calendar_list_cursor(p_cursor_overdue);
    perform public.validate_calendar_list_cursor_binding(
      v_cursor_overdue,
      v_tenant_id,
      v_ctx.scope,
      v_ctx.employee_id,
      p_date_from,
      p_date_to,
      'overdue_outside_range',
      v_filters_hash
    );
  end if;

  with scoped as (
    select *
    from public.calendar_read_scoped_events(
      v_tenant_id,
      v_ctx.scope,
      v_ctx.employee_id,
      v_filters,
      v_today
    )
  ),
  in_candidates as (
    select s.*
    from scoped s
    where s.scheduled_date between p_date_from and p_date_to
      and (
        v_cursor_in is null
        or (
          s.scheduled_date,
          s.type_rank,
          s.event_id
        ) > (
          (v_cursor_in -> 'last' ->> 'scheduled_date')::date,
          (v_cursor_in -> 'last' ->> 'type_rank')::int,
          (v_cursor_in -> 'last' ->> 'id')::uuid
        )
      )
    order by s.scheduled_date asc, s.type_rank asc, s.event_id asc
    limit v_limit + 1
  )
  select
    coalesce(
      (
        select jsonb_agg(ic.event_json order by ic.scheduled_date, ic.type_rank, ic.event_id)
        from (
          select *
          from in_candidates
          limit v_limit
        ) ic
      ),
      '[]'::jsonb
    ),
    (select count(*) > v_limit from in_candidates)
  into v_in_rows, v_in_has_more;

  if v_in_has_more then
    select ic.scheduled_date, ic.type_rank, ic.event_id, ic.event_json
    into v_last
    from (
      select *
      from (
        select s.*
        from public.calendar_read_scoped_events(
          v_tenant_id,
          v_ctx.scope,
          v_ctx.employee_id,
          v_filters,
          v_today
        ) s
        where s.scheduled_date between p_date_from and p_date_to
          and (
            v_cursor_in is null
            or (
              s.scheduled_date,
              s.type_rank,
              s.event_id
            ) > (
              (v_cursor_in -> 'last' ->> 'scheduled_date')::date,
              (v_cursor_in -> 'last' ->> 'type_rank')::int,
              (v_cursor_in -> 'last' ->> 'id')::uuid
            )
          )
        order by s.scheduled_date asc, s.type_rank asc, s.event_id asc
        limit v_limit
      ) page
      order by page.scheduled_date desc, page.type_rank desc, page.event_id desc
      limit 1
    ) ic;
    v_in_next := public.encode_calendar_list_cursor(
      jsonb_build_object(
        'version', 1,
        'tenant_id', v_tenant_id,
        'scope', v_ctx.scope,
        'employee_id', v_ctx.employee_id,
        'bucket', 'in_range',
        'date_from', p_date_from,
        'date_to', p_date_to,
        'filters_hash', v_filters_hash,
        'last', jsonb_build_object(
          'scheduled_date', v_last.scheduled_date,
          'type_rank', v_last.type_rank,
          'id', v_last.event_id
        )
      )
    );
  end if;

  if coalesce(p_include_overdue_outside_range, false) then
    with scoped as (
      select *
      from public.calendar_read_scoped_events(
        v_tenant_id,
        v_ctx.scope,
        v_ctx.employee_id,
        v_filters,
        v_today
      )
    ),
    overdue_candidates as (
      select s.*
      from scoped s
      where s.scheduled_date < p_date_from
        and s.is_overdue
        and (
          v_cursor_overdue is null
          or (
            s.original_due_date,
            s.scheduled_date,
            s.type_rank,
            s.event_id
          ) > (
            (v_cursor_overdue -> 'last' ->> 'original_due_date')::date,
            (v_cursor_overdue -> 'last' ->> 'scheduled_date')::date,
            (v_cursor_overdue -> 'last' ->> 'type_rank')::int,
            (v_cursor_overdue -> 'last' ->> 'id')::uuid
          )
        )
      order by s.original_due_date asc, s.scheduled_date asc, s.type_rank asc, s.event_id asc
      limit v_limit + 1
    )
    select
      coalesce(
        (
          select jsonb_agg(oc.event_json order by oc.original_due_date, oc.scheduled_date, oc.type_rank, oc.event_id)
          from (
            select *
            from overdue_candidates
            limit v_limit
          ) oc
        ),
        '[]'::jsonb
      ),
      (select count(*) > v_limit from overdue_candidates)
    into v_overdue_rows, v_overdue_has_more;

    if v_overdue_has_more then
      select oc.original_due_date, oc.scheduled_date, oc.type_rank, oc.event_id
      into v_last
      from (
        select *
        from (
          select s.*
          from public.calendar_read_scoped_events(
            v_tenant_id,
            v_ctx.scope,
            v_ctx.employee_id,
            v_filters,
            v_today
          ) s
          where s.scheduled_date < p_date_from
            and s.is_overdue
            and (
              v_cursor_overdue is null
              or (
                s.original_due_date,
                s.scheduled_date,
                s.type_rank,
                s.event_id
              ) > (
                (v_cursor_overdue -> 'last' ->> 'original_due_date')::date,
                (v_cursor_overdue -> 'last' ->> 'scheduled_date')::date,
                (v_cursor_overdue -> 'last' ->> 'type_rank')::int,
                (v_cursor_overdue -> 'last' ->> 'id')::uuid
              )
            )
          order by s.original_due_date asc, s.scheduled_date asc, s.type_rank asc, s.event_id asc
          limit v_limit
        ) page
        order by page.original_due_date desc, page.scheduled_date desc, page.type_rank desc, page.event_id desc
        limit 1
      ) oc;
      v_overdue_next := public.encode_calendar_list_cursor(
        jsonb_build_object(
          'version', 1,
          'tenant_id', v_tenant_id,
          'scope', v_ctx.scope,
          'employee_id', v_ctx.employee_id,
          'bucket', 'overdue_outside_range',
          'date_from', p_date_from,
          'date_to', p_date_to,
          'filters_hash', v_filters_hash,
          'last', jsonb_build_object(
            'original_due_date', v_last.original_due_date,
            'scheduled_date', v_last.scheduled_date,
            'type_rank', v_last.type_rank,
            'id', v_last.event_id
          )
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'limit', v_limit,
    'scope', v_ctx.scope,
    'tenant_local_today', v_today,
    'filters_hash', v_filters_hash,
    'in_range', jsonb_build_object(
      'rows', coalesce(v_in_rows, '[]'::jsonb),
      'next_cursor', v_in_next,
      'has_more', coalesce(v_in_has_more, false)
    ),
    'overdue_outside_range', jsonb_build_object(
      'rows', coalesce(v_overdue_rows, '[]'::jsonb),
      'next_cursor', v_overdue_next,
      'has_more', coalesce(v_overdue_has_more, false)
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section H: list_contract_upcoming_events_json hardening (mandatory)
-- ---------------------------------------------------------------------------
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
  v_today date;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  v_today := public.tenant_local_today(v_tenant_id);
  if v_today is null then
    return '[]'::jsonb;
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
        'days_remaining', (ce.scheduled_date - v_today)
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
        and ce.scheduled_date >= v_today
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

-- ---------------------------------------------------------------------------
-- Section I: ACL hardening
-- ---------------------------------------------------------------------------
revoke select on table public.calendar_events from authenticated, anon;

revoke all on function public.list_contract_upcoming_events_json(uuid, int)
  from public, anon, authenticated;

revoke all on function public.parse_calendar_read_json_boolean(jsonb, text, boolean)
  from public, anon, authenticated;
revoke all on function public.parse_calendar_read_json_uuid(jsonb, text)
  from public, anon, authenticated;
revoke all on function public.assert_calendar_event_view() from public, anon, authenticated;
revoke all on function public.calendar_read_filters_canonical_json(public.calendar_read_filter_bundle)
  from public, anon, authenticated;
revoke all on function public.calendar_read_filters_hash(public.calendar_read_filter_bundle)
  from public, anon, authenticated;
revoke all on function public.parse_calendar_read_filters(jsonb, text, uuid)
  from public, anon, authenticated;
revoke all on function public.calendar_event_type_sort_rank(public.calendar_event_type)
  from public, anon, authenticated;
revoke all on function public.calendar_event_schedule_state(boolean, public.tenant_working_day_mode, timestamptz)
  from public, anon, authenticated;
revoke all on function public.calendar_event_working_day_json(uuid, date)
  from public, anon, authenticated;
revoke all on function public.decode_calendar_list_cursor(text)
  from public, anon, authenticated;
revoke all on function public.validate_calendar_list_cursor_binding(jsonb, uuid, text, uuid, date, date, text, text)
  from public, anon, authenticated;
revoke all on function public.encode_calendar_list_cursor(jsonb)
  from public, anon, authenticated;
revoke all on function public.calendar_read_scoped_events(uuid, text, uuid, public.calendar_read_filter_bundle, date)
  from public, anon, authenticated;

grant execute on function public.get_calendar_range_summary(date, date, jsonb) to authenticated;
grant execute on function public.list_calendar_events(date, date, jsonb, text, text, int, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Section J: postflight asserts
-- ---------------------------------------------------------------------------
do $$
begin
  if has_table_privilege('authenticated', 'public.calendar_events', 'SELECT') then
    raise exception 'M4 postflight failed: authenticated can SELECT calendar_events';
  end if;

  if has_function_privilege('authenticated', 'public.list_contract_upcoming_events_json(uuid, int)', 'EXECUTE') then
    raise exception 'M4 postflight failed: authenticated can EXECUTE list_contract_upcoming_events_json';
  end if;

  if not has_function_privilege('authenticated', 'public.get_calendar_range_summary(date, date, jsonb)', 'EXECUTE') then
    raise exception 'M4 postflight failed: get_calendar_range_summary not granted';
  end if;

  if not has_function_privilege('authenticated', 'public.list_calendar_events(date, date, jsonb, text, text, int, boolean)', 'EXECUTE') then
    raise exception 'M4 postflight failed: list_calendar_events not granted';
  end if;

  if (
    select pg_get_function_result(
      'public.calendar_read_scoped_events(uuid, text, uuid, public.calendar_read_filter_bundle, date)'::regprocedure
    )::text ilike '%source_key%'
  ) then
    raise exception 'M4 postflight failed: scoped events expose source_key';
  end if;
end $$;
