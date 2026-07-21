# Gate E — Evidence Index

> Status: **`GATE E PASS / OWNER ACCEPTED`** (2026-07-20)
> Collected: 2026-07-20 · local Supabase · live `App()` on macOS
> Item 20: PASS EVIDENCE (migration `104`)
> Durable root: `docs/evidence/phase7_m12/gate_e/`
> Do **not** re-run Gate E for this acceptance.

## Checksum hygiene

Identical SHA-256 means **one visual state**, not two different proofs:

| Shared checksum pair | One state proves |
|----------------------|------------------|
| `*_10_agenda_after_manuals` ≡ `*_10b_month_counts_after_manuals` | Agenda + month counts in same frame |
| `*_11_wde_section` ≡ `*_12f_wde_cancelled` | Settings WDE after cancel |
| `*_12g_weekly_restored` ≡ `*_17_overdue_panel` | Weekly restored day includes overdue section |

EN story rows are cleared before AR (`p7m12_gate_e_clear_locale_story.sh`) so AR shows one Task, one Meeting, one overdue fixture (no EN duplicates).

## Live PNGs (EN + AR)

| Evidence ID | File | Items | Notes |
|-------------|------|-------|-------|
| `ge-*-01b` / `02` | setup + unconfigured settings | 1, 2 | Live unconfigured |
| `ge-*-03` | seven modes | 1 | Configured |
| `ge-*-05` / `06` | split + agenda | 3, 4, 7 | |
| `ge-*-07` / `08` / `10` | manuals success | 6, 8 | Untimed task + timed meeting |
| `ge-*-11`…`12g` | WDE lifecycle | 9, 10 | Live holiday → soft-conflict → cancel → weekly |
| `ge-*-17` | overdue panel | 15 | Badge only; no original_due/overdue_days in UI |
| `ge-*-15` | route missing coords | **20** | Employee selected; **Location unavailable**; mapped+missing same day; no day-error; no Directions on missing |
| `ge-*-16` | narrow | 17 | |

Checksums: `SHA256SUMS.txt` (40 PNGs).

## SQL / linked

| ID | Item | Result |
|----|------|--------|
| `ge-sql-20` | 20 | **FIXED** via `104` — `item20_route_sql.txt` |
| `ge-sql-15` | 15 | UI+SQL READY |
| `ge-sql-16` / `18` | 16, 18 | SQL PASS |
| `ge-sql-19` | 19 | **DEFERRED TO GATE F** |
| `ge-d-m8` | 12–13 | Gate D OWNER ACCEPTED (unchanged) |
| `ge-i21` | 21 | integrity EQUAL |
| `ge-cleanup` | cleanup | all 0 |

## Item 20 defect (resolved)

`P7M12-GE-I20-EXECUTION-SUMMARY` — FIXED by migration `104_phase_7_m12_route_event_contract_fix.sql`.
Historical note retained in `sql/item20_defect_execution_summary.txt` (status FIXED).
