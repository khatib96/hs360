# HS360 — Multi-Tenant Business Management System

HS360 is a bilingual Flutter/Supabase ERP for fragrance-device rental and sales
businesses. It is being built first for Hayat Secret and is designed around
serialized rental assets, recurring consumables, field service, customer debt,
and double-entry accounting.

> Repository status updated: **2026-07-24**
>
> Current milestone: **Phase 7.5 M0 and M0.5 — `CLOSED / ACCEPTED`; M1 `NEXT`**
> after Phase 7
> **`CLOSED / ACCEPTED`**. Phase 7 M12 Gates D/E/F are **`PASS / OWNER ACCEPTED`**,
> Gate G is **PASS**, and Final Gate H is **PASS** through migration `104`.
> Gate F acceptance is based on physical iOS + Android Emulator evidence.
> **Physical Android smoke remains required before production** as an
> owner-approved deferred obligation. Phase 8 has not started.
>
> Latest migrations on disk: **`104`** (M12 route event contract fix);
> `093`–`103` checksum-locked / unchanged.

---

## Current Implementation Status

| Phase | Status | Result |
|-------|--------|--------|
| 0 | Complete | Flutter project, structure, theme, localization foundation |
| 1 | Complete | Local Supabase, schema, functions, views, triggers, RLS, seed |
| 2 | Complete | Authentication, permission-aware routing, Arabic/English locale |
| 3 | Complete | Products, product units, warehouses, balances, movements, transfers |
| 4 | Engineering complete | Customers, suppliers, CoA, service locations, coordinates |
| 5 | Complete | Invoices, returns, vouchers, journal, inventory accounting, PDFs |
| 6 | Complete | Trial/rental contracts, lifecycle, billing, PDF, calendar handoff |
| 7 | Complete / accepted | M1–M12 closed/accepted; bilingual calendar, assignments, mobile calendar, route/directions, integration, performance, device acceptance, and final cleanliness gates passed through migration `104` |
| 7.5 | M0 and M0.5 closed / accepted; M1 next | Option C accepted; regression, SQL/integration, pollution, route/deep-link, screenshot, performance, and migration baselines recorded |
| 8-12 | Not started | Adaptive mobile/requests/field execution and later HR/POS/finance/reporting/production phases |

