\set ON_ERROR_STOP on

-- Phase 7 M7B: working-date exceptions (official holidays, company closures,
-- exceptional working days) verification.
-- Seed IDs (migration 031): tenant_a 00000000-0000-0000-0000-000000000101,
-- owner 00000000-0000-0000-0000-000000000201,
-- products_user 203 / products_tu 303 (permission matrix probe),
-- tenant_b 00000000-0000-0000-0000-000000000102,
-- owner_b 00000000-0000-0000-0000-000000000204 (unconfigured / cross-tenant probe).
-- Patterns follow supabase/tests/phase_7_calendar_working_schedule.sql (seed
-- tenants, standard days, set local role/jwt claim switching) and
-- supabase/tests/phase_7_manual_business_events.sql (idempotency replay style).
-- All rows created by this suite are tagged with a 'P7B ' title_en prefix so a
-- crashed prior run can be cleaned up before re-running.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function pg_temp.p7b_standard_days()
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

create or replace function pg_temp.p7b_configure()
returns void language plpgsql as $$
begin
  perform public.update_calendar_settings(jsonb_build_object(
    'timezone_name', 'Asia/Kuwait',
    'remind_event_workday_start', true,
    'remind_previous_workday_start', false,
    'days', pg_temp.p7b_standard_days()
  ));
end; $$;

create or replace function pg_temp.p7b_grant_perm(p_tu uuid, p_perm text)
returns void language plpgsql as $$
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (
    '00000000-0000-0000-0000-000000000101', p_tu, p_perm,
    '00000000-0000-0000-0000-000000000201'
  )
  on conflict (tenant_user_id, permission_id) do nothing;
end; $$;

create or replace function pg_temp.p7b_revoke_calendar_perms(p_tu uuid)
returns void language plpgsql as $$
begin
  delete from public.user_permissions
  where tenant_user_id = p_tu
    and permission_id in (
      'calendar.view', 'calendar.view_assigned', 'calendar.create',
      'calendar.edit', 'calendar.delete',
      'settings.calendar.view', 'settings.calendar.edit'
    );
end; $$;

create or replace function pg_temp.p7b_expect_error(p_sql text, p_code text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'p7b_expect_error: expected % for %', p_code, p_sql;
  exception when others then
    if sqlerrm not like '%' || p_code || '%' then
      raise exception 'p7b_expect_error: got % for %', sqlerrm, p_sql;
    end if;
  end;
end; $$;

create or replace function pg_temp.p7b_expect_check(p_sql text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'p7b_expect_check: statement succeeded unexpectedly: %', p_sql;
  exception
    when check_violation then null;
    when others then
      raise exception 'p7b_expect_check: unexpected error for %: %', p_sql, sqlerrm;
  end;
end; $$;

create or replace function pg_temp.p7b_base(p_case int)
returns date language sql immutable as $$
  select (current_date + 1000 + (p_case * 40))::date;
$$;

create or replace function pg_temp.p7b_next_weekday(p_iso int, p_from date)
returns date language sql immutable as $$
  select (p_from + ((p_iso - extract(isodow from p_from)::int + 7) % 7))::date;
$$;

create or replace function pg_temp.p7b_payload(
  p_kind text,
  p_start date,
  p_end date,
  p_title_en text default null,
  p_title_ar text default null,
  p_day_mode text default null,
  p_work_start text default null,
  p_work_end text default null,
  p_notes text default null
)
returns jsonb language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'kind', p_kind,
    'start_date', to_char(p_start, 'YYYY-MM-DD'),
    'end_date', to_char(p_end, 'YYYY-MM-DD'),
    'title_en', p_title_en,
    'title_ar', p_title_ar,
    'day_mode', p_day_mode,
    'work_start', p_work_start,
    'work_end', p_work_end,
    'notes', p_notes
  ));
$$;

create or replace function pg_temp.p7b_seed_bulk_exceptions(p_tenant_id uuid, p_count int, p_base date)
returns void language plpgsql as $$
declare
  v_i int;
begin
  for v_i in 0..(p_count - 1) loop
    insert into public.tenant_working_date_exceptions (
      tenant_id, kind, start_date, end_date, title_ar, title_en,
      status, version, created_by, updated_by
    ) values (
      p_tenant_id, 'official_holiday'::public.tenant_working_date_exception_kind,
      p_base + (v_i * 2), p_base + (v_i * 2),
      'عطلة بالجملة', 'P7B Bulk ' || v_i,
      'active'::public.tenant_working_date_exception_status, 1,
      '00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000201'
    );
  end loop;
end; $$;

-- ---------------------------------------------------------------------------
-- Rerun hygiene: drop any rows a previously crashed run left behind, and force
-- tenant B back to its never-configured seed shape (nothing in this pipeline
-- configures tenant B, so this is a defensive normalize, not a real mutation).
-- ---------------------------------------------------------------------------
do $$
begin
  delete from public.working_date_exception_operations op
  using public.tenant_working_date_exceptions twde
  where op.result_exception_id = twde.id
    and twde.title_en like 'P7B %';

  delete from public.tenant_working_date_exceptions
  where title_en like 'P7B %';

  update public.tenant_calendar_settings
  set working_schedule_configured = false, timezone_name = null,
      configured_at = null, configured_by = null
  where tenant_id = '00000000-0000-0000-0000-000000000102';
