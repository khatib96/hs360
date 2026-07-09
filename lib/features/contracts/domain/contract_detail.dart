import 'package:decimal/decimal.dart';

import 'contract_line.dart';
import 'contract_return_condition.dart';
import 'contract_status.dart';
import 'contract_type.dart';

/// Minimal contract detail shell grounded in known schema columns.
///
/// Tolerant parsing: optional keys stay null for future `get_contract_detail`.
class ContractDetail {
  const ContractDetail({
    required this.id,
    this.contractNumber,
    required this.type,
    required this.status,
    this.customerId,
    this.customerNameAr,
    this.customerNameEn,
    this.serviceLocationId,
    this.serviceLocationName,
    required this.startDate,
    this.endDate,
    this.trialDays,
    this.trialEndDate,
    this.billingDay,
    this.refillDay,
    this.monthlyRentalValue,
    this.totalContractValue,
    this.snapshotDeviceMonthlyCost,
    this.snapshotOilMonthlyCost,
    this.snapshotTotalMonthlyCost,
    this.snapshotMonthlyProfit,
    this.minProfitOverridden,
    this.overrideReason,
    this.convertedFromContractId,
    this.convertedToContractId,
    this.renewedFromContractId,
    this.renewedToContractId,
    this.extensionReason,
    this.returnedAt,
    this.returnReason,
    this.trialOutcome,
    this.returnCondition,
    this.closureReason,
    this.closedAt,
    this.notes,
    this.assetLines = const [],
    this.consumableLines = const [],
  });

  final String id;
  final String? contractNumber;
  final ContractType type;
  final ContractStatus status;
  final String? customerId;
  final String? customerNameAr;
  final String? customerNameEn;
  final String? serviceLocationId;
  final String? serviceLocationName;
  final DateTime startDate;
  final DateTime? endDate;
  final int? trialDays;
  final DateTime? trialEndDate;
  final int? billingDay;
  final int? refillDay;
  final Decimal? monthlyRentalValue;
  final Decimal? totalContractValue;
  final Decimal? snapshotDeviceMonthlyCost;
  final Decimal? snapshotOilMonthlyCost;
  final Decimal? snapshotTotalMonthlyCost;
  final Decimal? snapshotMonthlyProfit;
  final bool? minProfitOverridden;
  final String? overrideReason;
  final String? convertedFromContractId;
  final String? convertedToContractId;
  final String? renewedFromContractId;
  final String? renewedToContractId;
  final String? extensionReason;
  final DateTime? returnedAt;
  final String? returnReason;
  final String? trialOutcome;
  final ContractReturnCondition? returnCondition;
  final String? closureReason;
  final DateTime? closedAt;
  final String? notes;
  final List<ContractAssetLine> assetLines;
  final List<ContractConsumableLine> consumableLines;
}
