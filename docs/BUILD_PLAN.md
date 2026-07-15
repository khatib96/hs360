# BUILD_PLAN.md — Phased Implementation Roadmap

> A step-by-step plan to go from empty Supabase project to a running, production-grade ERP.
> Designed for solo development with Cursor AI.

---

## Progress Overview

| Phase | Status | Completed |
|-------|--------|-----------|
| **0 - Project Setup** | Done | 2026-05-16 |
| **1A - Local Supabase Foundation** | Done | 2026-05-16 |
| **1B - Core Business Schema** | Done | 2026-05-16 |
| **1C - Functions, Views, Triggers, RLS** | Done | 2026-05-16 |
| **1D - Seed and Verification** | Done | 2026-05-16 |
| **2 - Authentication & Routing** | Done | not recorded |
| **3 - Products & Inventory** | Done | 2026-05-30 |
| **4 - Customers, Suppliers & CoA** | Engineering complete | 2026-06-06 |
| **5 - Invoices, Vouchers & Journal** | Done | M1–M10 closed through migration `076` |
| **6 - Contracts** | Complete | M0–M13 closed (2026-07-12) |
| **7 - Calendar & Company Appointments** | M7A complete | M1–M7A closed through migrations `098`/`099` (2026-07-15); M7B next |
| **8 - Mobile Field Ops** | Not started | - |
| **9 - POS, Maintenance & HR** | Not started | - |
| **10 - Reports & Close** | Not started | - |
| **11 - Communications** | Not started | - |
| **12 - Polish & Production** | Not started | - |

> Phase 0 details: `docs/PHASE_0_SETUP.md`
> Capability placement: `docs/CAPABILITIES_DECISION_REPORT.md`.
> Phase 5 execution plan: `docs/PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md`.
> Phase 6 execution plan: `docs/PHASE_6_CONTRACTS_PLAN.md`.
> Phase 7 execution plan: `docs/PHASE_7_CALENDAR_PLAN.md`.

---

## How to Use This Document

Each phase has:
- **Goal** — what success looks like
- **Tasks** — concrete steps in dependency order
- **Deliverables** — what should exist at the end
- **Acceptance** — how you know you can move to the next phase

Don't skip ahead. The order matters. Each phase builds on the previous.

---

## Phase 0 — Project Setup (≈ 1 week) ✅ **COMPLETE** (2026-05-16)

### Goal
Have a working Flutter project, a Supabase project, and a basic CI workflow.

> **Local-dev scope applied:** no cloud Supabase, no VPS, no paid services, no Drift/offline in Phase 0. See `docs/PHASE_0_SETUP.md`.

### Tasks
- [x] **1.** Create Flutter project in repo root: `flutter create --org com.hs360 --platforms windows,android .` (docs preserved)
- [x] **2.** Set up project structure per `ARCHITECTURE.md` section 3 (`lib/core`, `data`, `domain`, `features`, `shared`, `supabase/`, tests)
- [x] **3.** Add Phase 0 dependencies to `pubspec.yaml`:
  - [x] `supabase_flutter`, `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`
  - [x] `go_router`, `decimal`, `intl`, `flutter_localizations`
  - [x] `image_picker`, `geolocator`, `mobile_scanner`, `logger`, `lucide_icons`
  - [x] ~~`drift`, `drift_flutter`~~ — **deferred** (offline out of v1)
  - [x] ~~`printing`, `pdf`~~ — **deferred** to later phases
- [x] **3b.** App shell: theme (DESIGN_SYSTEM), GoRouter, ARB l10n (ar/en), dashboard placeholder, Supabase client with local env placeholders
- [ ] **4.** Create Supabase project (cloud) — **deferred**; local CLI + Docker in Phase 1
- [x] **4b.** Scaffold `supabase/migrations/` and `supabase/functions/` (`.gitkeep` only)
- [x] **5.** Local env placeholders in `lib/core/config/env.dart` (not `.env` files yet)
- [x] **6.** Git repo on `main` + remote `https://github.com/khatib96/hs360.git` (pushed)
- [ ] **6b.** Second branch `dev` — **not created yet**
- [ ] **7.** GitHub Actions CI — **deferred**

### Deliverables
- [x] Flutter app opens on Windows with HS360 dashboard (bilingual, RTL/LTR)
- [x] Android platform scaffolded (not fully verified on device/emulator)
- [x] `.cursor/rules/.cursorrules` in place
- [x] `docs/PHASE_0_SETUP.md` runbook
- [ ] Supabase cloud dashboard — **deferred** to Phase 1 (local stack first)

### Acceptance
- [x] `flutter run -d windows` / `flutter build windows` — works
- [ ] `flutter run -d android` on emulator — **not verified** in Phase 0 session
- [x] `flutter analyze` — zero issues
- [x] `flutter test` — passes

---

## Phase 1 — Database Foundations (≈ 2 weeks)

### Goal
Create the local Supabase database foundation in controlled sub-phases: local stack, schema migrations, RLS, seed data, and verification. Phase 1 is database-first; it does not build production UI flows or real authentication screens.

### Canonical Migration Scope
Use `DATABASE_SCHEMA.md` section 21 as the source of truth for migration order:

