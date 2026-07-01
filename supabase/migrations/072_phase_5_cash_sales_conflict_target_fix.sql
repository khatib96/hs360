-- Phase 5 M9 hotfix: allow already-applied 071 RPCs to use their original
-- inventory_balances ON CONFLICT target. The base schema has uniqueness on
-- (warehouse_id, product_id); this compatible index is safe because warehouse
-- rows are already tenant-owned and existing data is therefore non-duplicated.

create unique index if not exists ux_inventory_balances_tenant_warehouse_product
on public.inventory_balances (tenant_id, warehouse_id, product_id);

notify pgrst, 'reload schema';
