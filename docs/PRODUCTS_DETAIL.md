# PRODUCTS_DETAIL.md — Product Model Deep Dive

> Detailed explanation of how products work: dual units, conversion factors, barcode vs serial number, image handling.
> This supplements `DATABASE_SCHEMA.md` section 7.
> Updated 2026-05-16 to resolve conflicts: KWD values are examples for Hayat Secret. Currency formatting is dynamic per tenant.

---

## 1. Dual Unit System (Primary + Secondary)

Like standard accounting software, every product has **two units of measure** with a **conversion factor** between them.

### 1.1 The Concept

```
Primary unit       — the storage / display unit (smallest practical unit)
Secondary unit     — the purchase / bulk unit (larger unit)
Conversion factor  — how many primary units in one secondary unit
```

### 1.2 Examples

| Product | Primary | Secondary | Conversion |
|---------|---------|-----------|------------|
| Hilton oil | ml | liter | 1000 |
| Premium perfume | ml | bottle (50ml) | 50 |
| Diffuser device | piece | piece | 1 |
| Coffee beans | gram | kg | 1000 |
| Air freshener | piece | box (24) | 24 |

### 1.3 Why Two Units?

Different operations use different units:
- **Purchase invoices:** entered in secondary (you bought 10 liters)
- **Storage / WAC:** computed in primary (10,000 ml at cost X per ml)
- **Sales / refills:** done in primary (500 ml refill)
- **Display:** flexible per context

The system **always stores in primary units internally**, but the UI lets you switch between views.

### 1.4 Database Model

```sql
create type unit_of_measure as enum (
  'piece', 'liter', 'ml', 'gram', 'kg',
  'box', 'bottle', 'carton', 'meter', 'pack'
);

-- products table (updated)
alter table products add column
  unit_primary unit_of_measure not null default 'piece',
  unit_secondary unit_of_measure,
  conversion_factor numeric(15,4) default 1;

-- Constraint: if secondary exists, factor must be > 1
alter table products add constraint chk_conversion check (
  unit_secondary is null
  or (unit_secondary is not null and conversion_factor > 1)
);
```

### 1.5 Conversion Helpers

```sql
-- Convert from secondary to primary
create or replace function to_primary(p_product_id uuid, p_qty_secondary numeric)
returns numeric as $$
  select p_qty_secondary * conversion_factor
  from products where id = p_product_id;
$$ language sql stable;

-- Convert from primary to secondary
create or replace function to_secondary(p_product_id uuid, p_qty_primary numeric)
returns numeric as $$
  select p_qty_primary / conversion_factor
  from products where id = p_product_id;
$$ language sql stable;
```

### 1.6 UI Behavior

**Purchase invoice form:**
```
Product: [ Hilton Oil ]
Quantity: [ 10 ] [ liter ▼ ]   ← can pick liter or ml
Unit cost: KWD [ 10.000 ] / liter

(System computes & stores: 10,000 ml at KWD 0.010/ml)
```

**Refill visit form (mobile):**
```
Oil: Hilton
Qty per refill: [ 500 ] ml
```

The user always sees the natural unit for the operation. Storage is consistent in primary.

### 1.7 WAC Calculation
WAC is **always per primary unit**. So:
- Hilton oil WAC = 0.010 KWD/ml (after a 10 KWD/liter purchase)
- Display in UI: "10.000 KWD/L (0.010/ml)"

---

## 2. Barcode vs Serial Number — The Key Distinction

This is the most commonly misunderstood part. Get this right.

### 2.0 Canonical Identity Decision

There are three identities:

- `products.sku`: internal generated product code. Keep it in the DB, but hide it from normal product UI.
- `products.barcode`: product-level barcode for sale, purchase, POS, and search.
- `product_units.serial_number`: unit-level identity for one physical device.

For serialized units, printed asset tags use a QR code whose payload is the human-readable serial number. The label must also print the serial as text.

### 2.1 The Rule

- **Barcode** is on the **product type** — same for all units of that type
- **Serial Number** is on the **individual unit** — unique to each physical item

