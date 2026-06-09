import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/inventory/presentation/inventory_adjustment_controller.dart';
import 'package:hs360/features/inventory/presentation/inventory_balances_controller.dart';
import '../fake_inventory_repository.dart';
import '../../products/fake_product_repositories.dart';
import '../fake_warehouse_repository.dart';

AppSession _session({
  Set<String> permissions = const {'inventory_movements.create'},
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

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

void main() {
  group('InventoryAdjustmentController', () {
    test('submit success refreshes balances', () async {
      final inventoryRepo = FakeInventoryRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {
                  'inventory_movements.create',
                  'inventory_movements.view',
                  'products.field.avg_cost',
                  'products.field.last_purchase_cost',
                  'products.field.min_sale_price',
                  'products.field.min_rental_price',
                },
              ),
            ),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryBalancesControllerProvider.notifier)
          .refresh();
      final notifier = container.read(
        inventoryAdjustmentControllerProvider.notifier,
      );

      final error = await notifier.submit(
        movementType: MovementType.adjustmentIn,
        warehouseId: 'wh-1',
        productId: 'p-1',
        qty: Decimal.one,
        notes: 'test in',
        unitCost: Decimal.parse('1.000'),
      );

      expect(error, isNull);
      expect(inventoryRepo.adjustmentCallCount, 1);
    });
  });
}
