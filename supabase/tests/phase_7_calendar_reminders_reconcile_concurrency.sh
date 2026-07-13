#!/usr/bin/env bash
# Phase 7 M3: settings mutation during reconcile — generation bump completes safely.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

tenant_a='00000000-0000-0000-0000-000000000101'
owner_sub='00000000-0000-0000-0000-000000000201'
marker="P7M3RC-$(date +%s)-$$"
tmpdir="$(mktemp -d)"
test_passed=0

psql_exec() {
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

cleanup_fixtures() {
  psql_exec -v marker="$marker" <<'SQL'
begin;
set local role postgres;
delete from public.calendar_reminder_plans crp
using public.calendar_events ce
where crp.calendar_event_id = ce.id
  and ce.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
  and ce.title_en like :'marker' || '%';
delete from public.calendar_events ce
where ce.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
  and ce.title_en like :'marker' || '%';
update public.tenant_calendar_settings
set
  working_schedule_configured = false,
  timezone_name = null,
  remind_event_workday_start = true,
  remind_previous_workday_start = true,
  configured_at = null,
  configured_by = null,
  updated_by = null
where tenant_id = '00000000-0000-0000-0000-000000000101'::uuid;
update public.tenant_working_days
set
  day_mode = null,
  work_start = null,
  work_end = null,
  updated_by = null
where tenant_id = '00000000-0000-0000-0000-000000000101'::uuid;
commit;
SQL
}

cleanup() {
  local exit_code=$?
  cleanup_fixtures || true
  rm -rf "$tmpdir"
  if [[ "$test_passed" -eq 1 ]]; then
    exit 0
  fi
  exit "$exit_code"
}
trap cleanup EXIT

printf 'P7M3 reconcile concurrency: settings change during cursor pagination\n'

psql_exec -v marker="$marker" -v owner_sub="$owner_sub" <<'SQL'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'owner_sub', true);
select public.update_calendar_settings(jsonb_build_object(
  'timezone_name', 'Asia/Kuwait',
  'remind_event_workday_start', true,
  'remind_previous_workday_start', false,
  'days', jsonb_build_array(
    jsonb_build_object('iso_weekday', 1, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 2, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 3, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 4, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 5, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '13:00'),
    jsonb_build_object('iso_weekday', 6, 'day_mode', 'day_off'),
    jsonb_build_object('iso_weekday', 7, 'day_mode', '24_hours')
  )
));

set local role postgres;

insert into public.calendar_events (
  tenant_id, type, status, source_kind, scheduled_date, title_ar, title_en, assigned_agent_id
)
select
  '00000000-0000-0000-0000-000000000101'::uuid,
  'custom'::public.calendar_event_type,
  'pending'::public.calendar_event_status,
  'manual'::public.calendar_event_source_kind,
  current_date + (g % 30),
  :'marker' || ' ' || g,
  :'marker' || ' ' || g,
  '00000000-0000-0000-0000-000000000601'::uuid
from generate_series(1, 520) g;

select public.bump_reminder_reconcile_generation('00000000-0000-0000-0000-000000000101'::uuid);
commit;
SQL

reconcile_sql="
begin;
set local role postgres;
select public.reconcile_tenant_calendar_reminder_plans(
  '${tenant_a}'::uuid,
  500
);
commit;
"

bump_sql="
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '${owner_sub}', true);
select public.update_calendar_settings(jsonb_build_object(
  'timezone_name', 'Asia/Kuwait',
  'remind_event_workday_start', true,
  'remind_previous_workday_start', true,
  'days', jsonb_build_array(
    jsonb_build_object('iso_weekday', 1, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 2, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 3, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 4, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 5, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '13:00'),
    jsonb_build_object('iso_weekday', 6, 'day_mode', 'day_off'),
    jsonb_build_object('iso_weekday', 7, 'day_mode', '24_hours')
  )
));
commit;
"

psql_exec -c "$reconcile_sql" >"$tmpdir/batch1.log" 2>&1 &
pid1=$!

sleep 0.05
psql_exec -c "$bump_sql" >"$tmpdir/bump.log" 2>&1 &
pid_bump=$!

wait "$pid1" || {
  cat "$tmpdir/batch1.log" >&2
  exit 1
}
wait "$pid_bump" || {
  cat "$tmpdir/bump.log" >&2
  exit 1
}

for attempt in $(seq 1 10); do
  psql_exec -c "$reconcile_sql" >"$tmpdir/batch_extra_${attempt}.log" 2>&1 || {
    cat "$tmpdir/batch_extra_${attempt}.log" >&2
    exit 1
  }

  queue_state="$(psql_exec -t -A -c "
select coalesce(processed_generation::text, 'null') || '|' || generation::text
from public.calendar_reminder_reconcile_queue
where tenant_id = '${tenant_a}';
" | tr -d '[:space:]')"

  processed="${queue_state%%|*}"
  generation="${queue_state##*|}"

  if [[ "$processed" == "$generation" ]]; then
    break
  fi
done

if [[ -z "$queue_state" ]]; then
  printf 'Missing reconcile queue row for tenant A\n' >&2
  exit 1
fi

if [[ "$processed" != "$generation" ]]; then
  printf 'Expected processed_generation=generation after reconcile loop; got %s\n' "$queue_state" >&2
  cat "$tmpdir/batch1.log" >&2
  cat "$tmpdir/bump.log" >&2
  ls "$tmpdir"/batch_extra_*.log >&2 || true
  exit 1
fi

dup_count="$(psql_exec -t -A -v marker="$marker" <<'SQL' | tr -d '[:space:]'
select count(*) from (
  select crp.tenant_id, crp.calendar_event_id, crp.rule_key, crp.occurrence_scheduled_date, count(*)
  from public.calendar_reminder_plans crp
  join public.calendar_events ce on ce.id = crp.calendar_event_id
  where ce.title_en like :'marker' || '%'
  group by 1, 2, 3, 4
  having count(*) > 1
) d;
SQL
)"

if [[ "${dup_count:-0}" != "0" ]]; then
  printf 'Duplicate reminder plan occurrences detected: %s\n' "$dup_count" >&2
  exit 1
fi

previous_plan_count="$(psql_exec -t -A -v marker="$marker" <<'SQL' | tr -d '[:space:]'
select count(distinct ce.id)
from public.calendar_events ce
join public.calendar_reminder_plans crp
  on crp.calendar_event_id = ce.id
 and crp.rule_key = 'previous_workday_start'::public.calendar_reminder_rule_key
where ce.title_en like :'marker' || '%';
SQL
)"

if [[ "${previous_plan_count:-0}" != "520" ]]; then
  printf 'Expected all 520 events to receive the newly enabled previous-day plan; got %s\n' \
    "$previous_plan_count" >&2
  exit 1
fi

test_passed=1
printf 'P7M3 reconcile concurrency test passed (queue=%s).\n' "$queue_state"
