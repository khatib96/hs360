#!/usr/bin/env bash
# Clear Gate E locale-story rows created by a prior EN/AR configured pass.
# Keeps durable fixtures: overdue pending, route seed visits, customers/locations.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<'SQL'
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101'::uuid;
  v_event_ids uuid[];
  v_exception_ids uuid[];
begin
  select coalesce(array_agg(ce.id), '{}'::uuid[])
  into v_event_ids
  from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and (
      ce.title_en in (
        'P7M12 Untimed Task',
        'P7M12 Timed Meeting',
        'P7M12 Holiday Override Event'
      )
      or ce.title_ar in (
        'مهمة بدون وقت P7M12',
        'اجتماع موقوت P7M12',
        'حدث على عطلة P7M12'
      )
    );

  select coalesce(array_agg(wde.id), '{}'::uuid[])
  into v_exception_ids
  from public.tenant_working_date_exceptions wde
  where wde.tenant_id = v_tenant
    and (
      wde.title_en = 'P7M12 Holiday'
      or wde.title_ar = 'عطلة P7M12'
    );

  -- Match full cleanup: disable RLS briefly; delete dependents before events.
  alter table public.calendar_reminder_plans disable row level security;
  alter table public.calendar_event_participants disable row level security;
  alter table public.calendar_meeting_notices disable row level security;
  alter table public.calendar_schedule_operations disable row level security;
  alter table public.calendar_events disable row level security;
  alter table public.tenant_working_date_exceptions disable row level security;
  alter table public.working_date_exception_operations disable row level security;

  delete from public.calendar_reminder_plans p
  where p.calendar_event_id = any (v_event_ids);

  delete from public.calendar_event_participants ep
  where ep.event_id = any (v_event_ids);

  -- Participant delete can recreate reminder plans via trigger; purge again.
  delete from public.calendar_reminder_plans p
  where p.calendar_event_id = any (v_event_ids);

  delete from public.calendar_meeting_notices n
  where n.calendar_event_id = any (v_event_ids);

  delete from public.calendar_schedule_operations so
  where so.result_event_id = any (v_event_ids);

  delete from public.calendar_reminder_plans p
  where p.calendar_event_id = any (v_event_ids);

  delete from public.calendar_events ce
  where ce.id = any (v_event_ids);

  delete from public.working_date_exception_operations op
  where op.result_exception_id = any (v_exception_ids);

  update public.tenant_working_date_exceptions wde
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancelled_by = '00000000-0000-0000-0000-000000000201'::uuid,
    cancel_reason = 'P7M12 locale-story clear'
  where wde.id = any (v_exception_ids)
    and wde.status = 'active';

  delete from public.tenant_working_date_exceptions wde
  where wde.id = any (v_exception_ids);

  alter table public.calendar_reminder_plans enable row level security;
  alter table public.calendar_event_participants enable row level security;
  alter table public.calendar_meeting_notices enable row level security;
  alter table public.calendar_schedule_operations enable row level security;
  alter table public.calendar_events enable row level security;
  alter table public.tenant_working_date_exceptions enable row level security;
  alter table public.working_date_exception_operations enable row level security;

  raise notice 'P7M12 locale-story cleared events=% exceptions=%',
    coalesce(cardinality(v_event_ids), 0),
    coalesce(cardinality(v_exception_ids), 0);
end;
$$;
SQL
