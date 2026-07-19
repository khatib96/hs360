\set ON_ERROR_STOP on

-- Phase 7 M11 pollution baseline: capture row counts for the 11 named calendar
-- tables BEFORE Phase 6/7 suites. Persisted across psql sessions so the post
-- gate (after Phase W) can compare.

create table if not exists public._m11_pollution_baseline (
  table_name text primary key,
  row_count bigint not null,
  captured_at timestamptz not null default now()
);

create or replace function pg_temp.m11_pollution_write_baseline()
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
  truncate public._m11_pollution_baseline;
  foreach v_name in array v_tables loop
    v_sql := format('select count(*) from public.%I', v_name);
    execute v_sql into v_count;
    insert into public._m11_pollution_baseline(table_name, row_count)
    values (v_name, v_count);
    raise notice 'm11_pollution_pre %=%', v_name, v_count;
  end loop;

  if (select count(*) from public._m11_pollution_baseline) <> 11 then
    raise exception 'm11_pollution_baseline: expected 11 rows';
  end if;
  raise notice 'phase_7_m11_pollution_baseline_captured';
end; $$;

select pg_temp.m11_pollution_write_baseline();
