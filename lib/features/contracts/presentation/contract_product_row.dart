import 'package:decimal/decimal.dart';

/// Unified product row for the contract detail products table.
class ContractProductRow {
  const ContractProductRow({
    required this.lineOrder,
    required this.isAsset,
    this.productSku,
    required this.productNameAr,
    required this.productNameEn,
    this.productGroupNameAr,
    this.productGroupNameEn,
    this.serialNumber,
    this.quantity,
    this.refillFrequencyMonths,
    this.snapshotUnitCost,
    this.snapshotMonthlyCost,
  });

  final int lineOrder;
  final bool isAsset;
  final String? productSku;
  final String? productNameAr;
  final String? productNameEn;
  final String? productGroupNameAr;
  final String? productGroupNameEn;
  final String? serialNumber;
  final Decimal? quantity;
  final int? refillFrequencyMonths;
  final Decimal? snapshotUnitCost;
  final Decimal? snapshotMonthlyCost;
}
