# ai_memory.md - AI Collaboration Memory

> Updated 2026-06-07 (Session: Phase 5 M2 asset identity, serial, scan, timeline complete).

---

## Session 2026-06-07 — Phase 5 M2 (Asset Identity, Serial, Scan, Timeline)

### Delivered

| Area | Files |
|------|-------|
| Migration | [`supabase/migrations/055_phase_5_asset_identity_scan_timeline.sql`](supabase/migrations/055_phase_5_asset_identity_scan_timeline.sql) |
| SQL tests | [`supabase/tests/phase_5_asset_identity.sql`](supabase/tests/phase_5_asset_identity.sql) |
| Scan core | [`lib/core/scanning/`](lib/core/scanning/) — `ScanResult`, `ScanRepository`, `ScanController`, `ScanInput`, `MobileScanSheet` |
| Unit detail | [`lib/features/products/presentation/product_unit_detail_screen.dart`](lib/features/products/presentation/product_unit_detail_screen.dart), timeline controllers/widgets, route `/product-units/:id` |
| SKU wizard | Removed user-editable SKU from product wizard; DB auto-generates via `SKU` document sequence |

### Migration 055 summary

- `SKU` document sequence + auto-generate/immutability triggers on `products`
- `serial_number_mode` enum + tenant settings columns; case-insensitive trimmed barcode unique indexes
- `unit_events` table + RLS; `v_unit_timeline` view
- RPCs: `preview_serialized_stock_reconciliation`, `reconcile_serialized_stock`, `correct_product_unit_serial`, `resolve_scan_code`
- Composite FK hardening on `product_units.current_warehouse_id` / `current_customer_id`

### Verification (this session)

```text
npx supabase db reset                          → 001–055 applied cleanly
phase_5_asset_identity.sql                     → passed (11 cases)
phase_1d_rls.sql                               → passed
phase_3_products_inventory.sql                 → passed
phase_4_customers_suppliers_coa.sql            → passed
phase_4_customer_service_locations.sql         → passed
phase_4_service_location_coordinates.sql       → passed
phase_5_finance_foundation.sql                 → passed (cases 17–18 updated for SKU sequence)
flutter analyze                                → no issues
flutter test                                   → 381 passed
```

### Next session

- **Phase 5 M3+** per [`docs/PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md`](docs/PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md)
- Optional: wire global scan launcher in AppShell (deferred from M2 by design)
- Cloud deploy of migrations 053–055 when Supabase project is linked

---

## Session 2026-06-07 — Phase 5 M1 (Finance Foundation)

### Context

- Started from Phase 4 closure at migration `052`. Local Supabase/Docker operational again (`npx supabase status` green).
- User provided full project audit (Arabic) + professional M1 prompt; Cursor produced an implementation plan reviewed by AntiGravity and ChatGPT before coding.

### Planning outcomes (approved before implementation)

Six architectural decisions locked as **AD-1 … AD-6**:

| ID | Decision |
|----|----------|
| AD-1 | **JE sequences in M1** — system-generated journal entries need `JE-000001` numbering even though manual journal UI is out of MVP |
| AD-2 | **Dual-field idempotency** — `idempotency_key` + `idempotency_payload_hash`; same key + same hash = retry; same key + different hash = `idempotency_payload_mismatch` |
| AD-3 | **`books_locked_through`** — lightweight v1 period lock on `tenant_settings`; full fiscal-period subsystem deferred |
| AD-4 | **Enum isolation** — `journal_source` reversals in separate migration (`053`) because PostgreSQL cannot use new enum values in the same transaction |
| AD-5 | **Auto document sequences** — `AFTER INSERT` trigger on `tenants` + backfill; keys SI/PI/RV/PV/JE (no hard-coded tenant UUIDs; migrations run before seed) |
| AD-6 | **Write-gate must not break RPCs** — dual path: `current_user IN ('postgres','supabase_admin')` OR session `hs360.finance_write=1` via `allow_finance_write()`; never use `session_user` as allow check |

