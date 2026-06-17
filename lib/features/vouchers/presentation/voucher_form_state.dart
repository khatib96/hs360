import '../domain/voucher_form_state.dart';
import '../domain/voucher_type.dart';

class VoucherFormUiState {
  const VoucherFormUiState({
    required this.voucherType,
    required this.form,
    this.isSubmitting = false,
    this.errorCode,
    this.validationCodes = const [],
    this.lastSavedVoucherId,
  });

  final VoucherType voucherType;
  final VoucherFormState form;
  final bool isSubmitting;
  final String? errorCode;
  final List<String> validationCodes;
  final String? lastSavedVoucherId;

  VoucherFormUiState copyWith({
    VoucherType? voucherType,
    VoucherFormState? form,
    bool? isSubmitting,
    String? errorCode,
    List<String>? validationCodes,
    String? lastSavedVoucherId,
    bool clearError = false,
    bool clearValidation = false,
  }) {
    return VoucherFormUiState(
      voucherType: voucherType ?? this.voucherType,
      form: form ?? this.form,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      lastSavedVoucherId: lastSavedVoucherId ?? this.lastSavedVoucherId,
    );
  }
}
