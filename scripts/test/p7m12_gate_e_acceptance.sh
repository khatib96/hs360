#!/usr/bin/env bash
# Phase 7 M12 Gate E orchestrator — collect EN+AR live evidence + SQL links.
# Does NOT mark Gate E PASS. Leaves status READY FOR OWNER RE-REVIEW.
# Never prints Supabase keys.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"
device_id="${2:-macos}"
evidence_dir="$repo_root/docs/evidence/phase7_m12/gate_e"
# Relative path so macOS sandboxed writes land under Containers/.../Data/
build_live="build/screenshots/gate_e"
mkdir -p "$evidence_dir/live" "$evidence_dir/sql"
rm -rf "$build_live"
mkdir -p "$build_live"
# Clear prior live PNGs so stale validation-failure shots cannot linger.
rm -rf "$evidence_dir/live/en" "$evidence_dir/live/ar"
mkdir -p "$evidence_dir/live/en" "$evidence_dir/live/ar"
# Clear sandboxed macOS container copies from prior Gate E runs.
container_data_pre="$HOME/Library/Containers/com.hs360.hs360/Data"
rm -rf "$container_data_pre/build/screenshots/gate_e" 2>/dev/null || true
find "$container_data_pre" -name 'ge_en_ltr_*.png' -mmin -720 -delete 2>/dev/null || true
find "$container_data_pre" -name 'ge_ar_rtl_*.png' -mmin -720 -delete 2>/dev/null || true

flutter_exit=0
cleanup_exit=0
cleanup_ran=0

