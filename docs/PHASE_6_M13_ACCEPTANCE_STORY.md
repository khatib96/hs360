# Phase 6 M13 — Manual Acceptance Story

> **Gate:** Business steps in **UI only** (AR + EN). **P6M13 counters must be 0**
> after cleanup on success or failure.

## What setup creates

| Script | Creates |
|--------|---------|
| `p6m13_manual_setup.sh` | Tagged **customer + service location only** (no inventory, no contract) |
| `p6m13_manual_fixture.sql` | Postgres infrastructure: customer, location, one **available serialized unit** (not a business step; used by acceptance runner) |
| `p6m13_manual_acceptance.sh` | Full EN + AR UI story via `integration_test` + cleanup between runs |

Collect-eligible user needs `invoices.create_sales` + `vouchers.create_receipt`
(and `chart_of_accounts.view` for cash/bank picker).

## Run manual acceptance

```bash
npx supabase db reset   # optional fresh DB
bash scripts/test/p6m13_manual_acceptance.sh macos
```

Or step-by-step:

```bash
bash scripts/test/p6m13_manual_cleanup.sh          # always first / last
docker exec -i supabase_db_hs360 psql -U postgres -d postgres -v tag=EN \
  < scripts/test/p6m13_manual_fixture.sql
# … UI steps …
bash scripts/test/p6m13_manual_cleanup.sh
```

## Counter queries (P6M13 gate)

`p6m13_manual_cleanup.sh` reports JSON counters and exits non-zero if any remain:

- `customers`, `locations`, `products`, `units`
- `contracts`, `invoices`, `vouchers`
- `coverages`, `lifecycle_ops`, `calendar_events`

## Business story (English UI)

1. **Customer** — Select P6M13 tagged customer (from fixture or setup).
2. **Trial** — Create trial with serialized device (scan/enter `P6M13-{TAG}-SN001`).
3. **Convert** — Convert to 12-month rental; confirm monthly rental value.
4. **Schedule (pre-collect)** — Upcoming schedule shows server `billing_due` row.
5. **Collect** — Contract detail → **Collect rental** dialog (atomic RPC).
6. **PDF** — Preview contract PDF; no cost/profit fields in rendered bytes or payload.
7. **Schedule (post-collect)** — UI reflects server state (empty when horizon month collected).
8. **Statement** — Customer statement tab: rental invoice + receipt voucher journal rows.
9. **Close** — Close rental and return device.
10. **Paid after close** — Collected rental invoice stays fully paid.

Automated via `integration_test/contracts/p6m13_manual_acceptance_test.dart`.

**Schedule note:** With default 30-day calendar horizon and billing on the contract
start day, the first collected month may leave no further *pending* rows; the test
asserts pending billing after convert and server-correct empty (or remaining) state after collect.

**Out of manual UI scope:** open A/R unchanged after close on a fixture invoice
that was never collected — **SQL P6M13-4 only**.

## Business story (Arabic UI)

Repeat with locale Arabic (`P6M13_LOCALE=ar` in acceptance runner):

- **تحصيل إيجار** dialog (أشهر التغطية، تأكيد التحصيل، عرض الفاتورة، عرض سند القبض).
- Schedule/history labels in Arabic.

## Canonical collect path (M5)

`collect_rental_payment` = sales invoice + receipt voucher + allocation **in one
RPC**. UI amount locked to `expected_collected_amount` from preview.

## Covered months (M13 / migration 092)

Create-only collectors use `list_covered_rental_months` RPC (month keys only).

## Automated gates (required before M13 close)

| Gate | Command |
|------|---------|
| DB | `npx supabase db reset` |
| SQL ×2 | `bash scripts/test/run_sql_suites.sh supabase_db_hs360` |
| Analyze | `flutter analyze` |
| Unit/widget | `flutter test` |
| Integration | `bash scripts/integration/run_supabase_templates.sh macos` |
| Manual AR/EN | `bash scripts/test/p6m13_manual_acceptance.sh macos` |
| Cleanup | `bash scripts/test/p6m13_manual_cleanup.sh` (counters = 0) |
| Whitespace | `git diff --check` |

**Last run (2026-07-12):** extended EN + AR acceptance passed; cleanup counters 0 each run.
