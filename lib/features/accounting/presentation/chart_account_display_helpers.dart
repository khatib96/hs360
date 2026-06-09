import 'package:hs360/l10n/app_localizations.dart';

import '../domain/account_type.dart';
import '../domain/chart_account.dart';

String localizedAccountType(AppLocalizations l10n, AccountType type) {
  return switch (type) {
    AccountType.asset => l10n.chartAccountTypeAsset,
    AccountType.liability => l10n.chartAccountTypeLiability,
    AccountType.equity => l10n.chartAccountTypeEquity,
    AccountType.income => l10n.chartAccountTypeIncome,
    AccountType.expense => l10n.chartAccountTypeExpense,
  };
}

String localizedAccountName(ChartAccount account, String languageCode) {
  return account.displayName(languageCode);
}

List<ChartAccount> parentOptionsForCreate(
  List<ChartAccount> allAccounts,
  AccountType selectedType,
) {
  return allAccounts
      .where((a) => a.isActive && a.type == selectedType && !a.isEntityLinked)
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));
}

List<ChartAccount> allEligibleParentOptions(List<ChartAccount> allAccounts) {
  return allAccounts.where((a) => a.isActive && !a.isEntityLinked).toList()
    ..sort((a, b) => a.code.compareTo(b.code));
}
