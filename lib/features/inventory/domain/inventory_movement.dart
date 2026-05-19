import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import 'movement_type.dart';

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.tenantId,
    required this.movementType,
    required this.warehouseId,
    required this.productId,
    this.productUnitId,
    required this.qty,
    this.unitCost,
    this.referenceTable,
    this.referenceId,
    this.notes,
    required this.occurredAt,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String tenantId;
  final MovementType movementType;
  final String warehouseId;
  final String productId;
  final String? productUnitId;
  final Decimal qty;
  final Decimal? unitCost;
  final String? referenceTable;
  final String? referenceId;
  final String? notes;
  final DateTime occurredAt;
  final DateTime? createdAt;
  final String? createdBy;

  factory InventoryMovement.fromRow(Map<String, dynamic> row) {
    return InventoryMovement(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      movementType: MovementType.fromDb(row['movement_type'] as String?),
      warehouseId: row['warehouse_id'] as String,
      productId: row['product_id'] as String,
      productUnitId: row['product_unit_id'] as String?,
      qty: parseDecimal(row['qty']),
      unitCost: tryParseDecimal(row['unit_cost']),
      referenceTable: row['reference_table'] as String?,
      referenceId: row['reference_id'] as String?,
      notes: row['notes'] as String?,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      createdBy: row['created_by'] as String?,
    );
  }
}
