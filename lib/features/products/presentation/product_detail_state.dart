import '../../inventory/domain/warehouse.dart';
import '../domain/product.dart';
import '../domain/product_group.dart';
import '../domain/product_stock_summary.dart';
import '../domain/product_unit.dart';

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
    this.units = const [],
    this.unitsLoading = false,
    this.unitsUnavailable = false,
    this.unitsErrorCode,
    this.warehouses = const [],
    this.stockWarehouses = const [],
  });

  final bool isLoading;
  final Product? product;
  final List<ProductGroup> groups;
  final ProductStockSummary? stockSummary;
  final bool stockUnavailable;
  final String? errorCode;
  final bool isUploadingImage;
  final String? imageErrorCode;
  final List<ProductUnit> units;
  final bool unitsLoading;
  final bool unitsUnavailable;
  final String? unitsErrorCode;
  final List<Warehouse> warehouses;
  final List<Warehouse> stockWarehouses;

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
    List<ProductUnit>? units,
    bool? unitsLoading,
    bool? unitsUnavailable,
    String? unitsErrorCode,
    bool clearUnitsError = false,
    List<Warehouse>? warehouses,
    List<Warehouse>? stockWarehouses,
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
      units: units ?? this.units,
      unitsLoading: unitsLoading ?? this.unitsLoading,
      unitsUnavailable: unitsUnavailable ?? this.unitsUnavailable,
      unitsErrorCode:
          clearUnitsError ? null : (unitsErrorCode ?? this.unitsErrorCode),
      warehouses: warehouses ?? this.warehouses,
      stockWarehouses: stockWarehouses ?? this.stockWarehouses,
    );
  }
}
