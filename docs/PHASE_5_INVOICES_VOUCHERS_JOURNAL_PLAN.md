# Phase 5 - Invoices, Vouchers & Journal Plan

> Purpose: implement the first production-safe accounting cycle for HS360:
> purchase -> inventory/WAC -> sale -> receivable -> receipt/payment -> journal.
>
> Status at creation: planned on 2026-06-06. Phase 4 is engineering-complete
> through M8, but the clean local database reset remains an M0 operational gate.
>
> Canonical sources: `CANONICAL_DECISIONS.md`, `PAYMENT_SYSTEM.md`,
> `DATABASE_SCHEMA.md`, `MVP_SCOPE.md`, and
> `CAPABILITIES_DECISION_REPORT.md`. If this plan conflicts with
> `CANONICAL_DECISIONS.md`, the canonical decisions win.

---

## Executive Summary

Phase 5 is not only an invoice screen. It is the first phase in which product,
inventory, customer, supplier, chart-of-accounts, permissions, and document
printing become one atomic financial workflow.

The phase has five tightly connected responsibilities:

1. Finish the asset identity foundation needed by serialized purchases and
   future contracts.
2. Add the structured JSON print engine needed by invoices, vouchers,
   statements, and asset labels.
3. Add the tax and deterministic money foundation before any invoice posting.
4. Implement RPC-only purchase, sales, voucher, allocation, cancellation, and
   journal posting.
5. Expose the workflow through responsive Arabic/English Flutter screens and
   close it with database, domain, widget, integration, and manual acceptance
   verification.

The old three-week estimate in `BUILD_PLAN.md` is no longer realistic because
Phase 5 now includes Asset/Barcode/Print and Tax Foundation work that was not in
the original finance-only estimate. A professional implementation should be
planned as approximately 8 to 12 focused weeks for one developer with AI
assistance, depending on local Docker recovery and PDF/font integration.

The implementation is divided into `M0` through `M10`. M0 is a mandatory
baseline gate. M1-M10 are the ten implementation and closure milestones.

---

## What Phase 5 Means

At the end of Phase 5:

- A purchase invoice increases stock, updates WAC, creates serialized units
  when required, creates A/P, and posts a balanced journal entry.
- A sales invoice validates stock, snapshots cost and tax, decreases stock,
  creates A/R, recognizes revenue and COGS, and posts balanced journal entries.
- A receipt voucher moves money into cash/bank, reduces customer A/R, and
  allocates the payment to one or more invoices.
- A payment voucher moves money out of cash/bank, reduces supplier A/P or posts
  to an explicitly selected allowed account.
- Cancelling a posted financial document never deletes it. It creates reversal
  accounting and reverses inventory/allocation effects when safe.
- Customer and supplier balances remain derived from the journal.
- Every confirmed financial document is immutable.
- Every write is tenant-safe, permission-gated, audited, idempotent, and
  performed through an atomic RPC.
- Invoice, receipt voucher, statement, and asset-label documents can be
  previewed and printed in Arabic and English.

Phase 5 is therefore the bridge between the operational master data completed
in Phases 3-4 and contracts/field operations in Phases 6-8.

---

## Current Repository Inspection

### Confirmed Starting Point

- Migrations `001` through `052` exist.
- Phase 3 products/inventory and Phase 4 customers/suppliers/CoA are
  engineering-complete.
- `decimal` is already used in Dart for money and quantity values.
- A basic money formatter exists, but the canonical `MoneyDisplay` widget and
  fully tenant-driven currency precision are documented rather than implemented.
  Phase 5 must close this before finance UI is accepted.
- `mobile_scanner` is already a dependency, but no global scan resolver or
  camera scan workflow exists.
- `pdf` and `printing` are not yet dependencies.
- Product barcode and product-unit serial/barcode fields already exist.
- Product SKU is still visible and required in the normal product form.
- Product-unit creation already updates movement, balance, and WAC atomically,
  but it is an adjustment-style flow, not a purchase-invoice flow.
- Serialized warehouse transfers are intentionally rejected by the current
  transfer RPC.
- Customer 360 already has permission-aware invoice and voucher placeholder
  tabs plus a working journal-backed statement tab.
- Supplier detail is still a placeholder.
- Chart of accounts has protected system leaves and entity-linked A/R/A/P
  subaccounts.

### Existing Finance Tables

The following Phase 1 tables exist but are only foundational:

- `journal_entries`
- `journal_lines`
- `invoices`
- `invoice_lines`
- `vouchers`
- `voucher_invoice_allocations`
- `quotations`
- `quotation_lines`

They are not yet a complete safe accounting implementation.

### Confirmed Finance Gaps

1. `record_purchase_invoice`, `record_sales_invoice`, and `recalculate_wac`
   are documented but not implemented.
2. There are no receipt/payment voucher posting RPCs.
3. Invoices and invoice lines still allow direct client insert/update through
   RLS policies.
4. Vouchers still allow direct client insert/update/delete.
5. Current cancellation policy is modeled as delete permission. Financial
   records must never be physically deleted after posting.
6. Invoice and voucher numbering has no concurrency-safe document sequence.
7. Confirmed invoice immutability is not enforced.
8. Voucher status, cancellation metadata, and reversal links do not exist.
9. Tax rates, tax classes, and invoice-line tax snapshots do not exist.
10. Financial foreign keys are not consistently tenant-safe composite keys.
11. Invoice type and party direction are not strongly enforced by the
    database.
12. Allocation rows do not enforce invoice party/direction compatibility.
13. The journal balance trigger does not by itself prove that every posted
    entry has at least two non-zero lines or that posting is immutable.
14. There is no idempotency key to prevent a network retry from creating a
    duplicate invoice or voucher.
15. There are no bounded finance list/detail RPCs or repositories.
16. There are no invoice, voucher, journal, or cash/bank routes/screens.
17. There is no JSON document-template schema or renderer.
18. There is no unit timeline view, serial reconciliation tool, or serial
    correction permission.
19. Product/unit barcodes are not protected by complete tenant-scoped
    uniqueness rules.
20. `quotations` are listed in the older Phase 5 build plan, but quotations are
    explicitly out of the strict v1 scope in `MVP_SCOPE.md` and
    `CANONICAL_DECISIONS.md`.

### Operational Gate From Phase 4

Before the first Phase 5 migration is trusted:

- repair or recreate the Docker Desktop data disk;
- run a clean `supabase db reset`;
- rerun every Phase 1, Phase 3, and Phase 4 SQL suite;
- record the exact passing baseline;
- keep cloud deployment as a separate release operation if credentials/project
  linking are still unavailable.

No Phase 5 schema work should be layered on an unverified local database.

---

## Scope

### In Scope

1. Internal generated product SKU.
2. Tenant serial settings and race-safe serial generation.
3. Serialized-stock reconciliation without stock double-counting.
4. Permission-gated audited serial correction.
5. Product-unit lifecycle events and canonical unit timeline.
6. Global barcode/QR/serial resolver.
7. Mobile camera and desktop scanner input using the same resolver service.
8. Structured JSON document templates and tenant document settings.
9. Flutter client-side A4, thermal 80mm, and asset-label rendering.
10. Tax enablement, tax rates, explicit product tax classes, and line
    snapshots.
11. Concurrency-safe financial document numbering.
12. Server-owned invoice calculations and rounding.
13. Persisted invoice drafts through RPCs.
14. Confirmed purchase invoices.
15. Confirmed sales invoices.
16. Receipt vouchers with FIFO, manual, and unallocated-credit modes.
17. Supplier/direct-account payment vouchers.
18. Safe invoice and voucher cancellation through reversals.
19. System-generated journal entry/detail screens.
20. Cash/bank account activity with running balance.
21. Customer invoice/voucher tab integration.
22. Supplier financial detail and basic statement integration.
23. Customer statement PDF using the shared renderer.
24. Arabic/English responsive UI and permission coverage.
25. SQL, Dart, widget, integration, performance, and manual close gates.

### Explicitly Out of Scope

The following are not Phase 5 completion blockers:

