import '../../../core/documents/domain/document_payload.dart';
import 'invoice_detail.dart';
import 'invoice_line.dart';
import 'invoice_print_support.dart';

InvoicePayload mapInvoiceDetailToPayload(InvoiceDetail detail) {
  final document = <String, dynamic>{
    'number': detail.invoiceNumber ?? '',
    'date': _dateOnly(detail.date),
    if (detail.dueDate != null) 'due_date': _dateOnly(detail.dueDate!),
    if (detail.notes != null && detail.notes!.trim().isNotEmpty)
      'notes': detail.notes,
    if (detail.returnReason != null && detail.returnReason!.trim().isNotEmpty)
      'return_reason': detail.returnReason,
  };

  final partyRef = detail.party;
  final party = <String, dynamic>{
    'name_ar': partyRef?.nameAr ?? '',
    'name_en': partyRef?.nameEn ?? '',
    if (partyRef?.code != null && partyRef!.code!.isNotEmpty)
      'code': partyRef.code,
  };

  return InvoicePayload(
    documentType: documentKindForInvoiceType(detail.type),
    document: document,
    party: party,
    lines: detail.lines.map(_mapLine).toList(),
    totals: {
      'subtotal': detail.subtotal,
      'discount': detail.discountAmount,
      'tax': detail.taxAmount,
      'total': detail.total,
    },
  );
}

Map<String, dynamic> _mapLine(InvoiceLine line) {
  return {
    'description': line.description ?? '',
    'qty': line.qty,
    'unit_price': line.unitPrice,
    'total': line.lineTotal,
  };
}

String _dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
