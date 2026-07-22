# DESIGN_SYSTEM.md — Visual & UX Design

> The brand is **premium, minimal, and refined**. Think luxury fragrance house, not generic SaaS.
> Updated 2026-05-16 to resolve conflicts: all KWD examples are examples only. Runtime currency labels and decimal places come from `currencies`.

---

## 1. Brand Identity

- **Brand:** Hayat Secret (حياة سكرت)
- **Tagline:** "Mind, Body, Soul & Beyond"
- **Logo:** "hs" lockup in gold script on dark background; "hayat secret" wordmark in serif
- **Mood:** elegant, calm, confident, sensorial

The system is white-label-ready. Tenant logo and primary color can be customized; layout and typography remain consistent.

---

## 2. Color System

### 2.1 Primary Palette

| Name | Hex | Usage |
|------|-----|-------|
| **Gold (Brand)** | `#C9A961` | Primary actions, brand accents, links, key icons |
| **Gold Soft** | `#E8D9B0` | Backgrounds for highlighted rows, badges |
| **Gold Deep** | `#9C8240` | Hover states, pressed states |
| **Charcoal** | `#1A1A1A` | Logo background, primary text on light surfaces |
| **Ink** | `#2C2C2C` | Body text on white |
| **Pure White** | `#FFFFFF` | App background |
| **Off-White** | `#FAF8F3` | Card backgrounds, subtle sections |

### 2.2 Semantic Palette

| Name | Hex | Usage |
|------|-----|-------|
| **Success** | `#2D7A4F` | Confirmed payments, completed visits |
| **Warning** | `#C8861A` | Below-minimum alerts, trial expiring |
| **Error** | `#A8362F` | Validation errors, missing data |
| **Info** | `#3A6F8F` | Informational toasts |

### 2.3 Neutral Scale

| Name | Hex | Usage |
|------|-----|-------|
| Neutral 50 | `#F7F5F0` | Hover backgrounds |
| Neutral 100 | `#EEEBE2` | Dividers, very subtle borders |
| Neutral 200 | `#D9D4C5` | Borders |
| Neutral 400 | `#A8A293` | Disabled text |
| Neutral 600 | `#5E5A4F` | Secondary text |
| Neutral 800 | `#2C2C2C` | Primary text |

### 2.4 Dark Mode (Optional, Phase 4)
Reverse the foundation: charcoal background, gold accents, off-white text. Same semantic colors with slight saturation reduction.

---

## 3. Typography

### 3.1 Font Families

**Arabic:**
- **Primary:** *Tajawal* (Google Fonts) — modern, clean, excellent for screens
- **Fallback:** *Cairo*, system Arabic font

**English:**
- **Primary:** *Cormorant Garamond* (serif, for headings — premium feel)
- **Body:** *Inter* (sans-serif, screen-optimized)

**Numbers:**
- *Inter Tabular* (or `font-feature-settings: 'tnum'`) — for tables and financial figures

### 3.2 Type Scale

| Level | Size (mobile) | Size (desktop) | Weight | Line height |
|-------|---------------|----------------|--------|-------------|
| Display | 32 | 40 | 600 | 1.2 |
| H1 | 24 | 28 | 600 | 1.3 |
| H2 | 20 | 22 | 600 | 1.35 |
| H3 | 17 | 18 | 600 | 1.4 |
| Body L | 16 | 16 | 400 | 1.55 |
| Body | 14 | 14 | 400 | 1.55 |
| Body S | 13 | 13 | 400 | 1.5 |
| Caption | 12 | 12 | 400 | 1.45 |
| Number | 16 | 18 | 500 | 1.2 (tabular) |

### 3.3 Rules
- Headings: serif (English) / Tajawal 600 (Arabic) for premium feel
- Body: sans-serif always
- Numbers in tables: always tabular figures (`font-feature-settings: 'tnum'`)
- Avoid all-caps; use sentence case
- Arabic text never italic

---

## 4. Spacing System

8-pixel base grid.

| Token | Value |
|-------|-------|
| `space-1` | 4 |
| `space-2` | 8 |
| `space-3` | 12 |
| `space-4` | 16 |
| `space-5` | 24 |
| `space-6` | 32 |
| `space-7` | 48 |
| `space-8` | 64 |

**Inside cards:** padding `space-5` (24)
**Between sections:** gap `space-6` (32)
**Form field gap:** `space-4` (16)

---

## 5. Components