Phase 6 closed through M13/migration `092` on 2026-07-12. Phase 7 M1 closed on
2026-07-12 (`093`–`094`); M2 event generation engine (`095`) closed on
2026-07-13; M3 reminder foundation (`096`) closed on 2026-07-13 with SQL Phase Q
(82 cases + two concurrency scripts); M4 read RPCs (`097`) closed on
2026-07-13 with SQL Phase R (68 cases). M5 Flutter domain/repository/routes
landed on 2026-07-14, were reopened for a corrective/acceptance pass the same
day, then **closed / accepted**. M6 Desktop Month + Agenda UI landed and passed
automated acceptance, then was reopened for owner visual/UX correction. The
compact search/filter toolbar, filter popover, event action menu, and direct
month/year selectors were subsequently implemented and **accepted by the owner
on 2026-07-15**. M6 is closed. M7A Manual Business Events implementation landed
with migrations `098`/`099` and Flutter create/edit/cancel/done/join flows.
The backend corrective pass, full regression gates, and corrected AR/EN visual
evidence were accepted by the owner on 2026-07-15. **M7A is closed / accepted.**
M7B Working Calendar Holidays & Exceptions is implemented and has completed a
corrective pass covering RPC ACLs, strict validation, unconfigured-schedule
warnings, explicit year windows, tenant-switch race protection, and stable
pagination. The owner accepted the corrected visuals on 2026-07-17, so **M7B
is closed / accepted**. M8 Assignment & Rescheduling landed with migration
`101`; the Flutter live wiring was corrected on 2026-07-18 and owner-accepted
on 2026-07-19 (**`M8 FLUTTER CLOSED / ACCEPTED`**; Gate D
**PASS / OWNER ACCEPTED**). M9 Mobile Calendar
passed its final corrective, automated, and visual gates and was accepted by
the owner on 2026-07-19 (**`M9 CLOSED / ACCEPTED`**). M10 Route View and
Directions passed its final corrective, automated, and owner visual gates on
2026-07-19 (**`M10 CLOSED / ACCEPTED`**) with migration `102`, a
flutter_map display-only map, and privacy-scoped directions RPCs. See
[PHASE_7_M10_MAP_PROVIDER.md](docs/PHASE_7_M10_MAP_PROVIDER.md). M11 Integration,
Performance, and Hardening was accepted by the owner on 2026-07-19 after the
Final Corrective and strict SQL pollution passes (**`M11 CLOSED / ACCEPTED`**).
Its list P95≈1023ms (M11) / ≈1089ms (M12 re-measure) passes the 3000ms hard
ceiling; the 800ms optimization target remains a non-blocking future
improvement. **M12 and Phase 7 are `CLOSED / ACCEPTED`** (Gates D/E/F
**`PASS / OWNER ACCEPTED`**; Gate F used physical iOS + Android Emulator;
Gate G and Final Gate H **PASS** through `104`; Gate C integration via
`scripts/test/p7m12_calendar_acceptance.sh` calendar-only EN+AR; Gate D M8
accepted). Physical Android smoke is still required before production under
the owner-approved deferral. Phase 8 has not started. See
[PHASE_7_M12_ACCEPTANCE_RUNBOOK.md](docs/PHASE_7_M12_ACCEPTANCE_RUNBOOK.md) and
[PHASE_7_M12_EVIDENCE_MANIFEST.md](docs/PHASE_7_M12_EVIDENCE_MANIFEST.md).
See also [PHASE_7_M8_OWNER_REACCEPTANCE.md](docs/PHASE_7_M8_OWNER_REACCEPTANCE.md).

Detailed roadmap: [BUILD_PLAN.md](docs/BUILD_PLAN.md)

Phase 7 source of truth: [PHASE_7_CALENDAR_PLAN.md](docs/PHASE_7_CALENDAR_PLAN.md)

Phase 7.5 source of truth:
[PHASE_7_5_PRODUCT_STRUCTURE_AND_STABILIZATION_PLAN.md](docs/PHASE_7_5_PRODUCT_STRUCTURE_AND_STABILIZATION_PLAN.md)

Canonical module tree:
[NAVIGATION_AND_MODULES_BRIEF.md](docs/NAVIGATION_AND_MODULES_BRIEF.md)

---

## Implemented Capabilities

- Multi-tenant PostgreSQL model with tenant isolation and RLS.
- Manager/full access and explicit per-user permission grants.
- Arabic-first UI with English toggle and RTL/LTR support.
- Products, groups, dual units, serialized assets, barcode/QR resolution, and
  product-unit timeline foundation.
- Warehouses, van-warehouse rules, stock balances, adjustments, transfers, and
  inventory movement history.
- Customers, suppliers, customer service locations, Google Maps coordinate
  resolution foundation, and Customer 360 integrations.
- Chart of accounts, purchase/sales invoices, returns, receipt/payment vouchers,
  allocations, journal entries, tax foundation, and inventory accounting.
- Structured JSON document templates with Arabic/English PDF preview and print.
- Trial and rental contracts with multi-asset/multi-consumable support,
  cost/profit snapshots, lifecycle operations, rental collection, contract PDF,
  and protected calendar-event generation.
- Calendar Settings: per-tenant IANA timezone, seven-day working schedule,
  reminder toggles, permission-gated RPCs, and settings screen/navigation.
- Automated SQL regression/concurrency suites and Flutter unit/widget tests.

## Planned, Not Yet Implemented

