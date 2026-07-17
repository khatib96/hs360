\set ON_ERROR_STOP on

-- Phase 7 M8: assignment and rescheduling verification (migration 101).
-- Seed IDs (migration 031): tenant_a 00000000-0000-0000-0000-000000000101,
-- owner/manager user 00000000-0000-0000-0000-000000000201,
-- field user 00000000-0000-0000-0000-000000000205 (tenant_user ...305),
-- tenant_b 00000000-0000-0000-0000-000000000102.
-- Employees: owner_emp ...601 (user 201), field_emp ...602 (user 205),
-- warehouse_emp ...603 (no app account).
-- Patterns follow supabase/tests/phase_7_manual_business_events.sql and
-- supabase/tests/phase_7_working_date_exceptions.sql.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function pg_temp.m8_standard_days()
returns jsonb language sql immutable as $$
  select jsonb_build_array(
    jsonb_build_object('iso_weekday', 1, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 2, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 3, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 4, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '17:00'),
    jsonb_build_object('iso_weekday', 5, 'day_mode', 'working_hours', 'work_start', '08:00', 'work_end', '13:00'),
    jsonb_build_object('iso_weekday', 6, 'day_mode', 'day_off'),
    jsonb_build_object('iso_weekday', 7, 'day_mode', '24_hours')
  );
$$;

create or replace function pg_temp.m8_configure(p_tz text default 'Asia/Kuwait')
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', p_tz,
    'remind_event_workday_start', true,
    'remind_previous_workday_start', false,
    'days', pg_temp.m8_standard_days()
  ));
end; $$;

create or replace function pg_temp.m8_grant_perm(p_tu uuid, p_perm text)
returns void language plpgsql as $$
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (
    '00000000-0000-0000-0000-000000000101',
    p_tu,
    p_perm,
    '00000000-0000-0000-0000-000000000201'
  )
  on conflict (tenant_user_id, permission_id) do nothing;
end; $$;

