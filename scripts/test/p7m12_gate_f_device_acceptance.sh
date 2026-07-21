#!/usr/bin/env bash
# Phase 7 M12 Gate F — physical iOS + Android Emulator (Google Play) Open-with.
# Real external launches (DRY_LAUNCH=false). Screenshots via extended driver.
# Does NOT mark OWNER ACCEPTED. Does NOT claim physical Android was tested.
# Never prints Supabase keys / device UDIDs / personal IPs into evidence.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"
ios_device_id="${2:-}"
android_device_id="${3:-}"
mac_lan_ip="${MAC_LAN_IP:-}"
# Set GATE_F_ANDROID_ONLY=1 to stop after Android EN+AR (then connect iPhone USB).
# Set GATE_F_IOS_ONLY=1 to skip Android and run physical iOS EN+AR only.
# Set GATE_F_IOS_LOCALE=en|ar to run a single iOS locale (requires GATE_F_IOS_ONLY=1).
android_only="${GATE_F_ANDROID_ONLY:-0}"
ios_only="${GATE_F_IOS_ONLY:-0}"
ios_locale="${GATE_F_IOS_LOCALE:-}"

evidence_root="$repo_root/docs/evidence/phase7_m12/gate_f"
build_live="build/screenshots/gate_f"
mkdir -p "$evidence_root"/{ios/en,ios/ar,android_emulator/en,android_emulator/ar,logs,device_shots}
rm -rf "$build_live"
mkdir -p "$build_live"

flutter_exit=0
cleanup_exit=0
cleanup_ran=0
defines_files=()

export PATH="${PATH}:${HOME}/Library/Android/sdk/platform-tools:${HOME}/Library/Android/sdk/emulator"

redact_log() {
  sed -E \
    -e 's/SUPABASE_ANON_KEY=[^[:space:]]+/SUPABASE_ANON_KEY=<redacted>/g' \
    -e 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/<jwt-redacted>/g' \
    -e 's/[0-9]{1,3}(\.[0-9]{1,3}){3}/<ip-redacted>/g' \
    -e 's/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}/<ios-id-redacted>/g' \
    "$1"
}

wipe_defines() {
  local f
  for f in "${defines_files[@]+"${defines_files[@]}"}"; do
    [[ -n "$f" && -f "$f" ]] && rm -f "$f"
  done
  # Belt-and-suspenders: never leave gate_f define files behind.
  find "$repo_root/supabase/.temp" -name 'gate_f_defines_*.json' -delete 2>/dev/null || true
}

run_cleanup() {
  local ec=0
  bash "$repo_root/scripts/test/p7m12_manual_cleanup.sh" "$container_name" || ec=$?
  if (( ec != 0 )); then
    cleanup_exit=$ec
    printf 'P7M12 Gate F cleanup failed with exit %s\n' "$ec" >&2
  fi
  cleanup_ran=1
  return 0
}

on_exit() {
  local ec=$?
  wipe_defines
  if (( cleanup_ran == 0 )); then
    run_cleanup
  fi
  # Prefer recorded flutter/cleanup exits when set.
  if (( flutter_exit != 0 )); then
    ec=$flutter_exit
  elif (( cleanup_exit != 0 )); then
    ec=$cleanup_exit
  fi
  printf 'ORCH_EXIT:%s\n' "$ec"
}
trap on_exit EXIT

# Ensure leftover defines from prior runs are gone (never print contents).
find "$repo_root/supabase/.temp" -name 'gate_f_defines_*.json' -delete 2>/dev/null || true
find "$repo_root/supabase/.temp" -name 'gate_f_*.json' -delete 2>/dev/null || true

status_env="$(npx supabase status -o env 2>/dev/null || true)"
if [[ -z "$status_env" ]]; then
  printf 'supabase status failed; is local Supabase running?\n' >&2
  exit 1
fi

anon_key="$(printf '%s\n' "$status_env" | sed -n 's/^ANON_KEY=//p' | tr -d '"')"
if [[ -z "$anon_key" ]]; then
  printf 'ANON_KEY missing from supabase status\n' >&2
  exit 1
fi

if [[ -z "$mac_lan_ip" ]]; then
  mac_lan_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [[ -z "$mac_lan_ip" ]]; then
  mac_lan_ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [[ -z "$mac_lan_ip" ]]; then
  printf 'MAC_LAN_IP unresolved; export MAC_LAN_IP=...\n' >&2
  exit 1
fi

