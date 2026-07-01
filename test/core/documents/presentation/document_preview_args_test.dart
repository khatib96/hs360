import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/presentation/document_preview_state.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';

void main() {
  test('DocumentPreviewArgs equality includes invoiceType', () {
    const a = DocumentPreviewArgs(
      kind: DocumentKind.salesInvoice,
      entityId: 'inv-1',
      invoiceType: InvoiceType.sales,
    );
    const b = DocumentPreviewArgs(
      kind: DocumentKind.salesInvoice,
      entityId: 'inv-1',
      invoiceType: InvoiceType.sales,
    );
    const c = DocumentPreviewArgs(
      kind: DocumentKind.salesInvoice,
      entityId: 'inv-1',
      invoiceType: InvoiceType.purchase,
    );

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });
}
