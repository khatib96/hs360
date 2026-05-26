import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_transfer_form_state.dart';
import 'package:hs360/features/inventory/domain/transfer_warehouse_option.dart';

import '../fake_inventory_repository.dart';

AppSession _session({Set<String> permissions = const {}}) {
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

InventoryTransferFormState _transferForm() {
  return InventoryTransferFormState(
    fromWarehouseId: 'wh-from',
    toWarehouseId: 'wh-to',
    productId: 'p',
    qty: Decimal.fromInt(2),
    notes: 'move stock',
    sourceQtyAvailable: Decimal.fromInt(10),
  );
}

void main() {
  group('InventoryRepository transfer methods', () {
    test('recordInventoryTransfer without permission throws before RPC', () async {
      final fake = FakeInventoryRepository();
      await expectLater(
        fake.recordInventoryTransfer(_session(), _transferForm()),
        throwsA(
          predicate<InventoryException>(
            (e) => e.code == InventoryException.permissionDenied,
          ),
        ),
      );
      expect(fake.transferCallCount, 0);
    });

    test('repository gates permission before RPC', () async {
      final repo = InventoryRepository(null);
      await expectLater(
        repo.recordInventoryTransfer(
          _session(permissions: {'inventory_movements.create'}),
          _transferForm(),
        ),
        throwsA(isA<InventoryException>()),
      );
    });

    test('fake records transfer with create permission', () async {
      final fake = FakeInventoryRepository();
      final id = await fake.recordInventoryTransfer(
        _session(permissions: {'inventory_movements.create'}),
        _transferForm(),
      );
      expect(id, 'transfer-id');
      expect(fake.transferCallCount, 1);
      expect(fake.lastTransferInput?.fromWarehouseId, 'wh-from');
    });

    test('lookup methods require create permission', () async {
      final fake = FakeInventoryRepository();
      await expectLater(
        fake.listTransferWarehouses(_session()),
        throwsA(
          predicate<InventoryException>(
            (e) => e.code == InventoryException.permissionDenied,
          ),
        ),
      );
    });

    test('lookup methods succeed with create permission', () async {
      final fake = FakeInventoryRepository(
        transferWarehouses: const [
          TransferWarehouseOption(
            id: 'w1',
            nameAr: 'ar',
            nameEn: 'Main',
            type: 'main',
          ),
        ],
      );
      final session = _session(permissions: {'inventory_movements.create'});
      final warehouses = await fake.listTransferWarehouses(session);
      expect(warehouses, hasLength(1));
      expect(fake.listTransferWarehousesCallCount, 1);
    });
  });
}
