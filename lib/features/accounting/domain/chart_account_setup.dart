import 'account_type.dart';
import 'chart_account.dart';

/// Diagnostic setup state for required A/R and A/P parent accounts.
class ChartAccountSetupIssues {
  const ChartAccountSetupIssues({
    required this.missingArParent,
    required this.missingApParent,
  });

  final bool missingArParent;
  final bool missingApParent;

  bool get hasAnyIssue => missingArParent || missingApParent;

  static const accountsReceivableParentCode = '1201';
  static const accountsPayableParentCode = '2101';
}

bool _hasValidArParent(List<ChartAccount> accounts) => accounts.any(
      (a) =>
          a.code == ChartAccountSetupIssues.accountsReceivableParentCode &&
          a.type == AccountType.asset &&
          a.isActive,
    );

bool _hasValidApParent(List<ChartAccount> accounts) => accounts.any(
      (a) =>
          a.code == ChartAccountSetupIssues.accountsPayableParentCode &&
          a.type == AccountType.liability &&
          a.isActive,
    );

ChartAccountSetupIssues detectAccountingSetupIssues(
  List<ChartAccount> allAccounts,
) {
  return ChartAccountSetupIssues(
    missingArParent: !_hasValidArParent(allAccounts),
    missingApParent: !_hasValidApParent(allAccounts),
  );
}
