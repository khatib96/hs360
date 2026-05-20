import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/presentation/inventory_placeholder_screen.dart';
import 'package:hs360/features/products/presentation/products_placeholder_screen.dart';
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
        child: const AppShell(
          title: 'Shell',
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.fieldTodayTitle), findsOneWidget);
    expect(find.text(l10n.dashboard), findsNothing);
  });

  testWidgets('zero-permission user sees no unauthorized dashboard link', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(),
        child: const AppShell(
          title: 'Blocked',
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.dashboard), findsNothing);
  });

  testWidgets('products list hides new product action without create permission', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      buildTestApp(
        appSession: session(permissions: {'products.view'}),
        child: const ProductsPlaceholderScreen(mode: ProductsViewMode.list),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.products), findsWidgets);
    expect(find.text(l10n.productsNew), findsNothing);
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
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