```
001_extensions.sql
002_tenants.sql
003_enums.sql
004_permissions.sql
005_currencies.sql
006_tenant_settings.sql
007_employees.sql
008_commissions_salaries_advances.sql
009_warehouses.sql
010_chart_of_accounts.sql
011_product_groups.sql
012_products.sql
013_product_units.sql
014_maintenance.sql
015_inventory.sql
016_customers.sql
017_suppliers.sql
018_journal.sql
019_invoices.sql
020_vouchers.sql
021_contracts.sql
022_visits.sql
023_quotations.sql
024_calendar.sql
025_notifications.sql
026_audit_log.sql
027_functions.sql
028_views.sql
029_triggers.sql
030_rls_policies.sql
031_seed.sql
032_late_fks.sql, only if forward-reference FKs cannot be added earlier
```

### Phase 1A — Local Supabase Foundation ✅ **COMPLETE** (2026-05-16)

**Goal:** the project has a working local Supabase stack and the first dependency-safe foundation migrations.

> Runbook: `docs/PHASE_1A_SETUP.md`

**Tasks**
- [x] Install or verify Supabase CLI (`npx supabase` used when not on PATH).
- [x] Run `supabase init` and commit generated local config.
- [x] Run `supabase start` with Docker.
- [x] Capture local `SUPABASE_URL` and `SUPABASE_ANON_KEY` (via `supabase status -o env`; not committed).
- [x] Confirm Flutter can initialize Supabase using `--dart-define` / `scripts/run-local.ps1`.
- [x] Add migrations:
  - [x] `001_extensions.sql`
  - [x] `002_tenants.sql`
  - [x] `003_enums.sql`
  - [x] `004_permissions.sql`
  - [x] `005_currencies.sql`
- [x] Run `supabase db reset`.

**Deliverables**
- `supabase/config.toml`
- `supabase/migrations/001_extensions.sql`
- `supabase/migrations/002_tenants.sql`
- `supabase/migrations/003_enums.sql`
- `supabase/migrations/004_permissions.sql`
- `supabase/migrations/005_currencies.sql`
- Documented local run command for Flutter with Supabase dart defines

**Acceptance**
- `supabase status` returns local API, DB, Studio, and anon key.
- `supabase db reset` succeeds.
- Tables/types/functions from migrations 001–005 exist locally.
- Flutter app starts with the real local anon key and does not use the placeholder key.

### Phase 1B — Core Business Schema ✅ **COMPLETE** (2026-05-16)

**Goal:** create the remaining business tables without RLS policies yet, in dependency order.

**Tasks**
- [x] Add migrations `006`–`026`.
- [x] Add late FKs via `ALTER` in migrations 016, 019, 020, 021, 022 (no `032_late_fks.sql`).
- [x] Run `supabase db reset` — all migrations apply cleanly.

**Deliverables**
- [x] 30 new public tables (35 total with Phase 1A foundation).
- [x] Indexes and constraints from `DATABASE_SCHEMA.md` are present.
- [x] 12 named deferred FK constraints applied inline.

**Acceptance**
- [x] Clean local reset from empty DB.
- [x] No migration ordering errors.
- [x] Schema inspection matches `DATABASE_SCHEMA.md` (35 tables, 26 enums, 0 RLS).

### Phase 1C — Functions, Views, Triggers, and RLS ✅ **COMPLETE** (2026-05-16)

**Goal:** implement the database behavior and tenant isolation layer.

**Tasks**
- [x] Add `027_functions.sql`.
- [x] Add `028_views.sql`, including security-invoker safe views.
- [x] Add `029_triggers.sql`.
- [x] Add `030_rls_policies.sql` from `SECURITY.md`.
- [x] Run `supabase db reset` and confirm verification SQL.

**Deliverables**
- [x] Permission-aware RPC foundation (`get_my_permissions`, helpers).
- [x] Safe views (`products_safe`, `contracts_safe`).
- [x] Audit and safety triggers (narrow WHEN clauses; `user_permissions` grant/revoke).
- [x] RLS enabled on all 35 public tables (~115 policies).

**Acceptance**
- [x] `supabase db reset` succeeds with 027–030 applied.
- [x] RLS enabled count = 35; 115 policies, safe views, helper functions, and triggers present in catalog.
- [x] Behavioral tests (manager vs user vs permissions) — verified in **Phase 1D** after seed.

### Phase 1D — Seed and Verification ✅ **COMPLETE** (2026-05-16)

**Goal:** prove the database works with realistic test data.

**Tasks**
- [x] Add `031_seed.sql`.
- [x] Create one tenant: `Hayat Secret` plus one second tenant for isolation tests.
- [x] Create owner/manager test user plus zero-permission, product-permission, tenant-B, and field-agent users.
- [x] Seed permissions catalog used by RLS policies and field-safe views.
- [x] Seed default KWD currency.
- [x] Seed chart of accounts, warehouses, product groups, sample employees, and products.
- [x] Add SQL verification script for tenant isolation and permission checks.

**Deliverables**
- [x] Working local test tenant.
- [x] Repeatable seed.
- [x] RLS verification script: `supabase/tests/phase_1d_rls.sql`.

**Acceptance**
- [x] `supabase db reset` creates a usable local test tenant.
- [x] A tenant user can query only their tenant's data.
- [x] A user without permission is blocked from restricted tables/actions.
- [x] A user with the required permission can perform the allowed read/write.

