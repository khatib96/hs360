import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/presentation/customers_hub_screen.dart';
import 'package:hs360/features/suppliers/data/supplier_repository.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_customer_repository.dart';
import '../../suppliers/fake_supplier_repository.dart';

void main() {
  AppSession session({Set<String> permissions = const {}}) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: 'user',
      displayName: 'Test User',
      preferredLocale: 'en',
      permissions: AppPermissions(
        isManager: false,
        permissions: permissions,
      ),
    );
  }

  Widget buildHub({required AppSession appSession}) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(appSession),
        ),
        customerRepositoryProvider
            .overrideWith((ref) => FakeCustomerRepository()),
        supplierRepositoryProvider
            .overrideWith((ref) => FakeSupplierRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1024, 768)),
          child: const CustomersHubScreen(),
        ),
      ),
    );
  }

  testWidgets('suppliers.view only shows supplier list body without tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHub(appSession: session(permissions: {'suppliers.view'})),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suppliers-tab-body')), findsOneWidget);
    expect(find.byKey(const Key('customers-tab-body')), findsNothing);
    expect(find.byKey(const Key('customers-tab')), findsNothing);
    expect(find.byKey(const Key('suppliers-tab')), findsNothing);
  });

  testWidgets('both grants show tab keys and customer list body', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHub(
        appSession: session(
          permissions: {'customers.view', 'suppliers.view'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customers-tab')), findsOneWidget);
    expect(find.byKey(const Key('suppliers-tab')), findsOneWidget);
    expect(find.byKey(const Key('customers-tab-body')), findsOneWidget);

    await tester.tap(find.byKey(const Key('suppliers-tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suppliers-tab-body')), findsOneWidget);
  });

  testWidgets('no tab grants shows module access unavailable', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(buildHub(appSession: session()));
    await tester.pumpAndSettle();

    expect(find.text(l10n.moduleAccessUnavailable), findsOneWidget);
    expect(find.byKey(const Key('customers-tab')), findsNothing);
  });
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
