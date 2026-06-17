import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import 'validation_result.dart';

/// Validates line discount percentage bounds (0–100 inclusive).
class DiscountValidator {
  const DiscountValidator();

  ValidationResult validate(Decimal discountPct) {
    if (discountPct < Decimal.zero || discountPct > Decimal.fromInt(100)) {
      return const ValidationResult(
        codes: [FinanceException.validationDiscountOutOfRange],
      );
    }
    return const ValidationResult.valid();
  }
}
