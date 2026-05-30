# Phase 3 - Products & Inventory Plan

> Purpose: build the first real business module on top of Phase 2 auth, routing, permissions, and locale foundation.
> Updated 2026-05-19.

---

## الملخص التنفيذي

لا تنفذ Phase 3 مرة واحدة.

الأفضل تنفيذها على Milestones واضحة: `M0`, `M1`, `M2`, ... لأن هذه المرحلة ليست مجرد شاشات منتجات. هي تمس:

- كتالوج المنتجات والمجموعات.
- وحدات القياس والتحويل بين الوحدة الأساسية والثانوية.
- المستودعات ومخزون السيارات.
- الوحدات المتسلسلة `product_units`.
- متوسط التكلفة `avg_cost` وآخر تكلفة شراء `last_purchase_cost`.
- إخفاء التكلفة حسب الصلاحيات.
- حركات المخزون والرصيد الحالي.
- أساس مراحل العقود والفواتير والزيارات القادمة.

خطأ صغير هنا سيظهر لاحقاً كخطأ محاسبي في العقود، الفواتير، تكلفة البضاعة، أو تقارير الربحية. لذلك التنفيذ يجب أن يكون تدريجياً وكل خطوة تنتهي باختبار وقبول واضح.

---

## قرار التنفيذ

نفذ Phase 3 على خطوات `M`.

لا تبدأ بالشاشات قبل تثبيت قواعد البيانات والـ repositories، ولا تبن حركات مخزون في الواجهة فقط. أي تغيير في المخزون يجب أن يكون مسجلاً كحركة قابلة للتدقيق، وأن يحدث الرصيد في عملية واحدة قابلة للاختبار.

التقسيم المقترح:

| Milestone | Name | Result |
|---|---|---|
| M0 | Phase 3 Baseline | تأكيد أن Phase 2 وقاعدة البيانات جاهزتان قبل أي تعديل |
| M0.5 | Safety Snapshot & Rollback Plan | نسخة احتياطية، schema snapshot، وخطة رجوع قبل migrations |
| M1 | Database Gap Review & Inventory Helpers | تثبيت أي دوال أو اختبارات ناقصة للمخزون والتحويل |
| M1.5 | Inventory Business Rules & Engine Boundaries | حسم قواعد السالب، WAC، references، وفصل stock عن cost |
| M2 | Domain Models & Repositories | نماذج وطبقة بيانات قابلة للاختبار |
| M3 | Routes, Permissions & Navigation | فتح مسارات المنتجات والمخزون بصلاحيات صحيحة |
| M4 | Product Groups & Product List | قائمة منتجات عملية مع بحث وفلاتر وإخفاء تكلفة |
| M5 | Product Detail, Edit & Wizard | تفاصيل المنتج والإضافة والتعديل والصورة |
| M6 | Product Units Management | إدارة الوحدات المتسلسلة والإضافة الجماعية |
| M7A | Warehouses | إدارة المستودعات ومستودعات السيارات |
| M7B | Stock Balances | عرض الأرصدة الجاهزة بدون جمع الحركات كل مرة |
| M7C | Movements Log | سجل حركات immutable وقابل للتصفية |
| M7D | Manual Adjustments | تعديلات مخزون محكومة بسبب وصلاحية |
| M7E | Transfers | نقل داخلي بين المستودعات بحركتي خروج/دخول |
| M7.5 | Performance & Stock Optimization | فهارس، seed ضغط، ومراجعة أداء المخزون |
| M8 | Verification & Phase Close | إغلاق المرحلة باختبارات تقنية ومحاسبية |

### Completion Status - 2026-05-30

- [x] M0 - Phase 3 Baseline
- [x] M0.5 - Safety Snapshot & Rollback Plan
- [x] M1 - Database Gap Review & Inventory Helpers
- [x] M1.5 - Inventory Business Rules & Engine Boundaries
- [x] M2 - Domain Models & Repositories
- [x] M3 - Routes, Permissions & Navigation
- [x] M4 - Product Groups & Product List
- [x] M5 - Product Detail, Edit & Wizard
- [x] M6 - Product Units Management
- [x] M6.5 - Product Sale/Rental Modes
- [x] M7A - Warehouses
- [x] M7B - Stock Balances
- [x] M7C - Movements Log
- [x] M7D - Manual Adjustments
- [x] M7E - Transfers
- [x] M7.5 - Performance & Stock Optimization
- [x] M8 - Verification & Phase Close

---

## مراجعة الوضع الحالي

### جاهز من Phase 1 و Phase 2

- جداول المنتجات موجودة:
  - `product_groups`
  - `products`
  - `product_units`
- جداول المخزون موجودة:
  - `warehouses`
  - `inventory_balances`
  - `inventory_movements`
- View آمن موجود:
  - `products_safe` ويخفي أعمدة التكلفة والحدود الدنيا.
- RLS موجود على الجداول الأساسية.
- الصلاحيات مزروعة في seed:
  - `products.view`
  - `products.create`
  - `products.edit`
  - `products.delete`
  - `products.field.avg_cost`
  - `products.field.last_purchase_cost`
  - `products.field.min_sale_price`
  - `products.field.min_rental_price`
  - `product_units.*`
  - `product_groups.*`
  - `warehouses.*`
  - `inventory.view`
  - `inventory_movements.*`
- Phase 2 جهزت:
  - تسجيل الدخول.
  - `AppSession`.
  - `AppPermissions`.
  - permission-aware routing.
  - locale persistence.
- تصميم Phase 1 يغطي مسبقاً بعض النقاط المهمة:
  - `inventory_balances` موجود كـ cached balance table، لذلك لا نعتمد على `SUM(inventory_movements)` في كل شاشة.
  - `product_type` موجود حالياً: `sale_only`, `asset_rental`, `consumable_rental`.
  - `unit_status` موجود كـ state machine أولي للأجهزة: available/rented/maintenance/damaged/retired وغيرها.
  - audit triggers موجودة على `products`, `product_units`, و `inventory_movements`، لكن Phase 3 يجب أن تتحقق أنها كافية لحالات المخزون الجديدة.

### يحتاج حسم أو إضافة في Phase 3