---

## Phase 2 — Authentication & Routing (≈ 1 week)

> Runbook: `docs/PHASE_2_AUTH_ROUTING_PLAN.md`

### Goal
Login screen works. After login, user is routed to the right place based on role.

### Tasks
1. Build `core/network/supabase_client.dart` with the client wrapped in a provider
2. Build `core/routing/app_router.dart` with GoRouter and permission-aware redirects
3. Build the auth feature:
   - Login screen (email + password)
   - Forgot password flow
   - Logout
4. Build the JWT hook in Supabase to add `tenant_id` and `role` to claims
5. Build permission-based redirect logic:
   - Manager or office permissions → desktop home
   - users with field permissions → mobile Today screen
6. Build the bilingual scaffold:
   - Initialize `intl` with ar and en
   - Locale toggle in settings (saved in shared_preferences)
   - `Directionality` widget at app root

### Deliverables
- Login screen in Arabic and English
- Successful login routes to role-appropriate screen
- Locale toggle works

### Acceptance
- Manager logs in → sees dashboard placeholder
- Field agent user logs in → sees mobile Today screen placeholder
- Switching locale flips the entire UI to RTL/LTR

---

## Phase 3 — Products & Inventory (≈ 2 weeks)

**Status:** [x] Complete as of 2026-05-30. Closed through Phase 3 M8 verification.

### Goal
Admin can manage products, units, and warehouses. Stock balances are visible.

### Tasks

**3.1 Models & Repositories**
- [x] `Product` model, `ProductGroup` model, `ProductUnit` model
- [x] `ProductRepository`, `ProductGroupRepository`, `ProductUnitRepository`
- [x] All using Riverpod-generated providers

**3.2 Product List Screen (Desktop)**
- [x] Tab bar/group panel: by group
- [x] Search field
- [x] Filter chips: sale/rental modes, stock, active/inactive
- [x] Data table with SKU, Name, Group, Type, Sale Price, permission-gated cost fields, Stock
- [x] Click row -> product detail

**3.3 Product Detail Screen (Desktop)**
- [x] Form with product fields
- [x] Image upload
- [x] Pricing block: sale_price, cost fields, min prices. No product-level rental price; contract monthly value is entered on the contract.
- [x] Cost block (requires cost field permissions): avg_cost, last_purchase_cost
- [x] Stock block: balances per warehouse
- [x] For serialized/rental assets: list of `product_units` with statuses

**3.4 Add Product Wizard**
- [x] Step 1: name + group + sale/rental mode
- [x] Step 2: unit of measure + pricing
- [x] Step 3: rental specifics (if rental type)
- [x] Step 4: serial-tracked? barcode? maintenance-trackable?
- [x] Save -> fires INSERT through repository

**3.5 Product Units Management**
- [x] Add unit: serial number + barcode + initial cost
- [x] Bulk add: paste serial numbers
- [x] Units tab shows current unit records/statuses
- [ ] Contract history per unit - deferred until contracts/rentals phase

**3.6 Warehouses Screen**
- [x] List + add/edit/deactivate warehouse
- [x] For van warehouses, link to an employee
- [x] Open inventory balances filtered by warehouse

**3.7 Inventory Movements Log**
- [x] Filterable table of movements
- [x] Adjustments: manual stock-in / stock-out with reason
- [x] Internal warehouse transfers with paired movements

### Deliverables
- [x] Admin can fully manage products
- [x] Stock balances update correctly
- [x] Field/safe users see `products_safe` view (no costs)

### Acceptance
- [x] Create a product -> it appears in list
- [x] Add product units -> they appear in unit list
- [x] Manual stock-in -> balance increases
- [x] Manual stock-out -> balance decreases
- [x] Transfer between warehouses -> source/destination balances update
- [ ] Sample purchase invoice -> deferred to Phase 5 purchase invoice RPC

---

## Phase 4 — Customers, Suppliers & Chart of Accounts (≈ 1 week)

**Status:** [x] Engineering complete as of 2026-06-06 through M8. A clean database reset is pending Docker Desktop data-disk recovery; cloud migration/Edge Function deployment is pending Supabase login and project linking.

### Goal
Customer and supplier management fully working. CoA visible and customizable.

### Tasks
1. [x] Customer CRUD screens (desktop + mobile)
2. [x] Auto-generate customer code (CUST-0001)
3. [x] Create an A/R subaccount only when requested, with a later ensure-account action
4. [x] Customer service locations: multiple branches/sites/addresses under one customer account
5. [x] Customer detail tabs: Profile | Locations | Contracts | Invoices | Vouchers | Statement
6. [x] Customer 360 Timeline foundation using available local metadata; module events arrive with their later phases
7. [x] Supplier CRUD
8. [x] CoA tree view (requires `chart_of_accounts.view`)
9. [x] CoA: add/edit non-system accounts
10. [x] M8 pagination, responsive/mobile, permission, localization, ACL, FK, and regression hardening

### Deliverables
- [x] Customers and suppliers fully managed
- [x] Multi-site customers modeled through service locations, not duplicate customer records
- [x] Chart of accounts visible and editable
- [x] Customer 360 shell exposes profile, locations, future modules, statement, and available local timeline metadata
- [x] Large lists/statements are paginated or explicitly bounded
- [x] Phase 4 API helper ACLs and cross-tenant account/parent FKs are hardened by migration `052`

