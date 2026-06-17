import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Original invoice line with returnable quantity from list RPC.
class ReturnableInvoiceLine {
  const ReturnableInvoiceLine({
    required this.originalLineId,
    required this.lineOrder,
    required this.productId,
    this.productUnitId,
    required this.originalQty,
    required this.returnedQty,
    required this.returnableQty,
    required this.unitPrice,
    required this.discountPct,
    required this.costPrice,
    required this.isSerialized,
  });

  final String originalLineId;
  final int lineOrder;
  final String productId;
  final String? productUnitId;
  final Decimal originalQty;
  final Decimal returnedQty;
  final Decimal returnableQty;
  final Decimal unitPrice;
  final Decimal discountPct;
  final Decimal costPrice;
  final bool isSerialized;

  factory ReturnableInvoiceLine.fromListRow(Map<String, dynamic> row) {
    return ReturnableInvoiceLine(
      originalLineId: row['original_line_id'] as String,
      lineOrder: row['line_order'] as int,
      productId: row['product_id'] as String,
      productUnitId: row['product_unit_id'] as String?,
      originalQty: parseDecimal(row['original_qty']),
      returnedQty: parseDecimal(row['returned_qty']),
      returnableQty: parseDecimal(row['returnable_qty']),
      unitPrice: parseDecimal(row['unit_price']),
      discountPct: parseDecimal(row['discount_pct']),
      costPrice: parseDecimal(row['cost_price']),
      isSerialized: row['is_serialized'] as bool? ?? false,
    );
  }
}
