# Phase 7 M12 — Verification Matrix

> Status: **`M12 CLOSED / ACCEPTED`** (2026-07-22).
> Gates D/E/F **`PASS / OWNER ACCEPTED`**; Gate F used physical iOS + Android
> Emulator. Gate G **PASS** and Final Gate H **PASS** through `104`.
> Phase 7 **CLOSED / ACCEPTED**. Physical Android smoke remains required before production.
> Evidence types: SQL | Flutter unit/widget | integration | screenshot | manual | device

## Milestone baseline (Gate 0)

| Item | Value |
|------|-------|
| HEAD baseline | `1fd3844` (M11 tip); working tree has M12 verification + `104` |
| Migrations | `093`–`103` checksum-locked unchanged; **`104`** route contract fix |
| M8 Flutter | `M8 FLUTTER CLOSED / ACCEPTED` |
| M12 / Phase 8 | No Phase 8 product work |

## SQL requirements → evidence

| Requirement | Evidence | Gap | Type |
|-------------|----------|-----|------|
| Working schedule / TZ / settings | `phase_7_calendar_working_schedule.sql` | none | SQL |
| Generation / lifecycle | `phase_7_calendar_event_generation_engine.sql` | none | SQL |
| Trusted Phase 8 handoff consume | `phase_7_m12_trusted_handoff_acceptance.sql` (W.4) | none | SQL |
| Reminders | `phase_7_calendar_reminders.sql` (+ case49 weekday fix) | none | SQL |
| Reads / filters | `phase_7_calendar_read_rpc.sql` | none | SQL |
| Manual events | `phase_7_manual_business_events.sql` | none | SQL |
| Exceptions | `phase_7_working_date_exceptions.sql` | none | SQL |
| Assign / reschedule / OCC | `phase_7_calendar_assignment.sql` | none | SQL |
| Route / directions + Item 20 contract | `phase_7_calendar_route_view.sql` + migration `104` | none | SQL |
| No finance/stock/visit side effects | `phase_7_m11_cross_module.sql` + Gate E integrity | none | SQL |
| Perf ceilings | `phase_7_m11_performance.sql` (P95 ≈1066ms) | none | SQL |
| Runner pollution | H.0 + W.5 + C.7 | none | SQL |
| Final cleanliness | Gate H final | none — final reset/cleanup/checksums passed through `104` | SQL/manual |

## Flutter requirements → evidence

| Requirement | Evidence | Gap | Type |
|-------------|----------|-----|------|
| Mappers / route `execution_summary: null` | `calendar_route_rpc_mapper_test.dart` | closed | Flutter |
| Route UI missing + AR copy | `calendar_route_screen_test.dart` | closed | Flutter |
| Route guards / back-nav | existing M12 tests | closed | Flutter |
| Directions Open-with unit | launcher / open-with tests | device = Gate F | Flutter |
| Contract→calendar UI | `p7m12_calendar_acceptance.sh` EN+AR | closed | integration |

## Integration inventory

| File | Class | Command |
|------|-------|---------|
| `p6m13_manual_acceptance_test.dart` | supporting | `p6m13_manual_acceptance.sh` |
| `p7m12_gate_e_acceptance_test.dart` | Gate E live UI | `p7m12_gate_e_acceptance.sh` |
| calendar-only wrapper | Gate C | `p7m12_calendar_acceptance.sh` |

## Manual / device

| Item | Evidence | Status |
|------|----------|--------|
| 21-item AR/EN runbook | runbook + `gate_e/` | **GATE E PASS / OWNER ACCEPTED** |
| M8 re-acceptance | Gate D | **PASS / OWNER ACCEPTED** |
| Open-with iOS + Android Emulator | Gate F checklist F1–F16 + `gate_f/` | **PASS / OWNER ACCEPTED** (physical Android smoke required before production) |
| Perf ceilings | Gate G | **PASS** (≈1066ms ≤ 3000) |
| Final cleanliness | Gate H | **FINAL PASS THROUGH 104** |
