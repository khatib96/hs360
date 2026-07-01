import '../domain/inventory_document_detail.dart';

class InventoryDocumentDetailState {
  const InventoryDocumentDetailState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.detail,
    this.errorCode,
    this.validationCodes = const [],
    this.cancelBlocked = false,
    this.productLabels = const {},
  });

  final bool isLoading;
  final bool isSubmitting;
  final InventoryDocumentDetail? detail;
  final String? errorCode;
  final List<String> validationCodes;
  final bool cancelBlocked;
  final Map<String, String> productLabels;

  bool get hasValidationErrors => validationCodes.isNotEmpty;

  InventoryDocumentDetailState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    InventoryDocumentDetail? detail,
    String? errorCode,
    List<String>? validationCodes,
    bool? cancelBlocked,
    Map<String, String>? productLabels,
    bool clearError = false,
    bool clearValidation = false,
    bool clearDetail = false,
  }) {
    return InventoryDocumentDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      detail: clearDetail ? null : (detail ?? this.detail),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      cancelBlocked: cancelBlocked ?? this.cancelBlocked,
      productLabels: productLabels ?? this.productLabels,
    );
  }
}
