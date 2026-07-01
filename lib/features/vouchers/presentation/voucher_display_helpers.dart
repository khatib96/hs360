import 'package:hs360/l10n/app_localizations.dart';

import '../../finance_shared/presentation/finance_error_messages.dart';
import '../../invoices/domain/invoice_type.dart';
import '../domain/voucher_status.dart';
import '../domain/voucher_type.dart';

export '../../finance_shared/presentation/finance_display_helpers.dart'
    show paymentMethodLabel, voucherTypeLabel;

const voucherStatusFilterOptions = [
  VoucherStatus.confirmed,
  VoucherStatus.cancelled,
];

List<VoucherType> voucherListTypeOptions() => VoucherType.values;

InvoiceType invoiceTypeForVoucher(VoucherType type) {
  return switch (type) {
    VoucherType.receipt => InvoiceType.sales,
    VoucherType.payment => InvoiceType.purchase,
  };
}

String voucherErrorMessage(AppLocalizations l10n, String code) {
  return financeErrorMessage(l10n, code);
}

String voucherValidationMessages(AppLocalizations l10n, List<String> codes) {
  return financeErrorMessages(l10n, codes);
}

String voucherStatusLabel(AppLocalizations l10n, VoucherStatus status) {
  return switch (status) {
    VoucherStatus.confirmed => l10n.voucherStatusConfirmed,
    VoucherStatus.cancelled => l10n.voucherStatusCancelled,
  };
}

String voucherAccountDisplayName(
  String languageCode, {
  required String nameAr,
  required String nameEn,
  required String code,
}) {
  final name = partyDisplayName(languageCode, nameAr: nameAr, nameEn: nameEn);
  if (code.isEmpty) return name;
  return '$code — $name';
}

String partyDisplayName(String languageCode, {String? nameAr, String? nameEn}) {
  final ar = nameAr ?? '';
  final en = nameEn ?? '';
  if (languageCode.startsWith('ar')) {
    return ar.isNotEmpty ? ar : en;
  }
  return en.isNotEmpty ? en : ar;
}