Other plan refinements incorporated:

- Split M1 into **two migrations** (053 enum + 054 foundation); later Phase 5 planned migrations renumbered +1 (M2 asset = `055`, … views = `061`).
- Exact FK drop names documented for composite FK migration.
- SQL tests use existing **DO-block + SET ROLE** style (no pgTAP — not installed).
- Legacy permissions (`invoices.view`, `vouchers.view`, etc.) **kept** until M8 Flutter guard split.

### Files created

| File | Role |
|------|------|
| [`supabase/migrations/053_phase_5_journal_source_enum.sql`](supabase/migrations/053_phase_5_journal_source_enum.sql) | Four `journal_source` reversal enum values only |
| [`supabase/migrations/054_phase_5_finance_foundation.sql`](supabase/migrations/054_phase_5_finance_foundation.sql) | Full M1 schema, sequences, idempotency, RLS/ACL, triggers, RPC stubs |
| [`supabase/tests/phase_5_finance_foundation.sql`](supabase/tests/phase_5_finance_foundation.sql) | 20 verification cases |

### Files updated (docs)

| File | Change |
|------|--------|
| [`docs/PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md`](docs/PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md) | M1 migration split; migration table 053–061; `books_locked_through` lightweight-lock note |

### What `054` implements (summary)

- **`document_sequences`** + `next_document_number()` (internal-only EXECUTE).
- **Invoice/voucher/allocation hardening:** nullable draft numbers, type-aware party checks, amount checks, idempotency columns, composite `(tenant_id, id)` FKs, line snapshot columns.
- **Journal hardening:** reversal links, idempotency, posting validation (≥2 lines, tenant/account alignment), posted-entry/line immutability triggers.
- **`voucher_status`** enum; cancellation/confirmation metadata on vouchers.
- **`resolve_finance_idempotency(regclass, uuid, text)`** — full contract implemented (not stub).
- **17 new permissions** inserted (`ON CONFLICT DO NOTHING`); legacy finance permissions unchanged.
- **RLS:** dropped INSERT/UPDATE/DELETE on finance tables; type-aware invoice SELECT (`view_sales`/`view_purchase` OR legacy `invoices.view`).
- **Write-gate triggers** on invoices, invoice_lines, vouchers, voucher_invoice_allocations.
- **8 RPC stubs** (`save_invoice_draft`, `record_*_invoice`, `cancel_*`, voucher stubs) → `feature_not_implemented`; EXECUTE granted to `authenticated` only.
- **`_test_finance_write_smoke()`** — internal postgres-only helper proving RPC write path (AD-6).

### Verification (this session)

```text
npx supabase db reset                          → 001–054 applied cleanly
phase_1d_rls.sql                               → passed
phase_3_products_inventory.sql                 → passed
phase_4_customers_suppliers_coa.sql            → passed
phase_4_customer_service_locations.sql         → passed
phase_4_service_location_coordinates.sql       → passed
phase_5_finance_foundation.sql                 → passed (20 cases)
flutter analyze                                → no issues
flutter test                                   → 376 passed
```

PowerShell note: pipe SQL tests with `Get-Content -Raw … | docker exec -i supabase_db_hs360 psql …` ( `<` redirection not supported).

### Explicit non-goals (honored)

- No Flutter UI, routes, repositories, or l10n changes.
- No tax columns / `tax_rates` (M4).
- No real posting, WAC, or stock logic in RPC stubs (M5–M7).
- No `books_locked_through` date enforcement in RPCs yet (column + comment only).

### Next session

