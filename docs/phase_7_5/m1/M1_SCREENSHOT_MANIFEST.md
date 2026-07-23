# Phase 7.5 M1 Screenshot Manifest

> Captured: 2026-07-24
>
> Status: **PASS**

All images are deterministic Flutter widget captures with bundled Noto and
Material Icons loaded. Desktop captures exercise the wide layout; narrow
captures use a 390 logical-pixel viewport. Each capture completed without a
Flutter exception or overflow.

| Evidence | Pixels | SHA-256 |
|----------|--------|---------|
| `screenshots/m1_foundation_desktop_ar_rtl.png` | 2560×1800 | `ea5d5f88972b7d87fbde448a56e639aee3883eec18717c569bc5e65af9c0d5f6` |
| `screenshots/m1_foundation_desktop_en_ltr.png` | 2560×1800 | `1b2a0a34ecd8da4d32de1d21f2503954e5fc1790ae248e46f59ead6e7246cc33` |
| `screenshots/m1_foundation_narrow_ar_rtl.png` | 780×1688 | `f361ce675c5fc0d091d79e0c1dc528089e6b22168bf060904af58962058c8c72` |
| `screenshots/m1_foundation_narrow_en_ltr.png` | 780×1688 | `4a9bd67ac99877c659bb1ad4517f22336f9e803574efd8cdad1ce5cab26496bc` |
| `screenshots/m1_contract_detail_desktop_ar_rtl.png` | 2560×1800 | `efc086be96e8f7217d87eb625f7782ce9f7c76cc46d80ef920b82a481bca3d39` |
| `screenshots/m1_contract_detail_desktop_en_ltr.png` | 2560×1800 | `0c03f7fb18ff572302405fef0fcf7696ba855060059d0fd12946442ccf4dbc77` |
| `screenshots/m1_contract_detail_narrow_ar_rtl.png` | 780×1688 | `2175491bd5836646da7d6c2f07fe409266322c2cb8bba36ee8d683fd7fbb16b5` |
| `screenshots/m1_contract_detail_narrow_en_ltr.png` | 780×1688 | `4b87f8ebede2da00f8f1487e22913999ccd70c2ba3c925ac46dafc1e41af7c59` |
| `screenshots/m1_invoice_detail_narrow_ar_rtl.png` | 780×1688 | `350cb40bda5c050e0debcd8a31d67ea31bab0d63289d7c7bc8ba9ba64980b81c` |
| `screenshots/m1_invoice_detail_narrow_en_ltr.png` | 780×1688 | `7d92c6eee981fe6627df46a31a2d642740f0ba0196da54f79becb47f2008b80e` |
| `screenshots/m1_invoice_list_desktop_ar_rtl.png` | 2880×2000 | `963d510d4fefeb7aac4ebd0ba4e0c66c3e5c0547ed5e4bb2a933615059b1b905` |
| `screenshots/m1_invoice_list_desktop_en_ltr.png` | 2880×2000 | `beb491b6b1bb66cac756a3f65bb894eb66b030eeca3fa746b8529da5749b868b` |

The contract narrow captures replace the M0.5 known-defect evidence: the
390-pixel overflow is no longer present in either direction.