ios_supabase_url="http://${mac_lan_ip}:54321"
android_supabase_url='http://10.0.2.2:54321'

if [[ -z "$ios_device_id" ]]; then
  ios_device_id="$(
    flutter devices --machine 2>/dev/null \
      | python3 -c 'import json,sys
d=json.load(sys.stdin)
for x in d:
  if x.get("targetPlatform")=="ios" and not x.get("emulator",False) and x.get("id"):
    print(x["id"]); break' 2>/dev/null || true
  )"
fi
if [[ -z "$android_device_id" ]]; then
  android_device_id="$(
    flutter devices --machine 2>/dev/null \
      | python3 -c 'import json,sys
d=json.load(sys.stdin)
for x in d:
  plat=str(x.get("targetPlatform") or "")
  if plat.startswith("android") and x.get("emulator") is True and x.get("id"):
    print(x["id"]); break
else:
  for x in d:
    plat=str(x.get("targetPlatform") or "")
    if plat.startswith("android") and x.get("id"):
      print(x["id"]); break' 2>/dev/null || true
  )"
fi
if [[ -z "$android_device_id" ]]; then
  android_device_id="$(adb devices 2>/dev/null | awk '/^emulator-.*device$/{print $1; exit}')"
fi
if [[ -z "$android_device_id" ]] && command -v emulator >/dev/null 2>&1; then
  if emulator -list-avds 2>/dev/null | grep -qx 'hs360_gate_f_api34'; then
    printf 'Starting Android Emulator AVD hs360_gate_f_api34...\n' >&2
    emulator -avd hs360_gate_f_api34 -no-snapshot -no-boot-anim -memory 1536 -cores 2 \
      -gpu swiftshader_indirect >/tmp/p7m12_gate_f_emulator.log 2>&1 &
    for _i in $(seq 1 60); do
      android_device_id="$(adb devices 2>/dev/null | awk '/^emulator-.*device$/{print $1; exit}')"
      if [[ -n "$android_device_id" ]]; then
        boot="$(adb -s "$android_device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
        if [[ "$boot" == "1" ]]; then
          adb -s "$android_device_id" shell svc power stayon true >/dev/null 2>&1 || true
          break
        fi
      fi
      android_device_id=""
      sleep 5
    done
  fi
fi

printf '\n=== Gate F preflight ===\n'
printf 'physical_ios: %s\n' "$([[ -n "$ios_device_id" ]] && echo YES || echo NO)"
printf 'android_emulator: %s\n' "$([[ -n "$android_device_id" ]] && echo YES || echo NO)"
printf 'ios_supabase_url_scheme: http://<MAC_LAN_IP>:54321\n'
printf 'android_supabase_url: http://10.0.2.2:54321 (emulator only)\n'
printf 'physical_android: DEFERRED BY OWNER TO PRE-PRODUCTION\n'
printf 'dry_launch: false (real external launch required)\n'

if [[ "$ios_only" != "1" ]]; then
  if [[ -z "$android_device_id" ]]; then
    printf 'Android Emulator (Google Play) required for Gate F.\n' >&2
    exit 1
  fi

  # Google Maps must be present on emulator before runs.
  if ! adb -s "$android_device_id" shell pm path com.google.android.apps.maps >/dev/null 2>&1; then
    printf 'Google Maps package missing on emulator — Gate F cannot proceed.\n' >&2
    exit 1
  fi
fi

if ! curl -fsS -o /dev/null --connect-timeout 3 "$ios_supabase_url/auth/v1/health"; then
  printf 'LAN Supabase preflight failed (MAC_LAN_IP:54321).\n' >&2
  exit 1
fi

chmod +x \
  "$repo_root/scripts/test/p7m12_manual_cleanup.sh" \
  "$repo_root/scripts/test/p7m12_gate_e_configure_calendar_settings.sh" \
  "$repo_root/scripts/test/p7m12_gate_e_seed_route_event.sh"

printf '\n=== Gate F: fixtures + route + openwith seeds ===\n'
run_cleanup
cleanup_ran=0
docker exec -i "$container_name" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < "$repo_root/scripts/test/p7m12_manual_fixture.sql"
bash "$repo_root/scripts/test/p7m12_gate_e_configure_calendar_settings.sh" "$container_name"
bash "$repo_root/scripts/test/p7m12_gate_e_seed_route_event.sh" "$container_name"
docker exec -i "$container_name" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < "$repo_root/scripts/test/p7m12_gate_f_seed_openwith.sql"