- **Phase 5 M2:** [`055_phase_5_asset_identity_scan_timeline.sql`](supabase/migrations/055_phase_5_asset_identity_scan_timeline.sql) — SKU/serial generation, scan resolver, unit timeline, serial reconcile/correct permissions.
- Cloud deploy of migrations 053–054 remains a separate ops step when Supabase project is linked.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 complete** - products and inventory (M0-M8).
- **Phase 4 M0-M8 complete** - customers, suppliers, CoA, service locations, coordinates, engineering closure through migration [`052`](supabase/migrations/052_phase_4_closure_hardening.sql).
- **Phase 5 M1 complete** - finance schema hardening via [`053`](supabase/migrations/053_phase_5_journal_source_enum.sql) + [`054`](supabase/migrations/054_phase_5_finance_foundation.sql): document sequences (SI/PI/RV/PV/JE), dual-field idempotency, `books_locked_through`, tenant-safe composite FKs, RPC-only finance writes, journal immutability, 17 new permissions, 8 posting RPC stubs. SQL suite [`phase_5_finance_foundation.sql`](supabase/tests/phase_5_finance_foundation.sql) passes; all Phase 1/3/4 suites still pass; `flutter analyze` clean; 376 Flutter tests green.
- **Phase 5 M2 complete** - asset identity, serial, scan, timeline via [`055`](supabase/migrations/055_phase_5_asset_identity_scan_timeline.sql): SKU auto-generation, barcode uniqueness, unit events/timeline view, scan resolver, reconcile/correct serial RPCs; Flutter scanning core + product unit detail screen at `/product-units/:id`; SKU removed from product wizard. SQL suite [`phase_5_asset_identity.sql`](supabase/tests/phase_5_asset_identity.sql) passes; all prior SQL suites pass; `flutter analyze` clean; 381 Flutter tests green.
- **Next:** Phase 5 M3+ per finance plan.

---

## Phase 5 M1 - Finance Schema, Permissions, and Invariants (done)

- **Migrations:** [`053_phase_5_journal_source_enum.sql`](supabase/migrations/053_phase_5_journal_source_enum.sql) (isolated enum); [`054_phase_5_finance_foundation.sql`](supabase/migrations/054_phase_5_finance_foundation.sql) (foundation).
- **Sequences (AD-1/AD-5):** `document_sequences` with SI/PI/RV/PV/JE; `next_document_number()` internal-only; tenant INSERT trigger + backfill.
- **Idempotency (AD-2):** `idempotency_key` + `idempotency_payload_hash` on invoices, vouchers, journal_entries; `resolve_finance_idempotency()` helper.
- **Period lock (AD-3):** `tenant_settings.books_locked_through` with SQL comment; enforcement deferred to M5–M7 RPCs.
- **Write safety (AD-6):** finance write-gate triggers (postgres owner + `hs360.finance_write` session gate); direct authenticated writes blocked; `_test_finance_write_smoke()` verifies RPC path.
- **RLS:** finance table writes dropped; type-aware invoice SELECT (view_sales/view_purchase + legacy view).
- **RPC stubs:** 8 posting functions raise `feature_not_implemented`; granted to `authenticated` only.
- **Permissions:** 17 new IDs inserted (legacy finance permissions retained).
- **Verification:** `supabase db reset` through 054; all SQL suites including [`phase_5_finance_foundation.sql`](supabase/tests/phase_5_finance_foundation.sql); `flutter analyze` clean; 376 tests green (2026-06-07).

---

## Phase 4 M8 - Verification & Engineering Close (done)

- **Pagination/bounds:** customer and supplier lists and customer statements load in 100-row pages; CoA is capped at 2000 rows and service locations at 500 rows.
- **Responsive UI:** customer, supplier, Customer 360, service-location, and CoA screens have Arabic 360x800 widget coverage. Mobile list actions use compact menus and narrow headers/filters wrap safely.
- **Database hardening:** migration [`052_phase_4_closure_hardening.sql`](supabase/migrations/052_phase_4_closure_hardening.sql) removes API-role execution from internal helpers, grants public Phase 4 RPCs only to `authenticated`, and replaces cross-entity account/parent references with tenant-safe composite FKs.
- **Dependency cleanup:** unused `geolocator` and its generated platform registrations were removed because coordinates now come only from Google Maps links.
- **Automated verification:** `flutter pub get`, localization generation, build runner, `flutter analyze`, 376 Flutter tests, Windows integration test/build, Node map parser tests, and `git diff --check` passed.
- **Database verification:** migration 052 applied successfully; catalog ACL/FK/RLS/audit checks passed; `phase_1d_rls.sql`, `phase_3_products_inventory.sql`, and all three Phase 4 SQL suites passed sequentially.
- **Docker recovery:** prior VHDX corruption blocker resolved; local Supabase stack operational as of 2026-06-07 (Phase 5 M1 reset + full SQL regression passed).
- **File-size review:** the largest Phase 4 presentation files were reviewed. Their size comes from cohesive desktop/mobile renderers or complete form/location workflows; no blocking split was required for M8.
- **Operational follow-ups:** clean reset after Docker recovery, then cloud migration/function deployment after Supabase login and project linking.

