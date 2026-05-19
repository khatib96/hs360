-- Phase 3 M1.5: inventory business rules metadata (comments only; no behavior change).
-- Canonical rules: docs/PHASE_3_M1_5_INVENTORY_RULES.md

comment on table inventory_movements is
  'Append-only stock ledger. Client INSERT/DELETE blocked (038). Corrections via reverse RPC movement with notes.';

comment on table inventory_balances is
  'Cached per-warehouse balances. Updated only by inventory RPCs/system functions, not direct client writes.';

comment on column inventory_movements.reference_table is
  'Source entity type for the movement, e.g. inventory_adjustment, inventory_transfer, purchase_invoice, sales_invoice, contract, visit.';

comment on column inventory_movements.reference_id is
  'Source entity id. For manual adjustments in M1, this equals inventory_movements.id.';

comment on column products.avg_cost is
  'Weighted average cost per unit_primary. Updated on adjustment_in and future purchase paths; not on adjustment_out or transfers.';

comment on column products.last_purchase_cost is
  'Last incoming unit cost per unit_primary. Updated on adjustment_in and future purchase paths; not on adjustment_out or transfers.';

comment on function to_primary(uuid, numeric) is
  'Converts secondary quantity to product.unit_primary using products.conversion_factor.';

comment on function to_secondary(uuid, numeric) is
  'Converts primary quantity to product.unit_secondary using products.conversion_factor.';

comment on function record_inventory_adjustment(uuid, uuid, numeric, movement_type, numeric, text) is
  'Atomic manual adjustment_in/out: movement + balance (+ WAC on stock-in). SECURITY DEFINER; requires inventory_movements.create.';
