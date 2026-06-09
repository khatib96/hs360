import 'package:hs360/l10n/app_localizations.dart';

import '../data/logo_loader.dart';
import '../domain/document_render_result.dart';
import '../../errors/document_exception.dart';

String documentErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    DocumentException.permissionDenied => l10n.documentPreviewPermissionDenied,
    DocumentException.noDefaultTemplate => l10n.documentErrorNoTemplate,
    DocumentException.statementDateRangeInvalid =>
      l10n.documentErrorStatementDateRange,
    DocumentException.statementRangeTooLarge =>
      l10n.documentErrorStatementTooLarge,
    DocumentException.unsupportedDocumentType =>
      l10n.documentErrorUnsupportedType,
    DocumentRenderException.thermalContentTooLarge =>
      l10n.documentErrorThermalTooLarge,
    DocumentRenderException.fontLoadFailed => l10n.documentErrorFontLoad,
    DocumentException.validationFailed => l10n.documentErrorValidation,
    DocumentException.tenantNotFound => l10n.documentErrorTenantNotFound,
    DocumentException.supabaseNotConfigured => l10n.documentErrorNotConfigured,
    NetworkLogoLoader.invalidUrl => l10n.documentErrorLogoInvalidUrl,
    NetworkLogoLoader.tooLarge => l10n.documentErrorLogoTooLarge,
    NetworkLogoLoader.invalidDimensions =>
      l10n.documentErrorLogoInvalidDimensions,
    NetworkLogoLoader.unsupportedFormat =>
      l10n.documentErrorLogoUnsupportedFormat,
    NetworkLogoLoader.fetchFailed => l10n.documentErrorLogoFetchFailed,
    _ => l10n.documentErrorUnknown,
  };
}