---

## Phase 4 M5.7 - Service Location Coordinates Foundation (done)

- **Migrations:** [`050_service_location_coordinates_foundation.sql`](supabase/migrations/050_service_location_coordinates_foundation.sql) adds coordinate metadata and constraints; [`051_google_maps_url_coordinate_resolution.sql`](supabase/migrations/051_google_maps_url_coordinate_resolution.sql) synchronizes resolved URL coordinates with the customer's primary service location.
- **Truth rule:** `latitude`/`longitude` are operational truth, but users enter only a Google Maps link. The app resolves the link before save.
- **Coverage rule:** Google Maps link resolution is available on both the customer's primary location (customer create/edit form) and every additional service location (location add/edit dialog). Each location stores and updates its own link and coordinate pair independently.
- **Flutter/Edge:** full links resolve locally; shortened `maps.app.goo.gl` links resolve through `resolve-google-maps-url`. There are no manual coordinate or device-GPS controls.
- **Tests:** model/payload/validator/widget coverage plus [`phase_4_service_location_coordinates.sql`](supabase/tests/phase_4_service_location_coordinates.sql).
- **Verification:** `flutter analyze` passed, `flutter test` passed (368 tests), Node parser tests passed, `git diff --check` passed, migration `051` applied, and the M5.7 SQL suite passed.
- **Real-link E2E:** `https://maps.app.goo.gl/4bNoy35oFC6UKAPP7` resolved locally through the authenticated Edge Function to `25.7800955, 55.9693682`; invalid host returned `400`, missing JWT returned `401`, and a transaction/rollback save test stored the link and exact coordinates on the primary service location.
- **Primary + additional verification:** the SQL suite verifies that a customer can retain a resolved primary location and a separately resolved additional location; updating the additional location does not alter the primary location.
- **Deployment:** local Edge Runtime is verified. Cloud deployment is pending because Supabase CLI has no access token/project link in this workspace.
- **Android build note:** `assembleDebug` produced the intermediate APK, but the final copy failed when drive `C:` reached zero free bytes. Temporary `build/app` output was removed and about 2.39 GB free space was restored; this was an environment-capacity failure, not a compile error.
- **Deferred by design:** choose-on-map UI.

---

## Phase 4 M7.5 - CoA Hierarchy & Arabic Repair (done)

