import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_pricing_preview.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/presentation/contract_create_screen.dart';
import 'package:hs360/features/contracts/presentation/contract_form_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/domain/customer_service_location.dart';
import 'package:hs360/features/customers/domain/service_location_type.dart';
import 'package:hs360/features/invoices/presentation/widgets/invoice_sheet.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/data/product_unit_repository.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/product_unit.dart';
import 'package:hs360/features/products/domain/product_unit_health_status.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/features/products/domain/unit_status.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_contract_repository.dart';
import '../../customers/fake_customer_repository.dart';
import '../../customers/fake_customer_service_location_repository.dart';
import '../../products/fake_product_repositories.dart';
import '../../products/fake_product_unit_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _createSession({
  Set<String> permissions = const {'contracts.create'},
}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

Product _assetProduct() {
  return Product(
    id: 'prod-asset',
    tenantId: 't',
    sku: 'ASSET-1',
    nameAr: 'جهاز',
    nameEn: 'Device',
    groupId: 'g-1',
    productType: ProductType.assetRental,
    canBeSold: false,
    canBeRented: true,
    unitPrimary: UnitOfMeasure.piece,
    conversionFactor: Decimal.one,
    salePrice: Decimal.zero,
    isSerialized: true,
    trackableForMaintenance: true,
    isActive: true,
  );
}

ProductUnit _unit() {
  return ProductUnit(
    id: 'unit-1',
    tenantId: 't',
    productId: 'prod-asset',
    serialNumber: 'SN-001',
    status: UnitStatus.availableNew,
    healthStatus: ProductUnitHealthStatus.good,
    acquiredAt: DateTime(2026, 1, 1),
  );
}

CustomerServiceLocation _location() {
  return CustomerServiceLocation(
    id: 'loc-1',
    tenantId: 't',
    customerId: 'cust-1',
    code: 'LOC-0001',
    name: 'Main site',
    locationType: ServiceLocationType.branch,
    isPrimary: true,
    isActive: true,
  );
}

Widget _wrap({
  required AppSession session,
  required FakeContractRepository contractRepo,
  required List<String> pushedRoutes,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      contractRepositoryProvider.overrideWith((ref) => contractRepo),
      customerRepositoryProvider.overrideWith(
        (ref) => FakeCustomerRepository(customers: [sampleCustomer()]),
      ),
      customerServiceLocationRepositoryProvider.overrideWith(
        (ref) =>
            FakeCustomerServiceLocationRepository(locations: [_location()]),
      ),
      productRepositoryProvider.overrideWith(
        (ref) => FakeProductRepository(products: [_assetProduct()]),
      ),
      productUnitRepositoryProvider.overrideWith(
        (ref) => FakeProductUnitRepository(units: [_unit()]),
      ),
      localeProvider.overrideWithValue(const Locale('en')),
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: AppRoutes.contractsNew,
            builder: (context, state) => const ContractCreateScreen(),
          ),
          GoRoute(
            path: '/contracts/:id',
            builder: (context, state) {
              pushedRoutes.add(state.uri.toString());
              return const Scaffold(body: Text('detail'));
            },
          ),
        ],
        initialLocation: AppRoutes.contractsNew,
      ),
    ),
  );
}

