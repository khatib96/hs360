import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_adjustment_form_state.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';

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

InventoryAdjustmentFormState _stockInForm({Decimal? unitCost}) {
  return InventoryAdjustmentFormState(
    warehouseId: 'wh',
    productId: 'p',
    qty: Decimal.one,
    movementType: MovementType.adjustmentIn,
    unitCost: unitCost,
    notes: 'in',
  );
}

void main() {
  group('InventoryRepository.recordInventoryAdjustment', () {
    test('adjustment_in without cost permission throws before RPC', () async {
      final fake = FakeInventoryRepository();
      await expectLater(
        fake.recordInventoryAdjustment(
          _session(permissions: {'inventory_movements.create'}),
          _stockInForm(),
        ),
        throwsA(
          predicate<InventoryException>(
            (e) => e.code == InventoryException.permissionDenied,
          ),
        ),
      );
      expect(fake.adjustmentCallCount, 0);
    });

    test('repository gates permission before RPC', () async {
      final repo = InventoryRepository(null);
      await expectLater(
        repo.recordInventoryAdjustment(
          _session(permissions: {'inventory_movements.create'}),
          _stockInForm(),
        ),
        throwsA(
          predicate<InventoryException>(
            (e) => e.code == InventoryException.permissionDenied,
          ),
        ),
      );
    });

    test('fake records adjustment_out with create-only permission', () async {
      final fake = FakeInventoryRepository();
      final id = await fake.recordInventoryAdjustment(
        _session(permissions: {'inventory_movements.create'}),
        InventoryAdjustmentFormState(
          warehouseId: 'wh',
          productId: 'p',
          qty: Decimal.one,
          movementType: MovementType.adjustmentOut,
          notes: 'out',
          currentQtyAvailable: Decimal.fromInt(5),
        ),
      );
      expect(id, 'movement-id');
      expect(fake.adjustmentCallCount, 1);
    });
  });
}