### 5.1 Buttons

**Primary**
- Background: Gold (`#C9A961`)
- Text: Charcoal (`#1A1A1A`)
- Hover: Gold Deep
- Height: 44 (mobile-tappable)
- Radius: 8
- Padding: 16 horizontal

**Secondary**
- Background: transparent
- Border: 1px Gold
- Text: Gold Deep
- Same height/radius

**Ghost**
- No background, no border
- Text: Gold Deep
- Underline on hover

**Destructive**
- Background: Error (`#A8362F`)
- Text: White
- Used for delete, cancel, terminate

**Disabled states:** 40% opacity, no hover.

### 5.2 Form Fields

- Height: 44
- Border: 1px Neutral 200
- Focus border: 2px Gold
- Radius: 8
- Padding: 12 horizontal
- Label above field, 14px, Ink color
- Error message below in Error red, 12px

Required indicator: small red dot `•` after label (RTL-aware).

### 5.3 Cards

- Background: Off-White (`#FAF8F3`)
- Border: 1px Neutral 100
- Radius: 12
- Shadow: very subtle `0 1px 2px rgba(0,0,0,0.04)`
- Padding: 24

### 5.4 Tables

- Header row: background Neutral 50, bold, 13px uppercase tracking
- Row hover: Neutral 50
- Border between rows: 1px Neutral 100
- Money column: right-aligned (LTR) / left-aligned (RTL), tabular figures
- Status badges: pill shape, semantic color background at 15% opacity, text full color

### 5.5 Status Badges

| Status | Background | Text |
|--------|------------|------|
| Active | Success @ 15% | Success |
| Trial | Gold Soft | Gold Deep |
| Pending | Warning @ 15% | Warning |
| Suspended | Neutral 200 | Neutral 800 |
| Completed | Neutral 100 | Neutral 600 |
| Terminated | Error @ 15% | Error |

### 5.6 Money Display Widget

Always show currency symbol in the user's locale. Decimal places come from the tenant default currency. KWD uses 3 decimals as the Hayat Secret example; other currencies may use 2, 0, or another configured precision.

```
Arabic:   12.500 د.ك
English:  KWD 12.500
```

Component: `MoneyDisplay(amount, currency, locale)` — used everywhere money appears.

### 5.7 Empty States

Each list view has an empty state:
- Icon (line style, gold)
- Gold filled buttons must use white text/icons (`AppColors.pureWhite`) for contrast and brand consistency.
- Headline
- One-line description
- Primary action button (where applicable)

Example for empty contracts list:
> 📜 *No contracts yet*
> Start by creating your first rental contract.
> **[+ New Contract]**

---

## 6. Layout

### 6.1 Desktop

```
┌──────────────┬──────────────────────────────────────────┐
│              │ Top bar: title/back · search · quick +  │
│ Module       │ notifications · locale                  │
│ sidebar      ├──────────────────────────────────────────┤
│              │ Contextual module tabs                  │
│ Dashboard    ├──────────────────────────────────────────┤
│ Daily        │                                          │
│ Parties      │ Main content                             │
│ Contracts    │                                          │
│ Operations   │                                          │
│ Inventory    │                                          │
│ Finance      │                                          │
│ POS / HR     │                                          │
│              │                                          │
│ ───────────  │                                          │
│ Audit        │                                          │
│ Settings     │                                          │
│ User/profile │                                          │
└──────────────┴──────────────────────────────────────────┘
```

- Sidebar width: 240px (collapsible to 64px icon-only)
- Sidebar uses the accepted HS360 neutral/white surface with restrained gold
  brand accents; do not use decorative artwork that reduces label contrast.
- Sidebar labels are business modules, not every route/action.
- Audit, Settings, and user identity/profile are anchored at the bottom.
- Active item: Gold treatment with contrast that passes accessibility.
- Top bar: White, 64px tall, bottom border Neutral 100
- Contextual module tabs sit below the global bar, scroll/collapse on narrow
  widths, and omit unauthorized tabs.
- Search, badges, Dashboard, and contextual counts must not leak unauthorized
  records.

### 6.2 Adaptive Mobile

```
┌──────────────────────────┐
│ ← Title         ⚙        │  ← top bar, 56 tall
├──────────────────────────┤
│                          │
│   Main content           │
│                          │
│                          │
│                          │
├──────────────────────────┤
│ 🏠   📅   👤   📦   ⋯   │  ← bottom nav
└──────────────────────────┘
```

