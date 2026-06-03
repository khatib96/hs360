# CAPABILITIES_DECISION_REPORT.md - Barcode/Serial, Print Engine, Location

> Repo-aligned decision report added 2026-06-03 after Phase 4 M5.6.
> This file corrects the earlier external draft against the actual migrations and code.
> If this file conflicts with older planning notes, `CANONICAL_DECISIONS.md` wins.

---

## 1. Executive Decision

The requested ideas are not random add-ons. They are three cross-cutting capabilities:

1. **Asset tracking** - product barcode, unit serial, product-unit lifecycle, QR/asset tag printing, scanner/camera lookup.
2. **Document printing** - invoices, vouchers, contracts, statements, receipts, labels, and reports from one structured template model.
3. **Location intelligence** - service-location coordinates, GPS verification, native map navigation, and later internal operations maps.

Do not create a new top-level phase. Put small location foundations in Phase 4, then add a **Phase 5 foundation block** before invoices/vouchers. Contracts and field ops then consume those foundations.

---

## 2. Current Repo Facts

### Exists

- `products.sku` exists and is `not null`, unique per tenant.
- `products.barcode`, `products.is_serialized`, and `products.trackable_for_maintenance` exist.
- `product_units.serial_number`, `product_units.barcode`, `product_units.status`, `current_contract_id`, `current_customer_id`, `current_warehouse_id`, `current_service_location_id`, `purchase_cost`, and unique `(tenant_id, serial_number)` exist.
- `customer_service_locations.google_maps_url`, `latitude`, and `longitude` exist in migration `047`.
- Contracts, visits, calendar events, and product units now reference service locations through composite foreign keys.
- Flutter already has `mobile_scanner`, `geolocator`, and `image_picker`.

### Not Yet Migrated or Implemented

- `tenant_settings.serial_number_mode` and `tenant_settings.serial_number_prefix`.
- `document_templates` and `tenant_document_settings`.
- `settings.templates.edit` in the actual seed permission catalog.
- `product_units.correct_serial`, label-print permissions, and template-edit implementation.
- `v_rented_assets`, `v_today_refills`, `v_unit_timeline`, and `v_rented_assets_map` actual database views.
- `pdf`, `printing`, `url_launcher`, and a Flutter map package.
- Google Maps URL resolver edge function.
- Product UI still exposes and requires SKU.
- Serialized warehouse transfers currently reject serialized products in `record_inventory_transfer`.

### Corrected From The External Draft

- `ai_memory.md` is current through Phase 4 M5.6; the stale document is mainly the top progress table in `BUILD_PLAN.md`.
- Customer-level GPS columns were removed in Phase 4 M5.5. Coordinates belong on `customer_service_locations`, not `customers`.
- `create_product_units` increments stock. It must not be reused for "generate missing serials" over existing stock without a separate reconcile/backfill path.

---

## 3. Canonical Decisions

### D1 - SKU, Barcode, Serial Are Different Identities

- **SKU** is an internal product code. Keep the database field for integrity, generate it automatically, and hide it from normal product UI.
- **Product barcode** lives on `products.barcode`. It identifies the product type for sales, purchase entry, POS, and search.
- **Serial number** lives on `product_units.serial_number`. It identifies one physical device.
- `products.is_serialized = true` means the product requires unit-level operations.

### D2 - Serialized Assets Must Be Operated By Unit

For any product where `is_serialized = true`, contract assignment, returns, maintenance, and future serialized transfers must include a concrete `product_unit_id`.

Missing unit identity should raise a validation error in the RPC, not be handled only in UI.

### D3 - QR/Asset Tag Payload

Asset labels should print a human-readable serial number and a QR code whose payload is the serial text, for example `HS-DEV-00042`.

Do not encode raw UUIDs or opaque URLs in the QR for v1. The text serial gives a fallback if the sticker is damaged and can be resolved inside the app through the scan service.

### D4 - Product Units Are Lifecycle Truth; Balances Are Maintained Aggregates

For serialized products:

- `product_units` is the identity and lifecycle source of truth, not just a serial-number table.
- `inventory_balances` remains the aggregate stock cache used by inventory screens and accounting flows.
- Mutating RPCs must keep both in sync atomically.
- Lifecycle state moves from purchase/creation -> available -> rented/trial -> maintenance -> returned/lost/damaged/retired through RPC-controlled transitions.
- Current pointers (`current_warehouse_id`, `current_customer_id`, `current_service_location_id`, `current_contract_id`) show where the unit is now.
- Timeline is built from source events through `v_unit_timeline`; `unit_events` is only for manual events or notes without a natural source table.
- A maintained `last_event_at` may be added for sorting/performance, but it must not replace the source-event timeline.

