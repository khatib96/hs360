import 'package:decimal/decimal.dart';

import '../domain/transfer_product_option.dart';
import '../domain/transfer_warehouse_option.dart';

class InventoryTransferState {
  const InventoryTransferState({
    this.warehouses = const [],
    this.searchResults = const [],
    this.selectedProduct,
    this.sourceQtyAvailable,
    this.isLoadingWarehouses = false,
    this.isSearching = false,
    this.isSubmitting = false,
    this.errorCode,
  });

  final List<TransferWarehouseOption> warehouses;
  final List<TransferProductOption> searchResults;
  final TransferProductOption? selectedProduct;
  final Decimal? sourceQtyAvailable;
  final bool isLoadingWarehouses;
  final bool isSearching;
  final bool isSubmitting;
  final String? errorCode;

  InventoryTransferState copyWith({
    List<TransferWarehouseOption>? warehouses,
    List<TransferProductOption>? searchResults,
    TransferProductOption? selectedProduct,
    Decimal? sourceQtyAvailable,
    bool? isLoadingWarehouses,
    bool? isSearching,
    bool? isSubmitting,
    String? errorCode,
    bool clearSelectedProduct = false,
    bool clearError = false,
    bool clearSourceQty = false,
    bool clearSearchResults = false,
  }) {
    return InventoryTransferState(
      warehouses: warehouses ?? this.warehouses,
      searchResults: clearSearchResults
          ? const []
          : (searchResults ?? this.searchResults),
      selectedProduct: clearSelectedProduct
          ? null
          : (selectedProduct ?? this.selectedProduct),
      sourceQtyAvailable: clearSourceQty
          ? null
          : (sourceQtyAvailable ?? this.sourceQtyAvailable),
      isLoadingWarehouses: isLoadingWarehouses ?? this.isLoadingWarehouses,
      isSearching: isSearching ?? this.isSearching,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
