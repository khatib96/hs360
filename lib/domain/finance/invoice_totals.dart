import 'package:decimal/decimal.dart';

import 'invoice_line_math.dart';

class InvoiceTotals {
  const InvoiceTotals({
    required this.lines,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
  });

  final List<InvoiceLineSnapshot> lines;
  final Decimal subtotal;
  final Decimal discountAmount;
  final Decimal taxAmount;
  final Decimal total;

  Map<String, String> toNormalizedMap({required int decimalPlaces}) => {
        'subtotal': _formatInvoiceMoney(subtotal, decimalPlaces),
        'discount_amount': _formatInvoiceMoney(discountAmount, decimalPlaces),
        'tax_amount': _formatInvoiceMoney(taxAmount, decimalPlaces),
        'total': _formatInvoiceMoney(total, decimalPlaces),
      };
}

String _formatInvoiceMoney(Decimal value, int decimalPlaces) {
  if (decimalPlaces <= 0) {
    return value.round(scale: 0).toString();
  }
  final rounded = value.round(scale: decimalPlaces);
  final parts = rounded.toString().split('.');
  final fraction = parts.length > 1 ? parts[1] : '';
  final padded = fraction.padRight(decimalPlaces, '0').substring(0, decimalPlaces);
  return '${parts.first}.$padded';
}

InvoiceTotals calculateInvoiceTotals({
  required List<InvoiceLineInput> lines,
  required int decimalPlaces,
  required bool taxEnabled,
  String? effectiveTaxRateId,
  Decimal? effectiveTaxRate,
}) {
  final snapshots = <InvoiceLineSnapshot>[];
  var subtotal = Decimal.zero;
  var discountTotal = Decimal.zero;
  var taxTotal = Decimal.zero;

  for (final line in lines) {
    final snapshot = calculateInvoiceLineSnapshot(
      input: line,
      decimalPlaces: decimalPlaces,
      taxEnabled: taxEnabled,
      effectiveTaxRateId: taxEnabled ? effectiveTaxRateId : null,
      effectiveTaxRate: taxEnabled ? effectiveTaxRate : null,
    );
    snapshots.add(snapshot);
    subtotal += snapshot.grossAmount;
    discountTotal += snapshot.discountAmount;
    taxTotal += snapshot.taxAmount;
  }

  final total = subtotal - discountTotal + taxTotal;

  return InvoiceTotals(
    lines: snapshots,
    subtotal: subtotal,
    discountAmount: discountTotal,
    taxAmount: taxTotal,
    total: total,
  );
}
