import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/products_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../inventory/data/warehouse_repository.dart';
import '../data/product_repository.dart';
import '../data/product_unit_repository.dart';
import '../domain/product.dart';
import '../domain/product_permissions.dart';
import '../domain/product_unit_permissions.dart';
import 'product_unit_detail_state.dart';
import 'product_unit_timeline_controller.dart';

part 'product_unit_detail_controller.g.dart';

@riverpod
class ProductUnitDetailController extends _$ProductUnitDetailController {
  @override
  ProductUnitDetailUiState build(String unitId) {
    Future.microtask(() => load(unitId));
    return const ProductUnitDetailUiState();
  }

  Future<void> load(String unitId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      state = const ProductUnitDetailUiState(isLoading: false);
      return;
    }

    if (!canViewProductUnits(session)) {
      state = const ProductUnitDetailUiState(
        isLoading: false,
        errorCode: ProductsException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final warehouses = await ref
          .read(warehouseRepositoryProvider)
          .fetchWarehouses(activeOnly: false);
      final warehousesById = {for (final w in warehouses) w.id: w};

      final unit = await ref
          .read(productUnitRepositoryProvider)
          .fetchUnitById(unitId, session, warehousesById: warehousesById);

      if (unit == null) {
        state = const ProductUnitDetailUiState(isLoading: false);
        return;
      }

      Product? product;
      if (canViewProductsList(session)) {
        product = await ref
            .read(productRepositoryProvider)
            .fetchProductById(unit.productId, session);
      }

      state = ProductUnitDetailUiState(
        isLoading: false,
        unit: unit,
        product: product,
      );
    } on ProductsException catch (e) {
      state = ProductUnitDetailUiState(
        isLoading: false,
        errorCode: e.code,
      );
    } catch (_) {
      state = const ProductUnitDetailUiState(
        isLoading: false,
        errorCode: ProductsException.unknown,
      );
    }
  }

  Future<void> correctSerial({
    required String newSerial,
    required String reason,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || state.unit == null) return;

    state = state.copyWith(
      isSubmittingCorrection: true,
      clearCorrectionError: true,
      correctionSuccess: false,
    );

    try {
      await ref.read(productUnitRepositoryProvider).correctSerial(
            session: session,
            unitId: state.unit!.id,
            newSerial: newSerial,
            reason: reason,
          );
      await load(state.unit!.id);
      ref.invalidate(productUnitTimelineControllerProvider(state.unit!.id));
      state = state.copyWith(
        isSubmittingCorrection: false,
        correctionSuccess: true,
      );
    } on ProductsException catch (e) {
      state = state.copyWith(
        isSubmittingCorrection: false,
        correctionErrorCode: e.code,
      );
    } catch (_) {
      state = state.copyWith(
        isSubmittingCorrection: false,
        correctionErrorCode: ProductsException.unknown,
      );
    }
  }
}
