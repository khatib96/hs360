# CURRENCIES_AND_LOCALIZATION.md — Currencies & Bilingual Content

> Dynamic currency system (Manager can add any currency) and **bilingual everywhere** — every label, name, description, and message exists in both Arabic and English.

---

## 1. The Currency System

### 1.1 Concept

Each currency has:
- **Major unit** — the main unit (Dinar, Riyal, Pound, Dollar)
- **Minor unit** — the fractional unit (Fils, Halala, Piaster, Cent)
- **Decimal places** — how many digits after the decimal point
- **Codes & symbols** — both Arabic and English
- **Conversion** — minor units per major unit (e.g. 1000 fils = 1 KWD)

This generalizes any world currency.

### 1.2 Examples

| Major | Minor | Decimals | Per Major | AR Symbol | EN Symbol |
|-------|-------|----------|-----------|-----------|-----------|
| Kuwaiti Dinar | Fils | 3 | 1000 | د.ك | KWD |
| Saudi Riyal | Halala | 2 | 100 | ر.س | SAR |
| US Dollar | Cent | 2 | 100 | $ | $ |
| Egyptian Pound | Piaster | 2 | 100 | ج.م | EGP |
| Bahraini Dinar | Fils | 3 | 1000 | د.ب | BHD |
| Jordanian Dinar | Fils | 3 | 1000 | د.أ | JOD |
| Iraqi Dinar | Fils | 3 | 1000 | د.ع | IQD |
| Japanese Yen | — | 0 | 1 | ¥ | JPY |
| Bitcoin | Satoshi | 8 | 100,000,000 | ₿ | BTC |

The system handles all of these uniformly.

---

## 2. Database Schema

### 2.1 `currencies` Table

```sql
create table currencies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  
  -- Identity
  iso_code text not null,                        -- ISO 4217 if exists (KWD, SAR, USD, ...)
  
  -- Major unit
  major_name_ar text not null,                   -- "دينار كويتي"
  major_name_en text not null,                   -- "Kuwaiti Dinar"
  major_symbol_ar text not null,                 -- "د.ك"
  major_symbol_en text not null,                 -- "KWD"
  
  -- Minor unit (optional — some currencies have no minor like JPY)
  minor_name_ar text,                            -- "فلس"
  minor_name_en text,                            -- "Fils"
  minor_symbol_ar text,
  minor_symbol_en text,
  
  -- Math
  decimal_places int not null default 2,         -- 0, 2, or 3 typically
  minor_units_per_major int not null default 100, -- 100 or 1000 typically
  
  -- Display preferences
  symbol_position text default 'after',          -- 'before' | 'after' the amount
  thousand_separator text default ',',
  decimal_separator text default '.',
  
  -- Status
  is_default boolean default false,              -- tenant's primary currency
  is_active boolean default true,
  sort_order int default 0,
  
  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  
  -- Constraints
  unique(tenant_id, iso_code),
  constraint chk_decimals check (decimal_places between 0 and 8),
  constraint chk_minor_per_major check (minor_units_per_major >= 1)
);

create index idx_currencies_tenant on currencies(tenant_id);
create unique index idx_currencies_default 
  on currencies(tenant_id) where is_default = true;
```

The unique partial index ensures only one default currency per tenant.

### 2.2 Money Columns Reference Currency

Most amounts in the system are in the tenant's default currency, so we don't need to store currency_id on every money column. But for **multi-currency support** (Phase 2 feature), tables like `invoices` and `vouchers` can have an optional `currency_id`:

```sql
alter table invoices add column
  currency_id uuid references currencies(id),    -- null = use tenant default
  exchange_rate_to_default numeric(15,8) default 1.0;
```

For v1, all amounts use the tenant's default currency. Multi-currency is a Phase 2 enhancement.

### 2.3 Tenant Default Currency

```sql
-- Helper: get tenant's default currency
create or replace function tenant_default_currency()
returns uuid as $$
  select id from currencies
  where tenant_id = current_tenant_id()
    and is_default = true
    and is_active = true
  limit 1;
$$ language sql stable;
```

---

## 3. Initial Seed Data

