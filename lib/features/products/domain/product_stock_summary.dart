import 'package:decimal/decimal.dart';

import '../../inventory/domain/inventory_balance.dart';

/// Aggregated stock for a product from [inventory_balances].
class ProductStockSummary {
  const ProductStockSummary({
    required this.productId,
    required this.totalQtyAvailable,
    this.balances = const [],
  });

  final String productId;
  final Decimal totalQtyAvailable;
  final List<InventoryBalance> balances;
}
