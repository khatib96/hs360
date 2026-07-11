import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/core/scanning/data/scan_repository.dart';
import 'package:hs360/core/scanning/domain/scan_result.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/presentation/contract_display_helpers.dart';
import 'package:hs360/features/contracts/presentation/contract_form_controller.dart';
import 'package:hs360/features/contracts/presentation/contract_form_unit_filter.dart';
import 'package:hs360/features/contracts/presentation/contract_form_draft_builder.dart';
import 'package:hs360/features/contracts/presentation/contract_form_state.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/domain/customer_service_location.dart';
import 'package:hs360/features/customers/domain/service_location_type.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/data/product_unit_repository.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/product_unit.dart';
import 'package:hs360/features/products/domain/product_unit_health_status.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/features/products/domain/unit_status.dart';

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

AppSession _createSession({bool isManager = false}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: isManager,
      permissions: const {'contracts.create', 'contracts.view'},
    ),
  );
}

Product _assetProduct({String id = 'prod-asset', bool isSerialized = true}) {
  return Product(
    id: id,
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
    isSerialized: isSerialized,
    trackableForMaintenance: true,
    isActive: true,
  );
}

Product _consumableProduct({String id = 'prod-consumable'}) {
  return Product(
    id: id,
    tenantId: 't',
    sku: 'OIL-1',
    nameAr: 'زيت',
    nameEn: 'Oil',
    groupId: 'g-1',
    productType: ProductType.consumableRental,
    canBeSold: false,
    canBeRented: true,
    unitPrimary: UnitOfMeasure.ml,
    conversionFactor: Decimal.one,
    salePrice: Decimal.zero,
    isSerialized: false,
    trackableForMaintenance: false,
    isActive: true,
  );
}

ProductUnit _unit({required String id, required UnitStatus status}) {
  return ProductUnit(
    id: id,
    tenantId: 't',
    productId: 'prod-asset',
    serialNumber: 'SN-$id',
    barcode: 'BC-$id',
    status: status,
    healthStatus: ProductUnitHealthStatus.good,
    acquiredAt: DateTime(2026, 1, 1),
  );
}

class FakeScanRepository extends ScanRepository {
  FakeScanRepository(this.results) : super(null);

  final Map<String, ScanResult> results;

