import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory_accounting/data/inventory_document_repository.dart';
import 'package:hs360/features/inventory_accounting/presentation/inventory_document_form_controller.dart';
import 'package:hs360/features/inventory_accounting/presentation/inventory_document_form_mode.dart';
import 'package:hs360/features/products/data/product_unit_repository.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/product_unit.dart';
import 'package:hs360/features/products/domain/product_unit_health_status.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/features/products/domain/unit_status.dart';

import '../../inventory/fake_warehouse_repository.dart';
import '../../products/fake_product_unit_repository.dart';
import '../fake_inventory_document_repository.dart';

AppSession _session() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: {
        'inventory_documents.create_opening',
        'inventory_documents.create_adjustment',
      },
    ),
  );
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession session;
  @override
  FutureOr<AppSession?> build() => session;
}

Product _serializedProduct() {
  return Product(
    id: 'p-serial',
    tenantId: 't-1',
    sku: 'SKU-SERIAL',
    nameAr: 'مُسلسل',
    nameEn: 'Serialized',
    groupId: 'g-1',
    productType: ProductType.saleOnly,
    canBeSold: true,
    canBeRented: false,
    unitPrimary: UnitOfMeasure.piece,
    conversionFactor: Decimal.one,
    salePrice: Decimal.fromInt(100),
    isSerialized: true,
    trackableForMaintenance: false,
    isActive: true,
  );
}

ProductUnit _unit({
  required String id,
  required UnitStatus status,
}) {
  return ProductUnit(
    id: id,
    tenantId: 't-1',
    productId: 'p-serial',
    serialNumber: 'SN-$id',
    status: status,
    currentWarehouseId: 'wh-1',
    healthStatus: ProductUnitHealthStatus.good,
    acquiredAt: DateTime(2026, 1, 1),
  );
}

Future<void> _waitForMeta(ProviderContainer container, dynamic provider) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(provider);
    if (!state.isLoadingMeta) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('InventoryDocumentFormController', () {
    test('submit with missing product returns validation error without crash', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => TestAuthController(_session())),
          inventoryDocumentRepositoryProvider.overrideWith(
            (ref) => FakeInventoryDocumentRepository(),
          ),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(warehouses: const []),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = inventoryDocumentFormControllerProvider(
        InventoryDocumentFormMode.openingStock,
      );
      await _waitForMeta(container, provider);

      final notifier = container.read(provider.notifier);
      notifier.setWarehouseId('wh-1');
      notifier.setNotes('Opening notes');

      final result = await notifier.submit();

      expect(result, FinanceException.validationProductRequired);
      final state = container.read(provider);
      expect(
        state.validationCodes,
        contains(FinanceException.validationProductRequired),
      );
      expect(state.isSubmitting, isFalse);
    });

    test('serialized opening stock submit stays blocked', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => TestAuthController(_session())),
          inventoryDocumentRepositoryProvider.overrideWith(
            (ref) => FakeInventoryDocumentRepository(),
          ),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(warehouses: const []),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = inventoryDocumentFormControllerProvider(
        InventoryDocumentFormMode.openingStock,
      );
      await _waitForMeta(container, provider);

      final notifier = container.read(provider.notifier);
      notifier.setWarehouseId('wh-1');
      notifier.setNotes('Opening notes');
      await notifier.selectProduct(0, _serializedProduct());
      notifier.setLineQty(0, Decimal.one);
      notifier.setLineUnitCost(0, Decimal.one);

      final result = await notifier.submit();

      expect(result, FinanceException.validationSerializedNotSupported);
      expect(
        container.read(provider).validationCodes,
        contains(FinanceException.validationSerializedNotSupported),
      );
    });

    test('stock-out includes available_new and available_used units', () async {
      final unitRepo = FakeProductUnitRepository(
        units: [
          _unit(id: 'new-1', status: UnitStatus.availableNew),
          _unit(id: 'used-1', status: UnitStatus.availableUsed),
          _unit(id: 'rented-1', status: UnitStatus.rented),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => TestAuthController(_session())),
          inventoryDocumentRepositoryProvider.overrideWith(
            (ref) => FakeInventoryDocumentRepository(),
          ),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(warehouses: const []),
          ),
          productUnitRepositoryProvider.overrideWith((ref) => unitRepo),
        ],
      );
      addTearDown(container.dispose);

      final provider = inventoryDocumentFormControllerProvider(
        InventoryDocumentFormMode.stockOut,
      );
      await _waitForMeta(container, provider);

      final notifier = container.read(provider.notifier);
      notifier.setWarehouseId('wh-1');
      await notifier.selectProduct(0, _serializedProduct());

      final state = container.read(provider);
      expect(state.availableUnits, hasLength(2));
      expect(
        state.availableUnits.map((unit) => unit.status).toSet(),
        equals({UnitStatus.availableNew, UnitStatus.availableUsed}),
      );
    });
  });
}