void main() {
  testWidgets('shows permission denied when user cannot create', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      _wrap(
        session: _createSession(permissions: const {}),
        contractRepo: FakeContractRepository(),
        pushedRoutes: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.financeModuleAccessUnavailable), findsOneWidget);
  });

  testWidgets('renders contract form sections', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      _wrap(
        session: _createSession(),
        contractRepo: FakeContractRepository(),
        pushedRoutes: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.contractSectionOverview), findsOneWidget);
    expect(find.text(l10n.contractSectionProducts), findsOneWidget);
  });

  testWidgets('adds and removes rental product lines', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      _wrap(
        session: _createSession(),
        contractRepo: FakeContractRepository(),
        pushedRoutes: [],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContractCreateScreen)),
    );
    final notifier = container.read(contractFormControllerProvider.notifier);
    await notifier.addRentalProduct(_assetProduct());
    await tester.pumpAndSettle();

    expect(find.text('Device'), findsWidgets);

    notifier.removeAssetLine(0);
    await tester.pumpAndSettle();

    expect(find.text(l10n.contractProductsEmpty), findsOneWidget);
  });

  testWidgets('rental without endDate shows 12-month duration preview', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      _wrap(
        session: _createSession(),
        contractRepo: FakeContractRepository(),
        pushedRoutes: [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.contractTypeRental));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contract-monthly-rental')),
      '100',
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.contractDurationMonths(12)), findsWidgets);
  });

  testWidgets('keeps financial details hidden without a cost permission', (
    tester,
  ) async {
    final repo = FakeContractRepository(
      pricingPreview: ContractPricingPreview(
        monthlyRentalValue: Decimal.fromInt(100),
        assetMonthlyCost: Decimal.fromInt(25),
        totalMonthlyCost: Decimal.fromInt(25),
        expectedMonthlyProfit: Decimal.fromInt(75),
      ),
    );
    await tester.pumpWidget(
      _wrap(session: _createSession(), contractRepo: repo, pushedRoutes: []),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContractCreateScreen)),
    );
    final notifier = container.read(contractFormControllerProvider.notifier);
    notifier.setType(ContractType.rental);
    await notifier.addRentalProduct(_assetProduct());
    notifier.setAssetUnit(0, 'unit-1');
    notifier.setMonthlyRentalValue(Decimal.fromInt(100));
    await notifier.refreshPreview();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contract-financial-details')), findsNothing);
    expect(find.text('Monthly rental value'), findsWidgets);
  });

  testWidgets('shows financial details only to an authorized user', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeContractRepository(
      pricingPreview: ContractPricingPreview(
        monthlyRentalValue: Decimal.fromInt(100),
        totalMonthlyCost: Decimal.fromInt(25),
        expectedMonthlyProfit: Decimal.fromInt(75),
        assetLines: [
          ContractPreviewAssetLine(
            productId: 'prod-asset',
            sourceUnitCost: Decimal.fromInt(600),
            monthlyCost: Decimal.fromInt(25),
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _wrap(
        session: _createSession(
          permissions: const {
            'contracts.create',
            'contracts.field.snapshot_device_cost',
            'contracts.field.snapshot_total_cost',
            'contracts.field.snapshot_profit',
          },
        ),
        contractRepo: repo,
        pushedRoutes: [],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContractCreateScreen)),
    );
    final notifier = container.read(contractFormControllerProvider.notifier);
    notifier.setType(ContractType.rental);
    await notifier.addRentalProduct(_assetProduct());
    notifier.setAssetUnit(0, 'unit-1');
    notifier.setMonthlyRentalValue(Decimal.fromInt(100));
    await notifier.refreshPreview();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contract-financial-details')), findsOneWidget);
    expect(find.text(l10n.contractFieldDeviceMonthlyCost), findsNothing);
    expect(find.text(l10n.contractFieldOilMonthlyCost), findsNothing);

    await tester.drag(
      find.descendant(
        of: find.byType(InvoiceSheet),
        matching: find.byType(ListView),
      ),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.contractFinancialDetails));
    await tester.pumpAndSettle();

    final financial = find.byKey(const Key('contract-financial-details'));
    expect(
      find.descendant(of: financial, matching: find.text('Device')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: financial,
        matching: find.text(l10n.contractFieldQuantity),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: financial,
        matching: find.text(l10n.contractFieldUnitCost),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: financial,
        matching: find.text(l10n.contractFieldMonthlyCost),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: financial,
        matching: find.text(l10n.contractFieldTotalMonthlyCost),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: financial,
        matching: find.text(l10n.contractFieldNetMonthlyProfit),
      ),
      findsOneWidget,
    );
  });

  testWidgets('manual product and unit selection submits trial contract', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeContractRepository(createdContractId: 'contract-new');
    final pushedRoutes = <String>[];

    await tester.pumpWidget(
      _wrap(
        session: _createSession(
          permissions: const {'contracts.create', 'contracts.view'},
        ),
        contractRepo: repo,
        pushedRoutes: pushedRoutes,
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContractCreateScreen)),
    );
    final notifier = container.read(contractFormControllerProvider.notifier);
    await notifier.selectCustomer(sampleCustomer());
    notifier.selectServiceLocation('loc-1');
    notifier.addAssetLine();
    await notifier.selectAssetProduct(0, _assetProduct());
    notifier.setAssetUnit(0, 'unit-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contract-create-submit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.contractCreateTrial),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lastCreateDraft?.type, ContractType.trial);
    expect(repo.listCallCount, greaterThan(0));
    expect(pushedRoutes, [AppRoutes.contractDetailPath('contract-new')]);
  });
}
