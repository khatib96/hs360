import '../domain/product.dart';
import '../domain/product_group.dart';
import '../domain/product_stock_summary.dart';

class ProductDetailUiState {
  const ProductDetailUiState({
    this.isLoading = true,
    this.product,
    this.groups = const [],
    this.stockSummary,
    this.stockUnavailable = false,
    this.errorCode,
    this.isUploadingImage = false,
    this.imageErrorCode,
  });

  final bool isLoading;
  final Product? product;
  final List<ProductGroup> groups;
  final ProductStockSummary? stockSummary;
  final bool stockUnavailable;
  final String? errorCode;
  final bool isUploadingImage;
  final String? imageErrorCode;

  bool get notFound => !isLoading && product == null && errorCode == null;

  ProductDetailUiState copyWith({
    bool? isLoading,
    Product? product,
    List<ProductGroup>? groups,
    ProductStockSummary? stockSummary,
    bool? stockUnavailable,
    String? errorCode,
    bool clearError = false,
    bool? isUploadingImage,
    String? imageErrorCode,
    bool clearImageError = false,
  }) {
    return ProductDetailUiState(
      isLoading: isLoading ?? this.isLoading,
      product: product ?? this.product,
      groups: groups ?? this.groups,
      stockSummary: stockSummary ?? this.stockSummary,
      stockUnavailable: stockUnavailable ?? this.stockUnavailable,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      imageErrorCode:
          clearImageError ? null : (imageErrorCode ?? this.imageErrorCode),
    );
  }
}