- Phase 7.5 accepted M0 direction and planned implementation:
  shared light-theme UI foundation, module-based desktop shell, contextual
  navigation, user profile footer, bounded global search, quick create,
  in-app notification center, four-slot Dashboard v1, Daily Activity,
  consistent record-action UX, basic Audit review, and integrity gate.
- Pre-production physical Android smoke for Gate F. Phase 7 acceptance used
  physical iOS + Android Emulator; this deferred obligation does not reopen
  Phase 7 unless the smoke exposes a defect.
- Phase 8 employee/work-profile link, adaptive mobile, Requests & Approvals
  foundation, field execution, unplanned visits, GPS/photo evidence, actual
  delivery/coverage, stock-out, optional collection, and offline sync.
- Offline mobile synchronization. Drift is deliberately not a current
  dependency and is outside v1 unless scope changes.
- External WhatsApp/email/SMS delivery automation. The schema/foundations do not
  mean production messaging is active.
- Phase 9 POS, maintenance, full employee/passport/residency/employment file,
  HR requests, payroll, advances, and commissions.
- Phase 10 General Ledger/accounting day book/trial balance/P&L/balance sheet,
  close, advanced dashboards/audit review, and Operations Map.
- Communications and production polish from later roadmap phases.

---

## Phase 7 Decisions Already Locked

- Contract-generated and untimed events are date-based. Manual company events
  may optionally have an explicitly entered same-day time window in the
  tenant's confirmed IANA timezone; the system never invents a time.
- Calendar is the shared company appointment-management surface, not only a
  contract follow-up calendar.
- Holidays, company closures, and exceptional working days are working-calendar
  exceptions, not ordinary appointment cards.
- The owner configures all seven working days and an IANA timezone; no weekend,
  hours, or timezone is inferred.
- No working-hours reminder is created before Calendar Settings are reviewed.
- Missed events remain pending/overdue and preserve their original due date.
- A refill cadence keeps one outstanding event. The next refill comes from
  trusted Phase 8 actual completion and confirmed coverage, not the missed
  planned date.
- Calendar Settings permissions are separate:
  - `settings.calendar.view`
  - `settings.calendar.edit`
- Event visibility remains controlled by `calendar.view` and
  `calendar.view_assigned`.

See [PHASE_7_CALENDAR_PLAN.md](docs/PHASE_7_CALENDAR_PLAN.md) for the complete
M0-M12 plan and acceptance gates.

---

## Technology Stack

| Layer | Current choice |
|-------|----------------|
| Application | Flutter / Dart |
| Supported project targets | Windows, macOS, Android, iOS |
| Backend | Supabase / PostgreSQL |
| Local backend | Supabase CLI + Docker |
| State management | Riverpod with generated providers |
| Routing | GoRouter with permission-aware guards |
| Localization | Flutter ARB, Arabic and English |
| Money | Dart `decimal` + PostgreSQL `numeric(15,3)` |
| Documents | `pdf` + `printing`, structured JSON templates |
| Scanning | `mobile_scanner` + shared resolver |
| Media/location foundation | `image_picker`, service-location coordinates |

Production hosting remains a deployment target, not a completed repository
milestone. Current development and verification use the local Supabase stack.

---

## Repository Layout

```text
lib/
  core/          Shared infrastructure: routing, network, documents, scanning
  domain/        Shared business services and validators
  features/      Feature-first data/domain/presentation modules
  shared/        Shared application widgets

supabase/
  migrations/    Ordered PostgreSQL migrations (currently 001-092)
  tests/         SQL regression and concurrency suites
  functions/     Edge Functions
  .temp/         Ignored local credentials and safety artifacts

test/            Dart and Flutter unit/widget tests
integration_test/ Integration and manual acceptance drivers
docs/            Canonical product, architecture, and phase plans
scripts/         Local run, verification, integration, and benchmark scripts
```

---

## Local Development

### Prerequisites

