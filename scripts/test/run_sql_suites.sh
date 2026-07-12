#!/usr/bin/env bash
# Phase 5 SQL regression gate:
# Phase A = M1-M3 baseline, Phase B = M4 tax, Phase G = M7.5 returns,
# Phase H = Phase 6 M1 contracts foundation, Phase C = baseline pollution rerun.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"

phase_a_suites=(
  "supabase/tests/phase_1d_rls.sql"
  "supabase/tests/phase_3_products_inventory.sql"
  "supabase/tests/phase_4_customers_suppliers_coa.sql"
  "supabase/tests/phase_4_customer_service_locations.sql"
  "supabase/tests/phase_4_service_location_coordinates.sql"
  "supabase/tests/phase_5_finance_foundation.sql"
  "supabase/tests/phase_5_asset_identity.sql"
  "supabase/tests/phase_5_m1_m2_hardening.sql"
  "supabase/tests/phase_5_document_templates.sql"
  "supabase/tests/phase_5_document_templates_validation.sql"
)

phase_b_suites=(
  "supabase/tests/phase_5_tax_foundation.sql"
)

run_suite() {
  local suite="$1"

  if [[ ! -f "$suite" ]]; then
    printf 'Suite not found: %s\n' "$suite" >&2
    return 1
  fi

  printf 'Running %s ...\n' "$suite"
  docker exec -i "$container_name" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$suite"
}

printf 'Phase A: Phase 5 M1-M3 baseline regression\n'
for suite in "${phase_a_suites[@]}"; do
  run_suite "$suite"
done

printf 'Phase B: Phase 5 M4 tax foundation\n'
for suite in "${phase_b_suites[@]}"; do
  run_suite "$suite"
done
bash "$repo_root/supabase/tests/phase_5_tax_foundation_concurrency.sh" "$container_name"

printf 'Phase C.5: Phase 5 M4.5 inventory accounting\n'

phase_c5_suites=(
  "supabase/tests/phase_5_inventory_accounting.sql"
)

for suite in "${phase_c5_suites[@]}"; do
  run_suite "$suite"
done

bash "$repo_root/supabase/tests/phase_5_inventory_accounting_concurrency.sh" "$container_name"

printf 'Phase D: Phase 5 M5 purchase invoices\n'

phase_d_suites=(
  "supabase/tests/phase_5_purchase_invoices.sql"
)

for suite in "${phase_d_suites[@]}"; do
  run_suite "$suite"
done

bash "$repo_root/supabase/tests/phase_5_purchase_invoices_concurrency.sh" "$container_name"

printf 'Phase E: Phase 5 M6 sales invoices\n'

phase_e_suites=(
  "supabase/tests/phase_5_sales_invoices.sql"
)

for suite in "${phase_e_suites[@]}"; do
  run_suite "$suite"
done

bash "$repo_root/supabase/tests/phase_5_sales_invoices_concurrency.sh" "$container_name"

printf 'Phase F: Phase 5 M7 vouchers\n'

phase_f_suites=(
  "supabase/tests/phase_5_vouchers.sql"
)

for suite in "${phase_f_suites[@]}"; do
  run_suite "$suite"
done

bash "$repo_root/supabase/tests/phase_5_vouchers_concurrency.sh" "$container_name"

printf 'Phase G: Phase 5 M7.5 returns\n'

phase_g_suites=(
  "supabase/tests/phase_5_returns.sql"
)

for suite in "${phase_g_suites[@]}"; do
  run_suite "$suite"
done

bash "$repo_root/supabase/tests/phase_5_returns_concurrency.sh" "$container_name"

printf 'Phase H: Phase 6 M1 contract settings and permissions\n'
run_suite "supabase/tests/phase_6_contract_settings_permissions.sql"

printf 'Phase I: Phase 6 M2 pricing and profit engine\n'
run_suite "supabase/tests/phase_6_contract_pricing_profit_engine.sql"

printf 'Phase J: Phase 6 M3 contract creation RPCs\n'
run_suite "supabase/tests/phase_6_contract_creation_rpc.sql"

printf 'Phase K: Phase 6 M4 contract lifecycle RPCs\n'
run_suite "supabase/tests/phase_6_contract_lifecycle_rpc.sql"

printf 'Phase K.5: Phase 6 M10b schedule consumable change RPCs\n'
run_suite "supabase/tests/phase_6_schedule_consumable_change_rpc.sql"

printf 'Phase L: Phase 6 M5 rental collection and billing engine\n'
run_suite "supabase/tests/phase_6_rental_collection_billing_engine.sql"

printf 'Phase M: Phase 6 M8 contract read RPCs\n'
run_suite "supabase/tests/phase_6_contract_read_rpc.sql"

printf 'Phase M11: Phase 6 contract PDF\n'
run_suite "supabase/tests/phase_6_contract_pdf.sql"

printf 'Phase M12: Phase 6 contract calendar handoff\n'
run_suite "supabase/tests/phase_6_contract_calendar_handoff.sql"
bash "$repo_root/supabase/tests/phase_6_contract_calendar_handoff_concurrency.sh" "$container_name"

printf 'Phase C: baseline pollution gate\n'
for suite in "${phase_a_suites[@]}"; do
  run_suite "$suite"
done

printf 'All SQL suite phases passed.\n'