Backfilling existing serialized stock needs a dedicated reconcile RPC/tool that creates missing units without changing the already-correct quantity.

### D4b - Barcode Search Everywhere

The scan resolver is global infrastructure:

```text
scan -> resolve object -> open or apply object in the current screen context
```

It must support product search, unit lookup, contract device picking, visit detail, maintenance intake, inventory count, return/replacement, and POS later. Barcode scanning is not a sales-only feature.

### D5 - Document Templates Use Structured JSON

Use structured JSON templates (`blocks`, `fields`, `settings`) as the canonical template representation.

- First renderer: Flutter client-side `pdf`/`printing` for A4, thermal 80mm, and asset labels.
- Later renderer: server/edge renderer for archived PDFs and auto-send, using the same JSON model.
- Do not use FastReport, Crystal Reports, raw free-form HTML, or AI-generated runtime templates.
- v1 should ship fixed templates plus tenant settings (logo, colors, header/footer, language, columns). A visual editor is Phase 10+.

### D6 - Service Location Coordinates Are The Location Truth

The stored `customer_service_locations.latitude/longitude` is the operational location truth.

`google_maps_url` is only an input/source and a convenience link. Store `resolution_source` later to distinguish `map_pick`, `device_gps`, `url`, and `manual`. Also store `resolved_at`, `coordinate_accuracy_m`, and optional `resolution_status`/`resolution_error` so bad or stale coordinates can be audited.

GPS verification should use a configurable radius and proceed-with-reason when outside range. It should flag risk, not silently block legitimate work.

### D7 - Native Directions Are Separate From Internal Maps

The mobile "Directions" action should open the native maps app through `url_launcher`.

The internal operations map is a later reusable widget with typed layers such as today's visits, customers, service locations, and rented assets. Do not build a large generic map engine early.

---

## 4. Roadmap Placement

### Phase 4 Add-on

- Add service-location coordinate capture UX:
  - Use current device location.
  - Paste Google Maps URL, then resolve it when resolver exists.
  - Later choose on map.
- Add `resolution_source`, `resolved_at`, `coordinate_accuracy_m`, and optional resolver status/error fields when implementing capture.
- Keep coordinates on `customer_service_locations`.

### Phase 5 Asset / Barcode / Print Foundation

Put this before invoice/voucher screens:

1. Internal generated SKU and hidden normal SKU UI.
2. Serial settings and serial generation helpers.
3. Product-unit lifecycle foundation and timeline surface.
4. Barcode/QR resolve service: unit barcode, product barcode, serial number.
5. Barcode Search Everywhere behavior across product/unit/contract/visit/maintenance/inventory contexts.
6. Generate missing serials reconcile/backfill tool, manager-only and audited.
7. Structured document template schema and tenant document settings.
8. Flutter PDF/print renderer for invoice, receipt voucher, and asset tag.
9. Purchase invoice unit generation in the same transaction as stock/accounting.
10. Asset tag batch printing.

### Phase 6

- Contract creation must require `product_unit_id` for serialized assets.
- Contract UI should allow search/scan by serial or QR.
- Contract RPCs update `product_units.current_customer_id`, `current_service_location_id`, and contract pointers together.

### Phase 7/8

- Native directions on mobile visits/calendar.
- GPS threshold configuration and proceed-with-reason risk flags.
- Mobile scan flow for picking devices in contract/field workflows.

### Phase 10+

- Operations map with clustering and layers.
- Visual document template editor.
- Rented-assets map and reporting exports.

---

## 5. Implementation Risks

- **Backfill risk:** creating units for existing stock must not increase stock again.
- **Accounting risk:** purchase invoices that create units must keep inventory movements, balances, WAC, and journal entries in one transaction.
- **Template risk:** building a visual editor too early will delay core accounting. Use JSON templates plus simple settings first.
- **Location risk:** pasted map URLs are convenient but unreliable. Device GPS and map-pick are stronger sources.
- **Permission risk:** serial correction and template editing are sensitive; both need explicit permissions and audit logs.
