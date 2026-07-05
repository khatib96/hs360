# ai_memory.md - AI Collaboration Memory

> Updated 2026-07-05 (Session: Phase 6 M0/M0.5 — **contract decisions and rollback baseline recorded**).

---

## Session 2026-07-05 - Phase 6 M0/M0.5 Contracts Baseline

**Decision:** Phase 6 starts from the closed Phase 5 baseline at migration
`076_phase_5_voucher_protected_account_guard.sql`; the first Phase 6 migration
is expected to be `077_phase_6_contract_settings_permissions.sql`.

### Locked contract decisions

- Contract types are exactly two: `عقد تجريبي` and `عقد إيجار`.
- `عقد` is only the generic module/document word, not a third type.
- A 12-month term is a rental-contract duration, not a separate database type.
- Trial contracts are in Phase 6/v1 scope.
- Rental asset cost basis is configurable; default owner preference is selected
  unit purchase cost when available.
- Rental consumable basis is configurable; default owner preference is product
  sale price.
- Accounting depreciation and deep asset-consumption adjustments are deferred
  beyond Phase 6. Device usage must come from real activity when implemented,
  not elapsed idle time.
- Phase 6 prepares schedule/visit handoff data; consumable replacement
  confirmation, stock-out, payment collection, GPS/photo proof, and receipt
  creation stay in Phase 8 unless scope changes.

### M0.5 safety notes

- Migration list captured locally in ignored file
  `supabase/.temp/phase_6_m0_5_migrations.txt` (76 migrations).
- Rollback notes captured locally in ignored file
  `supabase/.temp/phase_6_m0_5_rollback_notes.txt`.
- Schema dump was not captured from this Codex session because Docker API
  access was denied. Before the first Phase 6 migration is applied in a running
  local environment, create the schema-only dump under `supabase/.temp/`.
- Rollback before applying `077`: no DB rollback needed.
- Rollback after a failed `077` before real data: fix migration and run local
  reset.
- Rollback after real data exists: do not edit old migrations; add a
  forward-fix migration or restore a local/dev backup only.

---

## Session 2026-07-05 - Phase 5 M10 Closure

**Decision:** Phase 5 is closed for the production-safe accounting-cycle baseline. M10 verification passed for SQL regression, Dart analysis, Flutter unit tests, and the local Supabase seeded-template integration gate. Remaining integration exceptions are platform/runner constraints, not Phase 5 finance defects.

### Delivered

- Added migration `076_phase_5_voucher_protected_account_guard.sql`.
- The migration preserves the M9 voucher source-account generalization while rejecting direct voucher postings against protected accounts: cash/bank as direct payment destinations, AR/AP control accounts, inventory, tax-reserved accounts, inactive/entity-linked accounts, and same source/counter-account postings.
- This closes the M7 voucher regression discovered during M10: direct payment to the inventory control account was accepted after migration `075`.

### Verification