Example:
```
You receive 10 Alpha diffuser devices.

All 10 have the same barcode on the outer box:    8901234567890

But each has its own serial number:               HS-DEV-001
                                                  HS-DEV-002
                                                  HS-DEV-003
                                                  ...
                                                  HS-DEV-010
```

### 2.2 Database Reflection

```sql
-- Barcode lives on products (the type)
products.barcode = '8901234567890'

-- Serial lives on product_units (the individual instance)
product_units (for each of the 10):
  product_id = <Alpha diffuser product>
  serial_number = 'HS-DEV-001' (unique)
  barcode = 'HS-DEV-001' or another unit-specific label/QR payload (optional)
```

### 2.3 Why Barcode Also on Product Unit?

Sometimes individual units **do** have their own unique barcodes or QR labels (e.g., when each unit gets a printed asset tag at receipt time). The `product_units.barcode` field allows this. Do not assume it is the same as `products.barcode`.

For most cases:
- Sales / POS scanning → scan product barcode → identify product
- Asset tracking → scan unit-specific code → identify the specific device

### 2.4 Scanning Behavior

When a barcode is scanned anywhere in the system:

```
1. Try product_units.barcode (unit-specific)
   → If unique match: device-level operation (assign to contract, mark for maintenance)
   
2. Try products.barcode (type-level)
   → If unique match: product-level operation (add to sale, refill from this product type)
   
3. Try product_units.serial_number
   → If match: same as step 1
   
4. No match → error
```

This logic lives in a Dart service:
```dart
class BarcodeService {
  Future<ScanResult> resolveScan(String code) async {
    final unit = await _repo.findUnitByBarcodeOrSerial(code);
    if (unit != null) return ScanResult.unit(unit);
    
    final product = await _repo.findProductByBarcode(code);
    if (product != null) return ScanResult.product(product);
    
    return ScanResult.notFound();
  }
}

sealed class ScanResult {
  factory ScanResult.unit(ProductUnit u) = UnitScanResult;
  factory ScanResult.product(Product p) = ProductScanResult;
  factory ScanResult.notFound() = NotFoundScanResult;
}
```

### 2.4.1 Barcode Search Everywhere

Scanning is not only for sales or POS. The resolver is app-wide infrastructure:

```
scan
  -> resolve product/unit/not-found
  -> open or apply the resolved object based on the current screen
```

Expected contexts:

- Product list/detail: open product or unit detail.
- Purchase invoice: select product or assign entered serials.
- Contract wizard: pick the exact serialized unit.
- Visit detail: open the assigned unit/customer context.
- Maintenance: intake or update the exact unit.
- Inventory count: count product quantity or verify individual unit.
- Return/replacement: select the returned/replaced unit.
- POS later: add product to cart.

Unknown scans show a clear not-found state. Create/link actions are only shown in contexts where they are valid.

### 2.5 Serial Number Generation

**Two modes per tenant setting:**

**A. Auto-generated:** system creates serials like `HS-DEV-00001`, `HS-DEV-00002`...
```sql
select 'HS-DEV-' || lpad(nextval('serial_sequence')::text, 5, '0');
```

**B. Manual entry:** user types serial when receiving (useful when devices come with manufacturer serials you want to track).

Settings field:
```sql
alter table tenant_settings add column
  serial_number_mode text default 'auto',    -- 'auto' | 'manual'
  serial_number_prefix text default 'HS';
```

As of Phase 4 M5.6 these fields are planned, not migrated. Add them in the Phase 5 foundation block.

### 2.6 Bulk Receipt of Units

When a purchase arrives with 10 identical devices, the UI lets you:

```
┌──────────────────────────────────────────────────┐
│  Receive Units — Alpha Diffuser                  │
├──────────────────────────────────────────────────┤
│  Quantity: [ 10 ]                                │
│  Purchase cost (each): KWD [ 60.000 ]            │
│  Warehouse: [ Main Warehouse ▼ ]                 │
│                                                  │
│  Serial numbers:                                 │
│    ● Auto-generate (HS-DEV-00027 to HS-DEV-00036)│
│    ○ Manual entry (paste list)                   │
│                                                  │
│  Barcode for all: [ 8901234567890 ]              │
│  (Or scan to populate)                           │
│                                                  │
│  [Cancel]                  [Create 10 units]     │
└──────────────────────────────────────────────────┘
```

