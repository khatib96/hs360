#!/usr/bin/env bash
# Phase 6 M13 manual UI acceptance: English + Arabic via integration_test.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"
device_id="${2:-macos}"

status_env="$(npx supabase status -o env 2>/dev/null || true)"
if [[ -z "$status_env" ]]; then
  printf 'supabase status failed; is local Supabase running?\n' >&2
  exit 1
fi

anon_key="$(printf '%s\n' "$status_env" | sed -n 's/^ANON_KEY=//p' | tr -d '"')"
api_url="$(printf '%s\n' "$status_env" | sed -n 's/^API_URL=//p' | tr -d '"')"
if [[ -z "$anon_key" ]]; then
  printf 'ANON_KEY missing from supabase status\n' >&2
  exit 1
fi
if [[ -z "$api_url" ]]; then
  api_url='http://127.0.0.1:54321'
fi

run_locale() {
  local locale="$1"
  local tag="$2"

  printf '\n=== P6M13 manual acceptance locale=%s tag=%s ===\n' "$locale" "$tag"

  bash "$repo_root/scripts/test/p6m13_manual_cleanup.sh" "$container_name" || true

  docker exec -i "$container_name" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 -v tag="$tag" \
    < "$repo_root/scripts/test/p6m13_manual_fixture.sql"

  flutter test integration_test/contracts/p6m13_manual_acceptance_test.dart \
    -d "$device_id" \
    --dart-define=SUPABASE_ANON_KEY="$anon_key" \
    --dart-define=SUPABASE_URL="$api_url" \
    --dart-define=P6M13_LOCALE="$locale" \
    --dart-define=P6M13_TAG="$tag"

  bash "$repo_root/scripts/test/p6m13_manual_cleanup.sh" "$container_name"
}

run_locale en EN
run_locale ar AR

printf '\nP6M13 manual acceptance (EN + AR) passed.\n'