end $$;

-- ---------------------------------------------------------------------------
-- Bootstrap: configure tenant A's weekly schedule (committed; idempotent).
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select pg_temp.p7b_configure();
do $$ begin raise notice 'p7b_bootstrap_ok'; end $$;
commit;

-- ---------------------------------------------------------------------------
-- 1) Permission matrix: calendar.view alone insufficient; settings.calendar.view
--    enables list; settings.calendar.edit enables create.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform pg_temp.p7b_revoke_calendar_perms('00000000-0000-0000-0000-000000000303');
  perform pg_temp.p7b_grant_perm('00000000-0000-0000-0000-000000000303', 'calendar.view');
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  perform pg_temp.p7b_expect_error(
    'select public.list_working_date_exceptions()', 'permission_denied'
  );
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('official_holiday', pg_temp.p7b_base(1), pg_temp.p7b_base(1), 'P7B Case1 Holiday')::text
    ),
    'permission_denied'
  );
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7b_grant_perm('00000000-0000-0000-0000-000000000303', 'settings.calendar.view'); end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_res jsonb;
begin
  v_res := public.list_working_date_exceptions(
    jsonb_build_object('date_from', pg_temp.p7b_base(1) - 5, 'date_to', pg_temp.p7b_base(1) + 5)
  );
  if not (v_res ? 'items') then
    raise exception 'case1 failed: settings.calendar.view could not list: %', v_res;
  end if;

  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('official_holiday', pg_temp.p7b_base(1), pg_temp.p7b_base(1), 'P7B Case1 Holiday')::text
    ),
    'permission_denied'
  );
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$ begin perform pg_temp.p7b_grant_perm('00000000-0000-0000-0000-000000000303', 'settings.calendar.edit'); end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', pg_temp.p7b_base(1), pg_temp.p7b_base(1), 'P7B Case1 Holiday Edit'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case1 failed: settings.calendar.edit could not create: %', v_res;
  end if;
  raise notice 'p7b_case1_permission_matrix_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2) Direct table INSERT denied for authenticated.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    insert into public.tenant_working_date_exceptions (
      tenant_id, kind, start_date, end_date, title_en
    ) values (
      '00000000-0000-0000-0000-000000000101',
      'official_holiday'::public.tenant_working_date_exception_kind,
      pg_temp.p7b_base(2), pg_temp.p7b_base(2), 'P7B Case2 Direct Insert'
    );
    raise exception 'case2 failed: direct insert allowed';
  exception
    when insufficient_privilege then null;
  end;
  raise notice 'p7b_case2_direct_insert_denied_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3) Exact RPC grants for authenticated; internal helpers stay unreachable.
-- ---------------------------------------------------------------------------
begin;
set local role postgres;
do $$
begin
  if not has_function_privilege('authenticated', 'public.list_working_date_exceptions(jsonb, text, int)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.get_working_date_exception(uuid)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.create_working_date_exception(jsonb, uuid)', 'EXECUTE')
    or not has_function_privilege(
      'authenticated', 'public.update_working_date_exception(uuid, int, jsonb, uuid)', 'EXECUTE'
    )
    or not has_function_privilege(
      'authenticated', 'public.cancel_working_date_exception(uuid, int, text, uuid)', 'EXECUTE'
    )
  then
    raise exception 'case3 failed: expected RPC grants missing for authenticated';
  end if;

  if has_function_privilege('anon', 'public.list_working_date_exceptions(jsonb, text, int)', 'EXECUTE')
    or has_function_privilege('anon', 'public.get_working_date_exception(uuid)', 'EXECUTE')
    or has_function_privilege('anon', 'public.create_working_date_exception(jsonb, uuid)', 'EXECUTE')
    or has_function_privilege(
      'anon', 'public.update_working_date_exception(uuid, int, jsonb, uuid)', 'EXECUTE'
    )
    or has_function_privilege(
      'anon', 'public.cancel_working_date_exception(uuid, int, text, uuid)', 'EXECUTE'
    ) then
    raise exception 'case3 failed: public RPC execute leaked to anon';
  end if;

  if has_function_privilege('authenticated', 'public.resolve_tenant_working_window(uuid, date)', 'EXECUTE')
    or has_function_privilege(
      'authenticated',
      'public.detect_manual_calendar_schedule_warnings(uuid, date, timestamptz, timestamptz)',
      'EXECUTE'
    )
    or has_function_privilege('authenticated', 'public.load_active_working_date_exception(uuid, date)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.snapshot_working_date_exception_audit(uuid)', 'EXECUTE')
    or has_function_privilege(
      'authenticated', 'public.safe_date_exception_json(public.tenant_working_date_exceptions)', 'EXECUTE'
    )
    or has_function_privilege('authenticated', 'public.working_date_exception_payload_hash(jsonb)', 'EXECUTE')
    or has_function_privilege(
      'authenticated', 'public.resolve_working_date_exception_idempotency(text, uuid, text)', 'EXECUTE'
    )
    or has_function_privilege(
      'authenticated', 'public.record_working_date_exception_operation(text, uuid, text, uuid, jsonb)', 'EXECUTE'
    )
    or has_function_privilege(
      'authenticated', 'public.validate_working_date_exception_business_payload(jsonb)', 'EXECUTE'
    )
    or has_function_privilege(
      'authenticated', 'public.normalize_working_date_exception_create_payload(jsonb)', 'EXECUTE'
    )
    or has_function_privilege(
      'authenticated', 'public.normalize_working_date_exception_update_patch(jsonb)', 'EXECUTE'
    )
    or has_function_privilege(
      'authenticated',
      'public.merge_working_date_exception_update_business(public.tenant_working_date_exceptions, jsonb)',
      'EXECUTE'
    )
    or has_function_privilege('authenticated', 'public.build_working_date_exception_response(uuid)', 'EXECUTE')
  then
    raise exception 'case3 failed: internal helper leaked execute to authenticated';
  end if;

  if has_table_privilege('authenticated', 'public.tenant_working_date_exceptions', 'SELECT')
    or has_table_privilege('authenticated', 'public.working_date_exception_operations', 'SELECT')
    or has_table_privilege('anon', 'public.tenant_working_date_exceptions', 'SELECT')
    or has_table_privilege('anon', 'public.working_date_exception_operations', 'SELECT')
  then
    raise exception 'case3 failed: table grant leaked';
  end if;

  raise notice 'p7b_case3_exact_grants_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4) Kind/mode validation matrix.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(4);
