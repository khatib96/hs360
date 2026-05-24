import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/products_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../inventory/data/warehouse_repository.dart';
import '../../inventory/domain/warehouse.dart';
import '../data/product_group_repository.dart';
import '../data/product_image_repository.dart';
import '../data/product_repository.dart';
import '../data/product_unit_repository.dart';
import '../domain/product_group.dart';
import '../domain/product_permissions.dart';
import '../domain/product_stock_summary.dart';
import '../domain/product_unit_form_state.dart';
import '../domain/product_unit_permissions.dart';
import 'product_detail_state.dart';
import 'product_list_permissions.dart';

part 'product_detail_controller.g.dart';

@riverpod
class ProductDetailController extends _$ProductDetailController {
  @override
  ProductDetailUiState build(String productId) {
    Future.microtask(() => load(productId));
    return ProductDetailUiState();
  }

  Future<void> load(String productId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      state = ProductDetailUiState(isLoading: false);
      return;
    }

    state = ProductDetailUiState(isLoading: true);
    try {
      final product = await ref
          .read(productRepositoryProvider)
          .fetchProductById(productId, session);

      if (product == null) {
        state = ProductDetailUiState(isLoading: false);
        return;
      }

      var groups = <ProductGroup>[];
      if (canViewProductGroups(session)) {
        try {
          groups = await ref
              .read(productGroupRepositoryProvider)
              .fetchProductGroups(activeOnly: false);
        } catch (_) {
          groups = <ProductGroup>[];
        }
      }

      ProductStockSummary? stock;
      var stockUnavailable = true;
      if (canViewProductStock(session)) {
        try {
          stock = await ref
              .read(productRepositoryProvider)
              .fetchProductStock(productId);
          stockUnavailable = false;
        } catch (_) {
          stockUnavailable = true;
        }
      }

      var warehouses = <Warehouse>[];
      if (product.isSerialized &&
          (canCreateProductUnits(session) || canViewProductUnits(session))) {
        try {
          warehouses = await ref
              .read(warehouseRepositoryProvider)
              .fetchWarehouses(activeOnly: true);
        } catch (_) {
          warehouses = <Warehouse>[];
        }
      }

      state = ProductDetailUiState(
        isLoading: false,
        product: product,
        groups: groups,
        stockSummary: stock,
        stockUnavailable: stockUnavailable,
        warehouses: warehouses,
      );

      if (product.isSerialized) {
        await loadUnits(productId);
      }
    } catch (e) {
      state = ProductDetailUiState(
        isLoading: false,
        errorCode: e is ProductsException ? e.code : ProductsException.unknown,
      );
    }
  }

  Future<void> loadUnits(String productId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final product = state.product;
    if (session == null || product == null || !product.isSerialized) return;

    if (!canViewProductUnits(session)) {
      state = state.copyWith(
        units: [],
        unitsLoading: false,
        unitsUnavailable: true,
        clearUnitsError: true,
      );
      return;
    }

    state = state.copyWith(unitsLoading: true, unitsUnavailable: false);
    try {
      final warehousesById = {
        for (final w in state.warehouses) w.id: w,
      };
      final units = await ref.read(productUnitRepositoryProvider).fetchUnitsByProductId(
            productId,
            session,
            warehousesById: warehousesById,
          );
      state = state.copyWith(
        units: units,
        unitsLoading: false,
        clearUnitsError: true,
      );
    } catch (e) {
      state = state.copyWith(
        unitsLoading: false,
        unitsErrorCode:
            e is ProductsException ? e.code : ProductsException.unknown,
      );
    }
  }

  Future<String?> addUnit({
    required String productId,
    required String warehouseId,
    required ProductUnitCreateInput input,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return ProductsException.permissionDenied;

    try {
      await ref.read(productUnitRepositoryProvider).createUnit(
            session: session,
            productId: productId,
            warehouseId: warehouseId,
            input: input,
          );
      await _refreshAfterUnitMutation(productId);
      return null;
    } catch (e) {
      return e is ProductsException ? e.code : ProductsException.unknown;
    }
  }

  Future<String?> bulkAddUnits({
    required String productId,
    required String warehouseId,
    required List<ProductUnitCreateInput> units,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return ProductsException.permissionDenied;

    try {
      await ref.read(productUnitRepositoryProvider).bulkCreateUnits(
            session: session,
            productId: productId,
            warehouseId: warehouseId,
            units: units,
          );
      await _refreshAfterUnitMutation(productId);
      return null;
    } catch (e) {
      return e is ProductsException ? e.code : ProductsException.unknown;
    }
  }

  Future<String?> updateUnitSafe({
    required String productId,
    required String unitId,
    required ProductUnitSafeEditInput input,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return ProductsException.permissionDenied;

    try {
      await ref.read(productUnitRepositoryProvider).updateUnitSafe(
            session: session,
            unitId: unitId,
            input: input,
          );
      await loadUnits(productId);
      return null;
    } catch (e) {
      return e is ProductsException ? e.code : ProductsException.unknown;
    }
  }

  Future<void> _refreshAfterUnitMutation(String productId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    await loadUnits(productId);

    if (canViewProductStock(session)) {
      try {
        final stock = await ref
            .read(productRepositoryProvider)
            .fetchProductStock(productId);
        state = state.copyWith(stockSummary: stock, stockUnavailable: false);
      } catch (_) {
        state = state.copyWith(stockUnavailable: true);
      }
    }
  }

  Future<void> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String? mimeType,
    String? fileExtension,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canEditProduct(session)) return;

    state = state.copyWith(isUploadingImage: true, clearImageError: true);
    try {
      final url = await ref.read(productImageRepositoryProvider).uploadPrimaryImage(
            session: session,
            productId: productId,
            bytes: bytes,
            mimeType: mimeType,
            fileExtension: fileExtension,
          );
      await ref.read(productRepositoryProvider).updateProductImageUrl(
            session,
            productId,
            url,
          );
      await load(productId);
      state = state.copyWith(isUploadingImage: false);
    } catch (e) {
      state = state.copyWith(
        isUploadingImage: false,
        imageErrorCode:
            e is ProductsException ? e.code : ProductsException.unknown,
      );
    }
  }
}
