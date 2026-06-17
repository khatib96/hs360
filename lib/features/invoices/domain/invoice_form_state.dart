import '../../finance_shared/domain/date_range.dart';
import 'invoice_draft.dart';
import 'invoice_type.dart';

/// Form state for invoice create/edit/cancel RPC payloads.
class InvoiceFormState {
  const InvoiceFormState({required this.draft, this.cancellationReason});

  final InvoiceDraft draft;
  final String? cancellationReason;

  Map<String, dynamic> toRecordPayload() {
    return switch (draft.type) {
      InvoiceType.sales => {
        'customer_id': draft.customerId,
        'date': _isoDate(draft.date),
        if (draft.dueDate != null) 'due_date': _isoDate(draft.dueDate!),
        'warehouse_id': draft.warehouseId,
        if (draft.notes?.trim().isNotEmpty == true)
          'notes': draft.notes!.trim(),
        'lines': draft.lines.map((l) => l.toSalesPayload()).toList(),
      },
      InvoiceType.purchase => {
        if (draft.invoiceId != null) 'invoice_id': draft.invoiceId,
        'supplier_id': draft.supplierId,
        'date': _isoDate(draft.date),
        if (draft.dueDate != null) 'due_date': _isoDate(draft.dueDate!),
        'warehouse_id': draft.warehouseId,
        if (draft.notes?.trim().isNotEmpty == true)
          'notes': draft.notes!.trim(),
        'lines': draft.lines.map((l) => l.toPurchasePayload()).toList(),
      },
      InvoiceType.salesReturn || InvoiceType.purchaseReturn => throw StateError(
        'Use ReturnInvoiceDraft for return invoices',
      ),
    };
  }

  Map<String, dynamic> toDraftPayload() {
    if (draft.type != InvoiceType.purchase) {
      throw StateError('Draft save RPC supports purchase invoices only');
    }
    return {
      'type': draft.type.toDb(),
      if (draft.invoiceId != null) 'invoice_id': draft.invoiceId,
      'supplier_id': draft.supplierId,
      'date': _isoDate(draft.date),
      if (draft.dueDate != null) 'due_date': _isoDate(draft.dueDate!),
      'warehouse_id': draft.warehouseId,
      if (draft.notes?.trim().isNotEmpty == true) 'notes': draft.notes!.trim(),
      'lines': draft.lines
          .map(
            (l) => {
              'line_order': l.lineOrder,
              'product_id': l.productId,
              'qty': l.qty.toString(),
              'unit_price': l.unitPrice.toString(),
              'discount_pct': l.discountPct.toString(),
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> toCancelPayload(String invoiceId) {
    final reason = cancellationReason?.trim() ?? '';
    return {'invoice_id': invoiceId, 'reason': reason};
  }
}

String _isoDate(DateTime date) => dateRangeToIsoDate(date)!;
