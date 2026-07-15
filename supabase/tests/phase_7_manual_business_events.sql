\set ON_ERROR_STOP on

-- Phase 7 M7A: manual business events high-value verification.

create or replace function pg_temp.m7a_standard_days()
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

create or replace function pg_temp.m7a_configure(p_tz text default 'Asia/Kuwait')
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', p_tz,
    'remind_event_workday_start', true,
    'remind_previous_workday_start', false,
    'days', pg_temp.m7a_standard_days()
  ));
end; $$;

create or replace function pg_temp.m7a_grant_perm(p_tu uuid, p_perm text)
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

create or replace function pg_temp.m7a_expect_error(p_sql text, p_code text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'm7a_expect_error: expected % for %', p_code, p_sql;
  exception when others then
    if sqlerrm not like '%' || p_code || '%' then
      raise exception 'm7a_expect_error: got % for %', sqlerrm, p_sql;
    end if;
  end;
end; $$;

create or replace function pg_temp.m7a_next_weekday(p_iso int, p_from date default current_date)
returns date language sql immutable as $$
  select (p_from + ((p_iso - extract(isodow from p_from)::int + 7) % 7))::date;
$$;

create or replace function pg_temp.m7a_drain_reconcile(p_tenant_id uuid)
returns void language plpgsql as $$
declare
  v_i int;
begin
  for v_i in 1..10 loop
    perform public.reconcile_tenant_calendar_reminder_plans(p_tenant_id, 500);
    exit when not exists (
      select 1
      from public.calendar_reminder_reconcile_queue q
      where q.tenant_id = p_tenant_id
        and (
          q.generation is distinct from q.processed_generation
          or q.scan_after_event_id is not null
          or q.processing_generation is not null
        )
    );
  end loop;
end; $$;

create or replace function pg_temp.m7a_force_delivery_ready(p_plan_id uuid)
returns void language plpgsql as $$
begin
  update public.calendar_reminder_plans crp set
    status = 'delivery_pending',
    next_attempt_at = null,
    attempt_count = 0,
    updated_at = now()
  where crp.id = p_plan_id
    and crp.status = 'planned'::public.calendar_reminder_plan_status
    and crp.anchor_utc <= now()
    and crp.anchor_local_date = public.try_tenant_local_today(crp.tenant_id);
end; $$;

create or replace function pg_temp.m7a_deliver_plan(p_plan_id uuid)
returns void language plpgsql as $$
declare
  v_tenant_id uuid;
  v_status public.calendar_reminder_plan_status;
begin
  select tenant_id, status into v_tenant_id, v_status
  from public.calendar_reminder_plans
  where id = p_plan_id;

  if not found then
    raise exception 'm7a_deliver_plan: missing plan %', p_plan_id;
  end if;

  if v_status = 'delivered'::public.calendar_reminder_plan_status then
    return;
  end if;

  perform pg_temp.m7a_drain_reconcile(v_tenant_id);

  select status into v_status
  from public.calendar_reminder_plans
  where id = p_plan_id;

  if v_status = 'planned'::public.calendar_reminder_plan_status then
    update public.calendar_reminder_plans
    set
      anchor_utc = case
        when anchor_utc > now() then now() - interval '1 minute'
        else anchor_utc
      end,
      updated_at = now()
    where id = p_plan_id
      and status = 'planned'::public.calendar_reminder_plan_status;

    perform pg_temp.m7a_force_delivery_ready(p_plan_id);
  elsif v_status is distinct from 'delivery_pending'::public.calendar_reminder_plan_status then
    raise exception 'm7a_deliver_plan: unexpected status % for %', v_status, p_plan_id;
  end if;

  perform public.deliver_calendar_reminder_plan_locked(p_plan_id);
end; $$;

-- ---------------------------------------------------------------------------
-- Bootstrap schedule + field calendar.view_assigned + calendar.edit/create for owner
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
select pg_temp.m7a_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.view_assigned');
select pg_temp.m7a_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.create');
select pg_temp.m7a_grant_perm('00000000-0000-0000-0000-000000000305', 'calendar.edit');
do $$ begin raise notice 'm7a_bootstrap_ok'; end $$;
commit;

-- ---------------------------------------------------------------------------
-- 1) Type ranks
-- ---------------------------------------------------------------------------
begin;
do $$
begin
  if public.calendar_event_type_sort_rank('customer_visit') <> 9
    or public.calendar_event_type_sort_rank('internal_meeting') <> 10
    or public.calendar_event_type_sort_rank('internal_task') <> 11
    or public.calendar_event_type_sort_rank('internal_activity') <> 12
    or public.calendar_event_type_sort_rank('custom') <> 13 then
    raise exception 'm7a_rank_failed';
  end if;
  raise notice 'm7a_type_ranks_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2) HTTPS URL validator
-- ---------------------------------------------------------------------------
begin;
do $$
begin
  if not public.calendar_is_safe_https_url('https://meet.example.com/abc') then
    raise exception 'm7a_https_valid_rejected';
  end if;
  if public.calendar_is_safe_https_url('http://meet.example.com/abc') then
    raise exception 'm7a_http_accepted';
  end if;
  if public.calendar_is_safe_https_url('https://user:pass@meet.example.com/abc') then
    raise exception 'm7a_creds_accepted';
  end if;
  if public.calendar_is_safe_https_url('javascript:alert(1)') then
    raise exception 'm7a_javascript_accepted';
  end if;
  raise notice 'm7a_https_validator_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3) Time triple CHECK + DST reject on appointment resolve
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure('America/New_York');
do $$
declare
  v_spring date;