### Acceptance
- [x] Create a customer with `create_account = true` → A/R subaccount created atomically
- [x] Add multiple service locations under one customer without changing the customer count
- [x] View customer statement (initially empty) without error
- [x] Customer timeline shows currently available local metadata safely; invoice/payment/contract events are added by their owning phases
- [x] Arabic mobile-width customer, supplier, detail/location, and CoA screens pass widget verification
- [x] Phase 1, Phase 3, and all Phase 4 SQL suites pass on the migrated local database

### Phase 4.7 Location Coordinates Foundation

This is a small add-on before closing Phase 4 or at the start of Phase 5. It supports visits, mobile directions, and later operations maps.

Tasks:
- [x] Store operational coordinates only on `customer_service_locations`, not on `customers`.
- [x] Add `resolution_source` for service-location coordinates (`map_pick`, `device_gps`, `url`, `manual`).
- [x] Add `resolved_at`, `coordinate_accuracy_m`, `resolution_status`, and `resolution_error`.
- [x] Use the pasted Google Maps link as the only coordinate input.
- [x] Resolve full Google Maps URLs locally before save.
- [x] Resolve shortened map URLs through the authenticated `resolve-google-maps-url` Edge Function.
- [ ] Deploy `resolve-google-maps-url` to the target Supabase project after Supabase login/project linking.
- [x] Do not expose manual latitude/longitude or device-GPS controls.
- [x] Apply migration `051` and pass the local M5.7 SQL verification suite.
- [x] Verify a real shortened Google Maps link through the local authenticated Edge Runtime.
- [ ] Add "choose on map" after a map package is selected (deferred enhancement; not a Phase 4 closure blocker).

Acceptance:
- [x] A service location can hold verified `latitude`/`longitude` and the source that produced them.
- [x] Existing customer/account flows keep working without customer-level GPS fields.
- [x] Visit and calendar screens can rely on service-location coordinates later without duplicating address data.

---

## Phase 5 — Invoices, Vouchers & Journal (≈ 10-14 weeks)

**Status:** [x] Complete. M1–M10 are closed for the core Phase 5 accounting
baseline through migration `076` (2026-07-05). Post-Phase 5 polish remains
tracked separately and is not a Phase 5 closure blocker.
The detailed M0-M10 execution plan with inserted M4.5/M7.5 milestones in
`PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md` supersedes the older task ordering
below where they conflict. In particular, quotations and manual journal
posting are outside the strict Phase 5 MVP.

### Goal
Full accounting cycle works. Opening stock → Purchase → Sale → Return →
Receipt/Payment → P&L.

### Tasks

**5.0 Asset / Barcode / Print Foundation**
These foundations must be done before invoice/voucher screens because purchase invoices create serialized assets, labels need printing, and invoices need the same print engine.

- Internal SKU:
  - Keep `products.sku` in the database.
  - Generate SKU automatically in product create/edit flows.
  - Hide SKU from normal product UI; expose only as an internal code if needed for admin diagnostics.
- Serialized asset enforcement:
  - Add tenant serial settings (`serial_number_mode`, `serial_number_prefix`) if still absent.
  - Add serial generation helpers.
  - Ensure future serialized operations fail at RPC level when `product_unit_id` is missing.
  - Confirm current serialized transfer limitation before expanding warehouse-transfer RPCs.
- Asset tracking foundation:
  - Treat `product_units` as the physical asset lifecycle record, not only a serial-number table.
  - Track lifecycle from purchase/creation -> available -> rented/trial -> maintenance -> returned/lost/damaged/retired.
  - Keep current pointers (`current_warehouse_id`, `current_customer_id`, `current_service_location_id`, `current_contract_id`) in sync through RPCs.
  - Add a lightweight `unit_events` table only for manual/events-without-source records.
  - Add `v_unit_timeline` as the canonical timeline view from purchase, inventory movements, contracts, visits, maintenance, audit log, and `unit_events`.
  - If `last_event_at` is added for sorting/performance, maintain it from the same RPC/event writes; do not use it as the timeline source.
- Generate missing serials:
  - Manager-only audited reconcile tool.
  - It compares existing on-hand quantity to existing `product_units`.
  - It creates missing units for existing stock without increasing `inventory_balances` again.
  - Do not reuse `create_product_units` directly for this backfill unless it has a no-stock-delta mode.
- Barcode/QR resolve:
  - Implement a single scan resolver: unit barcode -> product barcode -> unit serial.
  - Support desktop scanner input and mobile camera through the same domain service.
  - QR payload for asset tags is the human-readable serial text.
- Barcode search everywhere:
  - The scan resolver is global app infrastructure, not a POS-only helper.
  - Pattern: scan -> resolve object -> open or apply object in the current screen context.
  - Support product search, unit lookup, contract device picking, visit detail, maintenance intake, inventory count, return/replacement, and POS later.
  - Unknown scan shows a clear not-found state and optional create/link action only where the current screen supports it.
- Document template foundation:
  - Add `document_templates` with structured JSON body.
  - Add `tenant_document_settings` for logo, colors, header/footer, language, paper size, and optional columns.
  - Add/seed template permissions such as `settings.templates.edit`, label print permission, and `product_units.correct_serial`.
  - Add Flutter `pdf`/`printing` dependencies and a client-side renderer for A4, thermal 80mm, and asset labels.
  - Use the same JSON model later for server-generated archived/auto-sent PDFs.
