import 'package:decimal/decimal.dart';

import 'inventory_movement.dart';
import 'movement_type.dart';

/// One movement line with optional hydrated product/warehouse labels.
class InventoryMovementRow {
  const InventoryMovementRow({
    required this.movement,
    required this.productId,
    required this.warehouseId,
    this.productSku,
    this.productNameAr,
    this.productNameEn,
    this.warehouseNameAr,
    this.warehouseNameEn,
    this.warehouseIsActive = true,
  });

  final InventoryMovement movement;
  final String productId;
  final String warehouseId;
  final String? productSku;
  final String? productNameAr;
  final String? productNameEn;
  final String? warehouseNameAr;
  final String? warehouseNameEn;
  final bool warehouseIsActive;

  MovementType get movementType => movement.movementType;
  Decimal get qty => movement.qty;
  Decimal? get unitCost => movement.unitCost;
  String? get referenceTable => movement.referenceTable;
  String? get referenceId => movement.referenceId;
  String? get notes => movement.notes;
  DateTime get occurredAt => movement.occurredAt;
  String? get createdBy => movement.createdBy;
}
