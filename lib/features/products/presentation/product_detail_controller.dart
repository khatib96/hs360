import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/products_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/product_group_repository.dart';
import '../data/product_image_repository.dart';
import '../data/product_repository.dart';
import '../domain/product_group.dart';
import '../domain/product_permissions.dart';
import '../domain/product_stock_summary.dart';
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

      state = ProductDetailUiState(
        isLoading: false,
        product: product,
        groups: groups,
        stockSummary: stock,
        stockUnavailable: stockUnavailable,
      );
    } catch (e) {
      state = ProductDetailUiState(
        isLoading: false,
        errorCode: e is ProductsException ? e.code : ProductsException.unknown,
      );
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
