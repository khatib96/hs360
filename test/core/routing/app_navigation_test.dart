import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/routing/app_navigation.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

void main() {
  AppSession session({
    String accountType = 'user',
    Set<String> permissions = const {},
  }) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tenant-user-1',
      accountType: accountType,
      displayName: 'Test User',
      preferredLocale: 'en',
      permissions: AppPermissions(
        isManager: accountType == 'manager',
        permissions: permissions,
      ),
    );
  }

  group('Phase 7.5 M2 typed module metadata', () {
    test('zero-permission user sees no business or settings modules', () {
      final appSession = session();
      expect(visibleNavigationModules(appSession), isEmpty);
      expect(canShowGlobalSearchAnchor(appSession), isFalse);
      expect(canShowQuickCreateAnchor(appSession), isFalse);
      expect(canShowNotificationsAnchor(appSession), isFalse);
    });

    test('global anchors are independently permission-shaped', () {
      final searchOnly = session(permissions: {'products.view'});
      expect(canShowGlobalSearchAnchor(searchOnly), isTrue);
      expect(canShowQuickCreateAnchor(searchOnly), isFalse);
      expect(canShowNotificationsAnchor(searchOnly), isFalse);

      final documentSearchOnly = session(permissions: {'vouchers.view'});
      expect(canShowGlobalSearchAnchor(documentSearchOnly), isTrue);
      expect(canShowQuickCreateAnchor(documentSearchOnly), isFalse);

      final createOnly = session(permissions: {'contracts.create'});
      expect(canShowGlobalSearchAnchor(createOnly), isFalse);
      expect(canShowQuickCreateAnchor(createOnly), isTrue);
      expect(canShowNotificationsAnchor(createOnly), isFalse);

      final notificationsOnly = session(permissions: {'notifications.view'});
      expect(canShowGlobalSearchAnchor(notificationsOnly), isFalse);
      expect(canShowQuickCreateAnchor(notificationsOnly), isFalse);
      expect(canShowNotificationsAnchor(notificationsOnly), isTrue);
    });

    test('single finance permission preserves dashboard home and finance', () {
      final appSession = session(permissions: {'journal.view'});
      final modules = visibleNavigationModules(appSession);
      final finance = modules.singleWhere(
        (module) => module.id == AppModuleId.finance,
      );

      expect(modules.map((module) => module.id), [
        AppModuleId.dashboard,
        AppModuleId.finance,
      ]);
      expect(
        finance
            .visibleDestinations(appSession)
            .map((destination) => destination.route),
        [AppRoutes.journal],
      );
      expect(finance.landingRoute(appSession), AppRoutes.journal);
    });

    test('module resolution groups detail paths without changing URLs', () {
      final appSession = session(
        permissions: {
          'contracts.view',
          'customers.view',
          'invoices.view_sales',
          'products.view',
        },
      );

      expect(
        resolveNavigationModule(Uri(path: '/contracts/c-1'), appSession)?.id,
        AppModuleId.contracts,
      );
      expect(
        resolveNavigationModule(
          Uri(path: '/customers/c-1/edit'),
          appSession,
        )?.id,
        AppModuleId.parties,
      );
      expect(
        resolveNavigationModule(Uri(path: '/invoices/i-1'), appSession)?.id,
        AppModuleId.finance,
      );
      expect(
        resolveNavigationModule(
          Uri(path: '/product-units/u-1'),
          appSession,
        )?.id,
        AppModuleId.inventory,
      );
    });

    test('Daily Activity is a primary module shaped by source permission', () {
      final field = session(permissions: {'visits.view_assigned'});
      final dailyActivity = visibleNavigationModules(
        field,
      ).singleWhere((module) => module.id == AppModuleId.dailyActivity);

      expect(
        dailyActivity
            .visibleDestinations(field)
            .map((destination) => destination.route),
        [AppRoutes.dailyActivity],
      );
      expect(dailyActivity.landingRoute(field), AppRoutes.dailyActivity);
    });

    test(
      'audit is an independent system module shaped by audit permission',
      () {
        final auditViewer = session(permissions: {'audit_log.view'});
        final modules = visibleNavigationModules(auditViewer);
        final audit = modules.singleWhere(
          (module) => module.id == AppModuleId.audit,
        );

        expect(modules.map((module) => module.id), [AppModuleId.audit]);
        expect(audit.area, AppNavigationArea.system);
        expect(audit.landingRoute(auditViewer), AppRoutes.auditLog);
      },
    );

    test('document preview inherits its authorized source module', () {
      final appSession = session(permissions: {'contracts.view'});
      final uri = Uri(
        path: AppRoutes.documentPreview,
        queryParameters: {'kind': 'contract', 'entityId': 'contract-1'},
      );

      expect(
        resolveNavigationModule(uri, appSession)?.id,
        AppModuleId.contracts,
      );
      expect(shellBackTarget(uri, appSession, null), '/contracts/contract-1');
    });
  });

  group('Phase 7.5 M2 deterministic back targets', () {
    final manager = session(accountType: 'manager');

    test('calendar route preserves its date context', () {
      final uri = Uri.parse('/calendar/route?date=2026-07-25');
      expect(shellBackTarget(uri, manager, null), '/calendar?date=2026-07-25');
    });

    test('edit, convert, and return paths return to their source records', () {
      expect(
        shellBackTarget(Uri(path: '/products/p-1/edit'), manager, null),
        '/products/p-1',
      );
      expect(
        shellBackTarget(Uri(path: '/customers/c-1/edit'), manager, null),
        '/customers/c-1',
      );
      expect(
        shellBackTarget(
          Uri(path: '/contracts/contract-1/convert'),
          manager,
          null,
        ),
        '/contracts/contract-1',
      );
      expect(
        shellBackTarget(Uri(path: '/invoices/invoice-1/return'), manager, null),
        '/invoices/invoice-1',
      );
    });

    test('inventory commands return to stable module parents', () {
      expect(
        shellBackTarget(Uri(path: AppRoutes.inventoryTransfers), manager, null),
        AppRoutes.inventory,
      );
      expect(
        shellBackTarget(
          Uri(path: AppRoutes.inventoryDocumentsStockCount),
          manager,
          null,
        ),
        AppRoutes.inventoryDocuments,
      );
    });
  });
}
