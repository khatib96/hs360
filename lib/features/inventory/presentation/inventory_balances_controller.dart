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
import '../domain/inventory_balance.dart';
import '../domain/inventory_balance_row.dart';
import '../domain/inventory_permissions.dart';
import '../domain/warehouse.dart';
import '../domain/warehouse_permissions.dart';
import 'inventory_balances_state.dart';

part 'inventory_balances_controller.g.dart';

@Riverpod(keepAlive: true)
class InventoryBalancesController extends _$InventoryBalancesController {
  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  InventoryBalancesState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const InventoryBalancesState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const InventoryBalancesState(isLoading: true);
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
    if (session == null || !canViewInventoryBalances(session)) {
      state = const InventoryBalancesState();
      return;
    }

    final refreshId = ++_refreshSerial;
    final previousFilters = (
      search: state.search,
      warehouseId: state.warehouseId,
      lowStockOnly: state.lowStockOnly,
    );

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearProductLabelsWarning: true,
      clearWarehouseLabelsWarning: true,
    );

    try {
      final balances = await ref
          .read(inventoryRepositoryProvider)
          .fetchInventoryBalances();
      if (refreshId != _refreshSerial) return;

      final productIds = balances.map((b) => b.productId).toSet();

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
      String? warehouseLabelsWarningCode;
      if (canViewWarehouses(session)) {
        try {
          final warehouses = await ref
              .read(warehouseRepositoryProvider)
              .fetchWarehouses(activeOnly: false);
          warehousesById = {for (final w in warehouses) w.id: w};
        } on ProductsException catch (e) {
          warehouseLabelsWarningCode = e.code;
        } catch (_) {
          warehouseLabelsWarningCode = ProductsException.unknown;
        }
      }

      var activeWarehouses = <Warehouse>[];
      if (canViewWarehouses(session)) {
        try {
          activeWarehouses = await ref
              .read(warehouseRepositoryProvider)
              .fetchWarehouses(activeOnly: true);
        } on ProductsException catch (e) {
          warehouseLabelsWarningCode ??= e.code;
        } catch (_) {
          warehouseLabelsWarningCode ??= ProductsException.unknown;
        }
      }

      if (refreshId != _refreshSerial) return;

      final rows = _mergeRows(balances, productLabels, warehousesById);

      state = InventoryBalancesState(
        allRows: rows,
        activeWarehouses: activeWarehouses,
        isLoading: false,
        search: previousFilters.search,
        warehouseId: previousFilters.warehouseId,
        lowStockOnly: previousFilters.lowStockOnly,
        productLabelsWarningCode: productLabelsWarningCode,
        warehouseLabelsWarningCode: warehouseLabelsWarningCode,
      );
    } on InventoryException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = InventoryBalancesState(
        isLoading: false,
        errorCode: e.code,
        search: previousFilters.search,
        warehouseId: previousFilters.warehouseId,
        lowStockOnly: previousFilters.lowStockOnly,
      );
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = InventoryBalancesState(
        isLoading: false,
        errorCode: InventoryException.unknown,
        search: previousFilters.search,
        warehouseId: previousFilters.warehouseId,
        lowStockOnly: previousFilters.lowStockOnly,
      );
    }
  }

  void setSearch(String? value) {
    state = state.copyWith(
      search: value?.trim().isEmpty == true ? null : value?.trim(),
      clearSearch: value == null || value.trim().isEmpty,
    );
  }

  void setWarehouseId(String? warehouseId) {
    state = state.copyWith(
      warehouseId: warehouseId,
      clearWarehouseFilter: warehouseId == null,
    );
  }

  void setLowStockOnly(bool value) {
    state = state.copyWith(lowStockOnly: value);
  }

  List<InventoryBalanceRow> _mergeRows(
    List<InventoryBalance> balances,
    Map<String, ProductStockLabel> productLabels,
    Map<String, Warehouse> warehousesById,
  ) {
    return [
      for (final balance in balances)
        _mergeRow(balance, productLabels, warehousesById),
    ];
  }

  InventoryBalanceRow _mergeRow(
    InventoryBalance balance,
    Map<String, ProductStockLabel> productLabels,
    Map<String, Warehouse> warehousesById,
  ) {
    final product = productLabels[balance.productId];
    final warehouse = warehousesById[balance.warehouseId];
    return InventoryBalanceRow(
      balance: balance,
      productId: balance.productId,
      warehouseId: balance.warehouseId,
      productSku: product?.sku,
      productNameAr: product?.nameAr,
      productNameEn: product?.nameEn,
      warehouseNameAr: warehouse?.nameAr,
      warehouseNameEn: warehouse?.nameEn,
      reorderPoint: product?.reorderPoint,
    );
  }
}
