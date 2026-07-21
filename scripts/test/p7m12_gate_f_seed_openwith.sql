-- Phase 7 M12 Gate F open-with fixtures (tag P7M12).
-- Adds url_only + invalid locations and assigns visits for Field Ahmad on Friday.
-- Local/test DB only. Requires Gate E-style customer fixture (Mapped/Unmapped) first.
\set ON_ERROR_STOP on

-- Cleanup prior Gate F-only titles (postgres; RLS-safe).
delete from public.calendar_reminder_plans p
using public.calendar_events ce
where p.calendar_event_id = ce.id
  and ce.title_en in (
    'P7M12 UrlOnly Route Visit',
    'P7M12 Invalid Route Visit'
  );
delete from public.calendar_event_participants ep
using public.calendar_events ce
where ep.event_id = ce.id
  and ce.title_en in (
    'P7M12 UrlOnly Route Visit',
    'P7M12 Invalid Route Visit'
  );
delete from public.calendar_meeting_notices n
using public.calendar_events ce
where n.calendar_event_id = ce.id
  and ce.title_en in (
    'P7M12 UrlOnly Route Visit',
    'P7M12 Invalid Route Visit'
  );
delete from public.calendar_schedule_operations so
using public.calendar_events ce
where so.result_event_id = ce.id
  and ce.title_en in (
    'P7M12 UrlOnly Route Visit',
    'P7M12 Invalid Route Visit'
  );
delete from public.calendar_events
where title_en in (
  'P7M12 UrlOnly Route Visit',
  'P7M12 Invalid Route Visit'
);

-- Location creates require authenticated customers.edit (owner seed).
-- Note: CSL CHECK constraints reject out-of-range coords, so a persisted
-- `invalid` location_state cannot be seeded via create_customer_service_location.
-- Gate F device evidence covers `missing` (Unmapped) + `url_only` here;
-- `invalid` remains SQL/unit-contract covered (see phase_7_calendar_route_view.sql).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_tag text := 'P7M12';
  v_customer uuid;
  v_loc_url uuid;
  v_agent uuid := '00000000-0000-0000-0000-000000000602';
  v_friday text := to_char(
    current_date + ((5 - extract(isodow from current_date)::int + 7) % 7),
    'YYYY-MM-DD'
  );
  v_res jsonb;
  v_id uuid;
  v_ver int;
begin
  select c.id into v_customer
  from public.customers c
  where c.name_en like '%' || v_tag || '%'
     or c.name_ar like '%' || v_tag || '%'
  order by c.created_at desc
  limit 1;

  if v_customer is null then
    raise exception 'P7M12 Gate F seed: acceptance customer missing';
  end if;

  select csl.id into v_loc_url
  from public.customer_service_locations csl
  where csl.customer_id = v_customer
    and csl.name = v_tag || ' UrlOnly Branch'
  order by csl.created_at desc
  limit 1;

  if v_loc_url is null then
    v_loc_url := public.create_customer_service_location(
      v_customer,
      jsonb_build_object(
        'name', v_tag || ' UrlOnly Branch',
        'location_type', 'branch',
        'governorate', 'Capital',
        'area', 'Sharq',
        'contact_person_phone', '+96550009403',
        'google_maps_url', 'https://www.google.com/maps?q=29.3753,47.9774&query=p7m12-gate-f-url-only'
      )
    );
  else
    -- Keep URL deterministic across re-seeds (avoid stale non-allowlisted URLs).
    perform public.update_customer_service_location(
      v_loc_url,
      jsonb_build_object(
        'google_maps_url', 'https://www.google.com/maps?q=29.3753,47.9774&query=p7m12-gate-f-url-only'
      )
    );
  end if;

  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', v_friday,
      'title_ar', 'زيارة رابط فقط ' || v_tag,
      'title_en', v_tag || ' UrlOnly Route Visit',
      'customer_id', v_customer::text,
      'service_location_id', v_loc_url::text
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' is distinct from 'ok' then
    raise exception 'P7M12 Gate F url_only create failed: %', v_res;
  end if;
  v_id := (v_res #>> '{event,id}')::uuid;
  v_ver := coalesce((v_res #>> '{event,schedule_version}')::int, 1);
  v_res := public.assign_calendar_event(
    v_id, v_ver,
    jsonb_build_object('assigned_agent_id', v_agent),
    gen_random_uuid()
  );
  if v_res ->> 'status' is distinct from 'ok' then
    raise exception 'P7M12 Gate F url_only assign failed: %', v_res;
  end if;

  raise notice 'P7M12 Gate F openwith seed friday=% url_only=%', v_friday, v_id;
end $$;

commit;
