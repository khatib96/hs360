\set ON_ERROR_STOP on

-- Phase 7 M11 pollution gate (post Phase W + audit reclaim):
-- Strict baseline/post count equality for all 11 tables, plus marker/orphan
-- checks and a negative self-test. Drops public._m11_pollution_baseline after
-- the final successful assertion.

create temporary table if not exists pg_temp.m11_pollution_post (
  table_name text primary key,
  row_count bigint not null
) on commit preserve rows;

create or replace function pg_temp.m11_pollution_capture_post()
returns void language plpgsql as $$
declare
  v_tables text[] := array[
    'calendar_events',
    'calendar_event_participants',
    'calendar_reminder_plans',
    'calendar_reminder_runs',
    'calendar_reminder_reconcile_queue',
    'calendar_generation_runs',
    'calendar_generation_run_tenants',
    'calendar_manual_event_operations',
    'calendar_schedule_operations',
    'tenant_working_date_exceptions',
    'working_date_exception_operations'
  ];
  v_name text;
  v_count bigint;
  v_sql text;
begin
  delete from pg_temp.m11_pollution_post;
  foreach v_name in array v_tables loop
    v_sql := format('select count(*) from public.%I', v_name);
    execute v_sql into v_count;
    insert into pg_temp.m11_pollution_post(table_name, row_count)
    values (v_name, v_count);
    raise notice 'm11_pollution_post %=%', v_name, v_count;
  end loop;
end; $$;

create or replace function pg_temp.m11_pollution_assert_clean()
returns void language plpgsql as $$
declare
  v_bad int;
  v_pre bigint;
  v_post bigint;
  v_name text;
  v_delta bigint;
  v_mismatches text := '';
begin
  if to_regclass('public._m11_pollution_baseline') is null then
    raise exception 'm11_pollution: missing baseline table (run baseline before Phase 6/7)';
  end if;

  if (select count(*) from public._m11_pollution_baseline) <> 11 then
    raise exception 'm11_pollution: baseline incomplete';
  end if;

  perform pg_temp.m11_pollution_capture_post();

  if (select count(*) from pg_temp.m11_pollution_post) <> 11 then
    raise exception 'm11_pollution: expected 11 post snapshot rows';
  end if;

  -- Strict count equality for every gated table. No blanket tolerance.
  -- Documented reclaim of generation/reminder run ledgers happens in
  -- phase_7_m11_phase67_audit_reclaim.sql before this gate; any remaining
  -- delta is a real leak and must fail the runner.
  for v_name, v_pre, v_post in
    select b.table_name, b.row_count, p.row_count
    from public._m11_pollution_baseline b
    join pg_temp.m11_pollution_post p using (table_name)
    order by b.table_name
  loop
    v_delta := v_post - v_pre;
    raise notice 'm11_pollution_delta % pre=% post=% delta=%',
      v_name, v_pre, v_post, v_delta;
    if v_delta <> 0 then
      v_mismatches := v_mismatches
        || format(' %s(pre=%s,post=%s,delta=%s)', v_name, v_pre, v_post, v_delta);
    end if;
  end loop;

  if v_mismatches <> '' then
    raise exception 'm11_pollution: count mismatch:%', v_mismatches;
  end if;

  -- Marker leftovers (additional layer; not a substitute for count equality).
  select count(*) into v_bad
  from public.calendar_events
  where title_en like 'P7M11-%'
     or title_en like 'P7R-PERF-%'
     or title_en like 'M11PERF-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: calendar_events marker rows=%', v_bad;
  end if;

  select count(*) into v_bad
  from public.calendar_event_participants ep
  join public.calendar_events e
    on e.id = ep.event_id and e.tenant_id = ep.tenant_id
  where e.title_en like 'P7M11-%'
     or e.title_en like 'M11PERF-%'
     or e.title_en like 'P7R-PERF-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: participants orphaned to markers=%', v_bad;
  end if;

  select count(*) into v_bad
  from public.calendar_reminder_plans p
  join public.calendar_events e
    on e.id = p.calendar_event_id and e.tenant_id = p.tenant_id
  where e.title_en like 'P7M11-%'
     or e.title_en like 'M11PERF-%'
     or e.title_en like 'P7R-PERF-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: reminder_plans tied to markers=%', v_bad;
  end if;

  select count(*) into v_bad
  from public.calendar_reminder_runs
  where coalesce(error_summary, '') like 'P7M11-%'
     or coalesce(error_summary, '') like 'M11PERF-%'
     or coalesce(error_summary, '') like 'P7R-PERF-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: reminder_runs marker rows=%', v_bad;
  end if;

  select count(*) into v_bad
  from public.calendar_schedule_operations
  where idempotency_key::text like '00000000-0000-4111-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: schedule_operations marker rows=%', v_bad;
  end if;

  select count(*) into v_bad
  from public.calendar_manual_event_operations
  where idempotency_key::text like '00000000-0000-4111-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: manual_event_operations marker rows=%', v_bad;
  end if;

  select count(*) into v_bad
  from public.calendar_generation_runs
  where coalesce(error_summary, '') like 'P7M11-%'
     or coalesce(error_summary, '') like 'M11PERF-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: generation_runs marker rows=%', v_bad;
  end if;

  select count(*) into v_bad
  from public.tenant_working_date_exceptions
  where coalesce(title_en, '') like 'P7M11-%'
     or coalesce(title_ar, '') like 'P7M11-%'
     or coalesce(notes, '') like 'P7M11-%';
  if v_bad <> 0 then
    raise exception 'm11_pollution: working_date_exceptions marker rows=%', v_bad;
  end if;

  raise notice 'phase_7_m11_pollution_gate_passed';
end; $$;

-- Negative self-test: inject an unmarked-count + marker leak, expect failure.
do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_id uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_failed boolean := false;
  v_err text;
begin
  alter table public.calendar_events
    disable trigger trg_calendar_events_reminder_refresh;

  insert into public.calendar_events (
    id, tenant_id, type, status, source_kind, scheduled_date, original_due_date,
    title_ar, title_en
  ) values (
    v_id, v_tenant, 'custom', 'pending', 'manual', current_date, current_date,
    'P7M11-LEAK', 'P7M11-LEAK'
  );

  begin
    perform pg_temp.m11_pollution_assert_clean();
  exception
    when others then
      v_err := sqlerrm;
      -- Count mismatch (strict) and/or marker detection both prove the gate.
      if v_err like 'm11_pollution: count mismatch:%'
         or v_err like 'm11_pollution: calendar_events marker rows=%' then
        v_failed := true;
        raise notice 'm11_pollution_negative_self_test_caught %', v_err;
      else
        alter table public.calendar_events
          enable trigger trg_calendar_events_reminder_refresh;
        raise;
      end if;
  end;

  delete from public.calendar_events where id = v_id;
  alter table public.calendar_events
    enable trigger trg_calendar_events_reminder_refresh;

  if not v_failed then
    raise exception 'm11_pollution negative self-test did not fail on marker leak';
  end if;
  raise notice 'm11_pollution_negative_self_test_passed';
end $$;

-- Real post assertion after negative cleanup.
select pg_temp.m11_pollution_assert_clean();

-- Remove the durable baseline scratch table after a successful final check.
drop table if exists public._m11_pollution_baseline;

do $$ begin
  raise notice 'm11_pollution_baseline_dropped';
end $$;