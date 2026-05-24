import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/products/domain/product_unit_permissions.dart';

AppSession _session({required AppPermissions permissions}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: permissions.isManager ? 'manager' : 'user',
    displayName: 'Test',
    preferredLocale: 'ar',
    permissions: permissions,
  );
}

void main() {
  test('manager can view create edit units', () {
    final session = _session(permissions: AppPermissions.manager);
    expect(canViewProductUnits(session), isTrue);
    expect(canCreateProductUnits(session), isTrue);
    expect(canEditProductUnits(session), isTrue);
  });

  test('requires explicit product_units permissions', () {
    final session = _session(
      permissions: AppPermissions(
        isManager: false,
        permissions: {'products.view'},
      ),
    );
    expect(canViewProductUnits(session), isFalse);
    expect(canCreateProductUnits(session), isFalse);
  });

  test('create permission does not imply view', () {
    final session = _session(
      permissions: AppPermissions(
        isManager: false,
        permissions: {'product_units.create'},
      ),
    );
    expect(canCreateProductUnits(session), isTrue);
    expect(canViewProductUnits(session), isFalse);
  });
}
