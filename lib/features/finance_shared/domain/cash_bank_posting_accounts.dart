import '../../accounting/domain/account_type.dart';
import '../../accounting/domain/accounting_permissions.dart';
import '../../accounting/domain/chart_account.dart';
import '../../auth/domain/app_session.dart';

/// Whether the session may load cash/bank posting accounts from chart of accounts.
///
/// There is no dedicated `list_cash_bank_accounts` RPC; [ChartAccountRepository]
/// is the only safe source and requires [canViewChartOfAccounts].
bool canLoadCashBankPostingAccounts(AppSession session) =>
    canViewChartOfAccounts(session);

/// Client-side filter matching SQL `validate_cash_bank_account`:
/// asset, active, not entity-linked, posting leaf.
List<ChartAccount> filterCashBankPostingAccounts(List<ChartAccount> accounts) {
  final parentIds = accounts
      .map((account) => account.parentId)
      .whereType<String>()
      .toSet();

  return accounts
      .where(
        (account) =>
            account.type == AccountType.asset &&
            account.isActive &&
            !account.isEntityLinked &&
            !parentIds.contains(account.id),
      )
      .toList();
}

/// Invoice cash settlement is intentionally narrower than voucher posting:
/// only the tenant's main cash box and main bank should appear on the invoice
/// form. Broader posting accounts still remain available in voucher screens.
List<ChartAccount> filterInvoiceCashBankAccounts(List<ChartAccount> accounts) {
  final posting = filterCashBankPostingAccounts(accounts);
  return posting
      .where((account) => account.code == '1101' || account.code == '1102')
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));
}
