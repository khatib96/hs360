import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Asset line in pricing preview or contract detail.
class ContractPreviewAssetLine {
  const ContractPreviewAssetLine({
    required this.productId,
    this.productUnitId,
    this.sourceUnitCost,
    this.monthlyCost,
    this.costBasis,
    this.lifespanMonths,
  });

  final String productId;
  final String? productUnitId;
  final Decimal? sourceUnitCost;
  final Decimal? monthlyCost;
  final String? costBasis;
  final int? lifespanMonths;
}

/// Consumable line in pricing preview or contract detail.
class ContractPreviewConsumableLine {
  const ContractPreviewConsumableLine({
    required this.productId,
    this.qtyPerRefill,
    this.refillFrequencyMonths,
    this.qtyPrimary,
    this.sourceUnitCost,
    this.monthlyCost,
    this.costBasis,
  });

  final String productId;
  final Decimal? qtyPerRefill;
  final int? refillFrequencyMonths;
  final Decimal? qtyPrimary;
  final Decimal? sourceUnitCost;
  final Decimal? monthlyCost;
  final String? costBasis;
}

/// Read-only profit preview from `preview_contract_profit`.
///
/// Sensitive cost/profit fields are nullable when the server omits them.
class ContractPricingPreview {
  const ContractPricingPreview({
    this.monthlyRentalValue,
    this.passesMinProfit,
    this.belowMinProfit,
    this.requiresOverride,
    this.canOverride,
    this.minProfitOverridden,
    this.assetMonthlyCost,
    this.consumableMonthlyCost,
    this.totalMonthlyCost,
    this.expectedMonthlyProfit,
    this.minimumAllowedMonthlyValue,
    this.minMonthlyProfitThreshold,
    this.assetCostBasis,
    this.consumableCostBasis,
    this.assetLifespanMonths,
    this.assetLines = const [],
    this.consumableLines = const [],
  });

  final Decimal? monthlyRentalValue;
  final bool? passesMinProfit;
  final bool? belowMinProfit;
  final bool? requiresOverride;
  final bool? canOverride;
  final bool? minProfitOverridden;
  final Decimal? assetMonthlyCost;
  final Decimal? consumableMonthlyCost;
  final Decimal? totalMonthlyCost;
  final Decimal? expectedMonthlyProfit;
  final Decimal? minimumAllowedMonthlyValue;
  final Decimal? minMonthlyProfitThreshold;
  final String? assetCostBasis;
  final String? consumableCostBasis;
  final int? assetLifespanMonths;
  final List<ContractPreviewAssetLine> assetLines;
  final List<ContractPreviewConsumableLine> consumableLines;
}

ContractPreviewAssetLine mapPreviewAssetLine(Map<String, dynamic> json) {
  return ContractPreviewAssetLine(
    productId: json['product_id'] as String,
    productUnitId: json['product_unit_id'] as String?,
    sourceUnitCost: tryParseDecimal(json['source_unit_cost']),
    monthlyCost: tryParseDecimal(json['monthly_cost']),
    costBasis: json['cost_basis'] as String?,
    lifespanMonths: json['lifespan_months'] as int?,
  );
}

ContractPreviewConsumableLine mapPreviewConsumableLine(
  Map<String, dynamic> json,
) {
  return ContractPreviewConsumableLine(
    productId: json['product_id'] as String,
    qtyPerRefill: tryParseDecimal(json['qty_per_refill']),
    refillFrequencyMonths: json['refill_frequency_months'] as int?,
    qtyPrimary: tryParseDecimal(json['qty_primary']),
    sourceUnitCost: tryParseDecimal(json['source_unit_cost']),
    monthlyCost: tryParseDecimal(json['monthly_cost']),
    costBasis: json['cost_basis'] as String?,
  );
}
