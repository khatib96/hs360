# Phase 6 - Contracts Plan

> Purpose: build the professional contract engine that HS360 was created for:
> trial contracts, rental contracts, serialized rental assets, rental
> consumables, profitability snapshots, contract billing, and lifecycle control.
>
> Status: **M0 through M9 complete** (M9 closed 2026-07-11). M10 is the next
> implementation milestone.
>
> Owner directive: contracts are the core business workflow, not an auxiliary
> module. Phase 6 must be treated with the same accounting and operational
> seriousness as Phase 5 finance.
>
> Canonical sources: `CANONICAL_DECISIONS.md`, `CONTRACTS_LOGIC.md`,
> `PAYMENT_SYSTEM.md`, `DATABASE_SCHEMA.md`, `MVP_SCOPE.md`,
> `CAPABILITIES_DECISION_REPORT.md`, and the owner decisions captured in this
> file. If older documents conflict with this plan, M0 must update the older
> documents or explicitly record the supersession.

---

## Executive Summary

Phase 6 is the reason the system exists.

It must not be implemented as a basic contracts CRUD screen. A safe Phase 6
implementation creates a full contract operating model:

1. Trial contracts can be issued, tracked, converted, extended, or returned.
2. Rental contracts can be fixed-term, 12-month by default, or open-ended.
3. A contract can include multiple serialized rental assets and multiple rental
   consumables.
4. Pricing remains simple for the user: the visible commercial price is the
   contract monthly rental value. Internal cost/profit calculations are computed
   by the system.
5. Internal pricing basis is configurable by tenant: rental assets can use
   actual unit cost, product average cost, or sale price; rental consumables can
   use sale price, average cost, or another approved cost basis.
6. Contract creation, conversion, return, closure, billing, and oil/consumable
   changes must be RPC-controlled, tenant-safe, permission-gated, idempotent
   where needed, and auditable.
7. Trial contracts are free to the customer, but they are not invisible to the
   business: assets leave stock, real usage/consumable events can be recorded
   when confirmed, and the outcome must be recorded.
8. Visits, refill confirmation, GPS/photo proof, mobile field flow, and payment
   collection are prepared by Phase 6 but executed in Phase 8 unless a later
   scope decision explicitly pulls in a smaller desktop confirmation flow.

The implementation should be divided into milestones `M0` through `M13`. Each
milestone ends with clear acceptance criteria. UI work should not begin until
the contract rules, pricing basis, permissions, and database lifecycle are
locked.

---

## What Phase 6 Means

At the end of Phase 6:

- A user can create a trial contract for a customer and service location.
- A user can create a rental contract with one or more devices and one
  or more rental consumables.
- Serialized assets are selected as concrete `product_unit_id` values, not only
  product rows.
- The system prevents a device that is unavailable, already rented, in trial,
  damaged, under maintenance, or tenant-mismatched from being assigned.
- The system snapshots customer/service-location details at signing.
- The system snapshots cost and profit at signing based on tenant contract
  settings.
- Low-profit contracts are rejected unless an authorized override is provided
  with a reason.
- A trial contract can be converted to a rental contract without re-entering the
  whole contract.
- A trial contract can be returned or extended with a reason.
- A rental contract can be closed and assets return to the correct inventory
  state.
- A rental contract can schedule or record a future consumable/oil change
  without rewriting history.
- Monthly rental invoices can be generated without duplicates.
- No receipt voucher is created unless payment is actually confirmed.
- Contract list, detail, creation, conversion, closure, and print surfaces exist
  in Arabic and English.
- Customer 360 shows real contract data instead of placeholders.

---

## Current Repository Inspection

### Confirmed Starting Point

- Phase 5 is complete through migration `076`.
- Core contract tables already exist from Phase 1:
  - `contracts`
  - `contract_lines`
  - `contract_oil_changes`
- Customer service locations exist and are linked to:
  - `contracts.service_location_id`
  - `visits.service_location_id`
  - `calendar_events.service_location_id`
  - `product_units.current_service_location_id`
- The service-location model is already tenant/customer safe through composite
  FKs added in Phase 4.
- Product units already have identity fields needed by rental assets:
  - serial number.
  - barcode.
  - current warehouse.
  - current customer.
  - current service location.
  - current contract.
  - purchase cost.
  - status.
- Product types already distinguish:
  - `sale_only`
  - `asset_rental`
  - `consumable_rental`
- Inventory balances already have buckets for:
  - `qty_available`
  - `qty_rented`
  - `qty_trial`
  - `qty_maintenance`
  - `qty_damaged`
- Phase 5 finance can already create customer invoices, vouchers, journal
  entries, returns, and PDF previews for financial documents.
- Customer 360 already has a contracts tab, but it is currently empty/read-only.
- Routing and app shell do not yet expose a real contracts module route.
- Existing seeded permissions include the basic contract set, but important
  permissions documented elsewhere need confirmation:
  - `contracts.close`
  - `contracts.approve_override`
  - any mobile-specific contract creation permission if needed later.

### Documentation Conflicts Reconciled In M0

M0 reconciled these before implementation:

1. `MVP_SCOPE.md` now includes trial contracts and basic trial lifecycle in v1.
2. Contract pricing docs now state that rental asset and rental consumable basis
   are tenant settings; default owner preference is unit purchase cost for
   rental assets and sale price for rental consumables.
3. Contract and payment docs now state that accounting depreciation and deep
   asset-consumption accounting are deferred beyond Phase 6.
4. Older Phase 6 text says refills are part of contracts, while the field refill
   workflow with GPS/photo/agent confirmation belongs mainly to Phase 8.
5. `RPC_SPEC.md` now supersedes the older positional `create_rental_contract`
   signature with a Phase 6 JSON/idempotency RPC surface.

---

