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
  };
}
