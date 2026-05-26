import 'package:decimal/decimal.dart';

import 'inventory_balance.dart';

/// One inventory balance line with optional hydrated product/warehouse labels.
class InventoryBalanceRow {
  const InventoryBalanceRow({
    required this.balance,
    required this.productId,
    required this.warehouseId,
    this.productSku,
    this.productNameAr,
    this.productNameEn,
    this.warehouseNameAr,
    this.warehouseNameEn,
    this.reorderPoint,
  });

  final InventoryBalance balance;
  final String productId;
  final String warehouseId;
  final String? productSku;
  final String? productNameAr;
  final String? productNameEn;
  final String? warehouseNameAr;
  final String? warehouseNameEn;
  final Decimal? reorderPoint;

  Decimal get qtyAvailable => balance.qtyAvailable;
  Decimal get qtyRented => balance.qtyRented;
  Decimal get qtyTrial => balance.qtyTrial;
  Decimal get qtyMaintenance => balance.qtyMaintenance;
  Decimal get qtyDamaged => balance.qtyDamaged;
}
