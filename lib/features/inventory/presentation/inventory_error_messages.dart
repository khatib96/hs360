import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/products_exception.dart';

String warehouseErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    ProductsException.nameArRequired => l10n.productValidationNameArRequired,
    ProductsException.nameEnRequired => l10n.productValidationNameEnRequired,
    ProductsException.warehouseAgentRequired =>
      l10n.warehouseValidationAgentRequired,
    ProductsException.duplicateActiveVanWarehouse =>
      l10n.warehouseErrorDuplicateActiveVan,
    ProductsException.permissionDenied => l10n.productErrorPermissionDenied,
    ProductsException.validationFailed => l10n.productValidationFailed,
    ProductsException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.warehouseErrorUnknown,
  };
}