When a tenant is provisioned, the system seeds **common GCC + USD** currencies, with the tenant's chosen one marked as default:

```sql
-- During tenant onboarding script
insert into currencies (tenant_id, iso_code,
  major_name_ar, major_name_en, major_symbol_ar, major_symbol_en,
  minor_name_ar, minor_name_en, minor_symbol_ar, minor_symbol_en,
  decimal_places, minor_units_per_major, is_default, sort_order)
values
  ('<tenant_id>', 'KWD',
    'دينار كويتي', 'Kuwaiti Dinar', 'د.ك', 'KWD',
    'فلس', 'Fils', 'فلس', 'fils',
    3, 1000, true, 1),                              -- default for HS360 launch
  ('<tenant_id>', 'SAR',
    'ريال سعودي', 'Saudi Riyal', 'ر.س', 'SAR',
    'هللة', 'Halala', 'هللة', 'halala',
    2, 100, false, 2),
  ('<tenant_id>', 'AED',
    'درهم إماراتي', 'UAE Dirham', 'د.إ', 'AED',
    'فلس', 'Fils', 'فلس', 'fils',
    2, 100, false, 3),
  ('<tenant_id>', 'USD',
    'دولار أمريكي', 'US Dollar', '$', 'USD',
    'سنت', 'Cent', 'سنت', 'cent',
    2, 100, false, 4);
```

Manager can disable, edit, or add more currencies via settings.

---

## 4. Managing Currencies — UI

```
┌────────────────────────────────────────────────────────┐
│  Settings → Currencies                                 │
├────────────────────────────────────────────────────────┤
│  Default currency: Kuwaiti Dinar (KWD)                 │
│                                                        │
│  [+ Add Currency]                                      │
│                                                        │
│  Code  Name                Symbol  Decimals  Default   │
│  ─────────────────────────────────────────────────     │
│  KWD   دينار كويتي          د.ك    3         ⭐ ✓      │
│        Kuwaiti Dinar        KWD                        │
│  ─────────────────────────────────────────────────     │
│  SAR   ريال سعودي           ر.س    2         ☐         │
│        Saudi Riyal          SAR                        │
│  ─────────────────────────────────────────────────     │
│  USD   دولار أمريكي         $      2         ☐         │
│        US Dollar            USD                        │
│  ─────────────────────────────────────────────────     │
│                                                        │
│  Tap a row → edit                                      │
│  Tap ⭐ → set as default (warning: affects all data)   │
└────────────────────────────────────────────────────────┘
```

### 4.1 Add Currency Dialog

```
┌────────────────────────────────────────────────┐
│  Add Currency                                  │
├────────────────────────────────────────────────┤
│  ISO code:           [_____] (e.g. JOD)        │
│                                                │
│  Major unit:                                   │
│    Name (Arabic):    [____________]            │
│    Name (English):   [____________]            │
│    Symbol (Arabic):  [______]                  │
│    Symbol (English): [______]                  │
│                                                │
│  Minor unit (optional):                        │
│    Name (Arabic):    [____________]            │
│    Name (English):   [____________]            │
│                                                │
│  Decimals after point:    [3] (0–8)            │
│  Minor per major:         [1000]                │
│                                                │
│  Display:                                      │
│    ● Symbol after amount   ○ Before            │
│                                                │
│  [Cancel]                          [Save]      │
└────────────────────────────────────────────────┘
```

### 4.2 Default Currency Lock

Once a tenant has any transactions (invoices, vouchers, etc.), the default currency **cannot be changed**. A warning appears:
> "Your default currency is locked because financial records exist. Contact support if you must change it."

This prevents data corruption from currency mismatches.

---

## 5. Currency Formatting in the App

### 5.1 Dart Model

```dart
class Currency {
  final String id;
  final String isoCode;
  final String majorNameAr;
  final String majorNameEn;
  final String majorSymbolAr;
  final String majorSymbolEn;
  final String? minorNameAr;
  final String? minorNameEn;
  final int decimalPlaces;
  final int minorUnitsPerMajor;
  final String symbolPosition;       // 'before' | 'after'
  final String thousandSeparator;
  final String decimalSeparator;
  final bool isDefault;

  String symbol(String locale) =>
    locale == 'ar' ? majorSymbolAr : majorSymbolEn;
  
  String name(String locale) =>
    locale == 'ar' ? majorNameAr : majorNameEn;
}
```

