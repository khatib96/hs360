import 'package:decimal/decimal.dart';

import '../../customers/domain/customer.dart';
import '../../customers/domain/customer_service_location.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_unit.dart';
import '../domain/contract_pricing_preview.dart';
import '../domain/contract_type.dart';

class ContractAssetLineUiState {
  const ContractAssetLineUiState({
    this.product,
    this.productUnitId,
    this.unitCode = '',
    this.unitErrorCode,
    this.availableUnits = const [],
    this.isLoadingUnits = false,
    this.isResolvingUnit = false,
  });

  final Product? product;
  final String? productUnitId;
  final String unitCode;
  final String? unitErrorCode;
  final List<ProductUnit> availableUnits;
  final bool isLoadingUnits;
  final bool isResolvingUnit;

  ContractAssetLineUiState copyWith({
    Product? product,
    bool clearProduct = false,
    String? productUnitId,
    bool clearProductUnitId = false,
    String? unitCode,
    bool clearUnitCode = false,
    String? unitErrorCode,
    bool clearUnitError = false,
    List<ProductUnit>? availableUnits,
    bool clearAvailableUnits = false,
    bool? isLoadingUnits,
    bool? isResolvingUnit,
  }) {
    return ContractAssetLineUiState(
      product: clearProduct ? null : (product ?? this.product),
      productUnitId: clearProductUnitId
          ? null
          : (productUnitId ?? this.productUnitId),
      unitCode: clearUnitCode ? '' : (unitCode ?? this.unitCode),
      unitErrorCode: clearUnitError
          ? null
          : (unitErrorCode ?? this.unitErrorCode),
      availableUnits: clearAvailableUnits
          ? const []
          : (availableUnits ?? this.availableUnits),
      isLoadingUnits: isLoadingUnits ?? this.isLoadingUnits,
      isResolvingUnit: isResolvingUnit ?? this.isResolvingUnit,
    );
  }
}

class ContractConsumableLineUiState {
  ContractConsumableLineUiState({
    this.product,
    Decimal? qtyPerRefill,
    this.refillFrequencyMonths = 1,
  }) : qtyPerRefill = qtyPerRefill ?? Decimal.one;

  final Product? product;
  final Decimal qtyPerRefill;
  final int refillFrequencyMonths;

  ContractConsumableLineUiState copyWith({
    Product? product,
    bool clearProduct = false,
    Decimal? qtyPerRefill,
    int? refillFrequencyMonths,
  }) {
    return ContractConsumableLineUiState(
      product: clearProduct ? null : (product ?? this.product),
      qtyPerRefill: qtyPerRefill ?? this.qtyPerRefill,
      refillFrequencyMonths:
          refillFrequencyMonths ?? this.refillFrequencyMonths,
    );
  }
}

class ContractFormUiState {
  const ContractFormUiState({
    this.type = ContractType.trial,
    this.startDate,
    this.endDate,
    this.trialDays = 3,
    this.billingDay,
    this.refillDay,
    this.notes = '',
    this.monthlyRentalValue,
    this.requestOverride = false,
    this.overrideReason = '',
    this.customerId,
    this.serviceLocationId,
    this.selectedCustomer,
    this.serviceLocations = const [],
    this.isLoadingLocations = false,
    this.assetLines = const [],
    this.consumableLines = const [],
    this.isSubmitting = false,
    this.isLoadingPreview = false,
    this.errorCode,
    this.errorDetail,
    this.validationCodes = const [],
    this.pricingPreview,
    this.lastCreatedContractId,
    this.customerSearchResults = const [],
    this.isSearchingCustomers = false,
    this.productSearchResults = const [],
    this.isSearchingProducts = false,
    this.productSearchTarget,
    this.productSearchLineIndex,
  });

  final ContractType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final int trialDays;
  final int? billingDay;
  final int? refillDay;
  final String notes;
  final Decimal? monthlyRentalValue;
  final bool requestOverride;
  final String overrideReason;
  final String? customerId;
  final String? serviceLocationId;
  final Customer? selectedCustomer;
  final List<CustomerServiceLocation> serviceLocations;
  final bool isLoadingLocations;
  final List<ContractAssetLineUiState> assetLines;
  final List<ContractConsumableLineUiState> consumableLines;
  final bool isSubmitting;
  final bool isLoadingPreview;
  final String? errorCode;
  final String? errorDetail;
  final List<String> validationCodes;
  final ContractPricingPreview? pricingPreview;
  final String? lastCreatedContractId;
  final List<Customer> customerSearchResults;
  final bool isSearchingCustomers;
  final List<Product> productSearchResults;
  final bool isSearchingProducts;
  final ContractProductSearchTarget? productSearchTarget;
  final int? productSearchLineIndex;