- **Migration:** [`049_chart_accounts_hierarchy_and_arabic_repair.sql`](supabase/migrations/049_chart_accounts_hierarchy_and_arabic_repair.sql) — fail-fast `duplicate_chart_account_codes`; idempotent `unique (tenant_id, code)`; disable only `trg_enforce_chart_account_protection` (audit/FK stay live); insert roots `1000/2000/3000/4000/5000` (`is_system`); reparent `1101`–`6101`; repair `name_ar` via `U&` escapes.
- **Root cause:** flat tree = seed had no `parent_id`/category roots; Arabic `???` = PowerShell `psql <` encoding when piping UTF-8 migrations (not bad file bytes).
- **Flutter:** category roots auto-expand on first fetch in [`chart_account_list_controller.dart`](lib/features/accounting/presentation/chart_account_list_controller.dart).
- **Tests:** SQL cases 44–47 in [`phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql); Dart tree/protection/screen tests extended.
- **Verification:** `flutter analyze`, `flutter test` (353 tests) green; migration 049 + phase_4 SQL passed on `supabase_db_hs360`; tenant A hierarchy confirmed (`1101`→`1000`, etc.) with correct Arabic in PostgreSQL.

---

## Phase 4 M7 - Chart of Accounts Tree (done)

- **Screen:** [`chart_of_accounts_screen.dart`](lib/features/accounting/presentation/chart_of_accounts_screen.dart) replaces placeholder; route `/accounts` unchanged.
- **DB:** [`048_chart_accounts_m7_hardening.sql`](supabase/migrations/048_chart_accounts_m7_hardening.sql) — RPC rejects immutable payload keys, entity-linked parent on create, `parent_type_mismatch`, `account_has_active_children`; trigger backstop on deactivate with active children.
- **Domain:** `detectAccountingSetupIssues`, `filterAccountsForTree` (ancestors from `allAccounts`), [`chart_account_policy.dart`](lib/features/accounting/domain/chart_account_policy.dart) (`deriveAccountBadges` / `deriveAllowedActions`).
- **Controller:** `ChartAccountListController` — one `fetchChartAccounts`, local filters, `ChartAccountSubmitResult` async dialog contract; screen owns SnackBar on success.
- **UI:** expand/collapse tree, search/type/status filters, setup banner (1201/2101), manual-only create/edit/deactivate; parent dropdown excludes entity-linked accounts.
- **Tests:** SQL cases 40-43 in [`phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql); Dart policy/setup/tree/controller/screen tests.
- **Verification:** `flutter gen-l10n`, `build_runner`, `flutter analyze`, `flutter test` (350 tests) green. SQL `048` verified locally via Docker `psql` against `supabase_db_hs360`; [`phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql) passed.

---

- SKU remains in DB but becomes internal/generated/hidden from normal product UI.
- Product barcode identifies product type; unit serial identifies one physical device; asset QR payload is the serial text.
- Phase 5.0 is **Asset / Barcode / Print Foundation**: product-unit lifecycle, scan resolver everywhere, labels, and JSON print engine.
- Serialized operations must require `product_unit_id` at RPC level.
- Existing stock serial backfill must reconcile units without increasing inventory balances again.
- Document templates use structured JSON; Flutter `pdf`/`printing` renderer first, later server renderer uses the same JSON model.
- Coordinates belong on `customer_service_locations`; the user supplies `google_maps_url`, and the resolved coordinate pair is stored as truth by migrations `050`/`051`.
- Tax Foundation belongs before Phase 5 invoice RPCs, not in M7: use `default_tax_rate_id`, tenant `tax_rates`, explicit product tax classes (`taxable`/`zero_rated`/`exempt`/`non_taxable`), invoice-line tax snapshots, and protected tax posting accounts when implemented.

---

## Phase 4 M5.6 - Customer Service Locations (done)

- **Model:** customer = company/account; `customer_service_locations` = branches/sites (not separate customers).
- **DB:** migration [`047`](supabase/migrations/047_customer_service_locations.sql); `ux_customers(tenant_id,id)`; locations use **composite FK only** to customers; child tables use composite FK to `(tenant_id, customer_id, service_location_id)`; contract snapshot columns added; `product_units.current_service_location_id` is **current pointer only** (not history).
- **RPCs:** `list/create/update/deactivate/set_primary_customer_service_location`; read `customers.view`, write `customers.edit`; internal helpers `generate_service_location_code`, `insert_primary_service_location_from_customer` (no public grant).
- **`create_customer`:** still `returns uuid`; creates primary location in same transaction when address/governorate/area/maps present.
- **Flutter:** domain/repository/controller; Locations tab in customer detail (M5.6); full Customer 360 shell in M6.
- **Tests:** [`phase_4_customer_service_locations.sql`](supabase/tests/phase_4_customer_service_locations.sql); Dart parsing/validator tests; `flutter test` green after M5.6.

---

## Phase 4 M6 - Customer Detail, Statement & Timeline (done)

- **Screen:** [`customer_detail_screen.dart`](lib/features/customers/presentation/customer_detail_screen.dart) replaces placeholder; route `/customers/:id` unchanged.
- **Controllers:** `CustomerDetailController` (`fetchCustomerById` only); `CustomerStatementController` (ledger RPCs; load on first Statement tab select; `load(force: true)` for retry; no auto-load in `build()`).
- **Tabs (7):** Profile (read-only + edit action), Locations (M5.6 unchanged), Contracts/Invoices/Vouchers (permission-aware empty placeholders), Statement (`customers.view_ledger` via `get_customer_balance_summary` + `get_customer_statement`), Timeline (local `createdAt`/`updatedAt`/`acquiredAt` only — no timeline controller/RPC).
- **Permissions helpers:** `canViewCustomerLedger`, `canViewContracts`, `canViewInvoices`, `canViewVouchers` in [`customer_permissions.dart`](lib/features/customers/domain/customer_permissions.dart).
- **Tests:** [`customer_detail_screen_test.dart`](test/features/customers/presentation/customer_detail_screen_test.dart), [`customer_statement_controller_test.dart`](test/features/customers/presentation/customer_statement_controller_test.dart); fakes override `customerServiceLocationRepositoryProvider`.
- **Verification:** `flutter gen-l10n`, `build_runner`, `flutter analyze`, `flutter test` (325 tests) green.

---

## Phase 4 M5.5 - Customer/Supplier Profile Cleanup (done)

- **Migration:** [`supabase/migrations/046_customer_supplier_profile_cleanup.sql`](supabase/migrations/046_customer_supplier_profile_cleanup.sql) — backfill `city`→`governorate`, `address`→`address_line`, drop removed columns, nullable `account_id`, RPC updates, `ensure_customer_account` / `ensure_supplier_account`, hardened immutable triggers, zero-safe statement/balance when no account.
- **Location catalog:** [`lib/core/location/kuwait_locations.dart`](lib/core/location/kuwait_locations.dart) + shared [`kuwait_location_fields.dart`](lib/shared/widgets/kuwait_location_fields.dart).
- **Forms:** responsive sections in [`customer_form.dart`](lib/features/customers/presentation/widgets/customer_form.dart) / [`supplier_form.dart`](lib/features/suppliers/presentation/widgets/supplier_form.dart); wide dialogs (~900-960px); `create_account` on create only; permission-gated ensure-account on edit when `account_id` is null.
- **Filters/lists:** governorate dropdown + area text on customers; operational table columns (no whatsapp/credit/payment); supplier location column.
- **Accounting:** `create_account` default false; company-only fields cleared in RPC for individuals.
- **Tests:** updated fakes/validators/form tests; SQL cases 32-39 in [`supabase/tests/phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql), including customer/supplier default-null accounts, ensure-account, and wrong-link trigger cases.
- **Docs:** `DATABASE_SCHEMA.md`, `PHASE_4_CUSTOMERS_SUPPLIERS_COA_PLAN.md`, `NAVIGATION_AND_MODULES_BRIEF.md`, `PAYMENT_SYSTEM.md`, `CONTRACTS_LOGIC.md`.

