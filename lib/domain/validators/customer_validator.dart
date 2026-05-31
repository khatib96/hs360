import 'package:decimal/decimal.dart';

import '../../core/errors/customer_exception.dart';
import '../../features/customers/domain/customer_form_state.dart';
import 'validation_result.dart';

class CustomerValidator {
  const CustomerValidator();

  ValidationResult validate(CustomerFormState input) {
    final codes = <String>[];

    if (input.nameAr.trim().isEmpty) {
      codes.add(CustomerException.nameArRequired);
    }
    if (input.phonePrimary.trim().isEmpty) {
      codes.add(CustomerException.phonePrimaryRequired);
    }
    if (input.creditLimit < Decimal.zero) {
      codes.add(CustomerException.negativeCreditLimit);
    }
    if (input.paymentTermsDays < 0) {
      codes.add(CustomerException.negativePaymentTerms);
    }

    _validateGps(input.gpsLat, input.gpsLng, codes);
    _validateEmail(input.email, codes);

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  void _validateGps(Decimal? lat, Decimal? lng, List<String> codes) {
    if (lat == null && lng == null) return;
    if (lat == null || lng == null) {
      codes.add(CustomerException.gpsInvalid);
      return;
    }

    if (lat < Decimal.fromInt(-90) || lat > Decimal.fromInt(90)) {
      codes.add(CustomerException.gpsInvalid);
    }
    if (lng < Decimal.fromInt(-180) || lng > Decimal.fromInt(180)) {
      codes.add(CustomerException.gpsInvalid);
    }
  }

  void _validateEmail(String? email, List<String> codes) {
    final trimmed = email?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (!trimmed.contains('@')) {
      codes.add(CustomerException.emailInvalid);
    }
  }
}
