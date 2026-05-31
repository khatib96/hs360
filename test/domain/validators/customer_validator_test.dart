import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/domain/validators/customer_validator.dart';
import 'package:hs360/features/customers/domain/customer_form_state.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';

CustomerFormState _validForm() {
  return CustomerFormState(
    nameAr: 'عميل',
    phonePrimary: '+96550000111',
    creditLimit: Decimal.fromInt(100),
  );
}

void main() {
  const validator = CustomerValidator();

  test('valid form returns no codes', () {
    expect(validator.validate(_validForm()).isValid, isTrue);
  });

  test('name_ar_required when name empty', () {
    final form = CustomerFormState(
      nameAr: ' ',
      phonePrimary: '+96550000111',
    );
    expect(
      validator.validate(form).codes,
      contains(CustomerException.nameArRequired),
    );
  });

  test('phone_primary_required when phone empty', () {
    final form = CustomerFormState(nameAr: 'عميل', phonePrimary: '');
    expect(
      validator.validate(form).codes,
      contains(CustomerException.phonePrimaryRequired),
    );
  });

  test('negative_credit_limit rejected', () {
    final form = CustomerFormState(
      nameAr: 'عميل',
      phonePrimary: '+96550000111',
      creditLimit: Decimal.fromInt(-1),
    );
    expect(
      validator.validate(form).codes,
      contains(CustomerException.negativeCreditLimit),
    );
  });

  test('negative_payment_terms rejected', () {
    final form = CustomerFormState(
      nameAr: 'عميل',
      phonePrimary: '+96550000111',
      paymentTermsDays: -1,
    );
    expect(
      validator.validate(form).codes,
      contains(CustomerException.negativePaymentTerms),
    );
  });

  test('gps_invalid when only lat set', () {
    final form = CustomerFormState(
      nameAr: 'عميل',
      phonePrimary: '+96550000111',
      gpsLat: Decimal.fromInt(29),
    );
    expect(
      validator.validate(form).codes,
      contains(CustomerException.gpsInvalid),
    );
  });

  test('gps_invalid when lat out of range', () {
    final form = CustomerFormState(
      nameAr: 'عميل',
      phonePrimary: '+96550000111',
      gpsLat: Decimal.fromInt(91),
      gpsLng: Decimal.fromInt(48),
    );
    expect(
      validator.validate(form).codes,
      contains(CustomerException.gpsInvalid),
    );
  });

  test('email_invalid when email lacks @', () {
    final form = CustomerFormState(
      nameAr: 'عميل',
      phonePrimary: '+96550000111',
      email: 'not-an-email',
    );
    expect(
      validator.validate(form).codes,
      contains(CustomerException.emailInvalid),
    );
  });

  test('company customer type is valid', () {
    final form = CustomerFormState(
      customerType: CustomerType.company,
      nameAr: 'شركة',
      phonePrimary: '+96550000111',
    );
    expect(validator.validate(form).isValid, isTrue);
  });
}
