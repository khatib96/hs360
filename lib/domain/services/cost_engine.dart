import 'package:decimal/decimal.dart';

import '../../core/errors/inventory_exception.dart';
import '../../features/inventory/domain/movement_type.dart';
import '../../domain/validators/validation_result.dart';

/// WAC preview and unit-cost validation (DB/RPC applies final WAC).
class CostEngine {
  const CostEngine();

  bool movementAffectsWac(MovementType type) =>
      type == MovementType.adjustmentIn;

  ValidationResult validateUnitCostForAdjustmentIn(Decimal? unitCost) {
    if (unitCost == null) {
      return const ValidationResult(
        codes: [InventoryException.validationFailed],
      );
    }
    if (unitCost < Decimal.zero) {
      return const ValidationResult(
        codes: [InventoryException.validationFailed],
      );
    }
    return const ValidationResult.valid();
  }

  /// WAC preview per migration 036 (primary unit).
  Decimal previewWac({
    required Decimal oldTotalQty,
    required Decimal oldAvgCost,
    required Decimal incomingQty,
    required Decimal incomingUnitCost,
  }) {
    if (oldTotalQty == Decimal.zero) {
      return incomingUnitCost;
    }
    final numerator =
        (oldTotalQty * oldAvgCost) + (incomingQty * incomingUnitCost);
    final denominator = oldTotalQty + incomingQty;
    return (numerator / denominator).toDecimal(scaleOnInfinitePrecision: 6);
  }
}
