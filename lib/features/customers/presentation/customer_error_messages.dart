import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/customer_exception.dart';
import 'customer_form_draft.dart';

String customerErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    CustomerException.permissionDenied => l10n.customerErrorPermissionDenied,
    CustomerException.nameArRequired => l10n.customerValidationNameArRequired,
    CustomerException.phonePrimaryRequired =>
      l10n.customerValidationPhoneRequired,
    CustomerException.negativeCreditLimit =>
      l10n.customerValidationNegativeCredit,
    CustomerException.negativePaymentTerms =>
      l10n.customerValidationNegativePayment,
    CustomerException.gpsInvalid => l10n.customerValidationGpsInvalid,
    CustomerException.emailInvalid => l10n.customerValidationEmailInvalid,
    CustomerFormDraft.invalidDecimal => l10n.customerInvalidDecimal,
    CustomerFormDraft.invalidInteger => l10n.customerInvalidInteger,
    CustomerException.validationFailed => l10n.customerValidationFailed,
    CustomerException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.customerErrorUnknown,
  };
}
