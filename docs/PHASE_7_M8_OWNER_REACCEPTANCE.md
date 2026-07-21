# Phase 7 Gate D — M8 Flutter Owner Re-Acceptance

> **Status:** `M8 FLUTTER CLOSED / ACCEPTED`
> **Gate D:** `PASS / OWNER ACCEPTED` (2026-07-19)
>
> Owner explicitly accepted evidence `m8-01`…`m8-11`.
> Source: approved supporting harness
> `test/screenshots/calendar_m8_screenshots.dart` (production calendar widgets +
> FakeCalendarRepository). Durable PNGs:
> `docs/evidence/phase7_m12/m8/`. Checksums: `SHA256SUMS.txt`.
>
> Regenerated: **2026-07-19**. Focused harness + M8 actions tests: **17 passed**.

## What was reviewed

Supporting (not live-session) renders of the **same production widgets** used in
the app: event actions, assignment dialog, reschedule dialog, soft-conflict
confirm, stale-version snackbar, meeting/cancelled gating, assigned-only
disappearance, AR/EN + RTL/LTR, desktop and narrow viewports.

## Checklist (owner) — ACCEPTED

| # | Topic | Evidence ID | Locale / layout | Expected | Owner |
|---|-------|-------------|-----------------|----------|-------|
| 1 | Assign + Reschedule on compatible event | `m8-01` | EN LTR desktop | Both actions visible | ☑ |
| 2 | Compatible candidates + capability warnings | `m8-02` | AR RTL desktop | Candidates list; warning for no-calendar employee | ☑ |
| 3 | Unassign when allowed | `m8-03` | EN LTR desktop | Unassign selected; current (unavailable) option shown | ☑ |
| 4 | Reschedule + mandatory reason; timed window | `m8-04` | EN LTR desktop | Date change, reason filled, time window visible | ☑ |
| 5 | Soft conflict warning | `m8-05` | AR RTL desktop | Conflict confirm dialog before override | ☑ |
| 6 | Optimistic concurrency / stale version | `m8-06` | EN LTR desktop | Stale-version snackbar; no silent overwrite | ☑ |
| 7 | Narrow / mobile-ish assignment | `m8-07` | AR RTL narrow (800×900) | Dialog readable; no overflow | ☑ |
| 8 | Narrow / mobile-ish reschedule | `m8-08` | EN LTR narrow (800×900) | Dialog readable; no overflow | ☑ |
| 9 | Meeting action gating | `m8-09` | AR RTL desktop | Assign hidden; Reschedule shown | ☑ |
| 10 | Cancelled action gating | `m8-10` | EN LTR desktop | Assign + Reschedule both hidden | ☑ |
| 11 | Manager vs assigned-only (disappearance) | `m8-11` | EN LTR desktop | After reassignment out of view: snackbar + empty agenda + 0 events | ☑ |

## Frame index

| Evidence ID | File |
|-------------|------|
| `m8-01` | `docs/evidence/phase7_m12/m8/m8_01_event_actions_assign_reschedule_en_ltr.png` |
| `m8-02` | `docs/evidence/phase7_m12/m8/m8_02_assignment_dialog_warnings_ar_rtl.png` |
| `m8-03` | `docs/evidence/phase7_m12/m8/m8_03_assignment_unassign_selected_en_ltr.png` |
| `m8-04` | `docs/evidence/phase7_m12/m8/m8_04_reschedule_dialog_timed_en_ltr.png` |
| `m8-05` | `docs/evidence/phase7_m12/m8/m8_05_reschedule_conflict_confirm_ar_rtl.png` |
| `m8-06` | `docs/evidence/phase7_m12/m8/m8_06_reschedule_stale_error_en_ltr.png` |
| `m8-07` | `docs/evidence/phase7_m12/m8/m8_07_assignment_dialog_narrow_ar_rtl.png` |
| `m8-08` | `docs/evidence/phase7_m12/m8/m8_08_reschedule_dialog_narrow_en_ltr.png` |
| `m8-09` | `docs/evidence/phase7_m12/m8/m8_09_meeting_actions_no_assign_ar_rtl.png` |
| `m8-10` | `docs/evidence/phase7_m12/m8/m8_10_cancelled_actions_no_mutations_en_ltr.png` |
| `m8-11` | `docs/evidence/phase7_m12/m8/m8_11_assigned_only_disappearance_en_ltr.png` |

## Owner decision (recorded)

- **Accept M8 Flutter** — recorded **2026-07-19**.
- Status: **`M8 FLUTTER CLOSED / ACCEPTED`**
- Gate D: **`PASS / OWNER ACCEPTED`**

Subsequent final state (2026-07-22): M12 and Phase 7 are **`CLOSED / ACCEPTED`**.
Gates D/E/F are **`PASS / OWNER ACCEPTED`**, Gate G **PASS**, and Final Gate H
**PASS** through `104`. Physical Android smoke remains required before production.
