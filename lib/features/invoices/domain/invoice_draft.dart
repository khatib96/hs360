import 'package:decimal/decimal.dart';

import 'invoice_type.dart';

/// Purchase serialized unit input for confirm payload.
class InvoiceDraftUnitInput {
  const InvoiceDraftUnitInput({this.serialNumber, this.barcode});

  final String? serialNumber;
  final String? barcode;

  Map<String, dynamic> toPayload() {
    return {
      if (serialNumber?.trim().isNotEmpty == true)
        'serial_number': serialNumber!.trim(),
      if (barcode?.trim().isNotEmpty == true) 'barcode': barcode!.trim(),
    };
  }
}

/// Editable invoice line for draft/confirm forms.
class InvoiceDraftLine {
  const InvoiceDraftLine({
    required this.lineOrder,
    required this.productId,
    required this.qty,
    required this.unitPrice,
    required this.discountPct,
    this.productUnitId,
    this.units = const [],
  });

  final int lineOrder;
  final String productId;
  final Decimal qty;
  final Decimal unitPrice;
  final Decimal discountPct;
  final String? productUnitId;
  final List<InvoiceDraftUnitInput> units;

  Map<String, dynamic> toSalesPayload() {
    return {
      'line_order': lineOrder,
      'product_id': productId,
      'qty': qty.toString(),
      'unit_price': unitPrice.toString(),
      'discount_pct': discountPct.toString(),
      if (productUnitId != null) 'product_unit_id': productUnitId,
    };
  }

  Map<String, dynamic> toPurchasePayload() {
    return {
      'line_order': lineOrder,
      'product_id': productId,
      'qty': qty.toString(),
      'unit_price': unitPrice.toString(),
      'discount_pct': discountPct.toString(),
      if (units.isNotEmpty) 'units': units.map((u) => u.toPayload()).toList(),
    };
  }
}

/// In-memory draft before save/confirm RPC.
class InvoiceDraft {
  const InvoiceDraft({
    required this.type,
    this.invoiceId,
    this.customerId,
    this.supplierId,
    required this.warehouseId,
    required this.date,
    this.dueDate,
    this.notes,
    required this.lines,
  });

  final InvoiceType type;
  final String? invoiceId;
  final String? customerId;
  final String? supplierId;
  final String warehouseId;
  final DateTime date;
  final DateTime? dueDate;
  final String? notes;
  final List<InvoiceDraftLine> lines;
}