### 5.2 MoneyDisplay Widget

```dart
class MoneyDisplay extends ConsumerWidget {
  final Decimal amount;
  final Currency? currency;           // null = use tenant default
  final TextStyle? style;
  final bool showSymbol;

  const MoneyDisplay(this.amount, {
    this.currency,
    this.style,
    this.showSymbol = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final curr = currency ?? ref.watch(defaultCurrencyProvider);
    final formatted = _format(amount, curr, locale);
    return Text(formatted, style: style);
  }

  String _format(Decimal amount, Currency curr, Locale locale) {
    final localeStr = locale.languageCode;
    
    // Format the number
    final fixed = amount.toStringAsFixed(curr.decimalPlaces);
    final parts = fixed.split('.');
    
    // Apply thousand separator
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}${curr.thousandSeparator}',
    );
    
    final numberStr = parts.length > 1
        ? '$intPart${curr.decimalSeparator}${parts[1]}'
        : intPart;
    
    if (!showSymbol) return numberStr;
    
    final sym = curr.symbol(localeStr);
    return curr.symbolPosition == 'before' 
        ? '$sym $numberStr'
        : '$numberStr $sym';
  }
}
```

### 5.3 Usage Examples

```dart
// Auto: uses tenant default currency, current locale
MoneyDisplay(Decimal.parse('12.500'))
// Output: "12.500 د.ك" (Arabic) or "12.500 KWD" (English)

// With explicit currency
MoneyDisplay(Decimal.parse('100.00'), currency: usdCurrency)
// Output: "100.00 $"

// In a table cell, with tabular figures
MoneyDisplay(
  amount,
  style: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
)
```

---

## 6. Bilingual Content — Everywhere

The system is **bilingual in every dimension**:

1. **App UI strings** — buttons, labels, error messages
2. **User-entered data** — product names, group names, customer names, descriptions
3. **System messages** — notifications, emails, WhatsApp templates
4. **PDF documents** — invoices, vouchers, contracts, statements
5. **Reports** — column headers, totals, footers

### 6.1 App UI Strings (Static)

Handled via Flutter's `intl` package + ARB files:

```
lib/l10n/
  app_ar.arb
  app_en.arb
```

Example `app_ar.arb`:
```json
{
  "appTitle": "HS360",
  "newContract": "عقد جديد",
  "customers": "الزبائن",
  "products": "المنتجات",
  "monthlyRentalValue": "قيمة الإيجار الشهري",
  "minProfitWarning": "الربح المتوقع أقل من الحد الأدنى المسموح",
  "totalAmount": "المبلغ الإجمالي"
}
```

Example `app_en.arb`:
```json
{
  "appTitle": "HS360",
  "newContract": "New Contract",
  "customers": "Customers",
  "products": "Products",
  "monthlyRentalValue": "Monthly Rental Value",
  "minProfitWarning": "Expected profit is below the minimum threshold",
  "totalAmount": "Total Amount"
}
```

Usage in widgets:
```dart
final loc = AppLocalizations.of(context)!;
Text(loc.newContract);
```

### 6.2 User-Entered Data (Dynamic)

Every name/description column in the database has **two columns**, never one:

```sql
-- Right
name_ar text not null,
name_en text not null,
description_ar text,
description_en text,

-- Wrong (don't do this)
-- name text not null
```

This pattern applies to:
- `product_groups.name_ar` / `name_en`
- `products.name_ar` / `name_en` / `description_ar` / `description_en`
- `chart_of_accounts.name_ar` / `name_en`
- `customers.name_ar` / `name_en`
- `whatsapp_templates.body_ar` / `body_en`
- `journal_entries.description_ar` / `description_en`
- ... and so on

### 6.3 Forms: Always Both Languages Side-by-Side

