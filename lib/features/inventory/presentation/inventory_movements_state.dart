import '../domain/inventory_movement_row.dart';
import '../domain/movement_type.dart';
import '../domain/warehouse.dart';

class InventoryMovementsState {
  const InventoryMovementsState({
    this.allRows = const [],
    this.filterWarehouses = const [],
    this.isLoading = false,
    this.errorCode,
    this.productLabelsWarningCode,
    this.warehouseLabelsWarningCode,
    this.search,
    this.warehouseId,
    this.movementType,
    this.occurredFromDate,
    this.occurredToDate,
    this.limit = 100,
    this.serverSideProductSearch = true,
  });

  final List<InventoryMovementRow> allRows;
  final List<Warehouse> filterWarehouses;
  final bool isLoading;
  final String? errorCode;
  final String? productLabelsWarningCode;
  final String? warehouseLabelsWarningCode;
  final String? search;
  final String? warehouseId;
  final MovementType? movementType;
  final DateTime? occurredFromDate;
  final DateTime? occurredToDate;
  final int limit;
  final bool serverSideProductSearch;

  bool get hasError => errorCode != null;
  bool get hasHydrationWarning =>
      productLabelsWarningCode != null || warehouseLabelsWarningCode != null;

  List<InventoryMovementRow> get visibleRows {
    if (!serverSideProductSearch) {
      return _applyClientSearch(allRows, search);
    }
    return allRows;
  }

  InventoryMovementsState copyWith({
    List<InventoryMovementRow>? allRows,
    List<Warehouse>? filterWarehouses,
    bool? isLoading,
    String? errorCode,
    String? productLabelsWarningCode,
    String? warehouseLabelsWarningCode,
    String? search,
    String? warehouseId,
    MovementType? movementType,
    DateTime? occurredFromDate,
    DateTime? occurredToDate,
    int? limit,
    bool? serverSideProductSearch,
    bool clearError = false,
    bool clearProductLabelsWarning = false,
    bool clearWarehouseLabelsWarning = false,
    bool clearSearch = false,
    bool clearWarehouseFilter = false,
    bool clearMovementType = false,
    bool clearOccurredFrom = false,
    bool clearOccurredTo = false,
  }) {
    return InventoryMovementsState(
      allRows: allRows ?? this.allRows,
      filterWarehouses: filterWarehouses ?? this.filterWarehouses,
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
      movementType:
          clearMovementType ? null : (movementType ?? this.movementType),
      occurredFromDate: clearOccurredFrom
          ? null
          : (occurredFromDate ?? this.occurredFromDate),
      occurredToDate:
          clearOccurredTo ? null : (occurredToDate ?? this.occurredToDate),
      limit: limit ?? this.limit,
      serverSideProductSearch:
          serverSideProductSearch ?? this.serverSideProductSearch,
    );
  }

  static List<InventoryMovementRow> _applyClientSearch(
    List<InventoryMovementRow> rows,
    String? query,
  ) {
    final trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) return rows;

    final lower = trimmed.toLowerCase();
    bool contains(String? value) =>
        value != null && value.toLowerCase().contains(lower);

    return rows
        .where(
          (row) =>
              contains(row.productId) ||
              contains(row.warehouseId) ||
              contains(row.referenceTable) ||
              contains(row.referenceId) ||
              contains(row.notes) ||
              contains(row.productSku) ||
              contains(row.productNameAr) ||
              contains(row.productNameEn),
        )
        .toList();
  }
}
