import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/products_exception.dart';
import '../../../domain/validators/product_validator.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/product_group_repository.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../domain/product_cost_access.dart';
import '../domain/product_form_mapper.dart';
import '../domain/product_group.dart';
import '../domain/product_permissions.dart';
import 'product_form_draft.dart';
import 'product_form_state.dart';
import 'product_list_permissions.dart';

part 'product_form_controller.g.dart';

@riverpod
class ProductFormController extends _$ProductFormController {
  @override
  ProductFormUiState build({String? productId}) {
    final isEdit = productId != null && productId.isNotEmpty;
    Future.microtask(() => _initialize(productId, isEdit));
    return ProductFormUiState(
      isEdit: isEdit,
      productId: productId,
      isLoading: isEdit,
    );
  }

  void updateDraft(ProductFormDraft draft) {
    state = state.copyWith(draft: draft, clearError: true);
  }

  void setStep(int index) {
    state = state.copyWith(stepIndex: index, clearError: true);
  }

  bool validateCurrentStep() {
    if (!state.isEdit && state.blockCreateWithoutGroups) {
      state = state.copyWith(
        errorCode: ProductsException.productGroupsPermissionRequired,
      );
      return false;
    }
    final session = ref.read(authControllerProvider).valueOrNull;
    final decimalCode = state.draft.firstInvalidDecimalCodeForStep(
      state.stepIndex + 1,
      canWriteCosts: session != null && canWriteProductCosts(session),
    );
    if (decimalCode != null) {
      state = state.copyWith(errorCode: decimalCode);
      return false;
    }
    if (state.stepIndex == 3 && state.draft.hasInvalidExpectedLifespan) {
      state = state.copyWith(
        errorCode: ProductsException.expectedLifespanInvalid,
      );
      return false;
    }
    final result = const ProductValidator().validateStep(
      state.stepIndex + 1,
      state.draft.toFormState(),
    );
    if (!result.isValid) {
      state = state.copyWith(errorCode: result.codes.first);
      return false;
    }
    state = state.copyWith(clearError: true);
    return true;
  }

  Future<ProductSubmitResult?> submit() async {
    if (!state.isEdit && state.blockCreateWithoutGroups) {
      state = state.copyWith(
        errorCode: ProductsException.productGroupsPermissionRequired,
      );
      return null;
    }

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return null;

    final decimalCode = state.draft.firstInvalidDecimalCode(
      canWriteCosts: canWriteProductCosts(session),
    );
    if (decimalCode != null) {
      state = state.copyWith(errorCode: decimalCode);
      return null;
    }
    if (state.draft.hasInvalidExpectedLifespan) {
      state = state.copyWith(
        errorCode: ProductsException.expectedLifespanInvalid,
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final input = state.draft.toFormState();
      if (state.isEdit && state.productId != null) {
        final product = await repo.updateProduct(
          session,
          state.productId!,
          input,
        );
        state = state.copyWith(isSubmitting: false);
        return ProductSubmitResult(product: product, isCreate: false);
      }
      final product = await repo.createProduct(session, input);
      state = state.copyWith(isSubmitting: false);
      return ProductSubmitResult(product: product, isCreate: true);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorCode: e is ProductsException ? e.code : ProductsException.unknown,
      );
      return null;
    }
  }

  Future<void> _initialize(String? productId, bool isEdit) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final canSelect = canSelectProductGroup(session);
    final blockCreate = !isEdit && !canSelect;

    state = state.copyWith(
      canSelectGroup: canSelect,
      blockCreateWithoutGroups: blockCreate,
      isLoading: isEdit,
    );

    List<ProductGroup> groups = <ProductGroup>[];
    if (canSelect) {
      try {
        groups = await ref
            .read(productGroupRepositoryProvider)
            .fetchProductGroups(activeOnly: false);
      } catch (_) {
        groups = const [];
      }
    }

    if (isEdit && productId != null) {
      try {
        final product = await ref
            .read(productRepositoryProvider)
            .fetchProductById(productId, session);
        if (product == null) {
          state = state.copyWith(
            isLoading: false,
            errorCode: ProductsException.unknown,
          );
          return;
        }
        var ui = state.copyWith(
          isLoading: false,
          groups: groups,
          draft: ProductFormDraft.fromFormState(
            productFormStateFromProduct(product),
          ),
          loadedProduct: product,
        );

        if (canViewProductStock(session)) {
          try {
            final stock = await ref
                .read(productRepositoryProvider)
                .fetchProductStock(productId);
            ui = ui.copyWith(
              stockSummary: stock,
              stockLoaded: true,
              stockLoadFailed: false,
            );
          } catch (_) {
            ui = ui.copyWith(stockLoadFailed: true, stockLoaded: false);
          }
        } else {
          ui = ui.copyWith(stockLoadFailed: true, stockLoaded: false);
        }

        state = ui;
        return;
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          errorCode: e is ProductsException
              ? e.code
              : ProductsException.unknown,
        );
        return;
      }
    }

    state = state.copyWith(isLoading: false, groups: groups);
  }
}

class ProductSubmitResult {
  const ProductSubmitResult({required this.product, required this.isCreate});

  final Product product;
  final bool isCreate;
}
