-- Phase 3 M1 follow-up: inventory movements are written through RPC only.
--
-- record_inventory_adjustment(...) is the controlled path that keeps
-- inventory_movements and inventory_balances atomic. Direct client writes can
-- create movements without balances, so remove direct INSERT/DELETE policies.

drop policy if exists inventory_movements_insert on inventory_movements;
drop policy if exists inventory_movements_delete on inventory_movements;