## Owner Decisions Locked For Phase 6

These decisions come from the 2026-07-05 Phase 6 planning discussion and should
be treated as the current product direction.

1. Contracts are the core system workflow. The implementation must be practical,
   fast for office users, and professional enough for daily contract operations.
2. The system has exactly two contract types:
   - `عقد تجريبي` for `type = trial`.
   - `عقد إيجار` for `type = rental`.
3. `عقد` is only the generic module/document word. It is not a third contract
   type.
4. A 12-month term is a contract duration, not a separate database contract
   type and not the primary Phase 6 label.
5. A trial contract is free to the customer, but internally it still moves the
   asset and may later need internal cost/consumption reporting.
6. A trial contract can be converted to a rental contract by one explicit action.
   The user should not have to recreate all lines from scratch.
7. A contract can include more than one rental asset and more than one rental
   consumable.
8. Rental asset pricing/cost basis is configurable in contract settings.
9. Rental consumable pricing/cost basis is configurable in contract settings.
10. The pricing-setting UI may be built when the settings area is expanded, but
   the database and engine must support the settings from Phase 6.
11. Consumable replacement/refill does not reduce stock until the replacement is
    actually confirmed.
12. A receipt voucher does not exist until payment is actually confirmed.
13. Contract creation UI should feel like the existing invoice/document
    workflow: strong header, customer area, line editor, summary, command bar,
    and professional desktop density. It should not feel like an unrelated
    module.
14. Accounting depreciation and deep asset-consumption adjustments are deferred
    beyond Phase 6. Device consumption should be based on real usage activity
    when implemented later, not merely on elapsed time while the device is idle.

---

## Scope

### In Scope

1. Contract settings foundation for pricing basis and lifecycle defaults.
2. Permission catalog cleanup for missing contract actions.
3. Schema hardening for trial conversion, renewal references, billing periods,
   and lifecycle audit.
4. Rental asset and consumable cost/profit calculation engine.
5. Trial creation, return, extension, and conversion.
6. Rental contract creation.
7. Multi-asset and multi-consumable contract lines.
8. Serialized asset assignment with strict `product_unit_id` requirements.
9. Inventory bucket movement for trial/rented/returned/lost/damaged assets.
10. Current pointers on product units:
    - `current_contract_id`
    - `current_customer_id`
    - `current_service_location_id`
    - `current_warehouse_id`
11. Contract list, detail, create, convert, close, and oil/consumable-change UI.
12. Customer 360 contract tab integration.
13. Monthly rental invoice generation using Phase 5 finance engine.
14. Contract PDF preview/print.
15. Calendar/visit handoff records needed for Phase 7/8, without building the
    full mobile visit workflow.
16. SQL, domain, repository, route, widget, and integration tests.

### Out Of Scope

Do not build these in Phase 6 unless the scope is explicitly changed:

- Full mobile field refill flow.
- GPS verification.
- Camera-only visit photo capture.
- Offline sync.
- Route optimization or map clustering.
- Full calendar UI beyond the handoff needed by contracts.
- WhatsApp sending automation.
- Visual contract-template editor.
- Full depreciation ledger automation unless accepted as a separate accounting
  block.
- POS.
- Maintenance module.
- HR/commissions.

---

## Core Business Rules

### Contract Types

The existing enum has:

```text
trial
rental
```

Keep this enum unless implementation finds a hard blocker.

Use UI labels and term fields to express exactly two contract types:

- `عقد تجريبي` / `trial`.
- `عقد إيجار` / `rental`.

Use term fields, not type values, to express:

- 12-month rental.
- fixed-term rental.
- open-ended rental.

Do not add a separate 12-month/annual enum value unless there is a unique
lifecycle or accounting rule that cannot be represented by `type = rental`,
`start_date`, and `end_date`.

### Trial Contracts

A trial contract:

- has `type = trial`;
- has no customer invoice by default;
- requires customer and service location;
- may include one or more rental assets;
- may include expected/default consumables, but consumable stock should not be
  reduced unless a real confirmed replacement/refill happens;
- moves selected devices to `unit_status = trial`;
- increments `inventory_balances.qty_trial`;
- stores enough dates, asset links, and outcome data for future usage/cost
  reporting;
- can end as:
  - converted to rental.
  - returned.
  - extended.
  - expired.

Trial usage/cost reporting is important but should not block the first
operational trial workflow. Phase 6 records enough data to support later
reporting, but it does not post accounting depreciation or deep asset-consumption
adjustments.

### Rental Contracts

A rental contract:

- has `type = rental`;
- can be open-ended or fixed-term;
- can use a 12-month default term;
- carries one visible monthly rental value for the contract;
- has lines that describe assets and consumables included in the contract;
- may include multiple asset lines and multiple consumable lines;
- generates rental invoices through the billing engine;
- remains linked to customer-level A/R and customer statement;
- does not auto-create payment vouchers.

### Pricing Basis

Product records do not carry a customer-facing rental price.

The user enters the contract monthly rental value. The engine calculates
internal basis and profit using tenant settings:

```text
monthly_revenue = contract.monthly_rental_value
monthly_cost    = asset_monthly_basis + consumable_monthly_basis
monthly_profit  = monthly_revenue - monthly_cost
```

Recommended default settings:

| Setting | Default | Meaning |
|---------|---------|---------|
| rental asset basis | `unit_purchase_cost` | Use the selected device's actual purchase cost when available |
| rental consumable basis | `sale_price` | Use the product sale price converted by unit/quantity |
| min monthly profit | existing `tenant_settings.min_monthly_profit` | Minimum allowed expected monthly profit |
| default contract term | `12` months | UI default term for rental contracts |
| default trial days | existing `tenant_settings.default_trial_days` | Trial duration default |

Allowed pricing-basis values should be explicit, not free text:

```text
rental_asset_cost_basis:
  unit_purchase_cost
  product_avg_cost
  product_sale_price

rental_consumable_cost_basis:
  product_sale_price
  product_avg_cost
  product_last_purchase_cost
```

The selected basis must be snapshotted on the contract or contract lines so a
later settings change does not rewrite historical profit.

### Depreciation And Usage Boundary

Phase 6 does not implement accounting depreciation.

The configured lifespan, such as 24 months, is used only as a pricing/profit
basis when the selected contract setting needs a monthly asset basis. It is not
a guarantee that the device is consumed after 24 months. A device can remain
useful for 30 months or more.

Future depreciation or asset-consumption accounting must be based on real usage
activity and accepted accounting rules. If a device is idle and not used, Phase
6 must not consume depreciation merely because time passed.

### Profit Visibility

Cost and profit snapshots are sensitive.

Users without the relevant field permissions can create or view contracts
without seeing internal cost/profit details. Users with permissions can see:

- asset monthly basis.
- consumable monthly basis.
- total monthly cost.
- expected monthly profit.
- whether an override was used.

### Low-Profit Overrides

If `monthly_profit < tenant.min_monthly_profit`:

- a normal user receives a stable `below_min_profit` validation error.
- an authorized user can override only with a required reason.
- the contract records:
  - `min_profit_overridden = true`
  - `override_approved_by`
  - `override_approved_at`
  - `override_reason`
- audit log records the override.

The request-manager-approval workflow can be added later if needed; Phase 6
should first implement the direct authorized override path.

### Confirmed Events Only

The system must distinguish schedule from confirmation:

- A planned refill/consumable replacement does not reduce stock.
- A planned collection does not create a voucher.
- A planned oil change does not rewrite the current line until it becomes
  effective or is confirmed by the allowed workflow.
- Confirmed field actions belong mainly to Phase 8.

---

## Suggested Schema Additions

Exact SQL should be finalized during implementation, but Phase 6 should expect
some or all of these additions.

### Tenant Contract Settings

Add to `tenant_settings` or a dedicated `tenant_contract_settings` table:

```text
rental_asset_cost_basis
rental_consumable_cost_basis
default_contract_term_months
first_rental_invoice_policy
record_trial_usage_facts
track_rental_depreciation (reserved, default false)
allow_multi_asset_contracts
allow_multi_consumable_contracts
updated_at
```

Recommended defaults:

```text
rental_asset_cost_basis = unit_purchase_cost
rental_consumable_cost_basis = product_sale_price
default_contract_term_months = 12
first_rental_invoice_policy = first_billing_day
record_trial_usage_facts = true
track_rental_depreciation = false
allow_multi_asset_contracts = true
allow_multi_consumable_contracts = true
```

`track_rental_depreciation` is reserved only. Phase 6 must not post depreciation
journal entries.

`first_rental_invoice_policy` should allow at least:

```text
on_activation
first_billing_day
manual
```

### Contract Lifecycle References

Add fields if missing:

```text
converted_from_contract_id
converted_to_contract_id
renewed_from_contract_id
renewed_to_contract_id
extended_from_date
extension_reason
returned_at
returned_by
return_condition
return_reason
```

Use only the subset needed for the accepted workflow. Avoid overbuilding
columns that are not supported by UI/RPC tests.

### Pricing Snapshots

Add fields or structured metadata to capture:

```text
snapshot_pricing_policy
snapshot_asset_cost_basis
snapshot_consumable_cost_basis
snapshot_asset_lifespan_months
snapshot_trial_cost_basis
```

At line level, capture:

```text
snapshot_source_cost
snapshot_cost_basis
snapshot_lifespan_months
snapshot_monthly_cost
```

The existing `snapshot_unit_cost` and `snapshot_monthly_cost` can be reused if
they are sufficient, but the cost basis itself must be recoverable.

### Billing Period Safety

Rental invoices need duplicate protection per contract and period.

Options:

1. Add period columns to `invoices`:

   ```text
   billing_period_start
   billing_period_end
   ```

   with a unique partial index for rental monthly invoices:

   ```text
   unique (tenant_id, contract_id, billing_period_start)
   where type = 'rental_monthly'
   ```

2. Or add a dedicated `contract_billing_runs` table that records generated
   periods and the resulting invoice id.

Prefer the simplest option that matches Phase 5 invoice constraints and makes
idempotent billing easy to test.

---

## RPC Surface

Phase 6 should expose contract operations through RPCs. Widgets should not write
directly to contract, contract-line, product-unit, balance, movement, invoice,
or journal tables.

Suggested RPCs:

```text
preview_contract_profit(p_data jsonb) returns jsonb
create_trial_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
create_rental_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
convert_trial_to_rental(p_data jsonb, p_idempotency_key uuid) returns uuid
extend_trial_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
return_trial_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
close_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
schedule_contract_consumable_change(p_data jsonb, p_idempotency_key uuid) returns uuid
generate_rental_invoice(p_data jsonb, p_idempotency_key uuid) returns uuid
run_rental_billing_for_date(p_date date default current_date) returns jsonb
list_contracts(p_filters jsonb, p_cursor text default null, p_limit int default 50)
get_contract_detail(p_contract_id uuid) returns jsonb
```

Public RPCs must:

- derive tenant from `current_tenant_id()`;
- validate permissions with `user_has_permission()`;
- validate customer/service-location alignment;
- validate all selected products and units belong to the current tenant;
- reject unavailable units;
- reject missing unit ids for serialized assets;
- use stable application errors;
- use idempotency for mutating operations that can be retried;
- create audit entries;
- avoid leaking sensitive cost/profit fields to users without field permissions.

---

## UI Principles

The contract UI must preserve the HS360 identity and the Phase 5 finance
workflow language.

### Contract Form