- quotations and quotation conversion;
- sales-return and purchase-return business workflows;
- unrestricted/manual journal entry creation;
- journal approval workflow;
- multi-currency invoices or FX accounting;
- VAT returns or tax filing;
- country-specific e-invoicing;
- ZATCA, FTA, or government API integrations;
- server/Edge PDF rendering and archived auto-send;
- WhatsApp/email delivery automation;
- visual document template editor;
- bank statement import and automatic bank matching;
- cheque lifecycle management;
- POS;
- contract billing and refill-generated invoices;
- mobile field collection workflow;
- full P&L, trial balance, and financial report suite;
- expanding serialized warehouse transfers unless a Phase 5 acceptance case
  proves it is required.

Quotations remain in the database for future use, but their direct-write
policies should not be expanded during this phase.

---

## Locked Accounting and Data Decisions

These decisions must be accepted in M0/M1 before implementation.

### 1. Posted Documents Are Immutable

- Draft invoices may be changed only through draft RPCs.
- Confirmed invoices cannot be edited.
- Confirmed vouchers cannot be edited.
- Journal entries and lines created by finance RPCs cannot be edited or
  deleted by clients.
- Corrections use cancellation/reversal or future return documents.

### 2. Financial Writes Are RPC-Only

Drop direct insert/update/delete RLS policies from:

- `invoices`
- `invoice_lines`
- `vouchers`
- `voucher_invoice_allocations`

Keep bounded/select access only. All writes must use `SECURITY DEFINER` RPCs
with explicit tenant and permission validation.

### 3. No Hard Delete

- Cancelling an invoice preserves the invoice and lines.
- Cancelling a voucher preserves the voucher and allocations.
- Reversal journal entries reference the original journal entry.
- Cancellation requires a non-empty reason and is audited.
- An unconfirmed invoice draft may be discarded through its RPC; this is the
  only Phase 5 invoice hard-delete case.

### 4. Persisted Drafts Do Not Receive Final Numbers

- Draft invoices use UUID identity only.
- `invoice_number` is assigned at confirmation.
- Confirmed/cancelled invoices must have a final number.
- Draft lines are recalculated and revalidated by the server on confirmation.

### 5. Document Numbers Are Server-Generated

Use a tenant-scoped `document_sequences` table and one internal helper.

Suggested v1 formats:

| Type | Format |
|------|--------|
| Sales invoice | `SI-000001` |
| Purchase invoice | `PI-000001` |
| Receipt voucher | `RV-000001` |
| Payment voucher | `PV-000001` |
| Journal entry | `JE-000001` |
| Internal product SKU | `SKU-000001` |
| Generated asset serial | configurable prefix + zero-padded number |

Sequence updates must be row-locked or use atomic upsert/returning semantics.
The client never proposes a final financial number.

### 6. Every Submit Is Idempotent

- Invoice and voucher RPCs accept `p_idempotency_key uuid`.
- `(tenant_id, idempotency_key)` is unique per document table.
- Repeating the same successful request returns the original document ID.
- Reusing one key with a different payload raises
  `idempotency_payload_mismatch`.

### 7. Money Math Is Server-Owned

The UI may preview totals, but PostgreSQL recomputes them.

For each line in v1:

```text
gross_amount = qty * unit_price
discount_amount = round(gross_amount * discount_pct / 100)
before_tax = gross_amount - discount_amount
tax_amount = round(before_tax * tax_rate / 100) when taxable
after_tax = before_tax + tax_amount
```

Invoice totals:

```text
subtotal = sum(gross_amount)
discount_amount = sum(line_discount_amount)
tax_amount = sum(line_tax_amount)
total = subtotal - discount_amount + tax_amount
```

Rules:

- Round each line using the tenant default currency decimal places.
- Sum rounded line values.
- Store `numeric(15,3)` values in the current v1 schema.
- Do not accept a client-supplied header total.
- V1 prices are tax-exclusive.
- V1 supports line-level percentage discount only.
- Negative prices, quantities, discounts, taxes, and totals are rejected.

### 8. Invoice Type Determines Party and Permission

- `sales` requires one active customer with an A/R account.
- `purchase` requires one active supplier with an A/P account.
- Sales RPC requires `invoices.create_sales`.
- Purchase RPC requires `invoices.create_purchase`.
- Viewing purchase documents is separately permissioned because it exposes
  business cost.

Legacy `invoices.create` can remain temporarily for migration compatibility,
but new code must use the specific permissions.

### 9. Purchase Posting

For a normal recoverable-tax purchase:

```text
Dr Inventory                         before-tax inventory value
Dr Input Tax Recoverable             recoverable tax
Cr Supplier A/P                      invoice total
```

Non-recoverable product tax is included in inventory acquisition cost and WAC.
An optional tax-expense account is reserved for future non-inventory expense
lines.

### 10. Sales Posting

Revenue side:

```text
Dr Customer A/R                      invoice total
Cr Sales Revenue                     before-tax net revenue
Cr Output Tax Payable                tax
```

Cost side:

```text
Dr Cost of Goods Sold                cost snapshot
Cr Inventory                         cost snapshot
```

For serialized products, `cost_price` is the specific unit purchase cost.
For non-serialized products, `cost_price` is the product WAC at confirmation.

### 11. WAC Rule

- Purchase confirmation updates WAC in the same transaction.
- Recoverable input tax is excluded from WAC.
- Non-recoverable product tax is capitalized into WAC.
- Sales do not recalculate WAC.
- Outbound sales use a frozen line cost snapshot.
- The purchase RPC must aggregate/lock affected products and warehouses in a
  stable order to reduce deadlock risk.

### 12. Serialized Product Rules

- Purchase quantity must be a whole number.
- The number of submitted/generated units must equal the line quantity.
- Each unit is created in the selected warehouse.
- Each unit references the purchase invoice.
- Creating purchase units must not call a helper that independently adds stock
  a second time.
- Selling a serialized product requires concrete unit IDs.
- Each sold unit must belong to the product and warehouse and be available.
- A serialized sales line has quantity equal to the number of selected units.
- A unit cannot be sold twice.

### 13. Allocation Rule

Receipt allocations support:

- FIFO: oldest due/open invoice first;
- manual: explicit invoice and amount rows;
- unallocated: amount remains customer credit.

Payment allocations support supplier purchase invoices using the same
direction-safe validation.

The sum of allocations:

- must be greater than or equal to zero;
- must not exceed voucher amount;
- must not exceed each invoice outstanding amount;
- must only target invoices for the voucher party;
- must only target confirmed/partially-paid documents of the correct direction.

### 14. `paid_amount` Is a Maintained Cache

`invoices.paid_amount` remains for list performance, but every voucher write or
cancellation recomputes it from active allocations in the same transaction.
Invoice status is then derived:

- `confirmed`: paid amount is zero;
- `partially_paid`: paid amount is greater than zero and less than total;
- `paid`: paid amount is greater than or equal to total;
- `cancelled`: cancellation completed.

### 15. Cancellation Is Conditional

Invoice cancellation is rejected when:

- active voucher allocations exist;
- any affected stock cannot be reversed safely;
- a serialized purchased unit has downstream activity;
- a serialized sold unit no longer satisfies the reversal preconditions;
- a later product movement makes purchase-WAC reversal unsafe.

For v1 purchase cancellation, require no later movement for each affected
product/warehouse after the invoice movement. Otherwise use a future purchase
return workflow.

Voucher cancellation:

- marks allocations inactive/reversed;
- recomputes invoice paid amounts and statuses;
- creates a reversal journal entry;
- marks the voucher cancelled;
- never deletes the original allocation rows.

### 16. Journal Is System-Generated in v1

Phase 5 provides journal viewing, filtering, source navigation, and balance
verification. Manual journal posting remains out of scope until an approval and
period-locking model is designed.

### 17. Accounting Periods

Phase 5 stores transaction dates and validates them, but full period close is
out of scope. M1 adds tenant-level `books_locked_through date`. All
posting/cancellation RPCs reject dates on or before the lock date. The setting
is nullable and manager/accounting-admin controlled.

### 18. Print Source Is Stored Data

PDFs render from confirmed document/detail DTOs returned by the repository.
The renderer must never recalculate accounting totals independently.

### 19. Arabic PDF Support Is a Release Requirement

- Bundle a licensed Arabic-capable font.
- Test RTL text, Arabic digits/Latin digits policy, long names, and mixed
  Arabic/English rows.
- Missing glyphs are a Phase 5 blocker.

### 20. Quotations Stay Deferred

Do not implement quotations inside Phase 5 merely because the old build plan
lists them. The strict MVP and canonical decisions exclude them.

---

## Milestone Overview