  factory ContractFormUiState.initial() {
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    return ContractFormUiState(startDate: startDate, trialDays: 3);
  }

  ContractFormUiState copyWith({
    ContractType? type,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? trialDays,
    int? billingDay,
    bool clearBillingDay = false,
    int? refillDay,
    bool clearRefillDay = false,
    String? notes,
    Decimal? monthlyRentalValue,
    bool clearMonthlyRentalValue = false,
    bool? requestOverride,
    String? overrideReason,
    String? customerId,
    bool clearCustomerId = false,
    String? serviceLocationId,
    bool clearServiceLocationId = false,
    Customer? selectedCustomer,
    bool clearSelectedCustomer = false,
    List<CustomerServiceLocation>? serviceLocations,
    bool clearServiceLocations = false,
    bool? isLoadingLocations,
    List<ContractAssetLineUiState>? assetLines,
    List<ContractConsumableLineUiState>? consumableLines,
    bool? isSubmitting,
    bool? isLoadingPreview,
    String? errorCode,
    String? errorDetail,
    bool clearError = false,
    List<String>? validationCodes,
    bool clearValidation = false,
    ContractPricingPreview? pricingPreview,
    bool clearPricingPreview = false,
    String? lastCreatedContractId,
    List<Customer>? customerSearchResults,
    bool clearCustomerSearchResults = false,
    bool? isSearchingCustomers,
    List<Product>? productSearchResults,
    bool clearProductSearchResults = false,
    bool? isSearchingProducts,
    ContractProductSearchTarget? productSearchTarget,
    bool clearProductSearchTarget = false,
    int? productSearchLineIndex,
    bool clearProductSearchLineIndex = false,
  }) {
    return ContractFormUiState(
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      trialDays: trialDays ?? this.trialDays,
      billingDay: clearBillingDay ? null : (billingDay ?? this.billingDay),
      refillDay: clearRefillDay ? null : (refillDay ?? this.refillDay),
      notes: notes ?? this.notes,
      monthlyRentalValue: clearMonthlyRentalValue
          ? null
          : (monthlyRentalValue ?? this.monthlyRentalValue),
      requestOverride: requestOverride ?? this.requestOverride,
      overrideReason: overrideReason ?? this.overrideReason,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      serviceLocationId: clearServiceLocationId
          ? null
          : (serviceLocationId ?? this.serviceLocationId),
      selectedCustomer: clearSelectedCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      serviceLocations: clearServiceLocations
          ? const []
          : (serviceLocations ?? this.serviceLocations),
      isLoadingLocations: isLoadingLocations ?? this.isLoadingLocations,
      assetLines: assetLines ?? this.assetLines,
      consumableLines: consumableLines ?? this.consumableLines,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingPreview: isLoadingPreview ?? this.isLoadingPreview,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      pricingPreview: clearPricingPreview
          ? null
          : (pricingPreview ?? this.pricingPreview),
      lastCreatedContractId:
          lastCreatedContractId ?? this.lastCreatedContractId,
      customerSearchResults: clearCustomerSearchResults
          ? const []
          : (customerSearchResults ?? this.customerSearchResults),
      isSearchingCustomers: isSearchingCustomers ?? this.isSearchingCustomers,
      productSearchResults: clearProductSearchResults
          ? const []
          : (productSearchResults ?? this.productSearchResults),
      isSearchingProducts: isSearchingProducts ?? this.isSearchingProducts,
      productSearchTarget: clearProductSearchTarget
          ? null
          : (productSearchTarget ?? this.productSearchTarget),
      productSearchLineIndex: clearProductSearchLineIndex
          ? null
          : (productSearchLineIndex ?? this.productSearchLineIndex),
    );
  }
}

enum ContractProductSearchTarget { asset, consumable, rental }
