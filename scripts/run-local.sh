#!/usr/bin/env bash
# Runs Flutter with local Supabase credentials (macOS / Linux).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

device="${1:-ios}"
supabase_url="${SUPABASE_URL:-http://127.0.0.1:54321}"
anon_key="${SUPABASE_ANON_KEY:-}"
local_env_path="$repo_root/supabase/.temp/local-run.env"

test_tcp_endpoint() {
  local url="$1"
  local host port

  host="$(python3 -c "from urllib.parse import urlparse; u=urlparse('$url'); print(u.hostname or '')")"
  port="$(python3 -c "from urllib.parse import urlparse; u=urlparse('$url'); print(u.port or (443 if u.scheme == 'https' else 80))")"

  if [[ "$host" != "127.0.0.1" && "$host" != "localhost" && "$host" != "::1" ]]; then
    return 0
  fi

  python3 - "$host" "$port" <<'PY'
import socket
import sys

host, port = sys.argv[1], int(sys.argv[2])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(1)
try:
    sock.connect((host, port))
except OSError:
    sys.exit(1)
finally:
    sock.close()
PY
}

if [[ -z "$anon_key" && -f "$local_env_path" ]]; then
  while IFS= read -r line; do
    case "$line" in
      API_URL=*)
        supabase_url="${line#API_URL=}"
        supabase_url="${supabase_url%\"}"
        supabase_url="${supabase_url#\"}"
        ;;
      ANON_KEY=*)
        anon_key="${line#ANON_KEY=}"
        anon_key="${anon_key%\"}"
        anon_key="${anon_key#\"}"
        ;;
    esac
  done < "$local_env_path"
fi

if [[ -z "$anon_key" ]]; then
  if ! status_output="$(npx --yes supabase status -o env 2>&1)"; then
    echo "supabase status failed. Run: npx --yes supabase start" >&2
    exit 1
  fi

  while IFS= read -r line; do
    case "$line" in
      API_URL=*)
        supabase_url="${line#API_URL=}"
        supabase_url="${supabase_url%\"}"
        supabase_url="${supabase_url#\"}"
        ;;
      ANON_KEY=*)
        anon_key="${line#ANON_KEY=}"
        anon_key="${anon_key%\"}"
        anon_key="${anon_key#\"}"
        ;;
    esac
  done <<< "$status_output"

  if [[ -z "$anon_key" ]]; then
    echo "ANON_KEY not found in supabase status output." >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$local_env_path")"
cat > "$local_env_path" <<EOF
API_URL="$supabase_url"
ANON_KEY="$anon_key"
EOF

if ! test_tcp_endpoint "$supabase_url"; then
  cat >&2 <<EOF
Local Supabase API is not reachable at $supabase_url.

Start Docker Desktop, then run:
  npx --yes supabase start

If the local stack URL changed, delete:
  supabase/.temp/local-run.env

Then rerun:
  ./scripts/run-local.sh
EOF
  exit 1
fi

echo "Using API_URL=$supabase_url"
echo "Starting Flutter on device: $device"

flutter run -d "$device" \
  --dart-define=SUPABASE_URL="$supabase_url" \
  --dart-define=SUPABASE_ANON_KEY="$anon_key"
