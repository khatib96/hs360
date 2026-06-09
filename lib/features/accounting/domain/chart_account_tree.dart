import 'chart_account.dart';

/// Node in a hierarchical chart-of-accounts tree.
class ChartAccountTreeNode {
  const ChartAccountTreeNode({required this.account, this.children = const []});

  final ChartAccount account;
  final List<ChartAccountTreeNode> children;
}

/// Builds a sorted tree from a flat [ChartAccount] list.
List<ChartAccountTreeNode> buildChartAccountTree(List<ChartAccount> accounts) {
  final accountIds = accounts.map((account) => account.id).toSet();
  final byParent = <String?, List<ChartAccount>>{};
  for (final account in accounts) {
    final parentId = account.parentId;
    final effectiveParentId = parentId != null && accountIds.contains(parentId)
        ? parentId
        : null;
    byParent.putIfAbsent(effectiveParentId, () => []).add(account);
  }
  for (final list in byParent.values) {
    list.sort(_compareAccounts);
  }

  final visited = <String>{};

  ChartAccountTreeNode buildNode(ChartAccount account, Set<String> path) {
    visited.add(account.id);
    final nextPath = {...path, account.id};
    final children = (byParent[account.id] ?? [])
        .where((child) => !nextPath.contains(child.id))
        .map((child) => buildNode(child, nextPath))
        .toList();
    return ChartAccountTreeNode(account: account, children: children);
  }

  final roots = (byParent[null] ?? [])
      .map((account) => buildNode(account, const {}))
      .toList();
  final result = [...roots];
  final remaining = [...accounts]..sort(_compareAccounts);
  for (final account in remaining) {
    if (visited.contains(account.id)) continue;
    result.add(buildNode(account, const {}));
  }

  return result;
}

int _compareAccounts(ChartAccount a, ChartAccount b) {
  final codeCompare = a.code.compareTo(b.code);
  if (codeCompare != 0) return codeCompare;
  return a.nameEn.compareTo(b.nameEn);
}
