import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/domain/customer_form_state.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';

void main() {
  final form = CustomerFormState(
    customerType: CustomerType.individual,
    nameAr: 'عميل',
    nameEn: 'Customer',
    phonePrimary: '+96550000111',
    creditLimit: Decimal.fromInt(50),
    acquiredBy: 'emp-1',
    acquiredAt: DateTime(2024, 1, 15),
  );

  test('toCreatePayload includes acquired fields', () {
    final payload = form.toCreatePayload();
    expect(payload['acquired_by'], 'emp-1');
    expect(payload['acquired_at'], '2024-01-15');
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
  });

  test('toUpdatePayload includes M2 update fields', () {
    final payload = form.toUpdatePayload();
    expect(payload['name_ar'], 'عميل');
    expect(payload['phone_primary'], '+96550000111');
    expect(payload['credit_limit'], '50');
  });

  test('toUpdatePayload includes nullable gps keys so edits can clear them', () {
    final payload = form.toUpdatePayload();
    expect(payload.containsKey('gps_lat'), isTrue);
    expect(payload.containsKey('gps_lng'), isTrue);
    expect(payload['gps_lat'], isNull);
    expect(payload['gps_lng'], isNull);
  });
}
