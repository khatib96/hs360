import 'package:hs360/l10n/app_localizations.dart';

import '../../finance_shared/presentation/finance_error_messages.dart';
import '../domain/contract_status.dart';
import '../domain/contract_type.dart';

String contractErrorMessage(AppLocalizations l10n, String code) =>
    financeErrorMessage(l10n, code);

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
