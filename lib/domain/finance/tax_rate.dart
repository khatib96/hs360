import 'package:decimal/decimal.dart';

import '../../core/utils/decimal_parser.dart';
import 'tax_class.dart';

class EffectiveTaxRate {
  const EffectiveTaxRate({
    this.rateId,
    required this.rate,
    required this.taxClass,
  });

  final String? rateId;
  final Decimal rate;
  final ProductTaxClass taxClass;

  factory EffectiveTaxRate.fromJson(Map<String, dynamic> json) {
    final rateRaw = json['tax_rate'];
    return EffectiveTaxRate(
      rateId: json['tax_rate_id'] as String?,
      rate: rateRaw == null ? Decimal.zero : parseDecimal(rateRaw),
      taxClass: ProductTaxClassDb.fromDb(
        json['tax_class'] as String? ?? 'non_taxable',
      ),
    );
  }
}

class TaxRateVersion {
  const TaxRateVersion({
    required this.id,
    required this.code,
    required this.rate,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isActive,
  });

  final String id;
  final String code;
  final Decimal rate;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;

  bool isEffectiveOn(DateTime date, {required bool requireActive}) {
    final day = DateTime(date.year, date.month, date.day);
    final from = DateTime(
      effectiveFrom.year,
      effectiveFrom.month,
      effectiveFrom.day,
    );
    if (day.isBefore(from)) return false;
    if (effectiveTo != null) {
      final to = DateTime(
        effectiveTo!.year,
        effectiveTo!.month,
        effectiveTo!.day,
      );
      if (day.isAfter(to)) return false;
    }
    if (requireActive && !isActive) return false;
    return true;
  }
}
