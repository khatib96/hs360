#!/usr/bin/env bash
# Seed Gate E route day: mapped + unmapped visits for Field Ahmad on Friday.
# Uses create_manual_calendar_event + assign so Flutter mappers see full shape.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
owner='00000000-0000-0000-0000-000000000201'
agent='00000000-0000-0000-0000-000000000602'

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<SQL
-- Cleanup any prior P7M12 route seed as postgres (RLS / grants safe).
delete from public.calendar_reminder_plans p
using public.calendar_events ce
where p.calendar_event_id = ce.id
  and ce.title_en in ('P7M12 Unmapped Route Visit', 'P7M12 Mapped Route Visit');
delete from public.calendar_event_participants ep
using public.calendar_events ce
where ep.event_id = ce.id
  and ce.title_en in ('P7M12 Unmapped Route Visit', 'P7M12 Mapped Route Visit');
delete from public.calendar_meeting_notices n
using public.calendar_events ce
where n.calendar_event_id = ce.id
  and ce.title_en in ('P7M12 Unmapped Route Visit', 'P7M12 Mapped Route Visit');
delete from public.calendar_schedule_operations so
using public.calendar_events ce
where so.result_event_id = ce.id
  and ce.title_en in ('P7M12 Unmapped Route Visit', 'P7M12 Mapped Route Visit');
delete from public.calendar_events
where title_en in ('P7M12 Unmapped Route Visit', 'P7M12 Mapped Route Visit');

do \$\$
declare
  v_tag text := 'P7M12';
  v_customer uuid;
  v_loc_unmapped uuid;
  v_loc_mapped uuid;
begin
  select c.id into v_customer
  from public.customers c
  where c.name_en like '%' || v_tag || '%'
     or c.name_ar like '%' || v_tag || '%'
  order by c.created_at desc
  limit 1;

  select csl.id into v_loc_unmapped
  from public.customer_service_locations csl
  where csl.name like '%' || v_tag || '%Unmapped%'
     or csl.name = v_tag || ' Unmapped Branch'
  order by csl.created_at desc
  limit 1;

  select csl.id into v_loc_mapped
  from public.customer_service_locations csl
  where csl.name like '%' || v_tag || '%Mapped%'
     or csl.name = v_tag || ' Mapped Branch'
  order by csl.created_at desc
  limit 1;

  if v_customer is null or v_loc_unmapped is null or v_loc_mapped is null then
    raise exception 'P7M12 route seed: customer/locations missing (postgres lookup)';
  end if;

  perform set_config('p7m12.route_customer_id', v_customer::text, false);
  perform set_config('p7m12.route_location_unmapped_id', v_loc_unmapped::text, false);
  perform set_config('p7m12.route_location_mapped_id', v_loc_mapped::text, false);
end;
\$\$;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '$owner';

do \$\$
declare
  v_tag text := 'P7M12';
  v_customer uuid := current_setting('p7m12.route_customer_id')::uuid;
  v_loc_unmapped uuid := current_setting('p7m12.route_location_unmapped_id')::uuid;
  v_loc_mapped uuid := current_setting('p7m12.route_location_mapped_id')::uuid;
  v_friday text := to_char(
    current_date + ((5 - extract(isodow from current_date)::int + 7) % 7),
    'YYYY-MM-DD'
  );
  v_res jsonb;
  v_id uuid;
  v_ver int;
begin
  -- Mapped companion (proves missing does not break the day).
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', v_friday,
      'title_ar', 'زيارة بإحداثيات ' || v_tag,
      'title_en', v_tag || ' Mapped Route Visit',
      'customer_id', v_customer::text,
      'service_location_id', v_loc_mapped::text
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' is distinct from 'ok' then
    raise exception 'P7M12 mapped route seed create failed: %', v_res;
  end if;
  v_id := (v_res #>> '{event,id}')::uuid;
  v_ver := coalesce((v_res #>> '{event,schedule_version}')::int, 1);
  v_res := public.assign_calendar_event(
    v_id, v_ver,
    jsonb_build_object('assigned_agent_id', '$agent'),
    gen_random_uuid()
  );
  if v_res ->> 'status' is distinct from 'ok' then
    raise exception 'P7M12 mapped route seed assign failed: %', v_res;
  end if;

  -- Unmapped / missing-coords visit (Item 20 primary).
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', v_friday,
      'title_ar', 'زيارة بلا إحداثيات ' || v_tag,
      'title_en', v_tag || ' Unmapped Route Visit',
      'customer_id', v_customer::text,
      'service_location_id', v_loc_unmapped::text
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' is distinct from 'ok' then
    raise exception 'P7M12 unmapped route seed create failed: %', v_res;
  end if;
  v_id := (v_res #>> '{event,id}')::uuid;
  v_ver := coalesce((v_res #>> '{event,schedule_version}')::int, 1);
  v_res := public.assign_calendar_event(
    v_id, v_ver,
    jsonb_build_object('assigned_agent_id', '$agent'),
    gen_random_uuid()
  );
  if v_res ->> 'status' is distinct from 'ok' then
    raise exception 'P7M12 unmapped route seed assign failed: %', v_res;
  end if;

  raise notice 'P7M12 route seed friday=% unmapped=%', v_friday, v_id;
end;
\$\$;

commit;
SQL
