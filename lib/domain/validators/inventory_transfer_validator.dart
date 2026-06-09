import '../../core/errors/inventory_exception.dart';
import '../../features/inventory/domain/inventory_transfer_form_state.dart';
import '../services/stock_engine.dart';
import 'validation_result.dart';

class InventoryTransferValidator {
  const InventoryTransferValidator({StockEngine? stockEngine})
    : _stockEngine = stockEngine ?? const StockEngine();

  final StockEngine _stockEngine;

  ValidationResult validate(InventoryTransferFormState input) {
    if (input.fromWarehouseId.trim().isEmpty) {
      return const ValidationResult(
        codes: [InventoryException.sourceWarehouseRequired],
      );
    }
    if (input.toWarehouseId.trim().isEmpty) {
      return const ValidationResult(
        codes: [InventoryException.destinationWarehouseRequired],
      );
    }
    if (input.productId.trim().isEmpty) {
      return const ValidationResult(
        codes: [InventoryException.productRequired],
      );
    }

    final stockResult = _stockEngine.validateTransfer(input);
    if (!stockResult.isValid) return stockResult;

    return const ValidationResult.valid();
  }
}
