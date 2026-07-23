# Phase 7.5 M0.5 — Regression Baseline and Safety Snapshot

> Decision: **M0.5 CLOSED / ACCEPTED**
>
> Completed: **2026-07-24**
>
> Next milestone: **M1 — Theme Tokens and Shared UI Foundation**

## 1. Baseline Identity

| Item | Recorded value |
|---|---|
| Git branch | `main` |
| Starting commit | `7dd916e43e85231eb7429712c74611999c1ec52f` |
| Flutter | `3.44.2` stable |
| Dart | `3.12.2` |
| Supabase CLI | `2.106.0` |
| Local database | `supabase_db_hs360` |
| Migration files | `104` |
| Applied local boundary | `104` |
| Phase 7.5 migrations | None |

The worktree already contained the accepted M0/planning documentation changes.
M0.5 did not rewrite application behavior or add a migration.

## 2. Automated Regression Baseline

| Gate | Result |
|---|---|
| `flutter analyze` | **PASS**, no issues |
| Complete `flutter test` | **PASS**, 1424 tests |
| Focused route guard + shell permission suite | **PASS**, 96 tests |
| Invoice screenshot harness | **PASS**, 6 cases |
| Contract screenshot harness | **PASS**, 4 cases with the known narrow overflow explicitly recorded |
| Calendar M11 screenshot harness | **PASS**, 11 cases |
| Full SQL runner | **PASS**, all phases |
| P7M12 calendar-only live integration | **PASS**, English + Arabic on macOS |
| Integration cleanup | **PASS**, all ten fixture counters zero after each locale |
| SQL pollution gate | **PASS**, strict pre/post delta zero |
| Dart formatting check | **PASS**, 2 files, 0 changes |
| Git whitespace check | **PASS** |

The macOS integration runner reports that the `printing` plugin does not yet
support Swift Package Manager. This is a future Flutter compatibility warning,
not a current acceptance failure.

## 3. SQL Test Reliability Corrections

Two existing SQL tests depended on the wall-clock date and failed only because
M0.5 ran near a month/working-day boundary:

1. `phase_6_contract_calendar_handoff.sql` used a fixed next-month expectation
   that could fall outside the production 30-day generation horizon. The test
   now derives a valid billing day on or after its start while staying inside
   that horizon.
2. `phase_7_calendar_reminders.sql` could choose a configured day off and mixed
   database UTC `current_date` with the tenant's `Asia/Kuwait` business date.
   The test now chooses a deterministic past Monday and uses the tenant-local
   date for reminder anchors.

Both changes are test-only. Their isolated suites and the final complete SQL
runner passed. No production function, RPC, migration, or business rule was
changed.

## 4. Data-Pollution Snapshot

The successful full SQL run proved strict zero delta across calendar events,
participants, reminder plans/runs/queue, generation journals, manual/schedule
operations, and working-date exceptions.

Two earlier interrupted attempts stopped before their cleanup gate and left:

- one completed generation journal with two cascade-owned tenant rows;
- two reminder-reconcile queue rows for the fixed seed tenants.

They were identified by exact UUID/timestamp and removed as test residue only.
They contained no customer, contract, invoice, voucher, inventory, or calendar
event data. Final local counts are:

| Table/group | Final count |
|---|---:|
| Tenants / tenant users (canonical seed) | `2 / 5` |
| Calendar events | `0` |
| Contracts | `0` |
| Invoices | `0` |
| Vouchers | `0` |
| Inventory documents | `0` |
| Notifications | `0` |
| Reminder reconcile queue | `0` |
| Calendar generation runs / tenant rows | `0 / 0` |

The removed technical rows are reproducible by rerunning their test RPCs; they
were not user records.

## 5. Performance Baseline

The full Phase 7 M11 performance suite seeded 5,000 measured events plus noise
tenants and recorded:

| Read path | Median | P95 | Returned rows |
|---|---:|---:|---:|
| `list_calendar_events` | `1074.81 ms` | `1095.42 ms` | `50` |
| `get_calendar_range_summary` | `65.00 ms` | `66.20 ms` | Summary |
| Selected-day agenda | `25.65 ms` | `26.12 ms` | Agenda |
| `get_calendar_route_day` | `25.31 ms` | `27.03 ms` | Route day |

The list P95 is effectively level with the accepted Phase 7 M12 re-measurement
(about 1089 ms) and remains below the 3000 ms hard gate. The plan's 800 ms
number remains an optimization target, not an M0.5 closure blocker.

## 6. Migration Integrity

- Disk contains migrations `001` through `104`.
- The local database reports the same applied boundary.
- SHA-256 for migrations `093` through `104` matches the accepted Phase 7 Gate
  H manifest exactly.
- The reproducible checksum file is
  `M0_5_MIGRATION_CHECKSUMS.txt`.
- No migration `105` or other Phase 7.5 database change was created.

## 7. Route and Visual Baselines

- The root resolver and all **50** named route paths are inventoried with
  current menu presence, deep-link contract, permission guard, and
  empty-history back behavior in
  `M0_5_ROUTE_BASELINE_AND_ZERO_LOSS_CHECKLIST.md`.
- The current flat shell has **19** permission-filtered rows.
- Twelve durable Phase 5–7 screenshots cover Arabic/English and
  desktop/narrow/mobile layouts. Files, dimensions, provenance, and checksums
  are in `M0_5_SCREENSHOT_MANIFEST.md`.
- Accepted live Phase 7 evidence remains linked rather than duplicated.

## 8. Known Pre-Change Debt

| Debt | Baseline | Owning milestone |
|---|---|---|
| Contract overview overflows in two rows at 390 px in AR and EN | Captured and intentionally asserted by the M0.5 harness | M1/M3 |
| `app_shell.dart` is 603 lines and owns too many concerns | Must be split during the shell rebuild | M2 |
| `route_guards.dart` is 421 lines and `app_router.dart` is 393 lines | Typed route/module metadata should reduce drift without weakening guards | M2 |
| Invoice form controller is 1018 lines | Untouched in M0.5; split only when a scoped milestone changes it | Touched-code pressure rule |
| Calendar event list remains above the 800 ms optimization target | No material regression; hard gate passes | Later measured optimization |

These items are visible baseline debt, not reasons to mix M1/M2/M3
implementation into M0.5.

## 9. Closure Statement

M0.5 now provides a reproducible safety snapshot for application tests, SQL,
integration, pollution, routes/deep links, permissions, screenshots,
performance, and migration integrity. The zero-lost-route checklist is
complete. Phase 7.5 may proceed to M1 without changing the accepted M0 product
contract.
