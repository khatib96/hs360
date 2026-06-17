import '../domain/invoice_detail.dart';

class InvoiceDetailState {
  const InvoiceDetailState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.detail,
    this.errorCode,
    this.validationCodes = const [],
  });

  final bool isLoading;
  final bool isSubmitting;
  final InvoiceDetail? detail;
  final String? errorCode;
  final List<String> validationCodes;

  bool get hasError => errorCode != null;

  InvoiceDetailState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    InvoiceDetail? detail,
    String? errorCode,
    List<String>? validationCodes,
    bool clearError = false,
    bool clearValidation = false,
  }) {
    return InvoiceDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      detail: detail ?? this.detail,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
    );
  }
}