---

## Phase 4 M5 - Customers & Suppliers Lists & Forms

- Path helpers on [`app_routes.dart`](lib/core/routing/app_routes.dart): `customerDetailPath`, `customerEditPath`, `supplierDetailPath` (all use `Uri.encodeComponent`); route template constants unchanged.
- Controllers (`@Riverpod(keepAlive: true)`): [`customer_list_controller.dart`](lib/features/customers/presentation/customer_list_controller.dart), [`supplier_list_controller.dart`](lib/features/suppliers/presentation/supplier_list_controller.dart). Default filters are **active-only** (`isActive: true`); `clearFilters()` resets to active-only. Mutations require `canView*` **and** the action permission, return `String?` error code (`null` = success), then `refresh()`. `ensureAccount(id)` links A/R or A/P when permitted.
- Drafts validate before building form state: [`customer_form_draft.dart`](lib/features/customers/presentation/customer_form_draft.dart) (name/phone/email), [`supplier_form_draft.dart`](lib/features/suppliers/presentation/supplier_form_draft.dart) (name_ar, email format).
- Shared form widgets: [`customer_form.dart`](lib/features/customers/presentation/widgets/customer_form.dart), [`supplier_form.dart`](lib/features/suppliers/presentation/widgets/supplier_form.dart). Dialogs and `CustomerEditScreen` embed them.
- Tab bodies: [`customers_tab_body.dart`](lib/features/customers/presentation/customers_tab_body.dart), [`suppliers_tab_body.dart`](lib/features/suppliers/presentation/suppliers_tab_body.dart).
- l10n: M5.5 keys for governorate, Google Maps URL, tax, sections, accounting, location; removed obsolete credit/GPS/whatsapp keys.
- Verification: `flutter gen-l10n`, `build_runner`, `flutter analyze`, `flutter test`.