- لا توجد حالياً شاشات منتجات أو مخزون.
- لا توجد repositories للمنتجات والمخزون.
- لا يوجد test خاص بـ Phase 3.
- `inventory_movements` وحدها لا تكفي إذا لم يتم تحديث `inventory_balances` معها بشكل ذري.
- `PRODUCTS_DETAIL.md` يذكر دوال تحويل `to_primary` و `to_secondary`، ويجب التأكد إن كانت موجودة أو إضافتها.
- رفع صورة المنتج يحتاج قرار MVP:
  - إما استخدام `products.image_url` فقط.
  - أو إضافة جدول `product_images` و bucket policies.
- قبول "purchase invoice updates stock and WAC" من `BUILD_PLAN.md` يتقاطع مع Phase 5، لذلك يجب ضبط الحدود كما في القسم التالي.

---

## الحدود المحاسبية للمرحلة

### داخل Phase 3

- إنشاء وتعديل المنتجات والمجموعات.
- إدارة الوحدات المتسلسلة.
- إدارة المستودعات.
- عرض أرصدة المخزون.
- تسجيل تعديلات مخزون تشغيلية:
  - `adjustment_in`
  - `adjustment_out`
- تحديث الرصيد من خلال حركة مخزون واحدة موثقة.
- احتساب WAC عند إدخال رصيد افتتاحي أو تعديل إدخال تكلفة، إذا تم تنفيذ ذلك عبر RPC محكم ومختبر.
- إخفاء التكلفة عن أي مستخدم لا يملك الصلاحيات الحساسة.

### خارج Phase 3

- فاتورة شراء مؤكدة مع قيود يومية.
- فاتورة بيع مؤكدة مع COGS.
- سندات قبض أو دفع.
- قيود اليومية الناتجة عن المخزون.
- عقود الإيجار وحجز الأجهزة.
- زيارات التعبئة ومخزون المندوب Offline.

هذه عناصر Phase 5 و Phase 6 و Phase 8.

### قرار مهم

لا نبني "فاتورة شراء تجريبية" داخل Phase 3 لمجرد تمرير acceptance قديم. الشراء الحقيقي يجب أن يدخل من `record_purchase_invoice(...)` في Phase 5 لأنه يحتاج فاتورة، مورد، ذمم، مخزون، WAC، وقيود يومية متوازنة.

في Phase 3 نثبت الأساس التشغيلي للمخزون: منتج، رصيد، حركة، تكلفة مرئية أو مخفية حسب الصلاحية. هذا هو القرار الأكثر أماناً لنظام محاسبي.

---

## قواعد هندسية ومحاسبية ملزمة

1. لا تستخدم `double` للمال أو التكلفة. استخدم `Decimal` في Dart و `numeric(15,3)` في Postgres.
2. كل الكميات تخزن داخلياً بالوحدة الأساسية `unit_primary`.
3. التحويل من الوحدة الثانوية إلى الأساسية يجب أن يكون في service أو RPC واضح، وليس متفرقاً داخل widgets.
4. لا تقرأ `products` مباشرة لمستخدم لا يملك كل صلاحيات التكلفة الحساسة. استخدم `products_safe`.
5. في Phase 3، إذا كان المستخدم يملك صلاحية حساسة جزئية فقط، تعامل معه كـ safe view إلى أن يتم بناء RPC يعيد أعمدة مخصصة حسب كل field permission.
6. لا تسمح للواجهة بإدخال `tenant_id` من المستخدم. repository يأخذه من `AppSession` أو RPC يستخرجه من JWT.
7. لا يوجد حذف فعلي للمنتجات أو المجموعات في الاستخدام الطبيعي. استخدم `is_active = false`.
8. لا تعدل الرصيد مباشرة من الواجهة. الرصيد يتغير فقط عبر حركة مخزون أو RPC.
9. حركات المخزون يجب أن تكون immutable. التصحيح يتم بحركة عكسية مع سبب.
10. لا تسمح برصيد سالب إلا إذا قررنا سياسة واضحة لاحقاً. الافتراضي: منع الرصيد السالب.
11. أي تعديل تكلفة أو سعر يجب أن يظهر في audit trail.
12. أي stock adjustment يجب أن يتطلب سبباً واضحاً.
13. افصل محرك الرصيد عن محرك التكلفة:
    - `StockEngine` يقرر الكمية والحالة والمستودع.
    - `CostEngine` يقرر WAC وآخر تكلفة وقيمة المخزون.
14. لا تبن `product_mode` جديد الآن؛ استخدم `product_type` الحالي ولا تضف enum جديد إلا عند ظهور حاجة حقيقية.
15. لا تعتمد على UUID وحده في التشغيل. `sku`, `barcode`, و `serial_number` يجب أن تكون جزءاً من تجربة البحث والعمل اليومي.
16. كل حركة مخزون يجب أن يكون لها source واضح:
    - adjustment
    - transfer
    - future invoice
    - future contract
    - future visit
17. لا تجعل Flutter يحسب الرصيد النهائي أو WAC النهائي. Flutter يمكن أن يعرض preview فقط، أما التغيير الحقيقي فيكون عبر RPC/DB transaction.
18. لا تضف `deleted_at` الآن إلا إذا احتجنا تاريخ حذف منطقي. في Phase 3 القرار المعتمد هو `is_active=false` لأن الجداول الحالية مصممة لذلك.

---

## M0 - Phase 3 Baseline

### Goal

تأكيد أن الأساس نظيف قبل بناء أول module تشغيلي.

### Work

1. افحص حالة git:

   ```powershell
   git status --short
   ```

2. تأكد من Supabase local:

   ```powershell
   npx --yes supabase status
   ```

3. أعد بناء قاعدة البيانات:

   ```powershell
   npx --yes supabase db reset
   ```

4. شغل اختبار RLS من Phase 1D:

   ```powershell
   docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_1d_rls.sql
   ```

