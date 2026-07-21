#!/usr/bin/env bash
# Reset tenant calendar settings to unconfigured (Gate E item 2 capture).
# Local/test only. Does not print secrets.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
tenant='00000000-0000-0000-0000-000000000101'

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<SQL
update public.tenant_calendar_settings
set
  working_schedule_configured = false,
  timezone_name = null,
  remind_event_workday_start = true,
  remind_previous_workday_start = true,
  updated_at = now()
where tenant_id = '$tenant'::uuid;

update public.tenant_working_days
set
  day_mode = null,
  work_start = null,
  work_end = null,
  updated_at = now()
where tenant_id = '$tenant'::uuid;

select jsonb_build_object(
  'working_schedule_configured', working_schedule_configured,
  'timezone_name', timezone_name
)
from public.tenant_calendar_settings
where tenant_id = '$tenant'::uuid;
SQL