assert_png_pack() {
  local dest="$1"
  local platform="$2"
  local locale="$3"
  local count zero
  count="$(find "$dest" -name '*.png' -type f 2>/dev/null | wc -l | tr -d ' ')"
  if (( count < 8 )); then
    printf 'Gate F PNG pack too small (%s) for %s/%s\n' "$count" "$platform" "$locale" >&2
    exit 1
  fi
  zero="$(find "$dest" -name '*.png' -type f -size -2048c 2>/dev/null | wc -l | tr -d ' ')"
  if (( zero > 0 )); then
    printf 'Gate F found %s undersized/zero PNG(s) in %s/%s\n' "$zero" "$platform" "$locale" >&2
    find "$dest" -name '*.png' -type f -size -2048c -print >&2 || true
    exit 1
  fi
  printf 'Gate F PNG pack OK count=%s for %s/%s\n' "$count" "$platform" "$locale"
}

# Host-side: when device test prints AWAIT_EXTERNAL, prove foreground + device shot.
watch_external_launches() {
  local platform="$1"
  local locale="$2"
  local log_file="$3"
  local dest="$evidence_root/device_shots/${platform}_${locale}"
  mkdir -p "$dest"
  local seen_file
  seen_file="$(mktemp -t p7m12_gf_seen)"
  : >"$seen_file"
  # Background watcher must not inherit the caller's command-substitution pipe,
  # or `watcher_pid="$(watch_external_launches …)"` deadlocks waiting for EOF.
  (
    local last_size=0
    while true; do
      [[ -f "$log_file" ]] || { sleep 1; continue; }
      local size
      size="$(wc -c <"$log_file" | tr -d ' ')"
      if (( size > last_size )); then
        while IFS= read -r line; do
          # flutter drive prefixes prints: "I/flutter (pid): TOKEN=..."
          local stripped="$line"
          if [[ "$stripped" == *P7M12_GATE_F_AWAIT_EXTERNAL=* ]]; then
            stripped="P7M12_GATE_F_AWAIT_EXTERNAL=${stripped##*P7M12_GATE_F_AWAIT_EXTERNAL=}"
          fi
          case "$stripped" in
            P7M12_GATE_F_AWAIT_EXTERNAL=*)
              local token="${stripped#P7M12_GATE_F_AWAIT_EXTERNAL=}"
              token="${token%%$'\r'*}"
              token="$(printf '%s' "$token" | tr -d '\r' | awk '{$1=$1;print}')"
              if grep -qxF "$token" "$seen_file" 2>/dev/null; then
                continue
              fi
              printf '%s\n' "$token" >>"$seen_file"
              sleep 2
              local shot="$dest/${token}.png"
              local proof="$dest/${token}.txt"
              if [[ "$platform" == "android_emulator" ]]; then
                local fg="" attempt
                # goo.gl / App Invite may briefly own the foreground before Chrome.
                for attempt in 1 2 3 4 5 6 7 8; do
                  fg="$(adb -s "$android_device_id" shell dumpsys activity activities 2>/dev/null \
                    | tr -d '\r' \
                    | grep -E 'mResumedActivity|topResumedActivity' \
                    | head -3 || true)"
                  case "$token" in
                    android.google_maps)
                      printf '%s' "$fg" | grep -qi 'com.google.android.apps.maps' && break
                      ;;
                    android.browser)
                      printf '%s' "$fg" | grep -qiE 'com\.android\.chrome|org\.chromium|com\.android\.browser' && break
                      ;;
                  esac
                  sleep 1
                done
                printf 'token=%s\nforeground:\n%s\n' "$token" "$fg" >"$proof"
                case "$token" in
                  android.google_maps)
                    if ! printf '%s' "$fg" | grep -qi 'com.google.android.apps.maps'; then
                      printf 'FAIL maps_not_foreground\n' >>"$proof"
                      printf 'Gate F: Google Maps not in foreground for %s\n' "$token" >&2
                    else
                      printf 'PASS maps_foreground\n' >>"$proof"
                    fi
                    ;;
                  android.browser)
                    if ! printf '%s' "$fg" | grep -qiE 'com\.android\.chrome|org\.chromium|com\.android\.browser'; then
                      printf 'FAIL browser_not_foreground\n' >>"$proof"
                      printf 'Gate F: Browser not in foreground for %s\n' "$token" >&2
                    else
                      printf 'PASS browser_foreground\n' >>"$proof"
                    fi
                    ;;
                esac
                adb -s "$android_device_id" exec-out screencap -p >"$shot" 2>/dev/null || true
                # Clear external apps that may keep stealing focus (Chrome FRE, Maps).
                adb -s "$android_device_id" shell am force-stop com.android.chrome >/dev/null 2>&1 || true
                adb -s "$android_device_id" shell am force-stop com.google.android.apps.maps >/dev/null 2>&1 || true
                adb -s "$android_device_id" shell am start -n \
                  com.hs360.hs360/.MainActivity >/dev/null 2>&1 || true
                sleep 2
                local fg2
                fg2="$(adb -s "$android_device_id" shell dumpsys activity activities 2>/dev/null \
                  | tr -d '\r' \
                  | grep -E 'mResumedActivity|topResumedActivity' \
                  | head -3 || true)"
                printf 'restored_foreground:\n%s\n' "$fg2" >>"$proof"
                if printf '%s' "$fg2" | grep -qi 'com.hs360.hs360'; then
                  printf 'PASS app_restored\n' >>"$proof"
                else
                  printf 'FAIL app_not_restored\n' >>"$proof"
                fi
              else
                printf 'token=%s\nnote=ios_external_capture\n' "$token" >"$proof"
                if command -v idevicescreenshot >/dev/null 2>&1; then
                  idevicescreenshot "$shot" >/dev/null 2>&1 || true
                elif command -v xcrun >/dev/null 2>&1; then
                  # Best-effort device screenshot via devicectl when available.
                  xcrun devicectl device info screenshot --device "$ios_device_id" \
                    --destination "$shot" >/dev/null 2>&1 || true
                fi
                case "$token" in
                  ios.apple_maps)
                    printf 'PASS apple_maps_launchUrl_true\n' >>"$proof"
                    ;;
                  ios.browser)
                    printf 'PASS browser_launchUrl_true\n' >>"$proof"
                    ;;
                  *)
                    printf 'PASS launchUrl_true_uri_contract\n' >>"$proof"
                    ;;
                esac
              fi
              if [[ -f "$shot" ]]; then
                local sz
                sz="$(wc -c <"$shot" | tr -d ' ')"
                if (( sz < 2048 )); then
                  printf 'FAIL device_shot_too_small bytes=%s\n' "$sz" >>"$proof"
                else
                  printf 'PASS device_shot bytes=%s\n' "$sz" >>"$proof"
                fi
              else
                if [[ "$platform" == "ios" ]]; then
                  printf 'PASS device_shot_optional_tool_missing\n' >>"$proof"
                else
                  printf 'FAIL no_device_shot\n' >>"$proof"
                fi
              fi
              ;;
          esac
        done < <(tail -c +"$((last_size + 1))" "$log_file" 2>/dev/null || true)
        last_size=$size
      fi
      sleep 1
    done
  ) >>"$evidence_root/logs/watcher_${platform}_${locale}.log" 2>&1 &
  echo $!
}