```
┌──────────────────────────────────────────┐
│  Add Product                             │
├──────────────────────────────────────────┤
│  Group: [Premium Oils ▼]                 │
│                                          │
│  Product Name                            │
│    Arabic:   [زيت هيلتون_______]         │
│    English:  [Hilton Oil______]          │
│                                          │
│  Description                             │
│    Arabic:   [_____________________]     │
│              [_____________________]     │
│                                          │
│    English:  [_____________________]     │
│              [_____________________]     │
│                                          │
│  SKU:        [OIL-HIL-01]                │
│  Barcode:    [8907894561234]             │
│                                          │
│  ... (rest of form) ...                  │
└──────────────────────────────────────────┘
```

Both fields are **required** by default (configurable per tenant — can be set to "Arabic required, English optional" if the tenant only operates in Arabic).

### 6.4 Display: Use Current Locale

```dart
// Product model has both
class Product {
  final String nameAr;
  final String nameEn;
  
  String name(String locale) =>
    locale == 'ar' ? nameAr : nameEn;
}

// In widgets
final loc = Localizations.localeOf(context);
Text(product.name(loc.languageCode));
```

### 6.5 Helper Extension

```dart
extension BilingualString on (String ar, String en) {
  String forLocale(String locale) => locale == 'ar' ? $1 : $2;
}

// Usage
final displayName = (product.nameAr, product.nameEn).forLocale(currentLocale);
```

### 6.6 PDF Documents

Every PDF has two templates:
- `invoice_template_ar.html`
- `invoice_template_en.html`

The Edge Function picks the template based on the customer's `preferred_language`. If unspecified, falls back to tenant's `default_locale`.

For some PDFs, **both languages appear side by side** (common for legal contracts):

```
┌─────────────────────────────────────────────────────┐
│   عقد إيجار                  Rental Agreement       │
│                                                     │
│   الطرف الأول: ...           First Party: ...       │
│   الطرف الثاني: ...          Second Party: ...      │
│                                                     │
│   البنود:                    Terms:                 │
│   ١. ...                     1. ...                 │
│   ٢. ...                     2. ...                 │
└─────────────────────────────────────────────────────┘
```

Tenant setting controls this:
```sql
alter table tenant_settings add column
  contract_pdf_style text default 'bilingual';  -- 'ar_only' | 'en_only' | 'bilingual'
```

---

## 7. RTL & LTR Handling

### 7.1 Automatic Direction

The app's root widget:

```dart
class HS360App extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    
    return MaterialApp.router(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => Directionality(
        textDirection: locale.languageCode == 'ar' 
            ? TextDirection.rtl 
            : TextDirection.ltr,
        child: child!,
      ),
      // ...
    );
  }
}
```

### 7.2 Direction-Aware Layouts

Always use `EdgeInsetsDirectional` and `AlignmentDirectional`:

```dart
// ✓ Correct
Padding(
  padding: EdgeInsetsDirectional.only(start: 16, end: 8),
  child: ...,
)

// ✗ Wrong — breaks in RTL
Padding(
  padding: EdgeInsets.only(left: 16, right: 8),
  child: ...,
)
```

### 7.3 Directional Icons

```dart
// Auto-flips: arrow_back becomes arrow_forward in RTL
Icon(Icons.arrow_back_ios_new)   // Material handles this automatically

// For custom icons, check direction
final isRtl = Directionality.of(context) == TextDirection.rtl;
Icon(isRtl ? Icons.chevron_left : Icons.chevron_right)
```

### 7.4 Mixed Content

When Arabic text contains English numbers/codes, browsers/Flutter handle it correctly out of the box. No special wrapping needed.

For sensitive ordering (like phone numbers), wrap in `Directionality`:
```dart
Directionality(
  textDirection: TextDirection.ltr,
  child: Text(phoneNumber),   // forces LTR even in Arabic UI
)
```

---

## 8. Locale Selection

### 8.1 Three Locale Sources (priority order)

1. User's manually-selected locale (stored in `SharedPreferences`)
2. Customer's `preferred_language` (for customer-facing docs)
3. Tenant's `default_locale` from settings
4. Device locale (fallback)

### 8.2 Per-User Preference

Each `tenant_users` row can store a locale preference:
```sql
alter table tenant_users add column 
  preferred_locale text default null;  -- null = use tenant default
```

A user in a Kuwait tenant might prefer English UI even though the company is Arabic-speaking. The app respects this.

