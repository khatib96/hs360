import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/domain/inventory_balance_row.dart';
import 'package:hs360/features/inventory/presentation/inventory_balances_state.dart';

InventoryBalanceRow _row({
  required String productId,
  required String warehouseId,
  required int qtyAvailable,
  required int reorderPoint,
}) {
  return InventoryBalanceRow(
    balance: InventoryBalance(
      id: 'b-$productId-$warehouseId',
      tenantId: 't',
      warehouseId: warehouseId,
      productId: productId,
      qtyAvailable: Decimal.fromInt(qtyAvailable),
      qtyRented: Decimal.zero,
      qtyTrial: Decimal.zero,
      qtyMaintenance: Decimal.zero,
      qtyDamaged: Decimal.zero,
    ),
    productId: productId,
    warehouseId: warehouseId,
    productSku: productId,
    productNameAr: productId,
    productNameEn: productId,
    warehouseNameAr: warehouseId,
    warehouseNameEn: warehouseId,
    reorderPoint: Decimal.fromInt(reorderPoint),
  );
}

void main() {
  group('InventoryBalancesState', () {
    test('low-stock filter uses product total before warehouse filter', () {
      final state = InventoryBalancesState(
        allRows: [
          _row(
            productId: 'p-1',
            warehouseId: 'wh-1',
            qtyAvailable: 2,
            reorderPoint: 5,
          ),
          _row(
            productId: 'p-1',
            warehouseId: 'wh-2',
            qtyAvailable: 10,
            reorderPoint: 5,
          ),
          _row(
            productId: 'p-2',
            warehouseId: 'wh-1',
            qtyAvailable: 1,
            reorderPoint: 5,
          ),
        ],
        warehouseId: 'wh-1',
        lowStockOnly: true,
      );

      expect(state.filteredRows.map((r) => r.productId), ['p-2']);
    });
  });
}
