import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account.dart';
import 'package:hs360/features/accounting/domain/chart_account_policy.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

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

  test('system category root has no edit/deactivate actions and no badge', () {
    final root = ChartAccount(
      id: 'root-assets',
      tenantId: 't',
      code: '1000',
      nameAr: 'الأصول',
      nameEn: 'Assets',
      type: AccountType.asset,
      isSubaccount: false,
      isActive: true,
      isSystem: true,
    );
    final session = AppSession(
      userId: 'u',
      email: 'e@test.com',
      tenantId: 't',
      tenantUserId: 'tu',
      accountType: 'user',
      displayName: 'Test',
      preferredLocale: 'en',
      permissions: AppPermissions(
        isManager: false,
        permissions: {
          'chart_of_accounts.view',
          'chart_of_accounts.edit',
          'chart_of_accounts.delete',
        },
      ),
    );

    final actions = deriveAllowedActions(root, session);
    expect(actions.canEdit, isFalse);
    expect(actions.canDeactivate, isFalse);
    expect(deriveAccountBadges(root), isEmpty);
  });
}
