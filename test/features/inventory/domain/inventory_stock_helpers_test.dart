import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/inventory/domain/inventory_stock_helpers.dart';

void main() {
  test('low stock when available equals reorder point', () {
    expect(
      isLowStock(
        totalAvailable: Decimal.fromInt(5),
        reorderPoint: Decimal.fromInt(5),
      ),
      isTrue,
    );
  });

  test('low stock when available below reorder point', () {
    expect(
      isLowStock(
        totalAvailable: Decimal.fromInt(3),
        reorderPoint: Decimal.fromInt(5),
      ),
      isTrue,
    );
  });

  test('no low stock when reorder point is null', () {
    expect(
      isLowStock(totalAvailable: Decimal.zero, reorderPoint: null),
      isFalse,
    );
  });

  test('no low stock when available above reorder point', () {
    expect(
      isLowStock(
        totalAvailable: Decimal.fromInt(10),
        reorderPoint: Decimal.fromInt(5),
      ),
      isFalse,
    );
  });
}