begin
  -- a) holiday with day_mode set
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case4a', null, '24_hours')::text
    ),
    'validation_failed'
  );

  -- b) company_closure with times set
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('company_closure', v_d, v_d, 'P7B Case4b', null, null, '08:00', '10:00')::text
    ),
    'validation_failed'
  );

  -- c) exceptional_working_day missing day_mode
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('exceptional_working_day', v_d, v_d, 'P7B Case4c')::text
    ),
    'validation_failed'
  );

  -- d) exceptional working_hours missing work_end
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('exceptional_working_day', v_d, v_d, 'P7B Case4d', null, 'working_hours', '08:00')::text
    ),
    'validation_failed'
  );

  -- e) exceptional working_hours start >= end
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload(
        'exceptional_working_day', v_d, v_d, 'P7B Case4e', null, 'working_hours', '17:00', '08:00'
      )::text
    ),
    'validation_failed'
  );

  -- f) exceptional 24_hours with work_start set
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('exceptional_working_day', v_d, v_d, 'P7B Case4f', null, '24_hours', '08:00')::text
    ),
    'validation_failed'
  );

  -- g) unknown kind
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('bank_holiday', v_d, v_d, 'P7B Case4g')::text
    ),
    'validation_failed'
  );

  -- h) end before start
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('official_holiday', v_d, v_d - 1, 'P7B Case4h')::text
    ),
    'validation_failed'
  );

  -- h2) optional scalar fields must remain strings/null, never coerced JSON.
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      (pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case4h2')
        || jsonb_build_object('notes', jsonb_build_object('unexpected', true)))::text
    ),
    'validation_failed'
  );

  -- h3) exact server limits are validated before table constraints.
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      (pg_temp.p7b_payload('official_holiday', v_d, v_d, repeat('t', 201)))::text
    ),
    'validation_failed'
  );
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      (pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case4h3')
        || jsonb_build_object('notes', repeat('n', 2001)))::text
    ),
    'validation_failed'
  );

  -- h4) dates are canonical YYYY-MM-DD strings only.
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      jsonb_build_object(
        'kind', 'official_holiday',
        'start_date', '2026-7-1',
        'end_date', '2026-07-01',
        'title_en', 'P7B Case4h4'
      )::text
    ),
    'validation_failed'
  );

  -- i) accept 24_hours exceptional
  if (
    public.create_working_date_exception(
      pg_temp.p7b_payload('exceptional_working_day', v_d, v_d, 'P7B Case4i', null, '24_hours'),
      gen_random_uuid()
    ) ->> 'status'
  ) <> 'ok' then
    raise exception 'case4i failed: 24_hours exceptional rejected';
  end if;

  -- j) accept working_hours exceptional (different day; avoids overlap with i)
  if (
    public.create_working_date_exception(
      pg_temp.p7b_payload(
        'exceptional_working_day', v_d + 10, v_d + 10, 'P7B Case4j', null, 'working_hours', '09:00', '15:00'
      ),
      gen_random_uuid()
    ) ->> 'status'
  ) <> 'ok' then
    raise exception 'case4j failed: working_hours exceptional rejected';
  end if;

  raise notice 'p7b_case4_validation_matrix_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 5) Inclusive single-day / multi-day ranges; max span 366 inclusive days.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_base date := pg_temp.p7b_base(5);
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base, v_base, 'P7B Case5 Single'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case5a failed: single-day range rejected: %', v_res;
  end if;
  if (v_res #>> '{exception,start_date}') <> (v_res #>> '{exception,end_date}') then
    raise exception 'case5a failed: single-day start/end mismatch: %', v_res;
  end if;

  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base + 20, v_base + 25, 'P7B Case5 Multi'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case5b failed: multi-day range rejected: %', v_res;
  end if;

  -- max allowed span: end_date - start_date = 365 (366 inclusive days)
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base + 100, v_base + 100 + 365, 'P7B Case5 MaxSpan'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case5c failed: max-span (365 day diff) rejected: %', v_res;
  end if;

  -- one day over the max span is rejected by the RPC validator.
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('official_holiday', v_base + 600, v_base + 600 + 366, 'P7B Case5 OverSpan')::text
    ),
    'validation_failed'
  );

  raise notice 'p7b_case5_ranges_and_span_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6) Boundary-touch: adjacent ranges allowed; same-day boundary touch rejected.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(6);
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d + 5, 'P7B Case6 First'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case6a failed: first range rejected: %', v_res;
  end if;

  -- end=D, start=D+1: adjacent, no overlap, allowed.
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d + 6, v_d + 10, 'P7B Case6 Adjacent'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case6b failed: adjacent range rejected: %', v_res;
  end if;

  -- end=D, start=D: touches the first range's end date, rejected as overlap.
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case6 Overlap')::text
    ),
    'working_date_exception_overlap'
  );

  raise notice 'p7b_case6_boundary_touch_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7) Cancel restores the underlying weekly resolution.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_next_weekday(1, pg_temp.p7b_base(7));
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case7 Holiday'),
    gen_random_uuid()
  );
  perform set_config('test.p7b.case7_id', (v_res #>> '{exception,id}'), true);
  perform set_config('test.p7b.case7_date', v_d::text, true);
end $$;
set local role postgres;
do $$
declare
  v_d date := current_setting('test.p7b.case7_date')::date;
  v_window jsonb;
begin
  v_window := public.resolve_tenant_working_window('00000000-0000-0000-0000-000000000101', v_d);
  if coalesce((v_window ->> 'is_day_off')::boolean, false) is not true then
    raise exception 'case7a failed: holiday did not force day_off: %', v_window;
  end if;
  if v_window -> 'date_exception' ->> 'kind' <> 'official_holiday' then
    raise exception 'case7a failed: date_exception missing kind: %', v_window;
  end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_id uuid := current_setting('test.p7b.case7_id')::uuid;
  v_res jsonb;
begin
  v_res := public.cancel_working_date_exception(v_id, 1, 'P7B case7 cancel', gen_random_uuid());
  if v_res #>> '{exception,status}' <> 'cancelled' then
    raise exception 'case7b failed: cancel did not persist: %', v_res;
  end if;
end $$;
set local role postgres;
do $$
declare
  v_d date := current_setting('test.p7b.case7_date')::date;
  v_window jsonb;
begin
  v_window := public.resolve_tenant_working_window('00000000-0000-0000-0000-000000000101', v_d);
  if coalesce((v_window ->> 'is_day_off')::boolean, false) is true then
    raise exception 'case7c failed: weekly resolution not restored after cancel: %', v_window;
  end if;
  if jsonb_typeof(v_window -> 'date_exception') <> 'null' then
    raise exception 'case7c failed: date_exception still present after cancel: %', v_window;
  end if;
  if (v_window ->> 'work_start') <> '08:00' or (v_window ->> 'work_end') <> '17:00' then
    raise exception 'case7c failed: weekly hours not restored: %', v_window;
  end if;
  raise notice 'p7b_case7_cancel_restores_weekly_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8) Stale version rejection (update + cancel).
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(8);
  v_res jsonb;
  v_id uuid;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case8 Base'),
    gen_random_uuid()
  );
  v_id := (v_res #>> '{exception,id}')::uuid;

  perform pg_temp.p7b_expect_error(
    format(
      'select public.update_working_date_exception(%L::uuid, 99, %L::jsonb, gen_random_uuid())',
      v_id, jsonb_build_object('title_en', 'P7B Case8 Stale')::text
    ),
    'stale_version'
  );

  v_res := public.update_working_date_exception(
    v_id,
    1,
    jsonb_build_object(
      'kind', 'exceptional_working_day',
      'day_mode', '24_hours'
    ),
    gen_random_uuid()
  );
  if v_res #>> '{exception,kind}' <> 'exceptional_working_day'
    or v_res #>> '{exception,day_mode}' <> '24_hours' then
    raise exception 'case8 failed: editable kind/matrix update failed: %', v_res;
  end if;

  perform pg_temp.p7b_expect_error(
    format(
      'select public.cancel_working_date_exception(%L::uuid, 99, %L, gen_random_uuid())',
      v_id, 'stale cancel reason'
    ),
    'stale_version'
  );

  raise notice 'p7b_case8_stale_version_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9) Idempotent create retry (same key/payload) + payload mismatch.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(9);
  v_key uuid := gen_random_uuid();
  v_payload jsonb := pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case9 Idem');
  v_res1 jsonb;
  v_res2 jsonb;
begin
  v_res1 := public.create_working_date_exception(v_payload, v_key);
  if v_res1 ->> 'status' <> 'ok' then
    raise exception 'case9a failed: initial create failed: %', v_res1;
  end if;

  v_res2 := public.create_working_date_exception(v_payload, v_key);
  if v_res2 is distinct from v_res1 then
    raise exception 'case9b failed: replay result mismatch: % vs %', v_res1, v_res2;
  end if;

  begin
    perform public.create_working_date_exception(
      pg_temp.p7b_payload('official_holiday', v_d, v_d + 1, 'P7B Case9 Idem'),
      v_key
    );
    raise exception 'case9d failed: mismatched payload accepted under same key';
  exception
    when others then
      if sqlerrm not like '%idempotency_payload_mismatch%' then
        raise exception 'case9d failed: wrong error: %', sqlerrm;
      end if;
  end;
end $$;
set local role postgres;
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.tenant_working_date_exceptions
  where title_en = 'P7B Case9 Idem';
  if v_count <> 1 then
    raise exception 'case9c failed: idempotent retry duplicated row, count=%', v_count;
  end if;
  raise notice 'p7b_case9_idempotent_create_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10) Title present requirement (blank/whitespace-only titles rejected).
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(10);
begin
  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      jsonb_build_object(
        'kind', 'official_holiday',
        'start_date', to_char(v_d, 'YYYY-MM-DD'),
        'end_date', to_char(v_d, 'YYYY-MM-DD')
      )::text
    ),
    'validation_failed'
  );

  perform pg_temp.p7b_expect_error(
    format(
      'select public.create_working_date_exception(%L::jsonb, gen_random_uuid())',
      jsonb_build_object(
        'kind', 'official_holiday',
        'start_date', to_char(v_d, 'YYYY-MM-DD'),
        'end_date', to_char(v_d, 'YYYY-MM-DD'),
        'title_ar', '   ',
        'title_en', ''
      )::text
    ),
    'validation_failed'
  );

  raise notice 'p7b_case10_title_present_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11) Unconfigured matrix: tenant B never runs update_calendar_settings, so its
