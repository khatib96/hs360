import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/domain/customer.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';

Customer _customer({String? nameEn, String? accountId}) {
  return Customer(
    id: 'c-1',
    tenantId: 't-1',
    code: 'CUST-0001',
    customerType: CustomerType.individual,
    nameAr: 'عميل',
    nameEn: nameEn,
    phonePrimary: '+96550000111',
    accountId: accountId,
    isActive: true,
    isVip: false,
  );
}

void main() {
  group('Customer.isStandardCodeFormat', () {
    test('accepts CUST-0001', () {
      expect(Customer.isStandardCodeFormat('CUST-0001'), isTrue);
    });

    test('accepts CUST-10000', () {
      expect(Customer.isStandardCodeFormat('CUST-10000'), isTrue);
    });

    test('rejects CUST-001', () {
      expect(Customer.isStandardCodeFormat('CUST-001'), isFalse);
    });

    test('rejects SUP-0001', () {
      expect(Customer.isStandardCodeFormat('SUP-0001'), isFalse);
    });
  });

  group('Customer.displayName', () {
    test('returns Arabic name for ar locale', () {
      expect(_customer(nameEn: 'Customer').displayName('ar'), 'عميل');
    });

    test('returns English name for en locale when present', () {
      expect(_customer(nameEn: 'Customer').displayName('en'), 'Customer');
    });

    test('falls back to Arabic when English missing', () {
      expect(_customer().displayName('en'), 'عميل');
    });
  });

  group('Customer.hasLinkedAccount', () {
    test('false when account_id is null', () {
      expect(_customer(accountId: null).hasLinkedAccount, isFalse);
    });

    test('true when account_id is set', () {
      expect(_customer(accountId: 'a-1').hasLinkedAccount, isTrue);
    });
  });
}
