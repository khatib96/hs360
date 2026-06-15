# HS360 — Multi-Tenant Business Management System

> A purpose-built ERP for fragrance device rental & sales businesses.
> Built initially for Hayat Secret (Kuwait). Designed as multi-tenant SaaS from day one.
> Each tenant runs on their own self-hosted VPS.
> Updated 2026-05-16 to resolve conflicts before Phase 0.

---

## Project Name

**HS360** (initial working name — may change before public release)

The codebase is **product-agnostic**. The name "HS360" appears only in branding configs and can be replaced per tenant build.

---

## What Is This?

A custom ERP that natively handles the **asset-rental + monthly-consumable** business model — something off-the-shelf systems like Odoo cannot do cleanly.

The system manages:
- **Direct sales** of devices, oils, and perfumes
- **Rental contracts** where devices stay company-owned and oils are refilled monthly
- **Field operations** with GPS-verified, live-photo-proven service visits
- **Full double-entry accounting** with chart of accounts, vouchers, and invoices
- **Customer ledger** with full transaction history
- **WhatsApp integration** for individual messages and broadcast campaigns
- **Granular permissions** — Manager (full) and User (per-permission custom access)
- **Multi-tenant architecture** — sellable to other companies; each runs their own VPS

---

## Stack

| Layer | Choice | Why |
|-------|--------|-----|
| Frontend (Desktop + Mobile) | Flutter + Dart | Single codebase: Windows, macOS, Android, iOS |
| Backend & Database | Self-Hosted Supabase | PostgreSQL + Auth + REST + Realtime + Storage + RLS |
| Hosting | Tenant's own VPS | Data sovereignty per tenant |
| State Management | Riverpod 2.x | Type-safe, modern, testable |
| Local Cache (Mobile) | Drift (SQLite) | Offline-first for field agents |
| Routing | GoRouter | Permission-aware redirects |
| Notifications | Resend (email) + Meta WhatsApp Cloud API | Auto + broadcast |
| Money handling | `decimal` package (Dart) + `numeric(15,3)` (Postgres) | Never floats |

---

## Document Map

Read these in order:

| # | File | Purpose |
|---|------|---------|
| 1 | `README.md` | You are here |
| 2 | `PROJECT.md` | Vision, scope, business rules |
| 3 | `ARCHITECTURE.md` | Tech stack, layers, code organization |
| 4 | `DATABASE_SCHEMA.md` | All tables, columns, relationships, SQL |
| 5 | `PRODUCTS_DETAIL.md` | Dual units, barcode vs serial, images |
| 6 | `CONTRACTS_LOGIC.md` | Contract creation, oil tracking, profit math |
| 7 | `PAYMENT_SYSTEM.md` | Vouchers, invoices, WAC, billing cycles |
| 8 | `CUSTOMER_LEDGER.md` | Customer ledger + WhatsApp/email broadcast |
| 9 | `FIELD_OPS.md` | Mobile app flows, GPS, calendar, refills |
| 10 | `PERMISSIONS.md` | Manager / Custom-User model, fully explicit grants |
| 11 | `CURRENCIES_AND_LOCALIZATION.md` | Dynamic currencies + bilingual everything |
| 12 | `SECURITY.md` | RLS, tenant isolation, photo enforcement |
| 13 | `DESIGN_SYSTEM.md` | Colors, typography, RTL, components |
| 14 | `DEPLOYMENT.md` | Self-hosted VPS setup, connection, white-label |
| 15 | `BUILD_PLAN.md` | Phased implementation roadmap |
| 16 | `CANONICAL_DECISIONS.md` | Final decisions when older docs conflict |
| 17 | `MVP_SCOPE.md` | Strict v1 scope |
| 18 | `RPC_SPEC.md` | Required RPC signatures and behavior |
| 19 | `.cursorrules` | AI assistant rules for this project |

---

## Brand (Default for HS360)

- **Working Name:** HS360
- **Primary Color:** Gold `#C9A961`
- **Background:** Pure Black `#0A0A0A` (logo context) / White `#FFFFFF` (app)
- **Tone:** Premium, minimal, refined

Each tenant can override branding via build config — see `DEPLOYMENT.md` section 5.

---

## Seven Core Principles

1. **Multi-tenant by default** — Every table has `tenant_id`. RLS enforces isolation.
2. **Self-hosted per tenant** — Each company runs their own VPS. No shared infrastructure.
3. **Bilingual** — Every label, error, document works in Arabic (RTL) and English (LTR).
4. **Permission-aware UI** — Manager sees all; Users see exactly what's granted.
5. **Live capture only** — Field photos come from the camera, never the gallery.
6. **Money is never a float** — `numeric(15,3)` in DB, `Decimal` in Dart, always.
7. **Snapshots are sacred** — Contract costs frozen at creation, never updated retroactively.

---

## Status

**Phase 5 is in progress.** M1 finance foundations, M2 asset identity, M3 document
templates/PDF rendering, and M4 tax foundation/money math are complete (migration `059`,
adversarial sign-off 2026-06-15).

Next: Phase 5 M5 Purchase Invoice Engine (`060_phase_5_purchase_invoice_rpc.sql`).

---

## Important Notes for Cursor

When starting any task:
1. Always read `.cursorrules` first
2. Read `docs/CANONICAL_DECISIONS.md` next
3. Read the relevant document(s) for the area you're working in
4. Never bypass RLS, never use `double` for money, never hardcode strings
5. Permissions go through `user_has_permission()` SQL function, not legacy role checks
6. Every new table gets `tenant_id` and RLS policies in the same migration

---

## Recent Changes (Important)

The system has evolved from earlier drafts. **Current truth, in case of conflicts between docs:**

- **Permission model:** Manager (full) / User (fully custom, zero defaults). **NO roles, NO templates.** Every permission explicitly granted. See `PERMISSIONS.md`.
- **Currencies:** Fully dynamic via the `currencies` table. Manager can add any currency with custom decimals, names, symbols. See `CURRENCIES_AND_LOCALIZATION.md`.
- **Bilingual:** Every user-entered name/description has `_ar` and `_en` columns. Every UI string is in ARB files. See `CURRENCIES_AND_LOCALIZATION.md`.
- **Hosting:** Self-hosted per tenant via Docker on their VPS. See `DEPLOYMENT.md`.
- **Product units:** Dual units (primary + secondary + conversion factor). See `PRODUCTS_DETAIL.md`.
- **Customer ledger:** Major feature, full-screen, with WhatsApp integration. See `CUSTOMER_LEDGER.md`.
- **Contract pricing:** Manual monthly value entered by agent + auto-snapshot of costs + min-profit threshold from settings. See `CONTRACTS_LOGIC.md`.

If anything in older docs references fixed job labels as access types, treat those as **example permission templates** rather than hardcoded roles. The actual implementation uses the flexible permission system.

---

## Known Issues Before Phase 0

- There is no repo or application code yet; this folder currently contains planning documents only.
- Some older documents may still contain partially updated examples. `docs/CANONICAL_DECISIONS.md` is the source of truth when documents conflict.
- Migration plan from Google Sheets is TODO and must be defined before importing live Hayat Secret data.
