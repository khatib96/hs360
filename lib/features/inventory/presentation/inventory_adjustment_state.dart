import 'package:decimal/decimal.dart';

import '../../products/domain/product.dart';
import '../domain/warehouse.dart';

class InventoryAdjustmentState {
  const InventoryAdjustmentState({
    this.warehouses = const [],
    this.searchResults = const [],
    this.selectedProduct,
    this.isSerialized = false,
    this.currentQtyAvailable,
    this.totalQtyAvailable,
    this.avgCost,
    this.isLoadingWarehouses = false,
    this.isSearching = false,
    this.isSubmitting = false,
    this.errorCode,
  });

  final List<Warehouse> warehouses;
  final List<Product> searchResults;
  final Product? selectedProduct;
  final bool isSerialized;
  final Decimal? currentQtyAvailable;
  final Decimal? totalQtyAvailable;
  final Decimal? avgCost;
  final bool isLoadingWarehouses;
  final bool isSearching;
  final bool isSubmitting;
  final String? errorCode;

  InventoryAdjustmentState copyWith({
    List<Warehouse>? warehouses,
    List<Product>? searchResults,
    Product? selectedProduct,
    bool? isSerialized,
    Decimal? currentQtyAvailable,
    Decimal? totalQtyAvailable,
    Decimal? avgCost,
    bool? isLoadingWarehouses,
    bool? isSearching,
    bool? isSubmitting,
    String? errorCode,
    bool clearSelectedProduct = false,
    bool clearError = false,
    bool clearQtyContext = false,
    bool clearAvgCost = false,
  }) {
    return InventoryAdjustmentState(
      warehouses: warehouses ?? this.warehouses,
      searchResults: searchResults ?? this.searchResults,
      selectedProduct: clearSelectedProduct
          ? null
          : (selectedProduct ?? this.selectedProduct),
      isSerialized: isSerialized ?? this.isSerialized,
      currentQtyAvailable: clearQtyContext
          ? null
          : (currentQtyAvailable ?? this.currentQtyAvailable),
      totalQtyAvailable: clearQtyContext
          ? null
          : (totalQtyAvailable ?? this.totalQtyAvailable),
      avgCost: clearAvgCost ? null : (avgCost ?? this.avgCost),
      isLoadingWarehouses: isLoadingWarehouses ?? this.isLoadingWarehouses,
      isSearching: isSearching ?? this.isSearching,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
