import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/journal/presentation/journal_source_navigation.dart';

void main() {
  group('routeForJournalSource', () {
    const id = 'doc-uuid';

    test('invoice sources link to invoice detail with type', () {
      expect(
        routeForJournalSource(JournalSource.salesInvoice, id),
        AppRoutes.invoiceDetailPath(id, type: InvoiceType.sales),
      );
      expect(
        routeForJournalSource(JournalSource.salesInvoiceReversal, id),
        AppRoutes.invoiceDetailPath(id, type: InvoiceType.sales),
      );
      expect(
        routeForJournalSource(JournalSource.purchaseReturnReversal, id),
        AppRoutes.invoiceDetailPath(id, type: InvoiceType.purchaseReturn),
      );
    });

    test('voucher sources link to voucher detail', () {
      expect(
        routeForJournalSource(JournalSource.receiptVoucher, id),
        AppRoutes.voucherDetailPath(id),
      );
      expect(
        routeForJournalSource(JournalSource.paymentVoucherReversal, id),
        AppRoutes.voucherDetailPath(id),
      );
      expect(
        routeForJournalSource(JournalSource.customerRefundVoucher, id),
        AppRoutes.voucherDetailPath(id),
      );
      expect(
        routeForJournalSource(JournalSource.supplierRefundReceipt, id),
        AppRoutes.voucherDetailPath(id),
      );
    });

    test('inventory sources link to inventory document detail', () {
      expect(
        routeForJournalSource(JournalSource.openingStock, id),
        AppRoutes.inventoryDocumentDetailPath(id),
      );
      expect(
        routeForJournalSource(JournalSource.inventoryStockIn, id),
        AppRoutes.inventoryDocumentDetailPath(id),
      );
      expect(
        routeForJournalSource(JournalSource.inventoryDocumentReversal, id),
        AppRoutes.inventoryDocumentDetailPath(id),
      );
    });

    test('label-only sources return null', () {
      expect(routeForJournalSource(JournalSource.manual, id), isNull);
      expect(routeForJournalSource(JournalSource.salaryPayment, id), isNull);
    });

    test('missing source id returns null without crash', () {
      expect(routeForJournalSource(JournalSource.salesInvoice, null), isNull);
      expect(routeForJournalSource(JournalSource.salesInvoice, ''), isNull);
      expect(routeForJournalSource(JournalSource.salesInvoice, '   '), isNull);
    });
  });
}