5. شغل Flutter checks:

   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   ```

6. إذا لم يتم التأكد يدوياً بعد Phase 2، نفذ login smoke:

   | User | Expected |
   |---|---|
   | `owner@hayat-secret.test` | dashboard |
   | `products@hayat-secret.test` | dashboard |
   | `field@hayat-secret.test` | field today |
   | `zero@hayat-secret.test` | blocked |

### Files Expected To Change

None.

### Acceptance

- كل أوامر baseline تمر.
- لا توجد تعديلات غير مفهومة في git.
- Phase 2 routing يعمل قبل إضافة routes جديدة.

---

## M0.5 - Safety Snapshot & Rollback Plan

### Goal

تأمين نقطة رجوع واضحة قبل أي migration جديدة في Phase 3.

### Work

1. أنشئ backup محلي من قاعدة البيانات بعد نجاح M0:

   ```powershell
   npx --yes supabase db dump --local --file supabase/.temp/phase_3_pre_migrations_backup.sql
   ```

2. أنشئ schema-only snapshot للمراجعة:

   ```powershell
   npx --yes supabase db dump --local --schema public --file supabase/.temp/phase_3_pre_migrations_schema.sql
   ```

3. احفظ catalog snapshot سريع للجداول المهمة:

   ```powershell
   docker exec supabase_db_hs360 psql -U postgres -d postgres -c "\dt public.*"
   ```

4. وثق rollback decision في ملاحظة قصيرة داخل session:
   - إذا فشلت migration قبل دخول بيانات حقيقية: استخدم `db reset` بعد إصلاح migration.
   - إذا فشلت بعد وجود بيانات مهمة: لا تعدل migration قديمة؛ أضف forward-fix migration أو استرجع backup في بيئة local فقط.

5. لا تلتزم بملفات backup في git. تبقى داخل `supabase/.temp/`.

### Files Expected To Change

None committed.

### Acceptance

- backup file موجود محلياً في `supabase/.temp/`.
- schema snapshot موجود محلياً.
- خطة الرجوع واضحة قبل M1.
- لا توجد secrets أو dumps مضافة إلى git.

---

## M1 - Database Gap Review & Inventory Helpers

### Goal

تثبيت الفجوات التي تمنع مخزون صحيح وقابل للتدقيق قبل بناء Flutter UI.

### Work

1. راجع الجداول الحالية:
   - `products`
   - `product_groups`
   - `product_units`
   - `warehouses`
   - `inventory_balances`
   - `inventory_movements`
   - `products_safe`

2. أضف migration فقط إذا كانت الفجوة موجودة فعلاً. الأسماء المقترحة:

   ```text
   supabase/migrations/035_product_inventory_helpers.sql
   supabase/migrations/036_inventory_adjustment_rpc.sql
   supabase/migrations/037_product_images_storage.sql
   supabase/migrations/038_inventory_transfer_rpc.sql
   ```

3. `035_product_inventory_helpers.sql` يجب أن يغطي:
   - `to_primary(p_product_id uuid, p_qty_secondary numeric)`
   - `to_secondary(p_product_id uuid, p_qty_primary numeric)`
   - View أو RPC اختياري لـ product stock summary إذا كان سيبسط Flutter.

4. `036_inventory_adjustment_rpc.sql` يجب أن يغطي RPC واحد محكم، مثل:

   ```text
   record_inventory_adjustment(
     p_warehouse_id uuid,
     p_product_id uuid,
     p_qty numeric,
     p_movement_type movement_type,
     p_unit_cost numeric,
     p_notes text
   )
   ```

   قواعده:

   - يقبل فقط `adjustment_in` أو `adjustment_out` في Phase 3.
   - يستخرج `tenant_id` من `current_tenant_id()`.
   - يتحقق من صلاحية `inventory_movements.create`.
   - يتأكد أن المستودع والمنتج من نفس tenant.
   - يمنع الرصيد السالب.
   - يضيف row في `inventory_movements`.
   - يحدث أو ينشئ row في `inventory_balances`.
   - عند `adjustment_in` مع `unit_cost`، يحدث `avg_cost` و `last_purchase_cost` حسب سياسة WAC المعتمدة.
   - لا ينشئ قيود يومية في Phase 3.

5. `037_product_images_storage.sql` يجب أن يغطي الحد الأدنى:
   - bucket باسم `product_images`.
   - read policy مناسبة.
   - write policy تتطلب `products.edit`.
   - استخدام `products.image_url` كصورة أساسية في MVP.

6. `038_inventory_transfer_rpc.sql` يؤجل تنفيذه إلى M7E إذا كان حجم M1 كبيراً، لكن يجب حجز تصميمه مبكراً حتى لا نخلط التحويلات مع التعديلات اليدوية.

7. أضف اختبار SQL:

   ```text
   supabase/tests/phase_3_products_inventory.sql
   ```

### Accounting Note

تحديث `avg_cost` هنا مسموح فقط كرصيد افتتاحي أو adjustment تشغيلي، وليس كبديل عن فاتورة شراء. عند بناء Phase 5، `record_purchase_invoice(...)` هو المسار المالي الصحيح للشراء.

### Acceptance

- `npx --yes supabase db reset` يمر.
- `phase_1d_rls.sql` لا ينكسر.
- `phase_3_products_inventory.sql` يثبت:
  - العزل بين tenants.
  - أن المستخدم بلا صلاحية لا يستطيع تعديل المخزون.
  - أن adjustment يحدث movement و balance معاً.
  - أن الرصيد السالب مرفوض.
  - أن cost fields لا تظهر من `products_safe`.

---

## M1.5 - Inventory Business Rules & Engine Boundaries

> Canonical inventory rules: [`PHASE_3_M1_5_INVENTORY_RULES.md`](PHASE_3_M1_5_INVENTORY_RULES.md)

### Goal

حسم قواعد المخزون المحاسبية والتشغيلية قبل بناء الشاشات، حتى لا تصبح القواعد موزعة بين UI و repositories و migrations.

### Business Decisions

| Rule | Phase 3 Decision |
|---|---|
| Negative stock | ممنوع افتراضياً |
| Cost method | WAC فقط |
| FIFO/LIFO | خارج Phase 3 |
| Stock quantity unit | دائماً `unit_primary` |
| Manual adjustment | يحتاج `inventory_movements.create` وسبب إلزامي |
| Movement reference | إلزامي منطقياً؛ إذا لم يوجد مستند فعلي استخدم `reference_table='inventory_adjustment'` |
| Movement immutability | لا تعديل بعد الإنشاء؛ التصحيح بحركة عكسية |
| Serialized assets | لا تعامل ككمية فقط؛ تحتاج `product_units` و `unit_status` |
| Transfers | خروج من مستودع ودخول إلى مستودع آخر في transaction واحدة |
| Accounting journal | خارج Phase 3 |

### Engine Boundaries

استخدم فصل واضح في domain/services:

```text
StockEngine
  - validates stock availability
  - validates movement type
  - validates warehouse/product/unit relationships
  - decides balance deltas

