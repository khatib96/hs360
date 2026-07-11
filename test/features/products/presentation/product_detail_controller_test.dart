import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/products/data/product_group_repository.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/data/product_unit_repository.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_stock_summary.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/features/products/presentation/product_detail_controller.dart';

import '../../inventory/fake_warehouse_repository.dart';
import '../fake_product_repositories.dart';
import '../fake_product_unit_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({Set<String> permissions = const {}}) {
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
    id: 'prod-1',
    tenantId: 't',
    sku: 'HS',
    nameAr: 'جهاز',
    nameEn: 'Device',
    groupId: 'g-1',
    productType: ProductType.assetRental,
    canBeSold: false,
    canBeRented: true,
    unitPrimary: UnitOfMeasure.piece,
    conversionFactor: Decimal.one,
    salePrice: Decimal.zero,
    isSerialized: false,
    trackableForMaintenance: true,
    isActive: true,
  );
}

ProductStockSummary _stock() {
  return ProductStockSummary(
    productId: 'prod-1',
    totalQtyAvailable: Decimal.fromInt(2),
    balances: [
      InventoryBalance(
        id: 'bal-1',
        tenantId: 't',
        warehouseId: 'wh-1',
        productId: 'prod-1',
        qtyAvailable: Decimal.fromInt(2),
        qtyRented: Decimal.zero,
        qtyTrial: Decimal.zero,
        qtyMaintenance: Decimal.zero,
        qtyDamaged: Decimal.zero,
      ),
    ],
  );
}

Future<void> _waitForLoad(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final state = container.read(productDetailControllerProvider('prod-1'));
    if (!state.isLoading && state.product != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test(
    'prepares serial tracking through repository and reloads product',
    () async {
      final unitRepo = FakeProductUnitRepository();
      final productRepo = FakeProductRepository(
        productById: _assetProduct(),
        stockSummary: _stock(),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: const {
                  'products.view',
                  'inventory.view',
                  'warehouses.view',
                  'product_units.reconcile_serials',
                },
              ),
            ),
          ),
          productRepositoryProvider.overrideWith((ref) => productRepo),
          productGroupRepositoryProvider.overrideWith(
            (ref) => FakeProductGroupRepository(),
          ),
          productUnitRepositoryProvider.overrideWith((ref) => unitRepo),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(
              warehouses: [sampleWarehouse(id: 'wh-1')],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _waitForLoad(container);

      final controller = container.read(
        productDetailControllerProvider('prod-1').notifier,
      );
      final code = await controller.prepareSerialTracking(
        productId: 'prod-1',
        warehouseId: 'wh-1',
        serials: const ['HS-0001', 'HS-0002'],
        reason: 'opening labels',
      );

      expect(code, isNull);
      expect(unitRepo.lastPreparedWarehouseId, 'wh-1');
      expect(unitRepo.lastPreparedSerials, ['HS-0001', 'HS-0002']);
      expect(unitRepo.lastPrepareReason, 'opening labels');
      expect(productRepo.stockFetchCount, greaterThanOrEqualTo(2));
    },
  );
}
