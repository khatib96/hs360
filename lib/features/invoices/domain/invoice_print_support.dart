import '../../../core/documents/domain/document_kind.dart';
import 'invoice_detail.dart';
import 'invoice_type.dart';

DocumentKind documentKindForInvoiceType(InvoiceType type) {
  return switch (type) {
    InvoiceType.sales || InvoiceType.salesReturn => DocumentKind.salesInvoice,
    InvoiceType.purchase ||
    InvoiceType.purchaseReturn => DocumentKind.purchaseInvoice,
  };
}

bool isInvoicePrintable(InvoiceDetail detail) => detail.status.isPosted;