- Initial templates:
  - Sales invoice A4.
  - Receipt voucher thermal/A4.
  - Asset tag label sheet/batch.
- Unit timeline:
  - Build `v_unit_timeline` from source events where possible.
  - Keep `unit_events` only for notes/manual events that have no natural source table.
  - Show the initial timeline in unit detail during 5.0, even if later phases add richer contract/visit/maintenance events.

Acceptance:
- Existing serialized stock can be reconciled into physical units without stock double-counting.
- Scanning a product barcode resolves to the product; scanning a unit QR/serial resolves to the unit.
- The same scan resolver can be called from product, contract, visit, maintenance, inventory, return/replacement, and POS flows.
- Unit detail shows a lifecycle/timeline surface backed by `v_unit_timeline`.
- A4 invoice, receipt voucher, and asset tag can render client-side in Arabic and English from JSON templates.
- Serial correction is permission-gated, requires a reason, and is audited.

**5.0A Tax Foundation (Invoice Foundation prerequisite)**
This is a small invoice-math foundation, not a tax filing module. It must be implemented before `record_sales_invoice` and `record_purchase_invoice`.

- Add tenant tax settings:
  - `tax_enabled`.
  - `tax_registration_number`.
  - `default_tax_rate_id` linked to `tax_rates` rather than a raw numeric default.
- Add tenant-scoped `tax_rates`:
  - code and Arabic/English names.
  - decimal rate.
  - `effective_from` / optional `effective_to`.
  - `output_account_id`, `input_account_id`, optional `expense_account_id`.
  - `is_recoverable`, `is_active`.
- Add product tax classification:
  - `taxable`.
  - `zero_rated`.
  - `exempt`.
  - `non_taxable`.
  - Do not model this as `taxable boolean`.
- Add invoice-line tax snapshots:
  - `tax_rate_id`.
  - numeric `tax_rate`.
  - `tax_class`.
  - `taxable_amount`.
  - `tax_amount`.
  - before-tax and after-tax line totals.
- Seed or provision protected tax posting accounts when tax is enabled:
  - Input VAT Recoverable / recoverable input tax.
  - Output VAT Payable / output tax liability.
  - Optional tax expense account for non-recoverable taxes.
- Keep Kuwait/default v1 tenants tax-disabled by default, with tax amounts equal to zero.
- Exclude VAT returns, government APIs, e-invoicing integrations, and country-specific filing from this foundation.

Acceptance:
- Invoice totals can be computed as subtotal, discount, tax amount, and grand total even when tax is disabled.
- Historical invoices keep their saved tax snapshots after tax rates change.
- Sales invoice posting can credit output tax separately from revenue.
- Purchase invoice posting can debit recoverable input tax or tax expense according to the tax-rate settings.

**5.0B Inventory Accounting & Opening Stock Foundation**

**Status:** Complete (migrations `065`–`070`, 2026-06-17). Backend and Flutter
repository/UI were verified before Phase 5 close.

Delivered:
- Financial inventory documents: opening stock, stock-in, stock-out, stock count.
- Controlled adjustment reasons mapped to allowed posting accounts (opening equity,
  owner capital/drawings, inventory gain, loss, internal consumption).
- Journal-backed `record_inventory_adjustment` compatibility wrapper.
- All-owned-buckets WAC for inventory documents; warehouse transfers non-financial.
- Serialized stock-in/out via M4.5 RPCs; cancel idempotency and safe-cancel guards
  (`069`–`070`).

Acceptance (verified):
- Opening stock posts Dr Inventory / Cr Opening Balance Equity.
- Stock count differences create only required movements and one balanced journal.
- Inventory movements and the inventory GL account cannot diverge through the app.
- Transfers never create income, expense, capital, or inventory-value changes.

While M5 was in flight (before M4.5 landed), purchase WAC correctly stayed on
the Phase 3 `qty_available` basis. M4.5 (`065`–`070`) now provides journal-backed
inventory documents without altering purchase WAC behavior.

**5.1 Stored Functions**
Implement all RPCs per `DATABASE_SCHEMA.md` section 19:
- `record_purchase_invoice`
- `record_sales_invoice`
- `record_sales_return`
- `record_purchase_return`
- `recalculate_wac` (called by the above)
- Each must create the journal entries
- `record_purchase_invoice` must create `product_units` for serialized purchase lines in the same transaction as balances, WAC, and journal entries.
- Returns are numbered documents linked to original invoice lines. They use
  original tax/cost snapshots and are not cancellation aliases.

**5.2 Invoice Screens (Desktop)**
- Invoices list (filterable by type, status, customer)
- New sales invoice form
- New purchase invoice form
- Invoice detail with lines, payment history, journal entry view
- Confirm / cancel actions
- PDF preview & generate

**5.3 Voucher Screens (Desktop)**
- Vouchers list
- New receipt voucher (with invoice allocation UI)
- New payment voucher
- Voucher detail
- Receipt PDF & generate

**5.4 Quotations (deferred)**
- Quotations and quotation conversion are outside the strict v1 scope.
- Keep the existing Phase 1 tables dormant until a later post-MVP phase.

