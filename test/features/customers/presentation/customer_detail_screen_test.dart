import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/domain/customer_service_location.dart';
import 'package:hs360/features/customers/domain/service_location_coordinates.dart';
import 'package:hs360/features/customers/domain/service_location_type.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/customers/presentation/customer_detail_screen.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../contracts/fake_contract_repository.dart';
import '../../invoices/fake_invoice_repository.dart';
import '../../vouchers/fake_voucher_repository.dart';
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
      permissions: AppPermissions(isManager: false, permissions: permissions),
    );
  }

  Widget buildDetail({
    required AppSession appSession,
    required FakeCustomerRepository customerRepo,
    FakeCustomerServiceLocationRepository? locationRepo,
    FakeInvoiceRepository? invoiceRepo,
    FakeVoucherRepository? voucherRepo,
    FakeContractRepository? contractRepo,
    Locale locale = const Locale('en'),
    Size size = const Size(1600, 900),
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
        if (invoiceRepo != null)
          invoiceRepositoryProvider.overrideWith((ref) => invoiceRepo),
        if (voucherRepo != null)
          voucherRepositoryProvider.overrideWith((ref) => voucherRepo),
        if (contractRepo != null)
          contractRepositoryProvider.overrideWith((ref) => contractRepo),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(size: size),
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

  testWidgets('locations tab renders with service location fake', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    await tester.pumpWidget(
      buildDetail(appSession: session(), customerRepo: repo),
    );
    await tester.pumpAndSettle();

    await selectCustomerTab(tester, 1);

    expect(find.text(l10n.serviceLocationEmpty), findsOneWidget);
  });

  testWidgets('locations tab shows coordinate source and accuracy', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    final locationRepo = FakeCustomerServiceLocationRepository(
      locations: [
        CustomerServiceLocation(
          id: 'location-1',
          tenantId: 'tenant-1',
          customerId: 'cust-1',
          code: 'LOC-0001',
          name: 'Main site',
          locationType: ServiceLocationType.branch,
          isPrimary: true,
          isActive: true,
          latitude: 29.3759,
          longitude: 47.9774,
          resolutionSource: CoordinateResolutionSource.deviceGps,
          resolvedAt: DateTime.utc(2026, 6, 6, 8, 30),
          coordinateAccuracyM: 4.25,
          resolutionStatus: CoordinateResolutionStatus.resolved,
        ),
      ],
    );
    await tester.pumpWidget(
      buildDetail(
        appSession: session(),
        customerRepo: repo,
        locationRepo: locationRepo,
      ),
    );
    await tester.pumpAndSettle();

    await selectCustomerTab(tester, 1);

    expect(find.text('29.375900, 47.977400'), findsOneWidget);
    expect(find.textContaining('Device GPS'), findsOneWidget);
    expect(find.textContaining('Accuracy: 4.3 m'), findsOneWidget);
  });

  testWidgets('statement tab does not call repository before tab select', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    await tester.pumpWidget(
      buildDetail(
        appSession: session(
          permissions: {'customers.view', 'customers.view_ledger'},
        ),
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
        appSession: session(
          permissions: {'customers.view', 'customers.view_ledger'},
        ),
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
        appSession: session(
          permissions: {'customers.view', 'customers.view_ledger'},
        ),
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

  testWidgets('contracts tab shows error when list fails', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    final contractRepo = FakeContractRepository(
      fetchError: const FinanceException(code: FinanceException.unknown),
    );

    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {'customers.view', 'contracts.view'}),
        customerRepo: repo,
        contractRepo: contractRepo,
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, CustomerDetailScreen.contractsTabIndex);
    await tester.pumpAndSettle();
    expect(find.text(l10n.financeErrorUnknown), findsOneWidget);
  });

  testWidgets('contracts tab shows rows from fake repository', (tester) async {
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    final contractRepo = FakeContractRepository(
      summaries: [sampleContractSummary(id: 'contract-1')],
    );

    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {'customers.view', 'contracts.view'}),
        customerRepo: repo,
        contractRepo: contractRepo,
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, CustomerDetailScreen.contractsTabIndex);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contract-compact-table')), findsOneWidget);
    expect(find.text('CON-001'), findsOneWidget);
  });

  testWidgets('contracts tab lazy load waits until tab selected', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    final contractRepo = FakeContractRepository(
      summaries: [sampleContractSummary()],
    );

    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {'customers.view', 'contracts.view'}),
        customerRepo: repo,
        contractRepo: contractRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(contractRepo.listCallCount, 0);

    await selectCustomerTab(tester, CustomerDetailScreen.contractsTabIndex);
    await tester.pumpAndSettle();

    expect(contractRepo.listCallCount, 1);
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

  testWidgets('contracts tab does not load with create permission only', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
    final contractRepo = FakeContractRepository();

    await tester.pumpWidget(
      buildDetail(
        appSession: session(
          permissions: {'customers.view', 'contracts.create'},
        ),
        customerRepo: repo,
        contractRepo: contractRepo,
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, CustomerDetailScreen.contractsTabIndex);
    await tester.pumpAndSettle();

    expect(contractRepo.listCallCount, 0);
    expect(find.byKey(const Key('customer-contracts-denied')), findsOneWidget);
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
        appSession: session(
          permissions: {'customers.view', 'invoices.view_sales'},
        ),
        customerRepo: repo,
        invoiceRepo: FakeInvoiceRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 3);
    await tester.pumpAndSettle();
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
        voucherRepo: FakeVoucherRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await selectCustomerTab(tester, 4);
    await tester.pumpAndSettle();
    expect(find.text(l10n.customerVouchersEmpty), findsOneWidget);
  });

  testWidgets('customer detail and locations fit a narrow Arabic viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeCustomerRepository(
      customers: [
        sampleCustomer(nameAr: 'عميل باسم طويل لاختبار العرض المتجاوب'),
      ],
    );
    final locationRepo = FakeCustomerServiceLocationRepository(
      locations: [
        CustomerServiceLocation(
          id: 'location-1',
          tenantId: 'tenant-1',
          customerId: 'cust-1',
          code: 'LOC-0001',
          name: 'الموقع الرئيسي باسم طويل',
          locationType: ServiceLocationType.branch,
          isPrimary: true,
          isActive: true,
          latitude: 25.7800955,
          longitude: 55.9693682,
          resolutionSource: CoordinateResolutionSource.url,
          resolvedAt: DateTime.utc(2026, 6, 6),
          resolutionStatus: CoordinateResolutionStatus.resolved,
        ),
      ],
    );

    await tester.pumpWidget(
      buildDetail(
        appSession: session(permissions: {'customers.view', 'customers.edit'}),
        customerRepo: repo,
        locationRepo: locationRepo,
        locale: const Locale('ar'),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await selectCustomerTab(tester, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('25.780096, 55.969368'), findsOneWidget);
  });
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
