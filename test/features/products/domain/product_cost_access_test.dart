import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/products/domain/product_cost_access.dart';

AppSession _session({
  required AppPermissions permissions,
}) {
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
  group('canViewFullProductCosts', () {
    test('permissions.isManager bypasses field checks', () {
      final session = _session(permissions: AppPermissions.manager);
      expect(canViewFullProductCosts(session), isTrue);
    });

    test('requires all four field permissions', () {
      final session = _session(
        permissions: AppPermissions(
          isManager: false,
          permissions: {
            'products.field.avg_cost',
            'products.field.last_purchase_cost',
            'products.field.min_sale_price',
            'products.field.min_rental_price',
          },
        ),
      );
      expect(canViewFullProductCosts(session), isTrue);
    });

    test('partial permissions returns false', () {
      final session = _session(
        permissions: AppPermissions(
          isManager: false,
          permissions: {'products.field.avg_cost'},
        ),
      );
      expect(canViewFullProductCosts(session), isFalse);
    });

    test('accountType manager without permissions.isManager is false', () {
      final session = AppSession(
        userId: 'u',
        email: 'e@test.com',
        tenantId: 't',
        tenantUserId: 'tu',
        accountType: 'manager',
        displayName: 'Test',
        preferredLocale: 'ar',
        permissions: AppPermissions(
          isManager: false,
          permissions: const {},
        ),
      );
      expect(canViewFullProductCosts(session), isFalse);
    });

    test('unauthorized reads use products_safe and safe columns', () {
      final session = _session(
        permissions: AppPermissions(
          isManager: false,
          permissions: {'products.view'},
        ),
      );

      expect(productReadTableForSession(session), 'products_safe');
      expect(productReadColumnsForSession(session), isNot(contains('avg_cost')));
      expect(
        productReadColumnsForSession(session),
        isNot(contains('last_purchase_cost')),
      );
      expect(
        productReadColumnsForSession(session),
        isNot(contains('min_sale_price')),
      );
    });

    test('unauthorized mutation response requests id only', () {
      final session = _session(
        permissions: AppPermissions(
          isManager: false,
          permissions: {'products.view', 'products.create'},
        ),
      );

      expect(productMutationReturnColumnsForSession(session), 'id');
    });

    test('authorized mutation response may return full product columns', () {
      final session = _session(permissions: AppPermissions.manager);

      expect(
        productMutationReturnColumnsForSession(session),
        contains('avg_cost'),
      );
    });
  });
}
