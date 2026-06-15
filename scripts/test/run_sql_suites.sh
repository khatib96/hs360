#!/usr/bin/env bash
# Phase 5 SQL regression gate:
# Phase A = M1-M3 baseline, Phase B = M4 tax, Phase C = baseline pollution rerun.
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

printf 'Phase C: baseline pollution gate\n'
for suite in "${phase_a_suites[@]}"; do
  run_suite "$suite"
done

printf 'All SQL suite phases passed.\n'
