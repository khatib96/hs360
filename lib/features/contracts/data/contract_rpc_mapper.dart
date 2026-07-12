import '../../../core/utils/decimal_parser.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_line.dart';
import '../domain/contract_pricing_preview.dart';
import '../domain/contract_return_condition.dart';
import '../domain/contract_schedule_event.dart';
import '../domain/contract_status.dart';
import '../domain/contract_type.dart';
import '../domain/rental_collection_draft.dart';

ContractPricingPreview mapContractPricingPreview(Map<String, dynamic> json) {
  final assetRaw = json['asset_lines'];
  final consumableRaw = json['consumable_lines'];

  return ContractPricingPreview(
    monthlyRentalValue: tryParseDecimal(json['monthly_rental_value']),
    passesMinProfit: json['passes_min_profit'] as bool?,
    belowMinProfit: json['below_min_profit'] as bool?,
    requiresOverride: json['requires_override'] as bool?,
    canOverride: json['can_override'] as bool?,
    minProfitOverridden: json['min_profit_overridden'] as bool?,
    assetMonthlyCost: tryParseDecimal(json['asset_monthly_cost']),
    consumableMonthlyCost: tryParseDecimal(json['consumable_monthly_cost']),
    totalMonthlyCost: tryParseDecimal(json['total_monthly_cost']),
    expectedMonthlyProfit: tryParseDecimal(json['expected_monthly_profit']),
    minimumAllowedMonthlyValue: tryParseDecimal(
      json['minimum_allowed_monthly_value'],
    ),
    minMonthlyProfitThreshold: tryParseDecimal(
      json['min_monthly_profit_threshold'],
    ),
    assetCostBasis: json['asset_cost_basis'] as String?,
    consumableCostBasis: json['consumable_cost_basis'] as String?,
    assetLifespanMonths: json['asset_lifespan_months'] as int?,
    assetLines: assetRaw is List
        ? assetRaw
              .map(
                (line) =>
                    mapPreviewAssetLine(Map<String, dynamic>.from(line as Map)),
              )
              .toList()
        : const [],
    consumableLines: consumableRaw is List
        ? consumableRaw
              .map(
                (line) => mapPreviewConsumableLine(
                  Map<String, dynamic>.from(line as Map),
                ),
              )
              .toList()
        : const [],
  );
}

RentalCollectionPreview mapRentalCollectionPreview(Map<String, dynamic> json) {
  return RentalCollectionPreview.fromRpcJson(json);
}

RentalCollectionResult mapRentalCollectionResult(Map<String, dynamic> json) {
  final monthsRaw = json['coverage_months'];
  final months = monthsRaw is List
      ? monthsRaw.map((m) => m.toString()).toList()
      : const <String>[];

  return RentalCollectionResult(
    invoiceId: json['invoice_id'] as String,
    voucherId: json['voucher_id'] as String,
    coverageMonths: months,
    invoiceTotal: tryParseDecimal(json['invoice_total']),
    collectedAmount: tryParseDecimal(json['collected_amount']),
  );
}

/// Minimal tolerant parser for future `get_contract_detail` JSON.
ContractDetail mapContractDetail(Map<String, dynamic> json) {
  final assetsRaw = json['asset_lines'] ?? json['assets'];
  final consumablesRaw = json['consumable_lines'] ?? json['consumables'];
  final scheduleRaw = json['upcoming_schedule'];

  final returnConditionRaw = json['return_condition'] as String?;

  return ContractDetail(
    id: json['id'] as String,
    contractNumber: json['contract_number'] as String?,
    type: ContractType.fromDb(json['type'] as String?),
    status: ContractStatus.fromDb(json['status'] as String?),
    customerId: json['customer_id'] as String?,
    customerNameAr: json['customer_name_ar'] as String?,
    customerNameEn: json['customer_name_en'] as String?,
    serviceLocationId: json['service_location_id'] as String?,
    serviceLocationName: json['service_location_name'] as String?,
    contactPersonName: json['contact_person_name'] as String?,
    contactPhone: json['contact_phone'] as String?,
    contactEmail: json['contact_email'] as String?,
    locationGovernorate: json['location_governorate'] as String?,
    locationArea: json['location_area'] as String?,
    signatureUrl: json['signature_url'] as String?,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: json['end_date'] != null
        ? DateTime.parse(json['end_date'] as String)
        : null,
    trialDays: json['trial_days'] as int?,
    trialEndDate: json['trial_end_date'] != null
        ? DateTime.parse(json['trial_end_date'] as String)
        : null,
    billingDay: json['billing_day'] as int?,
    refillDay: json['refill_day'] as int?,
    monthlyRentalValue: tryParseDecimal(json['monthly_rental_value']),
    totalContractValue: tryParseDecimal(json['total_contract_value']),
    snapshotDeviceMonthlyCost: tryParseDecimal(
      json['snapshot_device_monthly_cost'],
    ),
    snapshotOilMonthlyCost: tryParseDecimal(json['snapshot_oil_monthly_cost']),
    snapshotTotalMonthlyCost: tryParseDecimal(
      json['snapshot_total_monthly_cost'],
    ),
    snapshotMonthlyProfit: tryParseDecimal(json['snapshot_monthly_profit']),
    minProfitOverridden: json['min_profit_overridden'] as bool?,
    overrideReason: json['override_reason'] as String?,
    convertedFromContractId: json['converted_from_contract_id'] as String?,
    convertedToContractId: json['converted_to_contract_id'] as String?,
    renewedFromContractId: json['renewed_from_contract_id'] as String?,
    renewedToContractId: json['renewed_to_contract_id'] as String?,
    extensionReason: json['extension_reason'] as String?,
    returnedAt: json['returned_at'] != null
        ? DateTime.parse(json['returned_at'] as String)
        : null,
    returnReason: json['return_reason'] as String?,
    trialOutcome: json['trial_outcome'] as String?,
    returnCondition: returnConditionRaw != null
        ? ContractReturnCondition.fromDb(returnConditionRaw)
        : null,
    closureReason: json['closure_reason'] as String?,
    closedAt: json['closed_at'] != null
        ? DateTime.parse(json['closed_at'] as String)
        : null,
    notes: json['notes'] as String?,
    assetLines: assetsRaw is List
        ? assetsRaw
              .map(
                (line) => ContractAssetLine.fromRpcJson(
                  Map<String, dynamic>.from(line as Map),
                ),
              )
              .toList()
        : const [],
    consumableLines: consumablesRaw is List
        ? consumablesRaw
              .map(
                (line) => ContractConsumableLine.fromRpcJson(
                  Map<String, dynamic>.from(line as Map),
                ),
              )
              .toList()
        : const [],
    upcomingSchedule: scheduleRaw is List
        ? scheduleRaw
              .map(
                (event) => ContractScheduleEvent.fromRpcJson(
                  Map<String, dynamic>.from(event as Map),
                ),
              )
              .toList()
        : const [],
  );
}

String? parseRpcUuid(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

String parseRpcUuidRequired(dynamic value) => value.toString();