System creates 10 `product_units` rows in a single transaction, all linked to the same product.

### 2.7 Existing Stock Backfill

Existing serialized products may already have an on-hand quantity without matching `product_units`.

Use a dedicated manager-only reconcile tool:

```
missing_units = current_on_hand_quantity - count(existing product_units for product)
```

If `missing_units > 0`, create those unit rows and audit the action. This backfill must **not** increment `inventory_balances` again because the stock already exists.

Do not call the current `create_product_units` flow for this case unless it has a no-stock-delta mode.

---

## 3. Product Images

### 3.1 Storage

Bucket: `product_images` (public read, write requires `products.edit`)

Path structure:
```
product_images/
  {tenant_id}/
    products/
      {product_id}/
        primary.jpg              ← main image, displayed everywhere
        gallery_01.jpg           ← additional images
        gallery_02.jpg
        gallery_03.jpg
        thumbnail.jpg            ← auto-generated 200×200
```

### 3.2 Database

```sql
-- Single primary image URL on products table (already there)
products.image_url text;

-- Gallery in separate table
create table product_images (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  product_id uuid not null references products(id) on delete cascade,
  url text not null,
  alt_text text,
  is_primary boolean default false,
  sort_order int default 0,
  uploaded_by uuid references auth.users(id),
  uploaded_at timestamptz default now()
);

create index idx_prodimgs_product on product_images(product_id);
create unique index idx_prodimgs_primary on product_images(product_id) where is_primary = true;
```

### 3.3 Upload Flow

```
1. User selects image (camera or gallery — both OK for products)
2. App resizes client-side to max 1600×1600
3. App generates thumbnail at 200×200
4. Both uploaded to Storage with appropriate paths
5. Row inserted into product_images
6. If marked primary, updates products.image_url
```

### 3.4 Image Display

Different sizes for different contexts:
- **Product list (table):** thumbnail 40×40
- **Product card:** thumbnail 200×200
- **Product detail:** full image 800×800
- **Catalog view:** gallery slider with all images

The `imgproxy` service in self-hosted Supabase does on-the-fly resizing, so we don't need to pre-generate every size.

### 3.5 Image Display in Contracts & Invoices

When a contract is created, the device's primary image appears on the contract PDF. Same for invoice line items if the tenant chooses to include images on invoices.

---

## 4. Product Card UI — Where Everything Comes Together

The legacy wireframes below show `SKU` as visible metadata. Current canonical behavior is different: normal user-facing product UI should hide SKU and generate it internally. If an admin-only diagnostic view exposes it, label it as "Internal code".

```
┌────────────────────────────────────────────────────────┐
│  ← Alpha Diffuser                  [Edit] [Deactivate] │
├────────────────────────────────────────────────────────┤
│  ┌──────────┐                                          │
│  │          │  SKU: DIF-ALPHA-01                       │
│  │  [IMG]   │  Group: Diffuser Devices                 │
│  │          │  Type: Asset Rental                      │
│  │          │  Barcode: 8901234567890                  │
│  └──────────┘                                          │
│  [+ Add image]                                         │
│                                                        │
│  ────────────────────────────────────────────────      │
│  Units                                                 │
│                                                        │
│  Primary: piece    Secondary: piece    Factor: 1       │
│                                                        │
│  ────────────────────────────────────────────────      │
│  Pricing                                               │
│                                                        │
│  Sale price:          KWD 100.000                      │
│                                                        │
│  Cost (requires permission):                           │
│    Avg cost:        KWD 60.000                         │
│    Last purchase:   KWD 60.000                         │
│  Lifespan:          24 months                          │
│                                                        │
│  ────────────────────────────────────────────────      │
│  Rental Settings                                       │
│                                                        │
│  Serialized:        Yes                                │
│  Maintenance track: Yes                                │
│  Default oil/month: -                                  │
│  Reorder point:     5 units                            │
│                                                        │
│  ────────────────────────────────────────────────      │
│  Units in Stock (12)                  [+ Add units]    │
│                                                        │
│  Serial         Status      Warehouse   Last Maint     │
│  HS-DEV-00001   Rented      -          (on contract)   │
│  HS-DEV-00002   Available   Main       Jan 2026        │
│  HS-DEV-00003   Maintenance -          Mar 2026        │
│  HS-DEV-00004   Rented      -          -               │
│  HS-DEV-00005   Available   Van: Ahmad -               │
│  ... [show all 12]                                     │
│                                                        │
│  ────────────────────────────────────────────────      │
│  Stock Summary                                         │
│                                                        │
│  Main warehouse:   5 available, 1 maintenance          │
│  Van: Ahmad:       1 available                         │
│  Van: Sara:        0 available                         │
│  On contracts:     5 rented                            │
│  ────────────                                          │
│  Total: 12 units                                       │
└────────────────────────────────────────────────────────┘
```

