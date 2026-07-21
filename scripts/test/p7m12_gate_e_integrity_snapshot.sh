#!/usr/bin/env bash
# Gate E integrity snapshot (item 21). Writes JSON without secrets.
# Usage: bash scripts/test/p7m12_gate_e_integrity_snapshot.sh <pre|post> [container] [outdir]
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

label="${1:?usage: p7m12_gate_e_integrity_snapshot.sh <pre|post> [container] [outdir]}"
container_name="${2:-supabase_db_hs360}"
outdir="${3:-$repo_root/docs/evidence/phase7_m12/gate_e}"
mkdir -p "$outdir"

snapshot_json="$(docker exec -i "$container_name" psql -U postgres -d postgres -t -A <<'SQL'
select jsonb_build_object(
  'captured_at', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'inventory_balances', (select count(*)::int from public.inventory_balances),
  'inventory_movements', (
    select count(*)::int from public.inventory_movements
  ),
  'invoices', (select count(*)::int from public.invoices),
  'vouchers', (select count(*)::int from public.vouchers),
  'journal_entries', (select count(*)::int from public.journal_entries),
  'journal_lines', (select count(*)::int from public.journal_lines),
  'completed_visits', (
    select count(*)::int from public.visits where status = 'completed'
  ),
  'p7m12_customers', (
    select count(*)::int from public.customers
    where name_ar like '%P7M12%' or name_en like '%P7M12%'
       or phone_primary like '+965500094%'
  ),
  'p7m12_locations', (
    select count(*)::int from public.customer_service_locations
    where name like '%P7M12%'
  ),
  'p7m12_products', (
    select count(*)::int from public.products
    where sku like 'P7M12-%' or name_ar like '%P7M12%'
  ),
  'p7m12_units', (
    select count(*)::int from public.product_units
    where serial_number like 'P7M12-%'
  ),
  'p7m12_contracts', (
    select count(*)::int
    from public.contracts c
    join public.customers cu on cu.id = c.customer_id
    where cu.name_ar like '%P7M12%' or cu.name_en like '%P7M12%'
  ),
  'p7m12_calendar_events', (
    select count(*)::int
    from public.calendar_events ce
    where ce.title_en like '%P7M12%' or ce.title_ar like '%P7M12%'
  ),
  'p7m12_working_date_exceptions', (
    select count(*)::int
    from public.tenant_working_date_exceptions wde
    where wde.title_en like '%P7M12%' or wde.title_ar like '%P7M12%'
  )
)::text;
SQL
)"

outfile="$outdir/integrity_${label}.json"
printf '%s\n' "$snapshot_json" > "$outfile"
printf 'Wrote %s\n' "$outfile"
printf '%s\n' "$snapshot_json"
