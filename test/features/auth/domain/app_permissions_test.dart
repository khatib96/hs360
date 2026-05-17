import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';

void main() {
  group('AppPermissions', () {
    test('manager allows everything', () {
      final perms = AppPermissions.manager;

      expect(perms.can('products.delete'), isTrue);
      expect(perms.hasAny(['a', 'b']), isTrue);
      expect(perms.hasModule('customers'), isTrue);
    });

    test('normal user allows granted permission only', () {
      final perms = AppPermissions(
        isManager: false,
        permissions: {'products.view'},
      );

      expect(perms.can('products.view'), isTrue);
      expect(perms.can('products.delete'), isFalse);
    });

    test('hasAny works', () {
      final perms = AppPermissions(
        isManager: false,
        permissions: {'products.view'},
      );

      expect(perms.hasAny(['products.view', 'products.delete']), isTrue);
      expect(perms.hasAny(['customers.view', 'invoices.view']), isFalse);
    });

    test('hasModule works', () {
      final perms = AppPermissions(
        isManager: false,
        permissions: {'products.view'},
      );

      expect(perms.hasModule('products'), isTrue);
      expect(perms.hasModule('customers'), isFalse);
    });

    test('zero-permission user denies everything', () {
      final perms = AppPermissions.empty;

      expect(perms.can('dashboard.view'), isFalse);
      expect(perms.hasAny(['dashboard.view']), isFalse);
      expect(perms.hasModule('products'), isFalse);
    });

    test('fromRpc parses manager with empty permissions list', () {
      final perms = AppPermissions.fromRpc({
        'is_manager': true,
        'permissions': <String>[],
      });

      expect(perms.isManager, isTrue);
      expect(perms.permissions, isEmpty);
      expect(perms.can('anything'), isTrue);
    });

    test('fromRpc parses granted permissions', () {
      final perms = AppPermissions.fromRpc({
        'is_manager': false,
        'permissions': ['products.view', 'dashboard.view'],
      });

      expect(perms.isManager, isFalse);
      expect(perms.can('products.view'), isTrue);
      expect(perms.can('contracts.view'), isFalse);
    });
  });
}