--     schedule stays unconfigured for the whole pipeline.
-- ---------------------------------------------------------------------------
begin;
set local role postgres;
do $$
begin
  if (
    select working_schedule_configured from public.tenant_calendar_settings
    where tenant_id = '00000000-0000-0000-0000-000000000102'
  ) then
    raise exception 'case11 setup failed: tenant B unexpectedly configured';
  end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_d date := pg_temp.p7b_base(11);
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case11 Unconfigured'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case11a failed: create on unconfigured tenant rejected: %', v_res;
  end if;
  perform set_config('test.p7b.case11_date', v_d::text, true);
end $$;
set local role postgres;
do $$
declare
  v_d date := current_setting('test.p7b.case11_date')::date;
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_window jsonb;
  v_warnings jsonb;
begin
  v_window := public.resolve_tenant_working_window(v_tenant_b, v_d);
  if coalesce((v_window ->> 'schedule_configured')::boolean, true) is not false then
    raise exception 'case11b failed: schedule_configured should be false: %', v_window;
  end if;
  if coalesce((v_window ->> 'is_unreviewed')::boolean, true) is not false then
    raise exception 'case11b failed: is_unreviewed should be false when exception active: %', v_window;
  end if;
  if (v_window ->> 'day_mode') <> 'day_off' then
    raise exception 'case11b failed: expected day_off, got %', v_window;
  end if;

  v_warnings := public.detect_manual_calendar_schedule_warnings(
    v_tenant_b, v_d, null, null
  );
  if not (v_warnings @> '[{"code":"schedule_unconfigured"}]'::jsonb)
    or not exists (
      select 1
      from jsonb_array_elements(v_warnings) warning
      where warning ->> 'code' = 'non_working_day'
        and warning #>> '{date_exception,kind}' = 'official_holiday'
    ) then
    raise exception 'case11b failed: unconfigured exception warnings incomplete: %', v_warnings;
  end if;

  -- A date without an active exception stays unreviewed on the unconfigured tenant.
  v_window := public.resolve_tenant_working_window(v_tenant_b, v_d + 100);
  if coalesce((v_window ->> 'schedule_configured')::boolean, true) is not false then
    raise exception 'case11c failed: schedule_configured should stay false: %', v_window;
  end if;
  if coalesce((v_window ->> 'is_unreviewed')::boolean, false) is not true then
    raise exception 'case11c failed: expected is_unreviewed true without exception: %', v_window;
  end if;

  raise notice 'p7b_case11_unconfigured_matrix_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12) Configured matrix: holiday overrides a working day; exceptional working
