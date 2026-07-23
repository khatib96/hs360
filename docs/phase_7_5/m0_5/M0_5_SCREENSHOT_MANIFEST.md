# Phase 7.5 M0.5 — Pre-Change Screenshot Manifest

> Status: **RECORDED**
>
> These are pre-shell-change baselines. They document the current product; they
> are not approval of every current layout choice.

## Durable Baseline Set

| Phase | Surface | Locale / direction | Viewport evidence | File |
|---|---|---|---|---|
| 5 | Invoice list | Arabic / RTL | Desktop, 1440×1000 @2x | `screenshots/invoice_list_desktop_ar.png` |
| 5 | Invoice detail | Arabic / RTL | Narrow, 390×844 @2x | `screenshots/invoice_detail_narrow_ar.png` |
| 5 | Invoice list | English / LTR | Desktop, 1440×1000 @2x | `screenshots/invoice_list_desktop_en.png` |
| 5 | Invoice detail | English / LTR | Narrow, 390×844 @2x | `screenshots/invoice_detail_narrow_en.png` |
| 6 | Contract detail | Arabic / RTL | Desktop, 1280×900 @2x | `screenshots/m0_5_contract_detail_desktop_ar_rtl.png` |
| 6 | Contract detail | English / LTR | Desktop, 1280×900 @2x | `screenshots/m0_5_contract_detail_desktop_en_ltr.png` |
| 6 | Contract detail | Arabic / RTL | Narrow, 390×844 @2x | `screenshots/m0_5_contract_detail_narrow_ar_rtl.png` |
| 6 | Contract detail | English / LTR | Narrow, 390×844 @2x | `screenshots/m0_5_contract_detail_narrow_en_ltr.png` |
| 7 | Scoped calendar | English / LTR | Mobile, 360×800 | `screenshots/m11_01_customer_scope_mobile_360_en_ltr.png` |
| 7 | Scoped calendar | Arabic / RTL | Mobile, 360×800 | `screenshots/m11_02_customer_scope_mobile_360_ar_rtl.png` |
| 7 | Calendar filter clearing | English / LTR | Desktop, 1280×800 | `screenshots/m11_05_clear_filter_desktop_en_ltr.png` |
| 7 | Calendar filter clearing | Arabic / RTL | Desktop, 1280×800 | `screenshots/m11_06_clear_filter_desktop_ar_rtl.png` |

The Phase 5 and Phase 6 images are deterministic renders of production screens
with repository fixtures. The Phase 7 set is the accepted M11 deterministic
evidence. The accepted live Phase 7 Arabic/English desktop and narrow evidence
remains under `docs/evidence/phase7_m12/gate_e/live/`.

## Reproduction

```text
flutter test test/screenshots/invoice_screenshots.dart
flutter test test/screenshots/phase_7_5_m0_5_contract_screenshots.dart
flutter test test/screenshots/calendar_m11_screenshots.dart
```

Copy only the named PNGs from `build/screenshots/` into this directory's
`screenshots/` folder.

## Known Baseline Defect

At 390 px, two rows in the current contract overview section overflow
horizontally in both Arabic and English. The screenshot harness records this
known pre-change defect explicitly instead of hiding it. Its correction belongs
to the shared/detail responsive work in M1/M3, with a focused regression test.

No comparable overflow was reported by the invoice or calendar baseline
harnesses.

## SHA-256

| File | SHA-256 |
|---|---|
| `invoice_detail_narrow_ar.png` | `bd85ddd109d1fe2719f61952e44cf64ef406803c1b4fcfdbb2d2ced232900d2c` |
| `invoice_detail_narrow_en.png` | `554b7c8773a0d353d5cc4f233082a070f0bd0d09c21f5ed1be2c682a86b2b6fe` |
| `invoice_list_desktop_ar.png` | `b8171208622d4d61d8d3b7002e08e62f6f642edd1a6c73cc5f0c48f18476b870` |
| `invoice_list_desktop_en.png` | `967517e1864999af17b2211e77ea521ac3a7cf7bdc0e2e0feae407df609eb156` |
| `m0_5_contract_detail_desktop_ar_rtl.png` | `bc4b73b14855a2b51c0c17016b8bd2e7c6cf73eed52d362414034ed672c16cf5` |
| `m0_5_contract_detail_desktop_en_ltr.png` | `e2682d0332d7b8523515ff462134f4a7c523607bca40e4d8f576788994e46dd0` |
| `m0_5_contract_detail_narrow_ar_rtl.png` | `f0b9f58d94d99644454f1a7158ec5bb71fd3f8dbb191c1d0f210ae0ed57deec0` |
| `m0_5_contract_detail_narrow_en_ltr.png` | `ca936f11a9542a21441cb5e50af4a883d217ec6d5726fa46f30e7736b7629037` |
| `m11_01_customer_scope_mobile_360_en_ltr.png` | `2144b9a7c5ae909079c6961bb60e428706207ed96bbf657b4cd1c644f17872bf` |
| `m11_02_customer_scope_mobile_360_ar_rtl.png` | `f5034b3ca5d209024a59f52ec75c5dd7f1f74532dee031242d106df07bef0fb6` |
| `m11_05_clear_filter_desktop_en_ltr.png` | `b3f848d1afe41f42c05f0fc5f2baa92915250f20fdee0937a6d25d66e3ec9a11` |
| `m11_06_clear_filter_desktop_ar_rtl.png` | `cd6816b7cf619b3c0b67893a21d193cf26e600868cae28f1b6de9fdc68b76d34` |
