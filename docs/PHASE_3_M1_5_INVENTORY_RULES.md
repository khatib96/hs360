# Phase 3 M1.5 — Inventory Business Rules & Engine Boundaries

> Updated 2026-05-20.
> Milestone: lock inventory rules before Flutter repositories and UI (M2+).
>
> Supersession note (2026-06-15): Phase 5 M4.5 in
> `PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md` supersedes the Phase 3
> no-journal rule for manual adjustments once its migration is applied. The
> existing Phase 3 RPC remains the current implementation until then.

## Canonical status

**This document is the canonical source for inventory rules** until explicitly superseded by a later phase document (for example Phase 5 purchase RPC rules or M7 transfer specification).

If `BUILD_PLAN.md`, `PHASE_3_PRODUCTS_INVENTORY_PLAN.md`, `ai_memory.md`, or ad-hoc notes conflict with this file on **inventory behavior**, **this file wins** unless a newer milestone doc states otherwise.

---

## A. Scope

### In scope (M1.5)

- Document business rules enforced or implied by M1 database work.
- Optional PostgreSQL `COMMENT ON` metadata in migration `039`.
- StockEngine vs CostEngine responsibility boundaries (documentation only).
- M2 implementation contract for repositories and domain services.

### Out of scope (M1.5)

- Flutter UI screens or widgets.
- Dart domain models, repositories, or providers (starts in **M2**).
- `record_inventory_transfer` RPC (**M7E**).
- Serialized unit-level stock adjustment RPCs (**M6 / M7D**).
- Purchase/sales invoice stock RPCs (**Phase 5**).
- Contract/visit stock RPCs (**Phase 6 / Phase 8**).
- Accounting journal entries from inventory adjustments (deferred here and
  assigned to Phase 5 M4.5).

M1.5 **locks rules** for future M2/M7 work; it does not add new executable behavior except optional DB comments.

---

## B. Inventory write policy

### Clients must not write balances directly

- Table: `inventory_balances`.
- RLS: **SELECT only** for authenticated clients ([`030_rls_policies.sql`](../supabase/migrations/030_rls_policies.sql)).
- All balance changes happen inside **SECURITY DEFINER** inventory RPCs (or future system functions).

### Clients must not write movements directly

- Table: `inventory_movements`.
- After migration **038**, direct client **INSERT** and **DELETE** policies are dropped.
- Clients may **SELECT** movements when they have `inventory_movements.view`.

### All stock mutations go through RPCs

| Phase | RPC / path | Purpose |
|-------|------------|---------|
| M1 (current) | `record_inventory_adjustment(...)` | Manual `adjustment_in` / `adjustment_out` |
| M7E | `record_inventory_transfer(...)` | Internal warehouse transfer (planned) |
| Phase 5 | `record_purchase_invoice(...)` | Confirmed purchase + stock in + WAC + journal |
| Phase 5 | `record_sales_invoice(...)` | Confirmed sale + stock out + COGS + journal |
| Phase 6 / 8 | Contract / visit RPCs | Rental, refill, field consumption (planned) |

Repositories and UI must call these RPCs (or future equivalents), never insert into `inventory_movements` or `inventory_balances` directly.

---

## C. Movement immutability

- `inventory_movements` is an **append-only** ledger.
- No client **UPDATE** path exists.
- No client **DELETE** path after migration **038**.
- Corrections are made by posting a **reverse movement** with a clear reason in `notes` (for example `adjustment_out` to undo an erroneous `adjustment_in`).
- Emergency correction (data repair) is allowed only via **privileged admin operation** or controlled migration — not via normal app UI.

Audit: `trg_audit_inventory_movements_insert` logs new movements. Adjustment reasons are stored in `inventory_movements.notes` (no separate audit reason column in Phase 3).

---

## D. Negative stock

- **Negative stock is not allowed** in Phase 3.
- `adjustment_out` in `record_inventory_adjustment`:
  - Locks the balance row: `tenant_id`, `warehouse_id`, `product_id` with `FOR UPDATE`.
  - Requires an existing row with `qty_available >= p_qty`.
  - Otherwise raises `insufficient_stock`.
- Future RPCs (transfer, sale, contract, visit) **must apply the same rule** unless a documented, approved business exception exists.

---

## E. Quantity unit policy

- All stock quantities in `inventory_movements.qty` and `inventory_balances` buckets are stored in **`products.unit_primary`**.
- UI may display or accept **secondary** units later; repositories/services must convert before calling an RPC:
  - Use `to_primary(product_id, qty_secondary)` from migration **035**, or
  - equivalent Dart conversion in M2 that matches DB logic.
