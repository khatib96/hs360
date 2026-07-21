# Phase 7 M12 — Gate F Device Open-with Checklist

> **Gate F status:** `PASS / OWNER ACCEPTED — PHYSICAL IOS + ANDROID EMULATOR`
> **Permanent constraint:** `PHYSICAL ANDROID SMOKE — REQUIRED BEFORE PRODUCTION (OWNER-APPROVED DEFERRAL)`
> **M12 status:** `CLOSED / ACCEPTED`
> **Phase 7:** `CLOSED / ACCEPTED`
>
> Executed: **physical iPhone (USB)** EN+AR + **Android Emulator (Google Play)** EN+AR.
> Physical Android device smoke is **deferred by owner to pre-production** (not claimed PASS on a physical handset).
> The owner accepted Gate F and Phase 7 on 2026-07-22 with that constraint retained.

Do **not** store UDIDs, serials, personal IPs, or Supabase keys in evidence.

---

## Connectivity (executed)

| Target | URL form used | Notes |
|--------|---------------|-------|
| Physical iPhone | `http://<MAC_LAN_IP>:54321` | LAN IP redacted from evidence |
| Android Emulator | `http://10.0.2.2:54321` | Emulator alias only |
| Physical Android | — | **DEFERRED BY OWNER TO PRE-PRODUCTION** |

---

## Evidence layout

Durable under `docs/evidence/phase7_m12/gate_f/`.
Index: `EVIDENCE_INDEX.md` · Checksums: `SHA256SUMS.txt` · Narrative: `GATE_F_EXECUTION_SUMMARY.md`.

**iOS AR note:** After iOS EN PASS, AR hung on Dart VM Service; Android + iOS EN kept; AR re-run alone succeeded.

---

## iOS checklist (physical USB) — PASS

### F1 — App runs on real iPhone

| Field | Value |
|-------|--------|
| Device | Physical iOS |
| Locale | EN |
| Evidence | `ios/en/gf_ios_f01_or_f09_app_launch_en.png` |
| Result | **PASS** |

### F2 — Mapped event shows Directions

| Field | Value |
|-------|--------|
| Evidence | `ios/en/gf_ios_f02_or_f10_mapped_directions_en.png` |
| Result | **PASS** |

### F3 — Open with before any launch

| Field | Value |
|-------|--------|
| Evidence | `ios/en/gf_ios_f03_or_f11_open_with_sheet_en.png` |
| Result | **PASS** (no auto-launch before sheet) |

### F4 — Cancel closes sheet without launching

| Field | Value |
|-------|--------|
| Evidence | `ios/en/gf_ios_f04_or_f12_cancel_no_launch_en.png` |
| Result | **PASS** |

### F5 — Apple Maps always offered on iOS

| Field | Value |
|-------|--------|
| Evidence | `ios/en/gf_ios_f05_apple_maps_listed_en.png` |
| Result | **PASS** |

### F6 — Apple Maps opens correct destination

| Field | Value |
|-------|--------|
| Evidence | `ios/en/gf_ios_f06_apple_maps_after_launch_en.png` + `device_shots/ios_en/ios.apple_maps.txt` |
| Actual URI | `https://maps.apple.com/?daddr=29.339%2C48.075` (`launchUrl=true`) |
| Result | **PASS** |

### F7 — Other apps only per availability / resolver

| Field | Value |
|-------|--------|
| Evidence | `ios/en/gf_ios_f07_or_availability_en.png` |
| Result | **PASS** |

### F8 — AR sheet title + RTL

| Field | Value |
|-------|--------|
| Locale | AR |
| Evidence | `ios/ar/gf_ios_f08_or_f15_open_with_ar_rtl.png` |
| Result | **PASS** (`فتح باستخدام`) |
| Owner notes | AR completed on final AR-only retry after VM Service hang |

---

## Android checklist — PASS on Emulator (physical deferred)

> Owner waiver: physical handset smoke **deferred to pre-production**.  
> F9–F16 evidence below is from **Android Emulator Google Play** (`hs360_gate_f_api34`), not a physical phone.

### F9 — App runs (emulator stand-in)

| Field | Value |
|-------|--------|
| Device | Android Emulator (Google Play) |
| Evidence | `android_emulator/en/gf_and_f01_or_f09_app_launch_en.png` |
| Result | **PASS (emulator)** — physical Android **DEFERRED** |

### F10 — Mapped Directions visible

| Field | Value |
|-------|--------|
| Evidence | `android_emulator/en/gf_and_f02_or_f10_mapped_directions_en.png` |
| Result | **PASS (emulator)** |

### F11 — Open with before any launch

| Field | Value |
|-------|--------|
| Evidence | `android_emulator/en/gf_and_f03_or_f11_open_with_sheet_en.png` |
| Result | **PASS (emulator)** |

### F12 — Cancel does not launch

| Field | Value |
|-------|--------|
| Evidence | `android_emulator/en/gf_and_f04_or_f12_cancel_no_launch_en.png` |
| Result | **PASS (emulator)** |

### F13 — Google Maps available

| Field | Value |
|-------|--------|
| Evidence | `android_emulator/en/gf_and_f13_google_maps_availability_en.png` + Maps package preflight |
| Result | **PASS (emulator)** |

### F14 — Google Maps opens destination

| Field | Value |
|-------|--------|
| Evidence | `android_emulator/en/gf_and_f14_google_maps_after_launch_en.png` + `device_shots/.../android.google_maps.{txt,png}` |
| Actual | `google.navigation:q=29.339,48.075`; Maps foreground PASS |
| Result | **PASS (emulator)** |

### F15 — AR RTL

| Field | Value |
|-------|--------|
| Evidence | `android_emulator/ar/gf_and_f08_or_f15_open_with_ar_rtl.png` |
| Result | **PASS (emulator)** |

### F16 — missing / url_only (invalid = SQL/unit only)

| Field | Value |
|-------|--------|
| Evidence | `*_f16_missing_*`, `*_f16_url_only_browser_only_*`, `*_f16_url_only_browser_launched_*` (iOS + Android EN/AR) |
| Actual | `missing`: no Directions; `url_only`: Browser only; Browser `launchUrl=true` (Android → Chrome) |
| `invalid` | **Not device-seeded** — CSL CHECK; SQL/unit contract only |
| Result | **PASS** (missing + url_only); invalid deferred to SQL/unit |

---

## Related

| Item | Link |
|------|------|
| Detection / waiver (redacted) | `docs/evidence/phase7_m12/gate_f/DEVICE_PENDING.txt` |
| Evidence index | `docs/evidence/phase7_m12/gate_f/EVIDENCE_INDEX.md` |
| Execution summary | `docs/evidence/phase7_m12/gate_f/GATE_F_EXECUTION_SUMMARY.md` |
| Gate E item 19 | Covered by this Gate F packet (**PASS / OWNER ACCEPTED**) |
| Supporting unit tests | `calendar_open_with_sheet_test.dart` / launcher tests (not device proof) |
