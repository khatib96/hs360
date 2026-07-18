-- Phase 7 M10: Route View read contract + directions RPCs.
-- Forward-only. Does not edit migrations 093–101.

-- ---------------------------------------------------------------------------
-- Section A: location / Maps URL helpers
-- ---------------------------------------------------------------------------
create or replace function public.calendar_is_allowlisted_maps_url(p_url text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_url text;
  v_rest text;
  v_host text;
begin
  if not public.calendar_is_safe_https_url(p_url) then
    return false;
  end if;

  v_url := btrim(p_url);
  v_rest := substring(v_url from 9);
  v_host := lower(split_part(split_part(split_part(v_rest, '/', 1), '?', 1), '#', 1));

  -- Reject generic goo.gl shorteners; allow maps.app.goo.gl only.
  if v_host in (
    'google.com',
    'www.google.com',
    'maps.google.com',
    'www.maps.google.com',
    'maps.app.goo.gl'
  ) then
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.calendar_coords_are_valid(
  p_lat numeric,
  p_lng numeric
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select
    p_lat is not null
    and p_lng is not null
    and p_lat >= -90::numeric
    and p_lat <= 90::numeric
    and p_lng >= -180::numeric
    and p_lng <= 180::numeric;
$$;

create or replace function public.calendar_location_state(
  p_lat numeric,
  p_lng numeric,
  p_maps_url text
)
returns text
language plpgsql
immutable
set search_path = public
as $$
begin
  if public.calendar_coords_are_valid(p_lat, p_lng) then
    return 'mapped';
  end if;
  if public.calendar_is_allowlisted_maps_url(p_maps_url) then
    return 'url_only';
  end if;
  if p_lat is not null or p_lng is not null then
    return 'invalid';
  end if;
  return 'missing';
end;
$$;

create or replace function public.calendar_directions_available_from_location(
  p_lat numeric,
  p_lng numeric,
  p_maps_url text
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select public.calendar_location_state(p_lat, p_lng, p_maps_url)
    in ('mapped', 'url_only');
$$;

create or replace function public.calendar_maps_https_from_coords(
  p_lat numeric,
  p_lng numeric
)
returns text
language plpgsql
immutable
set search_path = public
as $$
begin
  if not public.calendar_coords_are_valid(p_lat, p_lng) then
    return null;
  end if;
  return format(
    'https://www.google.com/maps/dir/?api=1&destination=%s,%s',
    trim(to_char(p_lat, 'FM999990.9999999')),
    trim(to_char(p_lng, 'FM999990.9999999'))
  );
end;
$$;

create or replace function public.calendar_route_day_limit()
returns int
language sql
immutable
set search_path = public
as $$
  select 100;
$$;

create or replace function public.calendar_route_employee_limit_default()
returns int
language sql
immutable
set search_path = public
as $$
  select 50;
$$;

create or replace function public.calendar_route_employee_limit_max()
returns int
language sql
immutable
set search_path = public
as $$
  select 100;
$$;

create or replace function public.assert_calendar_route_employee(
  p_tenant_id uuid,
  p_scope text,
  p_requested_employee_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_self uuid;
  v_emp uuid;
begin
  if p_scope = 'assigned_only' then
    v_self := public.current_employee_id();
    if v_self is null then
      raise exception 'permission_denied';
    end if;
    if p_requested_employee_id is not null
      and p_requested_employee_id is distinct from v_self then
      raise exception 'permission_denied';
    end if;
    return v_self;
  end if;

  if p_scope = 'tenant_wide' then
    if p_requested_employee_id is null then
      raise exception 'validation_failed';
    end if;
    select e.id
      into v_emp
    from public.employees e
    where e.id = p_requested_employee_id
      and e.tenant_id = p_tenant_id
      and e.is_active = true;
    if v_emp is null then
      raise exception 'permission_denied';
    end if;
    return v_emp;
  end if;

  raise exception 'permission_denied';
end;
$$;

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
$$;

-- ---------------------------------------------------------------------------
-- Section C: get_calendar_route_day
-- ---------------------------------------------------------------------------
create or replace function public.get_calendar_route_day(
  p_date date,
  p_employee_id uuid default null
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
      v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today
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
$$;

-- ---------------------------------------------------------------------------
-- Section D: list_calendar_route_employees
-- ---------------------------------------------------------------------------
create or replace function public.list_calendar_route_employees(
  p_search text default null,
  p_limit int default null
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
  v_search text;
  v_limit int;
  v_rows jsonb := '[]'::jsonb;
  v_has_more boolean := false;
begin
  v_ctx := public.assert_calendar_event_view();
  if v_ctx.scope is distinct from 'tenant_wide' then
    raise exception 'permission_denied';
  end if;

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_limit := greatest(
    least(
      coalesce(p_limit, public.calendar_route_employee_limit_default()),
      public.calendar_route_employee_limit_max()
    ),
    1
  );

  with candidates as (
    select
      e.id as employee_id,
      e.name_ar,
      e.name_en,
      e.is_active,
      row_number() over (
        order by e.name_ar asc nulls last, e.name_en asc nulls last, e.id asc
      ) as rn
    from public.employees e
    where e.tenant_id = v_tenant_id
      and e.is_active = true
      and (
        v_search is null
        or lower(coalesce(e.name_ar, '')) like '%' || v_search || '%'
        or lower(coalesce(e.name_en, '')) like '%' || v_search || '%'
        or lower(coalesce(e.code, '')) like '%' || v_search || '%'
      )
  ),
  page as (
    select * from candidates where rn <= v_limit
  ),
  built as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'employee_id', p.employee_id,
          'name_ar', p.name_ar,
          'name_en', p.name_en,
          'is_active', p.is_active
        )
        order by p.rn
      ),
      '[]'::jsonb
    ) as rows,
    exists (select 1 from candidates c where c.rn > v_limit) as has_more
    from page p
  )
  select rows, has_more into v_rows, v_has_more from built;

  return jsonb_build_object(
    'has_more', coalesce(v_has_more, false),
    'rows', coalesce(v_rows, '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section E: get_calendar_event_directions
-- ---------------------------------------------------------------------------
create or replace function public.get_calendar_event_directions(
  p_event_id uuid
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
  v_event public.calendar_events%rowtype;
  v_lat numeric;
  v_lng numeric;
  v_url text;
  v_state text;
  v_built_url text;
begin
  if p_event_id is null then
    raise exception 'validation_failed';
  end if;

  v_ctx := public.assert_calendar_event_view();
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  select * into v_event
  from public.calendar_events ce
  where ce.id = p_event_id;

  if not found or v_event.tenant_id is distinct from v_tenant_id then
    raise exception 'not_found';
  end if;

  if v_ctx.scope = 'assigned_only' then
    if not public.user_has_calendar_event_visibility(
      v_tenant_id, auth.uid(), p_event_id
    ) then
      raise exception 'permission_denied';
    end if;
  elsif v_ctx.scope is distinct from 'tenant_wide' then
    raise exception 'permission_denied';
  end if;
  -- tenant_wide: no assigned-only visibility helper required.

  select csl.latitude, csl.longitude, csl.google_maps_url
    into v_lat, v_lng, v_url
  from public.customer_service_locations csl
  where csl.id = v_event.service_location_id
    and csl.tenant_id = v_event.tenant_id
    and csl.customer_id = v_event.customer_id;

  v_state := public.calendar_location_state(v_lat, v_lng, v_url);

  if v_state = 'mapped' then
    v_built_url := public.calendar_maps_https_from_coords(v_lat, v_lng);
    return jsonb_strip_nulls(
      jsonb_build_object(
        'event_id', p_event_id,
        'location_state', v_state,
        'latitude', v_lat,
        'longitude', v_lng,
        'maps_url', v_built_url
      )
    );
  end if;

  if v_state = 'url_only' then
    return jsonb_build_object(
      'event_id', p_event_id,
      'location_state', v_state,
      'maps_url', btrim(v_url)
    );
  end if;

  raise exception 'validation_failed';
end;
$$;

-- ---------------------------------------------------------------------------
-- Section F: Grants / revokes / postflight
-- ---------------------------------------------------------------------------
revoke all on function public.calendar_is_allowlisted_maps_url(text)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_coords_are_valid(numeric, numeric)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_location_state(numeric, numeric, text)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_directions_available_from_location(
  numeric, numeric, text
) from public, anon, authenticated, service_role;
revoke all on function public.calendar_maps_https_from_coords(numeric, numeric)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_route_day_limit()
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_route_employee_limit_default()
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_route_employee_limit_max()
  from public, anon, authenticated, service_role;
revoke all on function public.assert_calendar_route_employee(uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_read_scoped_events(
  uuid, text, uuid, public.calendar_read_filter_bundle, date
) from public, anon, authenticated, service_role;
revoke all on function public.get_calendar_route_day(date, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.list_calendar_route_employees(text, int)
  from public, anon, authenticated, service_role;
revoke all on function public.get_calendar_event_directions(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.get_calendar_route_day(date, uuid)
  to authenticated;
grant execute on function public.list_calendar_route_employees(text, int)
  to authenticated;
grant execute on function public.get_calendar_event_directions(uuid)
  to authenticated;

do $$
begin
  if has_function_privilege(
    'anon', 'public.get_calendar_route_day(date, uuid)', 'EXECUTE'
  )
    or has_function_privilege(
      'anon', 'public.list_calendar_route_employees(text, int)', 'EXECUTE'
    )
    or has_function_privilege(
      'anon', 'public.get_calendar_event_directions(uuid)', 'EXECUTE'
    ) then
    raise exception 'm10_postflight_failed: anon can execute route rpc';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.calendar_read_scoped_events(uuid, text, uuid, public.calendar_read_filter_bundle, date)',
    'EXECUTE'
  )
    or has_function_privilege(
      'authenticated',
      'public.assert_calendar_route_employee(uuid, text, uuid)',
      'EXECUTE'
    )
    or has_function_privilege(
      'authenticated',
      'public.calendar_location_state(numeric, numeric, text)',
      'EXECUTE'
    ) then
    raise exception 'm10_postflight_failed: helper executable by authenticated';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.get_calendar_route_day(date, uuid)', 'EXECUTE'
  )
    or not has_function_privilege(
      'authenticated',
      'public.list_calendar_route_employees(text, int)',
      'EXECUTE'
    )
    or not has_function_privilege(
      'authenticated',
      'public.get_calendar_event_directions(uuid)',
      'EXECUTE'
    ) then
    raise exception 'm10_postflight_failed: route rpc not granted';
  end if;
end $$;