- **WAC** (`products.avg_cost`, `products.last_purchase_cost`) is always **per primary unit**.

---

## F. Costing policy

| Rule | Phase 3 decision |
|------|------------------|
| Cost method | **WAC only** |
| FIFO / LIFO | Out of scope |
| `adjustment_in` | **`p_unit_cost` required** (use `0.000` for free stock) |
| `adjustment_out` | Does **not** change `avg_cost` or `last_purchase_cost` |
| Transfers (future) | Do **not** change WAC |
| WAC quantity basis (M1) | `coalesce(sum(qty_available), 0)` across all warehouses for the product |
| Journal entries | **None in the Phase 3 implementation; Phase 5 M4.5 replaces this with journal-backed inventory documents** |

### WAC formula (adjustment_in)

When existing total primary quantity before this movement is `old_total_qty` and existing average is `old_avg_cost`:

- If `old_total_qty = 0`: `new_avg_cost = incoming_unit_cost`
- Else: `new_avg_cost = ((old_total_qty * old_avg_cost) + (incoming_qty * incoming_unit_cost)) / (old_total_qty + incoming_qty)`

Also set `last_purchase_cost = incoming_unit_cost`.

### Deferred: valuation buckets

Before **Phase 5** or during **M7**, decide whether inventory valuation should use:

- **`qty_available` only** (current M1 behavior), or
- **All owned stock buckets** where appropriate: `qty_available + qty_rented + qty_trial + qty_maintenance + qty_damaged`

Document the decision in the superseding milestone doc when resolved.

---

## G. Serialized products

- `record_inventory_adjustment` **rejects** `products.is_serialized = true` with `serialized_adjustment_not_supported`.
- Serialized rental assets must not be bulk-adjusted by quantity alone.
- Stock changes for devices use **`product_units`** with `unit_status` and warehouse assignment (**M6 / M7D**).

### Future unit-level design (not implemented in M1.5)

- `product_units.status` drives which balance bucket applies (`qty_rented`, `qty_maintenance`, etc.).
- Allowed status transitions must be documented before M6/M7D UI and RPCs.
- Contract and maintenance flows will reference specific `product_unit_id` values.

---

## H. StockEngine vs CostEngine boundary

Documentation only in M1.5. Dart implementation starts in **M2** (`lib/domain/services/stock_engine.dart`, `lib/domain/services/cost_engine.dart`).

**Database/RPC remains the source of truth.** Dart services may preview or validate early; they must not be the final authority for balances or WAC.

### StockEngine (conceptual)

- Validates movement type and allowed RPC path.
- Validates product, warehouse, and tenant scope (active records).
- Validates stock availability (no negative stock).
- Blocks serialized bulk adjustments.
- Determines balance deltas (preview only in Dart; RPC applies for real).
- **Does not** own accounting journal logic.

### CostEngine (conceptual)

- Validates unit cost input (required on stock-in).
- Calculates WAC preview using the same formula as the RPC.
- Decides whether a movement type affects `avg_cost` and `last_purchase_cost`.
- **Does not** decide stock availability.
- **Does not** create journal entries in Phase 3.

---

## I. Reference policy

Every movement should identify its source:

| Field | Usage |
|-------|--------|
| `reference_table` | Source entity type |
| `reference_id` | Source entity UUID |

### M1 manual adjustments

- `reference_table = 'inventory_adjustment'`
- `reference_id = inventory_movements.id` (same row, set at insert time)

### Future reference types (reserved)

- `inventory_transfer`
- `purchase_invoice` / `sales_invoice`
- `contract`
- `visit`

### Notes

- Every manual adjustment requires **non-empty** `notes` after trim (`btrim`).
- Stored value is trimmed; raw whitespace-only input is rejected (`validation_failed`).

---

## J. Permission policy

| Permission | Meaning in Phase 3 |
|------------|-------------------|
| `inventory_movements.create` | May call **approved inventory RPCs** (e.g. `record_inventory_adjustment`). **Does not** grant direct `INSERT` on `inventory_movements` after migration **038**. |
| `inventory.view` | Read `inventory_balances` |
| `inventory_movements.view` | Read `inventory_movements` log |
| `products.view` | Read products (use `products_safe` when cost fields must be hidden) |
| `products.field.avg_cost` | Read `avg_cost` (sensitive) |
| `products.field.last_purchase_cost` | Read `last_purchase_cost` (sensitive) |
| `products.field.min_sale_price` | Read `min_sale_price` (sensitive) |
| `products.field.min_rental_price` | Read `min_rental_price` (sensitive) |

