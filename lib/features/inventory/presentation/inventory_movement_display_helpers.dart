import 'package:hs360/l10n/app_localizations.dart';

import '../domain/inventory_movement_row.dart';
import '../domain/movement_type.dart';
import '../domain/warehouse.dart';
import '../domain/warehouse_type.dart';
import 'warehouse_display_helpers.dart';

String inventoryMovementProductLabel(
  InventoryMovementRow row,
  String languageCode,
  AppLocalizations l10n,
) {
  final nameAr = row.productNameAr?.trim();
  final nameEn = row.productNameEn?.trim();
  if (nameAr != null &&
      nameAr.isNotEmpty &&
      nameEn != null &&
      nameEn.isNotEmpty) {
    return languageCode.toLowerCase() == 'ar' ? nameAr : nameEn;
  }
  final sku = row.productSku?.trim();
  if (sku != null && sku.isNotEmpty) return sku;
  return '${l10n.inventoryBalanceNameUnavailable} (${_shortId(row.productId)})';
}

String inventoryMovementWarehouseLabel(
  InventoryMovementRow row,
  String languageCode,
  AppLocalizations l10n, {
  required String inactiveSuffix,
}) {
  final nameAr = row.warehouseNameAr?.trim();
  final nameEn = row.warehouseNameEn?.trim();
  String label;
  if (nameAr != null &&
      nameAr.isNotEmpty &&
      nameEn != null &&
      nameEn.isNotEmpty) {
    label = localizedWarehouseName(
      Warehouse(
        id: row.warehouseId,
        tenantId: '',
        nameAr: nameAr,
        nameEn: nameEn,
        type: WarehouseType.main,
        isActive: row.warehouseIsActive,
      ),
      languageCode,
    );
  } else {
    label =
        '${l10n.inventoryBalanceNameUnavailable} (${_shortId(row.warehouseId)})';
  }
  if (!row.warehouseIsActive) {
    return '$label ($inactiveSuffix)';
  }
  return label;
}

String movementTypeLabel(MovementType type, AppLocalizations l10n) {
  return switch (type) {
    MovementType.purchase => l10n.inventoryMovementTypePurchase,
    MovementType.sale => l10n.inventoryMovementTypeSale,
    MovementType.rentalOut => l10n.inventoryMovementTypeRentalOut,
    MovementType.rentalReturn => l10n.inventoryMovementTypeRentalReturn,
    MovementType.refill => l10n.inventoryMovementTypeRefill,
    MovementType.transferOut => l10n.inventoryMovementTypeTransferOut,
    MovementType.transferIn => l10n.inventoryMovementTypeTransferIn,
    MovementType.adjustmentIn => l10n.inventoryMovementTypeAdjustmentIn,
    MovementType.adjustmentOut => l10n.inventoryMovementTypeAdjustmentOut,
    MovementType.saleReturn => l10n.inventoryMovementTypeSaleReturn,
    MovementType.purchaseReturn => l10n.inventoryMovementTypePurchaseReturn,
    MovementType.maintenanceIn => l10n.inventoryMovementTypeMaintenanceIn,
    MovementType.maintenanceOut => l10n.inventoryMovementTypeMaintenanceOut,
  };
}

String referenceLabel(InventoryMovementRow row, AppLocalizations l10n) {
  final table = row.referenceTable?.trim();
  final id = row.referenceId?.trim();
  if ((table == null || table.isEmpty) && (id == null || id.isEmpty)) {
    return l10n.inventoryMovementReferenceNone;
  }
  final tableLabel = _referenceTableLabel(table, l10n);
  if (id != null && id.isNotEmpty) {
    return '$tableLabel / ${_shortId(id)}';
  }
  return tableLabel;
}

String _referenceTableLabel(String? table, AppLocalizations l10n) {
  if (table == null || table.isEmpty) {
    return l10n.inventoryMovementReferenceNone;
  }
  return switch (table) {
    'inventory_adjustment' => l10n.inventoryMovementReferenceAdjustment,
    'inventory_transfer' => l10n.inventoryMovementReferenceTransfer,
    'product_unit' => l10n.inventoryMovementReferenceProductUnit,
    _ => table,
  };
}

String createdByLabel(String? createdBy, AppLocalizations l10n) {
  final id = createdBy?.trim();
  if (id == null || id.isEmpty) {
    return l10n.inventoryMovementCreatedByNotRecorded;
  }
  return _shortId(id);
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 8);
}
