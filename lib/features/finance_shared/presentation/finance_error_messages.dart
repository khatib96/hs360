import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/finance_exception.dart';

String financeErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    FinanceException.tenantNotFound => l10n.financeErrorTenantNotFound,
    FinanceException.permissionDenied => l10n.financeErrorPermissionDenied,
    FinanceException.validationFailed => l10n.financeErrorValidationFailed,
    FinanceException.idempotencyPayloadMismatch =>
      l10n.financeErrorIdempotencyPayloadMismatch,
    FinanceException.booksLocked => l10n.financeErrorBooksLocked,
    FinanceException.duplicateSerial => l10n.financeErrorDuplicateSerial,
    FinanceException.crossTenantReference =>
      l10n.financeErrorCrossTenantReference,
    FinanceException.taxRateNotFound => l10n.financeErrorTaxRateNotFound,
    FinanceException.taxRateInUse => l10n.financeErrorTaxRateInUse,
    FinanceException.notFound => l10n.financeErrorNotFound,
    FinanceException.notAvailable => l10n.financeErrorNotAvailable,
    FinanceException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.financeErrorUnknown,
  };
}

String financeErrorMessages(AppLocalizations l10n, List<String> codes) {
  if (codes.isEmpty) return l10n.financeErrorUnknown;
  return codes.map((code) => financeErrorMessage(l10n, code)).join('\n');
}
