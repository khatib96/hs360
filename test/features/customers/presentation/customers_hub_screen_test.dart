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
      permissions: AppPermissions(isManager: false, permissions: permissions),
    );
  }

  Widget buildHub({
    required AppSession appSession,
    Locale locale = const Locale('en'),
    Size size = const Size(1024, 768),
    FakeCustomerRepository? customerRepo,
    FakeSupplierRepository? supplierRepo,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(appSession),
        ),
        customerRepositoryProvider.overrideWith(
          (ref) => customerRepo ?? FakeCustomerRepository(),
        ),
        supplierRepositoryProvider.overrideWith(
          (ref) => supplierRepo ?? FakeSupplierRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
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
        appSession: session(permissions: {'customers.view', 'suppliers.view'}),
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

  testWidgets('customer and supplier lists fit a narrow Arabic viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildHub(
        appSession: session(
          permissions: {
            'customers.view',
            'customers.create',
            'customers.edit',
            'customers.delete',
            'suppliers.view',
            'suppliers.create',
            'suppliers.edit',
            'suppliers.delete',
          },
        ),
        locale: const Locale('ar'),
        size: const Size(360, 800),
        customerRepo: FakeCustomerRepository(
          customers: [sampleCustomer(nameAr: 'عميل باسم طويل للاختبار')],
        ),
        supplierRepo: FakeSupplierRepository(
          suppliers: [sampleSupplier(nameAr: 'مورد باسم طويل للاختبار')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('customer-mobile-actions-cust-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('suppliers-tab')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('supplier-mobile-actions-sup-1')),
      findsOneWidget,
    );
  });
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