- `dart analyze .` passed with **No issues found**.
- `flutter test` passed with **702 tests**.
- `bash scripts/test/run_sql_suites.sh` passed with **All SQL suite phases passed** after Docker was started and migration `076` was applied.
- `integration_test/documents/supabase_seeded_templates_test.dart -d macos` passed after providing `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- `git diff --check` passed clean.

### Documented integration exceptions

- `integration_test/documents/pdf_golden_test.dart` is intentionally Windows/Android-scoped in code (`golden tests: windows or android only`), so macOS failure is not a Phase 5 blocker.
- `integration_test/documents/statement_perf_test.dart` is a benchmark handshake test. It must be driven through `test_driver/benchmark_driver.dart` / the Windows/Android benchmark wrapper, not directly through `flutter test` on macOS.
- macOS `Failed to foreground app; open returned 1` warnings did not block the seeded-template integration test after configuration.

### Post-Phase 5 backlog

- Payment-voucher print template support.
- Cash-bank PDF/report polish.
- Supplier statement RPC/UI.
- Serialized opening/count enablement beyond the current safe backend/UI guard.
- Mobile finance redesign.
- Advanced edit/delete/cancel-policy UX for posted finance documents.

**Next:** Start Phase 6 contracts on top of the closed Phase 5 accounting baseline.

---

## Session 2026-07-01 - Phase 5 M9 Closure Audit

**Decision:** Phase 5 M9 is closed for the agreed **desktop operational finance UI/workflow** scope. The remaining items are intentionally deferred and must not be treated as blockers for M9: mobile redesign, voucher/report/PDF visual polish, advanced edit/delete/delete-permission flows for confirmed invoices/vouchers/journal entries, payment-voucher print, supplier statement RPC, cash-bank PDF, and serialized opening/count.

### Final M9 closure scope

- Inventory financial documents UI, invoice UI, voucher UI, journal UI, cash/bank UI, print/preview wiring, Customer 360 tabs, supplier detail, product/unit links, and cash-bank CSV are delivered.
- Invoice UX was reopened and corrected after live visual review: Odoo-style desktop structure, cash-sale workflow, direct returns, blank-line-safe confirm, negative-stock-friendly sales path, clearer errors, and searchable payment/counter account handling where supported by the current backend.
- Voucher UX was simplified after live review: receipt/payment forms now use the accounting-sheet pattern with source account + amount + destination/counter account + description, searchable account fields by code/name, direct account receipts/payments, default source account preference (`1101` then `1102`), decimal entry tolerance, and cancellation reason validation.
- Database support added for the M9 closure fixes via migrations `071`-`075` and `scripts/apply_m9_invoice_db_update.sh`.

### Verification performed in Codex

- `dart analyze .` passed with **no issues found** after replacing deprecated `DropdownButtonFormField.value` usages and the redundant separator placeholder.
- `dart format --set-exit-if-changed` on the recently touched files reported **0 changed**.
- `git diff --check` passed clean.
- `bash -n scripts/apply_m9_invoice_db_update.sh` passed.
- Full `flutter test` could not run inside Codex because Flutter tried to write to `/opt/homebrew/share/flutter/bin/cache/*`, which is outside the writable workspace. Run it from a normal Terminal before pushing.
- Applying the DB script from Codex was previously blocked by local database socket/network permissions; run `bash scripts/apply_m9_invoice_db_update.sh` from a normal Terminal if the DB was not already updated.

### Post-M9 backlog

- Advanced edit/delete/cancel-policy UX with permissions for confirmed invoices, vouchers, and journal entries.
- Mobile-first redesign after the desktop finance workflows are accepted.
- Voucher/report/PDF visual polish and payment-voucher print template support.
- Supplier statement RPC/UI, cash-bank PDF, serialized opening/count when backend tests exist.
- Broader app navigation/information architecture cleanup before mobile design.

**Next:** move to post-M9 hardening/backlog or M10, not another M9 scope expansion.

---

## Session 2026-06-18 - Phase 5 M9 Invoice Workflow Fix Round

**Historical status at that time:** M9 was still open for visual/workflow acceptance. Superseded by the 2026-07-01 closure audit.

### Delivered now

- **Cash-sale customer workflow:** `+ عميل جديد` quick-create beside sales invoice customer picker (`CustomerQuickCreateDialog` — Arabic name + primary phone only, uses existing `create_customer` RPC). Created customer is selected in-form without leaving the invoice. Backend still requires a customer on confirm — not faked optional.
- **Payment terms (cash):** No cash/bank selector — `record_sales_invoice` / `record_purchase_invoice` payloads have no payment/account field, so immediate posting is **not** supported. UI shows type-specific helper: sales → receipt voucher after confirm; purchase → payment voucher after confirm. Does not pretend money was posted.
- **Keyboard workflow:** Enter on last-line discount (or product cell when product selected) calls `addLineAndFocusProduct`; focus moves to new line product cell (`invoice-line-product-{index}` keys). Regression tests in `invoice_line_keyboard_test.dart`.
- **Return invoices UX:** `+ إضافة` menu enables sales/purchase return when permitted; opens `InvoiceOriginalInvoicePickerDialog` to search/select confirmed/partially-paid/paid originals, then navigates to existing `/invoices/:id/return`. Purchase return uses same route (screen infers type from original). No standalone return creation.

### Documented future (not implemented — needs backend/settings)

- **Default walk-in / cash customer** (`عميل نقدي`) auto-selected for cash sales (tenant setting + backend default customer).
- **Immediate invoice payment posting** on confirm: cash/bank account selector wired to RPC payload + receipt/payment voucher creation atomically with invoice.
- **Invoice grid customization:** barcode scan/search, show/hide optional columns, tax amount column, Al-Manara-style extra accounting columns, configurable field layout.

### Tests

- `invoice_line_keyboard_test.dart` (controller + widget). Run `flutter analyze`, `flutter test`, `git diff --check`.

---

## Session 2026-06-18 - Phase 5 M9 Invoice UX Fix Round (errors, number, payment terms)

**Historical status at that time:** M9 was still open for visual acceptance. Superseded by the 2026-07-01 closure audit.

### Delivered

- **Actionable confirm errors.** Root cause: `financeErrorMessage` mapped only a handful of codes, so every invoice **validation** code (`finance_validation_*`) and a few backend tokens fell through to the generic `financeErrorUnknown` ("حدث خطأ مالي. يرجى المحاولة مرة أخرى."). Now every known `FinanceException` code (party/warehouse/account/qty/price/discount/due-date/lines/serial/cash-account/return codes + `return_document_required`, `serialized_adjustment_not_supported`) maps to a specific translated reason. `FinanceException.fromSupabase` now also recognizes `return_document_required` and `serialized_adjustment_not_supported`. Truly unknown errors now render `financeErrorUnknownWithCode` with a sanitized, length-capped, whitespace-collapsed diagnostic reference from `technicalDetail` (`financeDiagnosticReference`). Invoice form/return submit catches store `errorDetail` (= `e.technicalDetail` or `e.toString()`).
- **Invoice number visible.** Form command bar subtitle = `invoiceFormNumberAuto` ("رقم الفاتورة: تلقائي بعد التأكيد"). Detail command bar already shows real `detail.invoiceNumber` as the title.
- **Payment terms (UI-only).** `InvoicePaymentTerms { cash, credit }` (domain enum, NOT in any payload). `InvoicePaymentTermsSection` segmented control: cash → helper "سيتم تسجيل الدفع لاحقًا من السندات." (no faked posting — record RPC payload has no payment field); credit → existing due-date field labeled "تاريخ الاستحقاق". `setPaymentTerms` clears due date on cash so an optional due date is never silently posted for an immediate sale. Due-date field moved out of `InvoiceFormHeader` into this section.

### Future scope (NOT implemented — needs backend/model work)

- **Payments on invoice:** cash/bank payment method recorded at confirm time; one or multiple installments; per-installment due dates; notifications/reminders for business and customer. Requires RPC/schema work — must NOT be faked in UI.
- **Configurable invoice fields/columns:** show/hide optional fields; tax amount/value column display; barcode field + barcode search when product has a barcode; additional accounting columns inspired by Al-Manara-style grids (barcode/code, product, description, unit, qty, unit price, discount, tax, line total). Build only when scoped; do not ship a generic field-customization engine prematurely.

### Tests

- New `test/features/finance_shared/finance_error_messages_test.dart` (known codes ≠ generic; unknown+detail uses ref code). Run `flutter analyze`, `flutter test`, `git diff --check`.

---

## Session 2026-06-17 - Phase 5 M9 Final Closure

**M9 UI scope complete. Backend/template gaps moved to M10.**

### Delivered

- **Customer 360:** invoice tab (`canViewSalesInvoices`, `partyId`, lazy load index 3); voucher tab (receipt only, `voucher_party_scope`, index 4); statement unchanged (index 5).
- **Supplier detail:** `SupplierDetailScreen` — profile, purchase invoices (`canViewPurchaseInvoices`), payment vouchers (scoped via `voucher_party_scope`); statement placeholder (no `get_supplier_statement`).
- **Product/unit integration:** unit table → detail; timeline invoice links when `metadata.invoice_type`; invoice line serial + unit link only when `productUnitId` set.
- **Cash-bank CSV:** export **loaded rows** to clipboard (labeled EN/AR); no PDF/DocumentPreview.
- **Serialized opening/count:** blocked safely + single message; stock-in/out serialized regression green.

### Blocked safely + documented (not implemented)

- Payment voucher print/preview (M3 template gap).
- Serialized opening/count UI (M10 when SQL/tests exist).
- Supplier statement (no `get_supplier_statement` RPC).
- Cash-bank PDF (M10 template gap).
- Inventory movement timeline deep links without `reference_id`.

### Tests

- **672** Flutter tests green; `flutter analyze` clean (info deprecations only); `git diff --check` clean.

**Next:** M10 — backend/template gaps (payment voucher print, supplier statement RPC, cash-bank PDF, serialized opening/count).

---

## Session 2026-06-17 - Phase 5 M9 Batch 3 Print & Preview Complete

Invoice and receipt-voucher PDF preview/print from detail screens via existing
`DocumentPreviewScreen` (no new SQL, no payment-voucher renderer).

### Delivery

- Payload mappers from `InvoiceDetail` / `VoucherDetail` (`invoice_document_payload_mapper`, `voucher_document_payload_mapper`).
- `finance_document_payload_loader.dart` — sole bridge from document preview to invoice/voucher repos.
- Preview buttons on invoice/voucher detail (`invoices.print` / `vouchers.print`; posted/confirmed only).
- `canPreviewDocument` requires print for sales/purchase/receipt (manager superuser bypasses print; customer statement/asset label unchanged).
- Invoice preview **requires** `invoiceType` query param — loader rejects missing/mismatched type (`unsupported_document_type`); no multi-type probe.
- `documentPreview` route guard kind-aware; query param `invoiceType` only (not `type`).
- Payment voucher: no preview button; `paymentVoucher` remains unsupported in M3 SQL/renderer.

### Tests

- **665** Flutter tests green. **M9 not declared complete** — Customer 360 tabs, supplier detail, product integration, serialized opening/count, cash-bank export, payment-voucher print remain deferred.

**Next:** M9 deferred items per `PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md` or M10 when scoped.

---

## Session 2026-06-17 - Phase 5 M9 Batch 2 Remainder Complete

Operational vouchers, journal (read-only), and cash/bank activity UI in M9 Batch 2 remainder.

### Prereq

- `JournalSource` enum aligned with SQL (M4.5 inventory + M1 reversals); labels + mapper tests.
- `journal_source_navigation.dart` — source links with SQL `source_id` semantics.
- `cash_bank_posting_accounts.dart` — cash/bank list only via `chart_of_accounts.view`; else placeholder (no dedicated RPC).
- CashBank `limit+1` pagination.

### Flutter delivery (2D + 2E + 2F)

- **Vouchers:** list/detail; receipt/payment forms with FIFO/manual allocations, party search, cash account picker.
- **Journal:** read-only list/detail; source + reversal entry links.
- **Cash/Bank:** account picker, date range, opening/running balance from RPC, activity links.
- Placeholders removed for vouchers, journal, cash-bank routes.

### Tests

- Journal mapper/navigation, cash bank controller, cash posting accounts; voucher controllers unchanged green.
- **641** Flutter tests green. **M9 not declared complete** — Batch 3 print/preview pending.

**Next:** M9 Batch 3 — invoice/voucher print/preview.

---

## Session 2026-06-17 - Phase 5 M9 Batch 2 Invoices UI Complete

Operational invoices UI in `lib/features/invoices/presentation/` wired to M8 RPCs
(no new SQL). Voucher/journal/cash-bank UI remains deferred.

### Flutter delivery (2A + 2B + 2C)

- **List + detail:** type-aware server status chips, date range, overdue badge,
  party/journal links, cancel/return CTAs; purchase draft edit/confirm via
  `/invoices/new/purchase?draftId=`; no print (Batch 3).
- **Forms:** sales/purchase create, line editor, party/product search, safe draft
  build, estimate totals with disclaimer when tax rates unavailable.
- **Return:** posted-original eligibility, returnable lines, estimated credit preview.
- **l10n:** invoice form/filter/detail keys EN+AR; parity test passes.
- **Placeholders removed** for all five invoice routes.

### Tests

- Display helpers, list/detail/form controllers, form mapper; fake repo extended.
- **611** Flutter tests green (Batch 1 inventory tests unchanged).

### Verification

- `flutter analyze` — info only.
- `git diff --check` — clean.

**Next:** M9 Batch 3 — invoice/voucher print/preview (invoices + vouchers/journal/cash-bank slices closed within Batch 2).

**Batch 2 fix (post-review):** purchase form route/guard split (`create_purchase` vs `?draftId=` + `edit_draft`); confirm gated on create (+ edit when editing draft); invoice list keeps filters visible on empty filtered results.

---

## Session 2026-06-17 - Phase 5 M9 Batch 1 Inventory Accounting UI Complete

Delivered the first M9 slice: operational inventory financial documents UI wired
to M4.5 RPCs (`065`–`070`). Invoices, vouchers, journal, cash/bank, and party
financial tabs remain deferred (M9 Batch 2).

### Flutter delivery

- **Data:** `inventory_document_repository.dart`, `inventory_document_rpc_mapper.dart` — all 7 RPCs; pagination via limit+1 (no total).
- **Domain:** filters, movements, detail/lines/reasons extended; `StockCountDraft` with required gain/loss reason codes.
- **Controllers:** list (refresh/loadMore), form (4 modes + idempotency), detail (cancel rules).
- **UI:** list (responsive table/cards, filters, permission-gated create), unified form (opening/stock-in/out/count), immutable detail with journal links and cancel.
- **Permissions:** `inventory_documents.view/create_opening/create_adjustment/create_stock_count/cancel` in guards and `finance_permissions.dart`.
- **Validators:** required `notes`; opening stock without reason; stock count gain+loss always; serialized blocked in opening/count; stock-in WAC fallback when `avg_cost <= 0`.
- **l10n:** «مستندات المخزون المالية»; finance validation/error keys; link from inventory screen.
- **Placeholders removed** for inventory accounting screens.

### Key UI decisions (Batch 1)

- Opening stock: no reason picker or `reason_code` in payload.
- Serialized: full stock-in/out; explicit block + message for opening stock and stock count.
- Cancel: hidden when cancelled or serialized; banner on `correction_document_required`.
- Product `isSerialized` / `avgCost` via repository/controller only.

### Tests

- Mapper, list/detail controllers, list screen (360×800 AR overflow), route guards.
- Validators: notes, stock count reasons, WAC fallback, serialized block.
- `finance_exception` maps `insufficient_stock` and `correction_document_required`.

### Verification

- `flutter analyze` — info only (deprecated `DropdownButtonFormField.value`).
- `flutter test` — **590** tests green.
- `git diff --check` — clean.

**Next:** M9 Batch 2 — invoice/voucher/journal/cash-bank UI; serialized opening/count when scope allows.

---

## Session 2026-06-17 - Phase 5 M4.5 Corrective Pass (Closure)

Follow-up hardening before M4.5 close (M9 still not started). **M4.5 is complete
through migration `070`.**

### Migrations added

- **`069_phase_5_inventory_cancel_idempotency.sql`** — cancel payload hash/idempotency
  replay via reversal `journal_entries` + `cancellation_idempotency_*` columns;
  serialized documents reject cancel with `correction_document_required`.
- **`070_phase_5_inventory_confirm_timestamps.sql`** — `clock_timestamp()` on document
  insert for monotonic `confirmed_at`; safe-cancel blocks when later confirmed
  documents affect the same product/warehouse.

### Tests added (`phase_5_inventory_accounting.sql` cases 15–25)

Serialized stock-in/out; cancel safe/unsafe/idempotent/mismatch; permission denied;
cross-tenant cancel; forced journal rollback; all-owned-buckets WAC (`qty_rented`);
reason-specific postings (owner_withdrawal, internal_consumption, damage/expiry/write_off).

### Verification

- `supabase db reset` + `./scripts/test/run_sql_suites.sh` — all phases green
- `flutter analyze` / `flutter test` (572) / `git diff --check` — clean

**Next:** M9 Finance UI (wire inventory accounting repository); do not start until explicitly requested.

---

## Session 2026-06-17 - Phase 5 M4.5 Inventory Accounting and Opening Stock Closed

Delivered Phase 5 M4.5 as SQL-first inventory financial documents:

### Migrations (`065`–`070`)

- **`065`–`068`** — initial M4.5 delivery (enum, schema, helpers, public RPCs).
- **`069`** — cancel idempotency replay; serialized cancel guard.
- **`070`** — monotonic `confirmed_at` for safe-cancel ordering.

### Public RPC surface

- `record_opening_stock`, `record_inventory_document` (stock_in/stock_out in payload),
  `record_stock_count`, `cancel_inventory_document`,
  `list_inventory_documents`, `get_inventory_document_detail`,
  `list_inventory_adjustment_reasons` (no account IDs exposed).

### Tests and suite runner

- `supabase/tests/phase_5_inventory_accounting.sql` — 25 acceptance cases (was 14).
- `supabase/tests/phase_5_inventory_accounting_concurrency.sh` — parallel idempotent
  stock-in with EXIT cleanup (no baseline pollution).
- `scripts/test/run_sql_suites.sh` — Phase C.5 between Phase B (M4 tax) and Phase D (M5).

### Key decisions preserved

- Purchase WAC (`apply_purchase_wac_internal`) unchanged; inventory-document WAC
  uses separate all-owned-buckets helper.
- Warehouse transfers stay non-financial.
- Zero-WAC legacy stock-out allowed (movement only, no journal).
- Cancellation: safe reversal only; else `correction_document_required`.

### Verification

- `supabase db reset` + `./scripts/test/run_sql_suites.sh` — all phases green.
- `flutter analyze` / `flutter test` / `git diff --check` — run at session close.

### Out of scope (unchanged)

- Flutter inventory accounting UI/repository wiring (M9).
- Full correction-document workflow.

**Next:** Phase 5 M9 — Finance UI; wire `lib/features/inventory_accounting/` to M4.5 RPCs.

---

## Session 2026-06-17 - Phase 5 M8 Dart Finance Layer, Routes, and Localization Closed

Delivered Phase 5 M8 as Flutter application-layer milestone
([`bd3c36f`](bd3c36f) — 155 files, +11,281 lines):

### M8A — Shared foundation

- Added [`lib/features/finance_shared/`](lib/features/finance_shared/) domain:
  financial document status, payment method, party reference, date range,
  pagination cursor, currency total DTO, idempotency session, granular
  [`finance_permissions.dart`](lib/features/finance_shared/domain/finance_permissions.dart).
- Added [`FinanceException`](lib/core/errors/finance_exception.dart) with
  Postgres token mapping and finance validation codes.
- Added canonical [`MoneyDisplay`](lib/features/finance_shared/presentation/money_display.dart)
  + cached [`tenantCurrencyFormatProvider`](lib/features/finance_shared/presentation/tenant_currency_provider.dart)
  using `TenantCurrencyFormat` / `formatDocumentMoney` (no `formatMoney` / `double`).
- Extended [`JournalSource`](lib/features/accounting/domain/journal_source.dart) with
  M7.5 return/refund values; centralized labels in finance_shared.

### M8B — Models, mappers, repositories

- **Invoices:** domain models + [`invoice_repository`](lib/features/invoices/data/invoice_repository.dart)
  / [`invoice_rpc_mapper`](lib/features/invoices/data/invoice_rpc_mapper.dart).
  Typed detail RPCs; `fetchInvoiceDetail(id, type?)` probes allowed RPCs when
  type missing; mutations pass `p_idempotency_key`; no Dart document numbering.
- **Vouchers:** domain + repository using migration **064** signatures for
  open-invoice lists and record voucher RPCs.
- **Journal / cash-bank:** RLS bounded `.select()` on `journal_entries` /
  `journal_lines`; `get_cash_bank_activity` JSON mapping.
- **Tax:** [`tax_settings_repository`](lib/features/settings/data/tax_settings_repository.dart)
  — rates via `list_tax_rates`, patch via `update_tax_settings`.
  **Read gap documented:** no `get_tax_settings()` RPC; no SQL patch in M8.
- **Inventory accounting:** domain stub only under
  [`lib/features/inventory_accounting/domain/`](lib/features/inventory_accounting/domain/);
  no live SQL-backed repository (M4.5 deferred).

### M8C — Validators + controllers

- 13 pure validators in [`lib/domain/validators/`](lib/domain/validators/) — called
  from **controllers before submit**, not from repositories.
- Riverpod controllers: invoice list/form/detail, voucher list/form/detail,
  journal list/detail, cash-bank activity, tax settings (rates-only minimal).
- Idempotency key lifecycle in form controllers via `FinanceIdempotencySession`.
- Invoice detail enforces type-specific view permission after load;
  cancel requires `invoices.cancel`.

### M8D — Routes, nav, placeholders, l10n

- Finance routes in [`app_routes.dart`](lib/core/routing/app_routes.dart) with
  `invoiceDetailPath(id, type: …)` query param; guards in
  [`route_guards.dart`](lib/core/routing/route_guards.dart).
- Nav items (permission-gated): Invoices, Vouchers, Journal, Cash & Bank.
  **No** inventory documents nav item.
- Lightweight l10n placeholder screens only — no M9 workflows (forms, tables,
  pickers, allocation UI, return wizard, print).
- Complete EN/AR finance keys; parity test
  [`finance_l10n_parity_test.dart`](test/core/localization/finance_l10n_parity_test.dart).
- Updated [`customer_permissions.dart`](lib/features/customers/domain/customer_permissions.dart)
  `canViewInvoices` / `canViewVouchers` to granular finance helpers.
- Existing `/product-units/:id` and `/settings/templates` routes unchanged.

### Permissions added to Flutter guards

- Granular invoice view: `invoices.view_sales`, `invoices.view_purchase`,
  `invoices.view_returns` (+ legacy `invoices.view`).
- Return/create/cancel: `invoices.create_sales_return`,
  `invoices.create_purchase_return`, `invoices.cancel`.
- Voucher/journal/cash/tax guards aligned with M5–M7.5 SQL permissions.

### Verification

- `dart run build_runner build --delete-conflicting-outputs` — OK
- `flutter gen-l10n` — OK
- `dart format` — OK
- `flutter analyze` — no issues
- `flutter test` — **572 tests** green
- `git diff --check` — clean
- SQL suites not rerun in M8 session (avoid local `db reset`); owner may run
  `./scripts/test/run_sql_suites.sh` before push if desired.

### Explicit non-goals (honored)

- No M9 operational finance UI workflows.
- No M4.5 inventory accounting SQL or live repository.
- No `get_tax_settings()` SQL patch.
- Repositories do not own business validation (controllers + validators do).

**Next:** Phase 5 M9 — Finance UI and Cross-Module Integration. M4.5 remains
deferred pending accountant review and required before Phase 5 M10 close.

---

## Session 2026-06-17 - M7.5 Return/Credit Engine Implemented + Refund Allocation Correction

Delivered Phase 5 M7.5 as SQL-only milestone:

- Added `063_phase_5_return_journal_source_enum.sql` for isolated
  `journal_source` enum values: returns, reversals, and refund vouchers.
- Added `064_phase_5_return_invoice_rpc.sql` for linked sales/purchase returns,
  credit allocations, SR/PR sequences, return permissions, COA 4102/2150/1160,
  return write/read RPCs, credit application, refund vouchers, and M7 effective
  outstanding hardening.
- Added `phase_5_returns.sql` and `phase_5_returns_concurrency.sh`; suite runner
  now includes Phase G after M7 vouchers.
- Updated finance foundation sequence expectations for SR/PR.

Post-implementation correction from owner review:

- Refunds must behave like ERP account settlements: a return creates party
  credit, then one or more refund vouchers consume that credit by cash/bank
  method.
- Removed the effective "one cash refund per return" model by keying
  `cash_refund` allocations by `(tenant_id, source_invoice_id, voucher_id)`.
- Added `voucher_id` linkage on `invoice_credit_allocations`, with allocation
  shape constraints so `cash_refund` rows are always tied to a voucher and
  original/future allocations are not.
- `record_customer_refund_voucher` and `record_supplier_refund_receipt` now keep
  the old single-return call path and also accept `allocations` in `p_data` for
  one voucher allocated across multiple return invoices.
- Return detail now exposes refund voucher id/number in credit allocations.
- Returns test case 24 now covers a customer refund voucher split across two
  returns plus a second voucher against the same return, proving partial/multiple
  refunds and voucher linkage.

Verification note:

- Cursor reported: `npx supabase db reset`, `./scripts/test/run_sql_suites.sh`
  twice, `flutter analyze`, `flutter test`, and `git diff --check` passed before
  the refund allocation correction.
- Codex static verification after the correction: trailing-whitespace check
  passed. Local `npx supabase db reset` could not run inside Codex because Docker
  socket access is blocked in this sandbox. Owner should rerun the SQL suite
  before pushing.

**Next:** Run full verification after the refund allocation correction, then
continue to Phase 5 M8 Dart Finance Layer / Routes / Localization. M4.5 remains
deferred pending accountant review and required before Phase 5 M10 close.

*(Superseded — M8 closed same day; see M8 session above.)*

---

## Session 2026-06-16 - M7 Voucher, Allocation, and Payment Engine Closed

Delivered Phase 5 M7 as SQL-only milestone
[`062_phase_5_voucher_allocation_rpc.sql`](supabase/migrations/062_phase_5_voucher_allocation_rpc.sql):

- **Schema:** three-mode `chk_vouchers_party_direction` (receipt/customer,
  supplier payment, direct account payment); `trg_audit_vouchers_status`.
- **Write RPCs:** `record_receipt_voucher`, `record_payment_voucher`
  (supplier fifo/manual only — unallocated supplier payments rejected),
  `cancel_voucher` with journal idempotency.
- **Read RPCs:** `list_vouchers`, `get_voucher_detail`,
  `list_open_customer_invoices`, `list_open_supplier_invoices`,
  `get_cash_bank_activity` (opening balance from pre-range posted lines).
- **Validators:** structural cash/bank check (no `11xx` prefix rule); direct
  payment deny-list (inventory 1301, entity A/R/A/P, cash/bank debit,
  protected roots); manual allocation rejects empty/zero-sum payloads.
- **Tests:** [`phase_5_vouchers.sql`](supabase/tests/phase_5_vouchers.sql)
  (33 cases: exact/partial/FIFO/manual/unallocated receipts, supplier payment,
  direct expense, rejections, cancel, idempotency, permissions, period lock,
  direct-write denial, `cancel_invoice` blocker after real allocation, helper
  ACL, rollback, read RPCs, opening balance).
  [`phase_5_vouchers_concurrency.sh`](supabase/tests/phase_5_vouchers_concurrency.sh)
  (idempotency race + invoice over-allocation race).
- **Suite runner:** Phase F in
  [`scripts/test/run_sql_suites.sh`](scripts/test/run_sql_suites.sh), after M6
  and before the Phase C pollution rerun.
- **Out of scope (unchanged):** Flutter UI, M7.5 returns, M4.5 inventory
  accounting, employee/HR vouchers, manual journals, weakening RPC-only write
  boundaries.

**Verification:** `npx supabase db reset`; `./scripts/test/run_sql_suites.sh`
twice (pollution gate); `flutter analyze`; `flutter test` (516);
`git diff --check`.

**Codex review note (2026-06-17):** implementation inspected after Cursor
closure. One direct-account payment validation gap was corrected: seeded
cash/bank posting accounts (`1101`/`1102`) are rejected as direct debit
accounts, including the case where the debit bank account differs from the
credited cash account. The M7 SQL suite case 12 now covers the seeded bank
account as well as inventory, A/R, A/P, and same-cash debit rejection.

**Final verification after Codex correction (reported by owner, 2026-06-17):**
`./scripts/test/run_sql_suites.sh` passed with `All SQL suite phases passed`;
`flutter analyze` reported no issues; `flutter test` passed 516 tests;
`git diff --check` was clean.

**Next:** M7.5 / returns — `063_phase_5_return_invoice_rpc.sql` (per plan sequence).

---

## Session 2026-06-16 - M6 Sales Invoice Engine Closed

Delivered Phase 5 M6 as SQL-only milestone
[`061_phase_5_sales_invoice_rpc.sql`](supabase/migrations/061_phase_5_sales_invoice_rpc.sql):

- **Posting RPC:** `record_sales_invoice(p_data, p_idempotency_key)` —
  idempotent confirmed sale with strict payload normalization, stock-out,
  serialized unit validation, frozen COGS snapshots, per-account output-tax
  posting, and balanced A/R, revenue, COGS, and inventory journal lines.
- **Cancellation RPC:** `cancel_invoice(p_invoice_id, p_reason,
  p_idempotency_key)` — shared sales/purchase cancellation with safety guards,
  negative reversal movements, reversal journals, no row deletion, payment and
  allocation blockers, serialized unit restore from `unit_events` metadata, and
  purchase cancellation WAC reversal on the current global `sum(qty_available)`
  basis.
- **Read RPCs:** `list_sales_invoices` and `get_sales_invoice_detail`.
- **Tests:** [`phase_5_sales_invoices.sql`](supabase/tests/phase_5_sales_invoices.sql)
  covers sales posting, serialized identity, aggregate stock, min-price gate,
  multi-rate output VAT, COGS snapshots, WAC unchanged by sale, idempotency,
  tenant isolation, cancellation, purchase cancellation safe/unsafe paths, and
  rollback. [`phase_5_sales_invoices_concurrency.sh`](supabase/tests/phase_5_sales_invoices_concurrency.sh)
  covers racing sales against last stock.
- **Suite runner:** Phase E in
  [`scripts/test/run_sql_suites.sh`](scripts/test/run_sql_suites.sh), after M5
  and before the Phase C pollution rerun.
- **Collateral fixes:** [`phase_5_finance_foundation.sql`](supabase/tests/phase_5_finance_foundation.sql)
  case 12 now expects `validation_failed` from the implemented sales RPC;
  [`phase_5_purchase_invoices_concurrency.sh`](supabase/tests/phase_5_purchase_invoices_concurrency.sh)
  cleanup now derives the supplier account at cleanup time.
- **Out of scope (unchanged):** sales drafts, Flutter UI, M4.5 inventory
  accounting, vouchers/allocations, and linked return documents.

**Verification reported by implementation agent:** `npx supabase db reset`;
`./scripts/test/run_sql_suites.sh` including Phase C pollution gate;
`flutter analyze`; `flutter test` (516); `git diff --check`.

**Codex review:** migration and tests inspected after implementation; no
blocking issue found. Guardrails confirmed for 4101 income, output VAT
liability, serialized aggregate stock decrement, cancellation-vs-return
movement distinction, unit metadata restore, purchase movement guard, and
concurrency coverage.

**Next:** M7 — `062_phase_5_voucher_allocation_rpc.sql`.

---

## Session 2026-06-15 - M5 Purchase Invoice Engine Closed

Delivered Phase 5 M5 as SQL-only milestone
[`060_phase_5_purchase_invoice_rpc.sql`](supabase/migrations/060_phase_5_purchase_invoice_rpc.sql):

- **Posting RPC:** `record_purchase_invoice(p_data, p_idempotency_key)` — atomic
  confirmed purchase with stock, serialized units, WAC, balanced A/P journal,
  idempotency (advisory lock → resolve → post), optional `invoice_id` draft
  confirm on same row.
- **Draft/read RPCs:** `save_invoice_draft`, `discard_invoice_draft`,
  `list_purchase_invoices`, `get_purchase_invoice_detail`.
- **Internal helpers** (revoked from `authenticated`): normalize/hash,
  supplier A/P validation, inventory 1301 resolver, WAC helper
  (`v_old_qty = v_post_qty - incoming_qty`), unit insert without stock
  double-count.
- **Tests:** [`phase_5_purchase_invoices.sql`](supabase/tests/phase_5_purchase_invoices.sql)
  (39 cases) + [`phase_5_purchase_invoices_concurrency.sh`](supabase/tests/phase_5_purchase_invoices_concurrency.sh)
  (idempotency race + concurrent WAC).
- **Suite runner:** Phase D in [`scripts/test/run_sql_suites.sh`](scripts/test/run_sql_suites.sh).
- **Out of scope (unchanged):** M4.5 inventory accounting, Flutter UI,
  `record_inventory_adjustment`, sales/returns/vouchers.

**Verification:** `supabase db reset`; `./scripts/test/run_sql_suites.sh` twice
without reset; `flutter analyze`; `flutter test` (516); `git diff --check`.

**Adversarial review:** tenant/ACL guards on reads and writes; strict payload
allowlists and JSON types; stable product locks; WAC value-based aggregation;
partial-commit case 37; pollution-free concurrency cleanup; no idempotency
exception swallowing.

**Next:** M6 — `061_phase_5_sales_invoice_rpc.sql`.

---

## Session 2026-06-15 - M4.5 Deferred, M5 Purchase Resumed

Owner decision:

- Defer **Phase 5 M4.5 Inventory Accounting and Opening Stock** until external
  accountants review opening stock, capital/drawings, inventory gains/losses,
  internal consumption, and stock-count treatment.
- M4.5 is not cancelled and remains required before Phase 5 M10 closure.
- No migration number is reserved for deferred M4.5.
- Resume **M5 Purchase Invoice Engine** now as
  `060_phase_5_purchase_invoice_rpc.sql`.
- Planned sequence returns to sales `061`, vouchers `062`, returns `063`, and
  finance views/hardening `064`.
- M5 must not change `record_inventory_adjustment`, create opening/capital/gain/
  loss accounts, or implement stock-count/generic adjustment accounting.
- M5 preserves the current Phase 3 WAC basis:
  `sum(qty_available)` across all warehouses, isolated behind an internal
  helper so it can be revisited after accountant approval.

**Next:** Phase 5 M5 — `060_phase_5_purchase_invoice_rpc.sql`.

---

## Session 2026-06-15 - Inventory Accounting, Returns, and Close Plan Placement

Canonical plan correction after M4 closure:

- Inserted **Phase 5 M4.5 Inventory Accounting and Opening Stock** conceptually
  before closure. Its migration was later deferred and unnumbered pending
  accountant review.
- M4.5 replaces the Phase 3 no-journal adjustment rule with RPC-only,
  idempotent, journal-backed opening stock, stock-in/out, and stock-count
  documents. Warehouse transfers remain non-financial.
- Historical numbering proposal was superseded by the deferral decision above.
- Sales/purchase returns are linked numbered documents using original
  tax/cost snapshots; they are not cancellation aliases.
- Full fiscal periods and year-end close belong to **Phase 10** after trial
  balance, P&L, and inventory-to-GL reconciliation. Income/expense close to
  retained earnings; balance-sheet accounts carry forward.

**Superseded next step:** M5 purchase at
`060_phase_5_purchase_invoice_rpc.sql`.

---

## Session 2026-06-15 - Phase 5 M4 Tax Foundation Closure

Adversarial corrective pass and closure blockers resolved:

- Migration [`059_phase_5_tax_foundation.sql`](supabase/migrations/059_phase_5_tax_foundation.sql): tax settings/rates, snapshots, gates, math RPCs, RLS/ACL.
- SQL suite [`phase_5_tax_foundation.sql`](supabase/tests/phase_5_tax_foundation.sql): 28 cases + pollution-free concurrency script.
- Dart domain [`lib/domain/finance/`](lib/domain/finance/) with PostgreSQL parity fixtures.
- [`phase_5_tax_foundation_concurrency.sh`](supabase/tests/phase_5_tax_foundation_concurrency.sh): exactly-one-winner race, seeded posting accounts (no provisioning pollution), postgres-only EXIT cleanup.

### Verification

```text
npx supabase db reset                          → 001–059 applied
./scripts/test/run_sql_suites.sh (×2, no reset) → Phase A/B/C passed both runs
flutter analyze                                → no issues
flutter test                                   → 516 passed
git diff --check                               → clean
```

**Phase 5 M4 is closed.** Current next step: M5 —
`060_phase_5_purchase_invoice_rpc.sql`.

---

## Session 2026-06-15 - Phase 5 M4 Adversarial Corrective Pass (superseded — closed)

Independent review found seven gaps; all fixed and re-verified. See closure session above.

---

## Session 2026-06-15 - Phase 5 M4 Tax Foundation Closure (superseded — invalidated)

Prior session claimed M4 closure before adversarial review; superseded by corrective pass and final closure above.

---

## Session 2026-06-14 - macOS Readiness and API ACL Review

### Findings and corrective work (historical — superseded by M4 closure 2026-06-15)

- ~~Phase 5 M4 is closed~~ — stale at time of writing; M4 was pending until 2026-06-15 adversarial sign-off (now closed).
- Reviewed the Apple-platform commit added after M3.
- Replaced migration `058` blanket authenticated grants with policy-derived
  table privileges. Client roles no longer receive TRUNCATE, broad routine
  EXECUTE, or default privileges that bypass RPC-only boundaries.
- Reserved migration `059` for M4 Tax Foundation and shifted later planned
  Phase 5 migrations by one.
- Added `scripts/test/run_sql_suites.sh` for the existing A/B/C SQL pollution
  gate on macOS/Linux.
- `scripts/run-local.sh` now defaults to the macOS desktop target; pass `ios`
  explicitly for the simulator/device.
- Updated Supabase initialization to the current `publishableKey` API.

### Environment notes

- Flutter 3.44.2 / Dart 3.12.2 and CocoaPods 1.16.2 are installed.
- Xcode 26.5 first-launch status is complete. A macOS build could not finish
  inside the Codex sandbox because CoreSimulator/SwiftPM cache services were
  blocked; retry from the normal Terminal remains required.
- Local Supabase reset through migration `058` passed.
- `scripts/test/run_sql_suites.sh` passed Phase A, M3 Phase B, and the Phase C
  pollution rerun.
- `flutter analyze` passes with no issues. Flutter widget tests could not run
  inside the Codex sandbox because `flutter_tester` was terminated before its
  localhost harness connected.

---

## Session 2026-06-10 - Phase 5 M3 Arabic PDF Correctness Closure

### Final status

- The M3 visual gate was reopened after Arabic text was found disconnected or reversed in rendered report images.
- The defect was fixed and protected by Arabic-only Windows and Android PDF goldens.
- **Phase 5 M3 is closed.** Arabic, bilingual, performance, analysis, and test gates all pass on the final code.

### Root causes and fixes

- The `pdf` package only applies Arabic shaping when a text run is explicitly RTL; bilingual Arabic/English strings had been combined into one LTR text widget.
- Localized Arabic and English are now emitted as separate RTL and LTR runs.
- Table headers, row values, totals, tenant/party details, metadata, notes, payment details, footer, and asset identity use content-aware direction.
- Latin identifiers inside Arabic documents remain LTR, preventing values such as `C-001` and `SN-12345` from being reversed.
- Arabic monetary labels use `د.ك`; English labels retain `KWD`.
- The statement table keeps a fast raw-string path for non-Arabic cells in bilingual documents, avoiding thousands of unnecessary widgets while preserving directed widgets for Arabic content and Arabic-only output.
- PDF golden and benchmark wrappers now drain child-process stdout/stderr, preventing pipe-buffer stalls and retaining useful failure output.

### Final visual and performance gates

```text
Windows PDF goldens                                   -> 10/10 compare-only passed
Android PDF goldens                                   -> 10/10 compare-only passed
Arabic-only goldens                                   -> customer statement + asset tag label
Visual inspection                                     -> connected Arabic; correct RTL; C-001 and SN-12345 remain LTR
Windows 1000-row benchmark median / max                -> 29,826 ms / 34,710 ms
Android 1000-row benchmark median / max                -> 42,901 ms / 54,122 ms
Performance thresholds                                -> median <=45s; max <=60s; passed on both platforms
```

### Final Flutter and environment gates

```text
flutter analyze                                       -> no issues
flutter test                                          -> 492 passed
Windows debug/profile builds through gates            -> passed
Android debug/profile builds through gates            -> passed
Docker/Supabase health                                -> all enabled services healthy, including Vector
```

### Manual acceptance phrases

- Verify `شركة تجريبية`, `عميل عربي`, `فاتورة مبيعات`, `الرصيد الافتتاحي`, and `الإجمالي`.
- Verify Arabic letters are connected and read right-to-left.
- Verify `C-001`, `SN-12345`, dates, numbers, and QR payloads are not reversed.

---

## Session 2026-06-09 - Phase 5 M3 Tier A Closure

### Final status

- Docker Desktop virtualization was restored and the local Supabase stack became operational.
- The invalid conditional Tier B label was superseded by a complete **Tier A pass at the database cap of 1000 statement rows**.
- **Phase 5 M3 is closed.** No M3 gate remains skipped or externally blocked.

### Final corrective work

- Fixed benchmark process exit handling, metadata transport, Android `adb` discovery, timeout handling, and result-artifact validation.
- Added a device-safe PDF golden driver because Flutter 3.41.6 passes an invalid Windows path URI through the stock device-golden proxy.
- Added Windows and Android golden baselines with update and compare-only wrappers.
- Fixed clipped asset labels, duplicate localized company/product/party text, missing statement running balances, and raw totals keys.
- Kept statement money as decimal strings and added a normalized serialized-money fast path without `double` conversion.
- Moved `KWD` from every statement money cell to the debit/credit/balance headers, preserving meaning while reducing PDF layout cost.
- Retained all earlier hardening: measured thermal pages, tenant optional columns, strict logo loading, template validation, read-only template ACLs, and restricted audit helpers.

### Database and integration gates

```text
npx supabase db reset                                  -> migrations 001-057 passed
scripts/test/run_sql_suites.ps1                        -> Phase A/B/C and pollution rerun passed
npx supabase db lint --local --level warning           -> exit 0; pre-existing warnings only
Windows Supabase seeded-template integration           -> passed; 6 templates
Android Supabase seeded-template integration           -> passed; 6 templates
Docker/Supabase post-restart health                     -> all enabled services healthy, including Vector
```

### Tier A performance

```text
Cap / workload                                         -> 1000 rows, 43 pages
Windows median / max                                   -> 21,594 ms / 21,598 ms
Windows peak memory / PDF size                         -> 168,792,064 B / 165,686 B
Android median / max                                   -> 36,029 ms / 41,108 ms
Android peak memory / PDF size                         -> 196,899,840 B / 165,686 B
Thresholds                                             -> median 45s, max 60s, memory 512MiB/384MiB, PDF 5MiB
Result                                                 -> passed on both platforms
```

### Flutter and visual gates

```text
dart run build_runner build --delete-conflicting-outputs -> passed
flutter gen-l10n                                         -> passed
dart format --output=none --set-exit-if-changed ...      -> 485 files, 0 changed
flutter analyze                                          -> no issues
flutter test                                             -> 487 passed
Windows PDF goldens                                      -> 8/8 update + compare-only passed
Android PDF goldens                                      -> 8/8 update + compare-only passed
Visual inspection                                        -> statement and asset label passed
flutter build windows                                    -> Release hs360.exe passed
flutter build apk --debug                                -> app-debug.apk passed
PowerShell parser                                        -> all M3 scripts valid
git diff --check                                         -> passed
```

### Residual note

- `build_runner` reports that SDK language version 3.11 is newer than the transitive `analyzer` language version 3.9. This is a dependency-tooling warning only; generation, analysis, tests, and both builds pass.
- Supabase Analytics on Windows requires Docker Desktop's unauthenticated API on `localhost:2375`. It was enabled together with IPv6 DNS filtering because the local Supabase network is IPv4-only. Keep this machine and port limited to trusted local development.

---

## Session 2026-06-08 — Phase 5 M3 Corrective Closure (v9)

### Context

- Executed standalone M3 corrective plan v9: hardened migration 057, block-split PDF renderer, isolate protocol, SQL pollution gate, benchmark wrapper, golden policy, integration tests.

### Corrective highlights (057 + Flutter)

- **`m3_statement_row_limit()` = 1000**; zero-safe no-account statement payload; stable `je.id/jl.id` ordering; root `notes: null`.
- **ACL:** `REVOKE ALL` + `GRANT SELECT` on `document_templates` / `tenant_document_settings`; TRUNCATE denied tests.
- **Validator:** 4-arg `validate_document_template_body(..., p_schema_version)`; payment_voucher rejected at all layers.
- **Renderer:** `lib/core/documents/services/pdf/` with 12 block files; thermal measure/reject >1200mm; label 18×10mm + 1mm gap; notes empty when null.
- **Isolate:** `Isolate.run(() => documentRenderWorker(dto))`; decimal money strings in DTO.
- **Benchmark:** `test_driver/benchmark_driver.dart` + `scripts/benchmark/run_statement_perf.ps1` (1800s timeout; null exit-code fix).
- **Goldens:** root `flutter_test_config.dart` host comparator; integration test installs `GoldenPdfComparator`; Windows baselines under `test/core/documents/goldens/windows/`.
- **Integration:** `integration_test/documents/supabase_seeded_templates_test.dart` + `scripts/integration/run_supabase_templates.ps1` (stderr-safe status parse; targets supabase test only).

### Verification (Windows Tier B — 2026-06-08)

```text
npx supabase db reset                          → 001–057 applied cleanly
scripts/test/run_sql_suites.ps1                → Phase A/B/C passed (pollution gate)
flutter analyze                                → no issues
flutter test                                   → 476 passed
flutter gen-l10n                               → ok
dart format lib test integration_test …        → ok
flutter build windows                          → Release hs360.exe
flutter build apk --debug                      → app-debug.apk
scripts/benchmark/run_statement_perf.ps1       → passed (1000 lines; median ~33.5s; peak mem ~159MB)
integration_test/documents/pdf_golden_test.dart -d windows → 8/8 passed
scripts/integration/run_supabase_templates.ps1 -Platform windows → passed (6 templates + payment_voucher reject)
```

### Tier A skips (documented)

```text
SKIPPED: Android perf benchmark (no device/emulator in gate run)
SKIPPED: Android PDF goldens (no device/emulator in gate run)
SKIPPED: Android Supabase integration (no device/emulator in gate run)
```

**Label:** M3 CONDITIONAL CLOSURE — Windows gates green; Android Tier A not run in this environment.

### M3 status

- **Corrective closure complete (Windows Tier B).** ~~Next: Phase 5 M4 — tax foundation per finance plan.~~ *(superseded — M4 closed 2026-06-15.)*

---

## Session 2026-06-07 — Phase 5 M3 Closure (Document Templates + PDF Renderer)

### Context

- Implemented approved M3 plan: migration [`057_phase_5_document_templates.sql`](supabase/migrations/057_phase_5_document_templates.sql), Flutter `lib/core/documents/`, settings screen, preview integration, SQL + Flutter tests.

### Database (057)

- **`document_templates`:** read-only for clients; six seeded templates per tenant; `validate_document_template_body`; bootstrap trigger + backfill.
- **`tenant_document_settings`:** RPC-only writes via `upsert_tenant_document_settings`.
- **RPCs:** `get_effective_document_template`, `get_tenant_document_settings`, `upsert_tenant_document_settings`, `get_customer_statement_document_payload` (range-correct summary, 5000-row provisional cap, 365-day inclusive window), `get_product_unit_label_payload` (requires `product_units.view`).
- **Audit:** `audit_log_row()` extended for `tenant_document_settings`; INSERT/UPDATE audited.
- **RLS:** SELECT with `settings.templates.view OR edit`; REVOKE direct writes on both tables.
- **SQL suite:** [`phase_5_document_templates.sql`](supabase/tests/phase_5_document_templates.sql) (17 cases: backfill, validator, RLS, label perms, date range, legacy invoice view, logo HTTPS, no-default, audit, summary math, tenant_settings fallback, statement_range_too_large, anon denial, direct settings write denial).

### Flutter

- **Core:** domain, repository, validator, `PdfFontRegistry`, `PdfDocumentRenderer`, `LogoLoader` (image package), QR encoder, permissions (preview vs export, legacy `invoices.view`).
- **UI:** `/settings/templates`, `/documents/preview` (statement + asset label); PdfPreview export gated; statement tab + unit detail preview buttons.
- **Fonts:** Noto Sans + Noto Sans Arabic under `assets/fonts/noto/` + OFL.txt.
- **Deps:** `pdf`, `printing`, `http`, `image`.

### Verification

```text
flutter analyze                                → no issues
flutter test                                   → 405 passed (+24 M3)
flutter test test/manual/arabic_pdf_prototype_test.dart → passed (prototype gate)
flutter test test/core/documents/services/pdf_document_renderer_test.dart → 2000-line statement perf gate passed (~19s, 5000-row SQL cap retained)
flutter build windows                          → succeeded
flutter build apk --debug                      → succeeded
npx supabase db reset                          → 001–057 applied cleanly
phase_1d_rls … phase_5_document_templates.sql  → all passed
npx supabase db lint --local --level warning   → pre-existing warnings only (057: m3_default_template_body stable fix applied)
```

### File-size notes (M3)

- [`057_phase_5_document_templates.sql`](supabase/migrations/057_phase_5_document_templates.sql) ~1098 lines — single migration with seeds/validators/RPCs (intentional).
- [`pdf_document_renderer.dart`](lib/core/documents/services/pdf_document_renderer.dart) ~570 lines — block rendering; dynamic `MultiPage.maxPages` for large statements/invoices.

### M3 status

- **Closed.** ~~Next: Phase 5 M4 — tax foundation per finance plan.~~ *(superseded — M4 closed 2026-06-15.)*

### Explicit non-goals (honored)

- No edits to migrations ≤056; no stamp/signature columns; no payment_voucher template; no truncated financial PDFs; no production invoice fixture routes.

---

## Session 2026-06-07 — Phase 5 M1/M2 Hardening Closure

### Context

- Migration `056` independently verified; no logic changes. Closed M1/M2 by adding permanent regression cases to [`phase_5_m1_m2_hardening.sql`](supabase/tests/phase_5_m1_m2_hardening.sql) per approved plan.

### Regression cases added

- `document_sequences`: anon INSERT/UPDATE/DELETE/TRUNCATE denial (42501)
- `unit_events`: authorized SELECT for manager with `product_units.view`
- Journal: zero-line posting rejected (`journal_entry_requires_two_lines`)
- `tenant_settings` audit: full `before_json`/`after_json` for books lock + serial fields
- Reconcile: inactive/non-serialized/cross-tenant product; inactive/cross-tenant/unknown warehouse, covered by both preview and reconcile RPCs
- Reconcile: direct `reconcile_serialized_stock` error paths (fractional, negative, bucket, exceeds)
- Metadata: invalid cancelled invoice/voucher (missing actor, blank reason)
- Reconcile gap: `created_by` and `qty_available` in event metadata

### M1/M2 status

- **Closed.** Next: Phase 5 M3 — `057_phase_5_document_templates.sql`.

### Verification (closure re-run)

```text
npx supabase db reset                          → 001–056 applied cleanly
phase_1d_rls.sql                               → passed
phase_3_products_inventory.sql                 → passed
phase_4_customers_suppliers_coa.sql            → passed
phase_4_customer_service_locations.sql         → passed
phase_4_service_location_coordinates.sql       → passed
phase_5_finance_foundation.sql                 → passed
phase_5_asset_identity.sql                     → passed
phase_5_m1_m2_hardening.sql                    → passed (expanded permanent regression)
```

---

## Session 2026-06-07 — Phase 5 M1/M2 Hardening Checkpoint

### Context

- Mandatory hardening gate before M3 (document templates). Reproduced security, accounting, inventory, and scan gaps against clean DB at migration `055`.
- Delivered as migration [`056_phase_5_m1_m2_hardening.sql`](supabase/migrations/056_phase_5_m1_m2_hardening.sql) + suite [`phase_5_m1_m2_hardening.sql`](supabase/tests/phase_5_m1_m2_hardening.sql).

### Root causes fixed

| # | Finding | Root cause |
|---|---------|------------|
| 1 | `document_sequences` exposed | No RLS/revoke on table; only `next_document_number()` was internal |
| 2 | Journal gaps | Line trigger lacked INSERT + parent `FOR UPDATE`; posting validator skipped INSERT-with-posted and balance check |
| 3 | `tenant_settings` audit | PL/pgSQL compile-time `new.id` on table without `id` column |
| 4 | Fractional reconcile | `numeric::bigint` **rounds** before validation |
| 5 | Scan permissions | Global `product_units.view` gate blocked product-only scans |
| 6 | Confirmation metadata | Missing `confirmed_by` / cancellation actor+reason constraints |

### Architecture decisions (056)

- **`document_sequences`:** `REVOKE ALL` + `ENABLE RLS` with **no client policies** (no FORCE RLS).
- **Reconcile/preview auth:** both require `is_manager()` OR `product_units.reconcile_serials` (not `product_units.view`).
- **Reconcile validation order:** negative → whole-number → non-available buckets → exceeds balance → difference; exact match → `serialized_reconciliation_not_needed`.
- **Conservative bucket rule:** reject when any of `qty_rented/trial/maintenance/damaged` is non-zero.
- **Scan policy:** per-category permissions; `scan_not_found` when no authorized match; cross-tenant → `scan_not_found`.
- **Journal lines:** lock both OLD/NEW parent entries in UUID order on UPDATE.

### Files changed

| File | Role |
|------|------|
| [`056_phase_5_m1_m2_hardening.sql`](supabase/migrations/056_phase_5_m1_m2_hardening.sql) | Hardening migration |
| [`phase_5_m1_m2_hardening.sql`](supabase/tests/phase_5_m1_m2_hardening.sql) | Permanent regression suite (~65 isolated cases) |
| [`phase_5_finance_foundation.sql`](supabase/tests/phase_5_finance_foundation.sql) | Cases 6/8/15 updated for metadata + posting transition |
| [`PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md`](docs/PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md) | Migration renumber 057–062; M1/M2 hardening milestone |
| [`ai_memory.md`](ai_memory.md) | This session block |

### Verification (2026-06-07)

```text
npx supabase db reset                          → 001–056 applied cleanly
phase_1d_rls.sql                               → passed
phase_3_products_inventory.sql                 → passed
phase_4_customers_suppliers_coa.sql            → passed
phase_4_customer_service_locations.sql         → passed
phase_4_service_location_coordinates.sql       → passed
phase_5_finance_foundation.sql                 → passed (20 cases)
phase_5_asset_identity.sql                     → passed (11 cases)
phase_5_m1_m2_hardening.sql                    → passed
npx supabase db lint --local --level warning   → pre-existing warnings only (054/055 stubs, create_product_units); no new 056 function warnings
flutter analyze                                → no issues
flutter test                                   → 381 passed
```

### Explicit non-goals (honored)

- No M3 document templates, tax, invoice/voucher posting RPCs, scan launcher, reconcile UI, or Flutter permission refactors.
- No edits to historical migrations `029`, `054`, or `055`.

### Next session

- **Phase 5 M3:** `057_phase_5_document_templates.sql` per finance plan.

---

## Session 2026-06-07 — Phase 5 M2 (Asset Identity, Serial, Scan, Timeline)

### Context

- Continued from Phase 5 M1 closure (migrations `053`–`054`, 376 Flutter tests green).
- User supplied the full M2 plan (DB migration + Flutter scanning/unit detail + test suites). Plan reviewed in Cursor; two scope decisions locked before coding.

### Planning outcomes (approved before implementation)

| Decision | Choice |
|----------|--------|
| SKU in Flutter wizard | **Fully remove** user-editable SKU from wizard/draft/form state/validator; DB auto-generates via `SKU` document sequence on insert |
| Scan entry in AppShell | **Route only** — add reachable `/product-units/:id` screen; **no** global scan launcher in M2 |
| Permissions for reconcile/correct | Already seeded in `054` (`product_units.correct_serial`, `product_units.reconcile_serials`); no new permission rows in `055` |

Implementation finding during migration design:

- `customer_service_locations` had only `unique (tenant_id, customer_id, id)`. Added `unique (tenant_id, id)` so `unit_events` can reference `(tenant_id, service_location_id)` via composite FK.
- Barcode unique partial indexes make `scan_ambiguous` unreachable for duplicate barcodes in normal operation; SQL case 9 verifies duplicate barcodes are rejected on bulk unit create instead of ambiguous scan resolution.

### Files created

| File | Role |
|------|------|
| [`supabase/migrations/055_phase_5_asset_identity_scan_timeline.sql`](supabase/migrations/055_phase_5_asset_identity_scan_timeline.sql) | M2 schema, RPCs, view, RLS/ACL |
| [`supabase/tests/phase_5_asset_identity.sql`](supabase/tests/phase_5_asset_identity.sql) | 11 verification cases |
| [`lib/core/errors/scan_exception.dart`](lib/core/errors/scan_exception.dart) | Typed scan errors (`scan_not_found`, `scan_ambiguous`, …) |
| [`lib/core/scanning/domain/scan_result.dart`](lib/core/scanning/domain/scan_result.dart) | `ScanResult` + kind/matchedBy enums |
| [`lib/core/scanning/data/scan_repository.dart`](lib/core/scanning/data/scan_repository.dart) | `resolve_scan_code` RPC wrapper |
| [`lib/core/scanning/presentation/scan_controller.dart`](lib/core/scanning/presentation/scan_controller.dart) | Riverpod scan state machine |
| [`lib/core/scanning/presentation/scan_input.dart`](lib/core/scanning/presentation/scan_input.dart) | Keyboard-wedge input (Enter → resolve) |
| [`lib/core/scanning/presentation/mobile_scan_sheet.dart`](lib/core/scanning/presentation/mobile_scan_sheet.dart) | `mobile_scanner` bottom sheet |
| [`lib/features/products/domain/unit_timeline_event.dart`](lib/features/products/domain/unit_timeline_event.dart) | `v_unit_timeline` row model |
| [`lib/features/products/presentation/product_unit_detail_state.dart`](lib/features/products/presentation/product_unit_detail_state.dart) | Detail UI state |
| [`lib/features/products/presentation/product_unit_detail_controller.dart`](lib/features/products/presentation/product_unit_detail_controller.dart) | Load unit + serial correction |
| [`lib/features/products/presentation/product_unit_timeline_controller.dart`](lib/features/products/presentation/product_unit_timeline_controller.dart) | Timeline fetch per unit |
| [`lib/features/products/presentation/product_unit_detail_screen.dart`](lib/features/products/presentation/product_unit_detail_screen.dart) | Responsive bilingual detail screen |
| [`lib/features/products/presentation/widgets/product_unit_detail_header.dart`](lib/features/products/presentation/widgets/product_unit_detail_header.dart) | Metadata + status chips |
| [`lib/features/products/presentation/widgets/product_unit_serial_correction_card.dart`](lib/features/products/presentation/widgets/product_unit_serial_correction_card.dart) | Permission-gated correction form |
| [`lib/features/products/presentation/widgets/product_unit_timeline_list.dart`](lib/features/products/presentation/widgets/product_unit_timeline_list.dart) | Chronological timeline (Column, not nested ListView) |
| [`test/core/scanning/domain/scan_result_test.dart`](test/core/scanning/domain/scan_result_test.dart) | JSON parsing |
| [`test/core/scanning/presentation/scan_input_test.dart`](test/core/scanning/presentation/scan_input_test.dart) | Wedge Enter + clear |
| [`test/features/products/presentation/product_unit_detail_screen_test.dart`](test/features/products/presentation/product_unit_detail_screen_test.dart) | Mobile AR 360×800 + desktop EN + permission gate |

### Files updated (high-signal)

| File | Change |
|------|--------|
| [`supabase/migrations/054`](supabase/migrations/054_phase_5_finance_foundation.sql) trigger fn | Extended by `055` replace: `initialize_tenant_document_sequences()` now seeds `SKU` |
| [`lib/features/products/domain/product_form_state.dart`](lib/features/products/domain/product_form_state.dart) et al. | Removed `sku` from create/edit input |
| [`lib/features/products/data/product_repository.dart`](lib/features/products/data/product_repository.dart) | Stop sending `sku` on write; read back DB SKU on create when permitted |
| [`lib/features/products/data/product_unit_repository.dart`](lib/features/products/data/product_unit_repository.dart) | `fetchUnitById`, `fetchUnitTimeline`, `correctSerial` |
| [`lib/features/products/domain/product_unit.dart`](lib/features/products/domain/product_unit.dart) | Location/maintenance fields for detail screen |
| [`lib/features/products/domain/product_unit_permissions.dart`](lib/features/products/domain/product_unit_permissions.dart) | `canCorrectProductUnitSerial`, `canReconcileProductUnitSerials` |
| [`lib/core/routing/app_routes.dart`](lib/core/routing/app_routes.dart), [`app_router.dart`](lib/core/routing/app_router.dart), [`route_guards.dart`](lib/core/routing/route_guards.dart) | Route `/product-units/:id`; guard `product_units.view` |
| [`lib/l10n/app_en.arb`](lib/l10n/app_en.arb), [`app_ar.arb`](lib/l10n/app_ar.arb) | Scan + unit detail + timeline strings |
| [`supabase/tests/phase_5_finance_foundation.sql`](supabase/tests/phase_5_finance_foundation.sql) | Cases 17–18: expect **6** sequences (added `SKU`) |
| [`test/domain/validators/product_validator_test.dart`](test/domain/validators/product_validator_test.dart) et al. | SKU removal test updates |
| [`test/features/products/fake_product_unit_repository.dart`](test/features/products/fake_product_unit_repository.dart) | Fakes for detail/timeline/correctSerial |

### What `055` implements (summary)

- **`SKU` sequence:** backfill + tenant trigger; `trg_generate_product_sku_on_insert` calls `next_document_number('SKU')`; `trg_enforce_product_sku_immutability` raises `immutable_column`.
- **Serial settings:** `serial_number_mode` enum; `tenant_settings.serial_number_mode/prefix/padding`.
- **Barcode uniqueness:** `ux_products_tenant_barcode`, `ux_product_units_tenant_barcode` (case-insensitive, trimmed, partial).
- **`unit_events`:** lifecycle log table; RLS select via `product_units.view`; writes only through SECURITY DEFINER RPCs.
- **RPCs (authenticated EXECUTE):**
  - `preview_serialized_stock_reconciliation` — balance vs physical unit count
  - `reconcile_serialized_stock` — insert missing units + `unit_events`; **no** balance/movement writes
  - `correct_product_unit_serial` — serial update + `serial_correction` event; **no** balance/movement writes
  - `resolve_scan_code` — priority: unit barcode → product barcode → serial; tenant-scoped; `scan_ambiguous` / `scan_not_found`
- **`v_unit_timeline`:** `security_invoker = true`; unions acquisition, purchase invoice, inventory movements, unit events; placeholder unions for contracts/visits/maintenance (`where false`).
- **Composite FK hardening:** `product_units.(tenant_id, current_warehouse_id)` → warehouses; `(tenant_id, current_customer_id)` → customers.
- **ACL:** revoke internal helpers from public/anon/authenticated; grant public RPCs to `authenticated` only.

### Flutter M2 summary

- **Scanning core** under [`lib/core/scanning/`](lib/core/scanning/): reusable `ScanInput`, `MobileScanSheet`, `ScanController` + `ScanRepository` (not wired into AppShell nav — deferred).
- **Product unit detail** at [`/product-units/:id`](lib/core/routing/app_routes.dart): serial, barcode, status/health chips, location (warehouse/customer/site), maintenance count, permission-gated serial correction card, timeline from `v_unit_timeline`.
- **SKU wizard:** field removed from identity step and review; create success snackbar uses product name instead of SKU.
- **Bilingual:** AR/EN l10n keys; RTL via existing `localeProvider` / `AppLocalizations`.

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
flutter gen-l10n                               → OK
dart run build_runner build --delete-conflicting-outputs → OK
flutter analyze                                → no issues
flutter test                                   → 381 passed (+5 vs M1)
```

PowerShell note: pipe SQL tests with `Get-Content -Raw … | docker exec -i supabase_db_hs360 psql …` (`<` redirection not supported).

### Explicit non-goals (honored)

- No global scan launcher / AppShell scan entry (components exist; integration deferred).
- No reconcile-serial UI (RPC + permission helper only; UI deferred).
- No automatic serial generation from `tenant_settings.serial_number_mode` yet (columns seeded; generation logic deferred).
- No changes to finance posting RPC stubs or tax foundation (M4+).
- `reconcile_serialized_stock` / `correct_product_unit_serial` do not touch inventory balances or movements (by design).

### Next session

- ~~**Phase 5 M3+** per finance plan~~ — **M1/M2 hardening complete**; next: M3 `057_phase_5_document_templates.sql`
- Optional: wire scan launcher in AppShell; link unit rows from product detail → `/product-units/:id`
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
- Legacy permissions (`invoices.view`, `vouchers.view`, etc.) **kept** for backward
  compatibility after M8 granular Flutter guard split (2026-06-17).

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

### Next session (superseded by M2 — done 2026-06-07)

- ~~**Phase 5 M2:** `055_phase_5_asset_identity_scan_timeline.sql`~~ — completed same day.
- Cloud deploy of migrations 053–055 remains a separate ops step when Supabase project is linked.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 complete** - products and inventory (M0-M8).
- **Phase 4 M0-M8 complete** - customers, suppliers, CoA, service locations, coordinates, engineering closure through migration [`052`](supabase/migrations/052_phase_4_closure_hardening.sql).
- **Phase 5 M1–M4 complete** — finance foundation, asset identity, document templates/PDF, tax foundation through migrations [`053`](supabase/migrations/053_phase_5_journal_source_enum.sql)–[`059`](supabase/migrations/059_phase_5_tax_foundation.sql).
- **Phase 5 M4.5 complete** — inventory accounting and opening stock through migrations [`065`](supabase/migrations/065_phase_5_inventory_journal_source_enum.sql)–[`070`](supabase/migrations/070_phase_5_inventory_confirm_timestamps.sql); 25-case SQL suite in Phase C.5.
- **Phase 5 M5–M7.5 complete** — purchase/sales invoice RPCs, voucher allocation, returns/credits through migrations [`060`](supabase/migrations/060_phase_5_purchase_invoice_rpc.sql)–[`064`](supabase/migrations/064_phase_5_return_invoice_rpc.sql).
- **Phase 5 M8 complete** — Dart finance application layer, guarded routes, localization, and tests in commit [`bd3c36f`](bd3c36f); 572 Flutter tests green.
- **Phase 5 M9 Batch 1 complete** — inventory financial documents UI (`lib/features/inventory_accounting/`) wired to M4.5 RPCs; list/form/detail screens; **590** Flutter tests green.
- **Phase 5 M9 Batch 2 (invoices) complete** — list/form/detail/return screens in `lib/features/invoices/presentation/`; **611** Flutter tests green.
- **Phase 5 M9 Batch 3 complete** — invoice/receipt voucher print/preview from detail screens; **665** Flutter tests green.
- **Phase 5 M9 Final Closure delivered** — Customer 360 tabs, supplier detail, product/unit links, cash-bank CSV (loaded rows); **672** Flutter tests green.
- **Phase 5 M9 desktop finance UI/workflow closure accepted** — invoice/voucher workflow fixes and DB migrations `071`-`075`; Codex verification: `dart analyze .` no errors, `git diff --check` clean, DB script syntax clean.
- **M9 desktop UI/workflow scope complete. Backend/template/mobile/report/edit-delete gaps moved to post-M9/M10.**
- **Blocked/deferred safely + documented:** advanced edit/delete permissions, mobile redesign, voucher/report/PDF polish, payment voucher print, serialized opening/count, supplier statement, cash-bank PDF.

---

## Phase 5 M8 - Dart Finance Layer, Routes, and Localization (done)

- **Commit:** [`bd3c36f`](bd3c36f) — application layer only; no new SQL migrations.
- **Features:** `finance_shared`, `invoices`, `vouchers`, `journal`, `inventory_accounting` (stub domain), tax settings repository.
- **Architecture:** validators in controllers (not repos); RPC mappers; `FinanceException`; `MoneyDisplay` + tenant currency provider; fake repos for tests.
- **Routes:** `/invoices`, `/vouchers`, `/journal`, `/cash-bank`, `/inventory/documents/*`, `/settings/tax` — all permission-guarded; placeholder screens only.
- **Permissions:** granular invoice view/create/return/cancel split in Flutter guards; legacy `invoices.view` retained for compatibility.
- **Verification:** `flutter analyze` clean; **572** Flutter tests; l10n EN/AR parity test for finance keys.
- **Deferred (M9):** finance UI workflows; `get_tax_settings()` read RPC. M4.5
  backend is complete (`065`–`070`); inventory accounting repository/UI remains M9.

---

## Phase 5 M2 - Asset Identity, Serial, Scan, and Timeline (done)

- **Migration:** [`055_phase_5_asset_identity_scan_timeline.sql`](supabase/migrations/055_phase_5_asset_identity_scan_timeline.sql).
- **SKU:** internal `SKU-000001` sequence; auto-generate on product insert; immutability trigger; wizard no longer accepts user SKU.
- **Barcodes:** tenant-scoped case-insensitive trimmed unique indexes on `products` and `product_units`.
- **Serial settings:** `serial_number_mode` enum + `tenant_settings` columns (generation behavior deferred).
- **Unit lifecycle:** `unit_events` table; `v_unit_timeline` view (`security_invoker`); reconcile/correct RPCs write events only (no stock side effects).
- **Scan resolver:** `resolve_scan_code` RPC; Flutter [`lib/core/scanning/`](lib/core/scanning/) stack (`ScanInput`, `MobileScanSheet`, controllers/repos).
- **Unit detail UI:** [`ProductUnitDetailScreen`](lib/features/products/presentation/product_unit_detail_screen.dart) at `/product-units/:id`; serial correction gated by `product_units.correct_serial`.
- **Permissions:** reuse `054` seeds for `correct_serial` / `reconcile_serials`; route guard requires `product_units.view`.
- **Verification:** `supabase db reset` through 055; [`phase_5_asset_identity.sql`](supabase/tests/phase_5_asset_identity.sql) + all prior SQL suites; `flutter analyze` clean; 381 tests green (2026-06-07).

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
