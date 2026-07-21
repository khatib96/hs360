# Phase 7 M12 — Manual Acceptance Runbook (Gate E)

> **Database:** local/test Supabase only — never production.
> **UI:** real HS360 `App()` (integration driver).
> **Gate E status:** **`PASS / OWNER ACCEPTED`** (owner decision 2026-07-20).
> **Item 20:** PASS EVIDENCE (migration `104`).
> **Unchanged:** `M8 FLUTTER CLOSED / ACCEPTED` · Gate D `PASS / OWNER ACCEPTED`
> **M12:** `CLOSED / ACCEPTED`
> Phase 7 **CLOSED / ACCEPTED**.
>
> Gate F (2026-07-22): **`PASS / OWNER ACCEPTED — PHYSICAL IOS + ANDROID EMULATOR`**
> with **physical Android smoke required before production**.
> See `docs/evidence/phase7_m12/gate_f/`.

## Orchestrator (historical — do not re-run for this accept)

```bash
bash scripts/test/p7m12_gate_e_acceptance.sh supabase_db_hs360 macos
```

## Checklist summary (EN / AR) — owner accepted

| # | EN | AR | Notes |
|---|----|----|-------|
| 1–18, 20–21 | ACCEPTED | ACCEPTED | See evidence pack |
| 19 | ACCEPTED | ACCEPTED | Gate F physical iOS + Android Emulator packet |

## Owner gates

| Gate | Status |
|------|--------|
| D M8 | **PASS / OWNER ACCEPTED** |
| E this runbook | **PASS / OWNER ACCEPTED** |
| F device | **PASS / OWNER ACCEPTED — PHYSICAL IOS + ANDROID EMULATOR** (physical Android smoke required before production) |
| G perf | **PASS** |
| H | **FINAL PASS THROUGH 104** |
| Phase 7 | **CLOSED / ACCEPTED** |
| M12 | **CLOSED / ACCEPTED** |