CostEngine
  - calculates WAC preview
  - validates incoming unit cost
  - decides whether movement affects avg_cost
  - never creates accounting journal entries in Phase 3
```

الـ DB/RPC يبقى مصدر الحقيقة النهائي. Dart services يمكنها عرض preview أو validation مبكر، لكن لا تكون المصدر النهائي للرصيد أو التكلفة.

### Internal Codes Strategy

- `sku` هو الكود التشغيلي الداخلي للمنتج ويجب أن يكون فريداً داخل tenant.
- `barcode` يعرّف product type أو وحدة معينة حسب قواعد المسح.
- `serial_number` يعرّف الجهاز الفعلي في `product_units`.
- لا تعتمد فرق التشغيل على UUID في الشاشات أو الطباعة.
- الصيغة المقترحة لاحقاً: `HS-DIFF-0001`, `HS-OIL-0001`, لكن التوليد التلقائي يمكن تأجيله إذا لم يكن مطلوباً فوراً.

### Audit Requirements

Phase 1 لديه audit triggers، لكن M1.5 يجب أن يثبت أن الحالات التالية مسجلة:

- تغيير أسعار المنتج أو التكلفة.
- إنشاء أو تغيير حالة `product_units`.
- إنشاء حركة مخزون.
- تعديلات المخزون اليدوية مع السبب.
- تعطيل منتج أو مستودع.

إذا كان audit الحالي لا يسجل سبب adjustment، أضف السبب داخل `inventory_movements.notes` في Phase 3، واترك audit reason العام لمرحلة لاحقة إذا احتجنا column مخصص.

### Validation Layer

ثبّت validators قبل UI:

- duplicate SKU.
- duplicate barcode where required.
- duplicate serial number.
- invalid unit conversion.
- negative quantity.
- stock-out over available balance.
- serialized product without unit-level operation.
- transfer to same warehouse.
- inactive product or warehouse in new movement.

### Acceptance

- ملف الخطة أو issue التنفيذ يحسم القواعد أعلاه قبل M2.
- `StockEngine` و `CostEngine` محددان كمسؤوليات منفصلة.
- SQL tests في M1 تغطي أهم قواعد السالب والحركة الذرية.
- لا توجد قاعدة مخزون أساسية متروكة كقرار UI.

---

## M2 - Domain Models & Repositories

### Goal

بناء طبقة Dart نظيفة قبل UI: models, repositories, providers, validators.

### Suggested Files

```text
lib/features/products/domain/product.dart
lib/features/products/domain/product_group.dart
lib/features/products/domain/product_unit.dart
lib/features/products/domain/product_filters.dart
lib/features/products/domain/product_form_state.dart
lib/features/products/data/product_repository.dart
lib/features/products/data/product_group_repository.dart
lib/features/products/data/product_unit_repository.dart
lib/features/products/presentation/products_controller.dart

lib/features/inventory/domain/warehouse.dart
lib/features/inventory/domain/inventory_balance.dart
lib/features/inventory/domain/inventory_movement.dart
lib/features/inventory/domain/inventory_adjustment_form_state.dart
lib/features/inventory/data/warehouse_repository.dart
lib/features/inventory/data/inventory_repository.dart
lib/features/inventory/presentation/inventory_controller.dart

