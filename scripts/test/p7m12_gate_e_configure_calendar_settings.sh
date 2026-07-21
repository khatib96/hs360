#!/usr/bin/env bash
# Configure tenant working week for Gate E item 1 (after unconfigured banner capture).
# Modes: Mon/Wed/Fri working 08-17, Tue half 08-12, Thu 24h, Sat/Sun day_off.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
tenant='00000000-0000-0000-0000-000000000101'
owner='00000000-0000-0000-0000-000000000201'

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<SQL
begin;

-- Keep configured=false while days are filled, then flip in the same transaction.
update public.tenant_calendar_settings
set
  working_schedule_configured = false,
  timezone_name = 'Asia/Kuwait',
  remind_event_workday_start = true,
  remind_previous_workday_start = true,
  updated_at = now(),
  updated_by = '$owner'::uuid
where tenant_id = '$tenant'::uuid;

update public.tenant_working_days set
  day_mode = 'working_hours', work_start = '08:00', work_end = '17:00',
  updated_at = now(), updated_by = '$owner'::uuid
where tenant_id = '$tenant'::uuid and iso_weekday in (1, 3, 5);

update public.tenant_working_days set
  day_mode = 'working_hours', work_start = '08:00', work_end = '12:00',
  updated_at = now(), updated_by = '$owner'::uuid
where tenant_id = '$tenant'::uuid and iso_weekday = 2;

update public.tenant_working_days set
  day_mode = '24_hours', work_start = null, work_end = null,
  updated_at = now(), updated_by = '$owner'::uuid
where tenant_id = '$tenant'::uuid and iso_weekday = 4;

update public.tenant_working_days set
  day_mode = 'day_off', work_start = null, work_end = null,
  updated_at = now(), updated_by = '$owner'::uuid
where tenant_id = '$tenant'::uuid and iso_weekday in (6, 7);

update public.tenant_calendar_settings
set
  working_schedule_configured = true,
  timezone_name = 'Asia/Kuwait',
  configured_at = now(),
  configured_by = '$owner'::uuid,
  updated_at = now(),
  updated_by = '$owner'::uuid
where tenant_id = '$tenant'::uuid;

commit;

select jsonb_build_object(
  'configured', working_schedule_configured,
  'timezone', timezone_name
) from public.tenant_calendar_settings where tenant_id = '$tenant'::uuid;
SQL
