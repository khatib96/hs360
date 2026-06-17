import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/inventory_accounting/domain/stock_count_draft.dart';
import 'validation_result.dart';

/// Pre-M4.5 client check for stock count documents.
class StockCountValidator {
  const StockCountValidator();

  ValidationResult validate(StockCountDraft draft) {
    final codes = <String>[];

    if (draft.warehouseId.trim().isEmpty) {
      codes.add(FinanceException.validationWarehouseRequired);
    }
    if (draft.lines.isEmpty) {
      codes.add(FinanceException.validationLinesRequired);
    }

    for (final line in draft.lines) {
      if (line.productId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
      }
      if (line.countedQty < Decimal.zero) {
        codes.add(FinanceException.validationCountedQtyInvalid);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