begin
  -- US spring-forward 2026-03-08: 02:30 nonexistent in America/New_York
  v_spring := date '2026-03-08';
  begin
    perform public.resolve_appointment_local_timestamptz(
      'America/New_York', v_spring, time '02:30'
    );
    raise exception 'm7a_dst_nonexistent_accepted';
  exception when others then
    if sqlerrm not like '%calendar_local_time_nonexistent%' then
      raise exception 'm7a_dst_nonexistent_wrong: %', sqlerrm;
    end if;
  end;

  -- Fall back 2025-11-02 01:30 ambiguous
  begin
    perform public.resolve_appointment_local_timestamptz(
      'America/New_York', date '2025-11-02', time '01:30'
    );
    raise exception 'm7a_dst_ambiguous_accepted';
  exception when others then
    if sqlerrm not like '%calendar_local_time_ambiguous%' then
      raise exception 'm7a_dst_ambiguous_wrong: %', sqlerrm;
    end if;
  end;

  raise notice 'm7a_dst_reject_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4) Create types + meeting organizer gate + https meeting_url
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field uuid := '00000000-0000-0000-0000-000000000205';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_day date := pg_temp.m7a_next_weekday(1);
  v_res jsonb;
  v_event_id uuid;
  v_key uuid := gen_random_uuid();
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  -- customer_visit date-only
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_ar', 'زيارة',
      'title_en', 'Visit'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm7a_create_visit_failed: %', v_res;
  end if;
  if v_res #>> '{event,time_window}' is not null
    and jsonb_typeof(v_res -> 'event' -> 'time_window') <> 'null' then
    -- key must exist; value may be JSON null
    null;
  end if;
  if not (v_res -> 'event' ? 'time_window') then
    raise exception 'm7a_missing_time_window_key';
  end if;
  if not (v_res -> 'event' ? 'participants') then
    raise exception 'm7a_missing_participants_key';
  end if;

  -- online meeting with https
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_meeting',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_ar', 'اجتماع',
      'title_en', 'Meeting',
      'meeting_mode', 'online',
      'meeting_url', 'https://meet.example.com/room-1',
      'participant_employee_ids', jsonb_build_array(v_field_emp::text),
      'time_window', jsonb_build_object('start_local', '09:00', 'end_local', '10:00')
    ),
    v_key
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm7a_create_meeting_failed: %', v_res;
  end if;
  v_event_id := (v_res #>> '{event,id}')::uuid;

  if coalesce((v_res #>> '{event,available_actions,can_edit_manual}')::boolean, false) is not true then
    raise exception 'm7a_organizer_cannot_edit';
  end if;
  if coalesce((v_res #>> '{event,available_actions,can_open_meeting_link}')::boolean, false) is not true then
    raise exception 'm7a_join_link_missing';
  end if;

  -- Reject http meeting url
  begin
    perform public.create_manual_calendar_event(
      jsonb_build_object(
        'type', 'internal_meeting',
        'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
        'title_en', 'Bad URL',
        'meeting_mode', 'online',
        'meeting_url', 'http://insecure.example.com'
      ),
      gen_random_uuid()
    );
    raise exception 'm7a_http_meeting_accepted';
  exception when others then
    if sqlerrm not like '%validation_failed%' then
      raise exception 'm7a_http_meeting_wrong: %', sqlerrm;
    end if;
  end;

  -- Non-organizer cannot update/cancel/close
  perform set_config('request.jwt.claim.sub', v_field::text, true);
  begin
    perform public.update_manual_calendar_event(
      v_event_id,
      1,
      jsonb_build_object('title_en', 'Hijack'),
      gen_random_uuid()
    );
    raise exception 'm7a_non_organizer_update_accepted';
  exception when others then
    if sqlerrm not like '%permission_denied%' then
      raise exception 'm7a_non_organizer_update_wrong: %', sqlerrm;
    end if;
  end;

  begin
    perform public.mark_manual_event_done(v_event_id, 1, gen_random_uuid());
    raise exception 'm7a_non_organizer_done_accepted';
  exception when others then
    if sqlerrm not like '%permission_denied%' then
      raise exception 'm7a_non_organizer_done_wrong: %', sqlerrm;
    end if;
  end;

  -- Participant can see join action when listing under assigned scope
  perform set_config('request.jwt.claim.sub', v_field::text, true);
  v_res := public.list_calendar_events(v_day, v_day, '{}'::jsonb);
  if not exists (
    select 1
    from jsonb_array_elements(v_res #>'{in_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
      and coalesce((r.value #>> '{available_actions,can_open_meeting_link}')::boolean, false)
      and not coalesce((r.value #>> '{available_actions,can_edit_manual}')::boolean, false)
  ) then
    raise exception 'm7a_participant_join_or_manage_failed: %', v_res;
  end if;

  raise notice 'm7a_meeting_organizer_gate_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 5) Organizer visibility (assigned-only, not participant)
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_field uuid := '00000000-0000-0000-0000-000000000205';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_day date := pg_temp.m7a_next_weekday(2);
  v_mine uuid;
  v_other uuid;
  v_res jsonb;
begin
  -- Field user creates own meeting (no participants)
  perform set_config('request.jwt.claim.sub', v_field::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_meeting',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Mine',
      'meeting_mode', 'in_person',
      'free_text_location', 'Room A'
    ),
    gen_random_uuid()
  );
  v_mine := (v_res #>> '{event,id}')::uuid;

  -- Owner creates another meeting (not involving field)
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_meeting',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Other',
      'meeting_mode', 'in_person',
      'free_text_location', 'Room B'
    ),
    gen_random_uuid()
  );
  v_other := (v_res #>> '{event,id}')::uuid;

  perform set_config('request.jwt.claim.sub', v_field::text, true);
  v_res := public.list_calendar_events(v_day, v_day, '{}'::jsonb);
  if not exists (
    select 1 from jsonb_array_elements(v_res #>'{in_range,rows}') r
    where r.value ->> 'id' = v_mine::text
  ) then
    raise exception 'm7a_organizer_missing_own: %', v_res;
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_res #>'{in_range,rows}') r
    where r.value ->> 'id' = v_other::text
  ) then
    raise exception 'm7a_organizer_sees_other: %', v_res;
  end if;

  raise notice 'm7a_organizer_visibility_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6) In-range ordering timed before date-only
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_day date := pg_temp.m7a_next_weekday(3);
  v_res jsonb;
  v_ids text[];
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  perform public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Date only B'
    ),
    gen_random_uuid()
  );
  perform public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Timed A',
      'time_window', jsonb_build_object('start_local', '09:00', 'end_local', '09:30')
    ),
    gen_random_uuid()
  );
  perform public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Date only A'
    ),
    gen_random_uuid()
  );

  v_res := public.list_calendar_events(v_day, v_day, '{}'::jsonb, null, null, 50, false);
  select array_agg(r.value ->> 'title_en' order by ordinality)
  into v_ids
  from jsonb_array_elements(v_res #>'{in_range,rows}') with ordinality r
  where r.value ->> 'scheduled_date' = to_char(v_day, 'YYYY-MM-DD');

  if v_ids[1] is distinct from 'Timed A' then
    raise exception 'm7a_order_timed_not_first: %', v_ids;
  end if;

  raise notice 'm7a_in_range_order_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7) Mark done exits overdue + appointment-done for customer_visit
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_past date := pg_temp.m7a_next_weekday(1, current_date - 14);
  v_res jsonb;
  v_event_id uuid;
  v_list jsonb;
  v_from date := current_date;
  v_to date := current_date + 7;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'customer_visit',
      'scheduled_date', to_char(v_past, 'YYYY-MM-DD'),
      'title_en', 'Overdue visit'
    ),
    gen_random_uuid()
  );
  -- Note: create forces original_due_date = scheduled_date via trigger.
  v_event_id := (v_res #>> '{event,id}')::uuid;

  v_list := public.list_calendar_events(
    v_from, v_to, '{}'::jsonb, null, null, 50, true
  );
  if not exists (
    select 1 from jsonb_array_elements(v_list #>'{overdue_outside_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
  ) then
    raise exception 'm7a_overdue_missing_before_done: %', v_list;
  end if;

  v_res := public.mark_manual_event_done(
    v_event_id,
    (v_res #>> '{event,schedule_version}')::int,
    gen_random_uuid()
  );
  if v_res #>> '{event,status}' <> 'done' then
    raise exception 'm7a_mark_done_failed: %', v_res;
  end if;

  v_list := public.list_calendar_events(
    v_from, v_to, '{}'::jsonb, null, null, 50, true
  );
  if exists (
    select 1 from jsonb_array_elements(v_list #>'{overdue_outside_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
  ) then
    raise exception 'm7a_overdue_still_present_after_done';
  end if;

  raise notice 'm7a_mark_done_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8) Idempotency + ack retry (confirmation_required then commit)
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_day date := pg_temp.m7a_next_weekday(6); -- Saturday day_off
  v_key uuid := gen_random_uuid();
  v_payload jsonb;
  v_res jsonb;
  v_res2 jsonb;
  v_event_id uuid;
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_payload := jsonb_build_object(
    'type', 'internal_task',
    'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
    'title_en', 'Weekend task'
  );

  v_res := public.create_manual_calendar_event(v_payload, v_key);
  if v_res ->> 'status' <> 'confirmation_required' then
    raise exception 'm7a_expected_confirm: %', v_res;
  end if;

  select count(*) into v_count
  from public.calendar_manual_event_operations
  where idempotency_key = v_key;
  if v_count <> 0 then
    raise exception 'm7a_confirm_wrote_ledger';
  end if;

  v_res := public.create_manual_calendar_event(
    v_payload || jsonb_build_object(
      'acknowledgements', jsonb_build_object(
        'acknowledge_non_working_day', true,
        'day_off_override_reason', 'Special Saturday work'
      )
    ),
    v_key
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm7a_ack_create_failed: %', v_res;
  end if;
  v_event_id := (v_res #>> '{event,id}')::uuid;

  v_res2 := public.create_manual_calendar_event(
    v_payload || jsonb_build_object(
      'acknowledgements', jsonb_build_object(
        'acknowledge_non_working_day', true,
        'day_off_override_reason', 'Different reason ok for replay'
      )
    ),
    v_key
  );
  if v_res2 #>> '{event,id}' is distinct from v_event_id::text then
    raise exception 'm7a_idem_replay_mismatch';
  end if;

  select count(*) into v_count
  from public.calendar_events
  where title_en = 'Weekend task' and scheduled_date = v_day;
  if v_count <> 1 then
    raise exception 'm7a_idem_duplicated_event: %', v_count;
  end if;

  raise notice 'm7a_idempotency_ack_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9) Participant uniqueness (PK) + candidates
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_day date := pg_temp.m7a_next_weekday(1);
  v_res jsonb;
  v_event_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_res := public.list_calendar_participant_candidates(null, 20);
  if jsonb_array_length(v_res -> 'rows') < 1 then
    raise exception 'm7a_candidates_empty';
  end if;
  if not (v_res #>> '{rows,0}' is not null and (v_res -> 'rows' -> 0) ? 'has_app_account') then
    raise exception 'm7a_candidates_missing_has_app_account';
  end if;

  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_activity',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Training',
      'participant_employee_ids', jsonb_build_array(
        v_field_emp::text, v_field_emp::text
      )
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  if jsonb_array_length(v_res -> 'event' -> 'participants') <> 1 then
    raise exception 'm7a_participant_dedupe_failed: %', v_res -> 'event' -> 'participants';
  end if;

  begin
    insert into public.calendar_event_participants (
      tenant_id, event_id, employee_id, created_by
    ) values (
      '00000000-0000-0000-0000-000000000101',
      v_event_id,
      v_field_emp,
      v_owner
    );
    raise exception 'm7a_participant_pk_not_enforced';
  exception
    when unique_violation then null;
    when others then
      if sqlerrm not like '%duplicate%' and sqlstate not like '23%' then
        raise exception 'm7a_participant_pk_unexpected: %', sqlerrm;
      end if;
  end;

  raise notice 'm7a_participant_uniqueness_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10) Scope for assigned participant
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field uuid := '00000000-0000-0000-0000-000000000205';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_day date := pg_temp.m7a_next_weekday(4);
  v_res jsonb;
  v_event_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'custom',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'With participant',
      'participant_employee_ids', jsonb_build_array(v_field_emp::text)
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  perform set_config('request.jwt.claim.sub', v_field::text, true);
  v_res := public.list_calendar_events(v_day, v_day, '{}'::jsonb);
  if not exists (
    select 1 from jsonb_array_elements(v_res #>'{in_range,rows}') r
    where r.value ->> 'id' = v_event_id::text
  ) then
    raise exception 'm7a_participant_scope_failed';
  end if;

  raise notice 'm7a_participant_scope_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11) Overdue order keeps original_due_date primary (not timed-first)
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_from date := current_date;
  v_to date := current_date + 7;
  v_res jsonb;
  v_older uuid;
  v_newer uuid;
  v_ids text[];
  v_due_old date := pg_temp.m7a_next_weekday(1, current_date - 28);
  v_sched_late date := pg_temp.m7a_next_weekday(3, current_date - 10);
  v_due_new date := pg_temp.m7a_next_weekday(2, current_date - 14);
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  -- Older due provenance; later move scheduled_date forward (M8-style), date-only.
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_due_old, 'YYYY-MM-DD'),
      'title_en', 'Overdue older due date-only'
    ),
    gen_random_uuid()
  );
  v_older := (v_res #>> '{event,id}')::uuid;

  update public.calendar_events
  set scheduled_date = v_sched_late
  where id = v_older;

  -- Newer due, earlier scheduled_date than the moved event, timed.
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_due_new, 'YYYY-MM-DD'),
      'title_en', 'Overdue newer due timed',
      'time_window', jsonb_build_object('start_local', '09:00', 'end_local', '09:30')
    ),
    gen_random_uuid()
  );
  v_newer := (v_res #>> '{event,id}')::uuid;

  if (
    select original_due_date from public.calendar_events where id = v_older
  ) is distinct from v_due_old then
    raise exception 'm7a_overdue_setup_due_not_preserved';
  end if;

  -- In-range-like comparator would prefer newer (earlier scheduled_date + timed).
  if v_due_new >= v_sched_late then
    raise exception 'm7a_overdue_setup_dates_not_divergent';
  end if;

  v_res := public.list_calendar_events(
    v_from, v_to, '{}'::jsonb, null, null, 50, true
  );

  select array_agg(r.value ->> 'id' order by ordinality)
  into v_ids
  from jsonb_array_elements(v_res #>'{overdue_outside_range,rows}') with ordinality r
  where r.value ->> 'id' in (v_older::text, v_newer::text);

  if v_ids is null or array_length(v_ids, 1) <> 2 then
    raise exception 'm7a_overdue_order_missing: %', v_res;
  end if;
  if v_ids[1] is distinct from v_older::text then
    raise exception 'm7a_overdue_order_wrong: %', v_ids;
  end if;

  raise notice 'm7a_overdue_order_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12) Reminder dual partial uniques + skip no-app-account + delivered immutability
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_no_app uuid := '00000000-0000-0000-0000-00000000e701';
  v_day date := pg_temp.m7a_next_weekday(2);
  v_res jsonb;
  v_event_id uuid;
  v_plan_id uuid;
  v_notification_id uuid;
  v_delivered_at timestamptz;
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into public.employees (
    id, tenant_id, name_ar, name_en, is_active, user_id, code, hire_date, job_type
  ) values (
    v_no_app,
    '00000000-0000-0000-0000-000000000101',
    'بدون حساب',
    'No App',
    true,
    null,
    'M7A-NOAPP',
    current_date,
    'other'
  );

  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Reminder fanout',
      'participant_employee_ids', jsonb_build_array(
        v_field_emp::text, v_no_app::text
      )
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  select count(*) into v_count
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and recipient_employee_id = v_field_emp
    and status = 'planned'::public.calendar_reminder_plan_status;
  if v_count < 1 then
    raise exception 'm7a_reminder_missing_participant_plan';
  end if;

  select count(*) into v_count
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and recipient_employee_id = v_no_app;
  if v_count <> 0 then
    raise exception 'm7a_reminder_planned_for_no_app_account';
  end if;

  -- Dedicated suppressed uniqueness check (no recipients).
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'custom',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'No recipients suppressed'
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  select count(*) into v_count
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and recipient_employee_id is null
    and status = 'suppressed'::public.calendar_reminder_plan_status;
  if v_count < 1 then
    raise exception 'm7a_suppressed_plan_missing: %', v_count;
  end if;

  -- Dual rules (event + previous workday) may each suppress once; uniqueness is per rule.
  select count(*) into v_count
  from (
    select rule_key
    from public.calendar_reminder_plans
    where calendar_event_id = v_event_id
      and recipient_employee_id is null
      and status = 'suppressed'::public.calendar_reminder_plan_status
    group by rule_key
    having count(*) > 1
  ) dups;
  if v_count <> 0 then
    raise exception 'm7a_suppressed_duplicate_per_rule';
  end if;

  begin
    insert into public.calendar_reminder_plans (
      tenant_id, calendar_event_id, rule_key, occurrence_scheduled_date,
      channel, status, suppressed_reason
    )
    select
      tenant_id, calendar_event_id, rule_key, occurrence_scheduled_date,
      channel, 'suppressed'::public.calendar_reminder_plan_status, 'no_assigned_recipient'
    from public.calendar_reminder_plans
    where calendar_event_id = v_event_id
      and recipient_employee_id is null
      and rule_key = 'event_workday_start'::public.calendar_reminder_rule_key
    limit 1;
    raise exception 'm7a_suppressed_unique_not_enforced';
  exception
    when unique_violation then null;
  end;

  -- Delivered immutability across rebuild.
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Delivered immutability',
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  select id into v_plan_id
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and recipient_employee_id = v_owner_emp
    and status = 'planned'::public.calendar_reminder_plan_status
  limit 1;

  if v_plan_id is null then
    raise exception 'm7a_delivered_setup_missing_plan';
  end if;

  insert into public.notifications (
    tenant_id, channel, recipient_type, recipient_id, recipient_address,
    subject, body_ar, body_en, template_key, status, sent_at,
    related_entity_table, related_entity_id
  ) values (
    '00000000-0000-0000-0000-000000000101',
    'in_app'::public.notification_channel,
    'user',
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000201',
    'm7a-delivered', 'm7a', 'm7a',
    'calendar_reminder_event_workday_start',
    'sent'::public.notification_status,
    now(),
    'calendar_reminder_plans',
    v_plan_id
  )
  returning id into v_notification_id;

  update public.calendar_reminder_plans
  set
    status = 'delivered'::public.calendar_reminder_plan_status,
    notification_id = v_notification_id,
    delivered_at = now(),
    updated_at = now()
  where id = v_plan_id
  returning delivered_at into v_delivered_at;

  -- Rebuild via participant change (adds field agent).
  v_res := public.update_manual_calendar_event(
    v_event_id,
    (select schedule_version from public.calendar_events where id = v_event_id),
    jsonb_build_object(
      'title_en', 'Delivered immutability',
      'participant_employee_ids', jsonb_build_array(
        v_owner_emp::text, v_field_emp::text
      )
    ),
    gen_random_uuid()
  );

  if (
    select status from public.calendar_reminder_plans where id = v_plan_id
  ) is distinct from 'delivered'::public.calendar_reminder_plan_status then
    raise exception 'm7a_delivered_mutated';
  end if;

  if (
    select delivered_at from public.calendar_reminder_plans where id = v_plan_id
  ) is distinct from v_delivered_at then
    raise exception 'm7a_delivered_at_mutated';
  end if;

  select count(*) into v_count
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and recipient_employee_id = v_owner_emp
    and status = 'planned'::public.calendar_reminder_plan_status;
  if v_count <> 0 then
    raise exception 'm7a_delivered_got_duplicate_planned';
  end if;

  select count(*) into v_count
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and recipient_employee_id = v_field_emp
    and status = 'planned'::public.calendar_reminder_plan_status;
  if v_count < 1 then
    raise exception 'm7a_new_recipient_plan_missing';
  end if;

  raise notice 'm7a_reminder_dual_unique_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13) Meeting notices unique (operation_id) + invite/remove + idempotent retry
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_day date := pg_temp.m7a_next_weekday(3);
  v_key uuid := gen_random_uuid();
  v_payload jsonb;
  v_res jsonb;
  v_event_id uuid;
  v_op_id uuid;
  v_count int;
  v_version int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_payload := jsonb_build_object(
    'type', 'internal_meeting',
    'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
    'title_en', 'Notice meeting',
    'title_ar', 'اجتماع إشعارات',
    'meeting_mode', 'online',
    'meeting_url', 'https://meet.example.com/notices',
    'participant_employee_ids', jsonb_build_array(v_field_emp::text)
  );

  v_res := public.create_manual_calendar_event(v_payload, v_key);
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm7a_notice_create_failed: %', v_res;
  end if;
  v_event_id := (v_res #>> '{event,id}')::uuid;

  select count(*) into v_count
  from public.calendar_meeting_notices
  where calendar_event_id = v_event_id
    and notice_kind = 'meeting_created';
  if v_count <> 1 then
    raise exception 'm7a_meeting_created_count: %', v_count;
  end if;

  select operation_id into v_op_id
  from public.calendar_meeting_notices
  where calendar_event_id = v_event_id
    and notice_kind = 'meeting_created'
  limit 1;

  -- Idempotent create retry must not duplicate notices.
  v_res := public.create_manual_calendar_event(v_payload, v_key);
  select count(*) into v_count
  from public.calendar_meeting_notices
  where calendar_event_id = v_event_id
    and notice_kind = 'meeting_created';
  if v_count <> 1 then
    raise exception 'm7a_meeting_created_duplicated_on_retry: %', v_count;
  end if;

  select schedule_version into v_version
  from public.calendar_events where id = v_event_id;

  -- Material title change → meeting_updated for remaining.
  v_res := public.update_manual_calendar_event(
    v_event_id,
    v_version,
    jsonb_build_object(
      'title_en', 'Notice meeting updated',
      'title_ar', 'اجتماع إشعارات محدّث',
      'meeting_mode', 'online',
      'meeting_url', 'https://meet.example.com/notices',
      'participant_employee_ids', jsonb_build_array(v_field_emp::text)
    ),
    gen_random_uuid()
  );
  select count(*) into v_count
  from public.calendar_meeting_notices
  where calendar_event_id = v_event_id
    and notice_kind = 'meeting_updated';
  if v_count <> 1 then
    raise exception 'm7a_meeting_updated_count: %', v_count;
  end if;

  select schedule_version into v_version
  from public.calendar_events where id = v_event_id;

  -- Roster swap: invite owner_emp, remove field_emp (no meeting_updated if only roster).
  v_res := public.update_manual_calendar_event(
    v_event_id,
    v_version,
    jsonb_build_object(
      'title_en', 'Notice meeting updated',
      'title_ar', 'اجتماع إشعارات محدّث',
      'meeting_mode', 'online',
      'meeting_url', 'https://meet.example.com/notices',
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );

  select count(*) into v_count
  from public.calendar_meeting_notices n
  join public.employees e on e.id = n.recipient_employee_id
  where n.calendar_event_id = v_event_id
    and n.notice_kind = 'meeting_invited'
    and e.id = v_owner_emp;
  if v_count <> 1 then
    raise exception 'm7a_meeting_invited_missing: %', v_count;
  end if;

  select count(*) into v_count
  from public.calendar_meeting_notices n
  where n.calendar_event_id = v_event_id
    and n.notice_kind = 'meeting_removed'
    and n.recipient_employee_id = v_field_emp;
  if v_count <> 1 then
    raise exception 'm7a_meeting_removed_missing: %', v_count;
  end if;

  -- Fresh operation_id for roster update — total updated notices still 1
  -- (roster-only must not emit another meeting_updated).
  select count(*) into v_count
  from public.calendar_meeting_notices
  where calendar_event_id = v_event_id
    and notice_kind = 'meeting_updated';
  if v_count <> 1 then
    raise exception 'm7a_roster_only_emitted_updated: %', v_count;
  end if;

  -- Unique constraint: duplicate row with same operation_id rejected.
  begin
    insert into public.calendar_meeting_notices (
      tenant_id, calendar_event_id, notice_kind,
      recipient_user_id, recipient_employee_id, operation_id
    ) values (
      '00000000-0000-0000-0000-000000000101',
      v_event_id,
      'meeting_created',
      '00000000-0000-0000-0000-000000000205',
      v_field_emp,
      v_op_id
    );
    raise exception 'm7a_notice_unique_not_enforced';
  exception
    when unique_violation then null;
  end;

  raise notice 'm7a_meeting_notices_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14) Real multi-participant reminder delivery (no manual notifications insert)
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_today date;
  v_iso int;
  v_res jsonb;
  v_event_id uuid;
  v_owner_plan uuid;
  v_field_plan uuid;
  v_owner_status public.calendar_reminder_plan_status;
  v_field_status public.calendar_reminder_plan_status;
  v_notif_count int;
  v_version int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_today := public.try_tenant_local_today(v_tenant);
  if v_today is null then
    raise exception 'm7a_delivery_local_today_null';
  end if;

  v_iso := extract(isodow from v_today)::int;
  update public.tenant_working_days
  set day_mode = '24_hours', work_start = null, work_end = null
  where tenant_id = v_tenant and iso_weekday = v_iso;

  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_today, 'YYYY-MM-DD'),
      'title_en', 'M7A real delivery',
      'participant_employee_ids', jsonb_build_array(
        v_owner_emp::text, v_field_emp::text
      )
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  perform pg_temp.m7a_drain_reconcile(v_tenant);

  select id into v_owner_plan
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and rule_key = 'event_workday_start'::public.calendar_reminder_rule_key
    and recipient_employee_id = v_owner_emp
    and status = 'planned'::public.calendar_reminder_plan_status
  limit 1;

  select id into v_field_plan
  from public.calendar_reminder_plans
  where calendar_event_id = v_event_id
    and rule_key = 'event_workday_start'::public.calendar_reminder_rule_key
    and recipient_employee_id = v_field_emp
    and status = 'planned'::public.calendar_reminder_plan_status
  limit 1;

  if v_owner_plan is null or v_field_plan is null then
    raise exception 'm7a_delivery_missing_planned_rows: owner=% field=%',
      v_owner_plan, v_field_plan;
  end if;

  -- Make due while planned (refresh will recompute absolute anchors; midnight today
  -- is already past under 24h working-day fixture).
  update public.calendar_reminder_plans
  set
    anchor_utc = case
      when anchor_utc > now() then now() - interval '1 minute'
      else anchor_utc
    end,
    updated_at = now()
  where id in (v_owner_plan, v_field_plan)
    and status = 'planned'::public.calendar_reminder_plan_status;

  perform pg_temp.m7a_deliver_plan(v_owner_plan);

  select status into v_owner_status
  from public.calendar_reminder_plans where id = v_owner_plan;
  if v_owner_status is distinct from 'delivered'::public.calendar_reminder_plan_status then
    raise exception 'm7a_delivery_owner_not_delivered: %', v_owner_status;
  end if;

  select count(*) into v_notif_count
  from public.notifications n
  where n.related_entity_table = 'calendar_reminder_plans'
    and n.related_entity_id = v_owner_plan;
  if v_notif_count <> 1 then
    raise exception 'm7a_delivery_owner_notif_count: %', v_notif_count;
  end if;

  -- Deliver again → no duplicate notification; same plan stays delivered.
  perform pg_temp.m7a_deliver_plan(v_owner_plan);
  select count(*) into v_notif_count
  from public.notifications n
  where n.related_entity_table = 'calendar_reminder_plans'
    and n.related_entity_id = v_owner_plan;
  if v_notif_count <> 1 then
    raise exception 'm7a_delivery_duplicate_notif: %', v_notif_count;
  end if;

  select status into v_field_status
  from public.calendar_reminder_plans where id = v_field_plan;
  if v_field_status is distinct from 'planned'::public.calendar_reminder_plan_status
    and v_field_status is distinct from 'delivery_pending'::public.calendar_reminder_plan_status then
    raise exception 'm7a_delivery_field_unexpectedly_changed: %', v_field_status;
  end if;

  -- Remove one participant → only that OPEN plan cancelled_superseded.
  select schedule_version into v_version
  from public.calendar_events where id = v_event_id;

  v_res := public.update_manual_calendar_event(
    v_event_id,
    v_version,
    jsonb_build_object(
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );

  select status into v_field_status
  from public.calendar_reminder_plans where id = v_field_plan;
  if v_field_status is distinct from 'cancelled_superseded'::public.calendar_reminder_plan_status then
    raise exception 'm7a_remove_participant_not_superseded: %', v_field_status;
  end if;

  select status into v_owner_status
  from public.calendar_reminder_plans where id = v_owner_plan;
  if v_owner_status is distinct from 'delivered'::public.calendar_reminder_plan_status then
    raise exception 'm7a_remove_participant_mutated_delivered: %', v_owner_status;
  end if;

  -- Settings/permission change with multi participants must not unique-violate.
  begin
    perform public.update_calendar_settings(jsonb_build_object(
      'timezone_name', 'Asia/Kuwait',
      'remind_event_workday_start', true,
      'remind_previous_workday_start', true,
      'days', pg_temp.m7a_standard_days()
    ));
    perform pg_temp.m7a_drain_reconcile(v_tenant);
  exception when unique_violation then
    raise exception 'm7a_multi_participant_settings_unique_violation';
  end;

  raise notice 'm7a_real_delivery_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 15) Meeting notice atomic emit (serial double-call)
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_day date := pg_temp.m7a_next_weekday(2);
  v_res jsonb;
  v_event_id uuid;
  v_op_id uuid;
  v_event public.calendar_events%rowtype;
  v_notice_count int;
  v_notif_count int;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Emit notice target',
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;

  insert into public.calendar_manual_event_operations (
    tenant_id, operation_type, idempotency_key, business_payload_hash,
    result_status, result_event_id, result_jsonb, created_by
  ) values (
    v_tenant, 'update', gen_random_uuid(), 'm7a-emit-serial',
    'ok', v_event_id, '{}'::jsonb, v_owner
  )
  returning id into v_op_id;

  select * into v_event from public.calendar_events where id = v_event_id;

  -- Re-cast type for emit (uses meeting notice kinds; allowed even if type differs).
  perform public.emit_calendar_meeting_notice(
    v_tenant, v_event_id, 'meeting_updated',
    v_owner, v_owner_emp, v_op_id, v_event
  );
  perform public.emit_calendar_meeting_notice(
    v_tenant, v_event_id, 'meeting_updated',
    v_owner, v_owner_emp, v_op_id, v_event
  );

  select count(*) into v_notice_count
  from public.calendar_meeting_notices
  where calendar_event_id = v_event_id
    and operation_id = v_op_id
    and notice_kind = 'meeting_updated';
  if v_notice_count <> 1 then
    raise exception 'm7a_emit_notice_count: %', v_notice_count;
  end if;

  select count(*) into v_notif_count
  from public.notifications n
  join public.calendar_meeting_notices mn on mn.notification_id = n.id
  where mn.calendar_event_id = v_event_id
    and mn.operation_id = v_op_id;
  if v_notif_count <> 1 then
    raise exception 'm7a_emit_notification_count: %', v_notif_count;
  end if;

  raise notice 'm7a_meeting_notice_emit_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16) Update idempotency resolve-before-assert + patch-hash identity
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_day date := pg_temp.m7a_next_weekday(3);
  v_key uuid := gen_random_uuid();
  v_patch jsonb;
  v_res1 jsonb;
  v_res2 jsonb;
  v_event_id uuid;
  v_version int;
  v_version_after int;
  v_later jsonb;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_res1 := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Idem update base',
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res1 #>> '{event,id}')::uuid;
  select schedule_version into v_version
  from public.calendar_events where id = v_event_id;

  v_patch := jsonb_build_object('title_en', 'Idem update first');
  v_res1 := public.update_manual_calendar_event(
    v_event_id, v_version, v_patch, v_key
  );
  if v_res1 ->> 'status' <> 'ok' then
    raise exception 'm7a_update_idem_first_failed: %', v_res1;
  end if;

  select schedule_version into v_version_after
  from public.calendar_events where id = v_event_id;

  -- Immediate replay → same result, no second version bump.
  v_res2 := public.update_manual_calendar_event(
    v_event_id, v_version, v_patch, v_key
  );
  if v_res2 is distinct from v_res1 then
    raise exception 'm7a_update_idem_replay_mismatch';
  end if;
  if (
    select schedule_version from public.calendar_events where id = v_event_id
  ) is distinct from v_version_after then
    raise exception 'm7a_update_idem_version_bumped_on_replay';
  end if;

  -- Unrelated later update, then replay original key → stored success (not stale).
  v_later := public.update_manual_calendar_event(
    v_event_id,
    v_version_after,
    jsonb_build_object('title_en', 'Idem update later'),
    gen_random_uuid()
  );
  if v_later ->> 'status' <> 'ok' then
    raise exception 'm7a_update_idem_later_failed: %', v_later;
  end if;

  v_res2 := public.update_manual_calendar_event(
    v_event_id, v_version, v_patch, v_key
  );
  if v_res2 is distinct from v_res1 then
    raise exception 'm7a_update_idem_after_later_mismatch';
  end if;

  -- Cancel then replay original update key → still original success.
  perform public.cancel_manual_calendar_event(
    v_event_id,
    (select schedule_version from public.calendar_events where id = v_event_id),
    'idempotency cancel fixture',
    gen_random_uuid()
  );
  v_res2 := public.update_manual_calendar_event(
    v_event_id, v_version, v_patch, v_key
  );
  if v_res2 is distinct from v_res1 then
    raise exception 'm7a_update_idem_after_cancel_mismatch';
  end if;

  -- Same key, changed patch → mismatch.
  begin
    perform public.update_manual_calendar_event(
      v_event_id,
      v_version,
      jsonb_build_object('title_en', 'Idem update changed patch'),
      v_key
    );
    raise exception 'm7a_update_idem_payload_mismatch_missing';
  exception when others then
    if sqlerrm not like '%idempotency_payload_mismatch%' then
      raise exception 'm7a_update_idem_payload_mismatch_wrong: %', sqlerrm;
    end if;
  end;

  raise notice 'm7a_update_idempotency_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17) Update idempotency cross-tenant isolation
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner_a uuid := '00000000-0000-0000-0000-000000000201';
  v_owner_b uuid := '00000000-0000-0000-0000-000000000204';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_day date := pg_temp.m7a_next_weekday(4);
  v_key uuid := gen_random_uuid();
  v_res jsonb;
  v_event_a uuid;
  v_version int;
  v_count int;
begin
  perform set_config('request.jwt.claim.sub', v_owner_a::text, true);
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'custom',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Tenant A idem',
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );
  v_event_a := (v_res #>> '{event,id}')::uuid;
  select schedule_version into v_version from public.calendar_events where id = v_event_a;

  v_res := public.update_manual_calendar_event(
    v_event_a, v_version, jsonb_build_object('title_en', 'Tenant A patched'), v_key
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'm7a_xtenant_update_failed: %', v_res;
  end if;

  -- Tenant B must not see/steal tenant A ledger under same key.
  perform set_config('request.jwt.claim.sub', v_owner_b::text, true);
  begin
    perform public.update_calendar_settings(jsonb_build_object(
      'timezone_name', 'Asia/Kuwait',
      'remind_event_workday_start', true,
      'remind_previous_workday_start', false,
      'days', pg_temp.m7a_standard_days()
    ));
  exception when others then
    null; -- settings may already exist / permission differ
  end;

  select count(*) into v_count
  from public.calendar_manual_event_operations
  where tenant_id = v_tenant_b
    and operation_type = 'update'
    and idempotency_key = v_key;
  if v_count <> 0 then
    raise exception 'm7a_xtenant_ledger_leak: %', v_count;
  end if;

  raise notice 'm7a_update_idem_xtenant_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18) Audit snapshots on update / cancel / mark_done
-- ---------------------------------------------------------------------------
begin;
select pg_temp.m7a_configure();
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_field_emp uuid := '00000000-0000-0000-0000-000000000602';
  v_owner_emp uuid := '00000000-0000-0000-0000-000000000601';
  v_day date := pg_temp.m7a_next_weekday(1);
  v_res jsonb;
  v_event_id uuid;
  v_version int;
  v_before jsonb;
  v_after jsonb;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'internal_task',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Audit before title',
      'participant_employee_ids', jsonb_build_array(
        v_owner_emp::text, v_field_emp::text
      )
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;
  select schedule_version into v_version from public.calendar_events where id = v_event_id;

  v_res := public.update_manual_calendar_event(
    v_event_id,
    v_version,
    jsonb_build_object(
      'title_en', 'Audit after title',
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );

  select before_json, after_json into v_before, v_after
  from public.audit_log
  where entity_type = 'calendar_events'
    and entity_id = v_event_id
    and action = 'update'
  order by at desc, id desc
  limit 1;

  if v_before is null or v_before ->> 'title_en' is distinct from 'Audit before title' then
    raise exception 'm7a_audit_update_before_bad: %', v_before;
  end if;
  if coalesce(jsonb_array_length(v_before -> 'participants'), 0) <> 2 then
    raise exception 'm7a_audit_update_before_participants: %', v_before -> 'participants';
  end if;
  if v_after is null or v_after ->> 'title_en' is distinct from 'Audit after title' then
    raise exception 'm7a_audit_update_after_bad: %', v_after;
  end if;
  if coalesce(jsonb_array_length(v_after -> 'participants'), 0) <> 1 then
    raise exception 'm7a_audit_update_after_participants: %', v_after -> 'participants';
  end if;

  select schedule_version into v_version from public.calendar_events where id = v_event_id;
  v_res := public.mark_manual_event_done(v_event_id, v_version, gen_random_uuid());

  select before_json, after_json into v_before, v_after
  from public.audit_log
  where entity_type = 'calendar_events'
    and entity_id = v_event_id
    and action = 'mark_done'
  order by at desc, id desc
  limit 1;

  if v_before is null or v_before ->> 'status' is distinct from 'pending' then
    raise exception 'm7a_audit_done_before_bad: %', v_before;
  end if;
  if v_after is null or v_after ->> 'status' is distinct from 'done' then
    raise exception 'm7a_audit_done_after_bad: %', v_after;
  end if;

  -- Separate cancel fixture.
  v_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'custom',
      'scheduled_date', to_char(v_day, 'YYYY-MM-DD'),
      'title_en', 'Audit cancel title',
      'participant_employee_ids', jsonb_build_array(v_owner_emp::text)
    ),
    gen_random_uuid()
  );
  v_event_id := (v_res #>> '{event,id}')::uuid;
  select schedule_version into v_version from public.calendar_events where id = v_event_id;

  v_res := public.cancel_manual_calendar_event(
    v_event_id, v_version, 'audit cancel reason', gen_random_uuid()
  );

  select before_json, after_json into v_before, v_after
  from public.audit_log
  where entity_type = 'calendar_events'
    and entity_id = v_event_id
    and action = 'cancel'
  order by at desc, id desc
  limit 1;

  if v_before is null or v_before ->> 'title_en' is distinct from 'Audit cancel title' then
    raise exception 'm7a_audit_cancel_before_bad: %', v_before;
  end if;
  if v_after is null
    or v_after ->> 'status' is distinct from 'cancelled'
    or v_after ->> 'cancellation_reason' is distinct from 'audit cancel reason' then
    raise exception 'm7a_audit_cancel_after_bad: %', v_after;
  end if;

  raise notice 'm7a_audit_snapshots_ok';
end $$;
rollback;

do $$ begin raise notice 'm7a_manual_business_events_suite_complete'; end $$;