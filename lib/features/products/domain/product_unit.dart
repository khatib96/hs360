import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import 'product_unit_health_status.dart';
import 'unit_status.dart';

class ProductUnit {
  const ProductUnit({
    required this.id,
    required this.tenantId,
    required this.productId,
    required this.serialNumber,
    this.barcode,
    required this.status,
    this.currentWarehouseId,
    this.warehouseNameAr,
    this.warehouseNameEn,
    this.purchaseCost,
    required this.healthStatus,
    required this.acquiredAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String productId;
  final String serialNumber;
  final String? barcode;
  final UnitStatus status;
  final String? currentWarehouseId;
  final String? warehouseNameAr;
  final String? warehouseNameEn;
  final Decimal? purchaseCost;
  final ProductUnitHealthStatus healthStatus;
  final DateTime acquiredAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ProductUnit.fromRow(
    Map<String, dynamic> row, {
    String? warehouseNameAr,
    String? warehouseNameEn,
  }) {
    return ProductUnit(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      productId: row['product_id'] as String,
      serialNumber: row['serial_number'] as String,
      barcode: row['barcode'] as String?,
      status: UnitStatus.fromDb(row['status'] as String?),
      currentWarehouseId: row['current_warehouse_id'] as String?,
      warehouseNameAr: warehouseNameAr,
      warehouseNameEn: warehouseNameEn,
      purchaseCost: row.containsKey('purchase_cost')
          ? tryParseDecimal(row['purchase_cost'])
          : null,
      healthStatus: ProductUnitHealthStatus.fromDb(
        row['health_status'] as String?,
      ),
      acquiredAt: DateTime.parse(row['acquired_at'] as String),
      notes: row['notes'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }
}
