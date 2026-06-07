import '../domain/product.dart';
import '../domain/product_unit.dart';

class ProductUnitDetailUiState {
  const ProductUnitDetailUiState({
    this.isLoading = true,
    this.unit,
    this.product,
    this.errorCode,
    this.isSubmittingCorrection = false,
    this.correctionErrorCode,
    this.correctionSuccess = false,
  });

  final bool isLoading;
  final ProductUnit? unit;
  final Product? product;
  final String? errorCode;
  final bool isSubmittingCorrection;
  final String? correctionErrorCode;
  final bool correctionSuccess;

  ProductUnitDetailUiState copyWith({
    bool? isLoading,
    ProductUnit? unit,
    Product? product,
    String? errorCode,
    bool clearError = false,
    bool? isSubmittingCorrection,
    String? correctionErrorCode,
    bool clearCorrectionError = false,
    bool? correctionSuccess,
  }) {
    return ProductUnitDetailUiState(
      isLoading: isLoading ?? this.isLoading,
      unit: unit ?? this.unit,
      product: product ?? this.product,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      isSubmittingCorrection:
          isSubmittingCorrection ?? this.isSubmittingCorrection,
      correctionErrorCode: clearCorrectionError
          ? null
          : (correctionErrorCode ?? this.correctionErrorCode),
      correctionSuccess: correctionSuccess ?? this.correctionSuccess,
    );
  }
}
