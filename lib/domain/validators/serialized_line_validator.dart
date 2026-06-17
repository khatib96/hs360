import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/invoices/domain/invoice_draft.dart';
import 'validation_result.dart';

/// Validates serialized product line unit selection and count parity.
class SerializedLineValidator {
  const SerializedLineValidator();

  ValidationResult validateSalesLine({
    required Decimal qty,
    required bool isSerialized,
    String? productUnitId,
  }) {
    if (!isSerialized) return const ValidationResult.valid();
    if (productUnitId == null || productUnitId.trim().isEmpty) {
      return const ValidationResult(
        codes: [FinanceException.validationSerializedUnitRequired],
      );
    }
    return _validateQtyPositive(qty);
  }

  ValidationResult validatePurchaseLine({
    required InvoiceDraftLine line,
    required bool isSerialized,
  }) {
    if (!isSerialized) return _validateQtyPositive(line.qty);

    final unitCount = line.units.length;
    if (unitCount == 0) {
      return const ValidationResult(
        codes: [FinanceException.validationSerializedUnitRequired],
      );
    }
    if (line.qty != Decimal.fromInt(unitCount)) {
      return const ValidationResult(
        codes: [FinanceException.validationSerialCountMismatch],
      );
    }
    return const ValidationResult.valid();
  }

  ValidationResult _validateQtyPositive(Decimal qty) {
    if (qty <= Decimal.zero) {
      return const ValidationResult(
        codes: [FinanceException.validationLineQtyInvalid],
      );
    }
    return const ValidationResult.valid();
  }
}
