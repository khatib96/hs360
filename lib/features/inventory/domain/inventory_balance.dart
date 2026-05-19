import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

class InventoryBalance {
  const InventoryBalance({
    required this.id,
    required this.tenantId,
    required this.warehouseId,
    required this.productId,
    required this.qtyAvailable,
    required this.qtyRented,
    required this.qtyTrial,
    required this.qtyMaintenance,
    required this.qtyDamaged,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String warehouseId;
  final String productId;
  final Decimal qtyAvailable;
  final Decimal qtyRented;
  final Decimal qtyTrial;
  final Decimal qtyMaintenance;
  final Decimal qtyDamaged;
  final DateTime? updatedAt;

  factory InventoryBalance.fromRow(Map<String, dynamic> row) {
    return InventoryBalance(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      warehouseId: row['warehouse_id'] as String,
      productId: row['product_id'] as String,
      qtyAvailable: parseDecimal(row['qty_available']),
      qtyRented: parseDecimal(row['qty_rented']),
      qtyTrial: parseDecimal(row['qty_trial']),
      qtyMaintenance: parseDecimal(row['qty_maintenance']),
      qtyDamaged: parseDecimal(row['qty_damaged']),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }
}
