import 'package:decimal/decimal.dart';

import 'tax_class.dart';

class InvoiceLineInput {
  const InvoiceLineInput({
    required this.productId,
    required this.qty,
    required this.unitPrice,
    required this.discountPct,
    required this.taxClass,
  });

  final String productId;
  final Decimal qty;
  final Decimal unitPrice;
  final Decimal discountPct;
  final ProductTaxClass taxClass;
}

class InvoiceLineSnapshot {
  const InvoiceLineSnapshot({
    required this.productId,
    required this.taxClass,
    required this.grossAmount,
    required this.discountAmount,
    required this.beforeTaxAmount,
    this.taxRateId,
    required this.taxRate,
    required this.taxableAmount,
    required this.taxAmount,
    required this.afterTaxAmount,
    required this.lineTotal,
  });

  final String productId;
  final ProductTaxClass taxClass;
  final Decimal grossAmount;
  final Decimal discountAmount;
  final Decimal beforeTaxAmount;
  final String? taxRateId;
  final Decimal taxRate;
  final Decimal taxableAmount;
  final Decimal taxAmount;
  final Decimal afterTaxAmount;
  final Decimal lineTotal;

  Map<String, String> toNormalizedMap({required int decimalPlaces}) => {
        'gross_amount': _formatMoney(grossAmount, decimalPlaces),
        'discount_amount': _formatMoney(discountAmount, decimalPlaces),
        'before_tax_amount': _formatMoney(beforeTaxAmount, decimalPlaces),
        'tax_rate': taxRate.toString(),
        'taxable_amount': _formatMoney(taxableAmount, decimalPlaces),
        'tax_amount': _formatMoney(taxAmount, decimalPlaces),
        'after_tax_amount': _formatMoney(afterTaxAmount, decimalPlaces),
        'line_total': _formatMoney(lineTotal, decimalPlaces),
      };
}

String _formatMoney(Decimal value, int decimalPlaces) {
  if (decimalPlaces <= 0) {
    return value.round(scale: 0).toString();
  }
  final rounded = value.round(scale: decimalPlaces);
  final parts = rounded.toString().split('.');
  final fraction = parts.length > 1 ? parts[1] : '';
  final padded = fraction.padRight(decimalPlaces, '0').substring(0, decimalPlaces);
  return '${parts.first}.$padded';
}

Decimal roundMoney(Decimal value, int decimalPlaces) {
  if (decimalPlaces > 3) {
    throw ArgumentError('decimal_places above 3 are unsupported in v1');
  }
  if (decimalPlaces <= 0) {
    return value.round(scale: 0);
  }
  return value.round(scale: decimalPlaces);
}

InvoiceLineSnapshot calculateInvoiceLineSnapshot({
  required InvoiceLineInput input,
  required int decimalPlaces,
  required bool taxEnabled,
  String? effectiveTaxRateId,
  Decimal? effectiveTaxRate,
}) {
  if (decimalPlaces > 3) {
    throw ArgumentError('decimal_places above 3 are unsupported in v1');
  }
  if (input.qty <= Decimal.zero) {
    throw ArgumentError('qty must be positive');
  }
  if (input.unitPrice < Decimal.zero) {
    throw ArgumentError('unit_price must be non-negative');
  }
  if (input.discountPct < Decimal.zero || input.discountPct > Decimal.fromInt(100)) {
    throw ArgumentError('discount_pct must be between 0 and 100');
  }

  final grossAmount = roundMoney(input.qty * input.unitPrice, decimalPlaces);
  final discountAmount = roundMoney(
    (grossAmount * input.discountPct / Decimal.fromInt(100)).toDecimal(),
    decimalPlaces,
  );
  final beforeTaxAmount = grossAmount - discountAmount;

  var taxRateId = effectiveTaxRateId;
  var taxRate = effectiveTaxRate ?? Decimal.zero;
  var taxableAmount = Decimal.zero;
  var taxAmount = Decimal.zero;

  if (taxEnabled && input.taxClass == ProductTaxClass.taxable) {
    taxableAmount = beforeTaxAmount;
    taxAmount = roundMoney(
      (taxableAmount * taxRate / Decimal.fromInt(100)).toDecimal(),
      decimalPlaces,
    );
  } else if (taxEnabled && input.taxClass == ProductTaxClass.zeroRated) {
    taxRateId = null;
    taxRate = Decimal.zero;
    taxableAmount = beforeTaxAmount;
    taxAmount = Decimal.zero;
  } else {
    taxRateId = null;
    taxRate = Decimal.zero;
    taxableAmount = Decimal.zero;
    taxAmount = Decimal.zero;
  }

  final afterTaxAmount = beforeTaxAmount + taxAmount;

  return InvoiceLineSnapshot(
    productId: input.productId,
    taxClass: input.taxClass,
    grossAmount: grossAmount,
    discountAmount: discountAmount,
    beforeTaxAmount: beforeTaxAmount,
    taxRateId: taxRateId,
    taxRate: taxRate,
    taxableAmount: taxableAmount,
    taxAmount: taxAmount,
    afterTaxAmount: afterTaxAmount,
    lineTotal: afterTaxAmount,
  );
}
