# Gate F — Execution Summary

**Status:** `GATE F PASS / OWNER ACCEPTED — PHYSICAL IOS + ANDROID EMULATOR`  
**Date:** 2026-07-22  
Owner accepted the packet and the documented device matrix. Final Gate H
subsequently passed and Phase 7 is **CLOSED / ACCEPTED**.

## Permanent owner constraint

`PHYSICAL ANDROID SMOKE — REQUIRED BEFORE PRODUCTION (OWNER-APPROVED DEFERRAL)`

This packet uses **physical iPhone (USB)** + **Android Emulator (Google Play)**.  
Physical Android device smoke remains a **pre-production** obligation and is **not** claimed here.

## Four platform/locale runs (actual)

| Platform | Locale | Orchestrator | Exit | PNG pack | External launches |
|----------|--------|--------------|------|----------|-------------------|
| Android Emulator | EN | `GATE_F_ANDROID_ONLY=1` (corrective pass 14) | **0** | 11 | Google Maps + Chrome |
| Android Emulator | AR | same | **0** | 12 | Google Maps + Chrome |
| Physical iOS | EN | `GATE_F_IOS_ONLY=1` | **0** | 11 | Apple Maps (`daddr=29.339,48.075`) + Browser |
| Physical iOS | AR | `GATE_F_IOS_ONLY=1 GATE_F_IOS_LOCALE=ar` (retry) | **0** | 12 | Apple Maps + Browser |

Cleanup counters after each orchestrator exit: **all 0**.  
Defines leftovers: **none** (mode 600 + EXIT trap).

## iOS AR VM Service hang (actual)

- After successful **iOS EN**, the combined iOS EN+AR job stuck on **Dart VM Service / Xcode install** for **iOS AR**.
- That job was aborted.
- **Android EN+AR evidence and iOS EN evidence were kept** (not wiped).
- **iOS AR** was re-run alone and **passed** (`ORCH_EXIT:0`, 12 PNGs, external proofs PASS).

## Harness corrective (shipped with this execution)

- No blanket `FlutterError.onError` overflow swallow; no fake `setSurfaceSize`.
- Device smoke requires `P7M12_GATE_F_DRY_LAUNCH=false`.
- Screenshots via extended driver (`takeScreenshot` / Android `convertFlutterSurfaceToImage`).
- url_only mandatory; no global Directions finder fallback.
- `invalid` = SQL/unit only.
- Android Browser uses Chrome navigate URI so Maps App Links do not steal `google.com/maps`.
- Local Network usage Debug-only; `NSBonjourServices` removed.
- Flutter-migrator `gradle.properties` flags reverted.

## Owner decision

F1–F16 and the evidence checksums were reviewed. Gate F is **PASS / OWNER
ACCEPTED** using physical iOS + Android Emulator. This acceptance does not claim
a physical Android handset run; that smoke remains mandatory before production.
