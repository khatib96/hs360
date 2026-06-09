// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'HS360';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get dashboardPhase2Subtitle =>
      'المرحلة 2 نشطة — المصادقة والصلاحيات والتوجيه جاهزة. الوحدات في المرحلة 3.';

  @override
  String get sessionDisplayNameLabel => 'اسم العرض';

  @override
  String get sessionAccountTypeLabel => 'نوع الحساب';

  @override
  String get sessionEmailLabel => 'البريد الإلكتروني';

  @override
  String get sessionTenantLabel => 'معرّف المستأجر';

  @override
  String get accountTypeManager => 'مدير';

  @override
  String get accountTypeUser => 'مستخدم';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'أدخل بيانات حسابك للمتابعة';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get signIn => 'دخول';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get sendResetLink => 'إرسال رابط إعادة التعيين';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get loading => 'جاري التحميل…';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get validationEmailRequired => 'أدخل البريد الإلكتروني';

  @override
  String get validationEmailInvalid => 'أدخل بريداً إلكترونياً صالحاً';

  @override
  String get validationPasswordRequired => 'أدخل كلمة المرور';

  @override
  String get authErrorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get authErrorNetworkUnavailable =>
      'تعذر الاتصال. تحقق من الشبكة أو من تشغيل Supabase محلياً';

  @override
  String get authErrorNoActiveTenantUser =>
      'لا يوجد حساب مستأجر نشط مرتبط بهذا المستخدم';

  @override
  String get authErrorUserInactive => 'حساب المستخدم غير نشط';

  @override
  String get authErrorSupabaseNotConfigured => 'إعداد Supabase غير مكتمل';

  @override
  String get authErrorUnknown => 'حدث خطأ غير متوقع. حاول مرة أخرى';

  @override
  String get authMissingAnonKey =>
      'مفتاح Supabase المحلي غير مضبوط. شغّل التطبيق عبر scripts/run-local.ps1';

  @override
  String get authInitFailed =>
      'تعذر تهيئة Supabase. تحقق من تشغيل الخدمة المحلية';

  @override
  String get resetPasswordSuccess =>
      'إذا كان البريد مسجلاً، ستصلك تعليمات إعادة تعيين كلمة المرور.';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordSubtitle =>
      'أدخل بريدك الإلكتروني وسنرسل تعليمات إعادة التعيين إن وُجد الحساب';

  @override
  String get fieldTodayTitle => 'اليوم';

  @override
  String get fieldTodayPlaceholder =>
      'ستظهر الزيارات المخصصة هنا في مرحلة لاحقة.';

  @override
  String get blockedTitle => 'لا يوجد وصول';

  @override
  String get blockedMessage =>
      'لا توجد صلاحيات مخصصة لحسابك. تواصل مع المدير للحصول على صلاحيات.';

  @override
  String get products => 'المنتجات';

  @override
  String get productsNew => 'منتج جديد';

  @override
  String get productsDetail => 'تفاصيل المنتج';

  @override
  String get warehouses => 'المستودعات';

  @override
  String get warehouseAdd => 'إضافة مستودع';

  @override
  String get warehouseEdit => 'تعديل مستودع';

  @override
  String get warehouseDeactivate => 'تعطيل المستودع';

  @override
  String get warehouseDeactivateConfirm =>
      'تعطيل هذا المستودع؟ لن يظهر في اختيارات حركات المخزون.';

  @override
  String get warehouseNameAr => 'الاسم بالعربية';

  @override
  String get warehouseNameEn => 'الاسم بالإنجليزية';

  @override
  String get warehouseType => 'نوع المستودع';

  @override
  String get warehouseTypeMain => 'رئيسي';

  @override
  String get warehouseTypeBranch => 'فرع';

  @override
  String get warehouseTypeVan => 'سيارة';

  @override
  String get warehouseEmployee => 'الموظف';

  @override
  String get warehouseEmployeeNone => 'اختر موظفاً';

  @override
  String get warehouseEmployeeInactiveHint => 'موظف غير نشط';

  @override
  String get warehouseLocationAddress => 'عنوان الموقع';

  @override
  String get warehouseActive => 'نشط';

  @override
  String get warehouseInactive => 'غير نشط';

  @override
  String get warehouseColumnName => 'الاسم';

  @override
  String get warehouseColumnType => 'النوع';

  @override
  String get warehouseColumnEmployee => 'الموظف';

  @override
  String get warehouseColumnAddress => 'العنوان';

  @override
  String get warehouseColumnStatus => 'الحالة';

  @override
  String get warehouseListEmpty => 'لا توجد مستودعات بعد.';

  @override
  String get warehouseListError => 'تعذر تحميل المستودعات. حاول مرة أخرى.';

  @override
  String get warehouseValidationAgentRequired =>
      'اختر موظفاً لمستودعات السيارات';

  @override
  String get warehouseErrorDuplicateActiveVan =>
      'هذا الموظف لديه مستودع سيارة نشط مسبقاً';

  @override
  String get warehouseErrorUnknown => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get warehouseEmployeeLookupFailed =>
      'تعذر تحميل الموظفين لتعيين السيارات. قد تكون مستودعات السيارات محدودة حتى يتم الإصلاح.';

  @override
  String get warehouseEmployeeLookupRetry => 'إعادة تحميل الموظفين';

  @override
  String get inventory => 'أرصدة المخزون';

  @override
  String get inventoryBalancesEmpty => 'لا توجد أرصدة مخزون بعد.';

  @override
  String get inventoryBalancesError =>
      'تعذر تحميل أرصدة المخزون. حاول مرة أخرى.';

  @override
  String get inventoryBalancesProductLabelsFailed =>
      'تعذر تحميل أسماء المنتجات. تُعرض الأرصدة بتسميات محدودة.';

  @override
  String get inventoryBalancesWarehouseLabelsFailed =>
      'تعذر تحميل أسماء المستودعات. تُعرض الأرصدة بتسميات محدودة.';

  @override
  String get inventoryBalanceNameUnavailable => 'غير متاح';

  @override
  String get inventoryBalanceProduct => 'المنتج';

  @override
  String get inventoryBalanceWarehouse => 'المستودع';

  @override
  String get inventoryBalanceAvailable => 'متاح';

  @override
  String get inventoryBalanceRented => 'مؤجر';

  @override
  String get inventoryBalanceTrial => 'تجريبي';

  @override
  String get inventoryBalanceMaintenance => 'صيانة';

  @override
  String get inventoryBalanceDamaged => 'تالف';

  @override
  String get inventoryBalancesSearchHint => 'بحث بالمنتج أو المستودع';

  @override
  String get inventoryBalancesFilterWarehouse => 'المستودع';

  @override
  String get inventoryBalancesFilterWarehouseAll => 'كل المستودعات';

  @override
  String get inventoryBalancesFilterLowStock => 'مخزون منخفض فقط';

  @override
  String get inventoryBalancesSummaryTotal => 'إجماليات التصفية';

  @override
  String get inventoryErrorInsufficientStock =>
      'المخزون غير كافٍ لهذه العملية.';

  @override
  String get inventoryErrorSerializedAdjustmentNotSupported =>
      'تعديلات الكمية الجماعية غير مدعومة للمنتجات المسلسلة. استخدم وحدات المنتج بدلاً من ذلك.';

  @override
  String get inventoryManualAdjustment => 'تعديل يدوي';

  @override
  String get inventoryAdjustmentTitle => 'تعديل مخزون يدوي';

  @override
  String get inventoryAdjustmentNotes => 'السبب / الملاحظات';

  @override
  String get inventoryAdjustmentQuantity => 'الكمية';

  @override
  String get inventoryAdjustmentUnitCost => 'تكلفة الوحدة';

  @override
  String get inventoryAdjustmentPreviewDelta => 'تغير المتاح';

  @override
  String get inventoryAdjustmentPreviewWac =>
      'متوسط التكلفة المتوقع بعد الإدخال';

  @override
  String get inventoryAdjustmentStockInRequiresCost =>
      'إدخال المخزون يتطلب صلاحيات تكلفة المنتج الكاملة.';

  @override
  String get inventoryAdjustmentProductsViewRequired =>
      'بحث المنتج يتطلب صلاحية products.view.';

  @override
  String get inventoryAdjustmentWarehouseRequired => 'اختر مستودعاً.';

  @override
  String get inventoryAdjustmentProductRequired => 'اختر منتجاً.';

  @override
  String get inventoryAdjustmentSuccess => 'تم تسجيل تعديل المخزون.';

  @override
  String get inventoryTransferTitle => 'تحويل مخزون';

  @override
  String get inventoryTransferSourceWarehouse => 'المستودع المصدر';

  @override
  String get inventoryTransferDestinationWarehouse => 'المستودع الوجهة';

  @override
  String get inventoryTransferQuantity => 'الكمية';

  @override
  String get inventoryTransferNotes => 'السبب / الملاحظات';

  @override
  String get inventoryTransferSelectProduct => 'ابحث عن منتج بالاسم أو SKU';

  @override
  String get inventoryTransferPreviewSource => 'تغيير المصدر';

  @override
  String get inventoryTransferPreviewDestination => 'تغيير الوجهة';

  @override
  String get inventoryTransferSameWarehouse =>
      'يجب أن يختلف المستودع المصدر عن الوجهة.';

  @override
  String get inventoryTransferSuccess => 'تم تسجيل تحويل المخزون.';

  @override
  String get inventorySourceWarehouseRequired => 'اختر المستودع المصدر.';

  @override
  String get inventoryDestinationWarehouseRequired => 'اختر مستودع الوجهة.';

  @override
  String get inventoryErrorSerializedTransferNotSupported =>
      'تحويل المخزون غير مدعوم للمنتجات المسلسلة.';

  @override
  String get inventoryAdjustmentSelectProduct => 'ابحث عن منتج بالاسم أو SKU';

  @override
  String get inventoryAdjustmentMovementType => 'نوع الحركة';

  @override
  String get productDetailStockByWarehouse => 'حسب المستودع';

  @override
  String get productDetailStockLowWarning =>
      'المخزون المتاح عند أو أقل من نقطة إعادة الطلب.';

  @override
  String get inventoryMovements => 'سجل الحركات';

  @override
  String get inventoryTransfers => 'تحويلات المخزون';

  @override
  String get inventoryMovementsEmpty => 'لا توجد حركات مخزون مطابقة للفلاتر.';

  @override
  String get inventoryMovementsError =>
      'تعذر تحميل حركات المخزون. حاول مرة أخرى.';

  @override
  String get inventoryMovementsProductLabelsFailed =>
      'تعذر تحميل أسماء المنتجات. تُعرض الحركات بتسميات محدودة.';

  @override
  String get inventoryMovementsWarehouseLabelsFailed =>
      'تعذر تحميل أسماء المستودعات. تُعرض الحركات بتسميات محدودة.';

  @override
  String get inventoryMovementsSearchHint => 'بحث باسم المنتج أو الرمز';

  @override
  String get inventoryMovementsSearchRequiresProducts =>
      'بحث الاسم أو الرمز يتطلب صلاحية عرض المنتجات. يمكنك البحث بمعرّفات الحركة والملاحظات.';

  @override
  String get inventoryMovementsFilterWarehouse => 'المستودع';

  @override
  String get inventoryMovementsFilterWarehouseAll => 'كل المستودعات';

  @override
  String get inventoryMovementsFilterMovementType => 'نوع الحركة';

  @override
  String get inventoryMovementsFilterMovementTypeAll => 'كل الأنواع';

  @override
  String get inventoryMovementsFilterDateFrom => 'من تاريخ';

  @override
  String get inventoryMovementsFilterDateTo => 'إلى تاريخ';

  @override
  String get inventoryMovementsFilterPageSize => 'حجم الصفحة';

  @override
  String get inventoryMovementOccurredAt => 'وقت الحركة';

  @override
  String get inventoryMovementType => 'النوع';

  @override
  String get inventoryMovementProduct => 'المنتج';

  @override
  String get inventoryMovementWarehouse => 'المستودع';

  @override
  String get inventoryMovementQuantity => 'الكمية';

  @override
  String get inventoryMovementReference => 'المرجع';

  @override
  String get inventoryMovementCreatedBy => 'معرّف المنشئ';

  @override
  String get inventoryMovementNotes => 'ملاحظات';

  @override
  String get inventoryMovementUnitCost => 'تكلفة الوحدة';

  @override
  String get inventoryMovementNotesNone => '—';

  @override
  String get inventoryMovementReferenceNone => '—';

  @override
  String get inventoryMovementCreatedByNotRecorded => 'غير مسجل';

  @override
  String get inventoryMovementReferenceAdjustment => 'تعديل مخزون';

  @override
  String get inventoryMovementReferenceTransfer => 'تحويل';

  @override
  String get inventoryMovementReferenceProductUnit => 'وحدة منتج';

  @override
  String get inventoryMovementTypePurchase => 'شراء';

  @override
  String get inventoryMovementTypeSale => 'بيع';

  @override
  String get inventoryMovementTypeRentalOut => 'إيجار خارج';

  @override
  String get inventoryMovementTypeRentalReturn => 'إرجاع إيجار';

  @override
  String get inventoryMovementTypeRefill => 'تعبئة';

  @override
  String get inventoryMovementTypeTransferOut => 'تحويل خارج';

  @override
  String get inventoryMovementTypeTransferIn => 'تحويل داخل';

  @override
  String get inventoryMovementTypeAdjustmentIn => 'تعديل داخل';

  @override
  String get inventoryMovementTypeAdjustmentOut => 'تعديل خارج';

  @override
  String get inventoryMovementTypeSaleReturn => 'مرتجع بيع';

  @override
  String get inventoryMovementTypePurchaseReturn => 'مرتجع شراء';

  @override
  String get inventoryMovementTypeMaintenanceIn => 'صيانة داخل';

  @override
  String get inventoryMovementTypeMaintenanceOut => 'صيانة خارج';

  @override
  String get productsSearchHint => 'بحث بالرمز أو الاسم أو الباركود';

  @override
  String get productsListEmpty => 'لا توجد منتجات مطابقة للفلاتر.';

  @override
  String get productsListError => 'تعذر تحميل المنتجات. حاول مرة أخرى.';

  @override
  String get productsNotAvailable => '—';

  @override
  String get productsGroupUnavailable => 'غير متاح';

  @override
  String get productsAllGroups => 'كل المنتجات';

  @override
  String get productsFilterType => 'النوع';

  @override
  String get productsFilterActive => 'الحالة';

  @override
  String get productsFilterStock => 'المخزون';

  @override
  String get productsFilterClear => 'مسح الفلاتر';

  @override
  String get productsFilterAll => 'الكل';

  @override
  String get productsFilterActiveOnly => 'نشط فقط';

  @override
  String get productsFilterInactiveOnly => 'غير نشط فقط';

  @override
  String get productTypeSaleOnly => 'بيع فقط';

  @override
  String get productTypeAssetRental => 'أصل إيجار';

  @override
  String get productTypeConsumableRental => 'مستهلك إيجار';

  @override
  String get productModeSale => 'بيع';

  @override
  String get productModeRental => 'تأجير';

  @override
  String get productRentalTypeAsset => 'أصل';

  @override
  String get productRentalTypeConsumable => 'مستهلك';

  @override
  String get productStatusActive => 'نشط';

  @override
  String get productStatusInactive => 'غير نشط';

  @override
  String get productStockIn => 'متوفر';

  @override
  String get productStockOut => 'نفد';

  @override
  String get productStockLow => 'مخزون منخفض';

  @override
  String get productColumnSku => 'الرمز';

  @override
  String get productColumnName => 'الاسم';

  @override
  String get productColumnGroup => 'المجموعة';

  @override
  String get productColumnType => 'النوع';

  @override
  String get productColumnSalePrice => 'سعر البيع';

  @override
  String get productColumnStock => 'المخزون';

  @override
  String get productColumnActive => 'الحالة';

  @override
  String get productColumnAvgCost => 'متوسط التكلفة';

  @override
  String get productColumnLastPurchaseCost => 'آخر شراء';

  @override
  String get productColumnMinSalePrice => 'أدنى سعر بيع';

  @override
  String get productGroupAdd => 'إضافة مجموعة';

  @override
  String get productGroupEdit => 'تعديل مجموعة';

  @override
  String get productGroupDeactivate => 'تعطيل المجموعة';

  @override
  String get productGroupDeactivateConfirm => 'تعطيل مجموعة المنتجات هذه؟';

  @override
  String get productGroupNameAr => 'الاسم بالعربية';

  @override
  String get productGroupNameEn => 'الاسم بالإنجليزية';

  @override
  String get productGroupParent => 'المجموعة الأب';

  @override
  String get productGroupActive => 'نشط';

  @override
  String get productGroupNone => 'بدون';

  @override
  String get productGroupValidationNameRequired =>
      'أدخل الاسم بالعربية والإنجليزية';

  @override
  String get productsGroupsTitle => 'مجموعات المنتجات';

  @override
  String get productsEdit => 'تعديل المنتج';

  @override
  String get productEditAction => 'تعديل';

  @override
  String get productWizardStepIdentity => 'البيانات الأساسية';

  @override
  String get productWizardStepUnits => 'الوحدات';

  @override
  String get productWizardStepPricing => 'التسعير';

  @override
  String get productWizardStepFlags => 'التفاصيل';

  @override
  String get productWizardStepReview => 'المراجعة';

  @override
  String get productWizardNext => 'التالي';

  @override
  String get productWizardBack => 'السابق';

  @override
  String get productWizardSubmit => 'حفظ المنتج';

  @override
  String get productWizardCreateTitle => 'منتج جديد';

  @override
  String get productFieldSku => 'الرمز';

  @override
  String get productFieldNameAr => 'الاسم بالعربية';

  @override
  String get productFieldNameEn => 'الاسم بالإنجليزية';

  @override
  String get productFieldGroup => 'مجموعة المنتج';

  @override
  String get productFieldType => 'نوع المنتج';

  @override
  String get productFieldMode => 'طريقة التعامل';

  @override
  String get productFieldRentalType => 'نوع التأجير';

  @override
  String get productFieldUnitPrimary => 'الوحدة الأساسية';

  @override
  String get productFieldUnitSecondary => 'الوحدة الثانوية';

  @override
  String get productFieldConversionFactor => 'معامل التحويل';

  @override
  String get productFieldSalePrice => 'سعر البيع';

  @override
  String get productFieldMinSalePrice => 'أدنى سعر بيع';

  @override
  String get productFieldAvgCost => 'متوسط التكلفة';

  @override
  String get productFieldLastPurchaseCost => 'آخر تكلفة شراء';

  @override
  String get productFieldBarcode => 'الباركود';

  @override
  String get productFieldSerialized => 'منتج متسلسل';

  @override
  String get productFieldMaintenance => 'قابل للصيانة';

  @override
  String get productFieldExpectedLifespan => 'العمر الافتراضي بالأشهر';

  @override
  String get productFieldReorderPoint => 'نقطة إعادة الطلب';

  @override
  String get productFieldActive => 'نشط';

  @override
  String get productSectionOverview => 'نظرة عامة';

  @override
  String get productSectionPricing => 'التسعير';

  @override
  String get productSectionUnits => 'الوحدات';

  @override
  String get productSectionInventory => 'المخزون';

  @override
  String get productSectionAudit => 'التدقيق';

  @override
  String get productDetailNotFound => 'المنتج غير موجود.';

  @override
  String get productDetailLoadError => 'تعذر تحميل المنتج. حاول مرة أخرى.';

  @override
  String get productDetailStockUnavailable => 'ملخص المخزون غير متاح.';

  @override
  String get productDetailStockTotal => 'الإجمالي المتاح';

  @override
  String get productDetailCreatedAt => 'تاريخ الإنشاء';

  @override
  String get productDetailUpdatedAt => 'آخر تحديث';

  @override
  String get productImageAdd => 'إضافة صورة';

  @override
  String get productImageChange => 'تغيير الصورة';

  @override
  String get productImageUploading => 'جاري رفع الصورة…';

  @override
  String productCreatedSuccess(String sku) {
    return 'تم إنشاء المنتج $sku بنجاح.';
  }

  @override
  String get productSavedSuccess => 'تم حفظ المنتج.';

  @override
  String get productGroupsPermissionRequired =>
      'تحتاج صلاحية مجموعات المنتجات لإنشاء منتج.';

  @override
  String get productValidationSkuRequired => 'الرمز مطلوب';

  @override
  String get productValidationNameArRequired => 'الاسم بالعربية مطلوب';

  @override
  String get productValidationNameEnRequired => 'الاسم بالإنجليزية مطلوب';

  @override
  String get productValidationGroupRequired => 'مجموعة المنتج مطلوبة';

  @override
  String get productValidationConversionInvalid =>
      'معامل التحويل غير صالح للوحدات المختارة';

  @override
  String get productValidationSaleBelowMin =>
      'سعر البيع لا يمكن أن يكون أقل من أدنى سعر بيع';

  @override
  String get productValidationModeRequired =>
      'اختر البيع أو التأجير أو الاثنين معًا';

  @override
  String get productValidationExpectedLifespan =>
      'العمر الافتراضي يجب أن يكون رقمًا صحيحًا أكبر من صفر';

  @override
  String get productValidationSerializedPiece =>
      'المنتجات المتسلسلة يجب أن تستخدم القطعة كوحدة أساسية';

  @override
  String get productValidationNegative => 'القيمة لا يمكن أن تكون سالبة';

  @override
  String get productValidationInvalidDecimal => 'أدخل رقماً صالحاً';

  @override
  String get productValidationFailed => 'يرجى تصحيح الحقول المحددة';

  @override
  String get productErrorPermissionDenied => 'ليس لديك صلاحية لهذا الإجراء';

  @override
  String get productErrorDuplicateSku => 'الرمز موجود مسبقاً';

  @override
  String get productErrorDuplicateBarcode => 'الباركود موجود مسبقاً';

  @override
  String get productErrorFieldNotSupported => 'هذا الحقل غير مدعوم حالياً';

  @override
  String get productErrorImageType => 'يجب أن تكون الصورة JPG أو PNG أو WebP';

  @override
  String get productErrorImageSize => 'يجب ألا يتجاوز حجم الصورة 5 ميجابايت';

  @override
  String get productErrorUnknown => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get productSerializedLocked =>
      'لا يمكن تغيير التسلسل مع وجود مخزون أو عدم معرفة المخزون';

  @override
  String get productNoSecondaryUnit => 'بدون';

  @override
  String get productWizardReviewTitle => 'مراجعة قبل الحفظ';

  @override
  String get productUnitsNotSerialized =>
      'تتبع الوحدات للمنتجات المتسلسلة فقط.';

  @override
  String get productUnitsViewDenied => 'ليس لديك صلاحية عرض وحدات المنتج.';

  @override
  String get productUnitsEmpty =>
      'لا توجد وحدات بعد. أضف وحدة أو الصق أرقام تسلسلية.';

  @override
  String get productUnitsHistoryEmpty => 'لا يوجد سجل عقود لهذه الوحدة بعد.';

  @override
  String get productUnitAdd => 'إضافة وحدة';

  @override
  String get productUnitBulkAdd => 'إضافة جماعية';

  @override
  String get productUnitEdit => 'تعديل الوحدة';

  @override
  String get productUnitFieldSerial => 'الرقم التسلسلي';

  @override
  String get productUnitFieldBarcode => 'الباركود';

  @override
  String get productUnitFieldStatus => 'الحالة';

  @override
  String get productUnitFieldWarehouse => 'المستودع';

  @override
  String get productUnitFieldPurchaseCost => 'تكلفة الشراء';

  @override
  String get productUnitFieldHealth => 'الصحة';

  @override
  String get productUnitFieldAcquired => 'تاريخ الاستلام';

  @override
  String get productUnitFieldNotes => 'ملاحظات';

  @override
  String get productUnitBulkPasteHint =>
      'الصق رقم تسلسلي في كل سطر، أو CSV: serial,barcode,cost. CSV بسيط فقط.';

  @override
  String get productUnitBulkPreview => 'معاينة';

  @override
  String get productUnitBulkConfirm => 'إنشاء الوحدات';

  @override
  String get productUnitHealthGood => 'جيد';

  @override
  String get productUnitHealthNeedsService => 'يحتاج صيانة';

  @override
  String get productUnitHealthDamaged => 'تالف';

  @override
  String get productUnitHealthLost => 'مفقود';

  @override
  String get productUnitStatusAvailableNew => 'متاح (جديد)';

  @override
  String get productUnitStatusAvailableUsed => 'متاح (مستعمل)';

  @override
  String get productUnitStatusRented => 'مؤجر';

  @override
  String get productUnitStatusTrial => 'تجريبي';

  @override
  String get productUnitStatusMaintenance => 'صيانة';

  @override
  String get productUnitStatusSold => 'مباع';

  @override
  String get productUnitStatusDamaged => 'تالف';

  @override
  String get productUnitStatusLost => 'مفقود';

  @override
  String get productUnitStatusRetired => 'متقاعد';

  @override
  String get productUnitErrorDuplicateSerial => 'الرقم التسلسلي موجود مسبقاً';

  @override
  String get productUnitErrorNotSerialized => 'هذا المنتج غير متسلسل';

  @override
  String get productUnitErrorNotEditable =>
      'لا يمكن تعديل هذه الوحدة في حالتها الحالية';

  @override
  String get productUnitErrorBulkLimit =>
      'الحد الأقصى 100 وحدة لكل عملية جماعية';

  @override
  String get productUnitParserEmptySerial => 'رقم تسلسلي فارغ في القائمة';

  @override
  String get productUnitParserDuplicate => 'رقم تسلسلي مكرر في القائمة';

  @override
  String get productUnitParserInvalidCost => 'تكلفة شراء غير صالحة في القائمة';

  @override
  String get productUnitSectionHistory => 'سجل العقود';

  @override
  String get productUnitWarehouseTransferHint =>
      'استخدم تحويلات المخزون لنقل المخزون بين المستودعات.';

  @override
  String get customers => 'العملاء';

  @override
  String get suppliers => 'الموردون';

  @override
  String get customerDetails => 'تفاصيل العميل';

  @override
  String get editCustomer => 'تعديل العميل';

  @override
  String get customerOverview => 'نظرة عامة';

  @override
  String get customerStatement => 'كشف الحساب';

  @override
  String get customerTimeline => 'السجل الزمني';

  @override
  String get customerProfile => 'الملف';

  @override
  String get customerContracts => 'العقود';

  @override
  String get customerInvoices => 'الفواتير';

  @override
  String get customerVouchers => 'السندات';

  @override
  String get customerNotFound => 'العميل غير موجود.';

  @override
  String get customerPrimaryLocationSummary => 'الموقع الأساسي';

  @override
  String get customerAccountNotLinked => 'لا يوجد حساب مدين مرتبط';

  @override
  String get customerAccountIdLabel => 'معرف الحساب';

  @override
  String get customerLedgerPermissionDenied =>
      'لا تملك صلاحية عرض دفتر حسابات هذا العميل.';

  @override
  String get customerStatementEmpty => 'لا توجد حركات في الدفتر بعد.';

  @override
  String get customerStatementNotLoaded =>
      'افتح هذا التبويب لتحميل كشف الحساب.';

  @override
  String get customerStatementSummaryTitle => 'ملخص الحساب';

  @override
  String get customerStatementDebit => 'مدين';

  @override
  String get customerStatementCredit => 'دائن';

  @override
  String get customerStatementBalance => 'الرصيد';

  @override
  String get customerStatementColumnDate => 'التاريخ';

  @override
  String get customerStatementColumnEntry => 'القيد';

  @override
  String get customerStatementColumnSource => 'المصدر';

  @override
  String get customerStatementColumnDescription => 'الوصف';

  @override
  String get customerContractsEmpty => 'لا توجد عقود بعد.';

  @override
  String get customerInvoicesEmpty => 'لا توجد فواتير بعد.';

  @override
  String get customerVouchersEmpty => 'لا توجد سندات بعد.';

  @override
  String get customerTimelineEmpty => 'لا توجد أحداث في السجل بعد.';

  @override
  String get customerTimelineCreated => 'تم إنشاء العميل';

  @override
  String get customerTimelineUpdated => 'تم تحديث الملف';

  @override
  String get customerTimelineAcquired => 'تم اكتساب العميل';

  @override
  String get journalSourceManual => 'قيد يدوي';

  @override
  String get journalSourceSalesInvoice => 'فاتورة مبيعات';

  @override
  String get journalSourcePurchaseInvoice => 'فاتورة مشتريات';

  @override
  String get journalSourceReceiptVoucher => 'سند قبض';

  @override
  String get journalSourcePaymentVoucher => 'سند صرف';

  @override
  String get journalSourceRentalInvoice => 'فاتورة إيجار';

  @override
  String get journalSourceContractCreation => 'إنشاء عقد';

  @override
  String get journalSourceContractClosure => 'إغلاق عقد';

  @override
  String get journalSourceOpeningBalance => 'رصيد افتتاحي';

  @override
  String get journalSourceInventoryAdjustment => 'تسوية مخزون';

  @override
  String get journalSourceSalaryPayment => 'دفع راتب';

  @override
  String get chartOfAccounts => 'دليل الحسابات';

  @override
  String get referenceId => 'المرجع';

  @override
  String get customersListUnavailable =>
      'قائمة العملاء غير متاحة في هذا الإصدار.';

  @override
  String get suppliersListUnavailable =>
      'قائمة الموردين غير متاحة في هذا الإصدار.';

  @override
  String get customerDetailsUnavailable => 'العميل غير موجود أو غير متاح.';

  @override
  String get customerEditUnavailable => 'تعديل العميل غير متاح في هذا الإصدار.';

  @override
  String get supplierDetailsUnavailable =>
      'تفاصيل المورد غير متاحة في هذا الإصدار.';

  @override
  String get chartOfAccountsUnavailable =>
      'عرض دليل الحسابات غير متاح في هذا الإصدار.';

  @override
  String get moduleSectionUnavailable => 'هذا القسم غير متاح في هذا الإصدار.';

  @override
  String get moduleAccessUnavailable => 'لا تملك صلاحية عرض هذا القسم.';

  @override
  String get createCustomerTitle => 'عميل جديد';

  @override
  String get customerSearchHint => 'ابحث بالكود أو الاسم أو الهاتف أو البريد';

  @override
  String get customerFilterStatus => 'الحالة';

  @override
  String get customerFilterAll => 'الكل';

  @override
  String get customerStatusActive => 'نشط';

  @override
  String get customerStatusInactive => 'غير نشط';

  @override
  String get customerFilterVip => 'مميز';

  @override
  String get customerVip => 'مميز';

  @override
  String get customerNonVip => 'عادي';

  @override
  String get customerClearFilters => 'مسح عوامل التصفية';

  @override
  String get customerTypeLabel => 'النوع';

  @override
  String get customerTypeIndividual => 'فرد';

  @override
  String get customerTypeCompany => 'شركة';

  @override
  String get customerColumnCode => 'الكود';

  @override
  String get customerColumnName => 'الاسم';

  @override
  String get customerColumnPhone => 'الهاتف';

  @override
  String get customerColumnType => 'النوع';

  @override
  String get customerColumnLocation => 'الموقع';

  @override
  String get customerColumnStatus => 'الحالة';

  @override
  String get customerActionView => 'عرض';

  @override
  String get customerActionEdit => 'تعديل';

  @override
  String get customerActionDeactivate => 'إلغاء التنشيط';

  @override
  String get customerAdd => 'إضافة عميل';

  @override
  String get customerListEmpty => 'لا يوجد عملاء بعد.';

  @override
  String get customerListEmptyFiltered =>
      'لا يوجد عملاء مطابقون لعوامل التصفية.';

  @override
  String get customerDeactivateConfirmTitle => 'إلغاء تنشيط العميل';

  @override
  String get customerDeactivateConfirmBody =>
      'سيتم إخفاء هذا العميل من القائمة النشطة. يمكنك إيجاده بتغيير عامل تصفية الحالة. هل تريد المتابعة؟';

  @override
  String get customerCreated => 'تم إنشاء العميل.';

  @override
  String get customerUpdated => 'تم حفظ العميل.';

  @override
  String get customerDeactivated => 'تم إلغاء تنشيط العميل.';

  @override
  String get customerFieldCode => 'الكود';

  @override
  String get customerFieldNameAr => 'الاسم';

  @override
  String get customerFieldNameEn => 'الاسم (إنجليزي)';

  @override
  String get customerFieldContactName => 'الشخص المسؤول';

  @override
  String get customerFieldContactPhone => 'هاتف المسؤول';

  @override
  String get customerFieldPhonePrimary => 'الهاتف الأساسي';

  @override
  String get customerFieldEmail => 'البريد الإلكتروني';

  @override
  String get customerFieldTaxNumber => 'الرقم الضريبي';

  @override
  String get customerFieldAddress => 'تفاصيل العنوان';

  @override
  String get customerFieldArea => 'المنطقة';

  @override
  String get customerFieldGovernorate => 'المحافظة';

  @override
  String get customerFieldCountry => 'الدولة';

  @override
  String get customerFieldGoogleMapsUrl => 'رابط خرائط Google';

  @override
  String get customerFieldVip => 'عميل مميز';

  @override
  String get customerFieldNotes => 'ملاحظات';

  @override
  String get customerFieldCreateAccount => 'إنشاء حساب محاسبي';

  @override
  String get customerFieldCreateAccountHint =>
      'يربط حسابًا فرعيًا للذمم المدينة تحت حساب المدينين.';

  @override
  String get customerLinkedAccountYes => 'حساب محاسبي مرتبط';

  @override
  String get customerLinkedAccountNo => 'لا يوجد حساب محاسبي';

  @override
  String get customerEnsureAccount => 'إنشاء حساب محاسبي';

  @override
  String get customerAccountLinked => 'تم ربط الحساب المحاسبي.';

  @override
  String get customerSectionIdentity => 'الهوية';

  @override
  String get customerSectionContact => 'التواصل';

  @override
  String get customerSectionLocation => 'الموقع';

  @override
  String get customerSectionAccounting => 'المحاسبة';

  @override
  String get customerValidationNameArRequired => 'الاسم بالعربية مطلوب.';

  @override
  String get customerValidationPhoneRequired => 'الهاتف الأساسي مطلوب.';

  @override
  String get customerValidationEmailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا.';

  @override
  String get customerValidationFailed => 'تعذّر حفظ العميل. يرجى مراجعة القيم.';

  @override
  String get customerErrorPermissionDenied =>
      'لا تملك صلاحية تنفيذ هذا الإجراء.';

  @override
  String get customerErrorAccountAlreadyLinked =>
      'هذا الملف مرتبط بحساب محاسبي بالفعل.';

  @override
  String get customerErrorUnknown => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get locationAreaOther => 'أخرى (إدخال يدوي)';

  @override
  String get locationEnterCustomArea => 'إدخال المنطقة يدويًا';

  @override
  String get locationUseCatalogArea => 'اختيار من القائمة';

  @override
  String get createSupplierTitle => 'مورّد جديد';

  @override
  String get editSupplierTitle => 'تعديل المورّد';

  @override
  String get supplierSearchHint => 'ابحث بالكود أو الاسم أو الهاتف أو البريد';

  @override
  String get supplierFilterStatus => 'الحالة';

  @override
  String get supplierFilterAll => 'الكل';

  @override
  String get supplierStatusActive => 'نشط';

  @override
  String get supplierStatusInactive => 'غير نشط';

  @override
  String get supplierClearFilters => 'مسح عوامل التصفية';

  @override
  String get supplierColumnCode => 'الكود';

  @override
  String get supplierColumnName => 'الاسم';

  @override
  String get supplierColumnPhone => 'الهاتف';

  @override
  String get supplierColumnEmail => 'البريد الإلكتروني';

  @override
  String get supplierColumnLocation => 'الموقع';

  @override
  String get supplierColumnStatus => 'الحالة';

  @override
  String get supplierActionView => 'عرض';

  @override
  String get supplierActionEdit => 'تعديل';

  @override
  String get supplierActionDeactivate => 'إلغاء التنشيط';

  @override
  String get supplierAdd => 'إضافة مورّد';

  @override
  String get supplierListEmpty => 'لا يوجد موردون بعد.';

  @override
  String get supplierListEmptyFiltered =>
      'لا يوجد موردون مطابقون لعوامل التصفية.';

  @override
  String get supplierDeactivateConfirmTitle => 'إلغاء تنشيط المورّد';

  @override
  String get supplierDeactivateConfirmBody =>
      'سيتم إخفاء هذا المورّد من القائمة النشطة. يمكنك إيجاده بتغيير عامل تصفية الحالة. هل تريد المتابعة؟';

  @override
  String get supplierCreated => 'تم إنشاء المورّد.';

  @override
  String get supplierUpdated => 'تم حفظ المورّد.';

  @override
  String get supplierDeactivated => 'تم إلغاء تنشيط المورّد.';

  @override
  String get supplierFieldCode => 'الكود';

  @override
  String get supplierFieldNameAr => 'الاسم (عربي)';

  @override
  String get supplierFieldNameEn => 'الاسم (إنجليزي)';

  @override
  String get supplierFieldPhone => 'الهاتف';

  @override
  String get supplierFieldEmail => 'البريد الإلكتروني';

  @override
  String get supplierFieldTaxNumber => 'الرقم الضريبي';

  @override
  String get supplierFieldAddress => 'تفاصيل العنوان';

  @override
  String get supplierFieldGoogleMapsUrl => 'رابط خرائط Google';

  @override
  String get supplierFieldNotes => 'ملاحظات';

  @override
  String get supplierFieldCreateAccount => 'إنشاء حساب محاسبي';

  @override
  String get supplierFieldCreateAccountHint =>
      'يربط حسابًا فرعيًا للذمم الدائنة تحت حساب الدائنين.';

  @override
  String get supplierLinkedAccountYes => 'حساب محاسبي مرتبط';

  @override
  String get supplierLinkedAccountNo => 'لا يوجد حساب محاسبي';

  @override
  String get supplierEnsureAccount => 'إنشاء حساب محاسبي';

  @override
  String get supplierAccountLinked => 'تم ربط الحساب المحاسبي.';

  @override
  String get supplierSectionIdentity => 'الهوية';

  @override
  String get supplierSectionContact => 'التواصل';

  @override
  String get supplierSectionLocation => 'الموقع';

  @override
  String get supplierSectionAccounting => 'المحاسبة';

  @override
  String get supplierValidationNameArRequired => 'الاسم بالعربية مطلوب.';

  @override
  String get supplierValidationEmailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا.';

  @override
  String get supplierValidationFailed =>
      'تعذّر حفظ المورّد. يرجى مراجعة القيم.';

  @override
  String get supplierErrorPermissionDenied =>
      'لا تملك صلاحية تنفيذ هذا الإجراء.';

  @override
  String get supplierErrorAccountAlreadyLinked =>
      'هذا الملف مرتبط بحساب محاسبي بالفعل.';

  @override
  String get supplierErrorUnknown => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get customerLocations => 'المواقع';

  @override
  String get serviceLocationPrimary => 'أساسي';

  @override
  String get serviceLocationAdd => 'إضافة موقع';

  @override
  String get serviceLocationEdit => 'تعديل الموقع';

  @override
  String get serviceLocationDeactivate => 'تعطيل';

  @override
  String get serviceLocationSetPrimary => 'تعيين كموقع أساسي';

  @override
  String get serviceLocationEmpty => 'لا توجد مواقع خدمة بعد.';

  @override
  String get serviceLocationInUse =>
      'هذا الموقع ما زال مستخدمًا في عقد أو زيارة أو موعد تقويم أو جهاز.';

  @override
  String get serviceLocationPrimaryRequired =>
      'عيّن موقعًا نشطًا آخر كأساسي قبل تعطيل هذا الموقع.';

  @override
  String get serviceLocationValidationNameRequired => 'اسم الموقع مطلوب.';

  @override
  String get primaryLocationLabel => 'الموقع الأساسي';

  @override
  String get customerAddressBecomesPrimaryLocation =>
      'حقول العنوان تنشئ موقع خدمة أساسي لهذا العميل.';

  @override
  String get serviceLocationFieldName => 'اسم الموقع';

  @override
  String get serviceLocationFieldType => 'النوع';

  @override
  String get serviceLocationFieldContactName => 'اسم المسؤول';

  @override
  String get serviceLocationFieldContactPhone => 'هاتف المسؤول';

  @override
  String get serviceLocationFieldContactEmail => 'بريد المسؤول';

  @override
  String get serviceLocationFieldLatitude => 'خط العرض';

  @override
  String get serviceLocationFieldLongitude => 'خط الطول';

  @override
  String get serviceLocationCoordinatesSection => 'الإحداثيات';

  @override
  String get serviceLocationCoordinatesHint =>
      'الصق رابط Google Maps وسيتم استخراج الإحداثيات تلقائيًا دون إدخال يدوي.';

  @override
  String get googleMapsLinkResolutionHint =>
      'الصق رابط Google Maps لاستخراج الموقع تلقائيًا.';

  @override
  String get googleMapsResolveLink => 'استخراج الموقع';

  @override
  String googleMapsCoordinatesResolved(String latitude, String longitude) {
    return 'تم استخراج الموقع: $latitude، $longitude';
  }

  @override
  String get googleMapsLinkInvalid => 'أدخل رابط Google Maps صحيحًا.';

  @override
  String get googleMapsCoordinatesNotFound =>
      'تعذر استخراج الإحداثيات من رابط Google Maps هذا.';

  @override
  String get googleMapsResolutionFailed =>
      'تعذر تحليل رابط Google Maps. تحقق من الاتصال وحاول مجددًا.';

  @override
  String get serviceLocationUseCurrentLocation => 'استخدام الموقع الحالي';

  @override
  String get serviceLocationClearCoordinates => 'مسح الإحداثيات';

  @override
  String get serviceLocationCoordinatePairRequired =>
      'أدخل خط العرض وخط الطول معًا.';

  @override
  String get serviceLocationLatitudeInvalid =>
      'يجب أن يكون خط العرض بين -90 و90.';

  @override
  String get serviceLocationLongitudeInvalid =>
      'يجب أن يكون خط الطول بين -180 و180.';

  @override
  String get serviceLocationCoordinateMetadataInvalid =>
      'بيانات مصدر الإحداثيات أو دقتها غير صحيحة.';

  @override
  String get serviceLocationCoordinatesCaptured => 'تم التقاط الموقع الحالي.';

  @override
  String get serviceLocationCoordinateSource => 'المصدر';

  @override
  String get serviceLocationCoordinateSourceMapPick => 'اختيار من الخريطة';

  @override
  String get serviceLocationCoordinateSourceDeviceGps => 'موقع الجهاز';

  @override
  String get serviceLocationCoordinateSourceUrl => 'رابط خريطة محلول';

  @override
  String get serviceLocationCoordinateSourceManual => 'إدخال يدوي';

  @override
  String get serviceLocationCoordinateResolvedAt => 'وقت التحديد';

  @override
  String serviceLocationCoordinateAccuracy(String meters) {
    return 'الدقة: $meters م';
  }

  @override
  String get serviceLocationTypeBranch => 'فرع';

  @override
  String get serviceLocationTypeOffice => 'مكتب';

  @override
  String get serviceLocationTypeWarehouse => 'مستودع';

  @override
  String get serviceLocationTypeHome => 'منزل';

  @override
  String get serviceLocationTypeInstallationSite => 'موقع تركيب';

  @override
  String get serviceLocationTypeOther => 'أخرى';

  @override
  String get serviceLocationMapsCopied => 'تم نسخ رابط الخريطة.';

  @override
  String get serviceLocationOpenMaps => 'فتح رابط الخريطة';

  @override
  String get chartAccountSearchHint => 'ابحث بالكود أو الاسم';

  @override
  String get chartAccountFilterType => 'نوع الحساب';

  @override
  String get chartAccountFilterAllTypes => 'كل الأنواع';

  @override
  String get chartAccountFilterStatus => 'الحالة';

  @override
  String get chartAccountFilterAll => 'الكل';

  @override
  String get chartAccountStatusActive => 'نشط';

  @override
  String get chartAccountStatusInactive => 'غير نشط';

  @override
  String get chartAccountClearFilters => 'مسح عوامل التصفية';

  @override
  String get chartAccountTypeAsset => 'أصول';

  @override
  String get chartAccountTypeLiability => 'خصوم';

  @override
  String get chartAccountTypeEquity => 'حقوق ملكية';

  @override
  String get chartAccountTypeIncome => 'إيرادات';

  @override
  String get chartAccountTypeExpense => 'مصروفات';

  @override
  String get chartAccountBadgeSystem => 'نظام';

  @override
  String get chartAccountBadgeManual => 'يدوي';

  @override
  String get chartAccountBadgeCustomer => 'عميل';

  @override
  String get chartAccountBadgeSupplier => 'مورد';

  @override
  String get chartAccountBadgeInactive => 'غير نشط';

  @override
  String get chartAccountAdd => 'إضافة حساب';

  @override
  String get chartAccountEdit => 'تعديل حساب';

  @override
  String get chartAccountDeactivate => 'إلغاء التنشيط';

  @override
  String get chartAccountExpandAll => 'توسيع الكل';

  @override
  String get chartAccountCollapseAll => 'طي الكل';

  @override
  String get chartAccountExpand => 'توسيع';

  @override
  String get chartAccountCollapse => 'طي';

  @override
  String get chartAccountCreateTitle => 'حساب جديد';

  @override
  String get chartAccountEditTitle => 'تعديل حساب';

  @override
  String get chartAccountFieldCode => 'الكود';

  @override
  String get chartAccountFieldNameAr => 'الاسم (عربي)';

  @override
  String get chartAccountFieldNameEn => 'الاسم (إنجليزي)';

  @override
  String get chartAccountFieldType => 'النوع';

  @override
  String get chartAccountFieldParent => 'الحساب الأب';

  @override
  String get chartAccountParentNone => 'بدون (مستوى جذر)';

  @override
  String get chartAccountCodeReadOnlyHint =>
      'لا يمكن تغيير كود الحساب بعد الإنشاء.';

  @override
  String get chartAccountCreated => 'تم إنشاء الحساب.';

  @override
  String get chartAccountUpdated => 'تم حفظ الحساب.';

  @override
  String get chartAccountDeactivated => 'تم إلغاء تنشيط الحساب.';

  @override
  String get chartAccountListEmpty => 'لا توجد حسابات بعد.';

  @override
  String get chartAccountListEmptyFiltered =>
      'لا توجد حسابات مطابقة لعوامل التصفية.';

  @override
  String get chartAccountDeactivateConfirmTitle => 'إلغاء تنشيط الحساب';

  @override
  String get chartAccountDeactivateConfirmBody =>
      'سيتم وضع علامة غير نشط على هذا الحساب. هل تريد المتابعة؟';

  @override
  String get chartAccountSetupArMissing =>
      'حساب أب الذمم المدينة (1201) مفقود. قد لا تعمل حسابات العملاء الفرعية بشكل صحيح.';

  @override
  String get chartAccountSetupApMissing =>
      'حساب أب الذمم الدائنة (2101) مفقود. قد لا تعمل حسابات الموردين الفرعية بشكل صحيح.';

  @override
  String get chartAccountErrorPermissionDenied =>
      'لا تملك صلاحية لهذا الإجراء.';

  @override
  String get chartAccountErrorUnknown => 'حدث خطأ. يرجى المحاولة مرة أخرى.';

  @override
  String get chartAccountValidationFailed =>
      'يرجى مراجعة النموذج والمحاولة مرة أخرى.';

  @override
  String get chartAccountValidationCodeRequired => 'كود الحساب مطلوب.';

  @override
  String get chartAccountValidationNameArRequired => 'الاسم العربي مطلوب.';

  @override
  String get chartAccountValidationNameEnRequired => 'الاسم الإنجليزي مطلوب.';

  @override
  String get chartAccountErrorParentTypeMismatch =>
      'يجب أن يطابق نوع الحساب نوع الحساب الأب.';

  @override
  String get chartAccountErrorDuplicateCode => 'كود الحساب مستخدم بالفعل.';

  @override
  String get chartAccountErrorAccountProtected =>
      'هذا الحساب محمي ولا يمكن تعديله.';

  @override
  String get chartAccountErrorTypeChangeUnsafe =>
      'لا يمكن تغيير نوع الحساب طالما له حسابات فرعية أو قيود يومية.';

  @override
  String get chartAccountErrorHasActiveChildren =>
      'لا يمكن إلغاء تنشيط حساب له حسابات فرعية نشطة.';

  @override
  String get chartAccountErrorImmutableColumn => 'لا يمكن تغيير هذا الحقل.';

  @override
  String get scanInputLabel => 'مسح الباركود أو الرقم التسلسلي';

  @override
  String get scanMobileTitle => 'مسح الرمز';

  @override
  String get scanErrorAmbiguous => 'تم العثور على أكثر من تطابق لهذا الرمز.';

  @override
  String get scanErrorNotFound => 'لم يتم العثور على منتج أو وحدة مطابقة.';

  @override
  String get scanErrorPermissionDenied => 'لا تملك صلاحية مسح رموز المخزون.';

  @override
  String get scanErrorUnknown => 'فشل المسح. يرجى المحاولة مرة أخرى.';

  @override
  String get productUnitDetailTitle => 'تفاصيل الوحدة';

  @override
  String get productUnitDetailNotFound => 'لم يتم العثور على وحدة المنتج.';

  @override
  String get productUnitDetailNoBarcode => 'لا يوجد باركود';

  @override
  String get productUnitDetailLocation => 'الموقع الحالي';

  @override
  String get productUnitDetailLocationUnknown => 'لم يُحدَّد موقع';

  @override
  String get productUnitDetailMaintenanceCount => 'عدد الصيانات';

  @override
  String get productUnitSerialCorrectionTitle => 'تصحيح الرقم التسلسلي';

  @override
  String get productUnitSerialCorrectionNewSerial => 'الرقم التسلسلي الجديد';

  @override
  String get productUnitSerialCorrectionReason => 'سبب التصحيح';

  @override
  String get productUnitSerialCorrectionSubmit => 'حفظ تصحيح الرقم';

  @override
  String get productUnitSerialCorrectionSuccess => 'تم تحديث الرقم التسلسلي.';

  @override
  String get productUnitTimelineTitle => 'الجدول الزمني للوحدة';

  @override
  String get productUnitTimelineEmpty => 'لا توجد أحداث في الجدول الزمني بعد.';

  @override
  String get productUnitTimelineAcquisition => 'اكتساب الوحدة';

  @override
  String get productUnitTimelinePurchaseInvoice => 'فاتورة شراء';

  @override
  String get productUnitTimelineInventoryMovement => 'حركة مخزون';

  @override
  String get productUnitTimelineReconciled => 'مطابقة تسلسل';

  @override
  String get productUnitTimelineSerialCorrection => 'تصحيح تسلسل';

  @override
  String get documentPreviewTitle => 'معاينة المستند';

  @override
  String get documentPreviewAction => 'معاينة PDF';

  @override
  String get documentPreviewAssetLabel => 'طباعة ملصق الأصل';

  @override
  String get documentPreviewEmpty => 'لا يوجد مستند للمعاينة.';

  @override
  String get documentPreviewPermissionDenied =>
      'لا تملك صلاحية معاينة هذا المستند.';

  @override
  String get documentErrorUnknown =>
      'تعذر إنشاء المستند. يرجى المحاولة مرة أخرى.';

  @override
  String get documentErrorNoTemplate => 'لم يتم إعداد قالب مستند افتراضي.';

  @override
  String get documentErrorStatementDateRange =>
      'نطاق تاريخ كشف الحساب غير صالح.';

  @override
  String get documentErrorStatementTooLarge =>
      'كشف الحساب يحتوي على عدد كبير جداً من الصفوف للطباعة.';

  @override
  String get documentErrorUnsupportedType => 'نوع المستند هذا غير مدعوم بعد.';

  @override
  String get documentErrorThermalTooLarge =>
      'المحتوى كبير جداً للطباعة الحرارية.';

  @override
  String get documentErrorFontLoad => 'تعذر تحميل خطوط المستند.';

  @override
  String get documentErrorValidation => 'إعدادات المستند غير صالحة.';

  @override
  String get documentErrorTenantNotFound => 'لم يتم العثور على سياق المستأجر.';

  @override
  String get documentErrorNotConfigured => 'خدمة المستندات غير مهيأة.';

  @override
  String get documentErrorLogoInvalidUrl => 'يجب أن يستخدم رابط الشعار HTTPS.';

  @override
  String get documentErrorLogoTooLarge =>
      'ملف الشعار كبير جداً (الحد الأقصى 512 كيلوبايت).';

  @override
  String get documentErrorLogoInvalidDimensions =>
      'أبعاد الشعار كبيرة جداً (الحد الأقصى 4096 بكسل لكل جانب، و16 ميجابكسل إجمالاً).';

  @override
  String get documentErrorLogoUnsupportedFormat =>
      'يجب أن يكون الشعار بصيغة PNG أو JPEG.';

  @override
  String get documentErrorLogoFetchFailed =>
      'تعذر تنزيل الشعار. تحقق من الرابط وحاول مرة أخرى.';

  @override
  String get customerStatementFromDate => 'من';

  @override
  String get customerStatementToDate => 'إلى';

  @override
  String get templateSettingsTitle => 'قوالب المستندات';

  @override
  String get templateSettingsPermissionDenied =>
      'لا تملك صلاحية عرض إعدادات القوالب.';

  @override
  String get templateSettingsLogoUrl => 'رابط الشعار (HTTPS)';

  @override
  String get templateSettingsPrimaryColor => 'اللون الأساسي (#RRGGBB)';

  @override
  String get templateSettingsSecondaryColor => 'اللون الثانوي (#RRGGBB)';

  @override
  String get templateSettingsDefaultLanguage => 'اللغة الافتراضية للمستند';

  @override
  String get templateSettingsInvoicePaper => 'ورق الفاتورة';

  @override
  String get templateSettingsAssetLabelPaper => 'ورق ملصق الأصل';

  @override
  String get templateSettingsVoucherPaper => 'ورق السند';

  @override
  String get templateSettingsHeaderSection => 'ترويسة المستند';

  @override
  String get templateSettingsHeaderAr => 'نص الترويسة (عربي)';

  @override
  String get templateSettingsHeaderEn => 'نص الترويسة (إنجليزي)';

  @override
  String get templateSettingsFooterSection => 'تذييل المستند';

  @override
  String get templateSettingsFooterAr => 'نص التذييل (عربي)';

  @override
  String get templateSettingsFooterEn => 'نص التذييل (إنجليزي)';

  @override
  String get templateSettingsOptionalColumnsSection => 'أعمدة اختيارية';

  @override
  String get templateSettingsOptionalSalesInvoice => 'فاتورة مبيعات';

  @override
  String get templateSettingsOptionalPurchaseInvoice => 'فاتورة مشتريات';

  @override
  String get templateSettingsOptionalCustomerStatement => 'كشف حساب عميل';

  @override
  String get templateSettingsOptionalQty => 'إظهار الكمية';

  @override
  String get templateSettingsOptionalUnitPrice => 'إظهار سعر الوحدة';

  @override
  String get templateSettingsOptionalDebit => 'إظهار المدين';

  @override
  String get templateSettingsOptionalCredit => 'إظهار الدائن';

  @override
  String get templateSettingsLanguageAr => 'العربية';

  @override
  String get templateSettingsLanguageEn => 'English';

  @override
  String get templateSettingsLanguageBilingual => 'ثنائي اللغة';

  @override
  String get templateSettingsPaperA4 => 'A4';

  @override
  String get templateSettingsPaperThermal => 'حراري 80mm';

  @override
  String get templateSettingsPaperLabel => 'ورق ملصقات';

  @override
  String get templateSettingsSaved => 'تم حفظ إعدادات المستند.';

  @override
  String get templateSettingsSave => 'حفظ الإعدادات';
}
