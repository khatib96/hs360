# HS360 — Multi-Tenant Business Management System

HS360 is a bilingual Flutter/Supabase ERP for fragrance-device rental and sales
businesses. It is being built first for Hayat Secret and is designed around
serialized rental assets, recurring consumables, field service, customer debt,
and double-entry accounting.

> Repository status updated: **2026-07-13**
>
> Current milestone: **Phase 7 M4 closed; next M5 — Flutter domain, repository, routes, and navigation**
>
> Latest applied migration: **`097_phase_7_calendar_read_rpc.sql`**

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
| 7 | M4 closed | Working schedule (`093`–`094`), generation (`095`), reminders (`096`), read RPCs (`097`) — full SQL A→R + Phase R 68 cases pass |
| 8-12 | Not started | Field execution and later operational/reporting/production phases |

Phase 6 closed through M13/migration `092` on 2026-07-12. Phase 7 M1 closed on
2026-07-12 (`093`–`094`); M2 event generation engine (`095`) closed on
2026-07-13; M3 reminder foundation (`096`) closed on 2026-07-13 with SQL Phase Q
(82 cases + two concurrency scripts); M4 read RPCs (`097`) closed on
2026-07-13 with SQL Phase R (68 cases). Next: Flutter domain/repository (M5).

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

- Phase 7 main Calendar UI, date-based reminders, manual events,
  assignment/rescheduling, mobile calendar, and route view.
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

- Calendar appointments are date-based, not exact-time appointments.
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

- Phase 7 M4 (calendar read RPCs) is complete via migration `097`. M5 Flutter
  domain/repository is next.
- Production Supabase/VPS deployment and external messaging credentials are not
  configured by this repository state.
- The `resolve-google-maps-url` Edge Function has local verification but still
  requires deployment/linking for a target Supabase project.
- Mobile field execution and offline sync remain future phases.
- Older design documents may preserve historical examples. The canonical
  decisions and active phase plan take precedence.

## M2/M3/M4 Verification (2026-07-13)

- `npx supabase db reset --no-seed` — clean through migration `097`.
- Complete SQL suite — all phases passed, including Phase P (16 cases) and its
  parallel batch-lock script, Phase Q (82 cases + two reminder concurrency
  scripts), and Phase R (58 calendar read RPC cases).
- `flutter analyze` — no issues.
- `flutter test` — 888 passed.
- `git diff --check` — clean.

---

## Brand

- Working product name: **HS360**.
- Default brand: Hayat Secret gold `#C9A961` with Arabic/English typography.
- Branding is currently present throughout the application and assets; full
  white-label packaging remains a production/deployment task.
