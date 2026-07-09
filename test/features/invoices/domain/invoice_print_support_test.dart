import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/features/invoices/domain/invoice_print_support.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';

import '../fake_invoice_repository.dart';

void main() {
  test('documentKindForInvoiceType maps returns to invoice kinds', () {
    expect(
      documentKindForInvoiceType(InvoiceType.salesReturn),
      DocumentKind.salesInvoice,
    );
    expect(
      documentKindForInvoiceType(InvoiceType.purchaseReturn),
      DocumentKind.purchaseInvoice,
    );
  });

  test('isInvoicePrintable excludes draft and cancelled', () {
    expect(
      isInvoicePrintable(sampleInvoiceDetail(status: InvoiceStatus.confirmed)),
      isTrue,
    );
    expect(
      isInvoicePrintable(sampleInvoiceDetail(status: InvoiceStatus.draft)),
      isFalse,
    );
    expect(
      isInvoicePrintable(sampleInvoiceDetail(status: InvoiceStatus.cancelled)),
      isFalse,
    );
  });
}
