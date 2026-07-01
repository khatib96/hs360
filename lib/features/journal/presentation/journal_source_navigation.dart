import '../../../core/routing/app_routes.dart';
import '../../accounting/domain/journal_source.dart';
import '../../invoices/domain/invoice_type.dart';

/// Resolves a navigation path for a journal entry source document.
///
/// SQL stores the originating document id in `journal_entries.source_id` for
/// invoices, vouchers, returns, inventory documents, and their reversals.
/// When [sourceId] is missing or the source has no target screen, returns null
/// (show label only — no crash).
String? routeForJournalSource(JournalSource source, String? sourceId) {
  final id = sourceId?.trim();
  if (id == null || id.isEmpty) return null;

  switch (source) {
    case JournalSource.salesInvoice:
    case JournalSource.salesInvoiceReversal:
      return AppRoutes.invoiceDetailPath(id, type: InvoiceType.sales);
    case JournalSource.purchaseInvoice:
    case JournalSource.purchaseInvoiceReversal:
      return AppRoutes.invoiceDetailPath(id, type: InvoiceType.purchase);
    case JournalSource.salesReturn:
    case JournalSource.salesReturnReversal:
      return AppRoutes.invoiceDetailPath(id, type: InvoiceType.salesReturn);
    case JournalSource.purchaseReturn:
    case JournalSource.purchaseReturnReversal:
      return AppRoutes.invoiceDetailPath(id, type: InvoiceType.purchaseReturn);
    case JournalSource.receiptVoucher:
    case JournalSource.paymentVoucher:
    case JournalSource.receiptVoucherReversal:
    case JournalSource.paymentVoucherReversal:
    case JournalSource.customerRefundVoucher:
    case JournalSource.supplierRefundReceipt:
      return AppRoutes.voucherDetailPath(id);
    case JournalSource.openingStock:
    case JournalSource.inventoryStockIn:
    case JournalSource.inventoryStockOut:
    case JournalSource.stockCount:
    case JournalSource.inventoryAdjustment:
    case JournalSource.inventoryDocumentReversal:
      return AppRoutes.inventoryDocumentDetailPath(id);
    case JournalSource.manual:
    case JournalSource.rentalInvoice:
    case JournalSource.contractCreation:
    case JournalSource.contractClosure:
    case JournalSource.openingBalance:
    case JournalSource.salaryPayment:
      return null;
  }
}
