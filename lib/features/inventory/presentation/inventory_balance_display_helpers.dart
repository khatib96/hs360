import 'package:hs360/l10n/app_localizations.dart';

import '../../products/domain/product_stock_label.dart';
import '../domain/inventory_balance_row.dart';
import '../domain/warehouse.dart';
import '../domain/warehouse_type.dart';
import 'warehouse_display_helpers.dart';

String inventoryBalanceProductLabel(
  InventoryBalanceRow row,
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

String inventoryBalanceWarehouseLabel(
  InventoryBalanceRow row,
  String languageCode,
  AppLocalizations l10n,
) {
  final nameAr = row.warehouseNameAr?.trim();
  final nameEn = row.warehouseNameEn?.trim();
  if (nameAr != null &&
      nameAr.isNotEmpty &&
      nameEn != null &&
      nameEn.isNotEmpty) {
    return localizedWarehouseName(
      Warehouse(
        id: row.warehouseId,
        tenantId: '',
        nameAr: nameAr,
        nameEn: nameEn,
        type: WarehouseType.main,
        isActive: true,
      ),
      languageCode,
    );
  }
  return '${l10n.inventoryBalanceNameUnavailable} (${_shortId(row.warehouseId)})';
}

String productStockLabelDisplayName(
  ProductStockLabel label,
  String languageCode,
) {
  if (languageCode.toLowerCase() == 'ar') {
    return label.nameAr;
  }
  return label.nameEn;
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 8);
}