### 8.3 Locale Toggle in UI

Always accessible from the top-right of the app:

```
[👤 Ahmad] [🌐 العربية] [⚙ Settings]
```

Tapping switches instantly. The change is saved to `tenant_users.preferred_locale`.

---

## 9. Number Formatting

### 9.1 Arabic vs Hindi Digits

Two ways to display Arabic numbers:
- **Arabic-Western:** 1, 2, 3, 4, 5 (most common in modern Arabic UIs)
- **Arabic-Indic:** ١, ٢, ٣, ٤, ٥ (traditional)

Default: **Arabic-Western digits**. Numbers like prices read more clearly. The tenant can override:

```sql
alter table tenant_settings add column 
  arabic_digit_style text default 'western';  -- 'western' | 'arabic_indic'
```

When set to `arabic_indic`, numbers are converted client-side via:
```dart
String toArabicIndic(String input) {
  const western = '0123456789';
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  return input.split('').map((c) {
    final i = western.indexOf(c);
    return i >= 0 ? arabicIndic[i] : c;
  }).join();
}
```

### 9.2 Dates

Date formatting respects the locale via `intl`:

```dart
final formatter = DateFormat.yMMMMd(currentLocale.toString());
formatter.format(DateTime.now());
// Arabic: "١٥ مايو ٢٠٢٦"  or "15 مايو 2026" depending on digit style
// English: "May 15, 2026"
```

Calendar systems: Gregorian is the default. **Hijri calendar support is a Phase 2 feature** — many Kuwaiti businesses use both, and conversion utilities will be added later.

---

## 10. Email & WhatsApp Localization

When sending automated messages, the system picks the language based on:
1. Customer's `preferred_language` (if set)
2. Tenant's `default_locale`

WhatsApp templates exist in both languages — the Edge Function picks the right one:

```sql
select * from whatsapp_templates
where tenant_id = $1
  and template_name = $2
  and language_code = (
    select coalesce(customers.preferred_language, tenants.default_locale)
    from customers, tenants
    where customers.id = $3 and tenants.id = $1
  );
```

---

## 11. Sorting & Search

### 11.1 Bilingual Search

The search box looks at **both** language fields:

```sql
-- Search products by name in either language
select * from products
where tenant_id = current_tenant_id()
  and (
    name_ar ilike '%' || $1 || '%'
    or name_en ilike '%' || $1 || '%'
  );
```

A user typing "Hilton" matches products with English name "Hilton Oil", and a user typing "هيلتون" matches the same row via Arabic name.

### 11.2 Sorting

Sorted by the current locale's name field:

```dart
final sortField = currentLocale == 'ar' ? 'name_ar' : 'name_en';
final results = await supabase.from('products').select().order(sortField);
```

---

## 12. Reports & Statements

Every report has bilingual column headers and bilingual narrative content:

```
[العربية] [English]      ← toggle at top of report

التقرير: الأرباح والخسائر
Period: January 2026

الإيرادات:                Income:
  إيراد الإيجار   1,500    Rental Income   1,500
  مبيعات         500       Sales           500
                ─────                      ─────
  المجموع       2,000      Total          2,000

المصروفات:                Expenses:
  ...                       ...
```

Or two parallel columns in side-by-side view.

---

## 13. Quick Reference for Cursor

When creating or editing any feature:

✅ **Always do:**
- Every user-entered name/description gets `*_ar` and `*_en` columns
- Every UI string goes in `.arb` files, never hardcoded
- Money uses `MoneyDisplay` widget, never raw `Text(amount.toString())`
- Currency comes from `defaultCurrencyProvider`, not hardcoded "KWD"
- Use `EdgeInsetsDirectional` and `AlignmentDirectional`
- Test in both `ar` and `en` locales before committing

❌ **Never:**
- Hardcode `"د.ك"` or `"KWD"` anywhere in code
- Use a single `name` column on a table — always `name_ar` + `name_en`
- Use `EdgeInsets.only(left:, right:)`
- Assume decimal places is always 3 (could be 2 for SAR, 0 for JPY)
- Format money manually with `toStringAsFixed(3)` — always use `MoneyDisplay`
