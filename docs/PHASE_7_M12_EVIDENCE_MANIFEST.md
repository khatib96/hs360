# Phase 7 M12 — Evidence Manifest

> Durable evidence only. Do **not** rely solely on ignored `build/screenshots`.
> Never store Supabase keys in this file or attached logs.

## Status snapshot

| Field | Value |
|-------|-------|
| Plan | Phase 7 M12 Verification and Phase Close |
| Final end-state | `M12 CLOSED / ACCEPTED` |
| M8 Flutter | `M8 FLUTTER CLOSED / ACCEPTED` |
| Gate D | `PASS / OWNER ACCEPTED` (unchanged) |
| Gate E | `PASS / OWNER ACCEPTED` (2026-07-20) |
| Gate F | `PASS / OWNER ACCEPTED — PHYSICAL IOS + ANDROID EMULATOR` (physical Android smoke required before production) |
| Gate G | **PASS** (post-104 P95 ≈1066ms ≤ 3000) |
| Gate H prior (103) | `SUPERSEDED — PRIOR REHEARSAL THROUGH 103` |
| Gate H current | `FINAL PASS THROUGH 104` |
| Phase 7 | **CLOSED / ACCEPTED** |

## Evidence rows

| Evidence ID | Gate / requirement | Locale | RTL/LTR | Viewport / device | Source | Result |
|-------------|-------------------|--------|---------|-------------------|--------|--------|
| `sql-w4-handoff` | Gate B W.4 trusted handoff consume | n/a | n/a | postgres | `phase_7_m12_trusted_handoff_acceptance.sql` | **PASS** |
| `sql-runner-full` | Gate B full suites + concurrency | n/a | n/a | `supabase_db_hs360` | `run_sql_suites.sh` | **PASS** (exit 0) |
| `sql-pollution-b` | Gate B runner baseline null | n/a | n/a | postgres | `to_regclass('_m11_pollution_baseline')` | **PASS** (`t`) |
| `sql-perf` | Gate G list P95 ≤ 3000ms | n/a | n/a | postgres | `phase_7_m11_performance.sql` | **PASS** (≈1089ms) |
| `flutter-format` | Gate C format | n/a | n/a | host | `dart format --output=none --set-exit-if-changed lib test integration_test` | **PASS** |
| `flutter-analyze` | Gate C analyze | n/a | n/a | host | `flutter analyze` | **PASS** (0 issues) |
| `flutter-unit` | Gate C/H full `flutter test` | n/a | n/a | host | unit/widget | **PASS** (final rerun 2026-07-22) |
| `flutter-route-guard` | `/calendar/route` guards | n/a | n/a | host | `route_guards_test.dart` | **PASS** |
| `flutter-back-nav` | Settings dirty PopScope | en | LTR | widget | `calendar_settings_back_nav_test.dart` | **PASS** |
| `p7m12-calendar-only-en` | Gate C contract→calendar UI | en | LTR | macos | `p7m12_calendar_acceptance.sh` (`P7M12_CALENDAR_ONLY=true`) | **PASS** (Flutter exit 0; cleanup counters all 0) |
| `p7m12-calendar-only-ar` | Gate C contract→calendar UI | ar | RTL | macos | same wrapper | **PASS** (Flutter exit 0; cleanup counters all 0) |
| `p6m13-full-path` | Full P6M13 (PDF/finance) — out of M12 bar | en+ar | both | macos | `p6m13_manual_acceptance.sh` | **NOT REQUIRED FOR M12** — EN previously failed at PDF `pumpAndSettle`; do not waive; do not fix PDF in M12 |
| `dart-format-churn` | Gate C format gate | n/a | n/a | host | `dart format` on lib/test | **MECHANICAL ONLY** — ~35 files line-wrap/trailing-comma; no authorized product behavior change |
| `m8-01` | Gate D assign+reschedule actions | en | LTR | desktop | `docs/evidence/phase7_m12/m8/m8_01_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-02` | Gate D candidates + capability warnings | ar | RTL | desktop | `m8_02_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-03` | Gate D unassign when allowed | en | LTR | desktop | `m8_03_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-04` | Gate D reschedule + reason + timed window | en | LTR | desktop | `m8_04_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-05` | Gate D soft conflict warning | ar | RTL | desktop | `m8_05_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-06` | Gate D OCC / stale version | en | LTR | desktop | `m8_06_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-07` | Gate D narrow assignment | ar | RTL | narrow 800×900 | `m8_07_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-08` | Gate D narrow reschedule | en | LTR | narrow 800×900 | `m8_08_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-09` | Gate D meeting action gating | ar | RTL | desktop | `m8_09_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-10` | Gate D cancelled action gating | en | LTR | desktop | `m8_10_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-11` | Gate D assigned-only disappearance | en | LTR | desktop | `m8_11_*.png` | **PASS / OWNER ACCEPTED** |
| `m8-harness-run` | Gate D regenerate packet | n/a | n/a | host | `calendar_m8_screenshots.dart` + `calendar_event_actions_m8_test.dart` | **PASS** (17) |
| `m8-owner-packet` | Gate D owner checklist | en/ar | both | narrow+desktop | `docs/PHASE_7_M8_OWNER_REACCEPTANCE.md` + `docs/evidence/phase7_m12/m8/` | **PASS / OWNER ACCEPTED** — `M8 FLUTTER CLOSED / ACCEPTED` |
| `ge-en-*` / `ge-ar-*` | Gate E live UI (post-104) | en+ar | both | macos live | `gate_e/` | **PASS / OWNER ACCEPTED** |
| `ge-sql-20` | Item 20 route contract | n/a | n/a | SQL+UI | migration 104 + `ge-*-15` | **PASS / OWNER ACCEPTED** |
| `mig-104` | Route event contract fix | n/a | n/a | postgres | `104_phase_7_m12_route_event_contract_fix.sql` | applied (unchanged) |
| `device-ios-openwith` | Gate F | en/ar | — | physical iOS USB | checklist F1–F8 + `gate_f/ios/` | **PASS / OWNER ACCEPTED** |
| `device-android-emulator-openwith` | Gate F | en/ar | — | Android Emulator Google Play | checklist F9–F16 emulator + `gate_f/android_emulator/` | **PASS (emulator)** |
| `gate-f-physical-android-waiver` | Gate F | n/a | n/a | host | `DEVICE_PENDING.txt` | **REQUIRED BEFORE PRODUCTION — OWNER-APPROVED DEFERRAL** |
| `gate-f-packet` | Gate F index/sums/summary | n/a | n/a | host | `EVIDENCE_INDEX.md` / `SHA256SUMS.txt` / `GATE_F_EXECUTION_SUMMARY.md` | **PASS / OWNER ACCEPTED** |
| `gate-f-pending-note` | Gate F | n/a | n/a | host | `gate_f/DEVICE_PENDING.txt` (redacted) | **DEFERRED PHYSICAL-ANDROID OBLIGATION ONLY** |
| `gate-g-perf` | Gate G | n/a | n/a | postgres | `gate_g/perf_ceiling_spotcheck.txt` | **PASS** (≈1066ms) |
| `gate-h-103-superseded` | Prior H | n/a | n/a | host | `H_SUMMARY.txt` / `PRIOR_H_THROUGH_103_SUPERSEDED.txt` | **SUPERSEDED — PRIOR REHEARSAL THROUGH 103** |
| `gate-h-rehearsal` | H pre-close | n/a | n/a | host/postgres | `H_REHEARSAL_SUMMARY.txt` | **SUPERSEDED BY FINAL PASS** |
| `gate-h-final` | H final cleanliness and reset | n/a | n/a | host/postgres | `H_FINAL_SUMMARY.txt` + `h_final_checksums.txt` | **FINAL PASS THROUGH 104** |
| `ge-i21` | Gate E item 21 integrity | n/a | n/a | postgres | `integrity_compare.json` | **EQUAL** |
| `ge-cleanup` | Gate E P7M12 cleanup | n/a | n/a | postgres | `cleanup_counters.txt` | **all 0** |
| `ge-sql-15` | Gate E item 15 overdue | n/a | n/a | UI+SQL | overdue panel + RPC | **READY** |
| `ge-sql-16` | Gate E item 16 | n/a | n/a | SQL | W.4 | **SQL PASS** |
| `ge-sql-18` | Gate E item 18 | n/a | n/a | SQL | reminders | **SQL PASS** |
| `ge-sql-19` | Gate E item 19 Open-with | — | — | device | Gate F packet | **PASS / OWNER ACCEPTED** |
| `runbook-en-*` / `runbook-ar-*` | Gate E 1–21 | en+ar | both | live | runbook | **PASS / OWNER ACCEPTED** |

## Gate H evidence

- Prior through `103`: `PRIOR_H_THROUGH_103_SUPERSEDED.txt` (**SUPERSEDED**)
- Rehearsal through `104`: `H_REHEARSAL_SUMMARY.txt` (**historical pre-close rehearsal**)
- Final Gate H: `H_FINAL_SUMMARY.txt` + `h_final_checksums.txt` (**FINAL PASS THROUGH 104**)
- Physical Android smoke remains required before production under the owner-approved deferral.
