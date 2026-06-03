import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/presentation/customer_detail_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_customer_repository.dart';
import '../fake_customer_service_location_repository.dart';

Future<void> selectCustomerTab(WidgetTester tester, int index) async {
  final tabBar = tester.widget<TabBar>(find.byType(TabBar));
  tabBar.controller!.animateTo(index);
  await tester.pumpAndSettle();
}

void main() {
  AppSession session({Set<String> permissions = const {'customers.view'}}) {
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

  Widget buildDetail({
    required AppSession appSession,
    required FakeCustomerRepository customerRepo,
    FakeCustomerServiceLocationRepository? locationRepo,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(appSession),
        ),
        customerRepositoryProvider.overrideWith((ref) => customerRepo),
        customerServiceLocationRepositoryProvider.overrideWith(
          (ref) => locationRepo ?? FakeCustomerServiceLocationRepository(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(size: Size(1600, 900)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: CustomerDetailScreen(customerId: 'cust-1'),
      ),
    );
  }

  testWidgets('customer detail not found', (tester) async {
    final repo = FakeCustomerRepository(customers: const []);
    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-detail-not-found')), findsOneWidget);
  });

  testWidgets('renders all seven tabs', (tester) async {
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-tab-profile')), findsOneWidget);
    expect(find.byKey(const Key('customer-tab-locations')), findsOneWidget);
    expect(find.byKey(const Key('customer-tab-contracts')), findsOneWidget);
    expect(find.byKey(const Key('customer-tab-invoices')), findsOneWidget);
    expect(find.byKey(const Key('customer-tab-vouchers')), findsOneWidget);
    expect(find.byKey(const Key('customer-tab-statement')), findsOneWidget);
    expect(find.byKey(const Key('customer-tab-timeline')), findsOneWidget);
  });

  testWidgets('locations tab renders with service location fake', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();

    await selectCustomerTab(tester, 1);

    expect(find.text(l10n.serviceLocationEmpty), findsOneWidget);
  });

  testWidgets('statement tab does not call repository before tab select', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(
      customers: [sampleCustomer()],
    );
    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {
          'customers.view',
          'customers.view_ledger',
        }),
        customerRepo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.statementCallCount, 0);
    expect(repo.balanceCallCount, 0);
  });

  testWidgets('statement tab permission denied without view_ledger', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();

    await selectCustomerTab(tester, CustomerDetailScreen.statementTabIndex);

    expect(repo.statementCallCount, 0);
    expect(repo.balanceCallCount, 0);
    expect(find.byKey(const Key('customer-statement-denied')), findsOneWidget);
    expect(find.text(l10n.customerLedgerPermissionDenied), findsOneWidget);
  });

  testWidgets('empty statement with permission renders without error', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {
          'customers.view',
          'customers.view_ledger',
        }),
        customerRepo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await selectCustomerTab(tester, CustomerDetailScreen.statementTabIndex);

    expect(repo.statementCallCount, 1);
    expect(repo.balanceCallCount, 1);
    expect(find.byKey(const Key('customer-statement-loaded')), findsOneWidget);
    expect(find.text(l10n.customerStatementEmpty), findsOneWidget);
  });

  testWidgets('statement tab fetch error shows retry and can recover', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(
      customers: [sampleCustomer()],
      balanceError: const CustomerException(code: CustomerException.unknown),
    );
    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {
          'customers.view',
          'customers.view_ledger',
        }),
        customerRepo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await selectCustomerTab(tester, CustomerDetailScreen.statementTabIndex);

    expect(repo.balanceCallCount, 1);
    expect(repo.statementCallCount, 0);
    expect(find.text(l10n.customerErrorUnknown), findsOneWidget);
    expect(find.byKey(const Key('customer-statement-retry')), findsOneWidget);
    expect(find.text(l10n.customerStatementNotLoaded), findsNothing);

    repo.balanceError = null;
    await tester.tap(find.byKey(const Key('customer-statement-retry')));
    await tester.pumpAndSettle();

    expect(repo.balanceCallCount, 2);
    expect(repo.statementCallCount, 1);
    expect(find.byKey(const Key('customer-statement-loaded')), findsOneWidget);
  });

  testWidgets('contracts tab denied without permission', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);

    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 2);
    expect(find.text(l10n.moduleAccessUnavailable), findsOneWidget);
  });

  testWidgets('contracts tab empty with permission', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);

    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {'customers.view', 'contracts.view'}),
        customerRepo: repo,
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 2);
    expect(find.text(l10n.customerContractsEmpty), findsOneWidget);
  });

  testWidgets('invoices tab denied without permission', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);

    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 3);
    expect(find.text(l10n.moduleAccessUnavailable), findsOneWidget);
  });

  testWidgets('invoices tab empty with permission', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);

    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {'customers.view', 'invoices.view'}),
        customerRepo: repo,
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 3);
    expect(find.text(l10n.customerInvoicesEmpty), findsOneWidget);
  });

  testWidgets('vouchers tab denied without permission', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);

    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 4);
    expect(find.text(l10n.moduleAccessUnavailable), findsOneWidget);
  });

  testWidgets('vouchers tab empty with permission', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);

    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {'customers.view', 'vouchers.view'}),
        customerRepo: repo,
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 4);
    expect(find.text(l10n.customerVouchersEmpty), findsOneWidget);
  });
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
