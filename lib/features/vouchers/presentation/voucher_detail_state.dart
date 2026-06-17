import '../domain/voucher_detail.dart';

class VoucherDetailState {
  const VoucherDetailState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.detail,
    this.errorCode,
    this.validationCodes = const [],
  });

  final bool isLoading;
  final bool isSubmitting;
  final VoucherDetail? detail;
  final String? errorCode;
  final List<String> validationCodes;

  bool get hasError => errorCode != null;

  VoucherDetailState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    VoucherDetail? detail,
    String? errorCode,
    List<String>? validationCodes,
    bool clearError = false,
    bool clearValidation = false,
  }) {
    return VoucherDetailState(
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
