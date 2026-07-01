import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import 'validation_result.dart';

class OpeningStockLineInput {
  const OpeningStockLineInput({
    required this.productId,
    required this.qty,
    this.unitCost,
    this.isSerialized = false,
  });

  final String productId;
  final Decimal qty;
  final Decimal? unitCost;
  final bool isSerialized;
}

class OpeningStockInput {
  const OpeningStockInput({
    required this.warehouseId,
    required this.date,
    required this.notes,
    required this.lines,
  });

  final String warehouseId;
  final DateTime date;
  final String notes;
  final List<OpeningStockLineInput> lines;
}

class OpeningStockValidator {
  const OpeningStockValidator();

  ValidationResult validate(OpeningStockInput input) {
    final codes = <String>[];

    if (input.warehouseId.trim().isEmpty) {
      codes.add(FinanceException.validationWarehouseRequired);
    }
    if (input.notes.trim().isEmpty) {
      codes.add(FinanceException.validationNotesRequired);
    }
    if (input.lines.isEmpty) {
      codes.add(FinanceException.validationLinesRequired);
    }

    for (final line in input.lines) {
      if (line.productId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
      }
      if (line.isSerialized) {
        codes.add(FinanceException.validationSerializedNotSupported);
      }
      if (line.qty <= Decimal.zero) {
        codes.add(FinanceException.validationLineQtyInvalid);
      }
      if (line.unitCost == null || line.unitCost! < Decimal.zero) {
        codes.add(FinanceException.validationCostRequired);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
