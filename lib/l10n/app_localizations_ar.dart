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
      'مفتاح Supabase المحلي غير مضبوط. شغّل التطبيق عبر سكربت التشغيل المحلي المناسب';

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
  String get productSerialTrackingPrepare => 'تجهيز الترقيم';

  @override
  String get productSerialTrackingPrefix => 'بادئة الرقم';

  @override
  String get productSerialTrackingStart => 'رقم البداية';

  @override
  String get productSerialTrackingCount => 'الكمية المتاحة';

  @override
  String get productSerialTrackingGenerate => 'إنشاء الأرقام';

  @override
  String get productSerialTrackingSerials => 'الأرقام التسلسلية';

  @override
  String get productSerialTrackingReason => 'السبب';

  @override
  String get productSerialTrackingConfirm => 'تفعيل التتبع';

  @override
  String get productSerialTrackingPrepared =>
      'تم تجهيز تتبع الأرقام التسلسلية.';

  @override
  String get productSerialTrackingValidation =>
      'اختر المستودع وأنشئ أرقامًا بعدد الكمية المتاحة تمامًا وأدخل السبب.';

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
  String get customerContractsPrepared =>
      'ستظهر عقود هذا العميل هنا عند توفرها.';

  @override
  String get customerContractsNotLoaded => 'افتح هذا التبويب لتحميل العقود.';

  @override
  String get contractTitle => 'العقود';

  @override
  String get contractDetailTitle => 'العقد';

  @override
  String get contractPreviewAction => 'معاينة عقد PDF';

  @override
  String get pdfDraftWatermark => 'مسودة';

  @override
  String get contractCreateTitle => 'عقد جديد';

  @override
  String get contractConvertTitle => 'تحويل العقد التجريبي';

  @override
  String get contractListPrepared => 'ستظهر قائمة العقود هنا عند توفرها.';

  @override
  String get contractCreatePrepared => 'سيفتح إنشاء العقد هنا عند الجاهزية.';

  @override
  String get contractDetailPrepared => 'ستظهر تفاصيل العقد هنا عند توفرها.';

  @override
  String get contractConvertPrepared =>
      'سيفتح تحويل العقد التجريبي هنا عند الجاهزية.';

  @override
  String get contractCreateNew => 'عقد جديد';

  @override
  String get contractViewAll => 'كل العقود';

  @override
  String get contractTypeTrial => 'تجريبي';

  @override
  String get contractTypeRental => 'إيجار';

  @override
  String get contractStatusDraft => 'مسودة';

  @override
  String get contractStatusActive => 'نشط';

  @override
  String get contractStatusSuspended => 'موقوف';

  @override
  String get contractStatusCompleted => 'مكتمل';

  @override
  String get contractStatusTerminatedEarly => 'منتهٍ مبكرًا';

  @override
  String get contractStatusExpired => 'منتهٍ';

  @override
  String get contractColumnNumber => 'رقم العقد';

  @override
  String get contractColumnType => 'النوع';

  @override
  String get contractColumnStatus => 'الحالة';

  @override
  String get contractColumnStartDate => 'تاريخ البدء';

  @override
  String get contractColumnDates => 'التواريخ';

  @override
  String get contractColumnMonthlyValue => 'القيمة الشهرية';

  @override
  String get contractColumnCustomer => 'العميل';

  @override
  String get contractColumnServiceLocation => 'موقع الخدمة';

  @override
  String get contractListEmpty => 'لا توجد عقود بعد.';

  @override
  String get contractListEmptyFiltered => 'لا توجد عقود مطابقة لعوامل التصفية.';

  @override
  String get contractFilterType => 'النوع';

  @override
  String get contractFilterSearchHint =>
      'ابحث برقم العقد أو العميل أو الهاتف أو المحافظة أو المنطقة';

  @override
  String get contractFilterLowProfitOverride => 'تجاوز الحد الأدنى للربح فقط';

  @override
  String get contractSectionOverview => 'نظرة عامة';

  @override
  String get contractSectionAssets => 'الأجهزة';

  @override
  String get contractSectionConsumables => 'المستهلكات';

  @override
  String get contractSectionLifecycle => 'دورة الحياة';

  @override
  String get contractSectionPricingSnapshot => 'لقطة التسعير';

  @override
  String get contractFieldEndDate => 'تاريخ الانتهاء';

  @override
  String get contractFieldTrialEndDate => 'نهاية التجربة';

  @override
  String get contractFieldBillingDay => 'يوم الفوترة';

  @override
  String get contractFieldRefillDay => 'يوم التعبئة';

  @override
  String get contractFieldNotes => 'ملاحظات';

  @override
  String get contractFieldSerialNumber => 'الرقم التسلسلي';

  @override
  String get contractFieldProduct => 'المنتج';

  @override
  String get contractFieldQtyPerRefill => 'الكمية لكل تعبئة';

  @override
  String get contractFieldRefillFrequency => 'تكرار التعبئة (أشهر)';

  @override
  String get contractFieldMonthlyCost => 'التكلفة الشهرية';

  @override
  String get contractFieldUnitCost => 'تكلفة الوحدة';

  @override
  String get contractFieldDeviceMonthlyCost => 'تكلفة الجهاز الشهرية';

  @override
  String get contractFieldOilMonthlyCost => 'تكلفة المستهلك الشهرية';

  @override
  String get contractFieldTotalMonthlyCost => 'إجمالي التكلفة الشهرية';

  @override
  String get contractFieldMonthlyProfit => 'الربح الشهري';

  @override
  String get contractFieldNetMonthlyProfit => 'صافي الربح الشهري';

  @override
  String get contractFieldConvertedFrom => 'محوّل من';

  @override
  String get contractFieldConvertedTo => 'محوّل إلى';

  @override
  String get contractFieldReturnReason => 'سبب الإرجاع';

  @override
  String get contractFieldClosureReason => 'سبب الإغلاق';

  @override
  String get contractFieldOverrideReason => 'سبب التجاوز';

  @override
  String get contractAssetsEmpty => 'لا توجد بنود أجهزة في هذا العقد.';

  @override
  String get contractConsumablesEmpty => 'لا توجد بنود مستهلكات في هذا العقد.';

  @override
  String get contractLifecycleEmpty => 'لا توجد بيانات دورة حياة مسجلة بعد.';

  @override
  String get contractSectionProducts => 'المنتجات';

  @override
  String get contractSectionValueSummary => 'قيمة العقد';

  @override
  String get contractFinancialDetails => 'التكلفة والربحية';

  @override
  String get contractSectionUpcomingSchedule => 'المواعيد القادمة';

  @override
  String get contractSectionHistory => 'السجل';

  @override
  String get contractFieldProductType => 'النوع';

  @override
  String get contractFieldQuantity => 'الكمية';

  @override
  String get contractFieldFrequency => 'التكرار';

  @override
  String get contractFieldContractDuration => 'المدة';

  @override
  String contractDurationMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months أشهر',
      one: 'شهر واحد',
    );
    return '$_temp0';
  }

  @override
  String get contractFieldTotalContractValue => 'إجمالي قيمة العقد';

  @override
  String get contractFieldMonthlyRentalValue => 'قيمة الإيجار الشهرية';

  @override
  String get contractNextVisit => 'الزيارة القادمة';

  @override
  String get contractNextPayment => 'الدفعة القادمة';

  @override
  String contractRemainingDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متبقي $days أيام',
      one: 'متبقي يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String contractRemainingDaysOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days أيام',
      one: 'يوم واحد',
    );
    return '-$_temp0';
  }

  @override
  String get contractOverdue => 'متأخر';

  @override
  String get contractProductsEmpty => 'لا توجد منتجات في هذا العقد.';

  @override
  String get contractScheduleEmpty => 'لا توجد زيارات أو دفعات قادمة بعد.';

  @override
  String get contractScheduleEventTrialEnding => 'انتهاء التجريبي';

  @override
  String get contractScheduleEventBillingDue => 'استحقاق الفوترة';

  @override
  String get contractScheduleEventRefillDue => 'استحقاق التعبئة';

  @override
  String get contractScheduleEventContractEnd => 'انتهاء العقد';

  @override
  String get contractScheduleEventConsumableChange => 'يتضمن تغيير مستهلكات';

  @override
  String get contractScheduleRemaining => 'المتبقي';

  @override
  String get contractHistoryEmpty => 'لا يوجد سجل للعقد بعد.';

  @override
  String get contractProductTypeAsset => 'جهاز';

  @override
  String get contractProductTypeConsumable => 'مستهلك';

  @override
  String get contractConvertLink => 'تحويل إلى إيجار';

  @override
  String get contractConvertAction => 'تحويل إلى إيجار';

  @override
  String get contractConvertConfirmTitle => 'تحويل التجريبي';

  @override
  String get contractConvertConfirmBody =>
      'تحويل هذا العقد التجريبي إلى عقد إيجار بالشروط المدخلة؟';

  @override
  String get contractExtendTrialTitle => 'تمديد التجريبي';

  @override
  String get contractExtendTrialAction => 'تمديد التجريبي';

  @override
  String get contractReturnTrialTitle => 'إرجاع التجريبي';

  @override
  String get contractReturnTrialAction => 'إرجاع التجريبي';

  @override
  String get contractCloseRentalTitle => 'إغلاق الإيجار';

  @override
  String get contractCloseRentalAction => 'إغلاق الإيجار';

  @override
  String get contractFieldExtensionReason => 'سبب التمديد';

  @override
  String get contractFieldChangeReason => 'سبب التغيير';

  @override
  String get contractFieldEffectiveDate => 'تاريخ السريان';

  @override
  String get contractFieldConversionStartDate => 'تاريخ بدء التحويل';

  @override
  String get contractFieldCloseDate => 'تاريخ الإغلاق';

  @override
  String get contractFieldClosedAt => 'أُغلق في';

  @override
  String get contractFieldReturnedAt => 'أُرجع في';

  @override
  String get contractFieldReturnCondition => 'حالة الإرجاع';

  @override
  String get contractFieldClosureType => 'نوع الإغلاق';

  @override
  String get contractClosureTypeNormal => 'إكمال عادي';

  @override
  String get contractClosureTypeEarlyTermination => 'إنهاء مبكر';

  @override
  String get contractReturnConditionAvailableUsed => 'متاح (مستخدم)';

  @override
  String get contractReturnConditionMaintenance => 'صيانة';

  @override
  String get contractReturnConditionDamaged => 'تالف';

  @override
  String get contractReturnConditionLost => 'مفقود';

  @override
  String get contractErrorManualWarehouseResolutionRequired =>
      'يتطلب هذا السطر تحديد المستودع يدوياً قبل الإرجاع.';

  @override
  String get contractErrorConsumableScheduleConflict =>
      'يوجد بالفعل تغيير مستهلكات مجدول لهذا السطر.';

  @override
  String get contractConsumableCurrent => 'المستهلك الحالي';

  @override
  String contractConsumableScheduledBanner(String date) {
    return 'يوجد تغيير مستهلكات مجدول بتاريخ $date.';
  }

  @override
  String get contractScheduleConsumableAction => 'جدولة تغيير المستهلك';

  @override
  String get contractCollectRentalAction => 'تحصيل إيجار';

  @override
  String get contractCollectRentalTitle => 'تحصيل دفعة إيجار';

  @override
  String get contractCollectCoverageMonths => 'أشهر التغطية';

  @override
  String get contractCollectCollectionDate => 'تاريخ التحصيل';

  @override
  String get contractCollectPaymentMethod => 'طريقة الدفع';

  @override
  String get contractCollectCashAccount => 'حساب النقد/البنك';

  @override
  String get contractCollectReferenceNo => 'المرجع';

  @override
  String get contractCollectExpectedAmount => 'المبلغ المتوقع تحصيله';

  @override
  String get contractCollectPreviewSubtotal => 'المجموع الفرعي';

  @override
  String get contractCollectPreviewTax => 'الضريبة';

  @override
  String get contractCollectPreviewTotal => 'إجمالي الفاتورة';

  @override
  String get contractCollectConfirmAction => 'تأكيد التحصيل';

  @override
  String get contractCollectViewInvoice => 'عرض الفاتورة';

  @override
  String get contractCollectViewReceipt => 'عرض سند القبض';

  @override
  String get contractCollectSuccess => 'تم تحصيل دفعة الإيجار بنجاح.';

  @override
  String get contractCollectNoEligibleMonths =>
      'لا توجد أشهر تغطية مؤهلة متبقية لهذا العقد.';

  @override
  String get contractCollectCashAccountsUnavailable =>
      'حسابات النقد/البنك غير متاحة لهذه الجلسة.';

  @override
  String get contractCreateTrial => 'إنشاء عقد تجريبي';

  @override
  String get contractCreateRental => 'إنشاء عقد إيجار';

  @override
  String get contractCreateConfirmTitle => 'إنشاء العقد';

  @override
  String get contractCreateConfirmBody =>
      'إنشاء هذا العقد بالبنود والشروط المدخلة؟';

  @override
  String get contractAddRentalProduct => 'إضافة منتج تأجير';

  @override
  String get contractAddAssetLine => 'إضافة جهاز';

  @override
  String get contractAddConsumableLine => 'إضافة مستهلكات';

  @override
  String get contractRemoveLine => 'حذف السطر';

  @override
  String get contractSerialOrBarcode => 'رقم تسلسلي أو باركود';

  @override
  String get contractResolveSerial => 'تحقق من الرقم/الباركود';

  @override
  String get contractTrialDaysLabel => 'أيام التجربة';

  @override
  String get contractTermTwelveMonths => 'مدة 12 شهرًا';

  @override
  String get contractLowProfitWarning =>
      'الربح الشهري أقل من الحد الأدنى المسموح.';

  @override
  String get contractRequestOverride => 'طلب تجاوز الربح';

  @override
  String get contractRefreshPreview => 'تحديث معاينة التسعير';

  @override
  String get contractCustomerSelectFirst => 'اختر العميل أولًا.';

  @override
  String get contractSelectProductFirst => 'اختر المنتج أولًا.';

  @override
  String get contractNoAvailableUnits => 'لا توجد وحدات متاحة لهذا المنتج.';

  @override
  String get customerInvoicesEmpty => 'لا توجد فواتير بعد.';

  @override
  String get customerInvoicesNotLoaded => 'افتح هذا التبويب لتحميل الفواتير.';

  @override
  String get customerVouchersEmpty => 'لا توجد سندات بعد.';

  @override
  String get customerVouchersNotLoaded =>
      'افتح هذا التبويب لتحميل سندات القبض.';

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
  String get supplierNotFound => 'المورد غير موجود.';

  @override
  String get supplierPurchaseInvoices => 'فواتير الشراء';

  @override
  String get supplierPaymentVouchers => 'سندات الدفع';

  @override
  String get supplierStatement => 'كشف الحساب';

  @override
  String get supplierStatementUnavailable =>
      'كشف حساب المورد يتطلب دعمًا من الخادم (get_supplier_statement). سيتوفر في إصدار لاحق.';

  @override
  String get supplierInvoicesEmpty => 'لا توجد فواتير شراء بعد.';

  @override
  String get supplierInvoicesNotLoaded =>
      'افتح هذا التبويب لتحميل فواتير الشراء.';

  @override
  String get supplierVouchersEmpty => 'لا توجد سندات دفع بعد.';

  @override
  String get supplierVouchersNotLoaded =>
      'افتح هذا التبويب لتحميل سندات الدفع.';

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

  @override
  String get navInvoices => 'الفواتير';

  @override
  String get navContracts => 'العقود';

  @override
  String get navVouchers => 'السندات';

  @override
  String get navJournal => 'اليومية';

  @override
  String get navCashBank => 'النقد والبنوك';

  @override
  String get financePlaceholderM9Body =>
      'شاشات العمل الكاملة ستتوفر في المرحلة التالية.';

  @override
  String get financeModuleAccessUnavailable =>
      'لا تملك صلاحية عرض هذا القسم المالي.';

  @override
  String get financeErrorTenantNotFound => 'لم يتم العثور على سياق المستأجر.';

  @override
  String get financeErrorPermissionDenied =>
      'لا تملك صلاحية لهذا الإجراء المالي.';

  @override
  String get financeErrorValidationFailed =>
      'بيانات المالية غير صالحة. راجع النموذج وحاول مجددًا.';

  @override
  String get financeErrorBelowMinProfit =>
      'الربح الشهري أقل من الحد الأدنى المسموح. عدّل التسعير أو اطلب تجاوزًا مصرحًا به.';

  @override
  String get financeErrorIdempotencyPayloadMismatch =>
      'يتعارض هذا الطلب مع إرسال سابق. ابدأ من جديد.';

  @override
  String get financeErrorBooksLocked => 'الدفاتر المحاسبية مقفلة لهذا التاريخ.';

  @override
  String get financeErrorDuplicateSerial => 'تم اكتشاف رقم تسلسلي مكرر.';

  @override
  String get financeErrorCrossTenantReference => 'مرجع عبر مستأجرين غير مسموح.';

  @override
  String get financeErrorTaxRateNotFound =>
      'لم يتم العثور على نسبة الضريبة المحددة.';

  @override
  String get financeErrorTaxRateInUse =>
      'نسبة الضريبة هذه مستخدمة ولا يمكن تغييرها.';

  @override
  String get financeErrorNotFound => 'لم يتم العثور على السجل المالي.';

  @override
  String get financeErrorNotAvailable => 'هذه الميزة المالية غير متاحة بعد.';

  @override
  String get financeErrorCorrectionDocumentRequired =>
      'الإلغاء الآمن غير متاح. يلزم مستند تصحيح.';

  @override
  String get financeErrorUnknown => 'حدث خطأ مالي. يرجى المحاولة مرة أخرى.';

  @override
  String get financeValidationNotesRequired => 'الملاحظات مطلوبة.';

  @override
  String get financeValidationGainReasonRequired => 'سبب الزيادة مطلوب.';

  @override
  String get financeValidationLossReasonRequired => 'سبب النقص مطلوب.';

  @override
  String get financeValidationSerializedQtyIntegerRequired =>
      'كمية المنتج المُسلسل يجب أن تكون عدداً صحيحاً موجباً.';

  @override
  String get financeErrorReturnDocumentRequired =>
      'تتطلب هذه العملية مستند مرتجع.';

  @override
  String get financeErrorSerializedAdjustmentNotSupported =>
      'تسويات المنتجات المُسلسلة غير مدعومة بعد.';

  @override
  String get financeErrorBackendMigrationRequired =>
      'تحتاج هذه الفاتورة إلى تحديث قاعدة البيانات قبل التأكيد.';

  @override
  String financeErrorUnknownWithCode(String code) {
    return 'حدث خطأ مالي غير متوقع. يرجى المحاولة مرة أخرى. (الرمز: $code)';
  }

  @override
  String get financeValidationCustomerRequired => 'اختر عميلاً لهذه الفاتورة.';

  @override
  String get financeValidationSupplierRequired => 'اختر مورّداً لهذه الفاتورة.';

  @override
  String get financeValidationWarehouseRequired => 'اختر المخزن.';

  @override
  String get financeValidationPartyRequired => 'اختر عميلاً أو مورّداً.';

  @override
  String get financeValidationLinesRequired => 'أضف بنداً واحداً على الأقل.';

  @override
  String get financeValidationProductRequired => 'اختر منتجاً لكل بند.';

  @override
  String get financeValidationLineQtyInvalid =>
      'يجب أن تكون الكمية أكبر من صفر.';

  @override
  String get financeValidationLinePriceInvalid =>
      'لا يمكن أن يكون سعر الوحدة سالباً.';

  @override
  String get financeValidationDiscountOutOfRange =>
      'يجب أن يكون الخصم بين 0 و100 بالمئة.';

  @override
  String get financeValidationDueDateBeforeInvoiceDate =>
      'لا يمكن أن يكون تاريخ الاستحقاق قبل تاريخ الفاتورة.';

  @override
  String get financeValidationSerializedUnitRequired =>
      'اختر الرقم التسلسلي/الوحدة للمنتجات المُسلسلة.';

  @override
  String get financeValidationSerialCountMismatch =>
      'يجب أن يطابق عدد الأرقام التسلسلية كمية البند.';

  @override
  String get financeValidationOriginalInvoiceRequired =>
      'اختر الفاتورة الأصلية المراد الإرجاع منها.';

  @override
  String get financeValidationReturnReasonRequired => 'أدخل سبب الإرجاع.';

  @override
  String get financeValidationReturnQtyExceedsReturnable =>
      'كمية الإرجاع تتجاوز الكمية القابلة للإرجاع.';

  @override
  String get financeValidationCashAccountRequired => 'اختر حساب نقدية أو بنك.';

  @override
  String get financeValidationAccountRequired => 'اختر حساباً مالياً.';

  @override
  String get financeValidationCancellationReasonRequired => 'أدخل سبب الإلغاء.';

  @override
  String get financeValidationCancellationReasonTooLong =>
      'سبب الإلغاء طويل جداً.';

  @override
  String get journalSourceSalesReturn => 'مرتجع مبيعات';

  @override
  String get journalSourcePurchaseReturn => 'مرتجع مشتريات';

  @override
  String get journalSourceSalesReturnReversal => 'عكس مرتجع مبيعات';

  @override
  String get journalSourcePurchaseReturnReversal => 'عكس مرتجع مششتريات';

  @override
  String get journalSourceCustomerRefundVoucher => 'سند استرداد عميل';

  @override
  String get journalSourceSupplierRefundReceipt => 'سند استرداد مورد';

  @override
  String get journalSourceSalesInvoiceReversal => 'عكس فاتورة مبيعات';

  @override
  String get journalSourcePurchaseInvoiceReversal => 'عكس فاتورة مشتريات';

  @override
  String get journalSourceReceiptVoucherReversal => 'عكس سند قبض';

  @override
  String get journalSourcePaymentVoucherReversal => 'عكس سند صرف';

  @override
  String get journalSourceOpeningStock => 'رصيد افتتاحي مخزون';

  @override
  String get journalSourceInventoryStockIn => 'إدخال مخزون';

  @override
  String get journalSourceInventoryStockOut => 'إخراج مخزون';

  @override
  String get journalSourceStockCount => 'جرد مخزون';

  @override
  String get journalSourceInventoryDocumentReversal => 'عكس مستند مخزون';

  @override
  String get cashBankChartViewRequiredTitle => 'صلاحية شجرة الحسابات مطلوبة';

  @override
  String get cashBankChartViewRequiredBody =>
      'لاختيار حساب نقدي أو بنكي تحتاج صلاحية عرض شجرة الحسابات. اطلبها من المسؤول.';

  @override
  String get invoiceTitle => 'الفواتير';

  @override
  String get invoiceNewSales => 'فاتورة مبيعات جديدة';

  @override
  String get invoiceNewPurchase => 'فاتورة مشتريات جديدة';

  @override
  String get invoiceDetailTitle => 'تفاصيل الفاتورة';

  @override
  String get invoiceReturnTitle => 'فاتورة مرتجع';

  @override
  String get invoiceTypeSales => 'مبيعات';

  @override
  String get invoiceTypePurchase => 'مشتريات';

  @override
  String get invoiceTypeSalesReturn => 'مرتجع مبيعات';

  @override
  String get invoiceTypePurchaseReturn => 'مرتجع مشتريات';

  @override
  String get invoiceStatusDraft => 'مسودة';

  @override
  String get invoiceStatusConfirmed => 'مؤكدة';

  @override
  String get invoiceStatusPartiallyPaid => 'مدفوعة جزئيًا';

  @override
  String get invoiceStatusPaid => 'مدفوعة';

  @override
  String get invoiceStatusCancelled => 'ملغاة';

  @override
  String get invoiceFilterType => 'النوع';

  @override
  String get invoiceFilterSearch => 'بحث';

  @override
  String get invoiceColumnNumber => 'الرقم';

  @override
  String get invoiceColumnParty => 'الطرف';

  @override
  String get invoiceColumnDate => 'التاريخ';

  @override
  String get invoiceColumnDueDate => 'تاريخ الاستحقاق';

  @override
  String get invoiceColumnTotal => 'الإجمالي';

  @override
  String get invoiceColumnPaid => 'المدفوع';

  @override
  String get invoiceColumnOutstanding => 'المتبقي';

  @override
  String get invoiceOverdueBadge => 'متأخر';

  @override
  String get invoiceListEmpty => 'لا توجد فواتير بعد.';

  @override
  String get invoiceListEmptyFiltered => 'لا توجد فواتير تطابق الفلاتر.';

  @override
  String get invoiceDetailLines => 'البنود';

  @override
  String get invoicePaymentSummary => 'ملخص الدفع';

  @override
  String get invoiceActionCancel => 'إلغاء الفاتورة';

  @override
  String get invoiceActionReturn => 'إنشاء مرتجع';

  @override
  String get invoiceActionEditDraft => 'تعديل المسودة';

  @override
  String get invoiceActionConfirmDraft => 'تأكيد المسودة';

  @override
  String get invoiceCancelReason => 'سبب الإلغاء';

  @override
  String get invoiceConfirmCancel => 'إلغاء هذه الفاتورة؟';

  @override
  String get invoiceJournalEntry => 'قيد اليومية';

  @override
  String get invoiceTotalsSubtotal => 'المجموع الفرعي';

  @override
  String get invoiceTotalsDiscount => 'الخصم';

  @override
  String get invoiceTotalsTax => 'الضريبة';

  @override
  String get invoiceTotalsTotal => 'الإجمالي';

  @override
  String get invoiceCreditAllocations => 'تخصيصات الرصيد';

  @override
  String get invoiceReturnNotEligible => 'لا يمكن إرجاع هذه الفاتورة.';

  @override
  String get invoiceCreateSales => 'مبيعات جديدة';

  @override
  String get invoiceCreatePurchase => 'شراء جديد';

  @override
  String get invoiceCreateNew => 'إضافة';

  @override
  String get invoiceCreateReturnHint => 'من فاتورة';

  @override
  String get invoiceFormWarehouse => 'المستودع';

  @override
  String get invoiceFormDate => 'تاريخ الفاتورة';

  @override
  String get invoiceFormDueDate => 'تاريخ الاستحقاق';

  @override
  String get invoiceFormNotes => 'ملاحظات';

  @override
  String get invoiceFormNumberAuto => 'رقم الفاتورة: تلقائي بعد التأكيد';

  @override
  String get invoicePaymentTermsTitle => 'طريقة السداد';

  @override
  String get invoicePaymentTermsCash => 'نقدي / فوري';

  @override
  String get invoicePaymentTermsCredit => 'آجل';

  @override
  String get invoicePaymentTermsCashHelper =>
      'سيتم تسجيل الدفع لاحقًا من السندات.';

  @override
  String get invoicePaymentTermsCashHelperSales =>
      'سيتم إنشاء/تسجيل سند قبض بعد تأكيد الفاتورة.';

  @override
  String get invoicePaymentTermsCashHelperPurchase =>
      'سيتم إنشاء/تسجيل سند صرف بعد تأكيد الفاتورة.';

  @override
  String get invoiceFormNewCustomer => '+ عميل جديد';

  @override
  String get invoicePickOriginalInvoiceTitle => 'اختيار الفاتورة الأصلية';

  @override
  String get invoicePickOriginalInvoiceSearch => 'بحث برقم الفاتورة أو الطرف';

  @override
  String get invoicePickOriginalInvoiceEmpty =>
      'لا توجد فواتير مؤكدة قابلة للإرجاع.';

  @override
  String get invoiceFormCustomer => 'العميل';

  @override
  String get invoiceFormSupplier => 'المورد';

  @override
  String get invoiceFormAddLine => 'إضافة سطر';

  @override
  String get invoiceFormSaveDraft => 'حفظ المسودة';

  @override
  String get invoiceFormConfirm => 'تأكيد الفاتورة';

  @override
  String get invoiceFormDiscardDraft => 'حذف المسودة';

  @override
  String get invoiceFormSelectProduct => 'المنتج';

  @override
  String get invoiceFormQty => 'الكمية';

  @override
  String get invoiceFormUnitPrice => 'سعر الوحدة';

  @override
  String get invoiceFormDiscount => 'نسبة الخصم';

  @override
  String get invoiceFormSerialNumber => 'الرقم التسلسلي';

  @override
  String get invoiceFormDiscard => 'إلغاء';

  @override
  String get invoiceColumnUnit => 'الوحدة';

  @override
  String get invoiceColumnDescription => 'الوصف';

  @override
  String get invoiceColumnLineTotal => 'إجمالي السطر';

  @override
  String get invoiceColumnActions => 'إجراءات';

  @override
  String get invoiceFormConfirmMessage =>
      'تأكيد وترحيل هذه الفاتورة؟ يتم احتساب الإجماليات على الخادم.';

  @override
  String get invoiceEstimatedTotalsDisclaimer =>
      'إجماليات تقديرية فقط. الضريبة والإجمالي النهائيان يُحسبان عند التأكيد.';

  @override
  String get invoiceEstimatedCreditPreview => 'معاينة الرصيد التقديري';

  @override
  String get invoiceFinalTotalsAfterConfirm =>
      'يتم احتساب الإجماليات النهائية بعد التأكيد.';

  @override
  String get invoiceReturnReason => 'سبب المرتجع';

  @override
  String get invoiceReturnSubmit => 'إرسال المرتجع';

  @override
  String get voucherTitle => 'السندات';

  @override
  String get voucherNewReceipt => 'سند قبض جديد';

  @override
  String get voucherNewPayment => 'سند صرف جديد';

  @override
  String get voucherDetailTitle => 'تفاصيل السند';

  @override
  String get voucherTypeReceipt => 'قبض';

  @override
  String get voucherTypePayment => 'صرف';

  @override
  String get voucherStatusConfirmed => 'مؤكد';

  @override
  String get voucherStatusCancelled => 'ملغى';

  @override
  String get voucherAllocationFifo => 'تطبيق على أقدم الفواتير أولاً';

  @override
  String get voucherAllocationManual => 'توزيع يدوي';

  @override
  String get voucherPaymentDestinationSupplier => 'دفع للمورد';

  @override
  String get voucherPaymentDestinationAccount => 'دفع لحساب';

  @override
  String get voucherOpenInvoices => 'الفواتير المفتوحة';

  @override
  String get voucherSelectCashAccount => 'حساب نقدي أو بنكي';

  @override
  String get voucherFormSubmit => 'تسجيل السند';

  @override
  String get voucherFormSubmitSuccess => 'تم تسجيل السند.';

  @override
  String get voucherFormPaymentMethod => 'طريقة الدفع';

  @override
  String get voucherListEmpty => 'لا توجد سندات بعد.';

  @override
  String get voucherListEmptyFiltered => 'لا توجد سندات مطابقة للفلاتر.';

  @override
  String get voucherFilterType => 'النوع';

  @override
  String get voucherFilterSearch => 'بحث';

  @override
  String get voucherCreateReceipt => 'سند قبض جديد';

  @override
  String get voucherCreatePayment => 'سند صرف جديد';

  @override
  String get voucherColumnNumber => 'الرقم';

  @override
  String get voucherFormCustomer => 'العميل';

  @override
  String get voucherFormSupplier => 'المورد';

  @override
  String get voucherFormCashAccount => 'حساب النقد';

  @override
  String get voucherFormReference => 'المرجع';

  @override
  String get voucherFormNotes => 'ملاحظات';

  @override
  String get voucherFormAmount => 'المبلغ';

  @override
  String get voucherFormDate => 'التاريخ';

  @override
  String get voucherAllocationsTitle => 'تخصيصات الفواتير';

  @override
  String get voucherAllocatedAmount => 'المخصص';

  @override
  String get voucherUnallocatedAmount => 'غير المخصص';

  @override
  String get voucherCancelAction => 'إلغاء السند';

  @override
  String get voucherCancelReason => 'سبب الإلغاء';

  @override
  String get voucherConfirmCancel => 'إلغاء هذا السند؟';

  @override
  String get voucherJournalEntry => 'قيد اليومية';

  @override
  String get voucherReversalJournal => 'قيد عكسي';

  @override
  String get journalTitle => 'اليومية';

  @override
  String get journalDetailTitle => 'قيد يومية';

  @override
  String get journalListEmpty => 'لا توجد قيود يومية بعد.';

  @override
  String get journalListEmptyFiltered => 'لا توجد قيود مطابقة للفلاتر الحالية.';

  @override
  String get journalFilterSource => 'المصدر';

  @override
  String get journalFilterSearch => 'بحث في القيود';

  @override
  String get journalPostedBadge => 'مرحّل';

  @override
  String get journalReversalBadge => 'عكسي';

  @override
  String get journalSourceDocument => 'المستند المصدر';

  @override
  String get journalReversalEntry => 'عكس قيد';

  @override
  String get journalLineAccount => 'الحساب';

  @override
  String get cashBankTitle => 'النقد والبنوك';

  @override
  String get cashBankSelectAccount => 'اختر حساب نقد أو بنك';

  @override
  String get cashBankOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get cashBankRunningBalance => 'الرصيد الجاري';

  @override
  String get cashBankExportLoadedRows => 'تصدير الصفوف المحمّلة';

  @override
  String get cashBankExportLoadedRowsCopied =>
      'تم نسخ الصفوف المحمّلة إلى الحافظة كملف CSV.';

  @override
  String get cashBankActivityEmpty =>
      'لا يوجد نشاط لهذا الحساب في الفترة المحددة.';

  @override
  String get taxSettingsTitle => 'إعدادات الضريبة';

  @override
  String get inventoryDocumentsTitle => 'مستندات المخزون المالية';

  @override
  String get inventoryDocumentsLink => 'المستندات المالية';

  @override
  String get inventoryDocumentOpeningStock => 'رصيد افتتاحي';

  @override
  String get inventoryDocumentStockIn => 'إدخال مخزون';

  @override
  String get inventoryDocumentStockOut => 'إخراج مخزون';

  @override
  String get inventoryDocumentStockCount => 'جرد مخزون';

  @override
  String get inventoryDocumentsDeferredBody =>
      'مستندات محاسبة المخزون ستتوفر بعد مراجعة المحاسبة.';

  @override
  String get inventoryDocumentListEmpty => 'لا توجد مستندات مخزون مالية بعد.';

  @override
  String get inventoryDocumentListEmptyFiltered =>
      'لا توجد مستندات مطابقة للفلاتر الحالية.';

  @override
  String get inventoryDocumentNumber => 'رقم المستند';

  @override
  String get inventoryDocumentKind => 'النوع';

  @override
  String get inventoryDocumentWarehouse => 'المخزن';

  @override
  String get inventoryDocumentDate => 'التاريخ';

  @override
  String get inventoryDocumentNotes => 'ملاحظات';

  @override
  String get inventoryDocumentReason => 'السبب';

  @override
  String get inventoryDocumentGainReason => 'سبب الزيادة';

  @override
  String get inventoryDocumentLossReason => 'سبب النقص';

  @override
  String get inventoryDocumentSystemQty => 'كمية النظام';

  @override
  String get inventoryDocumentCountedQty => 'الكمية المعدودة';

  @override
  String get inventoryDocumentDeltaQty => 'الفرق';

  @override
  String get inventoryDocumentUnitCost => 'تكلفة الوحدة';

  @override
  String get inventoryDocumentWacHint =>
      'يُستخدم متوسط التكلفة الحالي عند ترك تكلفة الوحدة فارغة.';

  @override
  String get inventoryDocumentAddLine => 'إضافة سطر';

  @override
  String get inventoryDocumentRemoveLine => 'حذف سطر';

  @override
  String get inventoryDocumentConfirmSubmit => 'تأكيد المستند';

  @override
  String get inventoryDocumentConfirmSubmitMessage =>
      'سيتم ترحيل مستند المخزون المالي ولن يمكن تعديله لاحقًا.';

  @override
  String get inventoryDocumentSubmit => 'ترحيل المستند';

  @override
  String get inventoryDocumentCancelAction => 'إلغاء المستند';

  @override
  String get inventoryDocumentCancelReason => 'سبب الإلغاء';

  @override
  String get inventoryDocumentCancelled => 'ملغى';

  @override
  String get inventoryDocumentLines => 'البنود';

  @override
  String get inventoryDocumentMovements => 'الحركات';

  @override
  String get inventoryDocumentJournalEntry => 'قيد اليومية';

  @override
  String get inventoryDocumentReversalJournal => 'قيد عكسي';

  @override
  String get inventoryDocumentSerializedNotSupportedYet =>
      'المنتجات المسلسلة غير مدعومة لهذا النوع من المستندات حاليًا.';

  @override
  String get inventoryDocumentStatusConfirmed => 'مؤكد';

  @override
  String get inventoryDocumentStatusCancelled => 'ملغى';

  @override
  String get inventoryDocumentFilterKind => 'نوع المستند';

  @override
  String get inventoryDocumentFilterWarehouse => 'المخزن';

  @override
  String get inventoryDocumentCreateOpening => 'رصيد افتتاحي';

  @override
  String get inventoryDocumentCreateStockIn => 'إدخال مخزون';

  @override
  String get inventoryDocumentCreateStockOut => 'إخراج مخزون';

  @override
  String get inventoryDocumentCreateStockCount => 'جرد مخزون';

  @override
  String get inventoryDocumentSelectProduct => 'اختر منتجًا';

  @override
  String get inventoryDocumentSelectReason => 'اختر سببًا';

  @override
  String get inventoryDocumentSerialUnits => 'الأرقام التسلسلية';

  @override
  String get inventoryDocumentSelectUnits => 'اختر الوحدات';

  @override
  String get paymentMethodCash => 'نقد';

  @override
  String get paymentMethodKnet => 'كي نت';

  @override
  String get paymentMethodBankTransfer => 'تحويل بنكي';

  @override
  String get paymentMethodCheque => 'شيك';

  @override
  String get paymentMethodOther => 'أخرى';

  @override
  String get financeColumnParty => 'الطرف';

  @override
  String get financeColumnDate => 'التاريخ';

  @override
  String get financeColumnDueDate => 'تاريخ الاستحقاق';

  @override
  String get financeColumnTotal => 'الإجمالي';

  @override
  String get financeColumnPaid => 'المدفوع';

  @override
  String get financeColumnOutstanding => 'المتبقي';

  @override
  String get financeColumnStatus => 'الحالة';

  @override
  String get financeColumnReference => 'المرجع';

  @override
  String get financeColumnAmount => 'المبلغ';

  @override
  String get financeColumnDescription => 'الوصف';

  @override
  String get financeColumnDebit => 'مدين';

  @override
  String get financeColumnCredit => 'دائن';

  @override
  String get financeColumnBalance => 'الرصيد';

  @override
  String get financeTotalsSubtotal => 'المجموع الفرعي';

  @override
  String get financeTotalsDiscount => 'الخصم';

  @override
  String get financeTotalsTax => 'الضريبة';

  @override
  String get financeTotalsGrandTotal => 'الإجمالي الكلي';

  @override
  String get financeAllocationModeFifo => 'FIFO';

  @override
  String get financeAllocationModeManual => 'يدوي';

  @override
  String get financeAllocationModeUnallocated => 'غير مخصص';

  @override
  String get financeActionCancel => 'إلغاء';

  @override
  String get financeActionPrint => 'طباعة';

  @override
  String get financeActionScan => 'مسح';

  @override
  String get financeActionSelectSerial => 'اختيار تسلسل';

  @override
  String get financeCancellationReason => 'سبب الإلغاء';

  @override
  String get financeReversalLabel => 'عكس';

  @override
  String get calendarSettingsTitle => 'أيام وساعات العمل';

  @override
  String get calendarSettingsPermissionDenied =>
      'ليس لديك صلاحية عرض إعدادات التقويم.';

  @override
  String get calendarSettingsSetupRequired =>
      'يلزم إعداد التقويم قبل تفعيل نوافذ العمل والتذكيرات.';

  @override
  String get calendarSettingsTimezone => 'المنطقة الزمنية IANA';

  @override
  String get calendarSettingsTimezoneRequired => 'اختر منطقة زمنية صالحة.';

  @override
  String calendarSettingsLegacyTimezoneSuggestion(String timezone) {
    return 'اقتراح قديم (غير مؤكد): $timezone';
  }

  @override
  String get calendarSettingsWorkingDaysSection => 'أيام العمل';

  @override
  String get calendarSettingsDayMode => 'وضع اليوم';

  @override
  String get calendarSettingsWorkStart => 'البداية';

  @override
  String get calendarSettingsWorkEnd => 'النهاية';

  @override
  String calendarSettingsDaySummary(String start, String end) {
    return 'النافذة: $start – $end';
  }

  @override
  String get calendarSettingsRemindEventDay =>
      'تذكير عند بداية يوم العمل للموعد';

  @override
  String get calendarSettingsRemindPreviousDay =>
      'تذكير عند بداية يوم العمل السابق';

  @override
  String get calendarSettingsSave => 'حفظ الإعدادات';

  @override
  String get calendarSettingsSaved => 'تم حفظ إعدادات التقويم.';

  @override
  String get calendarSettingsValidationFailed =>
      'تعذر حفظ إعدادات التقويم. راجع الحقول وحاول مرة أخرى.';

  @override
  String get calendarSettingsUnsavedTitle => 'تجاهل التغييرات؟';

  @override
  String get calendarSettingsUnsavedBody =>
      'لديك تغييرات غير محفوظة في إعدادات التقويم.';

  @override
  String get calendarSettingsDiscard => 'تجاهل';

  @override
  String get calendarSettingsDayValidationError => 'راجع إعدادات هذا اليوم.';

  @override
  String get calendarDayModeUnreviewed => 'غير مراجع';

  @override
  String get calendarDayModeDayOff => 'يوم إجازة';

  @override
  String get calendarDayModeWorkingHours => 'ساعات عمل';

  @override
  String get calendarDayMode24Hours => '24 ساعة';

  @override
  String get calendarWeekdayMonday => 'الاثنين';

  @override
  String get calendarWeekdayTuesday => 'الثلاثاء';

  @override
  String get calendarWeekdayWednesday => 'الأربعاء';

  @override
  String get calendarWeekdayThursday => 'الخميس';

  @override
  String get calendarWeekdayFriday => 'الجمعة';

  @override
  String get calendarWeekdaySaturday => 'السبت';

  @override
  String get calendarWeekdaySunday => 'الأحد';

  @override
  String get navCalendarSettings => 'إعدادات التقويم';

  @override
  String get navCalendar => 'التقويم';

  @override
  String get calendarTitle => 'التقويم';

  @override
  String get calendarLoading => 'جاري تحميل التقويم…';

  @override
  String get calendarPermissionDenied => 'ليس لديك صلاحية عرض التقويم.';

  @override
  String get calendarSetupWarning =>
      'لم يتم إعداد جدول العمل بعد. ما زال بإمكانك قراءة المواعيد، لكن قواعد التأخر وأيام العمل محدودة حتى يكتمل الإعداد.';

  @override
  String get calendarAgendaEmpty => 'لا توجد مواعيد في هذا اليوم.';

  @override
  String get calendarLoadMore => 'تحميل المزيد';

  @override
  String calendarVisibleRange(String from, String to) {
    return 'النطاق: $from – $to';
  }

  @override
  String calendarSelectedDate(String date) {
    return 'المحدد: $date';
  }

  @override
  String get calendarErrorValidation =>
      'طلب التقويم غير صالح. تحقق من النطاق والمرشحات.';

  @override
  String get calendarErrorInvalidCursor =>
      'انتهت صلاحية صفحة التقويم. حدّث وحاول مرة أخرى.';

  @override
  String get calendarErrorTenantNotFound => 'تعذر تحديد المستأجر للتقويم.';

  @override
  String get calendarErrorMalformed =>
      'بيانات التقويم من الخادم غير مكتملة. أعد المحاولة.';

  @override
  String get calendarErrorUnavailable =>
      'التقويم غير متاح مؤقتًا. حاول مرة أخرى.';

  @override
  String get calendarErrorUnknown => 'حدث خطأ أثناء تحميل التقويم.';

  @override
  String get calendarEventTypeRefillDue => 'موعد إعادة التعبئة';

  @override
  String get calendarEventTypeBillingDue => 'موعد الفوترة';

  @override
  String get calendarEventTypePaymentDue => 'موعد الدفع';

  @override
  String get calendarEventTypeMaintenanceDue => 'موعد الصيانة';

  @override
  String get calendarEventTypeFollowUp => 'متابعة';

  @override
  String get calendarEventTypeTrialEnding => 'انتهاء التجربة';

  @override
  String get calendarEventTypeContractStart => 'بدء العقد';

  @override
  String get calendarEventTypeContractEnd => 'انتهاء العقد';

  @override
  String get calendarEventTypeCustom => 'مخصص';

  @override
  String get calendarEventStatusPending => 'قيد الانتظار';

  @override
  String get calendarEventStatusDone => 'مكتمل';

  @override
  String get calendarEventStatusMissed => 'فائت';

  @override
  String get calendarEventStatusCancelled => 'ملغى';

  @override
  String get calendarEventStatusRescheduled => 'أُعيدت جدولته';

  @override
  String get calendarSourceKindManual => 'يدوي';

  @override
  String get calendarSourceKindContractGenerated => 'مولَّد من العقد';

  @override
  String get calendarScheduleStateWorkingDay => 'يوم عمل';

  @override
  String get calendarScheduleStateNonWorkingDay => 'يوم غير عمل';

  @override
  String get calendarScheduleStateUnconfigured => 'الجدول غير مُعد';

  @override
  String get calendarScheduleStateDayOffOverridden => 'إجازة مع استثناء';

  @override
  String get calendarOverdueStateNotApplicable => 'غير منطبق';

  @override
  String get calendarOverdueStateUnconfigured => 'الجدول غير مُعد';

  @override
  String get calendarOverdueStateOverdue => 'متأخر';

  @override
  String get calendarOverdueStateNotOverdue => 'غير متأخر';

  @override
  String get calendarFilterAssigned => 'الوكيل المعيّن';

  @override
  String get calendarFilterUnassigned => 'غير المعيّن فقط';

  @override
  String get calendarFilterSearch => 'بحث';

  @override
  String get calendarFilterSearchHint =>
      'ابحث في المواعيد والعملاء والعقود والمواقع والمندوبين';

  @override
  String get calendarFilterOpenFilters => 'المرشحات';

  @override
  String get calendarFilterReset => 'إعادة تعيين';

  @override
  String get calendarFilterAnySource => 'أي مصدر';

  @override
  String get calendarFilterOverdueOnly => 'المتأخر فقط';

  @override
  String get calendarFilterWorkingDayConflict => 'تعارض يوم العمل';

  @override
  String get calendarFilterTypes => 'أنواع المواعيد';

  @override
  String get calendarFilterStatuses => 'الحالات';

  @override
  String get calendarFilterSourceKind => 'المصدر';

  @override
  String get calendarFilterCustomer => 'العميل';

  @override
  String get calendarFilterContract => 'العقد';

  @override
  String get calendarFilterServiceLocation => 'موقع الخدمة';

  @override
  String get calendarFilterApply => 'تطبيق المرشحات';

  @override
  String get calendarFilterClear => 'مسح المرشحات';

  @override
  String calendarFilterActiveCount(int count) {
    return '$count نشط';
  }

  @override
  String get calendarFilterDirty => 'تغييرات مرشحات غير مطبّقة';

  @override
  String get calendarFilterSelectCustomerFirst => 'اختر عميلًا لتصفية المواقع.';

  @override
  String get calendarFilterLookupUnavailable => 'البحث غير متاح لصلاحياتك.';

  @override
  String get calendarFilterLookupError => 'تعذر تحميل نتائج البحث.';

  @override
  String get calendarEventActionsTitle => 'إجراءات الموعد';

  @override
  String get calendarEventActionsClose => 'إغلاق';

  @override
  String get calendarToday => 'اليوم';

  @override
  String get calendarPreviousMonth => 'الشهر السابق';

  @override
  String get calendarNextMonth => 'الشهر التالي';

  @override
  String get calendarSelectMonth => 'اختيار الشهر';

  @override
  String get calendarSelectYear => 'اختيار السنة';

  @override
  String calendarMonthYear(String month, int year) {
    return '$month $year';
  }

  @override
  String calendarCountOverflow(int value) {
    return '$value+';
  }

  @override
  String calendarDayEventCount(int count) {
    return '$count مواعيد';
  }

  @override
  String calendarDayUnassignedCount(int count) {
    return '$count غير معيّن';
  }

  @override
  String calendarDayOverdueCount(int count) {
    return '$count متأخر';
  }

  @override
  String calendarWorkingWindow(String start, String end) {
    return 'ساعات العمل: $start–$end';
  }

  @override
  String get calendarAgendaFilteredEmpty =>
      'لا توجد مواعيد تطابق المرشحات الحالية.';

  @override
  String get calendarOverdueSectionTitle => 'متأخر خارج هذا النطاق';

  @override
  String get calendarOverdueUnavailable =>
      'العناصر المتأخرة غير متاحة حتى يتم إعداد جدول العمل.';

  @override
  String get calendarOverdueEmpty => 'لا توجد مواعيد متأخرة خارج هذا النطاق.';

  @override
  String get calendarDirectionsAvailable => 'الاتجاهات متاحة';

  @override
  String get calendarRescheduledBadge => 'أُعيدت جدولته';

  @override
  String get calendarDayOffConflict => 'مجدول في يوم إجازة';

  @override
  String get calendarViewCustomer => 'عرض العميل';

  @override
  String get calendarViewContract => 'عرض العقد';

  @override
  String get calendarSemanticsToday => 'اليوم';

  @override
  String get calendarSemanticsSelected => 'محدد';

  @override
  String get calendarSemanticsDayOff => 'يوم إجازة';

  @override
  String get calendarSemanticsConflict => 'تعارض يوم العمل';

  @override
  String get calendarMonthSkeleton => 'جاري تحميل ملخص الشهر…';

  @override
  String get calendarAgendaLoading => 'جاري تحميل الأجندة…';

  @override
  String get calendarOverdueLoading => 'جاري تحميل المتأخر…';

  @override
  String get calendarValidationRangeSpan =>
      'يجب أن يكون نطاق التاريخ بين يوم واحد و62 يومًا.';

  @override
  String get calendarValidationSearchTooShort =>
      'يجب أن يكون البحث حرفين على الأقل.';

  @override
  String get calendarValidationUnassignedAssignedConflict =>
      'لا يمكن الجمع بين غير المعيّن ووكيل معيّن.';

  @override
  String get calendarValidationOverdueRequiresPending =>
      'تصفية المتأخر تتطلب حالة قيد الانتظار.';

  @override
  String get calendarValidationAssignedOnlyAgent =>
      'المستخدمون المعيّنون فقط لا يمكنهم التصفية حسب الوكيل.';

  @override
  String get calendarValidationAssignedOnlyUnassigned =>
      'المستخدمون المعيّنون فقط لا يمكنهم طلب مواعيد غير معيّنة.';

  @override
  String get calendarLabelAssigned => 'معيّن';

  @override
  String get calendarLabelUnassigned => 'غير معيّن';
}
