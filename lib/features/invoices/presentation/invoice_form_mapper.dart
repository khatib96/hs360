import 'package:decimal/decimal.dart';

import '../domain/invoice_draft.dart';
import '../domain/invoice_detail.dart';
import '../domain/invoice_form_state.dart' as domain;
import '../domain/invoice_type.dart';

/// Maps a purchase invoice detail snapshot into editable form state.
domain.InvoiceFormState purchaseDetailToInvoiceFormState(InvoiceDetail detail) {
  if (detail.type != InvoiceType.purchase) {
    throw ArgumentError('Expected purchase invoice, got ${detail.type}');
  }

  return domain.InvoiceFormState(
    draft: InvoiceDraft(
      type: InvoiceType.purchase,
      invoiceId: detail.id,
      supplierId: detail.supplier?.supplierId,
      warehouseId: detail.warehouse?.id ?? '',
      date: detail.date,
      dueDate: detail.dueDate,
      notes: detail.notes,
      lines: detail.lines
          .map(
            (line) => InvoiceDraftLine(
              lineOrder: line.lineOrder,
              productId: line.productId,
              qty: line.qty,
              unitPrice: line.unitPrice,
              discountPct: line.discountPct,
              productUnitId: line.productUnitId,
              units: line.productUnitIds
                  .map((_) => const InvoiceDraftUnitInput())
                  .toList(),
            ),
          )
          .toList(),
    ),
  );
}

/// Client-side estimate for return credit from frozen returnable line fields.
Decimal estimateReturnLineCredit(ReturnableLineEstimateInput input) {
  final gross = input.unitPrice * input.qty;
  final discount = (gross * input.discountPct / Decimal.fromInt(100)).toDecimal(
    scaleOnInfinitePrecision: 10,
  );
  return gross - discount;
}

class ReturnableLineEstimateInput {
  const ReturnableLineEstimateInput({
    required this.qty,
    required this.unitPrice,
    required this.discountPct,
  });

  final Decimal qty;
  final Decimal unitPrice;
  final Decimal discountPct;
}