- Flutter SDK compatible with `pubspec.yaml`.
- Docker Desktop.
- Node.js/npm for invoking the Supabase CLI through `npx`.

### Start the local backend

```bash
flutter pub get
npx --yes supabase start
```

For a new/disposable local database only, apply all migrations and seed data:

```bash
npx --yes supabase db reset
```

`db reset` is destructive to the local database. Do not run it against an
environment containing data that must be preserved.

### Run the app

macOS/Linux:

```bash
./scripts/run-local.sh macos
```

Windows PowerShell:

```powershell
.\scripts\run-local.ps1 -Device windows
```

The scripts read local Supabase credentials and cache them under the ignored
`supabase/.temp/` directory. Never commit real keys.

---

## Verification

Core application gates:

```bash
flutter analyze
flutter test
git diff --check
```

Full local SQL regression, concurrency, and pollution gate:

```bash
bash scripts/test/run_sql_suites.sh supabase_db_hs360
```

Latest **Phase 7.5 M0.5** baseline on 2026-07-24:

- Flutter analysis: no issues.
- Complete Flutter suite: **1424 passed**; focused route/shell suite: **96 passed**.
- Full SQL, concurrency, performance, and strict pollution runner: passed.
- Calendar-only live integration: passed on macOS in English and Arabic; all
  fixture cleanup counters returned to zero after each locale.
- Calendar event list P95: **1095.42 ms** for the 5,000-event measured data set;
  other high-use reads remained between **26.12–66.20 ms P95**.
- Root resolver plus all **50** named paths inventoried; 12 durable Phase 5–7
  AR/EN desktop/narrow/mobile screenshots recorded.
- Migration count and applied boundary: **104**; `093`–`104` checksums match the
  accepted Phase 7 Gate H manifest.

Historical **Phase 7 M0.5** baseline on 2026-07-12:

- Full SQL suite: passed.
- Flutter analysis: no issues.
- Flutter tests: **852 passed**.
- Post-test calendar/integrity/pollution checks: clean.
- Migration count: **92**.

---

## Documentation Map

Start with these sources:

