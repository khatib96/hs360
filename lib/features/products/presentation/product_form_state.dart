import 'package:decimal/decimal.dart';

import '../domain/product.dart';
import '../domain/product_group.dart';
import '../domain/product_stock_summary.dart';
import 'product_form_draft.dart';

class ProductFormUiState {
  ProductFormUiState({
    ProductFormDraft? draft,
    this.stepIndex = 0,
    this.isEdit = false,
    this.productId,
    this.groups = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorCode,
    this.stockSummary,
    this.stockLoadFailed = false,
    this.stockLoaded = false,
    this.canSelectGroup = true,
    this.blockCreateWithoutGroups = false,
    this.loadedProduct,
  }) : draft = draft ?? ProductFormDraft();

  final ProductFormDraft draft;
  final int stepIndex;
  final bool isEdit;
  final String? productId;
  final List<ProductGroup> groups;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorCode;
  final ProductStockSummary? stockSummary;
  final bool stockLoadFailed;
  final bool stockLoaded;
  final bool canSelectGroup;
  final bool blockCreateWithoutGroups;
  final Product? loadedProduct;

  bool get canChangeSerialized {
    if (!isEdit) return true;
    if (!stockLoaded || stockLoadFailed) return false;
    return stockSummary?.totalQtyAvailable == Decimal.zero;
  }

  ProductFormUiState copyWith({
    ProductFormDraft? draft,
    int? stepIndex,
    bool? isEdit,
    String? productId,
    List<ProductGroup>? groups,
    bool? isLoading,
    bool? isSubmitting,
    String? errorCode,
    bool clearError = false,
    ProductStockSummary? stockSummary,
    bool? stockLoadFailed,
    bool? stockLoaded,
    bool? canSelectGroup,
    bool? blockCreateWithoutGroups,
    Product? loadedProduct,
  }) {
    return ProductFormUiState(
      draft: draft ?? this.draft,
      stepIndex: stepIndex ?? this.stepIndex,
      isEdit: isEdit ?? this.isEdit,
      productId: productId ?? this.productId,
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      stockSummary: stockSummary ?? this.stockSummary,
      stockLoadFailed: stockLoadFailed ?? this.stockLoadFailed,
      stockLoaded: stockLoaded ?? this.stockLoaded,
      canSelectGroup: canSelectGroup ?? this.canSelectGroup,
      blockCreateWithoutGroups:
          blockCreateWithoutGroups ?? this.blockCreateWithoutGroups,
      loadedProduct: loadedProduct ?? this.loadedProduct,
    );
  }
}