**5.5 Cash & Bank Reconciliation View**
- Per cash account: list of vouchers in date range
- Running balance

**5.6 Customer Statement**
- Date range filter
- Opening balance + transactions + closing balance
- Export as PDF

### Deliverables
- A full opening stock → purchase → sale → return → payment cycle works
- Financial inventory adjustments and stock counts work
- Journal entries auto-generated and balanced
- PDFs printable

### Acceptance
- Record a purchase of 100 oil units → balance + WAC update
- Record a sale → A/R increases, inventory decreases
- Record partial sales/purchase returns → original snapshots and credits reverse correctly
- Record mixed stock count → inventory gain/loss journal balances
- Record a receipt voucher → A/R clears
- Print invoice PDF in Arabic and English

---

## Phase 6 — Contracts (the Big One) (≈ 4 weeks)

> Detailed execution plan: `docs/PHASE_6_CONTRACTS_PLAN.md`.
> The detailed Phase 6 plan supersedes the short task list below if there is a
> conflict, especially around trial periods, configurable pricing basis,
> multi-asset/multi-consumable contracts, and Phase 8 visit boundaries.

### Goal
The core of the system: contracts can be created, billed, refilled, and closed.

### Tasks

**6.1 Stored Functions**
- `create_rental_contract` (atomic, per `CONTRACTS_LOGIC.md` section 7)
- `close_contract`
- `contract_profitability`
- Require `service_location_id` and snapshot selected location/contact/address fields at contract creation
- Require `product_unit_id` for every serialized asset line; product-only contract lines are invalid when `products.is_serialized = true`

**6.2 Contracts List Screen (Desktop)**
- Filter chips per `CONTRACTS_LOGIC.md` section 11.1
- Search by contract #, customer, phone

**6.3 New Contract Form (Desktop)**
- Multi-step wizard per `CONTRACTS_LOGIC.md` section 11.2
- Customer step must select a service location: auto-select the only active location, require choice for multiple, or inline-create when none exist
- Device step must select or scan a specific serial/unit for serialized assets
- Live profitability preview (requires `contracts.field.snapshot_profit`)
- Min-profit enforcement

**6.4 Contract Detail Screen (Desktop)**
- Tabs per `CONTRACTS_LOGIC.md` section 11.3
- Close contract button (requires `contracts.close`)
- Switch oil button (requires `contracts.oil_change`)

**6.5 Oil Switching**
- UI to change `contract_oil_changes`
- Effective date picker

**6.6 Monthly Billing Job**
- Edge Function scheduled daily
- For each tenant: identify contracts billing today, generate invoices

**6.7 Trial Workflow**
- Trial expiry calendar event (auto-generated)
- "Convert to rental" button
- "Mark as returned" button

### Deliverables
- Contracts can be created, viewed, modified, closed
- Monthly invoices generate on schedule
- Trial periods handled properly

### Acceptance
- Create a contract with profit just above min → saves
- Create a contract for a multi-location customer -> requires service-location selection and snapshots the chosen site
- Create with profit below min → rejected (or override flow if user has `contracts.approve_override`)
- Wait for billing day → invoice appears (or trigger manually for test)
- Close a contract → device returns to inventory

---

## Phase 7 — Calendar & Company Appointment Management

> Detailed execution plan: `docs/PHASE_7_CALENDAR_PLAN.md`. Its M0-M12
> milestone order, M7A/M7B split, and owner-locked hybrid scheduling semantics
> supersede older high-level ordering where they conflict. The former two-week
> estimate is a legacy roadmap estimate; use the detailed plan for professional
> delivery sizing.
>
> Current status: **M1–M7A closed / accepted.** M7B Working Calendar Holidays
> & Exceptions is next; migration `100` has not been created.

### Goal
A unified company appointment-management calendar showing contract-generated
due items, customer visits, internal meetings, tasks/reminders, activities, and
the selected day's agenda. Generated and untimed events remain day-based;
manual events may optionally have an explicitly entered same-day time window in
the tenant's confirmed IANA timezone.

### Tasks
1. Harden the existing `calendar_events` table, RLS, and Phase 6 M12 provenance
2. Add per-weekday working-day/hour settings, including day off, limited hours,
   and 24-hour modes; all seven rows and IANA timezone are owner-configured,
   with no inferred defaults
3. Maintain contract-generated events idempotently; billing may materialize its
   horizon, while each refill cadence keeps one outstanding due event until
   trusted actual completion and confirmed coverage establish the next date
4. Add date/working-day reminder foundations without fabricating event times
5. Calendar screen (desktop): upper calendar + lower selected-day agenda, with
   Day / Week / Month presentation as accepted in the detailed plan
6. Calendar screen (mobile): the same hybrid model, touch-optimized
7. M7A company manual events: customer visits, internal meetings,
   tasks/reminders, activities/training, custom items, optional same-day time,
   and participants distinct from assignment
8. M7B working-date exceptions: official holidays, company closures, and
   exceptional working days
9. Audited date rescheduling; optional desktop drag-and-drop uses the same RPC
10. Agent assignment / reassignment
11. Route View: map of a user's selected-day events by service location and
    area, display-only in v1 planning
12. Filters
13. Native "Directions" action opens the selected service location in the phone's map app via `url_launcher`

