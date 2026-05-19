import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/domain/services/cost_engine.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';

void main() {
  const engine = CostEngine();

  test('WAC when old qty is zero uses incoming unit cost', () {
    expect(
      engine.previewWac(
        oldTotalQty: Decimal.zero,
        oldAvgCost: Decimal.parse('5.000'),
        incomingQty: Decimal.fromInt(100),
        incomingUnitCost: Decimal.parse('0.010'),
      ),
      Decimal.parse('0.010'),
    );
  });

  test('WAC formula when old qty positive', () {
    final result = engine.previewWac(
      oldTotalQty: Decimal.fromInt(100),
      oldAvgCost: Decimal.parse('1.000'),
      incomingQty: Decimal.fromInt(50),
      incomingUnitCost: Decimal.parse('2.000'),
    );
    // (100*1 + 50*2) / 150 = 200/150 = 1.333...
    expect(result.toString(), startsWith('1.333'));
  });

  test('adjustment_out does not affect WAC', () {
    expect(engine.movementAffectsWac(MovementType.adjustmentOut), isFalse);
    expect(engine.movementAffectsWac(MovementType.adjustmentIn), isTrue);
  });

  test('unit cost required on adjustment_in', () {
    final result = engine.validateUnitCostForAdjustmentIn(null);
    expect(result.codes, contains(InventoryException.validationFailed));
  });

  test('allows zero unit cost for free stock', () {
    final result = engine.validateUnitCostForAdjustmentIn(Decimal.zero);
    expect(result.isValid, isTrue);
  });
}