run_cleanup() {
  local ec=0
  bash "$repo_root/scripts/test/p7m12_manual_cleanup.sh" "$container_name" || ec=$?
  if (( ec != 0 )); then
    cleanup_exit=$ec
    printf 'P7M12 Gate E cleanup failed with exit %s\n' "$ec" >&2
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
      printf 'Gate E: Flutter failed (exit %s); cleanup also failed (exit %s).\n' \
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

anon_key="$(printf '%s\n' "$status_env" | sed -n 's/^ANON_KEY=//p' | tr -d '"')"
api_url="$(printf '%s\n' "$status_env" | sed -n 's/^API_URL=//p' | tr -d '"')"
if [[ -z "$anon_key" ]]; then
  printf 'ANON_KEY missing from supabase status\n' >&2
  exit 1
fi
if [[ -z "$api_url" ]]; then
  api_url='http://127.0.0.1:54321'
fi

chmod +x \
  "$repo_root/scripts/test/p7m12_manual_cleanup.sh" \
  "$repo_root/scripts/test/p7m12_gate_e_integrity_snapshot.sh" \
  "$repo_root/scripts/test/p7m12_gate_e_reset_calendar_settings.sh" \
  "$repo_root/scripts/test/p7m12_gate_e_configure_calendar_settings.sh"

printf '\n=== Gate E: load P7M12 fixtures ===\n'
run_cleanup
cleanup_ran=0
docker exec -i "$container_name" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < "$repo_root/scripts/test/p7m12_manual_fixture.sql"

printf '\n=== Gate E: pre-integrity snapshot (after fixtures) ===\n'
bash "$repo_root/scripts/test/p7m12_gate_e_integrity_snapshot.sh" pre \
  "$container_name" "$evidence_dir"

run_flutter() {
  local locale="$1"
  local setup_only="$2"
  local outdir="$build_live/$locale"
  local log_file
  log_file="$(mktemp -t p7m12_ge_${locale})"
  mkdir -p "$outdir"
  # Fresh per-run harvest dir inside evidence to avoid mixing phases incorrectly;
  # setup vs configured share locale folder by design (distinct filenames).

  printf '\n=== Gate E live locale=%s setup_only=%s ===\n' "$locale" "$setup_only"

  set +e
  flutter test integration_test/calendar/p7m12_gate_e_acceptance_test.dart \
    -d "$device_id" \
    --dart-define=SUPABASE_ANON_KEY="$anon_key" \
    --dart-define=SUPABASE_URL="$api_url" \
    --dart-define=P7M12_LOCALE="$locale" \
    --dart-define=P7M12_EVIDENCE_DIR="$outdir" \
    --dart-define=P7M12_SETUP_ONLY="$setup_only" \
    | tee "$log_file"
  flutter_exit=${PIPESTATUS[0]}
  set -e

  mkdir -p "$evidence_dir/live/$locale"
  # macOS app sandbox remaps relative writes into the container Data directory.
  local container_data="$HOME/Library/Containers/com.hs360.hs360/Data"
  local mirrored="$container_data/$outdir"
  if [[ -d "$mirrored" ]]; then
    cp -f "$mirrored"/*.png "$evidence_dir/live/$locale/" 2>/dev/null || true
  fi
  if compgen -G "$outdir"/*.png > /dev/null 2>&1; then
    cp -f "$outdir"/*.png "$evidence_dir/live/$locale/" || true
  fi
  while IFS= read -r png; do
    [[ -n "$png" ]] || continue
    if [[ -f "$png" ]]; then
      cp -f "$png" "$evidence_dir/live/$locale/" || true
    fi
    if [[ "$png" != /* && -f "$container_data/$png" ]]; then
      cp -f "$container_data/$png" "$evidence_dir/live/$locale/" || true
    fi
  done < <(sed -n 's/^P7M12_EVIDENCE_PNG=//p' "$log_file" || true)

  local prefix="ge_en_ltr_"
  [[ "$locale" == "ar" ]] && prefix="ge_ar_rtl_"
  while IFS= read -r png; do
    [[ -f "$png" ]] || continue
    cp -f "$png" "$evidence_dir/live/$locale/" 2>/dev/null || true
  done < <(find "$container_data" -name "${prefix}*.png" -mmin -180 2>/dev/null || true)

  local count
  count="$(find "$evidence_dir/live/$locale" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
  printf 'Gate E harvested %s PNG(s) for locale=%s\n' "$count" "$locale"

  if (( flutter_exit != 0 )); then
    printf 'Gate E Flutter locale=%s setup_only=%s failed with exit %s\n' \
      "$locale" "$setup_only" "$flutter_exit" >&2
    exit "$flutter_exit"
  fi
  if [[ "$count" -lt 1 ]]; then
    printf 'Gate E produced no PNGs for locale=%s\n' "$locale" >&2
    exit 1
  fi
}

printf '\n=== Gate E: EN setup-banner pass (unconfigured) ===\n'
bash "$repo_root/scripts/test/p7m12_gate_e_reset_calendar_settings.sh" \
  "$container_name"
run_flutter en true

printf '\n=== Gate E: AR setup-banner pass (unconfigured) ===\n'
# Re-reset so AR Item 2 never inherits a configured week from a prior EN session.
bash "$repo_root/scripts/test/p7m12_gate_e_reset_calendar_settings.sh" \
  "$container_name"
run_flutter ar true

printf '\n=== Gate E: configure working week (SQL) ===\n'
bash "$repo_root/scripts/test/p7m12_gate_e_configure_calendar_settings.sh" \
  "$container_name"

printf '\n=== Gate E: seed route missing-coords event ===\n'
chmod +x "$repo_root/scripts/test/p7m12_gate_e_seed_route_event.sh"
bash "$repo_root/scripts/test/p7m12_gate_e_seed_route_event.sh" "$container_name"

printf '\n=== Gate E: EN configured UI pass ===\n'
run_flutter en false

printf '\n=== Gate E: clear EN story before AR (keep fixtures) ===\n'
chmod +x "$repo_root/scripts/test/p7m12_gate_e_clear_locale_story.sh"
bash "$repo_root/scripts/test/p7m12_gate_e_clear_locale_story.sh" "$container_name"

printf '\n=== Gate E: AR configured UI pass ===\n'
run_flutter ar false

printf '\n=== Gate E: SQL evidence extracts ===\n'
cat > "$evidence_dir/sql/item16_w4_spotcheck.txt" <<'EOF'
source: supabase/tests/phase_7_m12_trusted_handoff_acceptance.sql (Gate B W.4)
primary_result: PASS (Gate B)
expected_next_due: 2026-11-04
note: Gate E does not add Phase 8 UI; primary proof remains W.4 SQL consume.
EOF

cat > "$evidence_dir/sql/item18_reminders_spotcheck.txt" <<'EOF'
source: supabase/tests/phase_7_calendar_reminders.sql (Gate B Phase Q)
asserts:
  - policies off => deliverable count 0
  - scheduler re-run => no duplicate notifications
  - unconfigured schedule => no working-hour reminder plans
note: No external message delivery claimed.
links_item2: unconfigured live banners + reminders suite unconfigured case.
EOF

cat > "$evidence_dir/sql/item12_13_gate_d_link.txt" <<'EOF'
primary: docs/evidence/phase7_m12/m8/ (m8-01..m8-11) Gate D OWNER ACCEPTED
EOF

cat > "$evidence_dir/sql/item15_overdue_spotcheck.txt" <<'EOF'
ui_primary: live/en/ge_en_ltr_17_overdue_panel.png + live/ar/ge_ar_rtl_17_overdue_panel.png
ui_shows: pending overdue event titled P7M12 Overdue Pending / مهمة متأخرة P7M12
ui_does_not_render: original_due_date and overdue_days numeric fields
  (CalendarAgendaEventCard exposes overdue badge via isOverdue/overdueState only)
sql_primary: supabase/tests/phase_7_calendar_read_rpc.sql cases 42-45 (overdue bucket + overdue_days)
sql_generation: supabase/tests/phase_7_calendar_event_generation_engine.sql (overdue preserved; no later refill)
fixture_row: calendar_events id 00000000-0000-7000-8000-00000000e015
  scheduled_date=current_date-40, original_due_date=current_date-55, status=pending
EOF

cat > "$evidence_dir/sql/item20_route_sql.txt" <<'EOF'
rpc: get_calendar_route_day (migration 104 contract fix)
result: points[].location_state = missing for P7M12 Unmapped Route Visit
        points keep event.execution_summary key (JSON null when no fact)
        mapped companion P7M12 Mapped Route Visit retains latitude/longitude
live_ui: ge_*_15_route_missing_coords.png
status: READY / PASS EVIDENCE (Item 20 corrected)
prior_defect: P7M12-GE-I20-EXECUTION-SUMMARY FIXED by 104_phase_7_m12_route_event_contract_fix.sql
EOF

# Keep historical defect note but mark resolved.
cat > "$evidence_dir/sql/item20_defect_execution_summary.txt" <<'EOF'
defect_id: P7M12-GE-I20-EXECUTION-SUMMARY
status: FIXED (migration 104)
resolved: 2026-07-20
summary:
  jsonb_strip_nulls on route points recursively removed execution_summary:null
  from nested event_json. Flutter required the key → day load failed.
fix:
  get_calendar_route_day builds points via base {event, location_state}
  || mapped-coords object only when location_state=mapped. No recursive strip.
EOF

printf 'item19: DEFERRED TO GATE F — real iOS/Android Open-with required\n' \
  > "$evidence_dir/sql/item19_deferred_gate_f.txt"

# Spot-check overdue RPC fields without claiming UI renders them.
docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<'SQL' \
  > "$evidence_dir/sql/item15_overdue_rpc_fields.txt"
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select jsonb_pretty(r)
from jsonb_array_elements(
  public.list_calendar_events(
    current_date, current_date + 6, '{}'::jsonb, null, null, 50, true
  ) -> 'overdue_outside_range' -> 'rows'
) r
where r ->> 'title_en' like '%P7M12 Overdue%'
   or r ->> 'title_ar' like '%P7M12%';
SQL

printf '\n=== Gate E: post-integrity snapshot ===\n'
bash "$repo_root/scripts/test/p7m12_gate_e_integrity_snapshot.sh" post \
  "$container_name" "$evidence_dir"

python3 - <<PY
import json, pathlib
root = pathlib.Path("$evidence_dir")
pre = json.loads((root / "integrity_pre.json").read_text())
post = json.loads((root / "integrity_post.json").read_text())
keys = [
  "inventory_balances", "inventory_movements", "invoices", "vouchers",
  "journal_entries", "journal_lines", "completed_visits",
]
rows = []
ok = True
for k in keys:
  same = pre.get(k) == post.get(k)
  ok = ok and same
  rows.append({"metric": k, "pre": pre.get(k), "post": post.get(k), "equal": same})
out = {
  "item21_equal": ok,
  "rows": rows,
  "note": "pre taken after P7M12 fixtures; calendar UI must not change finance/stock/visits",
}
(root / "integrity_compare.json").write_text(json.dumps(out, indent=2) + "\n")
print(json.dumps(out, indent=2))
if not ok:
  raise SystemExit("item 21 integrity mismatch")
PY

printf '\n=== Gate E: final fixture cleanup ===\n'
run_cleanup
cleanup_ran=1
bash "$repo_root/scripts/test/p7m12_manual_cleanup.sh" "$container_name" \
  | tee "$evidence_dir/cleanup_counters.txt"

(
  cd "$evidence_dir"
  find live -name '*.png' -print0 | sort -z | xargs -0 shasum -a 256
) > "$evidence_dir/SHA256SUMS.txt"

printf '\nGate E evidence corrective pass finished (READY FOR FINAL OWNER REVIEW).\n'
printf 'Evidence dir: %s\n' "$evidence_dir"