Managers bypass explicit grants via `user_has_permission()` but still use RPCs for stock mutations.

**M2 rule:** Do not fetch `products.avg_cost`, `last_purchase_cost`, `min_sale_price`, or `min_rental_price` for users lacking the corresponding field permissions. Prefer `products_safe` unless the user has **all** required sensitive field permissions for the screen.

---

## K. Database state after M1

| Migration | Purpose |
|-----------|---------|
| `035_product_inventory_helpers.sql` | `to_primary`, `to_secondary` |
| `036_inventory_adjustment_rpc.sql` | `record_inventory_adjustment` |
| `037_product_images_storage.sql` | `product_images` bucket + policies |
| `038_inventory_movements_rpc_only.sql` | Drop direct movement INSERT/DELETE policies |
| `039_inventory_business_rules.sql` | PostgreSQL comments (M1.5 metadata) |

View: `products_safe` — hides cost and floor price columns ([`028_views.sql`](../supabase/migrations/028_views.sql)).

### Test coverage (`phase_3_products_inventory.sql`)

| # | Test | Rule verified |
|---|------|----------------|
| 1 | Conversion | `to_primary` / `to_secondary` |
| 2 | Tenant isolation | Cross-tenant RPC → `validation_failed` |
| 3 | Zero permission | `permission_denied` |
| 4 | Permission gate | `inventory_movements.create` allows RPC (not direct insert) |
| 5 | Direct movement insert | Blocked by **038** even with create permission |
| 6 | Serialized reject | `serialized_adjustment_not_supported` |
| 7 | adjustment_in | Movement + balance + WAC |
| 8 | adjustment_out | Balance decrease; `unit_cost` null on movement |
| 9 | Insufficient stock | `insufficient_stock` |
| 10 | No unit_cost on in | `validation_failed` |
| 11 | products_safe | Sensitive columns not exposed |
| 12 | Storage catalog | `product_images` bucket + policies |

---

## L. Open decisions deferred

| Topic | Target milestone | Notes |
|-------|------------------|-------|
| `record_inventory_transfer` | **M7E** | Atomic transfer_out + transfer_in |
| `p_client_id` idempotency on RPCs | **M1.5+ / before offline** | Align with [`RPC_SPEC.md`](RPC_SPEC.md) before retry-heavy or mobile flows |
| Serialized unit-level adjustment RPC | **M6 / M7D** | `product_units` + status transitions |
| WAC valuation buckets (`qty_available` vs all buckets) | **M7 / before Phase 5** | See section F |
| Storage UPDATE/DELETE on `product_images` | **M5** | Primary image replace/remove |
| Movement reversal dedicated RPC | **M7C or Phase 5** | May use paired adjustments until then |
| Stock summary view/RPC | **M2 / M7B** | If repositories need aggregated stock without summing movements |
| `inventory_movements.delete` permission vs immutability | **M1.5 / M7C** | Policy dropped in 038; permission row remains in catalog — document emergency-only use |

---

## M. M2 implementation contract

Cursor and implementers **must** follow this when building Phase 3 M2:

1. **Call RPCs for stock changes** — use `record_inventory_adjustment(...)` (and future RPCs); never `insert`/`update`/`delete` on `inventory_movements` or `inventory_balances`.
2. **Use `products_safe`** unless the user has all required sensitive field permissions for the feature; never leak cost columns through raw `products` selects.
3. **Dart StockEngine / CostEngine are preview and validation only** — balances and WAC after save come from DB/RPC responses or refreshed queries, not client-side finalization.
4. **No direct table writes** for inventory ledger tables from repositories.
5. **Convert units before RPC** — quantities passed to RPCs are in `unit_primary`; use `to_primary` or shared conversion service.
6. **Respect stable RPC errors** — map `permission_denied`, `validation_failed`, `insufficient_stock`, `serialized_adjustment_not_supported`, `tenant_not_found` to localized UI messages.
7. **`inventory_movements.create` means RPC access** — UI labels and permission checks should not imply “insert movement row directly.”

---

## Related documents

- [`PHASE_3_PRODUCTS_INVENTORY_PLAN.md`](PHASE_3_PRODUCTS_INVENTORY_PLAN.md) — milestone roadmap
- [`PRODUCTS_DETAIL.md`](PRODUCTS_DETAIL.md) — dual units, conversion, WAC examples
- [`SECURITY.md`](SECURITY.md) — RLS, `products_safe`, storage
- [`RPC_SPEC.md`](RPC_SPEC.md) — future RPC contracts and idempotency
- [`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md) — table definitions
