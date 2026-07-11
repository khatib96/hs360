import 'package:decimal/decimal.dart';

import '../domain/contract_detail.dart';
import '../domain/contract_pricing_preview.dart';

class ContractConvertUiState {
  const ContractConvertUiState({
    this.isLoading = false,
    this.isLoadingPreview = false,
    this.isSubmitting = false,
    this.trialDetail,
    this.conversionStartDate,
    this.errorCode,
    this.validationCodes = const [],
    this.monthlyRentalValue,
    this.endDate,
    this.billingDay,
    this.refillDay,
    this.requestOverride = false,
    this.overrideReason = '',
    this.pricingPreview,
    this.lastRentalContractId,
  });

  final bool isLoading;
  final bool isLoadingPreview;
  final bool isSubmitting;
  final ContractDetail? trialDetail;
  final DateTime? conversionStartDate;
  final String? errorCode;
  final List<String> validationCodes;
  final Decimal? monthlyRentalValue;
  final DateTime? endDate;
  final int? billingDay;
  final int? refillDay;
  final bool requestOverride;
  final String overrideReason;
  final ContractPricingPreview? pricingPreview;
  final String? lastRentalContractId;

  ContractConvertUiState copyWith({
    bool? isLoading,
    bool? isLoadingPreview,
    bool? isSubmitting,
    ContractDetail? trialDetail,
    bool clearTrialDetail = false,
    DateTime? conversionStartDate,
    bool clearConversionStartDate = false,
    String? errorCode,
    bool clearError = true,
    List<String>? validationCodes,
    bool clearValidation = false,
    Decimal? monthlyRentalValue,
    bool clearMonthlyRentalValue = false,
    DateTime? endDate,
    bool clearEndDate = false,
    int? billingDay,
    bool clearBillingDay = false,
    int? refillDay,
    bool clearRefillDay = false,
    bool? requestOverride,
    String? overrideReason,
    ContractPricingPreview? pricingPreview,
    bool clearPricingPreview = false,
    String? lastRentalContractId,
    bool clearLastRentalContractId = false,
  }) {
    return ContractConvertUiState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingPreview: isLoadingPreview ?? this.isLoadingPreview,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      trialDetail: clearTrialDetail ? null : (trialDetail ?? this.trialDetail),
      conversionStartDate: clearConversionStartDate
          ? null
          : (conversionStartDate ?? this.conversionStartDate),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      monthlyRentalValue: clearMonthlyRentalValue
          ? null
          : (monthlyRentalValue ?? this.monthlyRentalValue),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      billingDay: clearBillingDay ? null : (billingDay ?? this.billingDay),
      refillDay: clearRefillDay ? null : (refillDay ?? this.refillDay),
      requestOverride: requestOverride ?? this.requestOverride,
      overrideReason: overrideReason ?? this.overrideReason,
      pricingPreview: clearPricingPreview
          ? null
          : (pricingPreview ?? this.pricingPreview),
      lastRentalContractId: clearLastRentalContractId
          ? null
          : (lastRentalContractId ?? this.lastRentalContractId),
    );
  }
}
