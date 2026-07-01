import 'package:decimal/decimal.dart';

class InventoryDocumentMovement {
  const InventoryDocumentMovement({
    required this.id,
    required this.movementType,
    required this.productId,
    required this.qty,
    this.unitCost,
  });

  final String id;
  final String movementType;
  final String productId;
  final Decimal qty;
  final Decimal? unitCost;
}
