# Gate F — Evidence Index

> Status: **`GATE F PASS / OWNER ACCEPTED — PHYSICAL IOS + ANDROID EMULATOR`** (2026-07-22)
> Permanent constraint: **`PHYSICAL ANDROID SMOKE — REQUIRED BEFORE PRODUCTION (OWNER-APPROVED DEFERRAL)`**
> Final Gate H **PASS**. Phase 7 **CLOSED / ACCEPTED**.
> Durable root: `docs/evidence/phase7_m12/gate_f/`
> Checksums: `SHA256SUMS.txt` (58 files: Flutter PNGs + host device-shot proofs)

## Scope of this packet

| Platform | What was run | Locales | Result |
|----------|--------------|---------|--------|
| Physical iPhone (USB) | Open-with device smoke via `flutter drive` + extended driver | EN + AR | **PASS** (exit 0) |
| Android Emulator (Google Play API 34, `hs360_gate_f_api34`) | Same harness; real Google Maps + Chrome | EN + AR | **PASS** (exit 0) |
| Physical Android | — | — | **DEFERRED BY OWNER TO PRE-PRODUCTION** |

## Harness notes (actual)

- `P7M12_GATE_F_DRY_LAUNCH=false` (URI recording alone is not external-launch proof).
- Screenshots: `takeScreenshot` + Android `convertFlutterSurfaceToImage` + `integration_test_driver_extended` `onScreenshot`.
- Android external proof: foreground package + `adb screencap` under `device_shots/`.
- iOS external proof: `launchUrl==true` + destination URI contract; host device PNG optional (tool missing → documented PASS optional).
- `invalid` location_state: SQL/unit only (not device-seedable under CSL CHECK).
- Defines: mode 600 + EXIT trap; none left after runs.

## iOS AR restart (documented)

1. First `GATE_F_IOS_ONLY=1` run: **iOS EN completed** (11 PNGs + Apple Maps / Browser proofs).
2. **iOS AR** then hung on Flutter/Xcode **Dart VM Service** discovery after EN.
3. Orchestrator was stopped; **Android evidence and iOS EN were preserved**.
4. Final success: `GATE_F_IOS_ONLY=1 GATE_F_IOS_LOCALE=ar` → **iOS AR exit 0** (12 PNGs + proofs).

## Flutter PNG packs

| Locale pack | Count | Undersize (&lt;2KB) | Notes |
|-------------|-------|---------------------|-------|
| `android_emulator/en/` | 11 | 0 | Includes Maps + url_only Browser frames |
| `android_emulator/ar/` | 12 | 0 | Includes AR RTL Open-with |
| `ios/en/` | 11 | 0 | Includes Apple Maps after-launch |
| `ios/ar/` | 12 | 0 | Final AR-only retry after VM hang |

Representative IDs (filenames on disk use `gf_and_*` / `gf_ios_*` prefixes):

| Evidence ID | Covers |
|-------------|--------|
| `gf_*-f01_or_f09_app_launch_*` | App launch / sign-in |
| `gf_*-route_day_loaded_*` | Route day + Field Ahmad |
| `gf_*-f02_or_f10_mapped_directions_*` | Mapped Directions visible |
| `gf_*-f03_or_f11_open_with_sheet_*` | Open-with before launch |
| `gf_ios_f05_apple_maps_listed_*` | Apple Maps listed (iOS) |
| `gf_and_f13_google_maps_availability_*` | Google Maps row (Android emulator) |
| `gf_*-f04_or_f12_cancel_no_launch_*` | Cancel without launch |
| `gf_ios_f06_apple_maps_after_launch_*` | After Apple Maps choice |
| `gf_and_f14_google_maps_after_launch_*` | After Google Maps choice |
| `gf_ios_f08_or_f15_open_with_ar_rtl` / `gf_and_f08_or_f15_*` | AR RTL title |
| `gf_*-f16_missing_*` | Unmapped / missing — no Directions |
| `gf_*-f16_url_only_browser_only_*` | url_only Browser-only sheet |
| `gf_*-f16_url_only_browser_launched_*` | After Browser launch |

## Host external-launch proofs

| Proof path | Result |
|------------|--------|
| `device_shots/android_emulator_en/android.google_maps.{txt,png}` | PASS maps foreground + device shot |
| `device_shots/android_emulator_en/android.browser.{txt,png}` | PASS Chrome foreground + device shot |
| `device_shots/android_emulator_ar/android.google_maps.{txt,png}` | PASS |
| `device_shots/android_emulator_ar/android.browser.{txt,png}` | PASS |
| `device_shots/ios_en/ios.apple_maps.txt` | PASS `launchUrl` true; daddr `29.339,48.075` |
| `device_shots/ios_en/ios.browser.txt` | PASS `launchUrl` true |
| `device_shots/ios_ar/ios.apple_maps.txt` | PASS |
| `device_shots/ios_ar/ios.browser.txt` | PASS |

## Related

| File | Role |
|------|------|
| `GATE_F_EXECUTION_SUMMARY.md` | Execution narrative + constraints |
| `DEVICE_PENDING.txt` | Redacted device detection + waiver |
| `SHA256SUMS.txt` | Integrity |
| `docs/PHASE_7_M12_DEVICE_OPENWITH.md` | F1–F16 checklist results |
