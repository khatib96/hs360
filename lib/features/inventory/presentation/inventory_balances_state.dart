import 'package:decimal/decimal.dart';

import '../domain/inventory_balance_row.dart';
import '../domain/inventory_stock_helpers.dart';
import '../domain/warehouse.dart';

class InventoryBalancesState {
  const InventoryBalancesState({
    this.allRows = const [],
    this.activeWarehouses = const [],
    this.isLoading = false,
    this.errorCode,
    this.productLabelsWarningCode,
    this.warehouseLabelsWarningCode,
    this.search,
    this.warehouseId,
    this.lowStockOnly = false,
  });

  final List<InventoryBalanceRow> allRows;
  final List<Warehouse> activeWarehouses;
  final bool isLoading;
  final String? errorCode;
  final String? productLabelsWarningCode;
  final String? warehouseLabelsWarningCode;
  final String? search;
  final String? warehouseId;
  final bool lowStockOnly;

  bool get hasError => errorCode != null;
  bool get hasHydrationWarning =>
      productLabelsWarningCode != null || warehouseLabelsWarningCode != null;

  List<InventoryBalanceRow> get filteredRows {
    var rows = allRows;
    final warehouseFilter = warehouseId;
    if (warehouseFilter != null) {
      rows = rows.where((r) => r.warehouseId == warehouseFilter).toList();
    }

    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      final lower = query.toLowerCase();
      rows = rows.where((r) => _matchesSearch(r, lower)).toList();
    }

    if (lowStockOnly) {
      final totals = _totalsByProduct(rows);
      rows = rows
          .where(
            (r) => isLowStock(
              totalAvailable: totals[r.productId] ?? Decimal.zero,
              reorderPoint: r.reorderPoint,
            ),
          )
          .toList();
    }

    return rows;
  }

  InventoryBalancesState copyWith({
    List<InventoryBalanceRow>? allRows,
    List<Warehouse>? activeWarehouses,
    bool? isLoading,
    String? errorCode,
    String? productLabelsWarningCode,
    String? warehouseLabelsWarningCode,
    String? search,
    String? warehouseId,
    bool? lowStockOnly,
    bool clearError = false,
    bool clearProductLabelsWarning = false,
    bool clearWarehouseLabelsWarning = false,
    bool clearWarehouseFilter = false,
    bool clearSearch = false,
  }) {
    return InventoryBalancesState(
      allRows: allRows ?? this.allRows,
      activeWarehouses: activeWarehouses ?? this.activeWarehouses,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      productLabelsWarningCode: clearProductLabelsWarning
          ? null
          : (productLabelsWarningCode ?? this.productLabelsWarningCode),
      warehouseLabelsWarningCode: clearWarehouseLabelsWarning
          ? null
          : (warehouseLabelsWarningCode ?? this.warehouseLabelsWarningCode),
      search: clearSearch ? null : (search ?? this.search),
      warehouseId:
          clearWarehouseFilter ? null : (warehouseId ?? this.warehouseId),
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }

  static Map<String, Decimal> _totalsByProduct(List<InventoryBalanceRow> rows) {
    final totals = <String, Decimal>{};
    for (final row in rows) {
      totals[row.productId] =
          (totals[row.productId] ?? Decimal.zero) + row.qtyAvailable;
    }
    return totals;
  }

  static bool _matchesSearch(InventoryBalanceRow row, String lower) {
    bool contains(String? value) =>
        value != null && value.toLowerCase().contains(lower);

    return contains(row.productSku) ||
        contains(row.productNameAr) ||
        contains(row.productNameEn) ||
        contains(row.warehouseNameAr) ||
        contains(row.warehouseNameEn);
  }
}