| Document | Purpose |
|----------|---------|
| [PROJECT.md](docs/PROJECT.md) | Product vision and business context |
| [CANONICAL_DECISIONS.md](docs/CANONICAL_DECISIONS.md) | Final decisions when older text conflicts |
| [MVP_SCOPE.md](docs/MVP_SCOPE.md) | Accepted v1 boundary |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Application architecture and code organization |
| [DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md) | Database model and migration-era notes |
| [RPC_SPEC.md](docs/RPC_SPEC.md) | RPC contracts and server-side rules |
| [PERMISSIONS.md](docs/PERMISSIONS.md) | Permission catalog and enforcement model |
| [SECURITY.md](docs/SECURITY.md) | RLS, tenant isolation, audit, and sensitive settings |
| [ENGINEERING_QUALITY.md](docs/ENGINEERING_QUALITY.md) | Quality and verification requirements |
| [BUILD_PLAN.md](docs/BUILD_PLAN.md) | Overall phased roadmap |
| [PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md](docs/PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md) | Closed finance execution plan |
| [PHASE_6_CONTRACTS_PLAN.md](docs/PHASE_6_CONTRACTS_PLAN.md) | Closed contracts execution plan |
| [PHASE_7_CALENDAR_PLAN.md](docs/PHASE_7_CALENDAR_PLAN.md) | Current calendar execution plan |
| [PHASE_7_5_PRODUCT_STRUCTURE_AND_STABILIZATION_PLAN.md](docs/PHASE_7_5_PRODUCT_STRUCTURE_AND_STABILIZATION_PLAN.md) | Phase 7.5 M0-M10 execution source of truth |
| [NAVIGATION_AND_MODULES_BRIEF.md](docs/NAVIGATION_AND_MODULES_BRIEF.md) | Canonical module/navigation contract |
| [PRODUCT_UI_VISION.md](docs/PRODUCT_UI_VISION.md) | Owner-approved supporting visual direction for M0 |
| [PROJECT_REVIEW_REPORT_2026-07-24.md](docs/PROJECT_REVIEW_REPORT_2026-07-24.md) | Corrected diagnostic snapshot supporting Phase 7.5 |
| [M0_DESIGN_OPTIONS.md](docs/phase_7_5/m0/M0_DESIGN_OPTIONS.md) | Three comparable Phase 7.5 desktop visual directions and owner decision |
| [M0_ACCEPTANCE_CHECKLIST.md](docs/phase_7_5/m0/M0_ACCEPTANCE_CHECKLIST.md) | Closed Selected-C M0 contract checklist |
| [M0_ROUTE_MODULE_MATRIX.md](docs/phase_7_5/m0/M0_ROUTE_MODULE_MATRIX.md) | Accepted module placement and deterministic back-target contract |
| [M0_PERMISSION_VISIBILITY_MATRIX.md](docs/phase_7_5/m0/M0_PERMISSION_VISIBILITY_MATRIX.md) | Accepted module, tab, command, search, notification, and data visibility contract |
| [M0_ACCEPTANCE_RECORD.md](docs/phase_7_5/m0/M0_ACCEPTANCE_RECORD.md) | Owner acceptance record and M0 evidence index |
| [M0_5_BASELINE_REPORT.md](docs/phase_7_5/m0_5/M0_5_BASELINE_REPORT.md) | Closed Phase 7.5 regression, integration, pollution, performance, and migration baseline |
| [M0_5_ROUTE_BASELINE_AND_ZERO_LOSS_CHECKLIST.md](docs/phase_7_5/m0_5/M0_5_ROUTE_BASELINE_AND_ZERO_LOSS_CHECKLIST.md) | Exact pre-shell route, deep-link, menu, guard, and back-target inventory |
| [M0_5_SCREENSHOT_MANIFEST.md](docs/phase_7_5/m0_5/M0_5_SCREENSHOT_MANIFEST.md) | Durable Phase 5–7 AR/EN desktop and narrow visual baseline |

Feature references include `PRODUCTS_DETAIL.md`, `CONTRACTS_LOGIC.md`,
`PAYMENT_SYSTEM.md`, `CUSTOMER_LEDGER.md`, `FIELD_OPS.md`,
`CURRENCIES_AND_LOCALIZATION.md`, `DESIGN_SYSTEM.md`, and `DEPLOYMENT.md`.

---

## Engineering Rules

Before implementing a milestone:

1. Read `docs/CANONICAL_DECISIONS.md` and the relevant phase plan.
2. Follow `.cursor/rules/engineering-quality.mdc` and
   `docs/ENGINEERING_QUALITY.md`.
3. Keep business writes inside permission-gated, tenant-safe RPCs.
4. Never bypass RLS from Flutter.
5. Never use floating-point values for money.
6. Keep all user-facing strings in ARB localization files.
7. Add `tenant_id`, RLS, ACL, validation, audit, and tests with every new
   business table/workflow.
8. Preserve applied migrations; use forward-fix migrations after data exists.

---

## M1 Verification (2026-07-12)

- `npx supabase db reset` — migrations `093`–`094` applied cleanly.
- `bash scripts/test/run_sql_suites.sh supabase_db_hs360` — all phases passed,
  including Phase O `phase_7_calendar_working_schedule.sql` (67 cases).
- `flutter analyze` — no issues.
- `flutter test` — 888 passed.
- `git diff --check` — clean.

---

## Current Constraints

- Phase 7 M6 Desktop Month + Agenda UI is **closed / owner-accepted**.
- Phase 7 M7A Manual Business Events is **closed / owner-accepted** with
  migrations `098`/`099`, typed Flutter mutations, meeting/participant flows,
  reminder reconciliation, and AR/EN desktop UI.
