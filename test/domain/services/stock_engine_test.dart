import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/domain/services/stock_engine.dart';
import 'package:hs360/features/inventory/domain/inventory_adjustment_form_state.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';

void main() {
  const engine = StockEngine();

  test('previewAdjustmentDelta in is positive', () {
    expect(
      engine.previewAdjustmentDelta(MovementType.adjustmentIn, Decimal.fromInt(5)),
      Decimal.fromInt(5),
    );
  });

  test('previewAdjustmentDelta out is negative', () {
    expect(
      engine.previewAdjustmentDelta(MovementType.adjustmentOut, Decimal.fromInt(5)),
      Decimal.fromInt(-5),
    );
  });

  test('rejects serialized bulk adjustment', () {
    final result = engine.validateAdjustment(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: 'p',
        qty: Decimal.one,
        movementType: MovementType.adjustmentIn,
        unitCost: Decimal.zero,
        notes: 'test',
        isSerialized: true,
      ),
    );
    expect(
      result.codes,
      contains(InventoryException.serializedAdjustmentNotSupported),
    );
  });

  test('rejects insufficient stock on adjustment_out', () {
    final result = engine.validateAdjustment(
      InventoryAdjustmentFormState(
        warehouseId: 'w',
        productId: 'p',
        qty: Decimal.fromInt(10),
        movementType: MovementType.adjustmentOut,
        notes: 'test',
        currentQtyAvailable: Decimal.fromInt(5),
      ),
    );
    expect(result.codes, contains(InventoryException.insufficientStock));
  });
}
