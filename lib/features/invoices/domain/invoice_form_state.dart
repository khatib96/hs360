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
        if (draft.customerId?.trim().isNotEmpty == true)
          'customer_id': draft.customerId!.trim(),
        if (draft.cashAccountId?.trim().isNotEmpty == true)
          'cash_account_id': draft.cashAccountId!.trim(),
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
        'Use toDirectReturnPayload for direct returns or ReturnInvoiceDraft for linked returns',
      ),
    };
  }

  Map<String, dynamic> toDirectReturnPayload() {
    if (!draft.type.isReturn) {
      throw StateError('Direct return payload supports return invoices only');
    }
    final reason = draft.notes?.trim();
    final isSalesReturn = draft.type == InvoiceType.salesReturn;
    return {
      if (draft.customerId?.trim().isNotEmpty == true)
        'customer_id': draft.customerId!.trim(),
      if (draft.supplierId?.trim().isNotEmpty == true)
        'supplier_id': draft.supplierId!.trim(),
      if (draft.cashAccountId?.trim().isNotEmpty == true)
        'cash_account_id': draft.cashAccountId!.trim(),
      'date': _isoDate(draft.date),
      'warehouse_id': draft.warehouseId,
      'reason': reason?.isNotEmpty == true ? reason : 'direct_return',
      if (reason?.isNotEmpty == true) 'notes': reason,
      'lines': draft.lines
          .map(
            (line) => isSalesReturn
                ? line.toSalesPayload()
                : line.toPurchasePayload(),
          )
          .toList(),
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