| Milestone | Name | Outcome |
|-----------|------|---------|
| M0 | Baseline, Safety, and Scope Lock | Verified Phase 4 base and locked finance rules |
| M1 | Finance Schema, Permissions, and Invariants | RPC-only, tenant-safe financial foundation |
| M2 | Asset Identity, Serial, Scan, and Timeline | Reliable serialized-asset identity foundation |
| M3 | JSON Templates and Print Renderer | Shared Arabic/English local print engine |
| M4 | Tax Foundation and Money Math | Historical tax snapshots and deterministic totals |
| M5 | Purchase Invoice Engine | Atomic purchase, stock, units, WAC, A/P, journal |
| M6 | Sales Invoice and Cancellation Engine | Atomic sale, stock-out, A/R, revenue, COGS |
| M7 | Voucher, Allocation, and Payment Engine | Receipt/payment cycle with reversals |
| M8 | Dart Finance Layer, Routes, and Localization | Testable application layer and guarded navigation |
| M9 | Finance UI and Cross-Module Integration | Operational desktop/mobile finance workflows |
| M10 | Hardening, Verification, and Phase Close | Proven accounting cycle and documented closure |

---

## M0 - Baseline, Safety, and Scope Lock

### Goal

Prove the starting database and Flutter application are clean before financial
migrations begin.

### Work

1. Recover/recreate Docker Desktop data.
2. Run a clean local Supabase reset.
3. Run every existing SQL verification suite in sequence.
4. Run localization generation, build runner, analyze, and Flutter tests.
5. Record the passing test count and migration head (`052`).
6. Record the current dependency versions.
7. Capture:
   - schema-only dump;
   - seed/data dump if useful;
   - migration list;
   - current permission catalog;
   - current protected system accounts.
8. Confirm tenant A has:
   - cash account `1101`;
   - bank account `1102`;
   - A/R parent `1201`;
   - inventory account `1301`;
   - A/P parent `2101`;
   - sales revenue `4101`;
   - COGS `5101`.
9. Lock every decision in the previous section.
10. Confirm quotations, manual journal, multi-currency, and server PDFs remain
    out of scope.
11. Create a rollback note for every planned migration.

### Required Evidence

- Clean reset output.
- Existing SQL suites pass.
- `flutter analyze` passes.
- `flutter test` passes.
- `git diff --check` passes.
- No unresolved Phase 4 schema blocker.

### Acceptance

- Migration `052` is the verified base.
- The database can be recreated from zero.
- Finance scope and accounting rules are no longer ambiguous.
- M1 can modify financial tables without relying on stale local state.

---

## M1 - Finance Schema, Permissions, and Invariants

### Goal

Turn the Phase 1 finance tables into a safe base for atomic posting.

### Suggested Migration

`053_phase_5_finance_foundation.sql`

### Schema Work

#### Document Sequences

Add `document_sequences`:

```text
tenant_id
sequence_key
prefix
next_value
padding
updated_at
```

Primary/unique key: `(tenant_id, sequence_key)`.

Add internal helper:

```text
next_document_number(sequence_key)
```

The helper is not executable directly by `authenticated`; only public posting
RPCs call it.

#### Invoice Hardening

Add or adjust:

- nullable `invoice_number` for drafts;
- `idempotency_key uuid`;
- `idempotency_payload_hash text`;
- `cancelled_at`;
- `cancelled_by`;
- `cancellation_reason`;
- `reversal_journal_entry_id`;
- `confirmed_at`/`confirmed_by` enforcement;
- optional `updated_at` for drafts;
- check: draft may have no number;
- check: confirmed/paid/partially-paid/cancelled must have number;
- check: totals and paid amount are non-negative;
- check: `paid_amount <= total`, except explicitly documented legacy cleanup;
- type/party checks for sales and purchase;
- unique partial indexes for idempotency and final number.

Add line snapshot fields:

- `gross_amount`;
- `discount_amount`;
- `before_tax_amount`;
- `after_tax_amount`;
- retain `cost_price` as frozen cost;
- optional `unit_ids jsonb` is not preferred; use one line/unit link strategy
  described below.

M4 adds `tax_rate_id`, `tax_rate`, `tax_class`, `taxable_amount`, and
`tax_amount` after `tax_rates` and the tax-class enum exist. M1 must not create
a forward FK to a table that is introduced only in M4.

For serialized sales, prefer one `invoice_line` per unit with `qty = 1` and
`product_unit_id` set. This keeps FKs, cost snapshots, cancellation, and audit
simple.

#### Voucher Hardening

Add:

- `voucher_status` enum: `confirmed`, `cancelled`;
- `status voucher_status not null default 'confirmed'`;
- `idempotency_key uuid`;
- `idempotency_payload_hash text`;
- `confirmed_at`;
- `confirmed_by`;
- `cancelled_at`;
- `cancelled_by`;
- `cancellation_reason`;
- `reversal_journal_entry_id`;
- positive amount check;
- direction/party checks.

Add allocation fields:

- `created_at`;
- `created_by`;
- `is_reversed boolean not null default false`;
- `reversed_at`;
- `reversed_by`;
- unique `(tenant_id, voucher_id, invoice_id)`;
- positive allocated amount check.

#### Journal Hardening

Add:

- `reversal_of_entry_id`;
- optional `reversed_by_entry_id`;
- reversal/cancellation values in `journal_source` for sales invoice, purchase
  invoice, receipt voucher, and payment voucher reversals;
- posted-entry immutability trigger;
- posted timestamp/user consistency checks;
- tenant-safe composite FKs;
- source/source_id indexes;
- entry number and idempotency/source uniqueness where applicable.

Replace or extend balance enforcement so posting verifies:

- at least two journal lines;
- every line has exactly one positive side;
- total debit equals total credit;
- every line tenant matches entry tenant;
- every account tenant matches entry tenant;
- posted entries cannot be changed or deleted.

#### Tenant-Safe Keys

Add required parent unique keys and composite FKs for:

- invoice -> customer/supplier/warehouse/journal;
- invoice line -> invoice/product/product unit;
- voucher -> customer/supplier/accounts/journal;
- allocation -> voucher/invoice;
- journal line -> journal entry/account.

Avoid parallel simple and composite FKs for the same relationship.

### Permissions

Add at minimum:

- `invoices.create_sales`
- `invoices.create_purchase`
- `invoices.view_sales`
- `invoices.view_purchase`
- `invoices.edit_draft`
- `invoices.cancel`
- `invoices.print`
- `invoices.override_min_price`
- `vouchers.create_receipt`
- `vouchers.create_payment`
- `vouchers.cancel`
- `vouchers.print`
- `journal.view`
- `cash_bank.view`
- `suppliers.view_ledger`
- `product_units.correct_serial`
- `product_units.reconcile_serials`
- `product_units.print_label`
- `settings.templates.view`
- `settings.templates.edit`
- `settings.tax.view`
- `settings.tax.edit`

Keep Manager full-access semantics. Users remain zero-permission by default.

### RLS and ACL

- Drop direct invoice/invoice-line/voucher/allocation write policies.
- Keep finance table selects permission/type aware.
- Revoke execute from `public` and `anon`.
- Grant only intended public RPCs to `authenticated`.
- Keep internal helpers ungranted.
- Add defense-in-depth triggers for immutable fields and posted rows.

### RPC Skeletons

Create signatures or stubs only after rules are locked:

- `save_invoice_draft(p_data jsonb)`
- `discard_invoice_draft(p_invoice_id uuid)`
- `record_purchase_invoice(p_data jsonb, p_idempotency_key uuid)`
- `record_sales_invoice(p_data jsonb, p_idempotency_key uuid)`
- `cancel_invoice(p_invoice_id uuid, p_reason text, p_idempotency_key uuid)`
- `record_receipt_voucher(p_data jsonb, p_idempotency_key uuid)`
- `record_payment_voucher(p_data jsonb, p_idempotency_key uuid)`
- `cancel_voucher(p_voucher_id uuid, p_reason text, p_idempotency_key uuid)`

Do not expose incomplete stubs to the UI. Signatures may be documented in M1
and implemented in M5-M7.

### SQL Test

Create:

`supabase/tests/phase_5_finance_foundation.sql`

Cover:

- direct writes denied;
- cross-tenant FKs rejected;
- invalid type/party combinations rejected;
- posted journal mutation rejected;
- unbalanced journal posting rejected;
- duplicate document number rejected;
- sequence concurrency behavior;
- anonymous/helper execute denied;
- expected authenticated RPC ACLs only.

