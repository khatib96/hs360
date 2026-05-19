import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/core/routing/route_guards.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

void main() {
  AppSession session({
    required String accountType,
    Set<String> permissions = const {},
  }) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: accountType,
      displayName: 'Test User',
      preferredLocale: 'ar',
      permissions: AppPermissions(
        isManager: accountType == 'manager',
        permissions: permissions,
      ),
    );
  }

  AsyncValue<AppSession?> loaded(AppSession value) => AsyncData(value);

  group('resolveHomeRoute', () {
    test('manager -> dashboard', () {
      expect(
        resolveHomeRoute(session(accountType: 'manager')),
        AppRoutes.dashboard,
      );
    });

    test('field permissions -> field today', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'visits.view_assigned'}),
        ),
        AppRoutes.fieldToday,
      );
    });

    test('office permissions -> dashboard', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'products.view'}),
        ),
        AppRoutes.dashboard,
      );
    });

    test('zero permissions -> blocked', () {
      expect(resolveHomeRoute(session(accountType: 'user')), AppRoutes.blocked);
    });

    test('field + office -> field today wins', () {
      expect(
        resolveHomeRoute(
          session(
            accountType: 'user',
            permissions: {'products.view', 'visits.view_assigned'},
          ),
        ),
        AppRoutes.fieldToday,
      );
    });
  });

  group('guardRedirectForPath', () {
    test('unauthenticated protected route -> login', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: false,
          authState: const AsyncData(null),
        ),
        AppRoutes.login,
      );
    });

    test('unauthenticated public route -> null', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.login,
          hasSupabaseSession: false,
          authState: const AsyncData(null),
        ),
        isNull,
      );
    });

    test('manager on login -> dashboard', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: AppRoutes.login,
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        AppRoutes.dashboard,
      );
    });

    test('field user on dashboard -> field today', () {
      final fieldUser = session(
        accountType: 'user',
        permissions: {'visits.view_assigned'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: loaded(fieldUser),
        ),
        AppRoutes.fieldToday,
      );
    });

    test('products user on field today -> dashboard', () {
      final productsUser = session(
        accountType: 'user',
        permissions: {'products.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.fieldToday,
          hasSupabaseSession: true,
          authState: loaded(productsUser),
        ),
        AppRoutes.dashboard,
      );
    });

    test('zero user on dashboard -> blocked', () {
      final zeroUser = session(accountType: 'user');
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: loaded(zeroUser),
        ),
        AppRoutes.blocked,
      );
    });

    test('loading on protected route -> null', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: const AsyncLoading(),
        ),
        isNull,
      );
    });

    test('error on login with session -> null (no home loop)', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.login,
          hasSupabaseSession: true,
          authState: AsyncError(Exception('fail'), StackTrace.empty),
        ),
        isNull,
      );
    });

    test('error on protected route -> login', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: AsyncError(Exception('fail'), StackTrace.empty),
        ),
        AppRoutes.login,
      );
    });

    test('manager on dashboard when home is dashboard -> null', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        isNull,
      );
    });

    test('field user on field today when home is field today -> null', () {
      final fieldUser = session(
        accountType: 'user',
        permissions: {'visits.view_assigned'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.fieldToday,
          hasSupabaseSession: true,
          authState: loaded(fieldUser),
        ),
        isNull,
      );
    });

    test('zero user on blocked when home is blocked -> null', () {
      final zeroUser = session(accountType: 'user');
      expect(
        guardRedirectForPath(
          path: AppRoutes.blocked,
          hasSupabaseSession: true,
          authState: loaded(zeroUser),
        ),
        isNull,
      );
    });

    test('manager on forgot-password -> dashboard', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: AppRoutes.forgotPassword,
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        AppRoutes.dashboard,
      );
    });

    test('field user on forgot-password -> field today', () {
      final fieldUser = session(
        accountType: 'user',
        permissions: {'visits.view_assigned'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.forgotPassword,
          hasSupabaseSession: true,
          authState: loaded(fieldUser),
        ),
        AppRoutes.fieldToday,
      );
    });

    test('root path when authenticated -> home', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: '/',
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        AppRoutes.dashboard,
      );
    });
  });
}