--     day reopens a weekly day_off.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_monday date := pg_temp.p7b_next_weekday(1, pg_temp.p7b_base(12));
  v_saturday date := pg_temp.p7b_next_weekday(6, pg_temp.p7b_base(12));
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_monday, v_monday, 'P7B Case12 Holiday'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case12a failed: holiday create failed: %', v_res;
  end if;

  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload(
      'exceptional_working_day', v_saturday, v_saturday, 'P7B Case12 Exceptional',
      null, 'working_hours', '10:00', '14:00'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case12b failed: exceptional create failed: %', v_res;
  end if;

  perform set_config('test.p7b.case12_monday', v_monday::text, true);
  perform set_config('test.p7b.case12_saturday', v_saturday::text, true);
end $$;
set local role postgres;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_monday date := current_setting('test.p7b.case12_monday')::date;
  v_saturday date := current_setting('test.p7b.case12_saturday')::date;
  v_window jsonb;
begin
  v_window := public.resolve_tenant_working_window(v_tenant_a, v_monday);
  if not coalesce((v_window ->> 'is_day_off')::boolean, false) then
    raise exception 'case12c failed: holiday did not override working Monday: %', v_window;
  end if;

  v_window := public.resolve_tenant_working_window(v_tenant_a, v_saturday);
  if not coalesce((v_window ->> 'is_working_hours')::boolean, false) then
    raise exception 'case12d failed: exceptional day did not reopen day_off Saturday: %', v_window;
  end if;
  if (v_window ->> 'work_start') <> '10:00' or (v_window ->> 'work_end') <> '14:00' then
    raise exception 'case12d failed: exceptional hours not applied: %', v_window;
  end if;

  raise notice 'p7b_case12_configured_matrix_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13) Safe resolve projection: date_exception carries only kind/title_ar/title_en.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(13);
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload(
      'official_holiday', v_d, v_d, 'P7B Case13 Projection', 'استثناء الإسقاط', null, null, null,
      'internal ops notes should never leak into the safe projection'
    ),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case13 setup failed: %', v_res;
  end if;
  perform set_config('test.p7b.case13_date', v_d::text, true);
end $$;
set local role postgres;
do $$
declare
  v_d date := current_setting('test.p7b.case13_date')::date;
  v_window jsonb;
  v_keys text[];
begin
  v_window := public.resolve_tenant_working_window('00000000-0000-0000-0000-000000000101', v_d);
  select array_agg(k order by k) into v_keys
  from jsonb_object_keys(v_window -> 'date_exception') k;

  if v_keys is distinct from array['kind', 'title_ar', 'title_en'] then
    raise exception 'case13 failed: unexpected date_exception keys: %', v_keys;
  end if;
  if v_window -> 'date_exception' ? 'notes' then
    raise exception 'case13 failed: notes leaked into safe projection: %', v_window;
  end if;

  raise notice 'p7b_case13_safe_projection_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14) detect_manual_calendar_schedule_warnings non_working_day carries date_exception.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(14);
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('company_closure', v_d, v_d, 'P7B Case14 Closure'),
    gen_random_uuid()
  );
  if v_res ->> 'status' <> 'ok' then
    raise exception 'case14 setup failed: %', v_res;
  end if;
  perform set_config('test.p7b.case14_date', v_d::text, true);
