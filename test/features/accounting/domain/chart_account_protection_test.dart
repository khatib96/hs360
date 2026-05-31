import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account.dart';

ChartAccount _account({
  required bool isSystem,
  String? relatedEntityId,
  String? relatedEntityTable,
}) {
  return ChartAccount(
    id: 'a-1',
    tenantId: 't',
    code: '1201.0001',
    nameAr: 'عميل',
    nameEn: 'Customer AR',
    type: AccountType.asset,
    isSubaccount: true,
    relatedEntityTable: relatedEntityTable,
    relatedEntityId: relatedEntityId,
    isActive: true,
    isSystem: isSystem,
  );
}

void main() {
  test('manual account can be edited and deactivated', () {
    final account = _account(isSystem: false);
    expect(account.canManualEdit, isTrue);
    expect(account.canManualDeactivate, isTrue);
  });

  test('system account cannot be edited or deactivated', () {
    final account = _account(isSystem: true);
    expect(account.canManualEdit, isFalse);
    expect(account.canManualDeactivate, isFalse);
  });

  test('entity-linked account cannot be edited or deactivated', () {
    final account = _account(
      isSystem: false,
      relatedEntityId: 'cust-1',
      relatedEntityTable: 'customers',
    );
    expect(account.isEntityLinked, isTrue);
    expect(account.isCustomerSubaccount, isTrue);
    expect(account.canManualEdit, isFalse);
    expect(account.canManualDeactivate, isFalse);
  });
}