### Acceptance

- No client can directly mutate posted finance tables.
- Every critical finance relationship is tenant-safe.
- Document numbering is race-safe.
- Posted journal entries are balanced and immutable.
- Permissions distinguish sales, purchase, voucher, journal, tax, template,
  and sensitive asset actions.

---

## M2 - Asset Identity, Serial, Scan, and Timeline

### Goal

Make serialized assets reliable before purchase invoices begin creating units.

### Suggested Migration

`054_phase_5_asset_identity_scan_timeline.sql`

### SKU

- Add internal SKU generation using `document_sequences`.
- Product create omits normal user-entered SKU.
- A before-insert trigger or server helper fills SKU.
- Existing SKU values remain unchanged.
- SKU becomes immutable after product creation.
- Remove SKU field from the normal product wizard.
- Keep SKU visible only in admin/diagnostic detail when useful.

### Serial Settings

Add to `tenant_settings` or a dedicated asset settings table:

- `serial_number_mode`: `manual`, `automatic`, `mixed`;
- `serial_number_prefix`;
- `serial_number_padding`;
- optional `next_serial_preview` must never be authoritative.

The server generates serials. The UI may preview only.

### Barcode Uniqueness

Add case-insensitive, trimmed, partial unique indexes for non-blank:

- tenant product barcode;
- tenant product-unit barcode;
- tenant unit serial already has a case-insensitive unique index and must remain
  canonical.

The resolver priority is:

1. unit barcode;
2. product barcode;
3. unit serial.

Within one priority level, ambiguity is an error.

### Serialized Stock Reconciliation

Add:

```text
preview_serialized_stock_reconciliation(product_id, warehouse_id)
reconcile_serialized_stock(product_id, warehouse_id, serial_inputs, reason)
```

Rules:

- manager or `product_units.reconcile_serials`;
- product must be active and serialized;
- available balance must be a whole number;
- compare available units in that warehouse to `qty_available`;
- only create the positive missing difference;
- never update inventory balance;
- never create purchase/adjustment movements;
- create one manual `unit_event` per reconcile batch or unit;
- require reason;
- audit actor, before count, after count, and generated serials;
- reject if unit count exceeds balance or if non-available buckets are
  inconsistent.

### Serial Correction

Add:

```text
correct_product_unit_serial(unit_id, new_serial, reason)
```

Rules:

- explicit permission;
- non-empty reason;
- uniqueness check;
- immutable tenant/product identity;
- audit old and new values;
- create a unit event;
- no stock delta.

### Unit Events

Add `unit_events` for manual events with no natural source:

```text
id
tenant_id
product_unit_id
event_type
occurred_at
warehouse_id
customer_id
service_location_id
contract_id
reference_table
reference_id
notes
metadata_json
created_by
created_at
```

Do not duplicate events that already have a source table.

### Unit Timeline

Add `v_unit_timeline` as `security_invoker = true`, combining available sources:

- unit creation/acquisition;
- purchase invoice;
- inventory movements;
- serial correction/reconciliation events;
- future contracts;
- future visits;
- future maintenance;
- selected unit audit events.

Canonical shape:

```text
tenant_id
product_unit_id
event_type
occurred_at
source_table
source_id
warehouse_id
customer_id
service_location_id
contract_id
title_key
notes
metadata_json
```

### Scan Resolver

Add:

```text
resolve_scan_code(p_code text)
```

Return a small typed result:

```json
{
  "kind": "product|product_unit",
  "id": "uuid",
  "product_id": "uuid",
  "matched_by": "unit_barcode|product_barcode|serial_number",
  "display_code": "text",
  "is_active_or_available": true
}
```

The resolver:

- trims input;
- applies tenant scope;
- does not leak objects without the relevant view permission;
- reports `scan_not_found`;
- reports `scan_ambiguous`;
- does not mutate data.

### Flutter Structure

Suggested files:

```text
lib/core/scanning/domain/scan_result.dart
lib/core/scanning/data/scan_repository.dart
lib/core/scanning/presentation/scan_controller.dart
lib/core/scanning/presentation/scan_input.dart
lib/core/scanning/presentation/mobile_scan_sheet.dart
lib/features/products/presentation/product_unit_detail_screen.dart
lib/features/products/presentation/product_unit_timeline_controller.dart
```

Desktop keyboard-wedge input and mobile camera must call the same repository.

### Tests

Create:

`supabase/tests/phase_5_asset_identity.sql`

Cover:

- SKU generation and immutability;
- serial modes;
- reconciliation with no balance change;
- no over-reconciliation;
- serial correction permission/reason/audit;
- barcode uniqueness;
- resolver priority and not-found behavior;
- cross-tenant isolation;
- timeline rows.

Dart/widget tests:

- scan result parsing;
- scan controller states;
- desktop scan input;
- mobile scanner callback;
- unit timeline parsing;
- permission-gated serial actions;
- 360x800 Arabic unit detail.

### Acceptance

- Existing serialized stock can be reconciled without increasing stock.
- Product barcode resolves to product.
- Unit barcode/serial resolves to product unit.
- Unit timeline shows acquisition and manual correction/reconcile events.
- SKU is automatically generated and hidden from normal product create/edit.
- Serial correction is permission-gated, reason-required, and audited.

---

## M3 - JSON Templates and Print Renderer

### Goal

Create one safe document model and one client-side renderer used by all Phase 5
documents.

### Suggested Migration

`055_phase_5_document_templates.sql`

### Database

Add `document_templates`:

```text
id
tenant_id
template_key
document_type
name_ar
name_en
language_mode
paper_kind
schema_version
body_json
is_default
is_active
created_at
created_by
updated_at
updated_by
```

Add `tenant_document_settings`:

```text
tenant_id
logo_url
primary_color
secondary_color
default_language
invoice_paper_kind
voucher_paper_kind
asset_label_paper_kind
header_json
footer_json
optional_columns_json
updated_at
updated_by
```

### JSON Rules

- Use a versioned schema.
- Allow only known block types.
- Reject unknown dynamic expressions.
- Reject arbitrary HTML/scripts.
- Validate required fields per document type.
- Store placeholders as a fixed allowlist.
- Keep layout settings bounded.
- Keep template changes audited.
- Template edit requires `settings.templates.edit`.

Suggested block types:

- `spacer`
- `divider`
- `tenant_header`
- `document_meta`
- `party_details`
- `line_table`
- `totals`
- `payment_details`
- `notes`
- `footer`
- `asset_identity`
- `qr_code`

### Initial Templates

Seed:

- `sales_invoice_a4`
- `purchase_invoice_a4`
- `receipt_voucher_a4`
- `receipt_voucher_80mm`
- `customer_statement_a4`
- `asset_tag_label`

Template settings are editable; the visual block editor is not.

### Flutter Dependencies

Add:

- `pdf`
- `printing`

Bundle a licensed Arabic font family under assets. Do not rely on host fonts.

### Flutter Structure

```text
lib/core/documents/domain/document_template.dart
lib/core/documents/domain/document_payload.dart
lib/core/documents/domain/document_kind.dart
lib/core/documents/data/document_template_repository.dart
lib/core/documents/services/document_template_validator.dart
lib/core/documents/services/pdf_document_renderer.dart
lib/core/documents/services/pdf_font_registry.dart
lib/core/documents/presentation/document_preview_screen.dart
```

Keep finance-specific payload mappers inside their feature modules.

### Renderer Requirements

- A4 portrait invoice/statement.
- A4 or thermal 80mm voucher.
- Configurable asset-label sheet.
- RTL Arabic and LTR English.
- Mixed-language product/customer names.
- Tenant logo with safe failure fallback.
- Currency symbol and precision from tenant currency.
- Page-break-safe line tables.
- Repeated table headers.
- Long notes wrapping.
- Print and share actions only when permission allows.

### Testing

- JSON schema validation fixtures.
- Unknown block rejection.
- Missing required field rejection.
- Golden or semantic PDF tests where stable.
- Assert generated bytes are non-empty and page count is expected.
- Arabic text shaping/glyph smoke test.
- Long invoice pagination.
- Thermal voucher width.
- QR payload equals human-readable serial text.

### Acceptance

- Sales invoice preview renders in Arabic and English.
- Receipt voucher renders on A4 and 80mm.
- Customer statement renders from existing statement data.
- Asset label includes tenant, product, serial, and QR.
- All renderers consume the same validated JSON template model.
- No server renderer or visual editor is required.

