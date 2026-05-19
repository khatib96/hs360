import 'package:decimal/decimal.dart';

import '../../core/errors/inventory_exception.dart';
import '../../domain/validators/validation_result.dart';

/// Primary/secondary unit conversion (matches DB helpers in migration 035).
class UnitConversionService {
  const UnitConversionService();

  Decimal toPrimary(Decimal qtySecondary, Decimal conversionFactor) {
    validateConversionFactor(conversionFactor);
    return qtySecondary * conversionFactor;
  }

  Decimal toSecondary(Decimal qtyPrimary, Decimal conversionFactor) {
    validateConversionFactor(conversionFactor);
    return (qtyPrimary / conversionFactor).toDecimal(
      scaleOnInfinitePrecision: 6,
    );
  }

  ValidationResult validateConversionFactorResult(Decimal factor) {
    if (factor <= Decimal.zero) {
      return const ValidationResult(
        codes: [InventoryException.validationFailed],
      );
    }
    return const ValidationResult.valid();
  }

  void validateConversionFactor(Decimal factor) {
    final result = validateConversionFactorResult(factor);
    if (!result.isValid) {
      throw const FormatException('conversion_factor must be > 0');
    }
  }
}