The contract form should feel related to invoice and document screens:

- top document header.
- customer and service-location block.
- contract type/term/billing block.
- line editor for assets and consumables.
- right-side or bottom summary panel.
- command bar for save/preview/print.
- responsive desktop density.
- Arabic/English labels through ARB files.

Avoid making the first version a disconnected marketing-style wizard. A stepper
can be used only if it improves focus without slowing normal office entry.

### Contract Lines

The line editor should support:

- asset lines:
  - product.
  - selected unit/serial.
  - current warehouse.
  - status.
  - optional note.
- consumable lines:
  - product.
  - quantity per refill/replacement.
  - unit display.
  - frequency.
  - current/default consumable marker.

Line prices are not customer-facing. Internal costs/profit appear only in the
summary when permissions allow it.

### Contract Detail

Recommended tabs:

- Overview.
- Assets.
- Consumables.
- Invoices.
- Vouchers.
- Schedule.
- History.
- Documents.

Customer 360 should show a compact contract list and link into the full detail
screen.

---

## Milestone Overview

| Milestone | Name | Result |
|-----------|------|--------|
| M0 | Baseline, Scope Lock, and Decision Reconciliation | Phase 6 rules are canonical and old doc conflicts are resolved |
| M0.5 | Safety Snapshot and Rollback | Clear rollback point before migrations |
| M1 | Contract Settings, Permissions, and Schema Hardening | Database can represent professional contract rules |
| M2 | Pricing and Profit Engine | Contract cost/profit can be previewed and tested |
| M3 | Trial and Rental Creation RPCs | Trial/rental creation is atomic and inventory-safe |
| M4 | Trial Conversion, Return, Extension, and Closure RPCs | Lifecycle changes are safe and auditable |
| M5 | Rental Billing Engine | Monthly invoices can be generated without duplicates |
| M6 | Domain Models, Validators, and Repositories | Flutter data layer is ready without widget-level Supabase access |
| M7 | Routes, Navigation, and Customer 360 Integration | Contract module is reachable and permission-gated |
| M8 | Contract List and Detail UI | Users can search, inspect, and manage existing contracts |
| M9 | Contract Form UI | Users can create trial/rental contracts efficiently |
| M10 | Trial Conversion and Lifecycle UI | Users can convert, return, extend, and close contracts |
| M11 | Contract PDF and Document Preview | Contracts can be previewed/printed |
| M12 | Calendar/Visit Handoff | Phase 7/8 receive clean contract schedule data |
| M13 | Verification and Phase Close | SQL, Dart, widget, and acceptance gates pass |

---

## M0 - Baseline, Scope Lock, and Decision Reconciliation

### Goal

Start Phase 6 on a verified Phase 5 base and make this file the Phase 6 source
of truth.

### Work

1. Confirm Phase 5 close state:
   - latest migration is `076`;
   - Phase 5 SQL suites pass;
   - Dart analysis passes;
   - Flutter tests pass.
2. Update `BUILD_PLAN.md` to link this plan.
3. Update or annotate older docs that conflict with this plan:
   - `MVP_SCOPE.md` trial contract scope.
   - `CONTRACTS_LOGIC.md` pricing basis.
   - `RPC_SPEC.md` Phase 6 RPC signatures.
4. Confirm the accepted Phase 6 vocabulary:
   - trial contract.
   - rental contract.
   - exactly two contract types.
   - 12-month term as duration, not a separate contract type.
5. Record that Phase 6 prepares schedule/visit handoff data, while actual
   consumable replacement confirmation, stock-out, and payment collection remain
   Phase 8 unless later scope changes.
6. Record that depreciation posting and deep asset-consumption accounting are
   deferred beyond Phase 6.
7. Record the exact migration number where Phase 6 starts. Expected: `077`.

### Acceptance

- Phase 6 decisions are no longer ambiguous.
- Trial contracts are explicitly accepted for Phase 6.
- Pricing-basis defaults are accepted.
- Depreciation accounting is explicitly deferred.
- Visit/refill/payment confirmation is left to Phase 8; Phase 6 only prepares
  contract schedule handoff data.
- No code or schema work starts on stale Phase 5 state.

---

## M0.5 - Safety Snapshot and Rollback

> Status 2026-07-05: baseline recorded. Last pre-Phase-6 migration is `076`;
> first Phase 6 migration is expected to be `077`. The migration list and
> rollback notes were captured locally under ignored `supabase/.temp/` files.
> A live schema dump was not captured from this Codex session because Docker API
> access was denied; run the schema dump command locally before applying the
> first Phase 6 migration in a live local database.

### Goal

Create a safe rollback point before changing contract schema or RPC behavior.

### Work

1. Capture migration list.
2. Capture schema snapshot if local Supabase is running.
3. Run `git status --short` and avoid mixing unrelated edits.
4. Record rollback notes in `ai_memory.md` or the implementation log if the
   session pauses.

### Local Snapshot Commands

Run these from the repo root when local Supabase/Docker is available:

```bash
npx --yes supabase db dump --local \
  --file supabase/.temp/phase_6_m0_5_pre_077_backup.sql

npx --yes supabase db dump --local --schema public \
  --file supabase/.temp/phase_6_m0_5_pre_077_schema.sql
```

Do not commit files from `supabase/.temp/`.

### Acceptance

- The last pre-Phase-6 migration is known:
  `076_phase_5_voucher_protected_account_guard.sql`.
- The first Phase 6 migration number is known:
  `077_phase_6_contract_settings_permissions.sql`.
- Rollback path is clear before schema changes.
- Schema dump is either captured locally or explicitly documented as blocked by
  unavailable local Docker/Supabase access.

---

## M1 - Contract Settings, Permissions, and Schema Hardening

**Status: complete** (migration `077_phase_6_contract_settings_permissions.sql`).

