-- Phase 7 M12 — Route-day event contract fix (Gate E Item 20).
--
-- Root cause: get_calendar_route_day wrapped each point in jsonb_strip_nulls,
-- which recursively removed execution_summary: null from nested event_json.
-- Flutter mapCalendarEvent requires the execution_summary key to be present.
--
-- Fix: build route points by merging a base {event, location_state} object with
-- optional mapped coordinates. Never strip nulls from the event payload.
-- Do not edit migrations 093–103.

create or replace function public.get_calendar_route_day(
  p_date date,
  p_employee_id uuid DEFAULT NULL::uuid
)
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
        (
          jsonb_build_object(
            'event', p.event_json,
            'location_state', p.location_state
          )
          || case
            when p.location_state = 'mapped' then
              jsonb_build_object(
                'latitude', p.raw_lat,
                'longitude', p.raw_lng
              )
            else '{}'::jsonb
          end
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
