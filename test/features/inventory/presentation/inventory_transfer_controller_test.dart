import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/transfer_product_option.dart';
import 'package:hs360/features/inventory/presentation/inventory_transfer_controller.dart';

import '../fake_inventory_repository.dart';

AppSession _session({
  Set<String> permissions = const {
    'inventory_movements.create',
    'inventory.view',
  },
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
  group('InventoryTransferController', () {
    test('submit success calls repository', () async {
      final inventoryRepo = FakeInventoryRepository(
        transferSourceQty: Decimal.fromInt(10),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        inventoryTransferControllerProvider.notifier,
      );
      await notifier.selectProduct(
        const TransferProductOption(
          id: 'p-1',
          sku: 'SKU',
          nameAr: 'ar',
          nameEn: 'Product',
          isSerialized: false,
          unitPrimary: 'piece',
        ),
      );
      await notifier.hydrateSourceQty('wh-from');

      final error = await notifier.submit(
        fromWarehouseId: 'wh-from',
        toWarehouseId: 'wh-to',
        productId: 'p-1',
        qty: Decimal.fromInt(2),
        notes: 'move',
      );

      expect(error, isNull);
      expect(inventoryRepo.transferCallCount, 1);
    });

    test(
      'serialized select keeps selectedProduct null and skips qty hydration',
      () async {
        final inventoryRepo = FakeInventoryRepository();
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(_session()),
            ),
            inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          inventoryTransferControllerProvider.notifier,
        );
        await notifier.selectProduct(
          const TransferProductOption(
            id: 'p-ser',
            sku: 'SER',
            nameAr: 'ar',
            nameEn: 'Serialized',
            isSerialized: true,
            unitPrimary: 'piece',
          ),
        );

        final state = container.read(inventoryTransferControllerProvider);
        expect(state.selectedProduct, isNull);
        expect(state.sourceQtyAvailable, isNull);
        expect(
          state.errorCode,
          InventoryException.serializedTransferNotSupported,
        );
        expect(inventoryRepo.getTransferSourceQtyCallCount, 0);
      },
    );

    test(
      'serialized select clears previous non-serialized selection',
      () async {
        final inventoryRepo = FakeInventoryRepository(
          transferSourceQty: Decimal.fromInt(8),
        );
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(_session()),
            ),
            inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          inventoryTransferControllerProvider.notifier,
        );
        await notifier.selectProduct(
          const TransferProductOption(
            id: 'p-normal',
            sku: 'NORMAL',
            nameAr: 'ar',
            nameEn: 'Normal',
            isSerialized: false,
            unitPrimary: 'piece',
          ),
        );
        await notifier.hydrateSourceQty('wh-from');

        await notifier.selectProduct(
          const TransferProductOption(
            id: 'p-ser',
            sku: 'SER',
            nameAr: 'ar',
            nameEn: 'Serialized',
            isSerialized: true,
            unitPrimary: 'piece',
          ),
        );

        final state = container.read(inventoryTransferControllerProvider);
        expect(state.selectedProduct, isNull);
        expect(state.sourceQtyAvailable, isNull);
        expect(
          state.errorCode,
          InventoryException.serializedTransferNotSupported,
        );
      },
    );
  });
}
