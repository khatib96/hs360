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
  String get phaseZeroReady => 'المرحلة 0 جاهزة — هيكل التطوير المحلي';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get uiDirectionRtl => 'اتجاه الواجهة: RTL';

  @override
  String get uiDirectionLtr => 'اتجاه الواجهة: LTR';

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
}
