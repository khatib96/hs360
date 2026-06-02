import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/customer_exception.dart';

String customerErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    CustomerException.permissionDenied => l10n.customerErrorPermissionDenied,
    CustomerException.nameArRequired => l10n.customerValidationNameArRequired,
    CustomerException.phonePrimaryRequired =>
      l10n.customerValidationPhoneRequired,
    CustomerException.emailInvalid => l10n.customerValidationEmailInvalid,
    CustomerException.accountAlreadyLinked =>
      l10n.customerErrorAccountAlreadyLinked,
    CustomerException.validationFailed => l10n.customerValidationFailed,
    CustomerException.serviceLocationNameRequired =>
      l10n.serviceLocationValidationNameRequired,
    CustomerException.locationInUse => l10n.serviceLocationInUse,
    CustomerException.primaryRequired => l10n.serviceLocationPrimaryRequired,
    CustomerException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.customerErrorUnknown,
  };
}
