import 'package:decimal/decimal.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../domain/invoice_detail.dart';
import '../domain/invoice_status.dart';
import '../domain/invoice_summary.dart';
import '../domain/invoice_type.dart';

/// Status filter chips shown per list type (server `p_status` only).
List<InvoiceStatus> statusFilterOptionsForType(InvoiceType type) {
  return switch (type) {
    InvoiceType.sales => const [
      InvoiceStatus.confirmed,
      InvoiceStatus.partiallyPaid,
      InvoiceStatus.paid,
      InvoiceStatus.cancelled,
    ],
    InvoiceType.purchase => InvoiceStatus.values,
    InvoiceType.salesReturn || InvoiceType.purchaseReturn => const [
      InvoiceStatus.confirmed,
      InvoiceStatus.cancelled,
    ],
  };
}

List<InvoiceStatus> statusFilterOptionsForTypes(List<InvoiceType> types) {
  final statuses = <InvoiceStatus>{};
  for (final type in types) {
    statuses.addAll(statusFilterOptionsForType(type));
  }
  return [
    for (final status in InvoiceStatus.values)
      if (statuses.contains(status)) status,
  ];
}

List<InvoiceType> invoiceListTypeOptions({
  required bool canViewSales,
  required bool canViewPurchase,
  required bool canViewReturns,
}) {
  final types = <InvoiceType>[];
  if (canViewSales) types.add(InvoiceType.sales);
  if (canViewPurchase) types.add(InvoiceType.purchase);
  if (canViewReturns) {
    types.add(InvoiceType.salesReturn);
    types.add(InvoiceType.purchaseReturn);
  }
  return types;
}

bool isReturnEligibleOriginal(InvoiceDetail detail) {
  if (detail.type.isReturn) return false;
  if (detail.type != InvoiceType.sales && detail.type != InvoiceType.purchase) {
    return false;
  }
  return detail.status == InvoiceStatus.confirmed ||
      detail.status == InvoiceStatus.partiallyPaid ||
      detail.status == InvoiceStatus.paid;
}

bool isInvoiceOverdue(InvoiceSummary invoice) {
  if (invoice.dueDate == null) return false;
  if (invoice.status != InvoiceStatus.confirmed &&
      invoice.status != InvoiceStatus.partiallyPaid) {
    return false;
  }
  final outstanding = invoice.outstanding ?? Decimal.zero;
  if (outstanding <= Decimal.zero) return false;
  final today = DateTime.now();
  final due = invoice.dueDate!;
  final dueDay = DateTime(due.year, due.month, due.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  return dueDay.isBefore(todayDay);
}

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

String partyDisplayName(String languageCode, {String? nameAr, String? nameEn}) {
  final ar = nameAr ?? '';
  final en = nameEn ?? '';
  if (languageCode.startsWith('ar')) {
    return ar.isNotEmpty ? ar : en;
  }
  return en.isNotEmpty ? en : ar;
}
