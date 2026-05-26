import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/domain/validators/inventory_adjustment_validator.dart';
import 'package:hs360/features/inventory/domain/inventory_adjustment_form_state.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';

void main() {
  const validator = InventoryAdjustmentValidator();

  test('rejects empty notes', () {
    final result = validator.validate(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: 'p',
        qty: Decimal.one,
        movementType: MovementType.adjustmentIn,
        unitCost: Decimal.zero,
        notes: '   ',
      ),
    );
    expect(result.isValid, isFalse);
  });

  test('adjustment_in requires unit cost', () {
    final result = validator.validate(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: 'p',
        qty: Decimal.one,
        movementType: MovementType.adjustmentIn,
        notes: 'stock in',
      ),
    );
    expect(result.codes, contains(InventoryException.validationFailed));
  });

  test('valid adjustment_in passes', () {
    final result = validator.validate(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: 'p',
        qty: Decimal.one,
        movementType: MovementType.adjustmentIn,
        unitCost: Decimal.zero,
        notes: 'opening stock',
      ),
    );
    expect(result.isValid, isTrue);
  });

  test('rejects empty warehouse', () {
    final result = validator.validate(
      InventoryAdjustmentFormState(
        warehouseId: '   ',
        productId: 'p',
        qty: Decimal.one,
        movementType: MovementType.adjustmentOut,
        notes: 'out',
        currentQtyAvailable: Decimal.fromInt(10),
      ),
    );
    expect(result.codes, contains(InventoryException.warehouseRequired));
  });

  test('rejects empty product', () {
    final result = validator.validate(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: '',
        qty: Decimal.one,
        movementType: MovementType.adjustmentOut,
        notes: 'out',
        currentQtyAvailable: Decimal.fromInt(10),
      ),
    );
    expect(result.codes, contains(InventoryException.productRequired));
  });

  test('rejects insufficient stock on adjustment_out', () {
    final result = validator.validate(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: 'p',
        qty: Decimal.fromInt(10),
        movementType: MovementType.adjustmentOut,
        notes: 'out',
        currentQtyAvailable: Decimal.fromInt(5),
      ),
    );
    expect(result.codes, contains(InventoryException.insufficientStock));
  });

  test('serialized product rejected', () {
    final result = validator.validate(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: 'p',
        qty: Decimal.one,
        movementType: MovementType.adjustmentOut,
        notes: 'out',
        isSerialized: true,
        currentQtyAvailable: Decimal.fromInt(10),
      ),
    );
    expect(
      result.codes,
      contains(InventoryException.serializedAdjustmentNotSupported),
    );
  });
}
