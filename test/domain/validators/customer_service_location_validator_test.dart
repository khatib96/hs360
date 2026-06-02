import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/domain/validators/customer_service_location_validator.dart';
import 'package:hs360/features/customers/domain/customer_service_location_form_state.dart';

void main() {
  const validator = CustomerServiceLocationValidator();

  test('requires name', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(name: '  '),
    );
    expect(result.isValid, isFalse);
    expect(result.codes, contains(CustomerException.serviceLocationNameRequired));
  });

  test('accepts valid form', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(name: 'Branch'),
    );
    expect(result.isValid, isTrue);
  });
}
