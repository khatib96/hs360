import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/inventory_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_cost_access.dart';
import '../../products/domain/product_filters.dart';
import '../../products/domain/product_permissions.dart';
import '../data/inventory_repository.dart';
import '../data/warehouse_repository.dart';
import '../domain/inventory_adjustment_form_state.dart';
import '../domain/inventory_permissions.dart';
import '../domain/movement_type.dart';
import 'inventory_adjustment_state.dart';
import 'inventory_balances_controller.dart';
import 'inventory_movements_controller.dart';

part 'inventory_adjustment_controller.g.dart';

@riverpod
class InventoryAdjustmentController extends _$InventoryAdjustmentController {
  @override
  InventoryAdjustmentState build() {
    return const InventoryAdjustmentState();
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  Future<void> loadWarehouses() async {
    state = state.copyWith(isLoadingWarehouses: true, clearError: true);
    try {
      final warehouses = await ref
          .read(warehouseRepositoryProvider)
          .fetchWarehouses(activeOnly: true);
      state = state.copyWith(
        warehouses: warehouses,
        isLoadingWarehouses: false,
      );
    } on InventoryException catch (e) {
      state = state.copyWith(
        isLoadingWarehouses: false,
        errorCode: e.code,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingWarehouses: false,
        errorCode: InventoryException.unknown,
      );
    }
  }

  Future<void> searchProducts(String query) async {
    final session = _session;
    if (session == null || !canViewProductsList(session)) {
      state = state.copyWith(searchResults: const []);
      return;
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(searchResults: const []);
      return;
    }

    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final products = await ref.read(productRepositoryProvider).fetchProducts(
            ProductFilters(search: trimmed, isActive: true),
            session,
          );
      state = state.copyWith(
        searchResults: products,
        isSearching: false,
      );
    } catch (_) {
      state = state.copyWith(
        searchResults: const [],
        isSearching: false,
      );
    }
  }

  void clearProductSelection() {
    state = state.copyWith(
      clearSelectedProduct: true,
      searchResults: const [],
      isSerialized: false,
      clearQtyContext: true,
      clearAvgCost: true,
    );
  }

  Future<void> selectProduct(Product product) async {
    final session = _session;
    if (session == null) return;

    state = state.copyWith(
      selectedProduct: product,
      isSerialized: product.isSerialized,
      searchResults: const [],
      clearError: true,
      clearQtyContext: true,
      clearAvgCost: true,
    );

    await _hydrateQtyContext(product.id);
  }

  Future<void> onWarehouseChanged(String? warehouseId) async {
    final product = state.selectedProduct;
    if (product == null || warehouseId == null) {
      state = state.copyWith(clearQtyContext: true);
      return;
    }
    await _hydrateQtyContext(product.id, warehouseId: warehouseId);
  }

  Future<void> _hydrateQtyContext(
    String productId, {
    String? warehouseId,
  }) async {
    final session = _session;
    if (session == null) return;

    Decimal? warehouseQty;
    if (warehouseId != null) {
      final balancesState = ref.read(inventoryBalancesControllerProvider);
      final fromCache = balancesState.allRows
          .where(
            (r) => r.productId == productId && r.warehouseId == warehouseId,
          )
          .toList();
      if (fromCache.isNotEmpty) {
        warehouseQty = fromCache.first.qtyAvailable;
      } else {
        try {
          final balances = await ref
              .read(inventoryRepositoryProvider)
              .fetchInventoryBalances(
                productId: productId,
                warehouseId: warehouseId,
              );
          warehouseQty = balances.isEmpty
              ? Decimal.zero
              : balances.first.qtyAvailable;
        } catch (_) {
          warehouseQty = Decimal.zero;
        }
      }
    }

    Decimal? totalQty;
    Decimal? avgCost;
    if (canViewFullProductCosts(session)) {
      final product = state.selectedProduct;
      avgCost = product?.avgCost;
      try {
        final stock = await ref
            .read(productRepositoryProvider)
            .fetchProductStock(productId);
        totalQty = stock.totalQtyAvailable;
      } catch (_) {
        totalQty = null;
      }
    }

    state = state.copyWith(
      currentQtyAvailable: warehouseQty,
      totalQtyAvailable: totalQty,
      avgCost: avgCost,
    );
  }

  /// Returns null on success, or error code.
  Future<String?> submit({
    required MovementType movementType,
    required String warehouseId,
    required String productId,
    required Decimal qty,
    required String notes,
    Decimal? unitCost,
  }) async {
    final session = _session;
    if (session == null) {
      return InventoryException.permissionDenied;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final form = InventoryAdjustmentFormState(
        warehouseId: warehouseId,
        productId: productId,
        qty: qty,
        movementType: movementType,
        unitCost: unitCost,
        notes: notes,
        isSerialized: state.isSerialized,
        currentQtyAvailable: state.currentQtyAvailable,
      );

      await ref.read(inventoryRepositoryProvider).recordInventoryAdjustment(
            session,
            form,
          );

      await ref.read(inventoryBalancesControllerProvider.notifier).refresh();

      if (canViewInventoryMovements(session)) {
        try {
          await ref
              .read(inventoryMovementsControllerProvider.notifier)
              .refresh();
        } catch (_) {}
      }

      state = state.copyWith(isSubmitting: false);
      return null;
    } on InventoryException catch (e) {
      state = state.copyWith(isSubmitting: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorCode: InventoryException.unknown,
      );
      return InventoryException.unknown;
    }
  }
}