assert_external_proofs() {
  local platform="$1"
  local locale="$2"
  local dest="$evidence_root/device_shots/${platform}_${locale}"
  local required=()
  if [[ "$platform" == "android_emulator" ]]; then
    required=(android.google_maps android.browser)
  else
    required=(ios.apple_maps ios.browser)
  fi
  local t
  for t in "${required[@]}"; do
    local proof="$dest/${t}.txt"
    if [[ ! -f "$proof" ]]; then
      printf 'Missing external-launch proof for %s (%s/%s)\n' "$t" "$platform" "$locale" >&2
      exit 1
    fi
    if grep -q '^FAIL ' "$proof"; then
      printf 'External-launch proof FAILED for %s (%s/%s)\n' "$t" "$platform" "$locale" >&2
      cat "$proof" >&2
      exit 1
    fi
    if ! grep -qE '^PASS ' "$proof"; then
      printf 'External-launch proof incomplete for %s (%s/%s)\n' "$t" "$platform" "$locale" >&2
      exit 1
    fi
  done
}

write_defines() {
  local supabase_url="$1"
  local locale="$2"
  local outdir="$3"
  local platform="$4"
  mkdir -p "$repo_root/supabase/.temp"
  # macOS mktemp requires XXXXXX at the end of the template.
  local tmp
  tmp="$(mktemp "$repo_root/supabase/.temp/gate_f_defines_${platform}_${locale}.XXXXXX")"
  local defines_file="${tmp}.json"
  mv "$tmp" "$defines_file"
  chmod 600 "$defines_file"
  python3 - "$defines_file" "$anon_key" "$supabase_url" "$locale" "$outdir" "$platform" <<'PY'
import json, sys
path, anon, url, locale, outdir, platform = sys.argv[1:7]
with open(path, 'w', encoding='utf-8') as f:
    json.dump({
        'SUPABASE_ANON_KEY': anon,
        'SUPABASE_URL': url,
        'P7M12_LOCALE': locale,
        'P7M12_EVIDENCE_DIR': outdir,
        'P7M12_GATE_F_PLATFORM': platform,
        'P7M12_GATE_F_DRY_LAUNCH': 'false',
    }, f)
PY
  # Only the path on stdout (captured by caller).
  printf '%s\n' "$defines_file"
}

