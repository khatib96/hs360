-- Phase 7 M11 hardening (evidence-gated).
-- Before (clean 5k measured + noise, PG 17.6 local Docker):
--   list_calendar_events median≈1460ms p95≈1487ms (ceiling 3000 — pass)
--   get_calendar_range_summary median≈1457ms p95≈1475ms (ceiling 1000 — FAIL)
-- Root cause: unbound calendar_read_scoped_events builds full event_json for
-- every tenant row; range summary invoked it twice. Raw date-window count ≈1–2ms.
-- Changes: composite index; date-bounded scoped_events; summary_facts path;
-- list + route_day pass date bounds.

create index if not exists idx_calendar_events_tenant_scheduled_date
  on public.calendar_events (tenant_id, scheduled_date);

create or replace function public.calendar_read_scoped_events(
  p_tenant_id uuid,
  p_scope text,
  p_employee_id uuid,
  p_filters public.calendar_read_filter_bundle,
  p_v_today date,
  p_date_from date,
  p_date_to date
)
returns table (
  event_id uuid,
  scheduled_date date,
  original_due_date date,
  scheduled_start_at timestamptz,
  time_bucket int,
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
as $scoped$
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
      ce.scheduled_start_at,
      ce.scheduled_end_at,
      ce.scheduled_timezone_name,
      case when ce.scheduled_start_at is not null then 0 else 1 end as time_bucket_calc,
      ce.assigned_agent_id,
      ce.status,
      ce.type,
      ce.source_kind,
      ce.title_ar,
      ce.title_en,
      ce.notes,
      ce.rescheduled_at,
      ce.customer_id,
      ce.service_location_id,
      ce.contract_id,
      ce.contract_line_id,
      ce.day_off_override_at,
      ce.free_text_team,
      ce.free_text_location,
      ce.meeting_mode,
      ce.meeting_url,
      ce.schedule_version,
      ce.created_by,
      ce.cancellation_reason,
      e.name_ar as assigned_agent_name_ar,
      e.name_en as assigned_agent_name_en,
      cu.name_ar as customer_name_ar,
      cu.name_en as customer_name_en,
      csl.name as service_location_name,
      csl.governorate as location_governorate,
      csl.area as location_area,
      csl.latitude,
      csl.longitude,
      csl.google_maps_url,
      c.contract_number,
      cl.qty_per_refill,
      p.name_ar as product_name_ar,
      p.name_en as product_name_en,
      p.unit_primary as qty_unit,
      case
        when ce.status <> 'pending'::public.calendar_event_status then false
        when exists (
          select 1 from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        ) then false
        when p_v_today is null then false
        when ce.original_due_date < p_v_today then true
        else false
      end as is_overdue_calc,
      case
        when ce.status <> 'pending'::public.calendar_event_status then 'not_applicable'
        when exists (
          select 1 from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        ) then 'not_applicable'
        when p_v_today is null then 'schedule_unconfigured'
        when ce.original_due_date < p_v_today then 'overdue'
        else 'not_overdue'
      end as overdue_state_calc,
      public.calendar_event_schedule_state(
        coalesce((rw.w ->> 'schedule_configured')::boolean, false),
        case
          when rw.w ->> 'day_mode' is null then null
          else (rw.w ->> 'day_mode')::public.tenant_working_day_mode
        end,
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
      rw.w as working_day_json,
      public.calendar_event_participants_json(ce.tenant_id, ce.id) as participants_json,
      public.calendar_event_time_window_json(
        ce.scheduled_start_at, ce.scheduled_end_at, ce.scheduled_timezone_name
      ) as time_window_json
    from public.calendar_events ce
    cross join settings s
    left join lateral (
      select public.resolve_tenant_working_window(ce.tenant_id, ce.scheduled_date) as w
    ) rw on true
    left join public.employees e
      on e.id = ce.assigned_agent_id and e.tenant_id = ce.tenant_id
    left join public.customers cu
      on cu.id = ce.customer_id and cu.tenant_id = ce.tenant_id
    left join public.customer_service_locations csl
      on csl.id = ce.service_location_id
      and csl.tenant_id = ce.tenant_id
      and csl.customer_id = ce.customer_id
    left join public.contracts c
      on c.id = ce.contract_id and c.tenant_id = ce.tenant_id
    left join public.contract_lines cl
      on cl.id = ce.contract_line_id and cl.tenant_id = ce.tenant_id
    left join public.products p
      on p.id = cl.product_id and p.tenant_id = ce.tenant_id
    left join public.calendar_refill_execution_facts f
      on f.calendar_event_id = ce.id and f.tenant_id = ce.tenant_id
    where ce.tenant_id = p_tenant_id
      and (
        p_scope = 'tenant_wide'
        or (
          p_scope = 'assigned_only'
          and (
            ce.assigned_agent_id = p_employee_id
            or exists (
              select 1 from public.calendar_event_participants ep
              where ep.tenant_id = ce.tenant_id
                and ep.event_id = ce.id
                and ep.employee_id = p_employee_id
            )
            or (
              ce.source_kind = 'manual'::public.calendar_event_source_kind
              and ce.created_by = auth.uid()
            )
          )
        )
      )
      and (p_filters.event_types is null or ce.type = any (p_filters.event_types))
      and (p_filters.statuses is null or ce.status = any (p_filters.statuses))
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
            select 1 from public.customers cx
            where cx.id = p_filters.customer_id and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (
        p_filters.contract_id is null
        or (
          ce.contract_id = p_filters.contract_id
          and exists (
            select 1 from public.contracts cx
            where cx.id = p_filters.contract_id and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (
        p_filters.service_location_id is null
        or (
          ce.service_location_id = p_filters.service_location_id
          and exists (
            select 1 from public.customer_service_locations cx
            where cx.id = p_filters.service_location_id and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (p_filters.source_kind is null or ce.source_kind = p_filters.source_kind)
      and (
        not coalesce(p_filters.working_day_conflict, false)
        or public.calendar_event_schedule_state(
          coalesce((rw.w ->> 'schedule_configured')::boolean, false),
          case
            when rw.w ->> 'day_mode' is null then null
            else (rw.w ->> 'day_mode')::public.tenant_working_day_mode
          end,
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
            select 1 from public.calendar_refill_execution_facts fx
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
      and (p_date_from is null or ce.scheduled_date >= p_date_from)
      and (p_date_to is null or ce.scheduled_date <= p_date_to)
  )
  select
    s.id,
    s.scheduled_date,
    s.original_due_date,
    s.scheduled_start_at,
    s.time_bucket_calc,
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
    (
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
          'notes', s.notes,
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
          'free_text_team', s.free_text_team,
          'free_text_location', s.free_text_location,
          'meeting_mode', s.meeting_mode,
          'meeting_url', s.meeting_url,
          'cancellation_reason', s.cancellation_reason,
          'operational_metadata', jsonb_strip_nulls(
            jsonb_build_object(
              'action_kind', s.source_metadata ->> 'action_kind',
              'coverage_month_key', s.source_metadata ->> 'coverage_month_key'
            )
          ),
          'directions_available',
            public.calendar_directions_available_from_location(
              s.latitude, s.longitude, s.google_maps_url
            ),
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
          'available_actions', public.calendar_manual_available_actions_json(
            (select ce from public.calendar_events ce where ce.id = s.id),
            public.calendar_directions_available_from_location(
              s.latitude, s.longitude, s.google_maps_url
            )
          )
        )
      )
      || jsonb_build_object(
        'time_window', s.time_window_json,
        'participants', coalesce(s.participants_json, '[]'::jsonb),
        'schedule_version', s.schedule_version,
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
    )
  from scoped s;
$scoped$;


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
  scheduled_start_at timestamptz,
  time_bucket int,
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
as $wrap$
  select *
  from public.calendar_read_scoped_events(
    p_tenant_id, p_scope, p_employee_id, p_filters, p_v_today, null, null
  );
$wrap$;


create or replace function public.calendar_read_summary_facts(
  p_tenant_id uuid,
  p_scope text,
  p_employee_id uuid,
  p_filters public.calendar_read_filter_bundle,
  p_v_today date,
  p_date_from date,
  p_date_to date
)
returns table (
  scheduled_date date,
  original_due_date date,
  assigned_agent_id uuid,
  is_overdue boolean
)
language sql
stable
security definer
set search_path = public
as $facts$
  select
    ce.scheduled_date,
    ce.original_due_date,
    ce.assigned_agent_id,
    case
      when ce.status <> 'pending'::public.calendar_event_status then false
      when exists (
        select 1 from public.calendar_refill_execution_facts f
        where f.calendar_event_id = ce.id
      ) then false
      when p_v_today is null then false
      when ce.original_due_date < p_v_today then true
      else false
    end as is_overdue
  from public.calendar_events ce
  left join lateral (
    select public.resolve_tenant_working_window(ce.tenant_id, ce.scheduled_date) as w
  ) rw on coalesce(p_filters.working_day_conflict, false)
  left join public.customers cu
    on p_filters.search is not null
   and cu.id = ce.customer_id and cu.tenant_id = ce.tenant_id
  left join public.customer_service_locations csl
    on p_filters.search is not null
   and csl.id = ce.service_location_id
   and csl.tenant_id = ce.tenant_id
   and csl.customer_id = ce.customer_id
  left join public.contracts c
    on p_filters.search is not null
   and c.id = ce.contract_id and c.tenant_id = ce.tenant_id
  left join public.employees e
    on p_filters.search is not null
   and e.id = ce.assigned_agent_id and e.tenant_id = ce.tenant_id
  where ce.tenant_id = p_tenant_id
    and (
      p_scope = 'tenant_wide'
      or (
        p_scope = 'assigned_only'
        and (
          ce.assigned_agent_id = p_employee_id
          or exists (
            select 1 from public.calendar_event_participants ep
            where ep.tenant_id = ce.tenant_id
              and ep.event_id = ce.id
              and ep.employee_id = p_employee_id
          )
          or (
            ce.source_kind = 'manual'::public.calendar_event_source_kind
            and ce.created_by = auth.uid()
          )
        )
      )
    )
    and (p_filters.event_types is null or ce.type = any (p_filters.event_types))
    and (p_filters.statuses is null or ce.status = any (p_filters.statuses))
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
          select 1 from public.customers cx
          where cx.id = p_filters.customer_id and cx.tenant_id = p_tenant_id
        )
      )
    )
    and (
      p_filters.contract_id is null
      or (
        ce.contract_id = p_filters.contract_id
        and exists (
          select 1 from public.contracts cx
          where cx.id = p_filters.contract_id and cx.tenant_id = p_tenant_id
        )
      )
    )
    and (
      p_filters.service_location_id is null
      or (
        ce.service_location_id = p_filters.service_location_id
        and exists (
          select 1 from public.customer_service_locations cx
          where cx.id = p_filters.service_location_id and cx.tenant_id = p_tenant_id
        )
      )
    )
    and (p_filters.source_kind is null or ce.source_kind = p_filters.source_kind)
    and (
      not coalesce(p_filters.working_day_conflict, false)
      or public.calendar_event_schedule_state(
        coalesce((rw.w ->> 'schedule_configured')::boolean, false),
        case
          when rw.w ->> 'day_mode' is null then null
          else (rw.w ->> 'day_mode')::public.tenant_working_day_mode
        end,
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
          select 1 from public.calendar_refill_execution_facts fx
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
    and (p_date_from is null or ce.scheduled_date >= p_date_from)
    and (p_date_to is null or ce.scheduled_date <= p_date_to);
$facts$;

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
as $summary$
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
    p_filters, v_ctx.scope, v_ctx.employee_id
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

  with facts as (
    select *
    from public.calendar_read_summary_facts(
      v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today,
      p_date_from, p_date_to
    )
  ),
  day_counts as (
    select
      f.scheduled_date as d,
      count(*)::int as event_count,
      count(*) filter (where f.assigned_agent_id is null)::int as unassigned_count,
      count(*) filter (where f.is_overdue)::int as overdue_count
    from facts f
    group by f.scheduled_date
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
    select jsonb_build_object(
      'state', 'available',
      'count', coalesce(count(*), 0),
      'oldest_original_due_date', min(f.original_due_date)
    )
    into v_overdue
    from public.calendar_read_summary_facts(
      v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today,
      null, p_date_from - 1
    ) f
    where f.is_overdue;
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
$summary$;

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
as $list$
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
    p_filters, v_ctx.scope, v_ctx.employee_id
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
    least(
      coalesce(p_limit, public.calendar_read_default_page_limit()),
      public.calendar_read_max_page_limit()
    ),
    1
  );

  if p_cursor_overdue is not null and not coalesce(p_include_overdue_outside_range, false) then
    raise exception 'validation_failed';
  end if;

  v_today := public.tenant_local_today(v_tenant_id);

  if p_cursor_in_range is not null then
    v_cursor_in := public.decode_calendar_list_cursor(p_cursor_in_range);
    perform public.validate_calendar_list_cursor_binding(
      v_cursor_in, v_tenant_id, v_ctx.scope, v_ctx.employee_id,
      p_date_from, p_date_to, 'in_range', v_filters_hash
    );
  end if;

  if p_cursor_overdue is not null then
    v_cursor_overdue := public.decode_calendar_list_cursor(p_cursor_overdue);
    perform public.validate_calendar_list_cursor_binding(
      v_cursor_overdue, v_tenant_id, v_ctx.scope, v_ctx.employee_id,
      p_date_from, p_date_to, 'overdue_outside_range', v_filters_hash
    );
  end if;

  with scoped as (
    select * from public.calendar_read_scoped_events(
      v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today,
      p_date_from, p_date_to
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
          s.time_bucket,
          coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
          s.type_rank,
          s.event_id
        ) > (
          (v_cursor_in -> 'last' ->> 'scheduled_date')::date,
          (v_cursor_in -> 'last' ->> 'time_bucket')::int,
          coalesce(
            nullif(v_cursor_in -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
            '-infinity'::timestamptz
          ),
          (v_cursor_in -> 'last' ->> 'type_rank')::int,
          (v_cursor_in -> 'last' ->> 'event_id')::uuid
        )
      )
    order by
      s.scheduled_date asc,
      s.time_bucket asc,
      s.scheduled_start_at asc nulls last,
      s.type_rank asc,
      s.event_id asc
    limit v_limit + 1
  )
  select
    coalesce(
      (
        select jsonb_agg(
          ic.event_json
          order by
            ic.scheduled_date,
            ic.time_bucket,
            ic.scheduled_start_at nulls last,
            ic.type_rank,
            ic.event_id
        )
        from (select * from in_candidates limit v_limit) ic
      ),
      '[]'::jsonb
    ),
    (select count(*) > v_limit from in_candidates)
  into v_in_rows, v_in_has_more;

  if v_in_has_more then
    select
      page.scheduled_date,
      page.time_bucket,
      page.scheduled_start_at,
      page.type_rank,
      page.event_id
    into v_last
    from (
      select s.*
      from public.calendar_read_scoped_events(
        v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today,
        p_date_from, p_date_to
      ) s
      where s.scheduled_date between p_date_from and p_date_to
        and (
          v_cursor_in is null
          or (
            s.scheduled_date,
            s.time_bucket,
            coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
            s.type_rank,
            s.event_id
          ) > (
            (v_cursor_in -> 'last' ->> 'scheduled_date')::date,
            (v_cursor_in -> 'last' ->> 'time_bucket')::int,
            coalesce(
              nullif(v_cursor_in -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
              '-infinity'::timestamptz
            ),
            (v_cursor_in -> 'last' ->> 'type_rank')::int,
            (v_cursor_in -> 'last' ->> 'event_id')::uuid
          )
        )
      order by
        s.scheduled_date asc,
        s.time_bucket asc,
        s.scheduled_start_at asc nulls last,
        s.type_rank asc,
        s.event_id asc
      limit v_limit
    ) page
    order by
      page.scheduled_date desc,
      page.time_bucket desc,
      page.scheduled_start_at desc nulls first,
      page.type_rank desc,
      page.event_id desc
    limit 1;

    v_in_next := public.encode_calendar_list_cursor(
      jsonb_build_object(
        'version', 2,
        'tenant_id', v_tenant_id,
        'scope', v_ctx.scope,
        'employee_id', v_ctx.employee_id,
        'bucket', 'in_range',
        'date_from', p_date_from,
        'date_to', p_date_to,
        'filters_hash', v_filters_hash,
        'last', jsonb_build_object(
          'bucket', 'in_range',
          'scheduled_date', v_last.scheduled_date,
          'time_bucket', v_last.time_bucket,
          'scheduled_start_at', v_last.scheduled_start_at,
          'type_rank', v_last.type_rank,
          'event_id', v_last.event_id
        )
      )
    );
  end if;

  if coalesce(p_include_overdue_outside_range, false) then
    with scoped as (
      select * from public.calendar_read_scoped_events(
        v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today,
        null, p_date_from - 1
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
            s.time_bucket,
            coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
            s.type_rank,
            s.event_id
          ) > (
            (v_cursor_overdue -> 'last' ->> 'original_due_date')::date,
            (v_cursor_overdue -> 'last' ->> 'scheduled_date')::date,
            (v_cursor_overdue -> 'last' ->> 'time_bucket')::int,
            coalesce(
              nullif(v_cursor_overdue -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
              '-infinity'::timestamptz
            ),
            (v_cursor_overdue -> 'last' ->> 'type_rank')::int,
            (v_cursor_overdue -> 'last' ->> 'event_id')::uuid
          )
        )
      order by
        s.original_due_date asc,
        s.scheduled_date asc,
        s.time_bucket asc,
        s.scheduled_start_at asc nulls last,
        s.type_rank asc,
        s.event_id asc
      limit v_limit + 1
    )
    select
      coalesce(
        (
          select jsonb_agg(
            oc.event_json
            order by
              oc.original_due_date,
              oc.scheduled_date,
              oc.time_bucket,
              oc.scheduled_start_at nulls last,
              oc.type_rank,
              oc.event_id
          )
          from (select * from overdue_candidates limit v_limit) oc
        ),
        '[]'::jsonb
      ),
      (select count(*) > v_limit from overdue_candidates)
    into v_overdue_rows, v_overdue_has_more;

    if v_overdue_has_more then
      select
        page.original_due_date,
        page.scheduled_date,
        page.time_bucket,
        page.scheduled_start_at,
        page.type_rank,
        page.event_id
      into v_last
      from (
        select s.*
        from public.calendar_read_scoped_events(
          v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today,
          null, p_date_from - 1
        ) s
        where s.scheduled_date < p_date_from
          and s.is_overdue
          and (
            v_cursor_overdue is null
            or (
              s.original_due_date,
              s.scheduled_date,
              s.time_bucket,
              coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
              s.type_rank,
              s.event_id
            ) > (
              (v_cursor_overdue -> 'last' ->> 'original_due_date')::date,
              (v_cursor_overdue -> 'last' ->> 'scheduled_date')::date,
              (v_cursor_overdue -> 'last' ->> 'time_bucket')::int,
              coalesce(
                nullif(v_cursor_overdue -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
                '-infinity'::timestamptz
              ),
              (v_cursor_overdue -> 'last' ->> 'type_rank')::int,
              (v_cursor_overdue -> 'last' ->> 'event_id')::uuid
            )
          )
        order by
          s.original_due_date asc,
          s.scheduled_date asc,
          s.time_bucket asc,
          s.scheduled_start_at asc nulls last,
          s.type_rank asc,
          s.event_id asc
        limit v_limit
      ) page
      order by
        page.original_due_date desc,
        page.scheduled_date desc,
        page.time_bucket desc,
        page.scheduled_start_at desc nulls first,
        page.type_rank desc,
        page.event_id desc
      limit 1;

      v_overdue_next := public.encode_calendar_list_cursor(
        jsonb_build_object(
          'version', 2,
          'tenant_id', v_tenant_id,
          'scope', v_ctx.scope,
          'employee_id', v_ctx.employee_id,
          'bucket', 'overdue_outside_range',
          'date_from', p_date_from,
          'date_to', p_date_to,
          'filters_hash', v_filters_hash,
          'last', jsonb_build_object(
            'bucket', 'overdue',
            'original_due_date', v_last.original_due_date,
            'scheduled_date', v_last.scheduled_date,
            'time_bucket', v_last.time_bucket,
            'scheduled_start_at', v_last.scheduled_start_at,
            'type_rank', v_last.type_rank,
            'event_id', v_last.event_id
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
$list$;

create or replace function public.get_calendar_route_day(p_date date, p_employee_id uuid DEFAULT NULL::uuid)

returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $route$
declare
  v_ctx public.calendar_read_scope_context;
  v_tenant_id uuid;
  v_employee_id uuid;
  v_today date;
  v_filters public.calendar_read_filter_bundle;
  v_limit int;
  v_rows jsonb := '[]'::jsonb;
  v_has_more boolean := false;
begin
  if p_date is null then
    raise exception 'validation_failed';
  end if;

  v_ctx := public.assert_calendar_event_view();
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  v_employee_id := public.assert_calendar_route_employee(
    v_tenant_id, v_ctx.scope, p_employee_id
  );

  v_today := public.tenant_local_today(v_tenant_id);
  v_filters := public.parse_calendar_read_filters(
    '{}'::jsonb, v_ctx.scope, v_ctx.employee_id
  );
  v_limit := public.calendar_route_day_limit();

  with scoped as (
    select *
    from public.calendar_read_scoped_events(
      v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today,
      p_date, p_date
    )
  ),
  members as (
    select
      s.event_id,
      s.scheduled_date,
      s.scheduled_start_at,
      s.time_bucket,
      s.type_rank,
      s.event_json,
      csl.latitude as raw_lat,
      csl.longitude as raw_lng,
      csl.google_maps_url as raw_url,
      public.calendar_location_state(
        csl.latitude, csl.longitude, csl.google_maps_url
      ) as location_state
    from scoped s
    join public.calendar_events ce
      on ce.id = s.event_id and ce.tenant_id = v_tenant_id
    left join public.customer_service_locations csl
      on csl.id = ce.service_location_id
      and csl.tenant_id = ce.tenant_id
      and csl.customer_id = ce.customer_id
    where s.scheduled_date = p_date
      and (
        s.assigned_agent_id = v_employee_id
        or exists (
          select 1
          from public.calendar_event_participants ep
          where ep.tenant_id = v_tenant_id
            and ep.event_id = s.event_id
            and ep.employee_id = v_employee_id
        )
      )
  ),
  ordered as (
    select
      m.*,
      row_number() over (
        order by
          m.time_bucket asc,
          m.scheduled_start_at asc nulls last,
          m.type_rank asc,
          m.event_id asc
      ) as rn
    from members m
  ),
  page as (
    select *
    from ordered
    where rn <= v_limit
  ),
  built as (
    select coalesce(
      jsonb_agg(
        jsonb_strip_nulls(
          jsonb_build_object(
            'event', p.event_json,
            'location_state', p.location_state,
            'latitude',
              case
                when p.location_state = 'mapped' then p.raw_lat
                else null
              end,
            'longitude',
              case
                when p.location_state = 'mapped' then p.raw_lng
                else null
              end
          )
        )
        order by p.rn
      ),
      '[]'::jsonb
    ) as rows,
    exists (select 1 from ordered o where o.rn > v_limit) as has_more
    from page p
  )
  select rows, has_more into v_rows, v_has_more from built;

  return jsonb_build_object(
    'date', p_date,
    'employee_id', v_employee_id,
    'has_more', coalesce(v_has_more, false),
    'points', coalesce(v_rows, '[]'::jsonb)
  );
end;
$route$;

revoke all on function public.calendar_read_scoped_events(
  uuid, text, uuid, public.calendar_read_filter_bundle, date, date, date
) from public, anon, authenticated, service_role;
revoke all on function public.calendar_read_scoped_events(
  uuid, text, uuid, public.calendar_read_filter_bundle, date
) from public, anon, authenticated, service_role;
revoke all on function public.calendar_read_summary_facts(
  uuid, text, uuid, public.calendar_read_filter_bundle, date, date, date
) from public, anon, authenticated, service_role;

do $$
begin
  if has_function_privilege(
    'authenticated',
    'public.calendar_read_scoped_events(uuid, text, uuid, public.calendar_read_filter_bundle, date, date, date)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.calendar_read_summary_facts(uuid, text, uuid, public.calendar_read_filter_bundle, date, date, date)',
    'EXECUTE'
  ) then
    raise exception 'm11_postflight_failed: summary/scoped helpers executable by authenticated';
  end if;
end $$;