---

## M4 - Tax Foundation and Money Math

### Goal

Make invoice calculations historically stable and tax-ready before posting
RPCs are implemented.

### Suggested Migration

`056_phase_5_tax_foundation.sql`

### Database

Add tax settings:

- `tenant_settings.tax_enabled boolean not null default false`;
- `tenant_settings.tax_registration_number text`;
- `tenant_settings.default_tax_rate_id uuid`.

Add enum:

```text
product_tax_class:
  taxable
  zero_rated
  exempt
  non_taxable
```

Add `products.tax_class` with a safe default. For tax-disabled existing tenants,
default may be `non_taxable` until explicitly configured.

Add `tax_rates`:

```text
id
tenant_id
code
name_ar
name_en
rate
effective_from
effective_to
output_account_id
input_account_id
expense_account_id
is_recoverable
is_active
created_at
created_by
updated_at
updated_by
```

Add invoice-line tax snapshots:

- `tax_rate_id uuid`;
- `tax_rate numeric`;
- `tax_class product_tax_class`;
- `taxable_amount numeric(15,3)`;
- `tax_amount numeric(15,3)`;
- tenant-safe FK from invoice line tax rate to `tax_rates`;
- checks that snapshot amounts are non-negative and internally consistent.

The snapshot columns are populated by draft preview/final posting helpers, not
trusted from client totals.

Constraints:

- rate between 0 and 100;
- valid effective date range;
- unique tenant/code;
- tenant-safe account FKs;
- account types match expected posting direction;
- no overlapping effective ranges for the same logical code unless explicitly
  versioned;
- active default rate must belong to tenant.

### Protected Tax Accounts

Provision only when tax is enabled/configured:

- Input Tax Recoverable under Assets.
- Output Tax Payable under Liabilities.
- Optional non-recoverable tax expense account.

These are protected system accounts.

Do not force tax accounts on tax-disabled tenants.

### Tax Configuration RPCs

Suggested:

- `list_tax_rates(...)`
- `create_tax_rate(p_data jsonb)`
- `update_tax_rate(p_id uuid, p_data jsonb)`
- `deactivate_tax_rate(p_id uuid)`
- `update_tax_settings(p_data jsonb)`
- `get_effective_tax_rate(product_id, invoice_date)`

Historical referenced rates cannot be deleted or materially rewritten.
Changing a rate creates a new effective row/version.

### Money Calculation Helper

Add one server helper used by draft preview and final posting:

```text
calculate_invoice_totals(p_type, p_date, p_lines)
```

It returns normalized line snapshots and header totals. The public preview
variant must not expose purchase cost to callers without permission.

### Dart Domain

Create pure Decimal-based services mirroring server behavior:

```text
invoice_line_math.dart
invoice_totals.dart
tax_class.dart
tax_rate.dart
tax_settings.dart
```

Use shared fixture vectors to prove Dart/PostgreSQL parity.

### SQL Tests

Create:

`supabase/tests/phase_5_tax_foundation.sql`

Cover:

- tax disabled -> all tax amounts zero;
- taxable line;
- zero-rated line;
- exempt line;
- non-taxable line;
- line discount before tax;
- effective date selection;
- historical snapshot unchanged after rate update;
- output/input account tenant mismatch rejected;
- invalid account type rejected;
- rounding at currency precision;
- Dart/SQL fixture expected totals.

### Acceptance

- Server and Dart produce identical totals for the fixture suite.
- Old invoice snapshots do not change when tax configuration changes.
- Tax-disabled tenant works with zero tax.
- Purchase and sales posting account IDs are resolvable before M5/M6.
- No government filing/e-invoicing behavior is introduced.

---

## M5 - Purchase Invoice Engine

### Goal

Record a complete purchase atomically:

```text
invoice + lines + stock + serialized units + WAC + A/P + journal
```

### Suggested Migration

`057_phase_5_purchase_invoice_rpc.sql`

### RPC

Implement:

```text
record_purchase_invoice(p_data jsonb, p_idempotency_key uuid)
```

Optionally allow `p_data.invoice_id` for confirming an existing draft.

### Required Validation

- authenticated tenant exists;
- caller has `invoices.create_purchase`;
- idempotency key is valid;
- supplier exists, active, same tenant, and has active A/P account;
- warehouse exists, active, same tenant;
- date is not in locked period;
- due date is not before invoice date;
- at least one line;
- product exists, active, same tenant;
- product can be purchased/stocked;
- quantity positive;
- unit price non-negative;
- discount in allowed range;
- tax rate effective and same tenant;
- serialized quantity is whole;
- serialized unit count equals quantity;
- serial/barcode uniqueness;
- no duplicate line/unit identity;
- calculated total is positive unless an explicit zero-value business rule is
  later approved.

### Transaction Order

1. Resolve tenant, permission, currency precision, finance settings.
2. Check idempotency.
3. Normalize and validate payload.
4. Lock affected product and inventory rows in stable sorted order.
5. Calculate line/tax totals.
6. Generate purchase invoice number.
7. Insert confirmed invoice and line snapshots.
8. Insert/increment inventory balances.
9. Insert purchase inventory movements.
10. Create serialized `product_units` directly through an internal helper that
    does not add stock again.
11. Recalculate/update product WAC and last purchase cost.
12. Generate journal entry number.
13. Insert balanced A/P/inventory/input-tax journal entry.
14. Mark journal posted.
15. Link invoice to journal.
16. Write audit events.
17. Return a typed result with IDs/numbers/totals.

Any failure rolls back all steps.

### WAC

Implement an internal helper:

```text
recalculate_wac(product_id)
```

or a deterministic incremental helper shared with purchase posting.

Do not expose broad direct execute permission. If a manager repair RPC is
needed, wrap it with permission, reason, and audit.

### Drafts

`save_invoice_draft` for purchase:

- validates party/line shape;
- stores no stock movement;
- stores no journal;
- stores preview totals only;
- server recalculates again on confirmation;
- only creator or authorized finance user can edit, according to the locked
  permission model.

### Read RPCs

Add bounded:

- `list_purchase_invoices(filters, cursor/page, limit)`
- `get_purchase_invoice_detail(invoice_id)`

The list should return supplier label, status, date, due date, total, paid,
outstanding, currency metadata, and cancellation state.

### SQL Tests

Create:

`supabase/tests/phase_5_purchase_invoices.sql`

Cover:

- non-serialized purchase;
- serialized purchase;
- first-purchase WAC;
- subsequent-purchase WAC;
- recoverable tax;
- non-recoverable tax capitalization;
- duplicate submit idempotency;
- duplicate serial rollback;
- bad supplier/account/warehouse/product;
- cross-tenant IDs;
- fractional serialized quantity;
- unit count mismatch;
- journal balances;
- inventory movement reference;
- unit purchase invoice reference;
- direct write denied;
- permission denied;
- complete rollback after forced late failure.

### Acceptance

- Buying 100 units updates available stock and WAC exactly once.
- Buying serialized devices creates exactly one unit per purchased quantity.
- A/P and inventory/tax journal lines balance.
- Duplicate network submit cannot duplicate the purchase.
- Any validation/posting failure leaves no partial invoice, stock, unit, or
  journal data.

---

## M6 - Sales Invoice and Cancellation Engine

### Goal

Record a sale atomically and support safe reversal of posting mistakes.

### Suggested Migration

`058_phase_5_sales_invoice_rpc.sql`

### RPCs

Implement:

```text
record_sales_invoice(p_data jsonb, p_idempotency_key uuid)
cancel_invoice(p_invoice_id uuid, p_reason text, p_idempotency_key uuid)
```

`cancel_invoice` handles purchase or sales using type-specific safety rules.

### Sales Validation

- caller has `invoices.create_sales`;
- customer exists, active, same tenant, and has active A/R account;
- warehouse active and same tenant;
- product active and sellable;
- quantity positive;
- sufficient stock;
- unit price respects minimum price unless
  `invoices.override_min_price`;
- serialized lines contain concrete unit IDs;
- units match tenant/product/warehouse;
- units are in an available status;
- no repeated unit;
- tax snapshot is valid;
- date/due date valid;
- no locked period.

### Transaction Order