---

## Phase 4 M4 - Routes, Guards, Navigation & Localization

- Routes: `/customers`, `/customers/:id`, `/customers/:id/edit`, `/suppliers`, `/suppliers/:id`, `/accounts` in [`lib/core/routing/app_routes.dart`](lib/core/routing/app_routes.dart) + [`app_router.dart`](lib/core/routing/app_router.dart).
- Guards: strict path matchers (`isCustomerEditPath`, `isCustomerDetailPath`, `isSupplierDetailPath`) reserve `new`; inline permission checks in [`route_guards.dart`](lib/core/routing/route_guards.dart); `_officePermissionIds` adds `suppliers.view` and `chart_of_accounts.view` only.
- Permission helpers (UI/tests): [`customer_permissions.dart`](lib/features/customers/domain/customer_permissions.dart), [`supplier_permissions.dart`](lib/features/suppliers/domain/supplier_permissions.dart), [`accounting_permissions.dart`](lib/features/accounting/domain/accounting_permissions.dart).
- Presentation placeholders only: `CustomersHubScreen` (Customers/Suppliers tabs with stable Keys, zero-tab fallback), customer detail/edit placeholders, supplier detail placeholder, chart of accounts placeholder - no repository imports.
- AppShell nav: Customers (customers.view or suppliers.view), Chart of Accounts (chart_of_accounts.view).
- l10n: 16 new AR/EN keys including `moduleAccessUnavailable`, professional placeholder copy (no milestone jargon in UI).
- Tests: Phase 4 route guard cases, AppShell nav permission cases, `customers_hub_screen_test.dart`.
- Verification: `flutter gen-l10n`, `flutter analyze` (clean), `flutter test` (278 tests).

---

## Phase 3 M8 - Verification & Close

- Fixed product table scrollbar controller ownership so the desktop `Scrollbar` always attaches to the scroll view it controls.
- Fixed filtered-empty product state: group/filter selection no longer replaces the full products page with a dead-end empty state; user can clear filters.
- Added Arabic display fallback for product, warehouse, and employee names when local seed data contains `?` placeholders from terminal encoding.
- Added warehouse row stock action that opens inventory balances filtered by `warehouseId`; inventory route accepts the query parameter.
- Cleaned local optional M7.5 performance seed rows from the dev database after verification; seed remains optional and should not be present in normal UI unless manually run.
- Verification passed: `flutter pub get`, `flutter pub run build_runner build --delete-conflicting-outputs --verbose`, `flutter analyze`, `flutter test` (220 tests), `flutter test integration_test`, `phase_1d_rls.sql`, `phase_3_products_inventory.sql`, and `git diff --check`.
- `npx --yes supabase db reset` was intentionally not re-run in this pass to avoid wiping local test data; prior reset failure is a Supabase CLI 2.102 internal duplicate service migration before project migrations, not a project migration failure.
- Quality scan: no widget-level Supabase access found, no money/quantity `double` usage found, no critical TODO/FIXME blocker found. Several files are now refactor candidates after Phase 3, but not M8 blockers.