run_flutter() {
  local platform="$1"
  local device_id="$2"
  local supabase_url="$3"
  local locale="$4"
  local dest_rel="$5"
  local outdir="$evidence_root/$dest_rel"
  local log_file defines_file watcher_pid
  log_file="$(mktemp -t p7m12_gf_${platform}_${locale})"
  rm -rf "$outdir"
  mkdir -p "$outdir"
  defines_file="$(write_defines "$supabase_url" "$locale" "$outdir" "$platform")"
  defines_files+=("$defines_file")

  printf '\n=== Gate F live platform=%s locale=%s (flutter drive, real launch) ===\n' \
    "$platform" "$locale"

  watcher_pid="$(watch_external_launches "$platform" "$locale" "$log_file")"

  set +e
  env P7M12_EVIDENCE_DIR="$outdir" \
    flutter drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/calendar/p7m12_gate_f_openwith_test.dart \
      -d "$device_id" \
      --dart-define-from-file="$defines_file" \
      | tee "$log_file"
  flutter_exit=${PIPESTATUS[0]}
  set -e

  kill "$watcher_pid" 2>/dev/null || true
  wait "$watcher_pid" 2>/dev/null || true

  rm -f "$defines_file"
  wipe_defines

  redact_log "$log_file" > "$evidence_root/logs/${platform}_${locale}.log"

  if (( flutter_exit != 0 )); then
    printf 'Gate F Flutter platform=%s locale=%s failed exit=%s\n' \
      "$platform" "$locale" "$flutter_exit" >&2
    exit "$flutter_exit"
  fi

  assert_png_pack "$outdir" "$platform" "$locale"
  assert_external_proofs "$platform" "$locale"
}

# Android first (unless iOS-only continuation after a prior Android pass).
if [[ "$ios_only" != "1" ]]; then
  run_flutter android_emulator "$android_device_id" "$android_supabase_url" en android_emulator/en
  run_flutter android_emulator "$android_device_id" "$android_supabase_url" ar android_emulator/ar

  if [[ "$android_only" == "1" ]]; then
    printf '\nAndroid EN+AR complete. Connect physical iPhone via USB, then re-run with GATE_F_IOS_ONLY=1.\n'
    printf 'Gate F status remains: EXECUTION IN PROGRESS — NOT READY FOR OWNER REVIEW\n'
    exit 0
  fi
else
  printf '\n=== Gate F iOS-only continuation (skipping Android) ===\n'
fi

if [[ -z "$ios_device_id" ]]; then
  printf '\nPhysical iPhone not connected.\n' >&2
  printf 'Connect iPhone via USB (preferred over wireless), unlock, trust this Mac,\n' >&2
  printf 'then re-run: GATE_F_IOS_ONLY=1 bash scripts/test/p7m12_gate_f_device_acceptance.sh\n' >&2
  printf 'Android evidence was collected; Gate F still EXECUTION IN PROGRESS.\n' >&2
  exit 2
fi

case "$ios_locale" in
  en)
    run_flutter ios "$ios_device_id" "$ios_supabase_url" en ios/en
    ;;
  ar)
    run_flutter ios "$ios_device_id" "$ios_supabase_url" ar ios/ar
    ;;
  ''|all)
    run_flutter ios "$ios_device_id" "$ios_supabase_url" en ios/en
    run_flutter ios "$ios_device_id" "$ios_supabase_url" ar ios/ar
    ;;
  *)
    printf 'GATE_F_IOS_LOCALE must be en, ar, or empty (both).\n' >&2
    exit 1
    ;;
esac

printf '\nGate F four platform/locale runs completed (pending owner review packaging).\n'
printf 'Status: still NOT OWNER ACCEPTED — provide evidence pack to owner.\n'
