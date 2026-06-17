import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/inventory_accounting/domain/inventory_adjustment_reason.dart';
import 'validation_result.dart';

enum InventoryAdjustmentDirection { stockIn, stockOut }

class InventoryAdjustmentDocumentLineInput {
  const InventoryAdjustmentDocumentLineInput({
    required this.productId,
    required this.qty,
    this.unitCost,
  });

  final String productId;
  final Decimal qty;
  final Decimal? unitCost;
}

class InventoryAdjustmentDocumentInput {
  const InventoryAdjustmentDocumentInput({
    required this.warehouseId,
    required this.date,
    required this.direction,
    required this.lines,
    this.reason,
  });

  final String warehouseId;
  final DateTime date;
  final InventoryAdjustmentDirection direction;
  final InventoryAdjustmentReason? reason;
  final List<InventoryAdjustmentDocumentLineInput> lines;
}

/// Pre-M4.5 client check for stock-in/stock-out documents.
class InventoryAdjustmentDocumentValidator {
  const InventoryAdjustmentDocumentValidator();

  ValidationResult validate(InventoryAdjustmentDocumentInput input) {
    final codes = <String>[];

    if (input.warehouseId.trim().isEmpty) {
      codes.add(FinanceException.validationWarehouseRequired);
    }
    if (input.reason == null || input.reason!.code.trim().isEmpty) {
      codes.add(FinanceException.validationReasonRequired);
    }
    if (input.lines.isEmpty) {
      codes.add(FinanceException.validationLinesRequired);
    }

    for (final line in input.lines) {
      if (line.productId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
      }
      if (line.qty <= Decimal.zero) {
        codes.add(FinanceException.validationLineQtyInvalid);
      }
      if (input.direction == InventoryAdjustmentDirection.stockIn &&
          input.reason!.requiresCost &&
          (line.unitCost == null || line.unitCost! < Decimal.zero)) {
        codes.add(FinanceException.validationCostRequired);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