create or replace function pg_temp.m8_expect_error(p_sql text, p_code text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'm8_expect_error: expected % for %', p_code, p_sql;
  exception when others then
    if sqlerrm not like '%' || p_code || '%' then
      raise exception 'm8_expect_error: got % for %', sqlerrm, p_sql;
    end if;
  end;
end; $$;

create or replace function pg_temp.m8_next_weekday(p_iso int, p_from date default current_date)
returns date language sql immutable as $$
  select (p_from + ((p_iso - extract(isodow from p_from)::int + 7) % 7))::date;
$$;

-- Create a date-only pending event as the current jwt user; returns event id.
create or replace function pg_temp.m8_create_event(p_type text, p_day date, p_title text)
returns uuid language plpgsql as $$
declare
  v_res jsonb;
begin
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', p_type,
      'scheduled_date', to_char(p_day, 'YYYY-MM-DD'),
      'title_en', p_title
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_create_event failed: %', v_res;
  end if;
  return (v_res #>> '{event,id}')::uuid;
end; $$;

create or replace function pg_temp.m8_version(p_event_id uuid)
returns int language sql as $$
  select schedule_version from public.calendar_events where id = p_event_id;
$$;

-- ---------------------------------------------------------------------------
-- 1) Bootstrap: configure schedule + grant field tenant_user calendar perms
--    (committed; idempotent).
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
select pg_temp.m8_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.view_assigned');
select pg_temp.m8_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.create');
select pg_temp.m8_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.edit');
do $$ begin raise notice 'm8_bootstrap_ok'; end $$;
commit;

-- ---------------------------------------------------------------------------
-- 2-6) Assignment lifecycle: assign / no-op re-assign / unassign / reassign
--      with version bumps, ledger rows and audit rows.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_event_id uuid;
  v_res jsonb;
  v_key uuid;
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('customer_visit', v_mon, 'M8 assign lifecycle');
  if pg_temp.m8_version(v_event_id) <> 1 then
    raise exception 'm8_assign_setup_version: %', pg_temp.m8_version(v_event_id);
  end if;

  -- 3) assign active employee: changed true + version bump + audit row.
  v_key := gen_random_uuid();
  v_res := public.assign_calendar_event(
    v_event_id, 1, jsonb_build_object('assigned_agent_id', v_field_emp::text), v_key
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true then
    raise exception 'm8_assign_failed: %', v_res;
  end if;
  if pg_temp.m8_version(v_event_id) <> 2 then
    raise exception 'm8_assign_no_version_bump: %', pg_temp.m8_version(v_event_id);
  end if;
  if (
    select assigned_agent_id from public.calendar_events where id = v_event_id
  ) is distinct from v_field_emp then
    raise exception 'm8_assign_agent_not_persisted';
  end if;

  select count(*) into v_count
  from public.audit_log
  where entity_type = 'calendar_events'
    and entity_id = v_event_id
    and action = 'assign';
  if v_count <> 1 then
    raise exception 'm8_assign_audit_count: %', v_count;
  end if;

  if (
    select after_json ->> 'assigned_agent_id'
    from public.audit_log
    where entity_type = 'calendar_events'
      and entity_id = v_event_id and action = 'assign'
    order by at desc, id desc limit 1
  ) is distinct from v_field_emp::text then
    raise exception 'm8_assign_audit_after_bad';
  end if;

  -- 4) assign same employee again: changed false, no version bump, no audit.
  v_res := public.assign_calendar_event(
    v_event_id, 2, jsonb_build_object('assigned_agent_id', v_field_emp::text),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not false then
    raise exception 'm8_assign_noop_changed: %', v_res;
  end if;
  if pg_temp.m8_version(v_event_id) <> 2 then
    raise exception 'm8_assign_noop_version_bumped';
  end if;
  select count(*) into v_count
  from public.audit_log
  where entity_type = 'calendar_events'
    and entity_id = v_event_id and action = 'assign';
  if v_count <> 1 then
    raise exception 'm8_assign_noop_audit_added: %', v_count;
  end if;

  -- No-op is still ledgered (changed=false).
  select count(*) into v_count
  from public.calendar_schedule_operations
  where result_event_id = v_event_id and operation_type = 'assign';
  if v_count <> 2 then
    raise exception 'm8_assign_ledger_count: %', v_count;
  end if;

  -- 5) unassign: changed true.
  v_res := public.assign_calendar_event(
    v_event_id, 2, jsonb_build_object('assigned_agent_id', null), gen_random_uuid()
  );
  if (v_res ->> 'changed')::boolean is not true then
    raise exception 'm8_unassign_not_changed: %', v_res;
  end if;
  if (
    select assigned_agent_id from public.calendar_events where id = v_event_id
  ) is not null then
    raise exception 'm8_unassign_not_cleared';
  end if;
  if pg_temp.m8_version(v_event_id) <> 3 then
    raise exception 'm8_unassign_version: %', pg_temp.m8_version(v_event_id);
  end if;

  -- 6) reassign to a different employee.
  v_res := public.assign_calendar_event(
    v_event_id, 3, jsonb_build_object('assigned_agent_id', v_owner_emp::text),
    gen_random_uuid()
  );
  if (v_res ->> 'changed')::boolean is not true
    or (v_res #>> '{event,assigned_agent_id}') is distinct from v_owner_emp::text then
    raise exception 'm8_reassign_failed: %', v_res;
  end if;
  if pg_temp.m8_version(v_event_id) <> 4 then
    raise exception 'm8_reassign_version: %', pg_temp.m8_version(v_event_id);
  end if;

  raise notice 'm8_assign_lifecycle_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7-8) Meetings: assign not applicable; reschedule organizer-only.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field uuid := '00000000-0000-0000-0000-000000000205';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_tue date := pg_temp.m8_next_weekday(2);
  v_res jsonb;
  v_event_id uuid;
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_meeting',
      'scheduled_date', to_char(v_mon, 'YYYY-MM-DD'),
      'title_en', 'M8 meeting',
      'meeting_mode', 'in_person',
      'free_text_location', 'Room M8',
      'participant_employee_ids', jsonb_build_array(v_field_emp::text)
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  -- 7) meeting assign is never applicable.
  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, %s, %L::jsonb, gen_random_uuid())',
      v_event_id,
      pg_temp.m8_version(v_event_id),
      jsonb_build_object('assigned_agent_id', v_field_emp::text)::text
    ),
    'calendar_assignment_not_applicable'
  );

  -- 8a) organizer reschedule ok + schedule-operation meeting notice fan-out.
  v_res := public.reschedule_calendar_event(
    v_event_id,
    pg_temp.m8_version(v_event_id),
    jsonb_build_object(
      'scheduled_date', to_char(v_tue, 'YYYY-MM-DD'),
      'reason', 'organizer moved meeting'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true then
    raise exception 'm8_meeting_reschedule_failed: %', v_res;
  end if;

  select count(*) into v_count
  from public.calendar_meeting_notices
  where calendar_event_id = v_event_id
    and notice_kind = 'meeting_updated'
    and schedule_operation_id is not null
    and recipient_employee_id = v_field_emp;
  if v_count <> 1 then
    raise exception 'm8_meeting_schedule_notice_count: %', v_count;
  end if;

  -- 8b) non-organizer (participant with calendar.edit) reschedule denied.
  perform set_config('request.jwt.claim.sub', v_field::text, true);
  perform pg_temp.m8_expect_error(
    format(
      'select public.reschedule_calendar_event(%L::uuid, %s, %L::jsonb, gen_random_uuid())',
      v_event_id,
      pg_temp.m8_version(v_event_id),
      jsonb_build_object(
        'scheduled_date', to_char(v_tue + 7, 'YYYY-MM-DD'),
        'reason', 'hijack attempt'
      )::text
    ),
    'permission_denied'
  );

  raise notice 'm8_meeting_gates_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9-13) Reschedule flows: reason + provenance, no-op, day-off confirmation,
--       ack override, override cleared on return to working day.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_tue date := pg_temp.m8_next_weekday(2, v_mon);
  v_sat date := pg_temp.m8_next_weekday(6, v_mon);
  v_event_id uuid;
  v_res jsonb;
  v_event public.calendar_events%rowtype;
  v_rescheduled_at timestamptz;
  v_count int;
  v_key uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('internal_task', v_mon, 'M8 reschedule flows');

  -- 9) reschedule to working day with reason.
  v_res := public.reschedule_calendar_event(
    v_event_id, 1,
    jsonb_build_object(
      'scheduled_date', to_char(v_tue, 'YYYY-MM-DD'),
      'reason', 'customer requested new date'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true then
    raise exception 'm8_reschedule_failed: %', v_res;
  end if;

  select * into v_event from public.calendar_events where id = v_event_id;
  if v_event.scheduled_date is distinct from v_tue
    or v_event.original_due_date is distinct from v_mon
    or v_event.status is distinct from 'pending'::public.calendar_event_status
    or v_event.rescheduled_at is null
    or v_event.rescheduled_by is distinct from v_owner
    or v_event.reschedule_reason is distinct from 'customer requested new date' then
    raise exception 'm8_reschedule_provenance_bad: %/%/%',
      v_event.scheduled_date, v_event.original_due_date, v_event.status;
  end if;
  v_rescheduled_at := v_event.rescheduled_at;

  select count(*) into v_count
  from public.audit_log
  where entity_type = 'calendar_events'
    and entity_id = v_event_id and action = 'reschedule';
  if v_count <> 1 then
    raise exception 'm8_reschedule_audit_count: %', v_count;
  end if;

  -- 10) reschedule to the same date: changed false, provenance untouched.
  v_res := public.reschedule_calendar_event(
    v_event_id, 2,
    jsonb_build_object(
      'scheduled_date', to_char(v_tue, 'YYYY-MM-DD'),
      'reason', 'same date noop'
    ),
    gen_random_uuid()
  );
  if (v_res ->> 'changed')::boolean is not false then
    raise exception 'm8_reschedule_noop_changed: %', v_res;
  end if;
  if pg_temp.m8_version(v_event_id) <> 2 then
    raise exception 'm8_reschedule_noop_version_bumped';
  end if;
  if (
    select rescheduled_at from public.calendar_events where id = v_event_id
  ) is distinct from v_rescheduled_at then
    raise exception 'm8_reschedule_noop_touched_provenance';
  end if;

  -- 11) weekly day off without ack: confirmation_required soft return,
  --     nothing ledgered, no version bump.
  v_key := gen_random_uuid();
  v_res := public.reschedule_calendar_event(
    v_event_id, 2,
    jsonb_build_object(
      'scheduled_date', to_char(v_sat, 'YYYY-MM-DD'),
      'reason', 'weekend push'
    ),
    v_key
  );
  if v_res ->> 'status' <> 'confirmation_required' then
    raise exception 'm8_dayoff_no_confirm: %', v_res;
  end if;
  select count(*) into v_count
  from public.calendar_schedule_operations
  where idempotency_key = v_key;
  if v_count <> 0 then
    raise exception 'm8_dayoff_confirm_wrote_ledger';
  end if;
  if pg_temp.m8_version(v_event_id) <> 2 then
    raise exception 'm8_dayoff_confirm_bumped_version';
  end if;

  -- 12) same move with ack + day_off_override_reason: ok, override set.
  v_res := public.reschedule_calendar_event(
    v_event_id, 2,
    jsonb_build_object(
      'scheduled_date', to_char(v_sat, 'YYYY-MM-DD'),
      'reason', 'weekend push',
      'acknowledgements', jsonb_build_object(
        'acknowledge_non_working_day', true,
        'day_off_override_reason', 'urgent weekend job'
      )
    ),
    v_key
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true then
    raise exception 'm8_dayoff_ack_failed: %', v_res;
  end if;
  select * into v_event from public.calendar_events where id = v_event_id;
  if v_event.day_off_override_reason is distinct from 'urgent weekend job'
    or v_event.day_off_override_at is null
    or v_event.day_off_override_by is distinct from v_owner then
    raise exception 'm8_dayoff_override_not_set: %', v_event.day_off_override_reason;
  end if;

  -- 13) reschedule back to a working day: override cleared.
  v_res := public.reschedule_calendar_event(
    v_event_id, 3,
    jsonb_build_object(
      'scheduled_date', to_char(v_mon + 7, 'YYYY-MM-DD'),
      'reason', 'back to weekday'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_back_to_weekday_failed: %', v_res;
  end if;
  select * into v_event from public.calendar_events where id = v_event_id;
  if v_event.day_off_override_reason is not null
    or v_event.day_off_override_at is not null
    or v_event.day_off_override_by is not null then
    raise exception 'm8_override_not_cleared';
  end if;

  raise notice 'm8_reschedule_flows_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14-16) Optimistic concurrency + idempotency: stale_version, replay,
--        payload mismatch.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_tue date := pg_temp.m8_next_weekday(2, v_mon);
  v_event_id uuid;
  v_key uuid := gen_random_uuid();
  v_res1 jsonb;
  v_res2 jsonb;
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('internal_task', v_mon, 'M8 idempotency');

  -- 14) stale expected_version rejected for both RPCs.
  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, 99, %L::jsonb, gen_random_uuid())',
      v_event_id, jsonb_build_object('assigned_agent_id', v_field_emp::text)::text
    ),
    'stale_version'
  );
  perform pg_temp.m8_expect_error(
    format(
      'select public.reschedule_calendar_event(%L::uuid, 99, %L::jsonb, gen_random_uuid())',
      v_event_id,
      jsonb_build_object(
        'scheduled_date', to_char(v_tue, 'YYYY-MM-DD'), 'reason', 'stale probe'
      )::text
    ),
    'stale_version'
  );

  -- 15) idempotent replay: same key + same payload returns the stored result
  --     without a second version bump or duplicate ledger row.
  v_res1 := public.assign_calendar_event(
    v_event_id, 1, jsonb_build_object('assigned_agent_id', v_field_emp::text), v_key
  );
  if v_res1 ->> 'status' <> 'ok' then
    raise exception 'm8_idem_first_failed: %', v_res1;
  end if;
  v_res2 := public.assign_calendar_event(
    v_event_id, 1, jsonb_build_object('assigned_agent_id', v_field_emp::text), v_key
  );
  if v_res2 is distinct from v_res1 then
    raise exception 'm8_idem_replay_mismatch';
  end if;
  if pg_temp.m8_version(v_event_id) <> 2 then
    raise exception 'm8_idem_replay_version: %', pg_temp.m8_version(v_event_id);
  end if;
  select count(*) into v_count
  from public.calendar_schedule_operations
  where idempotency_key = v_key;
  if v_count <> 1 then
    raise exception 'm8_idem_ledger_count: %', v_count;
  end if;

  -- 16) same key + changed payload rejected.
  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, 1, %L::jsonb, %L::uuid)',
      v_event_id, jsonb_build_object('assigned_agent_id', v_owner_emp::text)::text, v_key
    ),
    'idempotency_payload_mismatch'
  );

  raise notice 'm8_concurrency_idempotency_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17-18) Assignee validation: inactive employee and cross-tenant employee.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_warehouse_emp uuid := '00000000-0000-0000-0000-000000000603';
  v_tenant_b_emp uuid := '00000000-0000-0000-0000-00000000e8b1';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_event_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('custom', v_mon, 'M8 assignee validation');

  -- 17) inactive tenant employee rejected.
  update public.employees set is_active = false where id = v_warehouse_emp;
  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
      v_event_id, jsonb_build_object('assigned_agent_id', v_warehouse_emp::text)::text
    ),
    'validation_failed'
  );

  -- 18) tenant B employee invisible to tenant A assign.
  insert into public.employees (
    id, tenant_id, name_ar, name_en, is_active, user_id, code, hire_date, job_type
  ) values (
    v_tenant_b_emp,
    '00000000-0000-0000-0000-000000000102',
    'موظف ب', 'Tenant B Emp', true, null, 'M8-XTEN', current_date, 'other'
  );
  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
      v_event_id, jsonb_build_object('assigned_agent_id', v_tenant_b_emp::text)::text
    ),
    'validation_failed'
  );

  if (
    select assigned_agent_id from public.calendar_events where id = v_event_id
  ) is not null or pg_temp.m8_version(v_event_id) <> 1 then
    raise exception 'm8_invalid_assignee_mutated_event';
  end if;

  raise notice 'm8_assignee_validation_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19) available_actions.can_assign: false for meeting, true for pending
