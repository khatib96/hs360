import 'package:hs360/l10n/app_localizations.dart';

import '../domain/inventory_adjustment_reason.dart';
import '../domain/inventory_document_summary.dart';

String inventoryDocumentKindLabel(
  AppLocalizations l10n,
  InventoryDocumentKind kind,
) {
  return switch (kind) {
    InventoryDocumentKind.openingStock => l10n.inventoryDocumentOpeningStock,
    InventoryDocumentKind.stockIn => l10n.inventoryDocumentStockIn,
    InventoryDocumentKind.stockOut => l10n.inventoryDocumentStockOut,
    InventoryDocumentKind.stockCount => l10n.inventoryDocumentStockCount,
  };
}

String inventoryDocumentStatusLabel(
  AppLocalizations l10n,
  InventoryDocumentStatus status,
) {
  return switch (status) {
    InventoryDocumentStatus.confirmed => l10n.inventoryDocumentStatusConfirmed,
    InventoryDocumentStatus.cancelled => l10n.inventoryDocumentStatusCancelled,
    InventoryDocumentStatus.draft => l10n.invoiceStatusDraft,
  };
}

String inventoryReasonLabel(
  InventoryAdjustmentReason reason,
  String languageCode,
) {
  return languageCode == 'ar' ? reason.nameAr : reason.nameEn;
}

String localizedWarehouseName({
  required String languageCode,
  String? nameAr,
  String? nameEn,
}) {
  if (languageCode == 'ar') {
    return (nameAr?.trim().isNotEmpty == true ? nameAr! : nameEn) ?? '—';
  }
  return (nameEn?.trim().isNotEmpty == true ? nameEn! : nameAr) ?? '—';
}