lib/domain/services/stock_engine.dart
lib/domain/services/cost_engine.dart
lib/domain/services/unit_conversion_service.dart
lib/domain/validators/product_validator.dart
lib/domain/validators/inventory_adjustment_validator.dart
lib/core/utils/decimal_parser.dart
lib/core/utils/money_formatter.dart
lib/core/utils/quantity_formatter.dart
```

أنشئ فقط الملفات التي تحتاجها فعلاً. لا تنشئ folders فارغة.

### Model Rules

- Money fields:
  - `salePrice`
  - `minSalePrice`
  - `avgCost`
  - `lastPurchaseCost`
  - `purchaseCost`
  - `unitCost`
  يجب أن تكون `Decimal?` أو `Decimal` حسب nullable في DB.

- Quantity fields:
  - `conversionFactor`
  - `qtyAvailable`
  - `qtyRented`
  - `qtyTrial`
  - `qtyMaintenance`
  - `qtyDamaged`
  يجب أن تكون `Decimal`.

- Enums:
  - `ProductType`
  - `UnitOfMeasure`
  - `UnitStatus`
  - `WarehouseType`
  - `MovementType`
  يجب mapping واضح بينها وبين قيم Postgres النصية.

### Repository Rules

- widgets لا تستدعي Supabase مباشرة.
- repositories تقرأ `SupabaseClient` من provider.
- repositories لا تأخذ `tenant_id` من form.
- insert/update يملأ `tenant_id` من `AppSession` عند الحاجة.
- أي operation مركبة أو حساسة تستخدم RPC.

### Product Repository Minimum API

```text
fetchProducts(filters)
fetchProductById(id)
createProduct(input)
updateProduct(id, input)
deactivateProduct(id)
fetchProductStock(productId)
uploadPrimaryImage(productId, file)
```

### Cost Visibility Rule

نفذ سياسة محافظة:

- Manager يرى كل شيء.
- User يرى التكلفة فقط إذا كان يملك كل الصلاحيات المطلوبة لقراءة `products` بأمان:
  - `products.field.avg_cost`
  - `products.field.last_purchase_cost`
  - `products.field.min_sale_price`
  - `products.field.min_rental_price`
- غير ذلك، repository يستخدم `products_safe`.

لا تنفذ partial sensitive columns في Phase 3 إلا إذا أضفت RPC مخصص يعيد فقط الأعمدة المسموحة.

### Tests

- Unit tests لـ enum parsing.
- Unit tests لـ `UnitConversionService`.
- Unit tests لـ validators.
- Unit tests لـ cost visibility decision.

### Acceptance

- repositories قابلة للاختبار.
- لا يوجد `Supabase.instance.client` خارج core/repositories.
- لا يوجد `double` في نماذج المال أو الكمية.
- build runner يولد providers بدون أخطاء:

  ```powershell
  dart run build_runner build --delete-conflicting-outputs
  ```

---

## M3 - Routes, Permissions & Navigation

### Goal

فتح module المنتجات والمخزون داخل التطبيق بدون كسر Phase 2 routing.

### Work

1. أضف routes:

   ```text
   /products
   /products/new
   /products/:id
   /warehouses
   /inventory
   /inventory/movements
   /inventory/transfers
   ```

2. حدث `AppRoutes`.

3. حدث guard rules:

   | Route | Required |
   |---|---|
   | `/products` | manager أو `products.view` |
   | `/products/new` | manager أو `products.create` |
   | `/products/:id` | manager أو `products.view` |
   | `/warehouses` | manager أو `warehouses.view` |
   | `/inventory` | manager أو `inventory.view` |
   | `/inventory/movements` | manager أو `inventory_movements.view` |
   | `/inventory/transfers` | manager أو `inventory_movements.create` |

4. حدث dashboard أو app shell لإظهار روابط modules المسموحة فقط.

5. أضف localized strings الأساسية في:

   ```text
   lib/l10n/app_ar.arb
   lib/l10n/app_en.arb
   ```

### Suggested Files

```text
lib/core/routing/app_routes.dart
lib/core/routing/app_router.dart
lib/core/routing/route_guards.dart
lib/shared/widgets/app_shell.dart
lib/shared/widgets/permission_gated.dart
```

### Tests

- Route guard tests:
  - manager can access all Phase 3 routes.
  - products user can access `/products`.
  - products user cannot access `/inventory` unless permission exists.
  - field user stays on field home.
  - zero user stays blocked.

### Acceptance

- لا توجد redirect loops.
- الروابط لا تظهر لمن لا يملك الصلاحية.
- الدخول المباشر URL محمي بالـ guard.

---

## M4 - Product Groups & Product List

### Goal

بناء أول شاشة عملية للمنتجات: عرض، بحث، فلترة، ودخول للتفاصيل.

### Work

1. Product groups:
   - عرض tree أو قائمة grouped.
   - إنشاء وتعديل group إذا الصلاحية موجودة.
   - استخدام `is_active=false` للتعطيل.

2. Product list:
   - search by SKU, Arabic name, English name, barcode.
   - filter by group.
   - filter by type:
     - `sale_only`
     - `asset_rental`
     - `consumable_rental`
   - filter by active/inactive.
   - filter by stock:
     - in stock
     - out of stock
     - low stock

3. Table columns:
   - SKU
   - Name
   - Group
   - Type
   - Sale price
   - Stock
   - Active status

4. Sensitive columns:
   - Avg cost
   - Last purchase cost
   - Min sale price
   تظهر فقط حسب cost visibility rule من M2.

5. Row click يفتح `/products/:id`.

### Suggested Files

```text
lib/features/products/presentation/product_list_screen.dart
lib/features/products/presentation/widgets/product_filters_bar.dart
lib/features/products/presentation/widgets/product_table.dart
lib/features/products/presentation/widgets/product_type_badge.dart
lib/features/products/presentation/widgets/product_stock_badge.dart
lib/features/products/presentation/widgets/product_group_tree.dart
```

### UI Rules

- لا تستخدم card داخل card.
- Data table يجب أن تكون قابلة للقراءة في Arabic و English.
- الأرقام المالية تستخدم tabular style إن أمكن.
- استخدم `EdgeInsetsDirectional`.
- لا تعرض raw enum values للمستخدم.
- empty state يحتوي action واحد واضح إذا المستخدم يملك `products.create`.

### Tests

- Widget test للتكلفة:
  - user without cost permission لا يرى cost labels.
  - manager يرى cost labels.
- Widget test للـ empty state.
- Unit test للفلترة إن كانت منطقية في controller.

### Acceptance

- Manager يرى المنتجات والتكلفة.
- Products user يرى المنتجات بدون التكلفة.
- Search/filter يعملان بدون كسر RTL.
- الضغط على row يفتح detail.

---

## M5 - Product Detail, Edit & Add Product Wizard

### Goal

إدارة بيانات المنتج الأساسية بطريقة تمنع إدخال بيانات تكسر المحاسبة أو العقود لاحقاً.

### Work

1. Product detail screen:
   - header with image, SKU, name, type, status.
   - tabs أو sections:
     - Overview
     - Pricing
     - Inventory
     - Units
     - Audit hints if available

2. Add product wizard:
   - Step 1: name, SKU, group, type.
   - Step 2: units and conversion factor.
   - Step 3: pricing.
   - Step 4: rental specifics if needed.
   - Step 5: barcode, serialized flag, maintenance flag, reorder point.

3. Edit product:
   - يسمح بتعديل البيانات العامة.
   - cost fields تتطلب cost permissions.
   - تغيير `is_serialized` بعد وجود stock أو units يجب أن يكون ممنوعاً أو يحتاج قرار واضح.

4. Image upload:
   - MVP: primary image only.
   - upload to `product_images` bucket.
   - update `products.image_url`.
   - path contains tenant and product id.

### Validation Rules

- `sku` required and unique per tenant.
- Arabic name required.
- English name required or fallback decision documented.
- `group_id` required.
- `conversion_factor = 1` when `unit_secondary is null`.
- `conversion_factor > 1` when `unit_secondary` exists.
- `sale_price >= min_sale_price` if both exist.
- rental products do not have product-level rental price; contract monthly value is entered on contracts.
- serialized products should be `unit_primary = piece`.
- `reorder_point >= 0`.
- `avg_cost >= 0`.
- `last_purchase_cost >= 0`.

### Suggested Files

```text
lib/features/products/presentation/product_detail_screen.dart
lib/features/products/presentation/product_form_controller.dart
lib/features/products/presentation/product_wizard_screen.dart
lib/features/products/presentation/widgets/product_pricing_form.dart
lib/features/products/presentation/widgets/product_units_form.dart
lib/features/products/presentation/widgets/product_image_picker.dart
```

### Tests

- Validator tests.
- Controller tests for create/update success and error mapping.
- Widget test for wizard required fields.

### Acceptance

- Create product succeeds and appears in list.
- Edit product updates detail.
- Cost fields are hidden or disabled without permission.
- Image upload does not expose service-role secret.
- Validation messages are localized.

---

## M6 - Product Units Management

### Goal

إدارة الأجهزة والوحدات المتسلسلة بشكل صحيح، لأن هذه البيانات ستستخدم لاحقاً في العقود والصيانة.

### Work

1. Unit list inside product detail:
   - serial number.
   - barcode.
   - status.
   - warehouse.
   - purchase cost if allowed.
   - health status.
   - acquired date.

2. Add single unit:
   - serial number.
   - optional barcode.
   - current warehouse.
   - purchase cost.
   - acquired date.
   - notes.

3. Bulk add:
   - paste CSV or lines of serial numbers.
   - preview before save.
   - detect duplicates before insert.
   - insert as one operation or batched operation with all-or-nothing behavior if possible.

4. Unit status:
   - show current status.
   - do not allow arbitrary transition if it conflicts with future contracts.
   - in Phase 3 allow only safe edits:
     - notes.
     - barcode.
     - health status.
     - warehouse when available and not rented.

5. History:
   - show empty state if no contract lines exist.
   - do not fake contract history.
   - future Phase 6 will populate real contract usage.

### Suggested Files

```text
lib/features/products/presentation/product_units_screen.dart
lib/features/products/presentation/widgets/product_unit_table.dart
lib/features/products/presentation/widgets/add_product_unit_dialog.dart
lib/features/products/presentation/widgets/bulk_product_units_dialog.dart
lib/features/products/domain/product_unit_bulk_parser.dart
```

### Database Rule

If adding units should increase stock, do it through a controlled repository/RPC path that creates:

- `product_units` rows.
- related `inventory_movements`.
- related `inventory_balances` updates.

Do not insert units and forget stock.

### Tests

- Parser tests for pasted serials.
- Duplicate detection tests.
- Permission tests:
  - user without `product_units.create` cannot add.
  - user without cost permission cannot see purchase cost.

### Acceptance

- Add 10 units for serialized product.
- Units appear in product detail.
- Duplicate serial is rejected before DB error when possible.
- Stock summary reflects available units.

---

## M7A - Warehouses

### Goal

إدارة المستودعات ومستودعات السيارات ككيانات تشغيلية مستقلة قبل عرض الأرصدة والحركات.

### Work

1. Warehouses screen:
   - list warehouses.
   - create warehouse.
   - edit warehouse.
   - deactivate warehouse.
   - warehouse types:
     - `main`
     - `branch`
     - `van`
   - van warehouse can link to employee.

2. Validation:
   - warehouse name required.
   - van warehouse requires employee if type is `van`.
   - one active van warehouse per employee.
   - inactive warehouse cannot receive new stock movements.

### Suggested Files

```text
lib/features/inventory/presentation/warehouses_screen.dart
lib/features/inventory/presentation/widgets/warehouse_form_dialog.dart
lib/features/inventory/domain/warehouse_validator.dart
```

### Acceptance

- Create main warehouse.
- Create van warehouse linked to employee.
- Duplicate active van for same employee is rejected.
- Deactivated warehouse no longer appears in create movement choices.

---

## M7B - Stock Balances

### Goal

عرض الأرصدة من `inventory_balances` كـ cached source، وليس بجمع `inventory_movements` في كل شاشة.

### Work

1. Inventory balances screen:
   - show balance by warehouse and product.
   - show available/rented/trial/maintenance/damaged.
   - show total across warehouses.
   - low stock indicator using `reorder_point`.

2. Product detail stock block:
   - balance per warehouse.
   - total available.
   - warning when below reorder point.

3. Repository:
   - query `inventory_balances`.
   - join product and warehouse display names carefully.
   - do not expose cost value unless cost permission exists.

### Suggested Files

```text
lib/features/inventory/presentation/inventory_screen.dart
lib/features/inventory/presentation/widgets/inventory_balance_table.dart
lib/features/products/presentation/widgets/product_stock_summary.dart
```

### Acceptance

- Balance table loads from `inventory_balances`.
- Product detail shows stock summary.
- Low-stock indicator works from `reorder_point`.
- No screen calculates balance by summing all movements.

---

## M7C - Movements Log

### Goal

عرض سجل الحركات كدفتر تشغيل immutable يمكن مراجعته وتصفيته.

### Work

1. Inventory movements log:
   - filter by date.
   - filter by warehouse.
   - filter by product.
   - filter by movement type.
   - show reference table/id when present.
   - show created_by and occurred_at.
   - movements are read-only after creation.

2. Reference policy:
   - manual adjustment uses `reference_table='inventory_adjustment'`.
   - transfer uses `reference_table='inventory_transfer'`.
   - future invoice/contract/visit references are reserved for later phases.

### Suggested Files

```text
lib/features/inventory/presentation/inventory_movements_screen.dart
lib/features/inventory/presentation/widgets/inventory_movement_table.dart
lib/features/inventory/domain/inventory_movement_filters.dart
```

### Acceptance

- Movement log is filterable.
- Movement detail exposes reference metadata.
- No edit action exists for existing movements.
- User without `inventory_movements.view` cannot open the log.

---

## M7D - Manual Adjustments

### Goal

تسجيل stock-in و stock-out اليدوي بشكل محكم ومختبر.

### Work

1. Manual adjustment dialog:
   - stock in.
   - stock out.
   - reason required.
   - unit cost required for stock in if it affects WAC.
   - stock out rejects if insufficient stock.
   - serialized product requires unit-level handling, not just bulk qty.

2. WAC policy for Phase 3:
   - WAC is per primary unit.
   - `adjustment_in` with cost can update WAC.
   - `adjustment_out` does not change WAC.
   - formula:

     ```text
     new_avg_cost =
       ((old_total_qty * old_avg_cost) + (incoming_qty * incoming_unit_cost))
       / (old_total_qty + incoming_qty)
     ```

   - if old total qty is zero, `new_avg_cost = incoming_unit_cost`.
   - this does not create accounting journal entries in Phase 3.

### Suggested Files

```text
lib/features/inventory/presentation/inventory_adjustment_dialog.dart
lib/features/inventory/domain/inventory_adjustment_validator.dart
```

### Tests

- SQL test for `record_inventory_adjustment`.
- Unit test for WAC preview calculation.
- Widget test for hiding adjustment action without permission.

### Acceptance

- Manual stock-in increases balance.
- Manual stock-out decreases balance.
- Insufficient stock is rejected.
- Movement appears in log.
- WAC updates only according to policy.
- No accounting invoice or journal is created in this phase.

---

## M7E - Transfers

### Goal

نقل المخزون بين مستودعين في عملية واحدة، خصوصاً من المخزن الرئيسي إلى سيارة مندوب.

### Work

1. Add transfer flow:
   - source warehouse.
   - destination warehouse.
   - product.
   - quantity.
   - optional product unit for serialized assets.
   - reason/notes.

2. Add RPC if needed:

   ```text
   record_inventory_transfer(
     p_from_warehouse_id uuid,
     p_to_warehouse_id uuid,
     p_product_id uuid,
     p_qty numeric,
     p_product_unit_id uuid,
     p_notes text
   )
   ```

3. RPC rules:
   - source and destination must differ.
   - both warehouses must be active and in current tenant.
   - source must have enough available stock.
   - create `transfer_out` movement for source.
   - create `transfer_in` movement for destination.
   - update both balances in the same transaction.
   - transfer does not change WAC.

### Suggested Files

```text
lib/features/inventory/presentation/inventory_transfer_dialog.dart
lib/features/inventory/domain/inventory_transfer_validator.dart
```

### Acceptance

- Transfer from main warehouse to van decreases source and increases destination.
- Transfer to same warehouse is rejected.
- Transfer above available stock is rejected.
- Two linked movement rows appear in the log.
- WAC does not change after transfer.

---

## M7.5 - Performance & Stock Optimization

### Goal

إثبات أن تصميم المخزون لن ينهار مع بيانات أكبر من seed البسيط.

### Work

1. Add optional seed/test data script for local performance:
   - 100 products.
   - 3 warehouses.
   - 1,000+ inventory movements.
   - balances for common product/warehouse combinations.

2. Review indexes:
   - `inventory_balances(tenant_id)`
   - `inventory_balances(warehouse_id)`
   - `inventory_movements(tenant_id)`
   - `inventory_movements(occurred_at desc)`
   - `inventory_movements(reference_table, reference_id)`
   - add composite indexes only if query plans show need.

3. Run query-plan checks for the main list queries if practical:

   ```sql
   explain analyze
   select *
   from inventory_balances
   where tenant_id = current_tenant_id();
   ```

4. UI performance:
   - use pagination or limit for movements.
   - do not load all movement history on product detail.
   - avoid rebuilding large tables unnecessarily.

### Suggested Files

```text
supabase/tests/phase_3_inventory_performance_seed.sql
```

Use this only for local testing; do not make heavy seed part of normal `db reset` unless it stays fast.

### Acceptance

- Product list remains usable with 100+ products.
- Movement log uses pagination or bounded fetch.
- Main stock queries do not depend on summing all historical movements.
- No unnecessary composite indexes are added without query evidence.

---

## M8 - Verification & Phase Close

### Goal

إثبات أن Products & Inventory foundation جاهزة لتغذية Phase 4, Phase 5, Phase 6, Phase 8.

### Required Commands

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
npx --yes supabase db reset
docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_1d_rls.sql
docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_3_products_inventory.sql
```