1. Resolve settings and idempotency.
2. Validate/normalize payload.
3. Lock product, unit, and inventory rows in stable order.
4. Recheck stock after lock.
5. Calculate totals.
6. Snapshot cost:
   - serialized: unit `purchase_cost`;
   - non-serialized: current product `avg_cost`.
7. Generate sales invoice number.
8. Insert confirmed invoice and line snapshots.
9. Decrease available balances.
10. Insert sale inventory movements.
11. Mark sold units `sold`, clear warehouse pointer, and set current customer
    when ownership trace is required.
12. Insert/post A/R, revenue, output-tax, COGS, and inventory journal lines.
13. Link invoice/journal and audit.
14. Return typed result.

### Cancellation

For sales:

- require `invoices.cancel`;
- require reason;
- reject already-cancelled document;
- reject active voucher allocations;
- lock all affected rows;
- require enough reversible state;
- restore non-serialized stock;
- restore serialized unit status/warehouse only if no downstream unit event
  makes reversal unsafe;
- insert reversal inventory movements;
- insert/post reversal journal;
- mark invoice cancelled;
- never delete rows.

For purchase:

- reject active allocations;
- require purchased units untouched;
- require no later affected product/warehouse movement;
- reverse inventory and WAC deterministically;
- create reversal journal;
- mark cancelled.

If safe cancellation is impossible, raise a specific error such as
`return_document_required`.

### Read RPCs

Add bounded:

- `list_sales_invoices(filters, cursor/page, limit)`
- `get_sales_invoice_detail(invoice_id)`
- optional unified `list_invoices` that applies type-aware permissions.

### SQL Tests

Create:

`supabase/tests/phase_5_sales_invoices.sql`

Cover:

- non-serialized sale;
- serialized sale;
- insufficient stock;
- unit/product mismatch;
- sold unit reuse;
- min-price denial/override;
- tax posting;
- COGS cost snapshot;
- WAC unchanged by sale;
- duplicate submit;
- cross-tenant denial;
- balanced journal;
- successful cancellation;
- cancellation blocked by payment;
- cancellation blocked by downstream unit activity;
- purchase cancellation safe/unsafe cases;
- rollback after forced failure.

### Acceptance

- A sale increases A/R and revenue.
- Inventory quantity/value decreases using frozen cost.
- Serialized unit identity is mandatory and cannot be reused.
- Sales journal balances including COGS.
- Safe cancellation fully reverses document effects without deleting history.

---

## M7 - Voucher, Allocation, and Payment Engine

### Goal

Complete the cash movement cycle and maintain invoice payment status safely.

### Suggested Migration

`059_phase_5_voucher_allocation_rpc.sql`

### Receipt RPC

Implement:

```text
record_receipt_voucher(p_data jsonb, p_idempotency_key uuid)
```

Payload includes:

- customer ID;
- date;
- amount;
- payment method;
- cash/bank account;
- reference number;
- notes;
- allocation mode;
- manual allocation rows when applicable.

Posting:

```text
Dr Cash/Bank
Cr Customer A/R
```

### Payment RPC

Implement:

```text
record_payment_voucher(p_data jsonb, p_idempotency_key uuid)
```

Support v1 destinations:

1. supplier A/P payment;
2. direct allowed account payment.

Employee/HR payment integration remains deferred.

Supplier posting:

```text
Dr Supplier A/P
Cr Cash/Bank
```

Direct account posting:

```text
Dr Selected allowed expense/liability/asset account
Cr Cash/Bank
```

Require stricter permission or manager access for direct-account payments if
the standard payment permission is considered too broad.

### Account Validation

Cash/bank account must:

- belong to tenant;
- be active;
- be an asset account;
- be a posting leaf;
- not be an entity-linked A/R/A/P subaccount;
- not be a protected category root.

Counterparty account must match the selected party and tenant.

### Allocation Engine

Implement internal helpers:

- `allocate_receipt_fifo`
- `validate_manual_allocations`
- `recompute_invoice_payment_state`

FIFO ordering:

1. due date, nulls after dated invoices;
2. invoice date;
3. invoice number;
4. ID as deterministic tie-breaker.

Use row locks on target invoices.

### Voucher Cancellation

Implement:

```text
cancel_voucher(p_voucher_id uuid, p_reason text, p_idempotency_key uuid)
```

Transaction:

1. validate permission/status/period;
2. lock voucher, allocations, and invoices;
3. mark allocations reversed;
4. recompute invoice paid/status values;
5. post reversal journal;
6. mark voucher cancelled;
7. audit.

### Read RPCs

Add bounded:

- `list_vouchers(filters, cursor/page, limit)`
- `get_voucher_detail(voucher_id)`
- `list_open_customer_invoices(customer_id)`
- `list_open_supplier_invoices(supplier_id)`
- `get_cash_bank_activity(account_id, date_from, date_to, cursor, limit)`

Cash/bank activity returns opening balance and running balance. It is an
activity/reconciliation view, not bank statement matching.

### SQL Tests

Create:

`supabase/tests/phase_5_vouchers.sql`

Cover:

- exact receipt allocation;
- partial allocation;
- FIFO allocation;
- manual allocation;
- overpayment/unallocated credit;
- wrong customer invoice;
- wrong invoice direction;
- allocation over outstanding;
- supplier payment;
- direct account payment;
- invalid cash account;
- invoice status transitions;
- voucher cancellation transitions;
- reversal journal;
- duplicate submit;
- permission/cross-tenant denial;
- concurrent allocation protection;
- rollback after late failure.

### Acceptance

- Receipt voucher reduces A/R and increases cash/bank.
- Payment voucher reduces A/P or posts to an allowed account.
- FIFO/manual/unallocated modes work.
- Invoice paid amounts/statuses stay consistent.
- Cancelling a voucher restores invoice outstanding values and posts reversal.

---

## M8 - Dart Finance Layer, Routes, and Localization

### Goal

Create a testable application layer before building large finance screens.

### Feature Structure

Suggested:

```text
lib/features/invoices/domain/
lib/features/invoices/data/
lib/features/invoices/presentation/

lib/features/vouchers/domain/
lib/features/vouchers/data/
lib/features/vouchers/presentation/

lib/features/journal/domain/
lib/features/journal/data/
lib/features/journal/presentation/

lib/features/finance_shared/domain/
lib/features/finance_shared/presentation/
```

Shared finance domain may contain:

- financial document status;
- payment method;
- party reference;
- date range;
- pagination cursor;
- currency/total display DTOs;
- typed finance error mapping.

Do not create one oversized repository for all finance behavior.

Implement the canonical `MoneyDisplay` widget and tenant currency context in
this milestone. Every finance amount must use the tenant currency symbol,
locale, symbol position, and decimal places rather than a hardcoded three-digit
formatter.

### Domain Models

At minimum:

- `InvoiceSummary`
- `InvoiceDetail`
- `InvoiceLine`
- `InvoiceDraft`
- `InvoiceTotals`
- `InvoiceType`
- `InvoiceStatus`
- `VoucherSummary`
- `VoucherDetail`
- `VoucherAllocation`
- `VoucherType`
- `VoucherStatus`
- `JournalEntrySummary`
- `JournalEntryDetail`
- `JournalLine`
- `CashBankActivityRow`
- `DocumentSequenceDisplay` only if required for diagnostics

All money and quantities use `Decimal`.

### Validators

Pure validators for:

- sales draft;
- purchase draft;
- serialized line/unit count;
- due date;
- discount;
- manual allocations;
- voucher amount/payment method/reference;
- cancellation reason;
- cash/bank account selection.

Database validation remains authoritative.

### Repositories

- Use RPCs for every mutation.
- Use bounded RPCs/selects for lists and details.
- Keep Supabase calls out of widgets.
- Map Postgres error codes to typed feature exceptions.
- Preserve idempotency key across retry until a definite result is known.
- Never generate document numbers in Dart.

### Controllers

Suggested controllers:

- invoice list;
- invoice form/draft;
- invoice detail;
- voucher list;
- voucher form;
- voucher detail;
- journal list/detail;
- cash/bank activity;
- tax settings;
- template settings;
- document preview.

Controllers own loading/error/submitting state. Screens own navigation and
SnackBars.

### Routes

Add:

```text
/invoices
/invoices/new/sales
/invoices/new/purchase
/invoices/:id
/vouchers
/vouchers/new/receipt
/vouchers/new/payment
/vouchers/:id
/journal
/journal/:id
/cash-bank
/product-units/:id
/settings/tax
/settings/templates
```

