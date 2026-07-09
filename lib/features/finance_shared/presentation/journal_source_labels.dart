import 'package:hs360/l10n/app_localizations.dart';

import '../../accounting/domain/journal_source.dart';

String journalSourceLabel(AppLocalizations l10n, JournalSource source) {
  return switch (source) {
    JournalSource.manual => l10n.journalSourceManual,
    JournalSource.salesInvoice => l10n.journalSourceSalesInvoice,
    JournalSource.purchaseInvoice => l10n.journalSourcePurchaseInvoice,
    JournalSource.receiptVoucher => l10n.journalSourceReceiptVoucher,
    JournalSource.paymentVoucher => l10n.journalSourcePaymentVoucher,
    JournalSource.rentalInvoice => l10n.journalSourceRentalInvoice,
    JournalSource.contractCreation => l10n.journalSourceContractCreation,
    JournalSource.contractClosure => l10n.journalSourceContractClosure,
    JournalSource.openingBalance => l10n.journalSourceOpeningBalance,
    JournalSource.inventoryAdjustment => l10n.journalSourceInventoryAdjustment,
    JournalSource.salaryPayment => l10n.journalSourceSalaryPayment,
    JournalSource.salesInvoiceReversal =>
      l10n.journalSourceSalesInvoiceReversal,
    JournalSource.purchaseInvoiceReversal =>
      l10n.journalSourcePurchaseInvoiceReversal,
    JournalSource.receiptVoucherReversal =>
      l10n.journalSourceReceiptVoucherReversal,
    JournalSource.paymentVoucherReversal =>
      l10n.journalSourcePaymentVoucherReversal,
    JournalSource.salesReturn => l10n.journalSourceSalesReturn,
    JournalSource.purchaseReturn => l10n.journalSourcePurchaseReturn,
    JournalSource.salesReturnReversal => l10n.journalSourceSalesReturnReversal,
    JournalSource.purchaseReturnReversal =>
      l10n.journalSourcePurchaseReturnReversal,
    JournalSource.customerRefundVoucher =>
      l10n.journalSourceCustomerRefundVoucher,
    JournalSource.supplierRefundReceipt =>
      l10n.journalSourceSupplierRefundReceipt,
    JournalSource.openingStock => l10n.journalSourceOpeningStock,
    JournalSource.inventoryStockIn => l10n.journalSourceInventoryStockIn,
    JournalSource.inventoryStockOut => l10n.journalSourceInventoryStockOut,
    JournalSource.stockCount => l10n.journalSourceStockCount,
    JournalSource.inventoryDocumentReversal =>
      l10n.journalSourceInventoryDocumentReversal,
  };
}