Bottom navigation has at most five permission-shaped destinations. Field/hybrid
defaults to Today | Appointments & Visits | Requests | primary permitted action
| More. Administrative defaults to Home/Alerts | Approvals | Calendar | primary
permitted module | More. Work profile changes ordering only; explicit
permissions control visibility and access.

### 6.3 Direction Handling

- App-level `Directionality` widget switches with locale
- All `EdgeInsetsDirectional` (start/end, never left/right)
- Icons that imply direction (arrows, chevrons) auto-flip via `Directionality.of(context)`
- Form fields: label aligned to start
- Money columns: aligned to end

---

## 7. Iconography

- Style: **line icons** (not filled), 2px stroke
- Source: Lucide Icons (`flutter_lucide`)
- Default size: 20
- Color: inherit (uses parent text color)
- Brand icons (logo elements): hand-drawn SVGs in gold

**Avoid:** colorful illustrations, emoji as decoration, multi-color icons.

---

## 8. Photography & Imagery

- Product images: minimal background, single subject
- White or soft beige backdrop
- Soft natural lighting
- No heavy filters or saturation boosts
- Square aspect ratio for catalog thumbnails (1:1)
- 4:3 for detailed product views

---

## 9. Motion & Animation

Keep it minimal and purposeful.

- Page transitions: 200ms ease-out fade + slight slide
- Button press: 100ms scale to 0.97
- List item add/remove: 250ms slide-in / fade-out
- Loading: spinner in Gold, never more than 200ms before showing
- No bouncy, springy animations — refined easing only

---

## 10. Voice & Tone

### 10.1 In English
- Confident but warm
- No exclamation points except in welcome messages
- Plain language, no jargon
- Errors are descriptive: "Customer phone is required" not "Validation failed"

### 10.2 In Arabic
- Standard Arabic (الفصحى البسيطة), not dialect
- Formal but friendly
- Same plain-language principle

### 10.3 Empty State Copy Examples

| Screen | English | Arabic |
|--------|---------|--------|
| No contracts | Start your first rental contract | ابدأ بإنشاء أول عقد إيجار |
| No visits today | No visits scheduled for today | لا توجد زيارات مجدولة اليوم |
| Customer has no debt | All clear — no outstanding balance | الحساب نظيف — لا توجد مستحقات |

---

## 11. Receipts & PDFs

### 11.1 Receipt Layout (Mobile, Field-Generated)

```
┌─────────────────────────────────┐
│       [LOGO]                    │
│      Hayat Secret               │
│  ──────────────────────────     │
│                                 │
│  RECEIPT — RV-2026-00123        │
│  Date: 15 May 2026              │
│                                 │
│  Received from:                 │
│    Cafe Bloom                   │
│                                 │
│  Amount: KWD 37.500             │
│  Method: KNET                   │
│  Ref:    KNT-998877             │
│                                 │
│  Allocated to:                  │
│    INV-2026-00045   12.500      │
│    INV-2026-00067   12.500      │
│    INV-2026-00089   12.500      │
│                                 │
│  Collected by: Ahmed (EMP-002)  │
│                                 │
│  ──────────────────────────     │
│  Thank you for your business    │
└─────────────────────────────────┘
```

### 11.2 Invoice Layout

Two-column header (company info left, invoice meta right), itemized table, totals box bottom-right, footer with payment terms and bank details.

### 11.3 Contract PDF

Cover page with parties, terms summary, signature blocks. Page 2: detailed line items. Page 3: terms & conditions (tenant-customizable).

---

## 12. Accessibility

- All buttons have descriptive labels (`semanticsLabel`)
- Minimum tap target: 44×44
- Color contrast: WCAG AA minimum for text
- Form errors announced via screen reader
- Keyboard navigation supported on desktop
- No information conveyed by color alone (always paired with text or icon)

---

## 13. Cursor Implementation Hints

When Cursor builds widgets:

1. Use `Theme.of(context).colorScheme` for colors — define the scheme once.
2. Use `Theme.of(context).textTheme` for text — define type scale once.
3. Create a `core/theme/app_theme.dart` that builds both light and dark themes.
4. Never hardcode hex values in widget files — always reference theme tokens.
5. Use `Directionality.of(context)` to make direction-aware icons.
6. Wrap any text containing money in the `MoneyDisplay` widget.
7. Tables: use `DataTable` from Material 3 with custom styling, not raw `Row` widgets.
