#!/usr/bin/env bash
# Runs Flutter with local Supabase credentials (macOS / Linux).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

device="${1:-macos}"
supabase_url="${SUPABASE_URL:-}"
anon_key="${SUPABASE_ANON_KEY:-}"
local_env_path="$repo_root/supabase/.temp/local-run.env"
flutter_bin="${FLUTTER_BIN:-flutter}"

test_tcp_endpoint() {
  local url="$1"

  python3 - "$url" <<'PY'
import socket
import sys
from urllib.parse import urlparse

url = urlparse(sys.argv[1])
host = url.hostname
port = url.port or (443 if url.scheme == "https" else 80)
if not host:
    sys.exit(1)

try:
    with socket.create_connection((host, port), timeout=2):
        pass
except OSError:
    sys.exit(1)
PY
}

read_missing_env_values() {
  local contents="$1"
  local value

  while IFS= read -r line; do
    case "$line" in
      API_URL=*)
        if [[ -z "$supabase_url" ]]; then
          value="${line#API_URL=}"
          value="${value%\"}"
          supabase_url="${value#\"}"
        fi
        ;;
      ANON_KEY=*)
        if [[ -z "$anon_key" ]]; then
          value="${line#ANON_KEY=}"
          value="${value%\"}"
          anon_key="${value#\"}"
        fi
        ;;
    esac
  done <<< "$contents"
}

if [[ -z "$supabase_url" || -z "$anon_key" ]]; then
  if status_output="$(SUPABASE_TELEMETRY_DISABLED=true npx --yes supabase status -o env 2>&1)"; then
    read_missing_env_values "$status_output"
  elif [[ -f "$local_env_path" ]]; then
    read_missing_env_values "$(cat "$local_env_path")"
  else
    cat >&2 <<EOF
Could not read the local Supabase configuration.

Start Docker Desktop, then run:
  npx --yes supabase start

Then rerun:
  ./scripts/run-local.sh
EOF
    exit 1
  fi
fi

supabase_url="${supabase_url:-http://127.0.0.1:54321}"

if [[ -z "$anon_key" ]]; then
  echo "ANON_KEY not found in the local Supabase configuration." >&2
  exit 1
fi

mkdir -p "$(dirname "$local_env_path")"
cat > "$local_env_path" <<EOF
API_URL="$supabase_url"
ANON_KEY="$anon_key"
EOF
chmod 600 "$local_env_path"

if ! test_tcp_endpoint "$supabase_url"; then
  cat >&2 <<EOF
Local Supabase API is not reachable at $supabase_url.

Start Docker Desktop, then run:
  npx --yes supabase start

Then rerun:
  ./scripts/run-local.sh
EOF
  exit 1
fi

echo "Using API_URL=$supabase_url"
echo "Starting Flutter on device: $device"

"$flutter_bin" run -d "$device" \
  --dart-define=SUPABASE_URL="$supabase_url" \
  --dart-define=SUPABASE_ANON_KEY="$anon_key"
