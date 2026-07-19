\set ON_ERROR_STOP on

-- Phase 7 M11 performance protocol:
-- Dataset: measured tenant 5,000 events; two noise tenants >= 2,500 each.
-- Protocol per query: 2 warm-up + 20 measured runs; median/P95 from measured only.
-- Fixture creation is outside timed RPC windows.
-- Seq Scan is NOT an automatic failure; hard ceilings use P95.

create or replace function pg_temp.m11_percentile(p_values numeric[], p_p numeric)
returns numeric language plpgsql immutable as $$
declare
  v_sorted numeric[];
  v_n int;
  v_idx numeric;
  v_lo int;
  v_hi int;
  v_frac numeric;
begin
  if p_values is null or cardinality(p_values) = 0 then
    raise exception 'm11_percentile: empty';
  end if;
  select array_agg(x order by x) into v_sorted from unnest(p_values) as t(x);
  v_n := cardinality(v_sorted);
  if v_n = 1 then
    return v_sorted[1];
  end if;
  v_idx := 1 + (p_p / 100.0) * (v_n - 1);
  v_lo := floor(v_idx)::int;
  v_hi := ceil(v_idx)::int;
  v_frac := v_idx - v_lo;
  if v_lo < 1 then v_lo := 1; end if;
  if v_hi > v_n then v_hi := v_n; end if;
  if v_lo = v_hi then
    return v_sorted[v_lo];
  end if;
  return v_sorted[v_lo] + (v_sorted[v_hi] - v_sorted[v_lo]) * v_frac;
end; $$;

-- Marker cleanup must delete dependents first: reminder plans use ON DELETE
-- RESTRICT, and bulk seed fires trg_calendar_events_reminder_refresh.
create or replace function pg_temp.m11_purge_marker_events()
returns void language plpgsql as $$
begin
  delete from public.calendar_schedule_operations o
  using public.calendar_events e
  where o.tenant_id = e.tenant_id
    and o.result_event_id = e.id
    and e.title_en like 'M11PERF-%';

  delete from public.calendar_refill_execution_facts f
  using public.calendar_events e
  where f.tenant_id = e.tenant_id
    and f.calendar_event_id = e.id
    and e.title_en like 'M11PERF-%';

  delete from public.calendar_reminder_plans p
  using public.calendar_events e
  where p.tenant_id = e.tenant_id
    and p.calendar_event_id = e.id
    and e.title_en like 'M11PERF-%';

  update public.calendar_events ce
  set parent_event_id = null
  where ce.parent_event_id in (
    select e.id from public.calendar_events e where e.title_en like 'M11PERF-%'
  );

  delete from public.calendar_events where title_en like 'M11PERF-%';
end; $$;

create or replace function pg_temp.m11_insert_events(
  p_tenant uuid,
  p_prefix text,
  p_count int,
  p_agents uuid[]
)
returns void language plpgsql as $$
declare
  v_i int;
  v_date date;
  v_agent uuid;
  v_type public.calendar_event_type;
  v_status public.calendar_event_status;
  v_types public.calendar_event_type[] := array[
    'custom', 'refill_due', 'billing_due', 'follow_up', 'maintenance_due'
  ];
  v_statuses public.calendar_event_status[] := array['pending', 'done', 'missed'];
begin
  for v_i in 1..p_count loop
    v_date := current_date + ((v_i % 90) - 30);
    v_agent := case
      when cardinality(p_agents) = 0 then null
      else p_agents[1 + ((v_i - 1) % cardinality(p_agents))]
    end;
    v_type := v_types[1 + ((v_i - 1) % array_length(v_types, 1))];
    v_status := v_statuses[1 + ((v_i - 1) % array_length(v_statuses, 1))];
    insert into public.calendar_events (
      id, tenant_id, type, status, source_kind, scheduled_date, original_due_date,
      title_ar, title_en, assigned_agent_id
    ) values (
      gen_random_uuid(),
      p_tenant,
      v_type,
      v_status,
      'manual',
      v_date,
      v_date,
      p_prefix || v_i::text,
      p_prefix || v_i::text,
      v_agent
    );
  end loop;
end; $$;

-- ---------------------------------------------------------------------------
-- Seed (committed; outside timed windows)
-- ---------------------------------------------------------------------------
do $$
declare
  v_pg text;
  v_measured uuid := '00000000-0000-0000-0000-000000000101';
  v_noise_a uuid := '00000000-0000-0000-0000-000000000102';
  v_noise_b uuid := gen_random_uuid();
  v_agents uuid[] := array[
    '00000000-0000-0000-0000-000000000601'::uuid,
    '00000000-0000-0000-0000-000000000602'::uuid
  ];
  v_cnt int;
  v_slug text;
