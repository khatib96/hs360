import 'product_type.dart';

enum ProductStockFilter {
  inStock,
  outOfStock,
  lowStock,
}

/// Query filters for product list (repository applies to Supabase).
class ProductFilters {
  const ProductFilters({
    this.search,
    this.groupId,
    this.productType,
    this.isActive,
    this.stockFilter,
  });

  final String? search;
  final String? groupId;
  final ProductType? productType;
  final bool? isActive;
  final ProductStockFilter? stockFilter;

  bool get hasActiveFilters =>
      search?.trim().isNotEmpty == true ||
      groupId != null ||
      productType != null ||
      isActive != null ||
      stockFilter != null;
}
