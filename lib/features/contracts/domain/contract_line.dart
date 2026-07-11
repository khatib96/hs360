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
    this.productSku,
    this.productNameAr,
    this.productNameEn,
    this.productGroupNameAr,
    this.productGroupNameEn,
  });

  final String id;
  final String productId;
  final String? productUnitId;
  final int lineOrder;
  final Decimal? snapshotUnitCost;
  final Decimal? snapshotMonthlyCost;
  final String? serialNumber;
  final String? productSku;
  final String? productNameAr;
  final String? productNameEn;
  final String? productGroupNameAr;
  final String? productGroupNameEn;

  factory ContractAssetLine.fromRpcJson(Map<String, dynamic> json) {
    return ContractAssetLine(
      id: json['id'] as String? ?? json['line_id'] as String? ?? '',
      productId: json['product_id'] as String,
      productUnitId: json['product_unit_id'] as String?,
      lineOrder: json['line_order'] as int? ?? 0,
      snapshotUnitCost: tryParseDecimal(json['snapshot_unit_cost']),
      snapshotMonthlyCost: tryParseDecimal(json['snapshot_monthly_cost']),
      serialNumber: json['serial_number'] as String?,
      productSku: json['product_sku'] as String?,
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
      productGroupNameAr: json['product_group_name_ar'] as String?,
      productGroupNameEn: json['product_group_name_en'] as String?,
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
    this.productSku,
    this.productNameAr,
    this.productNameEn,
    this.productGroupNameAr,
    this.productGroupNameEn,
    this.currentOilProductId,
    this.currentOilProductNameAr,
    this.currentOilProductNameEn,
    this.currentQtyPerRefill,
    this.currentEffectiveFrom,
    this.scheduledOilProductId,
    this.scheduledOilProductNameAr,
    this.scheduledOilProductNameEn,
    this.scheduledQtyPerRefill,
    this.scheduledEffectiveFrom,
  });

  final String id;
  final String productId;
  final int lineOrder;
  final Decimal? qtyPerRefill;
  final int? refillFrequencyMonths;
  final Decimal? snapshotUnitCost;
  final Decimal? snapshotMonthlyCost;
  final String? productSku;
  final String? productNameAr;
  final String? productNameEn;
  final String? productGroupNameAr;
  final String? productGroupNameEn;
  final String? currentOilProductId;
  final String? currentOilProductNameAr;
  final String? currentOilProductNameEn;
  final Decimal? currentQtyPerRefill;
  final DateTime? currentEffectiveFrom;
  final String? scheduledOilProductId;
  final String? scheduledOilProductNameAr;
  final String? scheduledOilProductNameEn;
  final Decimal? scheduledQtyPerRefill;
  final DateTime? scheduledEffectiveFrom;

  factory ContractConsumableLine.fromRpcJson(Map<String, dynamic> json) {
    return ContractConsumableLine(
      id: json['id'] as String? ?? json['line_id'] as String? ?? '',
      productId: json['product_id'] as String,
      lineOrder: json['line_order'] as int? ?? 0,
      qtyPerRefill: tryParseDecimal(json['qty_per_refill']),
      refillFrequencyMonths: json['refill_frequency_months'] as int?,
      snapshotUnitCost: tryParseDecimal(json['snapshot_unit_cost']),
      snapshotMonthlyCost: tryParseDecimal(json['snapshot_monthly_cost']),
      productSku: json['product_sku'] as String?,
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
      productGroupNameAr: json['product_group_name_ar'] as String?,
      productGroupNameEn: json['product_group_name_en'] as String?,
      currentOilProductId: json['current_oil_product_id'] as String?,
      currentOilProductNameAr: json['current_oil_product_name_ar'] as String?,
      currentOilProductNameEn: json['current_oil_product_name_en'] as String?,
      currentQtyPerRefill: tryParseDecimal(json['current_qty_per_refill']),
      currentEffectiveFrom: _parseContractDate(json['current_effective_from']),
      scheduledOilProductId: json['scheduled_oil_product_id'] as String?,
      scheduledOilProductNameAr:
          json['scheduled_oil_product_name_ar'] as String?,
      scheduledOilProductNameEn:
          json['scheduled_oil_product_name_en'] as String?,
      scheduledQtyPerRefill: tryParseDecimal(json['scheduled_qty_per_refill']),
      scheduledEffectiveFrom: _parseContractDate(
        json['scheduled_effective_from'],
      ),
    );
  }
}

DateTime? _parseContractDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
