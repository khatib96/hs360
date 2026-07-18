# HS360 — Multi-Tenant Business Management System

HS360 is a bilingual Flutter/Supabase ERP for fragrance-device rental and sales
businesses. It is being built first for Hayat Secret and is designed around
serialized rental assets, recurring consumables, field service, customer debt,
and double-entry accounting.

> Repository status updated: **2026-07-19**
>
> Current milestone: **Phase 7 M10 CLOSED / ACCEPTED**
> — M7A/M7B closed/accepted; M8 SQL/`101` accepted historically; M8 Flutter
> corrective pass green (`M8 FLUTTER CORRECTED — OWNER RE-ACCEPTANCE PENDING`);
> M9 mobile calendar **CLOSED / ACCEPTED**; M10 Route View + Directions
> **CLOSED / ACCEPTED** (migration `102`, Flutter route UI, directions RPCs)
>
> Latest migrations on disk: **`102`** (route view / directions); `093`–`101`
> unchanged in this work.

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
| 7 | M10 closed / accepted | M1–M7B closed; M8 SQL/`101` + Flutter corrective green; M9 and M10 CLOSED/ACCEPTED; M11/M12 not started |
| 8-12 | Not started | Field execution and later operational/reporting/production phases |

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
`101`; the Flutter live wiring was corrected on 2026-07-18
(**`M8 FLUTTER CORRECTED — OWNER RE-ACCEPTANCE PENDING`**). M9 Mobile Calendar
passed its final corrective, automated, and visual gates and was accepted by
the owner on 2026-07-19 (**`M9 CLOSED / ACCEPTED`**). M10 Route View and
Directions passed its final corrective, automated, and owner visual gates on
2026-07-19 (**`M10 CLOSED / ACCEPTED`**) with migration `102`, a
flutter_map display-only map, and privacy-scoped directions RPCs. See
[PHASE_7_M10_MAP_PROVIDER.md](docs/PHASE_7_M10_MAP_PROVIDER.md). M11/M12 and
Phase 8 have not started.

Detailed roadmap: [BUILD_PLAN.md](docs/BUILD_PLAN.md)

Phase 7 source of truth: [PHASE_7_CALENDAR_PLAN.md](docs/PHASE_7_CALENDAR_PLAN.md)

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

- Remaining Phase 7 work after M7B closure: assignment/reschedule,
  mobile calendar, maps/directions, and Day/Week presentations (M8–M10).
- Phase 8 field execution: GPS proof, live-camera photo, actual consumable
  delivery, coverage confirmation, stock-out, and optional payment collection.
- Offline mobile synchronization. Drift is deliberately not a current
  dependency and is outside v1 unless scope changes.
- External WhatsApp/email/SMS delivery automation. The schema/foundations do not
  mean production messaging is active.
- POS, maintenance operations UI, HR/payroll, advanced reports, communications,
  and production polish from later roadmap phases.

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

Latest M0.5 baseline on 2026-07-12:

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
- Phase 7 M8 SQL/`101` is accepted historically; Flutter corrective is green
  (`M8 FLUTTER CORRECTED — OWNER RE-ACCEPTANCE PENDING`).
- Phase 7 M9 Mobile Calendar is **closed / owner-accepted** after its final
  responsive-layout, assigned-only, FAB-clearance, and visual gates.
- Phase 7 M10 Route View and Directions is **closed / owner-accepted** after
  its final Open-with, RTL navigation, tile-failure, privacy, and visual gates.
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
  header / Phase 7 status for M7B–M9 closed/accepted, M8 Flutter re-acceptance
  pending, and M10 closed/accepted.

---

## Brand

- Working product name: **HS360**.
- Default brand: Hayat Secret gold `#C9A961` with Arabic/English typography.
- Branding is currently present throughout the application and assets; full
  white-label packaging remains a production/deployment task.
