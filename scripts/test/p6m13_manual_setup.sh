#!/usr/bin/env bash
# Optional manual acceptance helper for Phase 6 M13.
# Creates ONLY a tagged customer + service location (no inventory, no contract).
# For inventory fixture used by UI trial creation, run p6m13_manual_fixture.sql
# from p6m13_manual_acceptance.sh (postgres infrastructure, not a business step).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_customer_id uuid;
  v_location_id uuid;
  v_contract_id uuid;
begin
  v_customer_id := public.create_customer(
    '{"name_ar":"عميل P6M13 يدوي","phone_primary":"+96550009301","create_account":true}'::jsonb
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    '{"name":"موقع P6M13 يدوي","location_type":"branch","governorate":"Hawalli","area":"Salmiya","contact_person_phone":"+96550009301"}'::jsonb
  );

  perform set_config('p6m13.manual.customer_id', v_customer_id::text, false);
  perform set_config('p6m13.manual.location_id', v_location_id::text, false);

  raise notice 'P6M13 manual customer % location %', v_customer_id, v_location_id;
end $$;
SQL

printf 'P6M13 manual setup complete (customer + service location only).\n'
