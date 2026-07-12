#!/usr/bin/env bash
# Runs integration tests against local Supabase with platform-specific API URL.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

platform="${1:-macos}"
device_id="${2:-}"

resolve_device() {
  case "$platform" in
    macos)
      device_id="${device_id:-macos}"
      ;;
    linux)
      device_id="${device_id:-linux}"
      ;;
    *)
      printf 'Unsupported platform: %s (use macos or linux)\n' "$platform" >&2
      exit 1
      ;;
  esac
}

resolve_device

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
  printf 'API_URL missing from supabase status; using %s\n' "$api_url"
fi

printf 'Using SUPABASE_URL=%s\n' "$api_url"
printf 'Running integration tests on device: %s\n' "$device_id"

flutter test integration_test/documents/supabase_seeded_templates_test.dart \
  -d "$device_id" \
  --dart-define=SUPABASE_ANON_KEY="$anon_key" \
  --dart-define=SUPABASE_URL="$api_url"
