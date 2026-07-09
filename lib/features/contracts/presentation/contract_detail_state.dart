import '../domain/contract_detail.dart';

class ContractDetailState {
  const ContractDetailState({
    this.detail,
    this.isLoading = false,
    this.errorCode,
    this.isNotFound = false,
  });

  final ContractDetail? detail;
  final bool isLoading;
  final String? errorCode;
  final bool isNotFound;

  ContractDetailState copyWith({
    ContractDetail? detail,
    bool? isLoading,
    String? errorCode,
    bool? isNotFound,
    bool clearError = false,
    bool clearNotFound = false,
  }) {
    return ContractDetailState(
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      isNotFound: clearNotFound ? false : (isNotFound ?? this.isNotFound),
    );
  }
}
