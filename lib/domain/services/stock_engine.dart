import 'package:decimal/decimal.dart';

import '../../core/errors/inventory_exception.dart';
import '../../features/inventory/domain/inventory_adjustment_form_state.dart';
import '../../features/inventory/domain/inventory_transfer_form_state.dart';
import '../../features/inventory/domain/movement_type.dart';
import '../../domain/validators/validation_result.dart';

/// Preview and validate stock adjustments (DB/RPC is source of truth).
class StockEngine {
  const StockEngine();

  /// Signed delta for [qty_available] preview only.
  Decimal previewAdjustmentDelta(MovementType type, Decimal qty) {
    switch (type) {
      case MovementType.adjustmentIn:
      case MovementType.transferIn:
      case MovementType.purchase:
      case MovementType.rentalReturn:
      case MovementType.saleReturn:
      case MovementType.maintenanceIn:
        return qty;
      case MovementType.adjustmentOut:
      case MovementType.transferOut:
      case MovementType.sale:
      case MovementType.rentalOut:
      case MovementType.refill:
      case MovementType.purchaseReturn:
      case MovementType.maintenanceOut:
        return -qty;
    }
  }

  ValidationResult validateAdjustment(InventoryAdjustmentFormState input) {
    final codes = <String>[];

    if (!input.movementType.isManualAdjustment) {
      codes.add(InventoryException.validationFailed);
    }

    if (input.qty <= Decimal.zero) {
      codes.add(InventoryException.validationFailed);
    }

    if (input.isSerialized) {
      codes.add(InventoryException.serializedAdjustmentNotSupported);
    }

    final notes = input.notes.trim();
    if (notes.isEmpty) {
      codes.add(InventoryException.validationFailed);
    }

    if (input.movementType == MovementType.adjustmentOut) {
      final available = input.currentQtyAvailable;
      if (available == null || available < input.qty) {
        codes.add(InventoryException.insufficientStock);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult validateTransfer(InventoryTransferFormState input) {
    final codes = <String>[];

    if (input.fromWarehouseId == input.toWarehouseId) {
      codes.add(InventoryException.transferSameWarehouse);
    }

    if (input.qty <= Decimal.zero) {
      codes.add(InventoryException.validationFailed);
    }

    if (input.isSerialized) {
      codes.add(InventoryException.serializedTransferNotSupported);
    }

    final notes = input.notes.trim();
    if (notes.isEmpty) {
      codes.add(InventoryException.validationFailed);
    }

    final available = input.sourceQtyAvailable;
    if (available == null || available < input.qty) {
      codes.add(InventoryException.insufficientStock);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
