import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/domain/customer_form_state.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';

void main() {
  final form = CustomerFormState(
    customerType: CustomerType.individual,
    nameAr: 'عميل',
    nameEn: 'Customer',
    phonePrimary: '+96550000111',
    governorate: 'hawalli',
    area: 'salmiya',
    googleMapsUrl: 'https://maps.example',
    createAccount: true,
    acquiredBy: 'emp-1',
    acquiredAt: DateTime(2024, 1, 15),
  );

  test('toCreatePayload includes acquired fields', () {
    final payload = form.toCreatePayload();
    expect(payload['acquired_by'], 'emp-1');
    expect(payload['acquired_at'], '2024-01-15');
  });

  test('toCreatePayload includes create_account and location', () {
    final payload = form.toCreatePayload();
    expect(payload['create_account'], isTrue);
    expect(payload['governorate'], 'hawalli');
    expect(payload['area'], 'salmiya');
    expect(payload['google_maps_url'], 'https://maps.example');
  });

  test('toCreatePayload omits forbidden keys', () {
    final payload = form.toCreatePayload();
    expect(payload.containsKey('tenant_id'), isFalse);
    expect(payload.containsKey('account_id'), isFalse);
    expect(payload.containsKey('code'), isFalse);
    expect(payload.containsKey('is_active'), isFalse);
  });

  test('toUpdatePayload omits acquired and forbidden keys', () {
    final payload = form.toUpdatePayload();
    expect(payload.containsKey('acquired_by'), isFalse);
    expect(payload.containsKey('acquired_at'), isFalse);
    expect(payload.containsKey('tenant_id'), isFalse);
    expect(payload.containsKey('account_id'), isFalse);
    expect(payload.containsKey('code'), isFalse);
    expect(payload.containsKey('is_active'), isFalse);
    expect(payload.containsKey('create_account'), isFalse);
  });

  test('toUpdatePayload includes M5.5 update fields', () {
    final payload = form.toUpdatePayload();
    expect(payload['name_ar'], 'عميل');
    expect(payload['phone_primary'], '+96550000111');
    expect(payload['governorate'], 'hawalli');
    expect(payload['google_maps_url'], 'https://maps.example');
  });

  test('individual update clears company-only tax_number', () {
    final companyForm = CustomerFormState(
      customerType: CustomerType.individual,
      nameAr: 'عميل',
      phonePrimary: '+96550000111',
      taxNumber: '123',
    );
    expect(companyForm.toUpdatePayload()['tax_number'], isNull);
  });
}