### Goal

Make the database capable of representing the accepted contract rules before
building the engine or UI.

### Delivered migration

Single migration `077` (consolidates the originally suggested `077` + `078`):

```text
077_phase_6_contract_settings_permissions.sql
```

### Implementation choices (M1)

1. **Contract types:** exactly two — `trial` (عقد تجريبي) and `rental` (عقد إيجار).
   `عقد` is the generic module label only.
2. **Settings:** eight columns on `tenant_settings` (not a separate settings table).
3. **Permissions:** seven new catalog rows with `sort_order` `140–146`:
   `contracts.close`, `contracts.approve_override`, `contracts.convert_trial`,
   `contracts.extend_trial`, `contracts.return_trial`, `contracts.print`,
   `contracts.field.snapshot_total_cost`.
4. **Line basis enum:** `contract_line_cost_basis` has four unique labels;
   line-type check enforces asset vs consumable allowed values.
5. **Billing duplicate prevention:** `invoices.billing_period_start/end` plus
   partial unique index `ux_invoices_rental_contract_period` (no
   `contract_billing_runs` table).
6. **`return_condition`:** contract-level summary only; per-unit return state
   deferred to M4 (`contract_line` / `product_unit`).
7. **SQL tests:** `supabase/tests/phase_6_contract_settings_permissions.sql`
   (Phase H in `scripts/test/run_sql_suites.sh`).

### Deferred from original M1 work list

- Snapshot immutability triggers after activation.
- RLS/ACL write hardening beyond existing policies.
- `contracts_safe` view / detail RPC field masking.

**M3 shipping gate:** contract creation RPCs must not ship until direct unsafe
writes are closed or RPC guards land in the M3/M4 hardening milestone.

### Suggested Migrations (superseded)

```text
077_phase_6_contract_settings_permissions.sql   ← delivered (includes schema hardening)
078_phase_6_contract_schema_hardening.sql         ← merged into 077
```

### Work

1. Add or normalize contract settings:
   - rental asset cost basis.
   - rental consumable cost basis.
   - default contract term months.
   - first rental invoice policy.
   - trial usage-fact recording flag.
   - reserved rental depreciation flag only if needed for future accounting.
2. Add missing permissions:
   - `contracts.close`
   - `contracts.approve_override`
   - `contracts.convert_trial`
   - `contracts.extend_trial`
   - `contracts.return_trial`
   - `contracts.print`
   - optional `contracts.field.snapshot_total_cost`
3. Add lifecycle reference columns needed for:
   - conversion.
   - renewal.
   - return.
   - extension.
4. Add billing period fields or a billing-run table.
5. Add immutable/protection triggers for contract snapshot fields after
   activation/confirmation.
6. Harden RLS/ACL so direct unsafe writes are blocked where RPCs must own the
   operation.
7. Update `contracts_safe` or detail RPCs so sensitive snapshots remain hidden.

### Acceptance

- Settings have safe defaults for existing tenants.
- Required permissions are seeded.
- A contract can represent trial, rental, conversion, and billing-period state.
- Sensitive fields are not exposed through safe views.
- SQL tests prove unauthorized users cannot mutate contract lifecycle tables
  directly.

---

## M2 - Pricing and Profit Engine

### Goal

Build the pricing/profit calculation once, test it deeply, then reuse it in
preview and creation RPCs.

### Work

1. Implement database helpers for:
   - resolving contract settings.
   - resolving asset basis.
   - resolving consumable basis.
   - converting consumable quantities.
   - calculating line monthly cost.
   - calculating total monthly cost.
   - calculating expected monthly profit.
2. Support multiple assets and multiple consumables.
3. Respect serialized asset cost:
   - use `product_units.purchase_cost` when basis is `unit_purchase_cost`;
   - fall back only by documented rule if purchase cost is missing.
4. Support preview without writing:
   - `preview_contract_profit(p_data jsonb)`.
5. Hide cost/profit fields in preview unless the user has the correct
   permissions, while still returning pass/fail validation.
6. Add SQL tests for:
   - asset basis = unit purchase cost.
   - asset basis = product average cost.
   - asset basis = sale price.
   - consumable basis = sale price.
   - multiple assets.
   - multiple consumables.
   - below-min-profit.
   - authorized override.

### Acceptance

- Profit math is deterministic and rounded consistently.
- Existing product price/cost changes do not rewrite old snapshots.
- Preview and create use the same calculation code path.
- Low-profit validation is tested before UI work begins.

---

## M3 - Trial and Rental Creation RPCs

### Goal

Create trial and rental contracts atomically and safely.

### Suggested Migration

```text
079_phase_6_contract_creation_rpc.sql
```

### Work

1. Implement `create_trial_contract`.
2. Implement `create_rental_contract`.
3. Use JSON payloads instead of long positional signatures.
4. Validate:
   - tenant.
   - permission.
   - customer exists and belongs to tenant.
   - service location belongs to customer and tenant.
   - at least one asset line exists unless explicitly allowed otherwise.
   - serialized assets have `product_unit_id`.
   - units are available and not already assigned.
   - consumables are valid `consumable_rental` products.
   - billing/refill days are in allowed range.
5. Insert:
   - contract row.
   - asset lines.
   - consumable lines.
   - initial `contract_oil_changes` / consumable-current records.
   - audit log.
6. Update:
   - product unit status.
   - product unit current pointers.
   - inventory balance buckets.
7. Insert inventory movements:
   - trial out.
   - rental out.
8. For rental contracts, follow the accepted first-invoice policy.
9. Use idempotency keys to prevent duplicate contracts on retry.

### Acceptance