  @override
  Future<ScanResult> resolveScanCode(String code) async {
    final result = results[code.trim()];
    if (result == null) throw Exception('not found');
    return result;
  }
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

Future<void> _fillValidTrialForm(ContractFormController notifier) async {
  await notifier.selectCustomer(sampleCustomer());
  notifier.selectServiceLocation('loc-1');
  notifier.addAssetLine();
  await notifier.selectAssetProduct(0, _assetProduct());
  notifier.setAssetUnit(0, 'unit-1');
}

void main() {
  group('ContractFormController', () {
    test('missing customer fails validation', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith(
            (ref) => FakeContractRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      notifier.setType(ContractType.rental);
      notifier.setMonthlyRentalValue(Decimal.fromInt(120));

      final result = notifier.validate();
      expect(
        result.codes,
        contains(FinanceException.validationCustomerRequired),
      );
    });

    test('creates trial contract with idempotency key', () async {
      final repo = FakeContractRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
          customerRepositoryProvider.overrideWith(
            (ref) => FakeCustomerRepository(customers: [sampleCustomer()]),
          ),
          customerServiceLocationRepositoryProvider.overrideWith(
            (ref) =>
                FakeCustomerServiceLocationRepository(locations: [_location()]),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(),
          ),
          productUnitRepositoryProvider.overrideWith(
            (ref) => FakeProductUnitRepository(
              units: [_unit(id: 'unit-1', status: UnitStatus.availableNew)],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      await _fillValidTrialForm(notifier);

      final code = await notifier.submit();
      expect(code, isNull);
      expect(repo.lastCreateDraft?.type, ContractType.trial);
      expect(repo.lastCreateDraft?.trialDays, 3);
      expect(repo.lastCreateDraft?.billingDay, isNull);
      expect(repo.lastCreateDraft?.refillDay, isNull);
      expect(repo.lastIdempotencyKey, isNotEmpty);
    });

    test('creates rental contract', () async {
      final repo = FakeContractRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
          customerRepositoryProvider.overrideWith(
            (ref) => FakeCustomerRepository(customers: [sampleCustomer()]),
          ),
          customerServiceLocationRepositoryProvider.overrideWith(
            (ref) =>
                FakeCustomerServiceLocationRepository(locations: [_location()]),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(),
          ),
          productUnitRepositoryProvider.overrideWith(
            (ref) => FakeProductUnitRepository(
              units: [_unit(id: 'unit-1', status: UnitStatus.availableUsed)],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      notifier.setStartDate(DateTime(2026, 7, 10));
      notifier.setType(ContractType.rental);
      notifier.setMonthlyRentalValue(Decimal.fromInt(150));
      await _fillValidTrialForm(notifier);

      final code = await notifier.submit();
      expect(code, isNull);
      expect(repo.lastCreateDraft?.type, ContractType.rental);
      expect(repo.lastCreateDraft?.monthlyRentalValue, Decimal.fromInt(150));
      expect(repo.lastCreateDraft?.billingDay, 10);
      expect(repo.lastCreateDraft?.refillDay, 10);
    });

    test('creates contract for non-serialized asset without unit id', () async {
      final repo = FakeContractRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
          customerRepositoryProvider.overrideWith(
            (ref) => FakeCustomerRepository(customers: [sampleCustomer()]),
          ),
          customerServiceLocationRepositoryProvider.overrideWith(
            (ref) =>
                FakeCustomerServiceLocationRepository(locations: [_location()]),
          ),
          productUnitRepositoryProvider.overrideWith(
            (ref) => FakeProductUnitRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      await notifier.selectCustomer(sampleCustomer());
      notifier.selectServiceLocation('loc-1');
      await notifier.addRentalProduct(_assetProduct(isSerialized: false));

      final code = await notifier.submit();

      expect(code, isNull);
      final line = repo.lastCreateDraft?.assetLines.single;
      expect(line?.productId, 'prod-asset');
      expect(line?.productUnitId, isNull);
      expect(line?.toPayload().containsKey('product_unit_id'), isFalse);
    });

    test('filters available units client-side', () async {
      final units = [
        _unit(id: 'available', status: UnitStatus.availableNew),
        _unit(id: 'rented', status: UnitStatus.rented),
        _unit(id: 'used', status: UnitStatus.availableUsed),
      ];
      final filtered = filterAvailableContractUnits(units);
      expect(filtered.map((u) => u.id), ['available', 'used']);
    });

    test('loads only available units for asset line', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith(
            (ref) => FakeContractRepository(),
          ),
          productUnitRepositoryProvider.overrideWith(
            (ref) => FakeProductUnitRepository(
              units: [
                _unit(id: 'available', status: UnitStatus.availableNew),
                _unit(id: 'rented', status: UnitStatus.rented),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      notifier.addAssetLine();
      await notifier.selectAssetProduct(0, _assetProduct());

      final line = container
          .read(contractFormControllerProvider)
          .assetLines
          .first;
      expect(line.availableUnits, hasLength(1));
      expect(line.availableUnits.first.id, 'available');
    });

    test('adds rental products into the correct draft lines', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith(
            (ref) => FakeContractRepository(),
          ),
          productUnitRepositoryProvider.overrideWith(
            (ref) => FakeProductUnitRepository(
              units: [_unit(id: 'unit-1', status: UnitStatus.availableNew)],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      await notifier.addRentalProduct(_assetProduct());
      await notifier.addRentalProduct(_consumableProduct());

      final state = container.read(contractFormControllerProvider);
      expect(state.assetLines, hasLength(1));
      expect(state.consumableLines, hasLength(1));
    });

    test('resolves scanned serial without preselecting product', () async {
      final unit = _unit(id: 'unit-1', status: UnitStatus.availableNew);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith(
            (ref) => FakeContractRepository(),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(products: [_assetProduct()]),
          ),
          productUnitRepositoryProvider.overrideWith(
            (ref) => FakeProductUnitRepository(units: [unit]),
          ),
          scanRepositoryProvider.overrideWith(
            (ref) => FakeScanRepository({
              'SN-unit-1': const ScanResult(
                id: 'unit-1',
                productId: 'prod-asset',
                kind: ScanResultKind.productUnit,
                matchedBy: ScanMatchedBy.serialNumber,
                displayCode: 'SN-unit-1',
                isActiveOrAvailable: true,
              ),
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      await notifier.addRentalCode('SN-unit-1');

      final line = container
          .read(contractFormControllerProvider)
          .assetLines
          .first;
      expect(line.product?.id, 'prod-asset');
      expect(line.productUnitId, 'unit-1');
    });

    test(
      'rental draft with null endDate assumes 12-month preview duration',
      () {
        final state = ContractFormUiState.initial().copyWith(
          type: ContractType.rental,
          startDate: DateTime(2026, 7, 1),
          monthlyRentalValue: Decimal.fromInt(100),
        );
        final draft = buildContractDraft(state);
        expect(contractDraftDurationMonths(draft), 12);
        expect(contractDraftDisplayTotalValue(draft), Decimal.fromInt(1200));
      },
    );

    test('refreshPreview stores pricing preview for rental', () async {
      final repo = FakeContractRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_createSession()),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(contractFormControllerProvider.notifier);
      notifier.setType(ContractType.rental);
      notifier.setMonthlyRentalValue(Decimal.fromInt(120));
      notifier.addAssetLine();
      await notifier.selectAssetProduct(0, _assetProduct());
      notifier.setAssetUnit(0, 'unit-1');

      await notifier.refreshPreview();

      expect(
        container.read(contractFormControllerProvider).pricingPreview,
        isNotNull,
      );
    });
  });
}
