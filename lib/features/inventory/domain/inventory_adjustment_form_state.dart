import 'package:decimal/decimal.dart';

import 'movement_type.dart';

/// Input for [record_inventory_adjustment] RPC. Quantity is always primary unit.
class InventoryAdjustmentFormState {
  const InventoryAdjustmentFormState({
    required this.warehouseId,
    required this.productId,
    required this.qty,
    required this.movementType,
    this.unitCost,
    required this.notes,
    this.isSerialized = false,
    this.currentQtyAvailable,
  });

  final String warehouseId;
  final String productId;
  final Decimal qty;
  final MovementType movementType;
  final Decimal? unitCost;
  final String notes;

  /// For client-side validation before RPC.
  final bool isSerialized;

  /// Current balance at warehouse for stock-out preview/validation.
  final Decimal? currentQtyAvailable;
}
