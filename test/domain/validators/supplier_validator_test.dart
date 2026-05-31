import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/supplier_exception.dart';
import 'package:hs360/domain/validators/supplier_validator.dart';
import 'package:hs360/features/suppliers/domain/supplier_form_state.dart';

void main() {
  const validator = SupplierValidator();

  test('valid form returns no codes', () {
    const form = SupplierFormState(nameAr: 'مورد');
    expect(validator.validate(form).isValid, isTrue);
  });

  test('name_ar_required when name empty', () {
    const form = SupplierFormState(nameAr: ' ');
    expect(
      validator.validate(form).codes,
      contains(SupplierException.nameArRequired),
    );
  });

  test('email_invalid when email lacks @', () {
    const form = SupplierFormState(
      nameAr: 'مورد',
      email: 'bad-email',
    );
    expect(
      validator.validate(form).codes,
      contains(SupplierException.emailInvalid),
    );
  });

  test('optional email empty is valid', () {
    const form = SupplierFormState(nameAr: 'مورد', email: '');
    expect(validator.validate(form).isValid, isTrue);
  });
}