Guard every route using the specific permission, not only module visibility.

### Navigation

Add finance navigation entries only when the user can access them:

- Invoices
- Vouchers
- Journal
- Cash & Bank

Manager sees all. Users see only explicitly granted modules/actions.

### Localization

Add complete Arabic/English keys for:

- document types/statuses;
- party fields;
- line columns;
- tax classes/rates;
- totals;
- payment methods;
- allocation modes;
- journal source labels;
- cancellation/reversal;
- scan and serial actions;
- print/template settings;
- all database error codes.

No hardcoded UI strings in new finance screens.

### Tests

- model parsing;
- Decimal parsing;
- validators;
- repository payloads;
- idempotency retry behavior;
- controller state transitions;
- route guard matrix;
- navigation visibility;
- localization key parity.

### Acceptance

- Every Phase 5 route is permission guarded.
- Repositories contain all Supabase access.
- Domain and controller tests run without widgets/Supabase.
- No money calculation uses `double`.
- Arabic/English keys cover all user-visible finance states.

---

## M9 - Finance UI and Cross-Module Integration

### Goal

Deliver usable finance workflows on desktop and narrow mobile layouts.

### Invoice List

Filters:

- sales/purchase;
- status;
- date range;
- customer/supplier;
- overdue/open/paid;
- search by number/party/reference.

Columns/cards:

- number;
- type;
- party;
- date/due date;
- total;
- paid;
- outstanding;
- status;
- actions.

Use server pagination. Do not load all financial history.

### Sales Invoice Form

Sections:

1. customer and warehouse;
2. date and due date;
3. product lines;
4. serialized unit selection/scan;
5. quantity, price, discount, tax;
6. totals preview;
7. notes;
8. save draft/confirm.

Requirements:

- searchable product picker;
- scan product barcode;
- scan/select unit for serialized line;
- server preview or parity-tested local preview;
- explicit confirmation dialog;
- preserve idempotency key during submit/retry;
- navigate to detail on success.

### Purchase Invoice Form

Sections:

1. supplier and warehouse;
2. date, due date, supplier reference;
3. product lines;
4. quantity/cost/discount/tax;
5. serial mode and unit serial/barcode inputs;
6. totals;
7. notes;
8. save draft/confirm.

Bulk serial entry must validate count before confirmation.

### Invoice Detail

Show:

- immutable confirmed snapshot;
- party;
- lines;
- tax snapshots;
- totals;
- payment history;
- inventory movement links;
- serialized units;
- journal entry;
- cancellation/reversal state;
- PDF preview/print.

Actions:

- edit draft;
- confirm draft;
- cancel when allowed;
- print;
- open party;
- open journal.

### Voucher List and Forms

Receipt form:

- customer;
- amount;
- method/reference;
- cash/bank account;
- allocation mode;
- open invoice list;
- allocation total/unallocated credit preview;
- confirm.

Payment form:

- supplier or direct account mode;
- amount;
- method/reference;
- cash/bank account;
- open supplier invoices when relevant;
- confirm.

Voucher detail:

- party/account;
- allocations;
- journal;
- cancellation;
- A4/thermal print.

### Journal

Read-only list/detail:

- date range;
- source;
- entry number;
- description;
- total debit/credit;
- posted/reversal badges;
- source document navigation;
- line account drill-down.

Do not expose manual create/edit actions.

### Cash & Bank

- account picker limited to valid cash/bank posting accounts;
- date range;
- opening balance;
- debit/credit activity;
- running balance;
- source voucher/document link;
- export/print can use a basic table template if time permits.

### Customer 360

Replace placeholders:

- invoice tab -> bounded customer invoice list;
- voucher tab -> bounded customer receipt list;
- statement -> keep journal-backed data and add print;
- header -> outstanding balance remains journal-derived.

Do not require general `journal.view` for customer-specific statement access;
continue using `customers.view_ledger`.

### Supplier Detail

Replace placeholder with:

- profile;
- purchase invoices;
- payment vouchers;
- supplier statement/balance when `suppliers.view_ledger`;
- links to create purchase/payment document when permitted.

### Product and Unit Integration

- Purchase invoice appears in product/unit timeline.
- Unit detail opens from serialized invoice line.
- Asset label print from unit detail and batch from purchase detail.
- Scan result opens product or unit detail.

### Responsive UX

Wide desktop:

- data tables;
- side-by-side party/totals sections;
- sticky totals/action area where practical.

Narrow mobile:

- cards instead of horizontally clipped tables;
- step/section form layout;
- bottom confirmation action;
- compact allocation cards;
- print preview remains usable.

At minimum, test Arabic `360x800` and one wide desktop viewport for every main
screen.

### Widget and Integration Tests

- permission-based create buttons;
- sales form non-serialized;
- sales form serialized scan/select;
- purchase bulk serial count;
- invoice detail cancellation states;
- receipt FIFO/manual/unallocated UI;
- payment voucher modes;
- journal source navigation;
- customer/supplier tab data;
- print action permissions;
- Arabic mobile overflow;
- desktop table pagination.

### Acceptance

- A user can complete purchase, sale, receipt, and payment workflows without
  using SQL.
- Customer and supplier financial tabs show real bounded data.
- Journal source navigation works.
- Invoice/voucher/statement/asset-label printing works.
- Main screens are usable in Arabic mobile and desktop layouts.

---

## M10 - Hardening, Verification, and Phase Close

### Goal

Prove that Phase 5 is financially correct, secure, performant, and ready for
Phase 6 contracts.

### Database Verification

Run a clean reset, then all SQL suites in migration order:

- Phase 1 RLS;
- Phase 3 products/inventory;
- Phase 4 customer/supplier/CoA/location suites;
- Phase 5 finance foundation;
- Phase 5 asset identity;
- Phase 5 tax;
- Phase 5 purchase invoices;
- Phase 5 sales invoices;
- Phase 5 vouchers;
- final Phase 5 security/closure suite.

Suggested final suite:

`supabase/tests/phase_5_finance_closure.sql`

### Required End-to-End Scenario

Use deterministic fixture values:

1. Create or select supplier/customer accounts.
2. Purchase 100 non-serialized oil units.
3. Verify quantity, movement, WAC, A/P, and journal.
4. Purchase two serialized devices.
5. Verify two units, labels, timeline, and no double-counting.
6. Sell a quantity of oil.
7. Verify stock decrease, A/R, revenue, tax if enabled, COGS, and inventory.
8. Sell one serialized unit.
9. Verify required unit identity and sold state.
10. Record partial receipt with FIFO allocation.
11. Verify invoice partially paid.
12. Record remaining receipt.
13. Verify invoice paid.
14. Record supplier payment.
15. Verify A/P reduction and bank/cash movement.
16. Cancel a safe test voucher and verify complete reversal.
17. Cancel a safe test invoice and verify complete reversal.
18. Confirm unsafe cancellation cases are rejected.
19. Render Arabic/English invoice, voucher, statement, and asset label.
20. Verify journal entries balance at every step.

### Security Matrix

Test:

- manager full access;
- zero-permission user;
- sales-only user;
- purchase-only user;
- receipt-only user;
- payment-only user;
- journal-view user;
- customer-ledger user without journal permission;
- template editor;
- tax editor;
- serial correction/reconcile user;
- tenant B isolation;
- anonymous user.

### Concurrency and Retry

Test:

- duplicate idempotency key;
- two simultaneous sales against last stock;
- two simultaneous allocations against one outstanding invoice;
- document sequence concurrency;
- serial generation concurrency;
- WAC updates on concurrent purchases;
- lock ordering and deadlock retry behavior.

### Performance

Verify indexes and query plans for:

- invoice list by tenant/type/date/status;
- party invoice list;
- voucher list;
- open invoice allocation picker;
- journal list;
- cash/bank activity;
- unit scan lookup;
- unit timeline;
- tax effective-date lookup.

All list APIs must have bounded limits and stable ordering.

### Flutter Quality

Run:

```text
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test
flutter build windows
git diff --check
```

Run platform builds that are supported by the current workstation and record
environment-only failures separately.

### Quality Checklist

