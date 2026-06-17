import 'package:hs360/l10n/app_localizations.dart';

import '../../invoices/domain/invoice_status.dart';
import '../../invoices/domain/invoice_type.dart';
import '../../vouchers/domain/voucher_type.dart';
import '../domain/payment_method.dart';

String invoiceTypeLabel(AppLocalizations l10n, InvoiceType type) {
  return switch (type) {
    InvoiceType.sales => l10n.invoiceTypeSales,
    InvoiceType.purchase => l10n.invoiceTypePurchase,
    InvoiceType.salesReturn => l10n.invoiceTypeSalesReturn,
    InvoiceType.purchaseReturn => l10n.invoiceTypePurchaseReturn,
  };
}

String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus status) {
  return switch (status) {
    InvoiceStatus.draft => l10n.invoiceStatusDraft,
    InvoiceStatus.confirmed => l10n.invoiceStatusConfirmed,
    InvoiceStatus.partiallyPaid => l10n.invoiceStatusPartiallyPaid,
    InvoiceStatus.paid => l10n.invoiceStatusPaid,
    InvoiceStatus.cancelled => l10n.invoiceStatusCancelled,
  };
}

String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => l10n.paymentMethodCash,
    PaymentMethod.knet => l10n.paymentMethodKnet,
    PaymentMethod.bankTransfer => l10n.paymentMethodBankTransfer,
    PaymentMethod.cheque => l10n.paymentMethodCheque,
    PaymentMethod.other => l10n.paymentMethodOther,
  };
}

String voucherTypeLabel(AppLocalizations l10n, VoucherType type) {
  return switch (type) {
    VoucherType.receipt => l10n.voucherTypeReceipt,
    VoucherType.payment => l10n.voucherTypePayment,
  };
}