begin
  select version() into v_pg;
  raise notice 'm11_perf_env pg=%', v_pg;
  raise notice 'm11_perf_dataset measured=5000 noise_a>=2500 noise_b>=2500';

  perform pg_temp.m11_purge_marker_events();
  delete from public.tenants where slug like 'm11-noise-%';

  select count(*) into v_cnt
  from public.calendar_events
  where tenant_id = v_measured;
  raise notice 'm11_perf_measured_tenant_residual_before_seed=%', v_cnt;

  v_slug := 'm11-noise-' || left(replace(v_noise_b::text, '-', ''), 12);
  insert into public.tenants (id, name, slug, default_locale, country_code, timezone)
  values (v_noise_b, 'M11 Noise B', v_slug, 'en', 'KW', 'Asia/Kuwait');

  -- Disable reminder fan-out during bulk seed: read-RPC budgets measure list /
  -- summary / route paths, not plan materialization on INSERT.
  alter table public.calendar_events
    disable trigger trg_calendar_events_reminder_refresh;
  begin
    perform pg_temp.m11_insert_events(v_measured, 'M11PERF-M-', 5000, v_agents);
    perform pg_temp.m11_insert_events(v_noise_a, 'M11PERF-NA-', 2500, array[]::uuid[]);
    perform pg_temp.m11_insert_events(v_noise_b, 'M11PERF-NB-', 2500, array[]::uuid[]);
  exception
    when others then
      alter table public.calendar_events
        enable trigger trg_calendar_events_reminder_refresh;
      raise;
  end;
  alter table public.calendar_events
    enable trigger trg_calendar_events_reminder_refresh;
  analyze public.calendar_events;

  select count(*) into v_cnt
  from public.calendar_events
  where tenant_id = v_measured and title_en like 'M11PERF-M-%';
  if v_cnt < 5000 then
    raise exception 'm11_perf seed measured count=%', v_cnt;
  end if;
  select count(*) into v_cnt
  from public.calendar_events
  where tenant_id = v_measured;
  raise notice 'm11_perf_measured_tenant_total_after_seed=%', v_cnt;
  select count(*) into v_cnt
  from public.calendar_events
  where tenant_id = v_noise_a and title_en like 'M11PERF-NA-%';
  if v_cnt < 2500 then
    raise exception 'm11_perf seed noise_a count=%', v_cnt;
  end if;
  select count(*) into v_cnt
  from public.calendar_events
  where tenant_id = v_noise_b and title_en like 'M11PERF-NB-%';
  if v_cnt < 2500 then
    raise exception 'm11_perf seed noise_b count=%', v_cnt;
  end if;

  -- Informational EXPLAIN as postgres (internal helper not granted to authenticated).
  declare
    v_plan jsonb;
    v_line text;
    v_today date := current_date;
  begin
    v_plan := null;
    for v_line in
      explain (analyze, buffers, format json)
      select s.event_id
      from public.calendar_read_scoped_events(
        v_measured,
        'tenant_wide',
        null,
        row(null, null, null, false, null, null, null, null, false, false, null)::public.calendar_read_filter_bundle,
        v_today
      ) s
      where s.scheduled_date between v_today - 30 and v_today + 30
      limit 50
    loop
      v_plan := v_line::jsonb;
    end loop;
    raise notice 'm11_perf_explain_list_sample execution_ms=%',
      (v_plan -> 0 -> 'Execution Time')::text;
  end;

  perform set_config('test.m11perf.noise_b', v_noise_b::text, false);
end $$;

-- ---------------------------------------------------------------------------
-- Timed RPCs under authenticated JWT (fixture already seeded)
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_measured uuid := '00000000-0000-0000-0000-000000000101';
  v_times numeric[];
  v_i int;
  v_start timestamptz;
  v_elapsed numeric;
  v_median numeric;
  v_p95 numeric;
  v_today date;
  v_page jsonb;
  v_summary jsonb;
  v_route jsonb;