### Deliverables
- Calendar shows real upcoming events
- Calendar supports company-wide manual appointments without changing
  generated-event provenance
- Timed manual appointments and date-only tasks/due items remain visibly
  distinct; month cells show counts, not clock times
- Holidays/closures override the weekly work calendar without becoming fake
  event cards
- Reminders fire on schedule
- Agents see their assignments
- Daily route map helps the office review workload geographically

### Acceptance
- Active contracts produce calendar events for next 30 days
- Calendar events carry `service_location_id` when generated from contracts
- Selecting a date shows that day's agenda and configured working window
- Day-off, limited-hours, and 24-hour weekdays resolve independently
- Reminder creation uses the event date and tenant working-day anchors, not an
  invented time for generated/date-only events
- No working-hours reminder is created until the manager configures all seven
  weekdays and selects an IANA timezone
- A missed refill stays pending/overdue with its original due date and does not
  generate the next refill until Phase 8 confirms execution and coverage
- A day's visits can be viewed on a map without route optimization

---

## Phase 8 — Mobile Field Operations (≈ 4 weeks)

### Goal
Field agents can do their full daily workflow on the mobile app, online and offline.

### Tasks

**8.1 Mobile Shell**
- Bottom nav (5 tabs)
- Today screen (default home)
- Calendar screen (mobile version)
- Customers screen with service locations
- Van Stock screen
- More screen

**8.2 Refill Flow**
- Visit detail → Begin Visit → Refill form → Complete
- Per `FIELD_OPS.md` section 4
- Photo via camera only
- GPS check-in
- Visit detail uses the selected service location for address, map, and GPS verification
- GPS mismatch uses configurable radius + proceed-with-reason; flagged visits feed Suspicious Visits Report

**8.3 New Contract on Mobile**
- Multi-step flow optimized for phone
- Barcode scan for device picking
- Serialized device picking must resolve to one `product_unit_id`
- Signature capture

**8.4 Collection Flow**
- Visit type = collection
- Quick-allocate to invoices
- Auto-send receipt

**8.5 Van Stock**
- Current balances view
- Request refill
- End-of-day reconciliation

**8.6 Offline Mode**
- Drift schema for local cache
- Sync engine
- Idempotent RPCs (use `client_id`)
- "Pending sync" badges

**8.7 EXIF Validation Edge Function**
- Triggered on photo upload
- Reads EXIF
- Flags visits with mismatched timestamps

**8.8 Visit Risk Flags**
- Store GPS mismatch, missing EXIF, stale photo timestamp, and manual proceed reasons
- Feed these flags into the Phase 10 Suspicious Visits Report

### Deliverables
- Field agent does full day's work on mobile
- Offline visits sync when online
- Photos verified via EXIF
- Visit risk flags are stored consistently for reporting

### Acceptance
- Complete 5 refills offline → all sync correctly when online
- Take a 3-day-old photo → visit flagged in Manager report
- GPS 1km from service location or contract snapshot → visit flagged

---

## Phase 9 — POS, Maintenance & HR (≈ 3 weeks)

### Goal
Add-on modules that round out the system.

### Tasks

**9.1 POS Screen**
- Walk-in sale
- Barcode scan
- Cart
- Payment selection
- Print receipt

**9.2 Maintenance Module**
- Maintenance records list
- Add maintenance from field visit
- Status workflow: reported → in_progress → completed / unrepairable
- Per-unit maintenance history

**9.3 HR**
- Employee CRUD
- Commission rules per role/employee
- Monthly salary generation
- Advances tracking & auto-deduction
- Salary voucher creation

### Deliverables
- POS works for cash sales
- Maintenance workflow tracks device repairs
- Salaries generate monthly

### Acceptance
- Sell a perfume at POS → inventory drops, cash receipt generated
- Mark a device as broken → unit status changes, maintenance record created
- Generate January salaries → vouchers created

---

## Phase 10 — Reports, Dashboards & Financial Close (≈ 3-4 weeks)

### Goal
All key reports work. Managers can answer business questions in under a minute.

### Tasks
1. P&L report (date range)
2. Debt aging report
3. Contract profitability report (uses snapshots)
4. Agent performance report
5. Inventory valuation report
6. Trial expiry watch
7. Sales summary (by product, by customer, by period)
8. Owner dashboard (key KPIs at a glance)
9. Contract Health Score: combines profit, overdue balance, missed visits, GPS/photo flags, and renewal risk
10. Debt Priority List: ranks customers by overdue amount, age, last payment, and active contract value
11. Suspicious Visits Report: GPS mismatch, stale/missing EXIF, unusual timing, repeated manual proceed reasons
12. Price Review Assistant: identifies contracts near/below target profit when current oil/device costs change
13. Renewal / Increase Suggestions: flags old contracts that may need price review before renewal
14. Audit Review Dashboard: sensitive changes, overrides, cancellations, permission changes
15. Data Quality Warnings: missing GPS, products without cost, contracts without refill day, duplicate phone numbers
16. Operations Map: reusable map widget with typed layers and clustering, starting with service locations/today's visits and later rented assets
17. Document Template Editor: visual/settings-based editor on top of the Phase 5 JSON template model
18. Trial Balance: opening, period debits/credits, and closing balance by account
19. Inventory-to-GL Reconciliation: compare inventory valuation with account `1301`
20. Fiscal Period & Year-End Close:
   - `fiscal_years` and `accounting_periods` with open/closed state
   - close preflight for balanced journals, unposted documents, and inventory/GL reconciliation
   - period close that blocks posting/cancellation through the closed date
   - audited reopen with dedicated permission and required reason
   - idempotent year-end closing entry that zeros income/expense into retained earnings
   - carry forward all balance-sheet accounts without resetting inventory, cash, A/R, A/P, or equity

