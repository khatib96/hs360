import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_movement.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';
import 'package:hs360/features/inventory/presentation/inventory_movements_controller.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import '../fake_inventory_repository.dart';
import '../fake_warehouse_repository.dart';
import '../../products/fake_product_repositories.dart';

AppSession _session({Set<String> permissions = const {'inventory_movements.view'}}) {
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
      permissions: permissions,
    ),
  );
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

InventoryMovement _movement({
  String id = 'm-1',
  String productId = 'p-1',
  String warehouseId = 'wh-1',
}) {
  return InventoryMovement(
    id: id,
    tenantId: 't',
    movementType: MovementType.adjustmentIn,
    warehouseId: warehouseId,
    productId: productId,
    qty: Decimal.fromInt(5),
    occurredAt: DateTime.utc(2026, 5, 15, 10),
  );
}

void main() {
  group('InventoryMovementsController', () {
    test('loads movements and never calls fetchInventoryBalances', () async {
      final inventoryRepo = FakeInventoryRepository(
        movements: [_movement()],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {
                  'inventory_movements.view',
                  'products.view',
                  'warehouses.view',
                },
              ),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith((ref) => FakeProductRepository()),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryMovementsControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryMovementsControllerProvider);
      expect(state.allRows, hasLength(1));
      expect(inventoryRepo.fetchBalancesCount, 0);
      expect(inventoryRepo.fetchMovementsCount, 1);
    });

    test('zero product search matches skips movements repo', () async {
      final inventoryRepo = FakeInventoryRepository(
        movements: [_movement()],
      );
      final productRepo = FakeProductRepository(
        searchProductIdsResult: {},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {
                  'inventory_movements.view',
                  'products.view',
                },
              ),
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
          .read(inventoryMovementsControllerProvider.notifier)
          .refresh();
      inventoryRepo.fetchMovementsCount = 0;

      container
          .read(inventoryMovementsControllerProvider.notifier)
          .setSearch('no-match');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final state = container.read(inventoryMovementsControllerProvider);
      expect(state.allRows, isEmpty);
      expect(productRepo.searchProductIdsCount, greaterThan(0));
      expect(inventoryRepo.fetchMovementsCount, 0);
    });

    test('product search forwards productIds to repo', () async {
      final inventoryRepo = FakeInventoryRepository(
        movements: [_movement(productId: 'p-99')],
      );
      final productRepo = FakeProductRepository(
        searchProductIdsResult: {'p-99'},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {
                  'inventory_movements.view',
                  'products.view',
                },
              ),
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
          .read(inventoryMovementsControllerProvider.notifier)
          .refresh();
      inventoryRepo.fetchMovementsCount = 0;

      container
          .read(inventoryMovementsControllerProvider.notifier)
          .setSearch('sku');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(inventoryRepo.lastProductIds, {'p-99'});
      expect(inventoryRepo.fetchMovementsCount, 1);
    });

    test('passes date boundaries to repo', () async {
      final inventoryRepo = FakeInventoryRepository(movements: [_movement()]);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'inventory_movements.view'}),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith((ref) => FakeProductRepository()),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(inventoryMovementsControllerProvider.notifier);
      notifier.setOccurredFromDate(DateTime(2026, 5, 10));
      notifier.setOccurredToDate(DateTime(2026, 5, 12));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(inventoryRepo.lastOccurredFrom, DateTime(2026, 5, 10));
      expect(inventoryRepo.lastOccurredBefore, DateTime(2026, 5, 13));
    });

    test('inverted date pick clears other endpoint', () async {
      final inventoryRepo = FakeInventoryRepository(movements: [_movement()]);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'inventory_movements.view'}),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith((ref) => FakeProductRepository()),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(inventoryMovementsControllerProvider.notifier);
      notifier.setOccurredToDate(DateTime(2026, 5, 10));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      notifier.setOccurredFromDate(DateTime(2026, 5, 15));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(inventoryMovementsControllerProvider);
      expect(state.occurredFromDate, DateTime(2026, 5, 15));
      expect(state.occurredToDate, isNull);
      expect(inventoryRepo.lastOccurredBefore, isNull);
    });

    test('hydration failure keeps movement rows', () async {
      final inventoryRepo = FakeInventoryRepository(
        movements: [_movement()],
      );
      final productRepo = FakeProductRepository(stockLabelsThrows: true);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {
                  'inventory_movements.view',
                  'products.view',
                },
              ),
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
          .read(inventoryMovementsControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryMovementsControllerProvider);
      expect(state.allRows, hasLength(1));
      expect(state.productLabelsWarningCode, isNotNull);
    });

    test('without products.view uses client search only', () async {
      final inventoryRepo = FakeInventoryRepository(
        movements: [
          _movement(id: 'm-1', productId: 'alpha-product'),
          _movement(id: 'm-2', productId: 'other'),
        ],
      );
      final productRepo = FakeProductRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'inventory_movements.view'}),
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
          .read(inventoryMovementsControllerProvider.notifier)
          .refresh();

      final notifier =
          container.read(inventoryMovementsControllerProvider.notifier);
      notifier.setSearch('alpha');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(productRepo.searchProductIdsCount, 0);
      final state = container.read(inventoryMovementsControllerProvider);
      expect(state.serverSideProductSearch, isFalse);
      expect(state.visibleRows, hasLength(1));
      expect(state.visibleRows.first.productId, 'alpha-product');
    });

    test('permission gate clears state', () async {
      final inventoryRepo = FakeInventoryRepository(movements: [_movement()]);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session(permissions: {})),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith((ref) => FakeProductRepository()),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryMovementsControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryMovementsControllerProvider);
      expect(state.allRows, isEmpty);
      expect(inventoryRepo.fetchMovementsCount, 0);
    });

    test('movements failure sets error', () async {
      final inventoryRepo = FakeInventoryRepository(
        movementsError: const InventoryException(
          code: InventoryException.permissionDenied,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'inventory_movements.view'}),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          productRepositoryProvider.overrideWith((ref) => FakeProductRepository()),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryMovementsControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryMovementsControllerProvider);
      expect(state.errorCode, InventoryException.permissionDenied);
      expect(state.allRows, isEmpty);
    });
  });
}