- Phase 7 M7B Working Calendar Holidays & Exceptions is **closed / owner-accepted**
  with migration `100`.
- Phase 7 M8 Assignment & Rescheduling is **closed / owner-accepted**
  (`M8 FLUTTER CLOSED / ACCEPTED`; Gate D **PASS / OWNER ACCEPTED**).
- Phase 7 M9 Mobile Calendar is **closed / owner-accepted** after its final
  responsive-layout, assigned-only, FAB-clearance, and visual gates.
- Phase 7 M10 Route View and Directions is **closed / owner-accepted** after
  its final Open-with, RTL navigation, tile-failure, privacy, and visual gates.
- Phase 7 M11 Integration, Performance, and Hardening is **closed /
  owner-accepted** after its final functional, visual, performance, full SQL,
  and strict pollution gates. The list-query 800ms optimization target remains
  non-blocking backlog; the enforced 3000ms ceiling passed.
- Production Supabase/VPS deployment and external messaging credentials are not
  configured by this repository state.
- The `resolve-google-maps-url` Edge Function has local verification but still
  requires deployment/linking for a target Supabase project.
- Mobile field execution and offline sync remain future phases.
- Older design documents may preserve historical examples. The canonical
  decisions and active phase plan take precedence.

## M5 Closure Verification (2026-07-14)

- Latest applied migration remains `097` (no SQL change; no `098`).
- `dart format` — clean.
- `flutter analyze` — no issues.
- Focused calendar/routing/nav/exception suites — **253** passed.
- `flutter test` — **1030** passed.
- `git diff --check` — clean.
- M5 **closed / accepted**; M6 was still ahead at that snapshot.

## M6 Closure Verification (2026-07-15)

- Latest applied migration remains `097` (no SQL change; no `098`).
- Final focused calendar suite — **223** passed; screenshot harness — **5**
  passed; routing/AppShell — **93** passed.
- `flutter analyze` — 0 issues; full `flutter test` — **1102** passed;
  `git diff --check` — clean.
- Owner visually accepted the corrected Arabic desktop UI and direct
  month/year navigation on 2026-07-15. **M6 closed / accepted.**

## M7A Closure Verification (2026-07-15)

- Migrations on disk: `098_phase_7_manual_business_event_types.sql`,
  `099_phase_7_manual_business_events.sql` (+ SQL test
  `supabase/tests/phase_7_manual_business_events.sql`).
- Visual corrective pass (icons/Lucide+Material, scheduled-date line, event
  actions vertical stack, destructive cancel, floating-label padding,
  expanded evidence): screenshot harness — **24** passed; paths under
  `build/screenshots/m7a_*.png`.
- Focused calendar + AppShell — **264** passed; routing guards — **71**
  passed; `flutter analyze` — 0 issues; full `flutter test` — **1121**
  passed; `./scripts/test/run_sql_suites.sh` — all phases passed;
  `git diff --check` — clean.
- Calendar lib sources kept under 350 lines after M7A extraction passes.
- Owner visually accepted the corrected 24-image AR/EN, RTL/LTR, desktop/narrow
  evidence on 2026-07-15. Live authenticated screenshots remain a preferred
  pre-release smoke check, not an M7A closure blocker.
- The partially visible last participant row in a supporting harness image is a
  non-blocking polish note, provided the list remains fully scrollable without
  overflow.
- **M7A closed / accepted.**
- Historical note at that snapshot: M7B–M10 were still ahead. See current
  header / Phase 7 status for M7B–M12 and Phase 7 **CLOSED / ACCEPTED**;
  Gate F was accepted using physical iOS + Android Emulator, with physical
  Android smoke still required before production.

---

## Brand

- Working product name: **HS360**.
- Default brand: Hayat Secret gold `#C9A961` with Arabic/English typography.
- Branding is currently present throughout the application and assets; full
  white-label packaging remains a production/deployment task.
