import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/supplier_exception.dart';

String supplierErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    SupplierException.permissionDenied => l10n.supplierErrorPermissionDenied,
    SupplierException.nameArRequired => l10n.supplierValidationNameArRequired,
    SupplierException.emailInvalid => l10n.supplierValidationEmailInvalid,
    SupplierException.validationFailed => l10n.supplierValidationFailed,
    SupplierException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.supplierErrorUnknown,
  };
}
