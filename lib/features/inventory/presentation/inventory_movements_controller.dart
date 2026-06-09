import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/inventory_exception.dart';
import '../../../core/errors/products_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product_permissions.dart';
import '../../products/domain/product_stock_label.dart';
import '../data/inventory_repository.dart';
import '../data/warehouse_repository.dart';
import '../domain/inventory_movement.dart';
import '../domain/inventory_movement_row.dart';
import '../domain/inventory_permissions.dart';
import '../domain/movement_type.dart';
import '../domain/warehouse.dart';
import '../domain/warehouse_permissions.dart';
import 'inventory_movements_state.dart';

part 'inventory_movements_controller.g.dart';

@Riverpod(keepAlive: true)
class InventoryMovementsController extends _$InventoryMovementsController {
  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  InventoryMovementsState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const InventoryMovementsState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const InventoryMovementsState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  Future<void> refresh() async {
    _hasStartedInitialLoad = true;
    final session = _session;
    if (session == null || !canViewInventoryMovements(session)) {
      state = const InventoryMovementsState();
      return;
    }

    final refreshId = ++_refreshSerial;
    final previousFilters = _snapshotFilters();
    final serverSideProductSearch = canViewProductsList(session);

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearProductLabelsWarning: true,
      clearWarehouseLabelsWarning: true,
      serverSideProductSearch: serverSideProductSearch,
    );