--     non-meeting with edit capability, false once cancelled.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field uuid := '00000000-0000-0000-0000-000000000205';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_res jsonb;
  v_event_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  -- Meeting: can_assign false, can_reschedule true for organizer.
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_meeting',
      'scheduled_date', to_char(v_mon, 'YYYY-MM-DD'),
      'title_en', 'M8 actions meeting',
      'meeting_mode', 'in_person',
      'free_text_location', 'Room A'
    ),
    gen_random_uuid()
  );
  if coalesce((v_res #>> '{event,available_actions,can_assign}')::boolean, true) then
    raise exception 'm8_actions_meeting_can_assign: %', v_res #> '{event,available_actions}';
  end if;
  if coalesce((v_res #>> '{event,available_actions,can_reschedule}')::boolean, false) is not true then
    raise exception 'm8_actions_meeting_can_reschedule: %', v_res #> '{event,available_actions}';
  end if;

  -- Pending non-meeting, owner (manager): can_assign true.
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', to_char(v_mon, 'YYYY-MM-DD'),
      'title_en', 'M8 actions visit'
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;
  if coalesce((v_res #>> '{event,available_actions,can_assign}')::boolean, false) is not true then
    raise exception 'm8_actions_visit_can_assign: %', v_res #> '{event,available_actions}';
  end if;

  -- Field user with calendar.edit sees can_assign true on own pending event.
  perform set_config('request.jwt.claim.sub', v_field::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'custom',
      'scheduled_date', to_char(v_mon, 'YYYY-MM-DD'),
      'title_en', 'M8 actions field custom'
    ),
    gen_random_uuid()
  );
  if coalesce((v_res #>> '{event,available_actions,can_assign}')::boolean, false) is not true then
    raise exception 'm8_actions_field_can_assign: %', v_res #> '{event,available_actions}';
  end if;

  -- Cancelled: can_assign / can_reschedule false.
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.cancel_manual_calendar_event(
    v_event_id, pg_temp.m8_version(v_event_id), 'm8 actions cancel', gen_random_uuid()
  );
  if coalesce((v_res #>> '{event,available_actions,can_assign}')::boolean, true)
    or coalesce((v_res #>> '{event,available_actions,can_reschedule}')::boolean, true) then
    raise exception 'm8_actions_cancelled: %', v_res #> '{event,available_actions}';
  end if;

  raise notice 'm8_available_actions_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20-21) List integration: working_day carries date_exception on a holiday and
--        working_day_conflict filter matches only conflicted events.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_holiday date := pg_temp.m8_next_weekday(1) + 21; -- future Monday
  v_workday date := pg_temp.m8_next_weekday(1) + 28; -- following Monday
  v_res jsonb;
  v_holiday_event uuid;
  v_workday_event uuid;
  v_list jsonb;
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_holiday_event := pg_temp.m8_create_event('internal_task', v_holiday, 'M8 holiday event');
  v_workday_event := pg_temp.m8_create_event('internal_task', v_workday, 'M8 workday event');

  v_res := public.create_working_date_exception(
    jsonb_build_object(
      'kind', 'official_holiday',
      'start_date', to_char(v_holiday, 'YYYY-MM-DD'),
      'end_date', to_char(v_holiday, 'YYYY-MM-DD'),
      'title_en', 'M8 Holiday'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_holiday_create_failed: %', v_res;
  end if;

  -- 20) working_day.date_exception present on the holiday row.
  v_list := public.list_calendar_events(v_holiday, v_workday, '{}'::jsonb);
  select r.value into v_row
  from jsonb_array_elements(v_list #> '{in_range,rows}') r
  where r.value ->> 'id' = v_holiday_event::text;
  if v_row is null then
    raise exception 'm8_holiday_event_missing: %', v_list;
  end if;
  if v_row #>> '{working_day,date_exception,kind}' is distinct from 'official_holiday' then
    raise exception 'm8_working_day_date_exception_missing: %', v_row -> 'working_day';
  end if;
  if v_row ->> 'schedule_state' is distinct from 'non_working_day' then
    raise exception 'm8_holiday_schedule_state: %', v_row ->> 'schedule_state';
  end if;

  -- 21) working_day_conflict filter returns the holiday event only.
  v_list := public.list_calendar_events(
    v_holiday, v_workday, jsonb_build_object('working_day_conflict', true)
  );
  if not exists (
    select 1 from jsonb_array_elements(v_list #> '{in_range,rows}') r
    where r.value ->> 'id' = v_holiday_event::text
  ) then
    raise exception 'm8_conflict_filter_missing_holiday_event: %', v_list;
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_list #> '{in_range,rows}') r
    where r.value ->> 'id' = v_workday_event::text
  ) then
    raise exception 'm8_conflict_filter_leaked_workday_event: %', v_list;
  end if;

  raise notice 'm8_working_day_conflict_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 22) Candidate list carries account/access reachability flags.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_warehouse_emp uuid := '00000000-0000-0000-0000-000000000603';
  v_res jsonb;
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.list_calendar_participant_candidates(null, 100);

  select r.value into v_row
  from jsonb_array_elements(v_res -> 'rows') r
  where r.value ->> 'employee_id' = v_field_emp::text;
  if v_row is null then
    raise exception 'm8_candidates_missing_field_emp: %', v_res;
  end if;
  if not (v_row ? 'has_app_account')
    or not (v_row ? 'has_active_tenant_account')
    or not (v_row ? 'has_calendar_access') then
    raise exception 'm8_candidates_missing_flags: %', v_row;
  end if;
  if (v_row ->> 'has_app_account')::boolean is not true
    or (v_row ->> 'has_active_tenant_account')::boolean is not true
    or (v_row ->> 'has_calendar_access')::boolean is not true then
    raise exception 'm8_candidates_field_flags_wrong: %', v_row;
  end if;

  select r.value into v_row
  from jsonb_array_elements(v_res -> 'rows') r
  where r.value ->> 'employee_id' = v_warehouse_emp::text;
  if v_row is null then
    raise exception 'm8_candidates_missing_warehouse_emp: %', v_res;
  end if;
  if (v_row ->> 'has_app_account')::boolean is not false
    or (v_row ->> 'has_active_tenant_account')::boolean is not false
    or (v_row ->> 'has_calendar_access')::boolean is not false then
    raise exception 'm8_candidates_warehouse_flags_wrong: %', v_row;
  end if;

  raise notice 'm8_candidate_flags_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 23) ACL: anon cannot execute assign/reschedule; authenticated can; internal
--     schedule helpers stay unreachable.
-- ---------------------------------------------------------------------------
begin;
do $$
begin
  if not has_function_privilege(
      'authenticated', 'public.assign_calendar_event(uuid, int, jsonb, uuid)', 'EXECUTE'
    )
    or not has_function_privilege(
      'authenticated', 'public.reschedule_calendar_event(uuid, int, jsonb, uuid)', 'EXECUTE'
    ) then
    raise exception 'm8_acl_authenticated_missing_execute';
  end if;

  if has_function_privilege(
      'anon', 'public.assign_calendar_event(uuid, int, jsonb, uuid)', 'EXECUTE'
    )
    or has_function_privilege(
      'anon', 'public.reschedule_calendar_event(uuid, int, jsonb, uuid)', 'EXECUTE'
    ) then
    raise exception 'm8_acl_anon_has_execute';
  end if;

  if has_function_privilege(
      'authenticated', 'public.record_calendar_schedule_operation(text, uuid, text, uuid, jsonb)', 'EXECUTE'
    )
    or has_function_privilege(
      'authenticated', 'public.resolve_calendar_schedule_idempotency(text, uuid, text)', 'EXECUTE'
    )
    or has_function_privilege(
      'authenticated', 'public.calendar_schedule_payload_hash(jsonb)', 'EXECUTE'
    ) then
    raise exception 'm8_acl_internal_helper_leaked';
  end if;

  if has_table_privilege('authenticated', 'public.calendar_schedule_operations', 'SELECT')
    or has_table_privilege('anon', 'public.calendar_schedule_operations', 'SELECT') then
    raise exception 'm8_acl_ledger_select_leaked';
  end if;
end $$;
set local role anon;
do $$
begin
  begin
    perform public.assign_calendar_event(
      gen_random_uuid(), 1, '{}'::jsonb, gen_random_uuid()
    );
    raise exception 'm8_anon_assign_executed';
  exception
    when insufficient_privilege then null;
    when others then
      raise exception 'm8_anon_assign_wrong_error: %', sqlerrm;
  end;

  begin
    perform public.reschedule_calendar_event(
      gen_random_uuid(), 1, '{}'::jsonb, gen_random_uuid()
    );
    raise exception 'm8_anon_reschedule_executed';
  exception
    when insufficient_privilege then null;
    when others then
      raise exception 'm8_anon_reschedule_wrong_error: %', sqlerrm;
  end;

  raise notice 'm8_acl_anon_denied_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 24) Legacy status 'rescheduled' is never a mutable pending state.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_tue date := pg_temp.m8_next_weekday(2, v_mon);
  v_event_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('internal_task', v_mon, 'M8 legacy rescheduled');

  -- Force the legacy enum status via the postgres role (no RPC produces it).
  update public.calendar_events
  set status = 'rescheduled'::public.calendar_event_status
  where id = v_event_id;

  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
      v_event_id, jsonb_build_object('assigned_agent_id', v_field_emp::text)::text
    ),
    'validation_failed'
  );
  perform pg_temp.m8_expect_error(
    format(
      'select public.reschedule_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
      v_event_id,
      jsonb_build_object(
        'scheduled_date', to_char(v_tue, 'YYYY-MM-DD'),
        'reason', 'legacy status probe'
      )::text
    ),
    'validation_failed'
  );

  raise notice 'm8_legacy_rescheduled_status_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 25) Timed event reschedule preserves the local HH:mm window.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_wed date := pg_temp.m8_next_weekday(3, v_mon);
  v_res jsonb;
  v_event_id uuid;
  v_event public.calendar_events%rowtype;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', to_char(v_mon, 'YYYY-MM-DD'),
      'title_en', 'M8 timed visit',
      'time_window', jsonb_build_object('start_local', '09:00', 'end_local', '10:30')
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_timed_create_failed: %', v_res;
  end if;
  v_event_id := (v_res #>> '{event,id}')::uuid;

  v_res := public.reschedule_calendar_event(
    v_event_id, pg_temp.m8_version(v_event_id),
    jsonb_build_object(
      'scheduled_date', to_char(v_wed, 'YYYY-MM-DD'),
      'reason', 'shift timed visit'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_timed_reschedule_failed: %', v_res;
  end if;

  select * into v_event from public.calendar_events where id = v_event_id;
  if v_event.scheduled_date is distinct from v_wed
    or v_event.scheduled_timezone_name is distinct from 'Asia/Kuwait' then
    raise exception 'm8_timed_move_wrong: % %', v_event.scheduled_date, v_event.scheduled_timezone_name;
  end if;
  if to_char(v_event.scheduled_start_at at time zone 'Asia/Kuwait', 'HH24:MI') <> '09:00'
    or to_char(v_event.scheduled_end_at at time zone 'Asia/Kuwait', 'HH24:MI') <> '10:30' then
    raise exception 'm8_timed_local_time_lost: % - %',
      v_event.scheduled_start_at, v_event.scheduled_end_at;
  end if;
  if (v_event.scheduled_start_at at time zone 'Asia/Kuwait')::date is distinct from v_wed then
    raise exception 'm8_timed_local_date_wrong: %', v_event.scheduled_start_at;
  end if;
  if v_res #>> '{event,time_window,start_local}' is distinct from '09:00'
    or v_res #>> '{event,time_window,end_local}' is distinct from '10:30' then
    raise exception 'm8_timed_response_window_wrong: %', v_res #> '{event,time_window}';
  end if;

  raise notice 'm8_timed_reschedule_local_time_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 26) EXPLAIN / performance regression gate for resolved working-day reads.
-- Explains calendar_read_scoped_events (inlined join of resolve window) and
-- rejects an absurdly large plan text (cartesian explosion signal).
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_today date := public.try_tenant_local_today(v_tenant);
  v_filters public.calendar_read_filter_bundle;
  v_plan jsonb;
  v_text text;
begin
  v_filters := public.parse_calendar_read_filters('{}'::jsonb, 'tenant_wide', null);

  execute format(
    $q$
      explain (format json, analyze false, verbose false, buffers false, costs true)
      select * from public.calendar_read_scoped_events(
        %L::uuid, 'tenant_wide', null, %L::public.calendar_read_filter_bundle, %L::date
      )
    $q$,
    v_tenant,
    v_filters,
    v_today
  )
  into v_plan;

  if v_plan is null or jsonb_typeof(v_plan) <> 'array' then
    raise exception 'm8_explain_failed: empty_or_invalid_plan';
  end if;

  v_text := lower(v_plan::text);
  -- LANGUAGE sql helpers often appear as a Function Scan of the helper itself
  -- rather than inlined table nodes; either form is acceptable.
  if position('calendar_events' in v_text) = 0
    and position('calendar_read_scoped_events' in v_text) = 0 then
    raise exception 'm8_explain_failed: plan_missing_calendar_nodes: %', left(v_text, 500);
  end if;

  -- Soft regression: reject a plan that is absurdly large for tenant-scoped
  -- reads (signals accidental cartesian explosion after the M7B resolve join).
  if length(v_text) > 200000 then
    raise exception 'm8_explain_failed: plan_text_too_large (% bytes)', length(v_text);
  end if;

  raise notice 'm8_explain_scoped_events_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 27) Assign payload contract: assigned_agent_id must be explicitly present;
--     the full malformed matrix is rejected with no side effects.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_event_id uuid;
  v_res jsonb;
  v_bad text;
  v_audit int;
  v_ledger int;
  v_reminders int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('internal_task', v_mon, 'M8 payload contract');

  select count(*) into v_audit
  from public.audit_log
  where entity_type = 'calendar_events' and entity_id = v_event_id;
  select count(*) into v_ledger
  from public.calendar_schedule_operations where result_event_id = v_event_id;
  select count(*) into v_reminders
  from public.calendar_reminder_plans where calendar_event_id = v_event_id;

  -- Malformed matrix: each payload must fail validation.
  for v_bad in
    select unnest(array[
      '{}',                                                    -- key absent
      '{"assigned_agent_id": ""}',                             -- empty string
      '{"assigned_agent_id": "   "}',                          -- whitespace only
      '{"assigned_agent_id": "not-a-uuid"}',                   -- malformed uuid
      '{"assigned_agent_id": 5}',                              -- wrong type: number
      '{"assigned_agent_id": true}',                           -- wrong type: boolean
      '{"assigned_agent_id": ["00000000-0000-0000-0000-000000000602"]}', -- array
      '{"assigned_agent_id": {"id": "00000000-0000-0000-0000-000000000602"}}', -- object
      '{"agent_id": "00000000-0000-0000-0000-000000000602"}',  -- unknown key
      '{"assigned_agent_id": null, "extra": 1}',               -- additional key
      '"00000000-0000-0000-0000-000000000602"',                -- non-object: string
      '[]',                                                    -- non-object: array
      'null'                                                   -- json null
    ])
  loop
    perform pg_temp.m8_expect_error(
      format(
        'select public.assign_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
        v_event_id, v_bad
      ),
      'validation_failed'
    );
  end loop;

  -- SQL null p_data also rejected.
  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, 1, null::jsonb, gen_random_uuid())',
      v_event_id
    ),
    'validation_failed'
  );

  -- No side effects from any invalid payload: version, assignee, audit,
  -- ledger and reminder plans untouched.
  if pg_temp.m8_version(v_event_id) <> 1
    or (select assigned_agent_id from public.calendar_events where id = v_event_id) is not null then
    raise exception 'm8_payload_matrix_mutated_event';
  end if;
  if (
    select count(*) from public.audit_log
    where entity_type = 'calendar_events' and entity_id = v_event_id
  ) <> v_audit then
    raise exception 'm8_payload_matrix_audit_added';
  end if;
  if (
    select count(*) from public.calendar_schedule_operations
    where result_event_id = v_event_id
  ) <> v_ledger then
    raise exception 'm8_payload_matrix_ledger_added';
  end if;
  if (
    select count(*) from public.calendar_reminder_plans
    where calendar_event_id = v_event_id
  ) <> v_reminders then
    raise exception 'm8_payload_matrix_reminders_touched';
  end if;

  -- Explicit null remains a valid unassignment: assign then unassign.
  v_res := public.assign_calendar_event(
    v_event_id, 1, jsonb_build_object('assigned_agent_id', v_field_emp::text), gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true then
    raise exception 'm8_payload_assign_failed: %', v_res;
  end if;
  v_res := public.assign_calendar_event(
    v_event_id, 2, '{"assigned_agent_id": null}'::jsonb, gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true
    or (select assigned_agent_id from public.calendar_events where id = v_event_id) is not null then
    raise exception 'm8_payload_explicit_null_unassign_failed: %', v_res;
  end if;

  raise notice 'm8_assign_payload_contract_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 28) Strict reschedule date contract: exact canonical YYYY-MM-DD only.
--     Valid leap day accepted; permissive ::date spellings rejected.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_event_id uuid;
  v_res jsonb;
  v_bad text;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('internal_task', v_mon, 'M8 date contract');

  -- Malformed / noncanonical scheduled_date matrix (all valid ::date inputs
  -- for PostgreSQL except the impossible dates, so this proves the strict
  -- contract is enforced beyond the cast).
  for v_bad in
    select unnest(array[
      '2026-7-1',              -- unpadded components
      '2026/07/01',            -- wrong separators
      ' 2026-07-01',           -- leading whitespace
      '2026-07-01 ',           -- trailing whitespace
      '2026-07-01T00:00:00',   -- ISO timestamp
      '2026-07-01 10:00',      -- timestamp with time
      '01-07-2026',            -- reordered components
      '20260701',              -- compact form
      '2026-02-30',            -- impossible day
      '2026-13-01',            -- impossible month
      '2027-02-29'             -- non-leap-year Feb 29
    ])
  loop
    perform pg_temp.m8_expect_error(
      format(
        'select public.reschedule_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
        v_event_id,
        jsonb_build_object('scheduled_date', v_bad, 'reason', 'strict date probe')::text
      ),
      'validation_failed'
    );
  end loop;

  -- Non-string and null scheduled_date values rejected.
  perform pg_temp.m8_expect_error(
    format(
      'select public.reschedule_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
      v_event_id, '{"scheduled_date": 20260701, "reason": "strict date probe"}'
    ),
    'validation_failed'
  );
  perform pg_temp.m8_expect_error(
    format(
      'select public.reschedule_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
      v_event_id, '{"scheduled_date": null, "reason": "strict date probe"}'
    ),
    'validation_failed'
  );
  perform pg_temp.m8_expect_error(
    format(
      'select public.reschedule_calendar_event(%L::uuid, 1, %L::jsonb, gen_random_uuid())',
      v_event_id, '{"reason": "strict date probe"}'
    ),
    'validation_failed'
  );

  -- No mutation happened.
  if pg_temp.m8_version(v_event_id) <> 1
    or (select scheduled_date from public.calendar_events where id = v_event_id) is distinct from v_mon then
    raise exception 'm8_date_matrix_mutated_event';
  end if;

  -- Valid canonical leap day accepted (2028-02-29 is a Tuesday: working day).
  v_res := public.reschedule_calendar_event(
    v_event_id, 1,
    jsonb_build_object('scheduled_date', '2028-02-29', 'reason', 'leap day move'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true
    or (select scheduled_date from public.calendar_events where id = v_event_id)
      is distinct from date '2028-02-29' then
    raise exception 'm8_leap_day_reschedule_failed: %', v_res;
  end if;

  raise notice 'm8_strict_date_contract_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 29) Server-authoritative available_actions: an assigned-only user who
--     reassigns the event away loses row visibility, actionable flags, and
--     read access; creator/participant visibility is retained when present.
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m8_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field uuid := '00000000-0000-0000-0000-000000000205';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_mon date := pg_temp.m8_next_weekday(1);
  v_tue date := pg_temp.m8_next_weekday(2, v_mon);
  v_event_id uuid;
  v_res jsonb;
  v_actions jsonb;
  v_list jsonb;
begin
  -- Fixture: owner creates the event (field user is NOT creator) with no
  -- participants, then assigns it to the field employee.
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_event_id := pg_temp.m8_create_event('customer_visit', v_mon, 'M8 assigned-only loss');
  v_res := public.assign_calendar_event(
    v_event_id, 1, jsonb_build_object('assigned_agent_id', v_field_emp::text), gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_visloss_setup_failed: %', v_res;
  end if;

  -- Field user (calendar.view_assigned + calendar.edit) sees it only as
  -- assignee.
  perform set_config('request.jwt.claim.sub', v_field::text, true);
  if exists (
    select 1 from public.calendar_event_participants
    where event_id = v_event_id and employee_id = v_field_emp
  ) then
    raise exception 'm8_visloss_unexpected_participant';
  end if;
  v_list := public.list_calendar_events(v_mon, v_mon, '{}'::jsonb);
  if not exists (
    select 1 from jsonb_array_elements(v_list #> '{in_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
  ) then
    raise exception 'm8_visloss_not_visible_before: %', v_list;
  end if;

  -- Reassign away from self: succeeds, but the response carries no actionable
  -- row flags because the caller lost visibility.
  v_res := public.assign_calendar_event(
    v_event_id, 2, jsonb_build_object('assigned_agent_id', v_owner_emp::text), gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' or (v_res ->> 'changed')::boolean is not true then
    raise exception 'm8_visloss_reassign_failed: %', v_res;
  end if;
  v_actions := v_res #> '{event,available_actions}';
  if coalesce((v_actions ->> 'can_assign')::boolean, true)
    or coalesce((v_actions ->> 'can_reschedule')::boolean, true)
    or coalesce((v_actions ->> 'can_edit_manual')::boolean, true)
    or coalesce((v_actions ->> 'can_cancel_manual')::boolean, true)
    or coalesce((v_actions ->> 'can_mark_manual_done')::boolean, true)
    or coalesce((v_actions ->> 'can_open_meeting_link')::boolean, true)
    or coalesce((v_actions ->> 'can_view_customer')::boolean, true)
    or coalesce((v_actions ->> 'can_view_contract')::boolean, true)
    or coalesce((v_actions ->> 'can_open_directions')::boolean, true) then
    raise exception 'm8_visloss_actions_leaked: %', v_actions;
  end if;

  -- Retrying assignment or rescheduling is now permission_denied.
  perform pg_temp.m8_expect_error(
    format(
      'select public.assign_calendar_event(%L::uuid, 3, %L::jsonb, gen_random_uuid())',
      v_event_id, jsonb_build_object('assigned_agent_id', v_field_emp::text)::text
    ),
    'permission_denied'
  );
  perform pg_temp.m8_expect_error(
    format(
      'select public.reschedule_calendar_event(%L::uuid, 3, %L::jsonb, gen_random_uuid())',
      v_event_id,
      jsonb_build_object(
        'scheduled_date', to_char(v_tue, 'YYYY-MM-DD'), 'reason', 'visloss probe'
      )::text
    ),
    'permission_denied'
  );

  -- Range/list reads no longer include the event.
  v_list := public.list_calendar_events(v_mon, v_mon, '{}'::jsonb);
  if exists (
    select 1 from jsonb_array_elements(v_list #> '{in_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
  ) then
    raise exception 'm8_visloss_still_listed: %', v_list;
  end if;

  -- Creator-based visibility is retained: field user creates their own event,
  -- assigns it away, and keeps actionable flags plus list visibility.
  v_event_id := pg_temp.m8_create_event('custom', v_mon, 'M8 creator retention');
  v_res := public.assign_calendar_event(
    v_event_id, 1, jsonb_build_object('assigned_agent_id', v_owner_emp::text), gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok'
    or coalesce((v_res #>> '{event,available_actions,can_assign}')::boolean, false) is not true
    or coalesce((v_res #>> '{event,available_actions,can_reschedule}')::boolean, false) is not true then
    raise exception 'm8_creator_retention_failed: %', v_res #> '{event,available_actions}';
  end if;
  v_list := public.list_calendar_events(v_mon, v_mon, '{}'::jsonb);
  if not exists (
    select 1 from jsonb_array_elements(v_list #> '{in_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
  ) then
    raise exception 'm8_creator_retention_not_listed: %', v_list;
  end if;

  -- Participant-based visibility is retained after reassigning away.
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', to_char(v_mon, 'YYYY-MM-DD'),
      'title_en', 'M8 participant retention',
      'participant_employee_ids', jsonb_build_array(v_field_emp::text)
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_participant_retention_create_failed: %', v_res;
  end if;
  v_event_id := (v_res #>> '{event,id}')::uuid;
  v_res := public.assign_calendar_event(
    v_event_id, 1, jsonb_build_object('assigned_agent_id', v_field_emp::text), gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm8_participant_retention_assign_failed: %', v_res;
  end if;

  perform set_config('request.jwt.claim.sub', v_field::text, true);
  v_res := public.assign_calendar_event(
    v_event_id, 2, jsonb_build_object('assigned_agent_id', v_owner_emp::text), gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok'
    or coalesce((v_res #>> '{event,available_actions,can_assign}')::boolean, false) is not true then
    raise exception 'm8_participant_retention_failed: %', v_res #> '{event,available_actions}';
  end if;
  v_list := public.list_calendar_events(v_mon, v_mon, '{}'::jsonb);
  if not exists (
    select 1 from jsonb_array_elements(v_list #> '{in_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
  ) then
    raise exception 'm8_participant_retention_not_listed: %', v_list;
  end if;

  raise notice 'm8_visibility_authoritative_actions_ok';
end $$;
rollback;

do $$ begin raise notice 'm8_calendar_assignment_suite_complete'; end $$;

select 'phase_7_calendar_assignment_verification_passed' as result;