### 4.1 Oil Product Card Differs

For consumable products (oils), the card focuses on bulk stock rather than serialized units:

```
┌────────────────────────────────────────────────────────┐
│  ← Hilton Oil                                          │
├────────────────────────────────────────────────────────┤
│  [IMG]   SKU: OIL-HIL-01                               │
│          Group: Premium Oils                           │
│          Type: Consumable Rental                       │
│          Barcode: 8907894561234                        │
│                                                        │
│  Units: ml (primary)  /  liter (secondary)             │
│  Factor: 1000                                          │
│                                                        │
│  Pricing:                                              │
│    Sale price:    KWD 15.000 / liter                   │
│    (= KWD 0.015 / ml)                                  │
│                                                        │
│  Cost (requires permission):                           │
│    Avg cost:      KWD 10.000 / liter                   │
│    (= KWD 0.010 / ml)                                  │
│                                                        │
│  Stock:                                                │
│    Main warehouse:    25,500 ml  (25.5 L)              │
│    Van: Ahmad:         8,000 ml  ( 8.0 L)              │
│    Van: Sara:          5,500 ml  ( 5.5 L)              │
│    ──────────                                          │
│    Total:             39,000 ml  (39.0 L)              │
│                                                        │
│  Stock value (at WAC):  KWD 390.000                    │
└────────────────────────────────────────────────────────┘
```

---

## 5. Product Groups (Hierarchical)

A product belongs to one group. Groups can have parents (a tree).

```
All Products
├── Devices
│   ├── Diffusers
│   │   ├── Standard
│   │   └── Premium
│   ├── Air Fresheners
│   └── Accessories
├── Oils
│   ├── Premium Oils
│   ├── Standard Oils
│   └── Limited Edition
└── Perfumes
    ├── Men
    ├── Women
    └── Unisex
```

The hierarchy supports:
- Filtering: "show me all premium products"
- Reporting: revenue by group
- UI navigation: drill down through categories

---

## 6. Product Discoverability

In the products list, multiple search affordances:

1. **Free-text search** — matches name (ar + en), SKU, barcode, serial number of any unit
2. **Filter by group** — multi-select tree
3. **Filter by type** — sale_only / asset_rental / consumable_rental
4. **Filter by status** — active / inactive
5. **Filter by stock** — in stock / out / low

A barcode scanner button is always visible — scan to jump to a product instantly.

---

## 7. Importing Existing Products (From Google Sheets)

For Hayat Secret's migration, a CSV import tool:

```
CSV columns:
  optional_legacy_sku, name_ar, name_en, group_name, product_type, unit_primary,
  unit_secondary, conversion_factor, sale_price,
  avg_cost, expected_lifespan_months, is_serialized, barcode

Import flow:
  1. Upload CSV
  2. System shows preview (first 10 rows)
  3. Map columns if needed
  4. Validate (check for duplicates, missing required fields)
  5. Import — creates products + product_groups as needed
  6. For serialized products: separate CSV for product_units
```

SKU is generated by the system during import. A legacy SKU column may be accepted for matching/debugging, but it should not become a normal required user field.

This is a one-time tool, accessible only to managers, used during onboarding.

---

## 8. Pricing Tiers (Future, Not v1)

The schema can later support:
- Customer-specific prices
- Volume discounts
- Time-limited promotional prices

Reserved column names for forward compatibility:
```sql
-- Future: customer_product_prices table
-- Future: price_tiers, promotional_prices
```

Not implemented in v1 — keep simple.
