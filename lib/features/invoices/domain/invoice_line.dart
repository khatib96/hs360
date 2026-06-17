import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../../domain/finance/tax_class.dart';

/// Confirmed invoice line snapshot from detail RPC JSON.
class InvoiceLine {
  const InvoiceLine({
    required this.id,
    required this.lineOrder,
    required this.productId,
    this.productUnitId,
    this.serialNumber,
    this.description,
    required this.qty,
    required this.unitPrice,
    required this.discountPct,
    required this.grossAmount,
    required this.discountAmount,
    required this.beforeTaxAmount,
    this.taxRateId,
    required this.taxRate,
    required this.taxClass,
    required this.taxableAmount,
    required this.taxAmount,
    required this.afterTaxAmount,
    required this.lineTotal,
    this.costPrice,
    this.originalInvoiceLineId,
    this.productUnitIds = const [],
  });

  final String id;
  final int lineOrder;
  final String productId;
  final String? productUnitId;
  final String? serialNumber;
  final String? description;
  final Decimal qty;
  final Decimal unitPrice;
  final Decimal discountPct;
  final Decimal grossAmount;
  final Decimal discountAmount;
  final Decimal beforeTaxAmount;
  final String? taxRateId;
  final Decimal taxRate;
  final ProductTaxClass taxClass;
  final Decimal taxableAmount;
  final Decimal taxAmount;
  final Decimal afterTaxAmount;
  final Decimal lineTotal;
  final Decimal? costPrice;
  final String? originalInvoiceLineId;
  final List<String> productUnitIds;

  factory InvoiceLine.fromRpcJson(Map<String, dynamic> json) {
    final unitIdsRaw = json['product_unit_ids'];
    return InvoiceLine(
      id: json['id'] as String,
      lineOrder: json['line_order'] as int,
      productId: json['product_id'] as String,
      productUnitId: json['product_unit_id'] as String?,
      serialNumber: json['serial_number'] as String?,
      description: json['description'] as String?,
      qty: parseDecimal(json['qty']),
      unitPrice: parseDecimal(json['unit_price']),
      discountPct: parseDecimal(json['discount_pct']),
      grossAmount: parseDecimal(json['gross_amount']),
      discountAmount: parseDecimal(json['discount_amount']),
      beforeTaxAmount: parseDecimal(json['before_tax_amount']),
      taxRateId: json['tax_rate_id'] as String?,
      taxRate: parseDecimal(json['tax_rate'] ?? 0),
      taxClass: ProductTaxClassDb.fromDb(
        json['tax_class'] as String? ?? 'non_taxable',
      ),
      taxableAmount: parseDecimal(json['taxable_amount']),
      taxAmount: parseDecimal(json['tax_amount']),
      afterTaxAmount: parseDecimal(json['after_tax_amount']),
      lineTotal: parseDecimal(json['line_total']),
      costPrice: tryParseDecimal(json['cost_price']),
      originalInvoiceLineId: json['original_invoice_line_id'] as String?,
      productUnitIds: unitIdsRaw is List
          ? unitIdsRaw.map((e) => e as String).toList()
          : const [],
    );
  }
}
