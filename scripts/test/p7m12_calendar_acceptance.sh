#!/usr/bin/env bash
# Phase 7 M12 calendar-only integration acceptance (EN + AR).
# Runs the shared P6M13 driver with P7M12_CALENDAR_ONLY=true so the story
# stops after contract→calendar handoff (before PDF / statement / close).
# Cleanup is guaranteed via trap EXIT (success, failure, or interrupt).
# Preserves original Flutter exit code; cleanup failure still fails the gate
# without masking the original Flutter failure reason.
# Never prints or persists Supabase keys.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"
device_id="${2:-macos}"

flutter_exit=0
cleanup_exit=0
cleanup_ran=0

run_cleanup() {
  local ec=0
  bash "$repo_root/scripts/test/p6m13_manual_cleanup.sh" "$container_name" || ec=$?
  if (( ec != 0 )); then
    cleanup_exit=$ec
    printf 'P7M12 cleanup failed with exit %s\n' "$ec" >&2
  fi
  cleanup_ran=1
  return 0
}

on_exit() {
  if (( cleanup_ran == 0 )); then
    run_cleanup
  fi
  if (( flutter_exit != 0 )); then
    if (( cleanup_exit != 0 )); then
      printf 'P7M12: Flutter failed (exit %s); cleanup also failed (exit %s). Preserving Flutter exit.\n' \
        "$flutter_exit" "$cleanup_exit" >&2
    fi
    exit "$flutter_exit"
  fi
  if (( cleanup_exit != 0 )); then
    exit "$cleanup_exit"
  fi
}

trap on_exit EXIT

status_env="$(npx supabase status -o env 2>/dev/null || true)"
if [[ -z "$status_env" ]]; then
  printf 'supabase status failed; is local Supabase running?\n' >&2
  exit 1
fi

# Extract keys for dart-define only — never print or persist them in evidence.
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

  printf '\n=== P7M12 calendar-only acceptance locale=%s tag=%s ===\n' "$locale" "$tag"

  run_cleanup
  cleanup_ran=0

  docker exec -i "$container_name" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 -v tag="$tag" \
    < "$repo_root/scripts/test/p6m13_manual_fixture.sql"

  set +e
  flutter test integration_test/contracts/p6m13_manual_acceptance_test.dart \
    -d "$device_id" \
    --dart-define=SUPABASE_ANON_KEY="$anon_key" \
    --dart-define=SUPABASE_URL="$api_url" \
    --dart-define=P6M13_LOCALE="$locale" \
    --dart-define=P6M13_TAG="$tag" \
    --dart-define=P7M12_CALENDAR_ONLY=true
  flutter_exit=$?
  set -e

  run_cleanup
  cleanup_ran=1

  if (( flutter_exit != 0 )); then
    printf 'P7M12 Flutter locale=%s failed with exit %s\n' "$locale" "$flutter_exit" >&2
    exit "$flutter_exit"
  fi
  if (( cleanup_exit != 0 )); then
    exit "$cleanup_exit"
  fi
}

run_locale en EN
run_locale ar AR

printf '\nP7M12 calendar-only acceptance (EN + AR) passed.\n'