- Creating a valid trial moves the device to `trial`.
- Creating a valid rental moves the device to `rented`.
- Multi-asset and multi-consumable contracts work.
- Serialized asset without `product_unit_id` is rejected.
- Unavailable asset is rejected.
- Multi-location customer requires the chosen location and snapshots it.
- Below-min-profit rental is rejected unless override is allowed.
- Reusing idempotency key with same payload returns the same result.
- Reusing idempotency key with different payload raises
  `idempotency_payload_mismatch`.

---

## M4 - Trial Conversion, Return, Extension, and Closure RPCs

### Goal

Make contract lifecycle changes safe, auditable, and reversible only by proper
business operations.

### Suggested Migration

```text
080_phase_6_contract_lifecycle_rpc.sql
```

### Work

1. Implement `convert_trial_to_rental`.
   - Use the trial's existing customer, service location, assets, and
     consumables as defaults.
   - Allow editing monthly rental value and term before conversion.
   - Move units from `trial` to `rented`.
   - Move inventory buckets from `qty_trial` to `qty_rented`.
   - Link the trial and rental records.
2. Implement `extend_trial_contract`.
   - Require reason.
   - Update trial end date.
   - Audit the extension.
3. Implement `return_trial_contract`.
   - Require asset return condition.
   - Move units back to available/used, damaged, lost, or maintenance based on
     condition.
   - Move inventory buckets correctly.
   - Close the trial.
4. Implement `close_contract`.
   - Support normal close and early termination.
   - Return assets to correct status.
   - Keep customer A/R open; do not clear debt automatically.
   - Cancel future generated schedule records when safe.
5. Keep direct client status updates blocked.

### Acceptance

- Trial converts to rental with no duplicate device assignment.
- Returned trial releases the device.
- Extended trial requires a reason.
- Closing a rental returns all assets correctly.
- Outstanding invoices remain owed after close.
- Audit log identifies who performed each lifecycle action.

---

## M5 - Rental Billing Engine

### Goal

Generate monthly rental invoices from active contracts without duplicates.

### Suggested Migration

```text
081_phase_6_rental_billing_rpc.sql
```

### Work

1. Implement `generate_rental_invoice`.
2. Implement `run_rental_billing_for_date`.
3. Determine billing period start/end from contract rules.
4. Create invoice type `rental_monthly` using Phase 5 invoice/journal engine.
5. Link invoice to:
   - customer.
   - contract.
   - service period.
6. Enforce duplicate prevention per contract and period.
7. Do not create a receipt voucher.
8. Respect paused/suspended/closed contracts.
9. Add SQL tests for duplicate prevention and journal balance.

### Acceptance

- Active contract due for billing creates one rental invoice.
- Re-running billing for the same date does not duplicate.
- Invoice posts balanced A/R and rental income journal entry.
- Closed or returned trial contracts do not bill.
- Generated invoice appears in contract detail and customer statement.

---

## M6 - Domain Models, Validators, and Repositories

### Goal

Build the Flutter contract application layer in the project style established
by earlier phases.

### Work

Create `lib/features/contracts/` with:

```text
domain/
data/
presentation/
```

Domain models should cover:

- contract summary.
- contract detail.
- contract type/status.
- contract lines.
- asset line draft.
- consumable line draft.
- contract draft.
- trial conversion draft.
- closure draft.
- pricing preview.
- contract filters.
- contract permissions.

Repositories should call RPCs only. No widget should call Supabase directly.

Validators should cover:

- required customer.
- required service location.
- at least one asset.
- serialized unit selection.
- valid monthly value for rental.
- valid trial dates.
- valid billing/refill days.
- closure reason/condition.
- override reason.

### Acceptance

- Domain tests cover validators and permission helpers.
- Repository mappers handle sensitive fields being absent.
- Fake repositories exist for widget/controller tests.
- No contract widget imports Supabase client directly.

---

## M7 - Routes, Navigation, and Customer 360 Integration

### Goal

Expose contracts through the app without breaking existing routing or
permission behavior.

### Work

1. Add route constants:
   - `/contracts`
   - `/contracts/new`
   - `/contracts/:id`
   - `/contracts/:id/convert`
2. Add route guards for:
   - `contracts.view`
   - `contracts.create`
   - `contracts.convert_trial`
   - `contracts.close`
3. Add AppShell navigation item.
4. Replace customer contracts placeholder tab with real data.
5. Add localization keys in Arabic and English.
6. Add routing tests for:
   - manager.
   - contracts viewer.
   - create-only user.
   - zero-permission user.

### Acceptance

- Authorized users can reach contracts.
- Unauthorized users are blocked.
- Customer 360 contract tab shows real rows when available.
- Route tests remain green.

---

## M8 - Contract List and Detail UI

### Goal

Make existing contracts easy to find, inspect, and operate.

### Work

1. Contract list:
   - search by contract number.
   - search by customer.
   - search by phone.
   - search by unit serial/barcode if repository supports it.
   - filters for trial, active, closed, expired, low-profit override.
2. Contract detail:
   - header with status, customer, site, monthly value.
   - overview tab.
   - assets tab.
   - consumables tab.
   - invoices tab.
   - vouchers tab.
   - schedule tab.
   - history tab.
   - documents tab.
3. Actions:
   - convert trial.
   - extend trial.
   - return trial.
   - close contract.
   - print/preview.
   - schedule consumable change.
4. Hide cost/profit UI when permission is missing.

### Acceptance

- List works on desktop and narrow layouts.
- Detail loads all core sections.
- Permission-sensitive fields are hidden.
- Empty states are useful and localized.
- Customer 360 can navigate to contract detail.

---

## M9 - Contract Form UI

> **Status: complete (2026-07-11).** Implemented and verified with the unified
> rental-product form, manual/scan serial resolution, non-serialized asset
> support, permission-gated per-product cost/profit tables, responsive contract
> detail/list layouts, and idempotent submission. Persisted save-as-draft
> remains explicitly deferred below as shared finance UX work.

