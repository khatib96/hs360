import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Read model for a contract asset line.
class ContractAssetLine {
  const ContractAssetLine({
    required this.id,
    required this.productId,
    this.productUnitId,
    this.lineOrder = 0,
    this.snapshotUnitCost,
    this.snapshotMonthlyCost,
    this.serialNumber,
    this.productNameAr,
    this.productNameEn,
  });

  final String id;
  final String productId;
  final String? productUnitId;
  final int lineOrder;
  final Decimal? snapshotUnitCost;
  final Decimal? snapshotMonthlyCost;
  final String? serialNumber;
  final String? productNameAr;
  final String? productNameEn;

  factory ContractAssetLine.fromRpcJson(Map<String, dynamic> json) {
    return ContractAssetLine(
      id: json['id'] as String? ?? json['line_id'] as String? ?? '',
      productId: json['product_id'] as String,
      productUnitId: json['product_unit_id'] as String?,
      lineOrder: json['line_order'] as int? ?? 0,
      snapshotUnitCost: tryParseDecimal(json['snapshot_unit_cost']),
      snapshotMonthlyCost: tryParseDecimal(json['snapshot_monthly_cost']),
      serialNumber: json['serial_number'] as String?,
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
    );
  }
}

/// Read model for a contract consumable line.
class ContractConsumableLine {
  const ContractConsumableLine({
    required this.id,
    required this.productId,
    this.lineOrder = 0,
    this.qtyPerRefill,
    this.refillFrequencyMonths,
    this.snapshotUnitCost,
    this.snapshotMonthlyCost,
    this.productNameAr,
    this.productNameEn,
  });

  final String id;
  final String productId;
  final int lineOrder;
  final Decimal? qtyPerRefill;
  final int? refillFrequencyMonths;
  final Decimal? snapshotUnitCost;
  final Decimal? snapshotMonthlyCost;
  final String? productNameAr;
  final String? productNameEn;

  factory ContractConsumableLine.fromRpcJson(Map<String, dynamic> json) {
    return ContractConsumableLine(
      id: json['id'] as String? ?? json['line_id'] as String? ?? '',
      productId: json['product_id'] as String,
      lineOrder: json['line_order'] as int? ?? 0,
      qtyPerRefill: tryParseDecimal(json['qty_per_refill']),
      refillFrequencyMonths: json['refill_frequency_months'] as int?,
      snapshotUnitCost: tryParseDecimal(json['snapshot_unit_cost']),
      snapshotMonthlyCost: tryParseDecimal(json['snapshot_monthly_cost']),
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
    );
  }
}
