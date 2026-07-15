#!/usr/bin/env bash
# Phase 7 M7A: parallel emit_calendar_meeting_notice — exactly one notice + notification.
set -euo pipefail

container_name="${1:-supabase_db_hs360}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

marker="P7M7A-NOTICE-$(date +%s)-$$"
tmpdir="$(mktemp -d)"
test_passed=0

psql_exec() {
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

cleanup_fixtures() {
  psql_exec -v marker="$marker" <<'SQL'
begin;
set local role postgres;
delete from public.calendar_meeting_notices n
using public.calendar_events ce
where n.calendar_event_id = ce.id
  and ce.title_en like :'marker' || '%';
delete from public.notifications n
where n.subject like :'marker' || '%';
delete from public.calendar_manual_event_operations op
using public.calendar_events ce
where op.result_event_id = ce.id
  and ce.title_en like :'marker' || '%';
delete from public.calendar_event_participants p
using public.calendar_events ce
where p.event_id = ce.id
  and ce.title_en like :'marker' || '%';
delete from public.calendar_reminder_plans crp
using public.calendar_events ce
where crp.calendar_event_id = ce.id
  and ce.title_en like :'marker' || '%';
delete from public.calendar_events ce
where ce.title_en like :'marker' || '%';
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

printf 'P7M7A meeting notice concurrency: parallel emit_calendar_meeting_notice\n'

psql_exec -v marker="$marker" <<'SQL' >"$tmpdir/setup.out"
begin;
set local role postgres;

insert into public.calendar_events (
  id, tenant_id, type, status, source_kind,
  scheduled_date, title_ar, title_en, created_by, schedule_version,
  meeting_mode, meeting_url
) values (
  '00000000-0000-4000-8000-00000000a701',
  '00000000-0000-0000-0000-000000000101',
  'internal_meeting'::public.calendar_event_type,
  'pending'::public.calendar_event_status,
  'manual'::public.calendar_event_source_kind,
  current_date,
  :'marker',
  :'marker',
  '00000000-0000-0000-0000-000000000201',
  1,
  'online'::public.calendar_meeting_mode,
  'https://meet.example.com/m7a-concurrency'
);

insert into public.calendar_manual_event_operations (
  id, tenant_id, operation_type, idempotency_key, business_payload_hash,
  result_status, result_event_id, result_jsonb, created_by
) values (
  '00000000-0000-4000-8000-00000000a702',
  '00000000-0000-0000-0000-000000000101',
  'update',
  '00000000-0000-4000-8000-00000000a703',
  'm7a-notice-concurrency',
  'ok',
  '00000000-0000-4000-8000-00000000a701',
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000201'
);

commit;

\echo m7a_notice_concurrency_setup_ok
SQL

emit_sql="
begin;
set local role postgres;
select public.emit_calendar_meeting_notice(
  '00000000-0000-0000-0000-000000000101'::uuid,
  '00000000-0000-4000-8000-00000000a701'::uuid,
  'meeting_updated',
  '00000000-0000-0000-0000-000000000201'::uuid,
  '00000000-0000-0000-0000-000000000601'::uuid,
  '00000000-0000-4000-8000-00000000a702'::uuid,
  (select ce from public.calendar_events ce
   where ce.id = '00000000-0000-4000-8000-00000000a701'::uuid)
);
commit;
"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$emit_sql" \
  >"$tmpdir/out1" 2>&1 &
pid1=$!
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$emit_sql" \
  >"$tmpdir/out2" 2>&1 &
pid2=$!

wait "$pid1" || ec1=$?
ec1=${ec1:-0}
wait "$pid2" || ec2=$?
ec2=${ec2:-0}

if [[ "$ec1" -ne 0 || "$ec2" -ne 0 ]]; then
  printf 'Parallel emit failed: ec1=%s ec2=%s\n' "$ec1" "$ec2" >&2
  cat "$tmpdir/out1" >&2
  cat "$tmpdir/out2" >&2
  exit 1
fi

psql_exec <<'SQL' >"$tmpdir/assert.out"
do $$
declare
  v_notice_count int;
  v_notif_count int;
begin
  select count(*) into v_notice_count
  from public.calendar_meeting_notices
  where calendar_event_id = '00000000-0000-4000-8000-00000000a701'::uuid
    and operation_id = '00000000-0000-4000-8000-00000000a702'::uuid
    and notice_kind = 'meeting_updated';

  if v_notice_count <> 1 then
    raise exception 'm7a_notice_concurrency_notice_count: %', v_notice_count;
  end if;

  select count(*) into v_notif_count
  from public.notifications n
  join public.calendar_meeting_notices mn on mn.notification_id = n.id
  where mn.calendar_event_id = '00000000-0000-4000-8000-00000000a701'::uuid
    and mn.operation_id = '00000000-0000-4000-8000-00000000a702'::uuid;

  if v_notif_count <> 1 then
    raise exception 'm7a_notice_concurrency_notif_count: %', v_notif_count;
  end if;

  raise notice 'm7a_notice_concurrency_ok';
end $$;
SQL

test_passed=1
printf 'P7M7A meeting notice concurrency test passed.\n'