- No widget-level Supabase access.
- No money/quantity `double`.
- No client-generated final totals or document numbers.
- No direct finance table writes.
- No hard delete of posted financial data.
- No unbounded list query.
- No missing permission/route guard.
- No cross-tenant simple FK where composite alignment is required.
- No helper executable by unintended roles.
- No PDF renderer recalculation.
- No untranslated user-visible finance string.
- No ignored Arabic/mobile overflow.
- No swallowed database error without typed UI message.
- No file with unrelated responsibilities left oversized without review.

### Documentation Close

Update:

- `BUILD_PLAN.md`;
- `DATABASE_SCHEMA.md`;
- `PAYMENT_SYSTEM.md`;
- `PERMISSIONS.md`;
- `CANONICAL_DECISIONS.md` only if a canonical decision changed;
- `ai_memory.md`;
- this plan with actual migration names, test counts, and verification results.

### Phase 5 Done Means

- Asset serial/scan/label foundation is reliable.
- Tax and money calculations are deterministic.
- Purchase and sales invoices post atomically.
- Vouchers and allocations post atomically.
- Cancellations preserve history and reverse safely.
- Journal entries are balanced, immutable, and source-linked.
- Customer/supplier finance views are operational.
- Arabic/English PDFs print locally.
- Clean reset and all regression suites pass.
- Phase 6 can create rental contracts and future rental invoices on top of
  trusted customer, asset, inventory, and accounting foundations.

---

## Suggested Migration Sequence

| Migration | Responsibility |
|-----------|----------------|
| `053_phase_5_finance_foundation.sql` | sequences, statuses, tenant-safe FKs, permissions, RLS/ACL, journal invariants |
| `054_phase_5_asset_identity_scan_timeline.sql` | SKU/serial generation, reconcile/correct, scan resolver, unit events/timeline |
| `055_phase_5_document_templates.sql` | JSON templates and tenant document settings |
| `056_phase_5_tax_foundation.sql` | tax settings/rates/classes/snapshots and math helpers |
| `057_phase_5_purchase_invoice_rpc.sql` | purchase draft/confirm, units, stock, WAC, A/P journal |
| `058_phase_5_sales_invoice_rpc.sql` | sales confirm, stock-out, cost snapshot, A/R/revenue/COGS, cancellation |
| `059_phase_5_voucher_allocation_rpc.sql` | receipt/payment/allocation/cancellation |
| `060_phase_5_finance_views_hardening.sql` | bounded read RPCs/views, indexes, final ACL/trigger hardening |

Migration names are planned, not reserved. If implementation uncovers a reason
to split a migration, preserve dependency order and document the change.

---

## Suggested SQL Suites

| Test File | Primary Coverage |
|-----------|------------------|
| `phase_5_finance_foundation.sql` | schema, FKs, RLS, ACL, sequence, journal invariants |
| `phase_5_asset_identity.sql` | SKU, serial, reconcile, correct, resolver, timeline |
| `phase_5_tax_foundation.sql` | tax classes/rates/snapshots/math |
| `phase_5_purchase_invoices.sql` | purchase, units, balances, WAC, A/P, rollback |
| `phase_5_sales_invoices.sql` | sales, stock, cost, A/R, COGS, cancellation |
| `phase_5_vouchers.sql` | receipt/payment/allocation/cancellation |
| `phase_5_finance_closure.sql` | permissions, tenant isolation, regression, E2E invariants |

Every suite should use transactions and roll back its test data.

---

## Suggested Implementation Chunks

| Chunk | Milestones | Reason |
|-------|------------|--------|
| 1 | M0 + M1 | verify baseline and lock financial safety first |
| 2 | M2 | finish serialized identity before purchase invoice units |
| 3 | M3 | establish one print model before document screens |
| 4 | M4 | lock tax/math before invoice posting |
| 5 | M5 | purchase is the inventory/WAC foundation |
| 6 | M6 | sales consumes inventory cost and creates A/R/revenue |
| 7 | M7 | vouchers complete cash and allocation cycle |
| 8 | M8 | build typed application layer and guarded routes |
| 9 | M9 | deliver operational screens and integrations |
| 10 | M10 | reset, regression, E2E, performance, and close |

Do not start M5/M6 posting SQL before M4 money/tax fixtures pass.

---

## Manual Acceptance Matrix

| Area | Scenario | Expected |
|------|----------|----------|
| Permissions | zero-permission user opens invoices URL | redirected/blocked |
| Purchase | non-serialized purchase | stock/WAC/A/P/journal update once |
| Purchase | serialized quantity 2 with 2 units | exactly 2 units and one stock delta |
| Purchase | serialized quantity/serial mismatch | rejected with no partial data |
| Sales | quantity exceeds stock | rejected |
| Sales | serialized line without unit | rejected |
| Sales | valid sale | A/R, revenue, COGS, stock, journal correct |
| Price | below minimum without override | rejected |
| Tax | tax disabled | tax zero, totals correct |
| Tax | taxable line | snapshots and posting correct |
| Receipt | FIFO partial payment | oldest invoice partially/fully allocated |
| Receipt | overpayment | excess remains customer credit |
| Payment | supplier payment | A/P down, cash/bank down |
| Cancel | paid invoice cancellation | rejected until voucher reversal |
| Cancel | voucher cancellation | allocations/status/journal reversed |
| Journal | open source entry | balanced lines and source navigation |
| Scan | product barcode | opens/resolves product |
| Scan | unit QR/serial | opens/resolves unit |
| Serial | reconcile legacy units | unit count fixed, balance unchanged |
| Print | Arabic invoice | correct RTL/glyphs/totals |
| Print | thermal receipt | correct width and no clipping |
| Print | asset label | serial text equals QR payload |
| Customer | invoice/voucher tabs | real bounded customer data |
| Supplier | invoice/payment tabs | real bounded supplier data |
| Responsive | Arabic 360x800 | no overflow or unreachable action |

---

## Risk Register

### Risk 1 - Partial Financial Posting

Mitigation:

- one RPC transaction;
- no client orchestration;
- late-failure rollback tests.

### Risk 2 - Duplicate Submit

Mitigation:

- idempotency keys;
- payload hash;
- retry tests.

### Risk 3 - WAC Corruption

Mitigation:

- stable row locks;
- SQL-owned calculation;
- purchase concurrency tests;
- no sales recalculation.

### Risk 4 - Serialized Double-Counting

Mitigation:

- purchase helper creates units without separate balance delta;
- reconciliation tool never changes balances;
- explicit unit-count invariants.

### Risk 5 - Cross-Tenant Accounting

Mitigation:

- composite FKs;
- RPC tenant checks;
- tenant B test cases in every SQL suite.

### Risk 6 - Unsafe Cancellation

Mitigation:

- reversal documents/entries;
- dependency checks;
- no hard delete;
- `return_document_required` when reversal is not safe.

### Risk 7 - Rounding Drift

Mitigation:

- line-first rounding rule;
- currency precision;
- shared SQL/Dart fixtures;
- stored snapshots.

### Risk 8 - Permission Leakage

Mitigation:

- split sales/purchase permissions;
- purchase document sensitivity;
- customer ledger RPC independent of broad journal view;
- route/widget/RLS matrix.

### Risk 9 - Arabic PDF Failure

Mitigation:

- bundled font;
- RTL tests;
- real printer/PDF acceptance before close.

### Risk 10 - UI Scope Expansion

Mitigation:

- no quotations;
- no visual template editor;
- no server PDFs;
- no manual journal;
- no bank-import reconciliation.

---

## Estimated Delivery

Approximate focused effort:

| Work | Estimate |
|------|----------|
| M0-M1 | 3-5 days |
| M2 | 4-6 days |
| M3 | 4-6 days |
| M4 | 3-5 days |
| M5 | 4-6 days |
| M6 | 4-6 days |
| M7 | 4-6 days |
| M8 | 3-5 days |
| M9 | 6-9 days |
| M10 | 3-5 days |

Total: approximately 38-59 focused development days before contingency. With
overlap, reusable patterns, and AI assistance, a practical target is 8-12
calendar weeks of concentrated work. Accounting correctness gates should not
be removed to meet the older three-week estimate.

---

## Starting Point for the Next Coding Session

Start with **M0 only**:

1. recover the local Docker/Supabase environment;
2. run a clean reset through migration `052`;
3. run all existing SQL suites;
4. run Flutter verification;
5. record the clean baseline in this plan and `ai_memory.md`;
6. then implement `053_phase_5_finance_foundation.sql`.

Do not start invoice UI or posting RPCs before the M0 baseline and M1 accounting
invariants are complete.
