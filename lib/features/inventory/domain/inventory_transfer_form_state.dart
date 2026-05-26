import 'package:decimal/decimal.dart';

/// Input for [record_inventory_transfer] RPC. Quantity is always primary unit.
class InventoryTransferFormState {
  const InventoryTransferFormState({
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.productId,
    required this.qty,
    required this.notes,
    this.isSerialized = false,
    this.sourceQtyAvailable,
  });

  final String fromWarehouseId;
  final String toWarehouseId;
  final String productId;
  final Decimal qty;
  final String notes;

  /// For client-side validation before RPC.
  final bool isSerialized;

  /// Current balance at source warehouse for preview/validation.
  final Decimal? sourceQtyAvailable;
}