### Goal

Build a fast, professional contract creation screen that matches HS360's
invoice/document identity.

### Work

1. Header:
   - contract type.
   - start date.
   - trial defaults to 3 editable days and does not show a billing day.
   - rental previews 12 months when no end date is entered.
   - rental billing/refill dates default to the contract start day and remain
     editable.
2. Customer block:
   - existing customer picker.
   - inline customer creation if needed.
   - service-location picker.
   - inline service-location creation if none exists.
3. Unified rental-product lines:
   - one product picker containing rentable products.
   - domain classification determines asset versus consumable behavior.
   - serialized assets support manual serial/barcode entry and scanning.
   - scanning an exact unit resolves and adds its product automatically.
   - non-serialized rental assets can be contracted without a unit id.
   - consumables expose quantity per refill and refill frequency.
4. Pricing summary:
   - monthly rental value for rental contracts.
   - profit preview for authorized users.
   - authorized cost details list every product separately with quantity, unit
     cost, monthly cost, total monthly cost, and net monthly profit.
   - validation warning for low profit.
   - override reason for authorized users.
5. Save:
   - create trial.
   - create rental.
   - idempotent submit.
6. UX:
   - match invoice form density and command style.
   - no visible developer-like instructions in the app.
   - Arabic/English and RTL/LTR support.

### Acceptance

- User can create a trial from the form.
- User can create a rental from the form.
- User can add multiple rental products in one unified table.
- Serialized scan/manual selection and non-serialized rental assets work.
- Low-profit warning/override behaves correctly.
- Cost/profit data is hidden unless the user has the matching field permission.
- Cost breakdown is per product and responsive without horizontal scrolling.
- Form remains visually aligned with Phase 5 finance screens.

---

## M10 - Trial Conversion and Lifecycle UI

### Goal

Make trial outcomes and contract closure practical for daily use.

### Work

1. Conversion screen:
   - prefilled from trial.
   - monthly rental value.
   - term selection.
   - pricing preview.
   - confirmation.
2. Trial return dialog:
   - return date.
   - asset condition.
   - reason.
   - notes.
3. Trial extension dialog:
   - new end date.
   - reason.
4. Contract closure dialog:
   - close date.
   - normal/early.
   - asset condition per device.
   - reason.
   - outstanding balance notice.
5. Consumable/oil change dialog:
   - current consumable.
   - new consumable.
   - effective date.
   - reason.

### Acceptance

- Trial converts without re-entering all lines.
- Trial return releases assets.
- Contract close handles multiple assets.
- User sees that outstanding A/R remains after close.
- Consumable change preserves history.

---

## M11 - Contract PDF and Document Preview

### Goal

Produce a professional contract document using the Phase 5 print foundation.

### Work

1. Add contract document kind/template support.
2. Map contract detail payload to document payload.
3. Include:
   - tenant header.
   - customer.
   - service location.
   - contract number.
   - dates/term.
   - monthly rental value.
   - assets.
   - consumables.
   - notes/terms.
   - signature area or signature image if available.
   - QR if accepted.
4. Support Arabic and English.
5. Add PDF rendering tests where practical.

### Acceptance

- Contract PDF previews from contract detail.
- Arabic text renders correctly.
- Multiple assets/consumables fit professionally.
- Users without print permission cannot print.

---

## M12 - Calendar/Visit Handoff

### Goal

Prepare clean schedule data for Phase 7 calendar and Phase 8 field operations
without building the full mobile visit workflow.

### Delivered (2026-07-12)

- Migrations `090_phase_6_contract_calendar_handoff_schema.sql` and
  `091_phase_6_contract_calendar_handoff_functions.sql`:
  - Added `billing_due` calendar type and contract-generated provenance columns
    (`source_kind`, `source_key`, `source_metadata`, `contract_line_id`).
  - Trusted-writer provenance guard (`postgres` / `supabase_admin` only; no GUC
    spoof; `service_role` direct generated writes blocked).
  - Idempotent contract sync internals with billing identity keyed by coverage
    month (`source_key` = `contract:{id}:billing:{YYYY-MM-01}`).
  - Refill UNION (regular cycle + future oil changes with `effective_from >=
    current_date`), suspension purge/reactivation sync, and lifecycle hooks on
    create/extend/return/convert/close/collect/schedule-consumable.
  - `get_contract_detail` enrichment with generated-only `upcoming_schedule`
    (pending, `scheduled_date >= current_date`, limit 10).
  - Callable batch RPC `sync_tenant_contract_calendar_events` (`calendar.edit`).
- SQL suite `supabase/tests/phase_6_contract_calendar_handoff.sql` plus
  concurrency shell script; registered in `scripts/test/run_sql_suites.sh`
  Phase M12.
- Flutter read path: `ContractScheduleEvent`, mapper, and
  `ContractUpcomingScheduleSection` (display only; no refresh RPC).

### Work

1. Seed or expose upcoming contract events:
   - trial end.
   - rental billing.
   - expected refill/replacement.
   - contract end.
2. Every generated event must carry:
   - tenant.
   - customer.
   - service location.
   - contract.
3. Do not confirm stock consumption from scheduled events.
4. Do not create payment vouchers from scheduled events.
5. Add duplicate prevention for generated schedule events.
6. Keep Phase 8 responsible for:
   - GPS.
   - photo.
   - field confirmation.
   - actual consumable stock-out.
   - payment collection on visit.

### Acceptance

- Active contracts can produce upcoming schedule data.
- Trial end reminders can be found.
- Re-running schedule generation does not duplicate events.
- Schedule records are visibly tied to service location.
- Contract detail shows server-provided `upcoming_schedule` without client-side
  date inference.
- Suspension removes pending billing/refill; reactivation recreates without
  duplicate `source_key` rows.

