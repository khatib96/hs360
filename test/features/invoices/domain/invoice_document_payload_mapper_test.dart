import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/invoices/domain/invoice_document_payload_mapper.dart';
import 'package:hs360/features/invoices/domain/invoice_line.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/domain/invoice_detail.dart';
import 'package:hs360/domain/finance/tax_class.dart';

InvoiceDetail _detail({
  InvoiceType type = InvoiceType.sales,
  List<InvoiceLine> lines = const [],
}) {
  return InvoiceDetail(
    id: 'inv-1',
    invoiceNumber: 'SI-001',
    type: type,
    status: InvoiceStatus.confirmed,
    date: DateTime(2026, 6, 1),
    dueDate: DateTime(2026, 6, 15),
    customer: const PartyReference(
      customerId: 'c-1',
      code: 'C-001',
      nameAr: 'عميل',
      nameEn: 'Customer',
    ),
    notes: 'Note',
    subtotal: Decimal.parse('100.000'),
    discountAmount: Decimal.parse('5.000'),
    taxAmount: Decimal.parse('0.000'),
    total: Decimal.parse('95.000'),
    paidAmount: Decimal.zero,
    outstanding: Decimal.parse('95.000'),
    lines: lines,
  );
}

InvoiceLine _line() {
  return InvoiceLine(
    id: 'line-1',
    lineOrder: 1,
    productId: 'p-1',
    description: 'Widget',
    qty: Decimal.parse('2'),
    unitPrice: Decimal.parse('50.000'),
    discountPct: Decimal.zero,
    grossAmount: Decimal.parse('100.000'),
    discountAmount: Decimal.zero,
    beforeTaxAmount: Decimal.parse('100.000'),
    taxRate: Decimal.zero,
    taxClass: ProductTaxClass.nonTaxable,
    taxableAmount: Decimal.parse('100.000'),
    taxAmount: Decimal.zero,
    afterTaxAmount: Decimal.parse('100.000'),
    lineTotal: Decimal.parse('100.000'),
  );
}

void main() {
  test('maps sales invoice with renderer field keys', () {
    final payload = mapInvoiceDetailToPayload(_detail(lines: [_line()]));

    expect(payload, isA<InvoicePayload>());
    expect(payload.documentType, DocumentKind.salesInvoice);
    expect(payload.document['number'], 'SI-001');
    expect(payload.document['date'], '2026-06-01');
    expect(payload.document['due_date'], '2026-06-15');
    expect(payload.document['notes'], 'Note');
    expect(payload.party['name_en'], 'Customer');

    final line = payload.lines.single;
    expect(line['description'], 'Widget');
    expect(line['qty'], Decimal.parse('2'));
    expect(line['unit_price'], Decimal.parse('50.000'));
    expect(line['total'], Decimal.parse('100.000'));
    expect(line.containsKey('line_total'), isFalse);

    expect(payload.totals['subtotal'], Decimal.parse('100.000'));
    expect(payload.totals['discount'], Decimal.parse('5.000'));
    expect(payload.totals['tax'], Decimal.parse('0.000'));
    expect(payload.totals['total'], Decimal.parse('95.000'));
  });

  test('maps purchase return to purchase invoice kind', () {
    final payload = mapInvoiceDetailToPayload(
      _detail(type: InvoiceType.purchaseReturn),
    );
    expect(payload.documentType, DocumentKind.purchaseInvoice);
  });
}