If practical:

```powershell
flutter test integration_test
```

### Verification Result - 2026-05-30

- [x] `flutter pub get`
- [x] `flutter pub run build_runner build --delete-conflicting-outputs --verbose`
- [x] `flutter analyze`
- [x] `flutter test` - 220 tests passed
- [x] `flutter test integration_test`
- [x] `phase_1d_rls.sql` verification passed
- [x] `phase_3_products_inventory.sql` verification passed
- [x] `git diff --check`
- [ ] `npx --yes supabase db reset` - intentionally not re-run for M8 close because it wipes local data and is currently blocked by Supabase CLI 2.102 internal duplicate service migration before project migrations.

### Manual Acceptance Matrix

| Done | Case | Expected |
|---|---|---|
| [x] | Manager opens `/products` | list visible with cost fields |
| [x] | Products user opens `/products` | list visible without cost fields |
| [x] | Products user opens `/inventory` without permission | redirected or blocked |
| [x] | Zero user opens `/products` | blocked |
| [x] | Field user logs in | still goes to `/field/today` |
| [x] | Create product | appears in list |
| [x] | Add serialized units | units appear and stock summary updates |
| [x] | Manual stock-in | balance increases and movement appears |
| [x] | Manual stock-out | balance decreases and movement appears |
| [x] | Stock-out above balance | localized business error |
| [x] | Transfer main -> van | source decreases, destination increases, two movements appear |
| [x] | Transfer above balance | localized business error |
| [x] | Switch Arabic/English | layout remains readable; bad local seed Arabic falls back to English instead of `?` placeholders |

