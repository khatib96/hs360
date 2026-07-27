import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/presentation/inventory_placeholder_screen.dart';
import 'package:hs360/features/products/data/product_group_repository.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/presentation/product_list_screen.dart';

import '../../features/products/fake_product_repositories.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/app_shell.dart';

void main() {
  AppSession session({
    String accountType = 'user',
    Set<String> permissions = const {},
  }) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: accountType,
      displayName: 'Test User',
      preferredLocale: 'en',
      permissions: AppPermissions(
        isManager: accountType == 'manager',
        permissions: permissions,
      ),
    );
  }

  Widget buildTestApp({
    required AppSession appSession,
    required Widget child,
    Size size = const Size(1024, 768),
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(appSession),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: child,
        ),
      ),
    );
  }

  testWidgets('field user sees field navigation but not dashboard', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'visits.view_assigned'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navAppointmentsVisits), findsOneWidget);
    expect(find.text(l10n.dashboard), findsNothing);
    expect(find.byKey(const Key('shell-search-anchor')), findsNothing);
    expect(find.byKey(const Key('shell-quick-create-anchor')), findsNothing);
    expect(find.byKey(const Key('shell-notifications-anchor')), findsNothing);
  });

  testWidgets('zero-permission user sees no unauthorized dashboard link', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(),
        child: const AppShell(title: 'Blocked', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.dashboard), findsNothing);
  });

  testWidgets(
    'products list hides new product action without create permission',
    (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(session(permissions: {'products.view'})),
            ),
            productRepositoryProvider.overrideWith(
              (ref) => FakeProductRepository(),
            ),
            productGroupRepositoryProvider.overrideWith(
              (ref) => FakeProductGroupRepository(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1024, 768)),
              child: const ProductListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.products), findsWidgets);
      expect(find.text(l10n.productsNew), findsNothing);
    },
  );

  testWidgets('products list exposes create as an in-module command', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              session(permissions: {'products.view', 'products.create'}),
            ),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(),
          ),
          productGroupRepositoryProvider.overrideWith(
            (ref) => FakeProductGroupRepository(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(1024, 768)),
            child: ProductListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell-module-command-bar')), findsOneWidget);
    expect(find.byKey(const Key('product-create-command')), findsOneWidget);
  });

  testWidgets('inventory page hides movement actions without movement grants', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'inventory.view'}),
        child: const InventoryPlaceholderScreen(
          mode: InventoryViewMode.balances,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.inventory), findsWidgets);
    expect(find.text(l10n.inventoryTransfers), findsNothing);
    expect(find.text(l10n.inventoryMovements), findsNothing);
  });

  testWidgets('nested module screen shows back and falls back to module list', (
    tester,
  ) async {
    final appSession = session(permissions: {'contracts.view'});
    final router = GoRouter(
      initialLocation: '/contracts/c-1',
      routes: [
        GoRoute(
          path: AppRoutes.contracts,
          builder: (context, state) => const AppShell(
            title: 'Contracts',
            currentRoute: AppRoutes.contracts,
            body: Text('contracts-list'),
          ),
        ),
        GoRoute(
          path: '/contracts/:id',
          builder: (context, state) => const AppShell(
            title: 'Contract detail',
            currentRoute: AppRoutes.contracts,
            body: Text('contract-detail'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(appSession),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('contracts-list'), findsOneWidget);
  });

  testWidgets('customers.view shows customers navigation item', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'customers.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navCustomersSuppliers), findsOneWidget);
    expect(find.text(l10n.navFinance), findsNothing);
  });

  testWidgets('suppliers.view shows customers navigation item', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'suppliers.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navCustomersSuppliers), findsOneWidget);
  });

  testWidgets('chart_of_accounts.view shows chart of accounts nav item', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'chart_of_accounts.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navFinance), findsOneWidget);
    expect(find.text(l10n.navCustomersSuppliers), findsNothing);
  });

  testWidgets('zero-permission user does not see Phase 4 nav items', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navCustomersSuppliers), findsNothing);
    expect(find.text(l10n.navFinance), findsNothing);
  });

  testWidgets('products.view only does not show Phase 4 nav items', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'products.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navInventory), findsOneWidget);
    expect(find.text(l10n.navCustomersSuppliers), findsNothing);
    expect(find.text(l10n.navFinance), findsNothing);
  });

  testWidgets('invoices.view_sales shows invoices navigation item', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'invoices.view_sales'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navFinance), findsOneWidget);
    expect(find.text(l10n.navInventory), findsNothing);
  });

  testWidgets('vouchers.view shows vouchers navigation item', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'vouchers.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navFinance), findsOneWidget);
    expect(find.text(l10n.navInventory), findsNothing);
  });

  testWidgets('contracts.view shows contracts navigation item', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'contracts.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navContracts), findsOneWidget);
    expect(find.text(l10n.navFinance), findsNothing);
  });

  testWidgets('contracts.create only hides contracts navigation item', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'contracts.create'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navContracts), findsNothing);
  });

  testWidgets('manager sees contracts navigation item', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(accountType: 'manager'),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navContracts), findsOneWidget);
    expect(find.byKey(const Key('shell-search-anchor')), findsOneWidget);
    expect(find.byKey(const Key('shell-quick-create-anchor')), findsOneWidget);
    expect(find.byKey(const Key('shell-notifications-anchor')), findsOneWidget);
  });

  testWidgets('journal.view shows journal navigation item', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'journal.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navFinance), findsOneWidget);
    expect(find.text(l10n.navInventory), findsNothing);
  });

  testWidgets('cash_bank.view shows cash and bank navigation item', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'cash_bank.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navFinance), findsOneWidget);
    expect(find.text(l10n.navInventory), findsNothing);
  });

  testWidgets('finance nav items stay hidden without finance permissions', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'products.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navFinance), findsNothing);
    expect(find.text(l10n.navContracts), findsNothing);
    expect(find.text(l10n.navVouchers), findsNothing);
    expect(find.text(l10n.navJournal), findsNothing);
    expect(find.text(l10n.navCashBank), findsNothing);
  });

  testWidgets('calendar.view shows navCalendar', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'calendar.view'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navAppointmentsVisits), findsOneWidget);
  });

  testWidgets('calendar.view_assigned shows navCalendar', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'calendar.view_assigned'}),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navAppointmentsVisits), findsOneWidget);
  });

  testWidgets(
    'settings.calendar.view alone shows settings nav but not navCalendar',
    (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        buildTestApp(
          appSession: session(permissions: {'settings.calendar.view'}),
          child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.navAppointmentsVisits), findsNothing);
      expect(find.text(l10n.navSettings), findsOneWidget);
    },
  );

  testWidgets('manager shows navCalendar', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(accountType: 'manager'),
        child: const AppShell(title: 'Shell', body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navAppointmentsVisits), findsOneWidget);
  });

  testWidgets('mixed finance permissions expose only authorized context tabs', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(
          permissions: {'invoices.view_sales', 'journal.view'},
        ),
        child: const AppShell(
          title: 'Finance',
          currentRoute: AppRoutes.invoices,
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('shell-contextual-navigation')),
      findsOneWidget,
    );
    expect(find.text(l10n.navInvoices), findsOneWidget);
    expect(find.text(l10n.navJournal), findsOneWidget);
    expect(find.text(l10n.navVouchers), findsNothing);
    expect(find.text(l10n.navCashBank), findsNothing);
  });

  testWidgets('desktop sidebar collapses without losing module access', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'contracts.view', 'products.view'}),
        child: const AppShell(
          title: 'Contracts',
          currentRoute: AppRoutes.contracts,
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.navContracts), findsWidgets);
    expect(find.text(l10n.navInventory), findsOneWidget);
    await tester.tap(find.byKey(const Key('shell-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.navInventory), findsNothing);
    expect(find.byKey(const Key('shell-module-inventory')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow shell uses a permission-shaped drawer', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'contracts.view'}),
        size: const Size(390, 844),
        child: const AppShell(
          title: 'Contracts',
          currentRoute: AppRoutes.contracts,
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-navigation-drawer')), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-navigation-drawer')), findsOneWidget);
    expect(find.text(l10n.navContracts), findsWidgets);
    expect(find.text(l10n.navFinance), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
