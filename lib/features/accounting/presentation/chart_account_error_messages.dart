import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/accounting_exception.dart';

String chartAccountErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    AccountingException.permissionDenied =>
      l10n.chartAccountErrorPermissionDenied,
    AccountingException.codeRequired => l10n.chartAccountValidationCodeRequired,
    AccountingException.nameArRequired =>
      l10n.chartAccountValidationNameArRequired,
    AccountingException.nameEnRequired =>
      l10n.chartAccountValidationNameEnRequired,
    AccountingException.parentTypeMismatch =>
      l10n.chartAccountErrorParentTypeMismatch,
    AccountingException.duplicateCode => l10n.chartAccountErrorDuplicateCode,
    AccountingException.accountProtected =>
      l10n.chartAccountErrorAccountProtected,
    AccountingException.accountTypeChangeUnsafe =>
      l10n.chartAccountErrorTypeChangeUnsafe,
    AccountingException.accountHasActiveChildren =>
      l10n.chartAccountErrorHasActiveChildren,
    AccountingException.immutableColumn => l10n.chartAccountErrorImmutableColumn,
    AccountingException.validationFailed => l10n.chartAccountValidationFailed,
    AccountingException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.chartAccountErrorUnknown,
  };
}

String chartAccountErrorMessages(AppLocalizations l10n, List<String> codes) {
  return codes.map((c) => chartAccountErrorMessage(l10n, c)).join('\n');
}
