import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/presentation/inventory_balances_controller.dart';
import 'package:hs360/features/inventory/presentation/inventory_balance_display_helpers.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/domain/product_stock_label.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_inventory_repository.dart';
import '../fake_warehouse_repository.dart';
import '../../products/fake_product_repositories.dart';

AppSession _session({Set<String> permissions = const {'inventory.view'}}) {
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

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

InventoryBalance _balance({
  String productId = 'p-1',
  String warehouseId = 'wh-1',
}) {
  return InventoryBalance(
    id: 'b-1',
    tenantId: 't',
    warehouseId: warehouseId,
    productId: productId,
    qtyAvailable: Decimal.fromInt(10),
    qtyRented: Decimal.zero,
    qtyTrial: Decimal.zero,
    qtyMaintenance: Decimal.zero,
    qtyDamaged: Decimal.zero,
  );
}

void main() {
  group('InventoryBalancesController', () {
    test('balances failure sets error and clears rows', () async {
      final inventoryRepo = FakeInventoryRepository(
        balancesError: const InventoryException(
          code: InventoryException.permissionDenied,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {
                  'inventory.view',
                  'products.view',
                  'warehouses.view',
                },
              ),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(),
          ),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryBalancesControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryBalancesControllerProvider);
      expect(state.errorCode, InventoryException.permissionDenied);
      expect(state.allRows, isEmpty);
      expect(inventoryRepo.fetchMovementsCount, 0);
    });

    test('product label hydration failure keeps rows with fallback', () async {
      final inventoryRepo = FakeInventoryRepository(balances: [_balance()]);
      final productRepo = FakeProductRepository(stockLabelsThrows: true);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'inventory.view', 'products.view'}),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith((ref) => productRepo),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryBalancesControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryBalancesControllerProvider);
      expect(state.errorCode, isNull);
      expect(state.allRows, hasLength(1));
      expect(state.productLabelsWarningCode, ProductsException.unknown);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final label = inventoryBalanceProductLabel(
        state.allRows.first,
        'en',
        l10n,
      );
      expect(label, contains(l10n.inventoryBalanceNameUnavailable));
    });

    test('warehouse hydration failure keeps rows', () async {
      final inventoryRepo = FakeInventoryRepository(balances: [_balance()]);
      final warehouseRepo = FakeWarehouseRepository();
      warehouseRepo.fetchWarehousesError = const ProductsException(
        code: ProductsException.unknown,
      );

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {
                  'inventory.view',
                  'products.view',
                  'warehouses.view',
                },
              ),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(
              stockLabelsById: {
                'p-1': const ProductStockLabel(
                  id: 'p-1',
                  sku: 'SKU',
                  nameAr: 'ع',
                  nameEn: 'Product',
                ),
              },
            ),
          ),
          warehouseRepositoryProvider.overrideWith((ref) => warehouseRepo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryBalancesControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryBalancesControllerProvider);
      expect(state.errorCode, isNull);
      expect(state.allRows, hasLength(1));
      expect(state.warehouseLabelsWarningCode, ProductsException.unknown);
    });
  });
}
