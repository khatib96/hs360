import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/inventory_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_transfer_form_state.dart';
import '../domain/inventory_permissions.dart';
import '../domain/transfer_product_option.dart';
import 'inventory_balances_controller.dart';
import 'inventory_movements_controller.dart';
import 'inventory_transfer_state.dart';

part 'inventory_transfer_controller.g.dart';

@riverpod
class InventoryTransferController extends _$InventoryTransferController {
  @override
  InventoryTransferState build() {
    return const InventoryTransferState();
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  Future<void> loadWarehouses() async {
    final session = _session;
    if (session == null) return;

    state = state.copyWith(isLoadingWarehouses: true, clearError: true);
    try {
      final warehouses = await ref
          .read(inventoryRepositoryProvider)
          .listTransferWarehouses(session);
      state = state.copyWith(
        warehouses: warehouses,
        isLoadingWarehouses: false,
      );
    } on InventoryException catch (e) {
      state = state.copyWith(isLoadingWarehouses: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoadingWarehouses: false,
        errorCode: InventoryException.unknown,
      );
    }
  }

  Future<void> searchProducts(String query) async {
    final session = _session;
    if (session == null) {
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
      final products = await ref
          .read(inventoryRepositoryProvider)
          .searchTransferProducts(session, trimmed);
      state = state.copyWith(searchResults: products, isSearching: false);
    } catch (_) {
      state = state.copyWith(searchResults: const [], isSearching: false);
    }
  }

  void clearProductSelection() {
    state = state.copyWith(
      clearSelectedProduct: true,
      clearSearchResults: true,
      clearSourceQty: true,
    );
  }

  Future<void> selectProduct(TransferProductOption product) async {
    if (product.isSerialized) {
      state = state.copyWith(
        errorCode: InventoryException.serializedTransferNotSupported,
        clearSelectedProduct: true,
        clearSourceQty: true,
      );
      return;
    }

    state = state.copyWith(
      selectedProduct: product,
      searchResults: const [],
      clearError: true,
      clearSourceQty: true,
    );
  }

  Future<void> hydrateSourceQty(String? fromWarehouseId) async {
    final session = _session;
    final product = state.selectedProduct;
    if (session == null ||
        fromWarehouseId == null ||
        fromWarehouseId.isEmpty ||
        product == null) {
      state = state.copyWith(clearSourceQty: true);
      return;
    }

    try {
      final qty = await ref
          .read(inventoryRepositoryProvider)
          .getTransferSourceQty(
            session,
            warehouseId: fromWarehouseId,
            productId: product.id,
          );
      state = state.copyWith(sourceQtyAvailable: qty);
    } catch (_) {
      state = state.copyWith(sourceQtyAvailable: Decimal.zero);
    }
  }

  void clearFormAfterSuccess() {
    state = state.copyWith(
      clearSelectedProduct: true,
      clearSearchResults: true,
      clearSourceQty: true,
      clearError: true,
    );
  }

  /// Returns null on success, or error code.
  Future<String?> submit({
    required String fromWarehouseId,
    required String toWarehouseId,
    required String productId,
    required Decimal qty,
    required String notes,
  }) async {
    final session = _session;
    if (session == null) {
      return InventoryException.permissionDenied;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final form = InventoryTransferFormState(
        fromWarehouseId: fromWarehouseId,
        toWarehouseId: toWarehouseId,
        productId: productId,
        qty: qty,
        notes: notes,
        isSerialized: state.selectedProduct?.isSerialized ?? false,
        sourceQtyAvailable: state.sourceQtyAvailable,
      );

      await ref
          .read(inventoryRepositoryProvider)
          .recordInventoryTransfer(session, form);

      if (canViewInventoryBalances(session)) {
        await ref.read(inventoryBalancesControllerProvider.notifier).refresh();
      }

      if (canViewInventoryMovements(session)) {
        try {
          await ref
              .read(inventoryMovementsControllerProvider.notifier)
              .refresh();
        } catch (_) {}
      }

      clearFormAfterSuccess();
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