    try {
      List<InventoryMovement> movements;
      final search = previousFilters.search?.trim();

      if (serverSideProductSearch && search != null && search.isNotEmpty) {
        final productIds = await ref
            .read(productRepositoryProvider)
            .searchProductIdsForInventoryMovements(session, search);
        if (refreshId != _refreshSerial) return;

        if (productIds.isEmpty) {
          movements = [];
        } else {
          movements = await ref
              .read(inventoryRepositoryProvider)
              .fetchInventoryMovements(
                warehouseId: previousFilters.warehouseId,
                movementType: previousFilters.movementType,
                occurredFrom: _occurredFromBoundary(
                  previousFilters.occurredFromDate,
                ),
                occurredBefore: _occurredBeforeBoundary(
                  previousFilters.occurredToDate,
                ),
                productIds: productIds,
                limit: previousFilters.limit,
              );
        }
      } else {
        movements = await ref
            .read(inventoryRepositoryProvider)
            .fetchInventoryMovements(
              warehouseId: previousFilters.warehouseId,
              movementType: previousFilters.movementType,
              occurredFrom: _occurredFromBoundary(
                previousFilters.occurredFromDate,
              ),
              occurredBefore: _occurredBeforeBoundary(
                previousFilters.occurredToDate,
              ),
              limit: previousFilters.limit,
            );
      }

      if (refreshId != _refreshSerial) return;

      final productIds = movements.map((m) => m.productId).toSet();

      var productLabels = <String, ProductStockLabel>{};
      String? productLabelsWarningCode;
      if (canViewProductsList(session) && productIds.isNotEmpty) {
        try {
          productLabels = await ref
              .read(productRepositoryProvider)
              .fetchProductsByIdsForStockLabels(session, productIds);
        } on ProductsException catch (e) {
          productLabelsWarningCode = e.code;
        } catch (_) {
          productLabelsWarningCode = ProductsException.unknown;
        }
      }

      var warehousesById = <String, Warehouse>{};
      var filterWarehouses = <Warehouse>[];
      String? warehouseLabelsWarningCode;
      if (canViewWarehouses(session)) {
        try {
          final warehouses = await ref
              .read(warehouseRepositoryProvider)
              .fetchWarehouses(activeOnly: false);
          warehousesById = {for (final w in warehouses) w.id: w};
          filterWarehouses = warehouses;
        } on ProductsException catch (e) {
          warehouseLabelsWarningCode = e.code;
        } catch (_) {
          warehouseLabelsWarningCode = ProductsException.unknown;
        }
      }

      if (refreshId != _refreshSerial) return;

      final rows = _mergeRows(movements, productLabels, warehousesById);

      state = InventoryMovementsState(
        allRows: rows,
        filterWarehouses: filterWarehouses,
        isLoading: false,
        search: previousFilters.search,
        warehouseId: previousFilters.warehouseId,
        movementType: previousFilters.movementType,
        occurredFromDate: previousFilters.occurredFromDate,
        occurredToDate: previousFilters.occurredToDate,
        limit: previousFilters.limit,
        serverSideProductSearch: serverSideProductSearch,
        productLabelsWarningCode: productLabelsWarningCode,
        warehouseLabelsWarningCode: warehouseLabelsWarningCode,
      );
    } on InventoryException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = _errorState(e.code, previousFilters, serverSideProductSearch);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = _errorState(
        InventoryException.unknown,
        previousFilters,
        serverSideProductSearch,
      );
    }
  }

  void setSearch(String? value) {
    final trimmed = value?.trim();
    state = state.copyWith(
      search: trimmed == null || trimmed.isEmpty ? null : trimmed,
      clearSearch: trimmed == null || trimmed.isEmpty,
    );
    refresh();
  }

  void setWarehouseId(String? warehouseId) {
    state = state.copyWith(
      warehouseId: warehouseId,
      clearWarehouseFilter: warehouseId == null,
    );
    refresh();
  }

  void setMovementType(MovementType? type) {
    state = state.copyWith(movementType: type, clearMovementType: type == null);
    refresh();
  }

  void setOccurredFromDate(DateTime? date) {
    final local = _localDateOnly(date);
    var toDate = state.occurredToDate;
    if (local != null &&
        toDate != null &&
        local.isAfter(_localDateOnly(toDate)!)) {
      toDate = null;
    }
    state = state.copyWith(
      occurredFromDate: local,
      occurredToDate: toDate,
      clearOccurredFrom: local == null,
      clearOccurredTo: toDate == null && state.occurredToDate != null,
    );
    refresh();
  }

  void setOccurredToDate(DateTime? date) {
    final local = _localDateOnly(date);
    var fromDate = state.occurredFromDate;
    if (local != null &&
        fromDate != null &&
        local.isBefore(_localDateOnly(fromDate)!)) {
      fromDate = null;
    }
    state = state.copyWith(
      occurredToDate: local,
      occurredFromDate: fromDate,
      clearOccurredTo: local == null,
      clearOccurredFrom: fromDate == null && state.occurredFromDate != null,
    );
    refresh();
  }

  void setLimit(int limit) {
    state = state.copyWith(limit: limit);
    refresh();
  }

  static DateTime? _localDateOnly(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime? _occurredFromBoundary(DateTime? localDate) {
    if (localDate == null) return null;
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  static DateTime? _occurredBeforeBoundary(DateTime? localDate) {
    if (localDate == null) return null;
    final next = localDate.add(const Duration(days: 1));
    return DateTime(next.year, next.month, next.day);
  }

  ({
    String? search,
    String? warehouseId,
    MovementType? movementType,
    DateTime? occurredFromDate,
    DateTime? occurredToDate,
    int limit,
  })
  _snapshotFilters() {
    return (
      search: state.search,
      warehouseId: state.warehouseId,
      movementType: state.movementType,
      occurredFromDate: state.occurredFromDate,
      occurredToDate: state.occurredToDate,
      limit: state.limit,
    );
  }

  InventoryMovementsState _errorState(
    String code,
    ({
      String? search,
      String? warehouseId,
      MovementType? movementType,
      DateTime? occurredFromDate,
      DateTime? occurredToDate,
      int limit,
    })
    filters,
    bool serverSideProductSearch,
  ) {
    return InventoryMovementsState(
      isLoading: false,
      errorCode: code,
      search: filters.search,
      warehouseId: filters.warehouseId,
      movementType: filters.movementType,
      occurredFromDate: filters.occurredFromDate,
      occurredToDate: filters.occurredToDate,
      limit: filters.limit,
      serverSideProductSearch: serverSideProductSearch,
      filterWarehouses: state.filterWarehouses,
    );
  }

  List<InventoryMovementRow> _mergeRows(
    List<InventoryMovement> movements,
    Map<String, ProductStockLabel> productLabels,
    Map<String, Warehouse> warehousesById,
  ) {
    return [
      for (final movement in movements)
        _mergeRow(movement, productLabels, warehousesById),
    ];
  }

  InventoryMovementRow _mergeRow(
    InventoryMovement movement,
    Map<String, ProductStockLabel> productLabels,
    Map<String, Warehouse> warehousesById,
  ) {
    final product = productLabels[movement.productId];
    final warehouse = warehousesById[movement.warehouseId];
    return InventoryMovementRow(
      movement: movement,
      productId: movement.productId,
      warehouseId: movement.warehouseId,
      productSku: product?.sku,
      productNameAr: product?.nameAr,
      productNameEn: product?.nameEn,
      warehouseNameAr: warehouse?.nameAr,
      warehouseNameEn: warehouse?.nameEn,
      warehouseIsActive: warehouse?.isActive ?? true,
    );
  }
}