begin
  -- Use calendar date from the host; RPC still resolves tenant-local today internally.
  v_today := current_date;

  -- Query 1: list_calendar_events month page
  v_times := array[]::numeric[];
  for v_i in 1..22 loop
    v_start := clock_timestamp();
    v_page := public.list_calendar_events(
      v_today - 30, v_today + 30, '{}'::jsonb, null, null, 50
    );
    v_elapsed := extract(epoch from (clock_timestamp() - v_start)) * 1000.0;
    if v_i > 2 then
      v_times := v_times || v_elapsed;
    end if;
  end loop;
  v_median := pg_temp.m11_percentile(v_times, 50);
  v_p95 := pg_temp.m11_percentile(v_times, 95);
  raise notice 'm11_perf list_calendar_events median_ms=% p95_ms=% rows=%',
    round(v_median, 2), round(v_p95, 2),
    jsonb_array_length(v_page -> 'in_range' -> 'rows');
  if v_p95 > 3000 then
    raise exception 'm11_perf list_calendar_events P95 % exceeds hard ceiling 3000ms', v_p95;
  end if;

  -- Query 2: range summary
  v_times := array[]::numeric[];
  for v_i in 1..22 loop
    v_start := clock_timestamp();
    v_summary := public.get_calendar_range_summary(v_today - 30, v_today + 30, '{}'::jsonb);
    v_elapsed := extract(epoch from (clock_timestamp() - v_start)) * 1000.0;
    if v_i > 2 then
      v_times := v_times || v_elapsed;
    end if;
  end loop;
  v_median := pg_temp.m11_percentile(v_times, 50);
  v_p95 := pg_temp.m11_percentile(v_times, 95);
  raise notice 'm11_perf get_calendar_range_summary median_ms=% p95_ms=%',
    round(v_median, 2), round(v_p95, 2);
  if v_p95 > 1000 then
    raise exception 'm11_perf range_summary P95 % exceeds hard ceiling 1000ms', v_p95;
  end if;

  -- Query 3: selected-day agenda
  v_times := array[]::numeric[];
  for v_i in 1..22 loop
    v_start := clock_timestamp();
    v_page := public.list_calendar_events(
      v_today, v_today, '{}'::jsonb, null, null, 100
    );
    v_elapsed := extract(epoch from (clock_timestamp() - v_start)) * 1000.0;
    if v_i > 2 then
      v_times := v_times || v_elapsed;
    end if;
  end loop;
  v_median := pg_temp.m11_percentile(v_times, 50);
  v_p95 := pg_temp.m11_percentile(v_times, 95);
  raise notice 'm11_perf selected_day_agenda median_ms=% p95_ms=%',
    round(v_median, 2), round(v_p95, 2);
  if v_p95 > 800 then
    raise exception 'm11_perf selected_day P95 % exceeds hard ceiling 800ms', v_p95;
  end if;

  -- Query 4: route day (owner employee scoped)
  v_times := array[]::numeric[];
  for v_i in 1..22 loop
    v_start := clock_timestamp();
    v_route := public.get_calendar_route_day(
      v_today,
      '00000000-0000-0000-0000-000000000601'::uuid
    );
    v_elapsed := extract(epoch from (clock_timestamp() - v_start)) * 1000.0;
    if v_i > 2 then
      v_times := v_times || v_elapsed;
    end if;
  end loop;
  v_median := pg_temp.m11_percentile(v_times, 50);
  v_p95 := pg_temp.m11_percentile(v_times, 95);
  raise notice 'm11_perf get_calendar_route_day median_ms=% p95_ms=%',
    round(v_median, 2), round(v_p95, 2);
  if v_p95 > 1000 then
    raise exception 'm11_perf route_day P95 % exceeds hard ceiling 1000ms', v_p95;
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_page -> 'in_range' -> 'rows') r
    where (r ->> 'title_en') like 'M11PERF-N%'
  ) then
    raise exception 'm11_perf: noise tenant rows leaked into measured list';
  end if;

  raise notice 'phase_7_m11_performance_timed_ok';
end $$;
commit;

-- ---------------------------------------------------------------------------
-- Cleanup committed markers
-- ---------------------------------------------------------------------------
do $$
declare
  v_noise_b uuid := nullif(current_setting('test.m11perf.noise_b', true), '')::uuid;
begin
  perform pg_temp.m11_purge_marker_events();
  if v_noise_b is not null then
    delete from public.tenants where id = v_noise_b;
  end if;
  delete from public.tenants where slug like 'm11-noise-%';
  analyze public.calendar_events;
  raise notice 'phase_7_m11_performance_passed';
end $$;