### Quality Checklist

- [x] No widget calls Supabase directly.
- [x] No money or quantity uses `double`.
- [x] Permission checks use `AppPermissions`.
- [x] Cost fields are not fetched for users without full sensitive cost permission.
- [x] Product and inventory repositories are separate.
- [x] `StockEngine` and `CostEngine` responsibilities are separate.
- [x] Inventory adjustments are atomic.
- [x] Inventory transfers are atomic.
- [x] Movement log is immutable.
- [x] Heavy movement history is paginated or bounded.
- [x] Arabic and English strings exist for user-facing text.
- [x] File-size scan reviewed.

### File-Size Scan

```powershell
Get-ChildItem lib,supabase -Recurse -File |
  Where-Object { $_.Extension -in '.dart','.sql' } |
  ForEach-Object {
    [pscustomobject]@{
      Lines = (Get-Content $_.FullName | Measure-Object -Line).Lines
      File = $_.FullName
    }
  } |
  Where-Object { $_.Lines -gt 250 } |
  Sort-Object Lines -Descending
```

### Phase 3 Done Means

- [x] Products can be created, listed, viewed, edited, and deactivated.
- [x] Product groups are usable.
- [x] Product units can be added and reviewed.
- [x] Warehouses are usable.
- [x] Inventory balances are visible and update through controlled movements.
- [x] Transfers between warehouses are supported.
- [x] Cost fields are protected.
- [x] Stock and cost rules are centralized outside UI.
- [x] The app has routes and UI ready for products and inventory.
- [x] Phase 5 can build purchase/sales invoices on a stable product and stock foundation.
- [x] Phase 6 can use serialized product units for rental contracts.
- [x] Phase 8 can later use warehouse/van stock as a base for field operations.

