// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HS360';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get phaseZeroReady => 'Phase 0 ready — local development scaffold';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get uiDirectionRtl => 'UI direction: RTL';

  @override
  String get uiDirectionLtr => 'UI direction: LTR';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Enter your account details to continue';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get logout => 'Sign out';

  @override
  String get loading => 'Loading…';

  @override
  String get retry => 'Retry';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get validationEmailRequired => 'Enter your email';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String get validationPasswordRequired => 'Enter your password';

  @override
  String get authErrorInvalidCredentials => 'Invalid email or password';

  @override
  String get authErrorNetworkUnavailable =>
      'Could not connect. Check your network or local Supabase';

  @override
  String get authErrorNoActiveTenantUser =>
      'No active tenant account is linked to this user';

  @override
  String get authErrorUserInactive => 'This user account is inactive';

  @override
  String get authErrorSupabaseNotConfigured => 'Supabase is not configured';

  @override
  String get authErrorUnknown =>
      'An unexpected error occurred. Please try again';

  @override
  String get authMissingAnonKey =>
      'Local Supabase key is missing. Run the app via scripts/run-local.ps1';

  @override
  String get authInitFailed =>
      'Could not initialize Supabase. Check that local services are running';

  @override
  String get resetPasswordSuccess =>
      'If the email is registered, password reset instructions will be sent.';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we will send reset instructions if the account exists';
}
