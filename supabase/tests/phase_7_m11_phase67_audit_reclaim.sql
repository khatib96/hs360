\set ON_ERROR_STOP on

-- Phase 7 M11: reclaim append-only RPC audit journals created during Phase 6/7
-- after the H.0 pollution baseline.
--
-- Why (not a blanket count exception):
--   calendar_generation_runs / calendar_generation_run_tenants /
--   calendar_reminder_runs are immutable run ledgers written by generation and
--   reminder RPCs. Suites cannot avoid creating them, and leaving them would
--   force either informational deltas (hides unmarked leaks) or growing
--   expected-delta exceptions. Reclaiming rows with started_at >= baseline
--   restores those three tables to the H.0 counts so the pollution gate can
--   enforce strict equality on all 11 tables.
--
-- Durable business tables (events, participants, plans, reconcile queue, ops,
-- working-date exceptions) are intentionally untouched — any leftover there
-- must fail the gate.

do $$
declare
  v_since timestamptz;
  v_gen int;
  v_rem int;
begin
  if to_regclass('public._m11_pollution_baseline') is null then
    raise exception 'm11_phase67_audit_reclaim: missing baseline table';
  end if;

  select min(captured_at) into v_since from public._m11_pollution_baseline;
  if v_since is null then
    raise exception 'm11_phase67_audit_reclaim: baseline has no captured_at';
  end if;

  delete from public.calendar_generation_runs
  where started_at >= v_since;
  get diagnostics v_gen = row_count;

  delete from public.calendar_reminder_runs
  where started_at >= v_since;
  get diagnostics v_rem = row_count;

  raise notice
    'm11_phase67_audit_reclaimed since=% generation_runs=% reminder_runs=%',
    v_since, v_gen, v_rem;
end $$;