### Deliverables
- All reports per `PROJECT.md` 3.1 working
- Each exportable to PDF and CSV
- Smart operational dashboards are available to Managers
- Trial balance and inventory/GL reconciliation support a controlled annual close
- Fiscal years can be closed and reopened only through audited workflows

### Acceptance
- Generate P&L for last month in <30 seconds
- Trial balance is balanced and agrees with journal lines
- Inventory valuation agrees with the inventory GL before close
- Year-end close transfers net income to retained earnings exactly once
- Closing a year does not zero inventory or any other balance-sheet account
- "Is contract X profitable?" answerable in <5 clicks
- Contract Health Score identifies at-risk contracts without manual spreadsheet work
- Debt Priority List gives a ranked collection queue
- Suspicious Visits Report shows all flagged visits with supporting evidence
- Operations Map can show clustered service-location/rented-asset points without duplicating map logic per report

---

## Phase 11 — Communications (≈ 2 weeks)

### Goal
Automated email + WhatsApp working.

### Tasks
1. Resend integration (Edge Function)
2. Meta WhatsApp Cloud API integration (Edge Function)
3. Notification templates per event:
   - Contract created
   - Refill receipt
   - Payment received
   - Debt reminder
   - Refill reminder to customer
4. Template editor in settings (requires `settings.templates.edit`)
5. Notification queue worker
6. Customer notification preferences (opt-in/out per channel)

### Deliverables
- Send a receipt → customer gets it via WhatsApp and email
- Refill reminder fires 1 day before scheduled visit

### Acceptance
- Test customer receives all template types
- Failed sends retry up to 3 times then mark `failed`

---

## Phase 12 — Polish, Testing & Production (≈ 3 weeks)

### Goal
Production-ready system.

### Tasks
1. End-to-end tests for critical flows:
   - Create customer + contract + first refill + payment
   - Purchase → WAC update → sale → profit recognized
2. Migrate live data from existing Google Sheets (one-time script)
3. Production Supabase setup (Pro tier)
4. Signed installer builds:
   - Windows MSIX
   - macOS DMG (notarized)
5. Mobile builds:
   - Android (Play Console internal track)
   - iOS (TestFlight)
6. Sentry integration for production error tracking
7. Documentation for the owner (admin manual)
8. User training (the team)
9. Soft launch with parallel running (Sheets + new system) for 1 month
10. Cutover

### Deliverables
- Production system live
- All 115 contracts migrated
- Team trained
- Sheets retired

### Acceptance
- One full month with zero data entry in Sheets
- No data loss
- No critical bugs in 30 days

---

## Phase 13+ — Future Work

These are out of v1 scope but worth noting for the roadmap:

- **Multi-tenant onboarding UI** — admin tool to provision new tenants without DB scripts
- **Tenant subscription billing** — bill tenants for SaaS usage
- **Customer portal** — let customers view their own contracts, balances, request refills
- **Advanced analytics** — forecasting, trend analysis, customer churn prediction
- **Mobile for Manager account type** — full Manager features on phone (currently desktop-only)
- **Multi-branch support** — within a single tenant
- **Multi-currency** — for tenants in other GCC countries
- **API for third-party integrations**

### Explicitly Not Planned

- **Van Stock Alerts** — automatic low-stock alerts before visits are not needed for this business workflow.

---

## Estimated Timeline (Solo, with AI Assistance)

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 0 — Setup ✅ | 1 wk | 1 wk |
| 1 — DB | 2 wk | 3 wk |
| 2 — Auth | 1 wk | 4 wk |
| 3 — Products | 2 wk | 6 wk |
| 4 — Customers | 1 wk | 7 wk |
| 5 — Invoices & Vouchers | 10-14 wk | 17-21 wk |
| 6 — Contracts | 4 wk | 21-25 wk |
| 7 — Calendar & Company Appointments | 6-10 wk | 27-35 wk |
| 8 — Mobile | 4 wk | 31-39 wk |
| 9 — POS + Maint + HR | 3 wk | 34-42 wk |
| 10 — Reports & Close | 3-4 wk | 37-46 wk |
| 11 — Comms | 2 wk | 39-48 wk |
| 12 — Polish & Launch | 3 wk | **42-51 wk** |

**Total: ~42-51 weeks (~10-12 months)** of focused work. The Phase 7 range now
includes the owner-approved company appointment-management expansion; delivery
can be faster if non-essential later-phase features are deferred.

---

## What to Build First (MVP — 12 weeks)

If you want a minimal working version fast, cut to:
- Phase 0, 1, 2 (setup + DB + auth)
- Phase 3, 4 (products + customers)
- Phase 6 (contracts — partial: no oil switching, no trial workflow)
- Phase 8 partial (mobile: just refills, no offline, no advanced flows)
- Manual invoicing instead of automated

That gives you the basics in ~12 weeks. Iterate from there.