---

## M13 - Verification and Phase Close

### Goal

Prove that Phase 6 is safe enough to support daily contract operations.

### Required SQL Tests

Create a Phase 6 SQL suite such as:

```text
supabase/tests/phase_6_contracts.sql
```

Cover:

1. Create trial with one asset.
2. Create trial with multiple assets.
3. Return trial.
4. Extend trial.
5. Convert trial to rental.
6. Create rental directly.
7. Create rental with multiple assets and consumables.
8. Reject serialized asset without unit id.
9. Reject unavailable unit.
10. Reject service location from another customer.
11. Reject below-min-profit without override.
12. Allow below-min-profit with permission and reason.
13. Hide sensitive profit fields without field permission.
14. Generate rental invoice once.
15. Prevent duplicate rental invoice for same period.
16. Close contract and return assets.
17. Ensure outstanding A/R remains after close.
18. Schedule consumable change without stock-out.
19. Validate inventory buckets after trial/rental/return/close.
20. Validate audit records for lifecycle changes.

### Required Flutter Tests

Cover:

- contract validators.
- contract permissions.
- pricing preview mapper.
- repository RPC payload mappers.
- route guards.
- contract list controller.
- contract detail controller.
- contract form controller.
- contract form widget.
- trial conversion dialog/screen.
- lifecycle dialogs.
- customer 360 contracts tab.

### Required Manual Acceptance

Run one full business story:

1. Create customer and service location.
2. Create trial contract with one device and one consumable.
3. Convert trial contract to rental contract with a 12-month term.
4. Generate first rental invoice.
5. Record receipt voucher from the invoice detail/customer flow.
6. Print contract PDF.
7. Close the contract and return the device.
8. Confirm customer statement remains correct.

### Acceptance

- SQL regression passes.
- Dart analysis passes.
- Flutter tests pass.
- `git diff --check` passes.
- Manual story passes in Arabic and English.
- Phase 7/8 have clean schedule/location/contract data to build on.

---

## Deferred UX Commitments (Recorded 2026-07-11)

### Save As Draft

Contract create must eventually support an explicit persisted **Save as draft**
command. This is deferred from the current M9 form polish and must be designed
with the shared finance draft work rather than as local widget state.

Required follow-up scope:

- persist and reopen contract drafts;
- distinguish save, discard, and activate/create commands;
- preserve customer, service location, dates, products, serial assignments,
  refill quantities, notes, and commercial value;
- define reservation rules so a draft never silently reserves stock or a
  serialized unit;
- add permission, audit, idempotency, stale-draft, and concurrent-edit tests;
- align the interaction with invoice and voucher draft commands.

### Navigation Acceptance Rule

Every new contract create/detail/edit/convert/operation screen must expose a
working back action. It must pop when navigation history exists and otherwise
return to the contracts list. Missing back navigation is a release blocker for
future contract UI milestones.

---

## Risk Register

### Risk 1 - Treating Contracts As CRUD

Mitigation:

- all lifecycle writes through RPCs;
- no direct widget writes;
- M2/M3 before UI.

### Risk 2 - Wrong Profit Basis

Mitigation:

- configurable pricing basis;
- snapshot selected basis;
- dedicated SQL tests for each basis.

### Risk 3 - Trial Cost Is Invisible

Mitigation:

- trial moves asset state/buckets;
- record trial dates, assets, service location, outcome, and return condition;
- defer cost/depreciation accounting until a later accepted accounting phase.

### Risk 4 - Duplicate Rental Invoices

Mitigation:

- period unique key or billing-run table;
- idempotency key;
- rerun tests.

### Risk 5 - Device Location Drift

Mitigation:

- update current customer, service location, warehouse, and contract pointers
  in one transaction;
- use inventory movements and unit timeline.

### Risk 6 - Consuming Stock On Planned Visits

Mitigation:

- schedule is not confirmation;
- stock-out only on confirmed visit/refill operation.

### Risk 7 - Permission Leakage

Mitigation:

- safe views/detail shaping;
- cost/profit field permissions;
- route/widget tests.

### Risk 8 - UI Becomes Too Slow

Mitigation:

- contract form follows invoice screen density;
- scan/select exact unit;
- inline customer/location create;
- avoid unnecessary multi-page flow if a document-style form is faster.

### Risk 9 - Scope Drift Into Phase 8

Mitigation:

- Phase 6 prepares visits/calendar data;
- GPS/photo/mobile confirmation remains Phase 8 unless explicitly pulled in.

---

## Estimated Delivery

Approximate focused effort:

| Work | Estimate |
|------|----------|
| M0-M0.5 | 1-2 days |
| M1 | 2-4 days |
| M2 | 3-5 days |
| M3 | 4-6 days |
| M4 | 3-5 days |
| M5 | 3-5 days |
| M6 | 2-4 days |
| M7 | 1-2 days |
| M8 | 3-5 days |
| M9 | 5-8 days |
| M10 | 3-5 days |
| M11 | 2-4 days |
| M12 | 2-4 days |
| M13 | 3-5 days |

Total: approximately 35-64 focused development days before contingency.

Because contracts are the heart of HS360, correctness gates should not be
removed to make the older four-week estimate appear true. A practical target is
8-12 calendar weeks for a professional implementation by one developer with AI
assistance, depending on database test speed, UI polish, and PDF scope.

---

## Starting Point For Implementation

Start with M0.

Do not begin contract UI until:

- this plan is accepted;
- trial scope is reconciled in older docs;
- pricing-basis defaults are accepted;
- missing permissions are added to seed;
- Phase 5 baseline is verified.

The first implementation session should produce:

1. documentation reconciliation;
2. migration `077` for contract settings and permissions;
3. SQL tests proving settings and permission catalog are correct.
