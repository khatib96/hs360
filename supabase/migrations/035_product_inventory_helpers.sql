-- Phase 3 M1: product unit conversion helpers (PRODUCTS_DETAIL.md section 1.5).

create or replace function to_primary(p_product_id uuid, p_qty_secondary numeric)
returns numeric
language sql
stable
set search_path = public
as $$
  select p_qty_secondary * conversion_factor
  from products
  where id = p_product_id;
$$;

create or replace function to_secondary(p_product_id uuid, p_qty_primary numeric)
returns numeric
language sql
stable
set search_path = public
as $$
  select p_qty_primary / conversion_factor
  from products
  where id = p_product_id;
$$;

revoke all on function to_primary(uuid, numeric) from public;
revoke all on function to_secondary(uuid, numeric) from public;

grant execute on function to_primary(uuid, numeric) to authenticated;
grant execute on function to_secondary(uuid, numeric) to authenticated;
