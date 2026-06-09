import '../../core/errors/inventory_exception.dart';
import '../../features/inventory/domain/inventory_adjustment_form_state.dart';
import '../../features/inventory/domain/movement_type.dart';
import '../services/cost_engine.dart';
import '../services/stock_engine.dart';
import 'validation_result.dart';

class InventoryAdjustmentValidator {
  const InventoryAdjustmentValidator({
    StockEngine? stockEngine,
    CostEngine? costEngine,
  }) : _stockEngine = stockEngine ?? const StockEngine(),
       _costEngine = costEngine ?? const CostEngine();

  final StockEngine _stockEngine;
  final CostEngine _costEngine;

  ValidationResult validate(InventoryAdjustmentFormState input) {
    if (input.warehouseId.trim().isEmpty) {
      return const ValidationResult(
        codes: [InventoryException.warehouseRequired],
      );
    }
    if (input.productId.trim().isEmpty) {
      return const ValidationResult(
        codes: [InventoryException.productRequired],
      );
    }

    final stockResult = _stockEngine.validateAdjustment(input);
    if (!stockResult.isValid) return stockResult;

    if (input.movementType == MovementType.adjustmentIn) {
      final costResult = _costEngine.validateUnitCostForAdjustmentIn(
        input.unitCost,
      );
      if (!costResult.isValid) return costResult;
    }

    return const ValidationResult.valid();
  }
}
