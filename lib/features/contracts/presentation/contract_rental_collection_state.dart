import 'package:decimal/decimal.dart';

import '../../accounting/domain/chart_account.dart';
import '../../finance_shared/domain/payment_method.dart';
import '../domain/rental_collection_draft.dart';

class ContractRentalCollectionUiState {
  const ContractRentalCollectionUiState({
    this.isLoadingMonths = false,
    this.isLoadingMeta = false,
    this.isPreviewLoading = false,
    this.isSubmitting = false,
    this.coveredMonthKeys = const [],
    this.eligibleMonthKeys = const [],
    this.selectedMonthKeys = const [],
    this.collectionDate,
    this.paymentMethod = PaymentMethod.cash,
    this.cashAccountId = '',
    this.referenceNo = '',
    this.notes = '',
    this.preview,
    this.cashBankAccounts = const [],
    this.canLoadCashAccounts = false,
    this.errorCode,
    this.validationCodes = const [],
    this.lastResult,
    this.showSuccessActions = false,
  });

  final bool isLoadingMonths;
  final bool isLoadingMeta;
  final bool isPreviewLoading;
  final bool isSubmitting;
  final List<String> coveredMonthKeys;
  final List<String> eligibleMonthKeys;
  final List<String> selectedMonthKeys;
  final DateTime? collectionDate;
  final PaymentMethod paymentMethod;
  final String cashAccountId;
  final String referenceNo;
  final String notes;
  final RentalCollectionPreview? preview;
  final List<ChartAccount> cashBankAccounts;
  final bool canLoadCashAccounts;
  final String? errorCode;
  final List<String> validationCodes;
  final RentalCollectionResult? lastResult;
  final bool showSuccessActions;

  bool get canConfirm =>
      preview != null &&
      selectedMonthKeys.isNotEmpty &&
      cashAccountId.trim().isNotEmpty &&
      !isSubmitting &&
      !isPreviewLoading;

  Decimal? get lockedAmount => preview?.expectedCollectedAmount;

  ContractRentalCollectionUiState copyWith({
    bool? isLoadingMonths,
    bool? isLoadingMeta,
    bool? isPreviewLoading,
    bool? isSubmitting,
    List<String>? coveredMonthKeys,
    List<String>? eligibleMonthKeys,
    List<String>? selectedMonthKeys,
    DateTime? collectionDate,
    PaymentMethod? paymentMethod,
    String? cashAccountId,
    String? referenceNo,
    String? notes,
    RentalCollectionPreview? preview,
    bool clearPreview = false,
    List<ChartAccount>? cashBankAccounts,
    bool? canLoadCashAccounts,
    String? errorCode,
    bool clearError = true,
    List<String>? validationCodes,
    bool clearValidation = false,
    RentalCollectionResult? lastResult,
    bool clearLastResult = false,
    bool? showSuccessActions,
  }) {
    return ContractRentalCollectionUiState(
      isLoadingMonths: isLoadingMonths ?? this.isLoadingMonths,
      isLoadingMeta: isLoadingMeta ?? this.isLoadingMeta,
      isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      coveredMonthKeys: coveredMonthKeys ?? this.coveredMonthKeys,
      eligibleMonthKeys: eligibleMonthKeys ?? this.eligibleMonthKeys,
      selectedMonthKeys: selectedMonthKeys ?? this.selectedMonthKeys,
      collectionDate: collectionDate ?? this.collectionDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashAccountId: cashAccountId ?? this.cashAccountId,
      referenceNo: referenceNo ?? this.referenceNo,
      notes: notes ?? this.notes,
      preview: clearPreview ? null : (preview ?? this.preview),
      cashBankAccounts: cashBankAccounts ?? this.cashBankAccounts,
      canLoadCashAccounts: canLoadCashAccounts ?? this.canLoadCashAccounts,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      showSuccessActions: showSuccessActions ?? this.showSuccessActions,
    );
  }
}
