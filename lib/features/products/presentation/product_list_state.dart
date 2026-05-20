import '../domain/product.dart';
import '../domain/product_filters.dart';
import '../domain/product_group.dart';
import '../domain/product_stock_summary.dart';

/// Immutable UI state for the product list screen.
class ProductListState {
  const ProductListState({
    this.products = const [],
    this.groups = const [],
    this.stockByProductId = const {},
    this.filters = const ProductFilters(),
    this.isLoading = false,
    this.errorCode,
  });

  final List<Product> products;
  final List<ProductGroup> groups;
  final Map<String, ProductStockSummary> stockByProductId;
  final ProductFilters filters;
  final bool isLoading;
  final String? errorCode;

  bool get hasError => errorCode != null;

  ProductListState copyWith({
    List<Product>? products,
    List<ProductGroup>? groups,
    Map<String, ProductStockSummary>? stockByProductId,
    ProductFilters? filters,
    bool? isLoading,
    String? errorCode,
    bool clearError = false,
  }) {
    return ProductListState(
      products: products ?? this.products,
      groups: groups ?? this.groups,
      stockByProductId: stockByProductId ?? this.stockByProductId,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

/// Builds repository [ProductFilters] with stock filter cleared when stock is disabled.
ProductFilters effectiveProductFilters(
  ProductFilters filters, {
  required bool canViewStock,
  required bool canViewGroups,
}) {
  return ProductFilters(
    search: filters.search,
    groupId: canViewGroups ? filters.groupId : null,
    productType: filters.productType,
    isActive: filters.isActive,
    stockFilter: canViewStock ? filters.stockFilter : null,
  );
}
