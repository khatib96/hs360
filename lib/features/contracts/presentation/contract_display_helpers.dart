import 'package:decimal/decimal.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/scan_exception.dart';
import '../../finance_shared/presentation/finance_error_messages.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_draft.dart';
import '../domain/contract_status.dart';
import '../domain/contract_type.dart';
import 'contract_form_draft_builder.dart';
import 'contract_product_row.dart';

String contractErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    ScanException.scanNotFound => l10n.scanErrorNotFound,
    ScanException.scanAmbiguous => l10n.scanErrorAmbiguous,
    _ => financeErrorMessage(l10n, code),
  };
}

List<String> contractValidationMessages(
  AppLocalizations l10n,
  Iterable<String> codes,
) {
  return codes.map((code) => contractErrorMessage(l10n, code)).toList();
}

int? contractDraftDurationMonths(ContractDraft draft) {
  final end = contractDraftEffectiveEndDate(draft);
  if (end == null) return null;
  return billingMonthsBetween(draft.startDate, end);
}

Decimal? contractDraftDisplayTotalValue(ContractDraft draft) {
  if (draft.type != ContractType.rental) return null;
  final monthly = draft.monthlyRentalValue;
  final months = contractDraftDurationMonths(draft);
  if (monthly == null || months == null || months <= 0) return null;
  return monthly * Decimal.fromInt(months);
}

String contractTypeLabel(AppLocalizations l10n, ContractType type) {
  return switch (type) {
    ContractType.trial => l10n.contractTypeTrial,
    ContractType.rental => l10n.contractTypeRental,
  };
}

String contractStatusLabel(AppLocalizations l10n, ContractStatus status) {
  return switch (status) {
    ContractStatus.draft => l10n.contractStatusDraft,
    ContractStatus.active => l10n.contractStatusActive,
    ContractStatus.suspended => l10n.contractStatusSuspended,
    ContractStatus.completed => l10n.contractStatusCompleted,
    ContractStatus.terminatedEarly => l10n.contractStatusTerminatedEarly,
    ContractStatus.expired => l10n.contractStatusExpired,
  };
}

String formatContractDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String contractCustomerName({
  required String languageCode,
  String? nameAr,
  String? nameEn,
}) {
  final isArabic = languageCode.toLowerCase().startsWith('ar');
  final primary = isArabic ? nameAr : nameEn;
  final fallback = isArabic ? nameEn : nameAr;
  return (primary?.trim().isNotEmpty == true
          ? primary
          : fallback?.trim().isNotEmpty == true
          ? fallback
          : null) ??
      '—';
}

const contractStatusFilterOptions = <ContractStatus>[
  ContractStatus.draft,
  ContractStatus.active,
  ContractStatus.suspended,
  ContractStatus.completed,
  ContractStatus.terminatedEarly,
  ContractStatus.expired,
];

const contractTypeFilterOptions = <ContractType>[
  ContractType.trial,
  ContractType.rental,
];

/// Full billing months between [start] and [end].
///
/// Example: 2026-07-09 → 2027-07-09 = 12 months (not 13).
int? billingMonthsBetween(DateTime start, DateTime end) {
  if (end.isBefore(start)) return null;

  var months = (end.year - start.year) * 12 + (end.month - start.month);
  if (end.day < start.day) {
    months -= 1;
  }
  return months < 0 ? null : months;
}

/// Derives contract duration in full billing months.
int? contractDurationMonths(ContractDetail detail) {
  final end =
      detail.endDate ??
      (detail.type == ContractType.trial ? detail.trialEndDate : null);
  if (end == null) return null;
  return billingMonthsBetween(detail.startDate, end);
}

/// Display-only total: prefers stored value, else monthly × duration.
Decimal? contractDisplayTotalValue(ContractDetail detail) {
  final stored = detail.totalContractValue;
  if (stored != null) return stored;

  final monthly = detail.monthlyRentalValue;
  final months = contractDurationMonths(detail);
  if (monthly == null || months == null || months <= 0) return null;
  return monthly * Decimal.fromInt(months);
}

List<ContractProductRow> buildContractProductRows(ContractDetail detail) {
  final rows = <ContractProductRow>[
    for (final line in detail.assetLines)
      ContractProductRow(
        lineOrder: line.lineOrder,
        isAsset: true,
        productSku: line.productSku,
        productNameAr: line.productNameAr,
        productNameEn: line.productNameEn,
        productGroupNameAr: line.productGroupNameAr,
        productGroupNameEn: line.productGroupNameEn,
        serialNumber: line.serialNumber,
        quantity: Decimal.one,
        snapshotUnitCost: line.snapshotUnitCost,
        snapshotMonthlyCost: line.snapshotMonthlyCost,
      ),
    for (final line in detail.consumableLines)
      ContractProductRow(
        lineOrder: line.lineOrder,
        isAsset: false,
        productSku: line.productSku,
        productNameAr: line.productNameAr,
        productNameEn: line.productNameEn,
        productGroupNameAr: line.productGroupNameAr,
        productGroupNameEn: line.productGroupNameEn,
        quantity: line.qtyPerRefill,
        refillFrequencyMonths: line.refillFrequencyMonths,
        snapshotUnitCost: line.snapshotUnitCost,
        snapshotMonthlyCost: line.snapshotMonthlyCost,
      ),
  ];
  rows.sort((a, b) {
    final order = a.lineOrder.compareTo(b.lineOrder);
    if (order != 0) return order;
    if (a.isAsset == b.isAsset) return 0;
    return a.isAsset ? -1 : 1;
  });
  return rows;
}

String contractLocationSummary({String? governorate, String? area}) {
  return [
    if (governorate?.trim().isNotEmpty == true) governorate!.trim(),
    if (area?.trim().isNotEmpty == true) area!.trim(),
  ].join(' - ');
}

String contractProductTypeLabel(AppLocalizations l10n, bool isAsset) {
  return isAsset
      ? l10n.contractProductTypeAsset
      : l10n.contractProductTypeConsumable;
}

/// Formats remaining days for schedule rows. Negative values indicate overdue.
String formatRemainingDays(AppLocalizations l10n, int days) {
  if (days < 0) {
    return l10n.contractRemainingDaysOverdue(days.abs());
  }
  return l10n.contractRemainingDays(days);
}

bool isRemainingDaysOverdue(int days) => days < 0;