---

## Suggested Implementation Chunks

For actual coding sessions, use these chunks:

| Chunk | Milestones | Why |
|---|---|---|
| Chunk 1 | M0 + M0.5 | baseline ثم backup/schema snapshot قبل migrations |
| Chunk 2 | M1 + M1.5 | تثبيت DB/RPC والقواعد المحاسبية قبل UI |
| Chunk 3 | M2 + M3 | بناء models/repositories/routes معاً |
| Chunk 4 | M4 | شاشة القائمة والمجموعات وحدها لأنها أول UI كبيرة |
| Chunk 5 | M5 + M6 | التفاصيل والwizard والوحدات المتسلسلة |
| Chunk 6 | M7A + M7B | المستودعات والأرصدة |
| Chunk 7 | M7C + M7D + M7E | سجل الحركات والتعديلات والتحويلات |
| Chunk 8 | M7.5 + M8 | الأداء وإغلاق المرحلة |

كل chunk يجب أن ينتهي بـ:

```powershell
flutter analyze
flutter test
```

وإذا لمس DB:

```powershell
npx --yes supabase db reset
```

---

## شرح الخطوات بصورة عملية

### لماذا M0؟

حتى لا نبني Phase 3 فوق أساس مكسور. إذا كان login أو RLS أو routing فيه مشكلة، ستظهر كأنها مشكلة منتجات وهي ليست كذلك.

### لماذا M0.5؟

لأن Phase 3 ستضيف migrations وRPCs تمس المخزون والتكلفة. وجود backup وschema snapshot قبل التغيير يجعل الرجوع واضحاً إذا فشلت migration أو احتجنا مقارنة schema قبل وبعد.

### لماذا M1 قبل Flutter؟

لأن شاشة المخزون لا قيمة لها إذا كانت تغيّر الرصيد محلياً أو تعرض أرقاماً غير مسجلة. في برامج المحاسبة، الرصيد يجب أن يأتي من حركة موثقة، وليس من state داخل الواجهة.

### لماذا M1.5؟

حتى نحسم قواعد العمل قبل أن تنتشر داخل الشاشات: هل السالب مسموح، كيف نحسب WAC، هل التحويل يغير التكلفة، ومتى نحتاج reference. هذه قرارات نظام، وليست قرارات UI.

### لماذا M2؟

حتى تكون طبقة Supabase معزولة وقابلة للاختبار. UI يجب أن يعرض ويتفاعل، لا أن يقرر كيف يحتسب WAC أو كيف يقرأ جدول حساس.

### لماذا M3؟

Phase 2 routing كان متعمداً صغيراً. قبل إضافة شاشات فعلية يجب توسيع المسارات والصلاحيات بدون كسر المستخدمين الحاليين: manager, products user, field user, zero user.

### لماذا M4؟

قائمة المنتجات هي أول نقطة تشغيل يومية. يجب أن تثبت البحث، الفلاتر، إخفاء التكلفة، والانتقال للتفاصيل قبل بناء wizard معقد.

### لماذا M5؟

تفاصيل المنتج والwizard يحددان جودة بيانات العقود والفواتير لاحقاً. المنتج السيئ الآن يعني عقد أو فاتورة سيئة لاحقاً.

### لماذا M6؟

الأجهزة المؤجرة ليست كمية فقط. كل جهاز له serial/status/warehouse/history. هذه نقطة مهمة جداً قبل Phase 6 contracts.

### لماذا تقسيم M7؟

المستودعات والحركات هي أساس المخزون الحقيقي، لكنها أكبر من خطوة واحدة. تقسيمها إلى `M7A..M7E` يجعل كل جزء قابلاً للاختبار: المستودعات، الأرصدة، السجل، التعديلات، والتحويلات. هذا يقلل خطر بناء شاشة كبيرة تخفي أخطاء في الرصيد أو الصلاحيات.

### لماذا M7.5؟

حتى لا نكتشف متأخرين أن شاشة المخزون بطيئة مع بيانات واقعية. عندنا `inventory_balances` كجدول أرصدة جاهز، وM7.5 يثبت أننا نستخدمه صح ولا نعتمد على جمع كل الحركات في كل طلب.

### لماذا M8؟

إغلاق المرحلة ليس "الشاشات تفتح". الإغلاق يعني أن الصلاحيات، العزل، التكلفة، الرصيد، RTL/LTR، والتحقق التقني كلها تعمل.

---

## Starting Point For Next Coding Session

ابدأ بـ M0. إذا نجح، نفذ M0.5 لحفظ backup وschema snapshot، ثم انتقل إلى M1 وM1.5.

لا تبدأ بـ Product UI قبل M1 و M1.5 و M2. هذه أسرع طريقة ظاهرياً لكنها أخطر طريقة لنظام محاسبي، لأنها تسمح للواجهة أن تقود قواعد المخزون بدلاً من قاعدة بيانات وخدمات قابلة للتدقيق.
