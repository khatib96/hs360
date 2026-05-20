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
  String get inventory => 'أرصدة المخزون';

  @override
  String get inventoryMovements => 'سجل الحركات';

  @override
  String get inventoryTransfers => 'تحويلات المخزون';

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
  String get productColumnRentalPrice => 'سعر الإيجار';

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
  String get productFieldRentalPrice => 'سعر الإيجار الشهري';

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
  String get productValidationRentalRequired =>
      'سعر الإيجار مطلوب لمنتجات الإيجار';

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
}
