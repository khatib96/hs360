#!/usr/bin/env bash
# Phase 7 M8 concurrency gate:
# 1) Two parallel assign_calendar_event calls with the SAME idempotency key
#    and payload: both must succeed (winner writes, loser replays), exactly
#    one ledger row, exactly one version bump.
# 2) Parallel assign vs reschedule with DIFFERENT keys against the same
#    expected version: exactly one wins, the loser fails with stale_version.
# 3) assign vs deactivate, both orderings: deactivate-first must reject the
#    assign (validation_failed); assign-first must succeed, and a later
#    deactivation leaves the event pointing at the now-inactive assignee.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

owner_sub='00000000-0000-0000-0000-000000000201'
tenant_a='00000000-0000-0000-0000-000000000101'
field_emp='00000000-0000-0000-0000-000000000602'
owner_emp='00000000-0000-0000-0000-000000000601'
marker="M8CC-$(date +%s)-$$"
tmpdir="$(mktemp -d)"
test_passed=0

uuid_gen() {
  uuidgen | tr 'A-Z' 'a-z'
}

temp_emp="$(uuid_gen)"

psql_exec() {
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

psql_scalar() {
  psql_exec -t -A -c "$1"
}

cleanup_fixtures() {
  psql_exec <<SQL || true
begin;
set local role postgres;
delete from public.calendar_meeting_notices n
using public.calendar_events ce
where n.calendar_event_id = ce.id
  and ce.title_en like '${marker}%';
delete from public.calendar_schedule_operations op
using public.calendar_events ce
where op.result_event_id = ce.id
  and ce.title_en like '${marker}%';
delete from public.calendar_manual_event_operations op
using public.calendar_events ce
where op.result_event_id = ce.id
  and ce.title_en like '${marker}%';
delete from public.calendar_reminder_plans p
using public.calendar_events ce
where p.calendar_event_id = ce.id
  and ce.title_en like '${marker}%';
delete from public.calendar_event_participants ep
using public.calendar_events ce
where ep.event_id = ce.id
  and ce.title_en like '${marker}%';
delete from public.calendar_events
where title_en like '${marker}%';
delete from public.employees
where id = '${temp_emp}';
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

printf 'M8 assignment concurrency (marker=%s)\n' "$marker"

# ---------------------------------------------------------------------------
# Fixtures: two pending manual events + a dedicated deactivatable employee.
# ---------------------------------------------------------------------------
psql_exec <<SQL >/dev/null
begin;
set local request.jwt.claim.sub = '${owner_sub}';
select public.create_manual_calendar_event(
  jsonb_build_object(
    'type', 'customer_visit',
    'scheduled_date', to_char(current_date + ((8 - extract(isodow from current_date)::int) % 7) + 7, 'YYYY-MM-DD'),
    'title_en', '${marker} same-key'
  ),
  gen_random_uuid()
);
select public.create_manual_calendar_event(
  jsonb_build_object(
    'type', 'internal_task',
    'scheduled_date', to_char(current_date + ((8 - extract(isodow from current_date)::int) % 7) + 7, 'YYYY-MM-DD'),
    'title_en', '${marker} race'
  ),
  gen_random_uuid()
);
select public.create_manual_calendar_event(
  jsonb_build_object(
    'type', 'custom',
    'scheduled_date', to_char(current_date + ((8 - extract(isodow from current_date)::int) % 7) + 7, 'YYYY-MM-DD'),
    'title_en', '${marker} deactivate'
  ),
  gen_random_uuid()
);
set local role postgres;
insert into public.employees (
  id, tenant_id, name_ar, name_en, is_active, user_id, code, hire_date, job_type
) values (
  '${temp_emp}', '${tenant_a}', 'مؤقت', '${marker} temp emp', true, null,
  'M8CC-$$', current_date, 'other'
);
commit;
SQL

event_same="$(psql_scalar "select id from public.calendar_events where title_en = '${marker} same-key';")"
event_race="$(psql_scalar "select id from public.calendar_events where title_en = '${marker} race';")"
event_deact="$(psql_scalar "select id from public.calendar_events where title_en = '${marker} deactivate';")"

if [[ -z "$event_same" || -z "$event_race" || -z "$event_deact" ]]; then
  printf 'M8 concurrency failed: fixture events missing\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Scenario 1: parallel assign, same idempotency key + payload.
# ---------------------------------------------------------------------------
key_same="$(uuid_gen)"
assign_same_sql="
begin;
set local request.jwt.claim.sub = '${owner_sub}';
select public.assign_calendar_event(
  '${event_same}'::uuid, 1,
  jsonb_build_object('assigned_agent_id', '${field_emp}'),
  '${key_same}'::uuid
);
commit;
"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$assign_same_sql" \
  >"$tmpdir/same_a" 2>&1 &
pid_a=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$assign_same_sql" \
  >"$tmpdir/same_b" 2>&1 &
pid_b=$!

ec_a=0; ec_b=0
wait "$pid_a" || ec_a=$?
wait "$pid_b" || ec_b=$?

if [[ "$ec_a" -ne 0 || "$ec_b" -ne 0 ]]; then
  printf 'S1 failed: same-key parallel assign was not idempotent (ec_a=%s ec_b=%s)\n' "$ec_a" "$ec_b" >&2
  cat "$tmpdir/same_a" "$tmpdir/same_b" >&2
  exit 1
fi

ledger_count="$(psql_scalar "
  select count(*) from public.calendar_schedule_operations
  where idempotency_key = '${key_same}';
")"
if [[ "$ledger_count" != "1" ]]; then
  printf 'S1 failed: expected 1 ledger row for shared key, found %s\n' "$ledger_count" >&2
  exit 1
fi

state="$(psql_scalar "
  select assigned_agent_id::text || '|' || schedule_version::text
  from public.calendar_events where id = '${event_same}';
")"
if [[ "$state" != "${field_emp}|2" ]]; then
  printf 'S1 failed: expected %s|2, found %s\n' "$field_emp" "$state" >&2
  exit 1
fi
printf 'S1 same-key idempotent parallel assign passed.\n'

# ---------------------------------------------------------------------------
# Scenario 2: parallel assign vs reschedule, different keys, same version.
# ---------------------------------------------------------------------------
assign_race_sql="
begin;
set local request.jwt.claim.sub = '${owner_sub}';
select public.assign_calendar_event(
  '${event_race}'::uuid, 1,
  jsonb_build_object('assigned_agent_id', '${owner_emp}'),
  '$(uuid_gen)'::uuid
);
commit;
"
reschedule_race_sql="
begin;
set local request.jwt.claim.sub = '${owner_sub}';
select public.reschedule_calendar_event(
  '${event_race}'::uuid, 1,
  jsonb_build_object(
    'scheduled_date', to_char(current_date + ((9 - extract(isodow from current_date)::int) % 7) + 14, 'YYYY-MM-DD'),
    'reason', 'M8CC race reschedule'
  ),
  '$(uuid_gen)'::uuid
);
commit;
"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$assign_race_sql" \
  >"$tmpdir/race_assign" 2>&1 &
pid_a=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$reschedule_race_sql" \
  >"$tmpdir/race_resched" 2>&1 &
pid_b=$!

ec_a=0; ec_b=0
wait "$pid_a" || ec_a=$?
wait "$pid_b" || ec_b=$?

if [[ "$ec_a" -eq 0 && "$ec_b" -eq 0 ]]; then
  printf 'S2 failed: both assign and reschedule succeeded at the same version\n' >&2
  cat "$tmpdir/race_assign" "$tmpdir/race_resched" >&2
  exit 1
fi
if [[ "$ec_a" -ne 0 && "$ec_b" -ne 0 ]]; then
  printf 'S2 failed: both assign and reschedule failed\n' >&2
  cat "$tmpdir/race_assign" "$tmpdir/race_resched" >&2
  exit 1
fi

loser_out="$tmpdir/race_assign"
if [[ "$ec_a" -eq 0 ]]; then
  loser_out="$tmpdir/race_resched"
fi
if ! grep -q 'stale_version' "$loser_out"; then
  printf 'S2 failed: losing branch did not report stale_version\n' >&2
  cat "$loser_out" >&2
  exit 1
fi

race_version="$(psql_scalar "
  select schedule_version from public.calendar_events where id = '${event_race}';
")"
if [[ "$race_version" != "2" ]]; then
  printf 'S2 failed: expected schedule_version 2, found %s\n' "$race_version" >&2
  exit 1
fi
printf 'S2 assign vs reschedule stale_version race passed.\n'

# ---------------------------------------------------------------------------
# Scenario 3a: deactivate first, then assign -> validation_failed.
# ---------------------------------------------------------------------------
psql_exec -c "update public.employees set is_active = false where id = '${temp_emp}';" >/dev/null

assign_deact_sql() {
  local version="$1" key="$2"
  cat <<SQL
begin;
set local request.jwt.claim.sub = '${owner_sub}';
select public.assign_calendar_event(
  '${event_deact}'::uuid, ${version},
  jsonb_build_object('assigned_agent_id', '${temp_emp}'),
  '${key}'::uuid
);
commit;
SQL
}

ec=0
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "$(assign_deact_sql 1 "$(uuid_gen)")" >"$tmpdir/deact_first" 2>&1 || ec=$?
if [[ "$ec" -eq 0 ]]; then
  printf 'S3a failed: assign to a deactivated employee succeeded\n' >&2
  cat "$tmpdir/deact_first" >&2
  exit 1
fi
if ! grep -q 'validation_failed' "$tmpdir/deact_first"; then
  printf 'S3a failed: expected validation_failed, got:\n' >&2
  cat "$tmpdir/deact_first" >&2
  exit 1
fi
printf 'S3a deactivate-first assign rejection passed.\n'

# ---------------------------------------------------------------------------
# Scenario 3b: assign first (active), then deactivate -> event keeps the
# now-inactive assignee.
# ---------------------------------------------------------------------------
psql_exec -c "update public.employees set is_active = true where id = '${temp_emp}';" >/dev/null

ec=0
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "$(assign_deact_sql 1 "$(uuid_gen)")" >"$tmpdir/assign_first" 2>&1 || ec=$?
if [[ "$ec" -ne 0 ]]; then
  printf 'S3b failed: assign to the reactivated employee failed\n' >&2
  cat "$tmpdir/assign_first" >&2
  exit 1
fi

psql_exec -c "update public.employees set is_active = false where id = '${temp_emp}';" >/dev/null

state="$(psql_scalar "
  select ce.assigned_agent_id::text || '|' || ce.status::text || '|' || e.is_active::text
  from public.calendar_events ce
  join public.employees e on e.id = ce.assigned_agent_id
  where ce.id = '${event_deact}';
")"
if [[ "$state" != "${temp_emp}|pending|false" ]]; then
  printf 'S3b failed: expected %s|pending|false, found %s\n' "$temp_emp" "$state" >&2
  exit 1
fi
printf 'S3b assign-first then deactivate passed.\n'

# ---------------------------------------------------------------------------
# S4: M7A update_manual_calendar_event vs assign_calendar_event (shared version)
# ---------------------------------------------------------------------------
psql_exec <<SQL >/dev/null
begin;
set local request.jwt.claim.sub = '${owner_sub}';
select public.create_manual_calendar_event(
  jsonb_build_object(
    'type', 'customer_visit',
    'scheduled_date', to_char(current_date + 21, 'YYYY-MM-DD'),
    'title_en', '${marker} cross'
  ),
  gen_random_uuid()
);
commit;
SQL
event_cross="$(psql_scalar "select id from public.calendar_events where title_en = '${marker} cross';")"
if [[ -z "$event_cross" ]]; then
  printf 'S4 failed: could not create cross-race event\n' >&2
  exit 1
fi
cross_version="$(psql_scalar "select schedule_version from public.calendar_events where id = '${event_cross}';")"

edit_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.update_manual_calendar_event(
  '${event_cross}'::uuid,
  ${cross_version},
  jsonb_build_object('title_en', '${marker} edited'),
  gen_random_uuid()
);
commit;
"
assign_cross_sql="
begin;
set local role authenticated;
set local request.jwt.claim.sub = '${owner_sub}';
select public.assign_calendar_event(
  '${event_cross}'::uuid,
  ${cross_version},
  jsonb_build_object('assigned_agent_id', '${field_emp}'::uuid),
  gen_random_uuid()
);
commit;
"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$edit_sql" \
  >"$tmpdir/out_edit" 2>&1 &
pid_edit=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$assign_cross_sql" \
  >"$tmpdir/out_assign_cross" 2>&1 &
pid_assign_cross=$!

ec_edit=0
ec_assign_cross=0
wait "$pid_edit" || ec_edit=$?
wait "$pid_assign_cross" || ec_assign_cross=$?

ok_edit=0
ok_assign_cross=0
[[ "$ec_edit" -eq 0 ]] && grep -q '"status" *: *"ok"\|status | ok' "$tmpdir/out_edit" && ok_edit=1 || true
[[ "$ec_assign_cross" -eq 0 ]] && grep -q '"status" *: *"ok"\|changed' "$tmpdir/out_assign_cross" && ok_assign_cross=1 || true

if [[ "$ok_edit" -eq 1 && "$ok_assign_cross" -eq 1 ]]; then
  printf 'S4 failed: both edit and assign succeeded at the same version\n' >&2
  cat "$tmpdir/out_edit" "$tmpdir/out_assign_cross" >&2 || true
  exit 1
fi
if [[ "$ok_edit" -eq 0 && "$ok_assign_cross" -eq 0 ]]; then
  printf 'S4 failed: both edit and assign failed\n' >&2
  cat "$tmpdir/out_edit" "$tmpdir/out_assign_cross" >&2 || true
  exit 1
fi
loser_out="$tmpdir/out_edit"
[[ "$ok_edit" -eq 1 ]] && loser_out="$tmpdir/out_assign_cross"
if ! grep -qi 'stale_version' "$loser_out"; then
  printf 'S4 failed: losing branch did not report stale_version\n' >&2
  cat "$loser_out" >&2 || true
  exit 1
fi
printf 'S4 M7A edit vs assign stale_version race passed.\n'

test_passed=1
printf 'M8 assignment concurrency test passed.\n'
