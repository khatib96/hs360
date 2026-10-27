#!/usr/bin/env bash
# Creates a complete company (tenant) and its owner login.
#
# Usage:
#   SUPABASE_URL=https://api.example.com \
#   SUPABASE_SERVICE_ROLE_KEY=... \
#   ./scripts/provision_company.sh scripts/companies/kuwait.example.json owner@example.com "Owner Name"
#
# The owner password is read from the terminal (not echoed, not stored).
# The service-role key bypasses security: run this only from a trusted machine
# and never commit the key.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <company.json> <owner-email> <owner-display-name>" >&2
  exit 1
fi

company_file="$1"
owner_email="$2"
owner_name="$3"
api_url="${SUPABASE_URL:?Set SUPABASE_URL}"
service_key="${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY}"

if [[ ! -f "$company_file" ]]; then
  echo "Company file not found: $company_file" >&2
  exit 1
fi

if [[ -n "${OWNER_PASSWORD:-}" ]]; then
  owner_password="$OWNER_PASSWORD"
else
  read -r -s -p "Owner password (min 12 characters): " owner_password
  echo
  read -r -s -p "Repeat password: " owner_password_repeat
  echo
  if [[ "$owner_password" != "$owner_password_repeat" ]]; then
    echo "Passwords do not match." >&2
    exit 1
  fi
fi

if [[ ${#owner_password} -lt 12 ]]; then
  echo "Password must be at least 12 characters." >&2
  exit 1
fi

# 1. Owner login through the Auth admin API (body passed on stdin so the
#    password never appears in the process list).
create_user_body="$(
  OWNER_EMAIL="$owner_email" OWNER_PASSWORD="$owner_password" OWNER_NAME="$owner_name" \
  python3 -c '
import json, os
print(json.dumps({
    "email": os.environ["OWNER_EMAIL"],
    "password": os.environ["OWNER_PASSWORD"],
    "email_confirm": True,
    "user_metadata": {"name": os.environ["OWNER_NAME"]},
}))'
)"

user_response="$(
  printf '%s' "$create_user_body" | curl -sS -X POST "$api_url/auth/v1/admin/users" \
    -H "apikey: $service_key" \
    -H "Authorization: Bearer $service_key" \
    -H "Content-Type: application/json" \
    --data-binary @-
)"
unset create_user_body owner_password owner_password_repeat

owner_user_id="$(
  printf '%s' "$user_response" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("id", ""))'
)"
if [[ -z "$owner_user_id" ]]; then
  echo "Could not create the owner login:" >&2
  printf '%s\n' "$user_response" >&2
  exit 1
fi

# 2. Company, currency, settings, accounts, warehouse, and owner membership.
provision_body="$(
  OWNER_USER_ID="$owner_user_id" OWNER_NAME="$owner_name" \
  python3 -c '
import json, os, sys
company = json.load(open(sys.argv[1], encoding="utf-8"))
company["owner_user_id"] = os.environ["OWNER_USER_ID"]
company["owner_display_name"] = os.environ["OWNER_NAME"]
print(json.dumps({"p_data": company}, ensure_ascii=False))' "$company_file"
)"

tenant_response="$(
  printf '%s' "$provision_body" | curl -sS -X POST "$api_url/rest/v1/rpc/provision_company" \
    -H "apikey: $service_key" \
    -H "Authorization: Bearer $service_key" \
    -H "Content-Type: application/json" \
    --data-binary @-
)"

tenant_id="$(
  printf '%s' "$tenant_response" | python3 -c '
import json, sys
value = json.load(sys.stdin)
print(value if isinstance(value, str) else "")'
)"
if [[ -z "$tenant_id" ]]; then
  echo "Company provisioning failed:" >&2
  printf '%s\n' "$tenant_response" >&2
  # Remove the owner login created above so a retry starts clean.
  if curl -sS -f -o /dev/null -X DELETE "$api_url/auth/v1/admin/users/$owner_user_id" \
    -H "apikey: $service_key" \
    -H "Authorization: Bearer $service_key"; then
    echo "The new owner login $owner_email was removed." >&2
  else
    echo "Could not remove the new owner login $owner_email ($owner_user_id); delete it manually." >&2
  fi
  exit 1
fi

echo "Company created: $tenant_id"
echo "Owner login: $owner_email (manager)"
