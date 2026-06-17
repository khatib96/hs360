import 'package:decimal/decimal.dart';

/// Return line input linked to an original invoice line.
class ReturnInvoiceDraftLine {
  const ReturnInvoiceDraftLine({
    required this.lineOrder,
    required this.originalInvoiceLineId,
    required this.qty,
    this.productUnitId,
  });

  final int lineOrder;
  final String originalInvoiceLineId;
  final Decimal qty;
  final String? productUnitId;

  Map<String, dynamic> toPayload() {
    return {
      'line_order': lineOrder,
      'original_invoice_line_id': originalInvoiceLineId,
      'qty': qty.toString(),
      if (productUnitId != null) 'product_unit_id': productUnitId,
    };
  }
}

/// Return invoice form draft before record RPC.
class ReturnInvoiceDraft {
  const ReturnInvoiceDraft({
    required this.originalInvoiceId,
    required this.warehouseId,
    required this.date,
    required this.reason,
    this.notes,
    required this.lines,
  });

  final String originalInvoiceId;
  final String warehouseId;
  final DateTime date;
  final String reason;
  final String? notes;
  final List<ReturnInvoiceDraftLine> lines;

  Map<String, dynamic> toRecordPayload() {
    return {
      'original_invoice_id': originalInvoiceId,
      'warehouse_id': warehouseId,
      'date': _isoDate(date),
      'reason': reason.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      'lines': lines.map((l) => l.toPayload()).toList(),
    };
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
