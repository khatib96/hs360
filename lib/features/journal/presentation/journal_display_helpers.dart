import 'package:hs360/l10n/app_localizations.dart';

import '../../accounting/domain/journal_source.dart';
import '../../finance_shared/presentation/finance_error_messages.dart';

export '../../finance_shared/presentation/journal_source_labels.dart'
    show journalSourceLabel;

String journalErrorMessage(AppLocalizations l10n, String code) {
  return financeErrorMessage(l10n, code);
}

String journalEntryDescription(
  String languageCode, {
  String? descriptionAr,
  String? descriptionEn,
}) {
  final ar = descriptionAr ?? '';
  final en = descriptionEn ?? '';
  if (languageCode.startsWith('ar')) {
    return ar.isNotEmpty ? ar : en;
  }
  return en.isNotEmpty ? en : ar;
}

String journalAccountDisplayName(
  String languageCode, {
  required String? nameAr,
  required String? nameEn,
  required String? code,
}) {
  final ar = nameAr ?? '';
  final en = nameEn ?? '';
  final name = languageCode.startsWith('ar')
      ? (ar.isNotEmpty ? ar : en)
      : (en.isNotEmpty ? en : ar);
  final accountCode = code ?? '';
  if (accountCode.isEmpty) return name.isEmpty ? '—' : name;
  return '$accountCode — $name';
}

bool journalEntryIsReversal(JournalSource source) {
  return switch (source) {
    JournalSource.salesInvoiceReversal ||
    JournalSource.purchaseInvoiceReversal ||
    JournalSource.receiptVoucherReversal ||
    JournalSource.paymentVoucherReversal ||
    JournalSource.salesReturnReversal ||
    JournalSource.purchaseReturnReversal ||
    JournalSource.inventoryDocumentReversal => true,
    _ => false,
  };
}