end $$;
set local role postgres;
do $$
declare
  v_d date := current_setting('test.p7b.case14_date')::date;
  v_warnings jsonb;
  v_warning jsonb;
  v_found boolean := false;
begin
  v_warnings := public.detect_manual_calendar_schedule_warnings(
    '00000000-0000-0000-0000-000000000101', v_d, null, null
  );
  for v_warning in select jsonb_array_elements(v_warnings) loop
    if v_warning ->> 'code' = 'non_working_day' then
      v_found := true;
      if v_warning -> 'date_exception' ->> 'kind' <> 'company_closure' then
        raise exception 'case14 failed: date_exception missing/wrong on warning: %', v_warning;
      end if;
    end if;
  end loop;
  if not v_found then
    raise exception 'case14 failed: non_working_day warning missing: %', v_warnings;
  end if;

  raise notice 'p7b_case14_schedule_warnings_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 15) Creating a manual calendar event on a closed date must not mutate the
--     underlying date exception row.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(15);
  v_res jsonb;
  v_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_event_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case15 Holiday'),
    gen_random_uuid()
  );
  v_id := (v_res #>> '{exception,id}')::uuid;

  v_before := public.get_working_date_exception(v_id);

  v_event_res := public.create_manual_calendar_event(
    jsonb_build_object(
      'type', 'custom',
      'scheduled_date', to_char(v_d, 'YYYY-MM-DD'),
      'title_en', 'P7B Case15 Event',
      'acknowledgements', jsonb_build_object(
        'acknowledge_non_working_day', true,
        'day_off_override_reason', 'P7B closure override'
      )
    ),
    gen_random_uuid()
  );
  if v_event_res ->> 'status' <> 'ok' then
    raise exception 'case15 failed: event create on closure date rejected: %', v_event_res;
  end if;

  v_after := public.get_working_date_exception(v_id);

  if v_after is distinct from v_before then
    raise exception 'case15 failed: exception row mutated by event creation: before=% after=%',
      v_before, v_after;
  end if;

  raise notice 'p7b_case15_events_unchanged_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16) Conditional reminder bump: title-only update must not bump the tenant's
--     reminder reconcile generation; a schedule-affecting field update must.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(16);
  v_res jsonb;
  v_id uuid;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case16 Reminder'),
    gen_random_uuid()
  );
  v_id := (v_res #>> '{exception,id}')::uuid;
  perform set_config('test.p7b.case16_id', v_id::text, true);
  perform set_config('test.p7b.case16_date', v_d::text, true);
end $$;
set local role postgres;
do $$
declare
  v_gen bigint;
begin
  select generation into v_gen
  from public.calendar_reminder_reconcile_queue
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  perform set_config('test.p7b.case16_gen_create', v_gen::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_id uuid := current_setting('test.p7b.case16_id')::uuid;
begin
  perform public.update_working_date_exception(
    v_id, 1, jsonb_build_object('title_en', 'P7B Case16 Reminder Renamed'), gen_random_uuid()
  );
end $$;
set local role postgres;
do $$
declare
  v_gen_create bigint := current_setting('test.p7b.case16_gen_create')::bigint;
  v_gen bigint;
begin
  select generation into v_gen
  from public.calendar_reminder_reconcile_queue
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  if v_gen <> v_gen_create then
    raise exception 'case16a failed: title-only update bumped reminder generation (% -> %)',
      v_gen_create, v_gen;
  end if;
  perform set_config('test.p7b.case16_gen_title', v_gen::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_id uuid := current_setting('test.p7b.case16_id')::uuid;
  v_d date := current_setting('test.p7b.case16_date')::date;
begin
  perform public.update_working_date_exception(
    v_id, 2, jsonb_build_object('end_date', to_char(v_d + 1, 'YYYY-MM-DD')), gen_random_uuid()
  );
end $$;
set local role postgres;
do $$
declare
  v_gen_title bigint := current_setting('test.p7b.case16_gen_title')::bigint;
  v_gen bigint;
begin
  select generation into v_gen
  from public.calendar_reminder_reconcile_queue
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  if v_gen <= v_gen_title then
    raise exception 'case16b failed: schedule-field update did not bump reminder generation (% -> %)',
      v_gen_title, v_gen;
  end if;
  raise notice 'p7b_case16_conditional_reminder_bump_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17) Audit: entity_type tenant_working_date_exceptions, lowercase actions,
--     exactly one row per mutation.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(17);
  v_res jsonb;
  v_id uuid;
  v_count int;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case17 Audit'),
    gen_random_uuid()
  );
  v_id := (v_res #>> '{exception,id}')::uuid;

  select count(*) into v_count from public.audit_log
  where entity_type = 'tenant_working_date_exceptions' and entity_id = v_id and action = 'create';
  if v_count <> 1 then
    raise exception 'case17a failed: expected 1 create audit row, got %', v_count;
  end if;

  perform public.update_working_date_exception(
    v_id, 1, jsonb_build_object('title_en', 'P7B Case17 Audit Renamed'), gen_random_uuid()
  );
  select count(*) into v_count from public.audit_log
  where entity_type = 'tenant_working_date_exceptions' and entity_id = v_id and action = 'update';
  if v_count <> 1 then
    raise exception 'case17b failed: expected 1 update audit row, got %', v_count;
  end if;

  perform public.cancel_working_date_exception(v_id, 2, 'P7B case17 cancel reason', gen_random_uuid());
  select count(*) into v_count from public.audit_log
  where entity_type = 'tenant_working_date_exceptions' and entity_id = v_id and action = 'cancel';
  if v_count <> 1 then
    raise exception 'case17c failed: expected 1 cancel audit row, got %', v_count;
  end if;

  if exists (
    select 1 from public.audit_log
    where entity_type = 'tenant_working_date_exceptions' and entity_id = v_id and action <> lower(action)
  ) then
    raise exception 'case17d failed: audit action not lowercase for %', v_id;
  end if;

  raise notice 'p7b_case17_audit_rows_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18) EXPLAIN gate: at fixture scale, the active-range containment lookup
--     must use excl_tenant_working_date_exceptions_active_range.
-- ---------------------------------------------------------------------------
begin;
set local role postgres;
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_base date := pg_temp.p7b_base(18);
  v_probe_date date := v_base + 40;
  v_plan_text text := '';
  v_line text;
begin
  perform pg_temp.p7b_seed_bulk_exceptions(v_tenant, 60, v_base);
  perform set_config('enable_seqscan', 'off', true);

  for v_line in
    explain (format text)
    select 1
    from public.tenant_working_date_exceptions twde
    where twde.tenant_id = v_tenant
      and twde.status = 'active'::public.tenant_working_date_exception_status
      and daterange(twde.start_date, twde.end_date, '[]') @> v_probe_date
  loop
    v_plan_text := v_plan_text || v_line || E'\n';
  end loop;

  perform set_config('enable_seqscan', 'on', true);

  if v_plan_text not ilike '%excl_tenant_working_date_exceptions_active_range%' then
    raise exception 'case18 failed: explain plan did not use the exclusion index: %', v_plan_text;
  end if;

  raise notice 'p7b_case18_explain_gate_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19) Cross-tenant: tenant B cannot read tenant A's exception id.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(19);
  v_res jsonb;
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case19 CrossTenant'),
    gen_random_uuid()
  );
  perform set_config('test.p7b.case19_id', (v_res #>> '{exception,id}'), true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_id uuid := current_setting('test.p7b.case19_id')::uuid;
begin
  perform pg_temp.p7b_expect_error(
    format('select public.get_working_date_exception(%L::uuid)', v_id),
    'validation_failed'
  );
  raise notice 'p7b_case19_cross_tenant_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20) List defaults (status=active) and both-or-neither date filters.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_base date := pg_temp.p7b_base(20);
  v_res jsonb;
  v_id_active uuid;
  v_id_cancel uuid;
  v_list jsonb;
  v_ids text[];
begin
  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base, v_base, 'P7B Case20 Active'),
    gen_random_uuid()
  );
  v_id_active := (v_res #>> '{exception,id}')::uuid;

  v_res := public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base + 10, v_base + 10, 'P7B Case20 Cancelled'),
    gen_random_uuid()
  );
  v_id_cancel := (v_res #>> '{exception,id}')::uuid;
  perform public.cancel_working_date_exception(
    v_id_cancel, 1, 'cancel for default-status probe', gen_random_uuid()
  );

  v_list := public.list_working_date_exceptions(
    jsonb_build_object('date_from', v_base - 5, 'date_to', v_base + 20)
  );
  select array_agg(r ->> 'id') into v_ids from jsonb_array_elements(v_list -> 'items') r;

  if v_ids is null or not (v_ids @> array[v_id_active::text]) then
    raise exception 'case20a failed: active row missing from default list: %', v_list;
  end if;
  if v_ids @> array[v_id_cancel::text] then
    raise exception 'case20a failed: cancelled row leaked into default (active) list: %', v_list;
  end if;
  if (v_list -> 'filters_applied' ->> 'status') <> 'active' then
    raise exception 'case20a failed: filters_applied.status not active: %', v_list;
  end if;

  -- both-or-neither: supplying date_from without date_to is rejected.
  perform pg_temp.p7b_expect_error(
    format(
      'select public.list_working_date_exceptions(%L::jsonb)',
      jsonb_build_object('date_from', to_char(v_base, 'YYYY-MM-DD'))::text
    ),
    'validation_failed'
  );

  perform pg_temp.p7b_expect_error(
    'select public.list_working_date_exceptions(''{"unexpected":true}''::jsonb)',
    'validation_failed'
  );
  perform pg_temp.p7b_expect_error(
    'select public.list_working_date_exceptions(''{}''::jsonb, null, 0)',
    'validation_failed'
  );
  perform pg_temp.p7b_expect_error(
    'select public.list_working_date_exceptions(''{}''::jsonb, null, 101)',
    'validation_failed'
  );
  perform pg_temp.p7b_expect_error(
    'select public.list_working_date_exceptions(''{"date_from":"2026-7-01","date_to":"2026-07-31"}''::jsonb)',
    'validation_failed'
  );
  perform pg_temp.p7b_expect_error(
    'select public.list_working_date_exceptions(''{}''::jsonb, ''eyJ2ZXJzaW9uIjoibm90LWFuLWludCJ9'', 50)',
    'validation_failed'
  );

  raise notice 'p7b_case20_list_defaults_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 21) Pagination has_more + cursor binding fails on filter change.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_base date := pg_temp.p7b_base(21);
  v_page1 jsonb;
  v_page2 jsonb;
  v_cursor text;
begin
  perform public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base, v_base, 'P7B Case21 Page1'),
    gen_random_uuid()
  );
  perform public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base + 5, v_base + 5, 'P7B Case21 Page2'),
    gen_random_uuid()
  );
  perform public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_base + 10, v_base + 10, 'P7B Case21 Page3'),
    gen_random_uuid()
  );

  v_page1 := public.list_working_date_exceptions(
    jsonb_build_object('kind', 'official_holiday', 'date_from', v_base - 1, 'date_to', v_base + 20),
    null, 2
  );
  if jsonb_array_length(v_page1 -> 'items') <> 2 then
    raise exception 'case21a failed: expected 2 items on page1: %', v_page1;
  end if;
  if not coalesce((v_page1 ->> 'has_more')::boolean, false) then
    raise exception 'case21a failed: expected has_more true on page1: %', v_page1;
  end if;
  v_cursor := v_page1 ->> 'next_cursor';
  if v_cursor is null then
    raise exception 'case21a failed: next_cursor missing on page1: %', v_page1;
  end if;

  v_page2 := public.list_working_date_exceptions(
    jsonb_build_object('kind', 'official_holiday', 'date_from', v_base - 1, 'date_to', v_base + 20),
    v_cursor, 2
  );
  if jsonb_array_length(v_page2 -> 'items') <> 1 then
    raise exception 'case21b failed: expected 1 remaining item on page2: %', v_page2;
  end if;
  if coalesce((v_page2 ->> 'has_more')::boolean, true) then
    raise exception 'case21b failed: expected has_more false on final page: %', v_page2;
  end if;

  -- cursor bound to kind='official_holiday' must reject a changed filter.
  perform pg_temp.p7b_expect_error(
    format(
      'select public.list_working_date_exceptions(%L::jsonb, %L, 2)',
      jsonb_build_object(
        'kind', 'exceptional_working_day', 'date_from', v_base - 1, 'date_to', v_base + 20
      )::text,
      v_cursor
    ),
    'validation_failed'
  );

  raise notice 'p7b_case21_pagination_and_cursor_ok';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 22) Return shape: list uses items + filters_applied (never rows).
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_d date := pg_temp.p7b_base(22);
  v_list jsonb;
begin
  perform public.create_working_date_exception(
    pg_temp.p7b_payload('official_holiday', v_d, v_d, 'P7B Case22 Shape'),
    gen_random_uuid()
  );

  v_list := public.list_working_date_exceptions(
    jsonb_build_object('date_from', v_d - 1, 'date_to', v_d + 1)
  );
  if not (v_list ? 'items') or (v_list ? 'rows') then
    raise exception 'case22 failed: unexpected list shape: %', v_list;
  end if;
  if not (v_list ? 'filters_applied') then
    raise exception 'case22 failed: filters_applied missing: %', v_list;
  end if;
  if jsonb_typeof(v_list -> 'items') <> 'array' then
    raise exception 'case22 failed: items is not an array: %', v_list;
  end if;

  raise notice 'p7b_case22_return_shape_ok';
end $$;
rollback;

select 'phase_7_working_date_exceptions_verification_passed' as result;
