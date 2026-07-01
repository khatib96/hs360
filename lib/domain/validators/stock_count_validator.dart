import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/inventory_accounting/domain/stock_count_draft.dart';
import 'validation_result.dart';

class StockCountValidator {
  const StockCountValidator();

  ValidationResult validate(StockCountDraft draft) {
    final codes = <String>[];

    if (draft.warehouseId.trim().isEmpty) {
      codes.add(FinanceException.validationWarehouseRequired);
    }
    if (draft.notes.trim().isEmpty) {
      codes.add(FinanceException.validationNotesRequired);
    }
    if (draft.gainReasonCode.trim().isEmpty) {
      codes.add(FinanceException.validationGainReasonRequired);
    }
    if (draft.lossReasonCode.trim().isEmpty) {
      codes.add(FinanceException.validationLossReasonRequired);
    }
    if (draft.lines.isEmpty) {
      codes.add(FinanceException.validationLinesRequired);
    }

    for (final line in draft.lines) {
      if (line.productId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
      }
      if (line.isSerialized) {
        codes.add(FinanceException.validationSerializedNotSupported);
      }
      if (line.countedQty < Decimal.zero) {
        codes.add(FinanceException.validationCountedQtyInvalid);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
