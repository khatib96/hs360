import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/inventory_exception.dart';
import '../../../core/errors/products_exception.dart';

String warehouseEmployeeLookupErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    ProductsException.permissionDenied => l10n.productErrorPermissionDenied,
    ProductsException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.warehouseEmployeeLookupFailed,
  };
}

String inventoryErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    InventoryException.permissionDenied => l10n.productErrorPermissionDenied,
    InventoryException.validationFailed => l10n.productValidationFailed,
    InventoryException.insufficientStock => l10n.inventoryErrorInsufficientStock,
    _ => l10n.inventoryBalancesError,
  };
}

String inventoryMovementsErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    InventoryException.permissionDenied => l10n.productErrorPermissionDenied,
    InventoryException.validationFailed => l10n.productValidationFailed,
    _ => l10n.inventoryMovementsError,
  };
}

String inventoryHydrationWarningMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    ProductsException.permissionDenied => l10n.productErrorPermissionDenied,
    ProductsException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    InventoryException.unknown => l10n.inventoryBalancesError,
    _ => l10n.inventoryBalancesError,
  };
}

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
