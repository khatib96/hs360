import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/invoices/domain/return_invoice_draft.dart';
import 'validation_result.dart';

class ReturnInvoiceValidator {
  const ReturnInvoiceValidator();

  ValidationResult validate(
    ReturnInvoiceDraft draft, {
    Map<String, Decimal> returnableQtyByLineId = const {},
    Set<String> serializedLineIds = const {},
  }) {
    final codes = <String>[];

    if (draft.originalInvoiceId.trim().isEmpty) {
      codes.add(FinanceException.validationOriginalInvoiceRequired);
    }
    if (draft.warehouseId.trim().isEmpty) {
      codes.add(FinanceException.validationWarehouseRequired);
    }
    if (draft.reason.trim().isEmpty) {
      codes.add(FinanceException.validationReturnReasonRequired);
    }
    if (draft.lines.isEmpty) {
      codes.add(FinanceException.validationLinesRequired);
    }

    for (final line in draft.lines) {
      if (line.originalInvoiceLineId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
        continue;
      }
      if (line.qty <= Decimal.zero) {
        codes.add(FinanceException.validationLineQtyInvalid);
      }
      final returnable = returnableQtyByLineId[line.originalInvoiceLineId];
      if (returnable != null && line.qty > returnable) {
        codes.add(FinanceException.validationReturnQtyExceedsReturnable);
      }
      if (serializedLineIds.contains(line.originalInvoiceLineId) &&
          (line.productUnitId == null || line.productUnitId!.trim().isEmpty)) {
        codes.add(FinanceException.validationSerializedUnitRequired);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
