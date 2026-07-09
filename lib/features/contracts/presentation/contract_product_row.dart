import 'package:decimal/decimal.dart';

/// Unified product row for the contract detail products table.
class ContractProductRow {
  const ContractProductRow({
    required this.lineOrder,
    required this.isAsset,
    required this.productNameAr,
    required this.productNameEn,
    this.serialNumber,
    this.quantity,
    this.refillFrequencyMonths,
  });

  final int lineOrder;
  final bool isAsset;
  final String? productNameAr;
  final String? productNameEn;
  final String? serialNumber;
  final Decimal? quantity;
  final int? refillFrequencyMonths;
}
