import 'chart_account.dart';

bool matchesChartAccountSearch(ChartAccount account, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return account.code.toLowerCase().contains(q) ||
      account.nameAr.toLowerCase().contains(q) ||
      account.nameEn.toLowerCase().contains(q);
}

Map<String, ChartAccount> _accountById(List<ChartAccount> accounts) {
  return {for (final account in accounts) account.id: account};
}

Set<String> _collectAncestorIds(
  ChartAccount account,
  Map<String, ChartAccount> byId,
) {
  final ids = <String>{};
  var parentId = account.parentId;
  final visited = <String>{account.id};
  while (parentId != null && !visited.contains(parentId)) {
    visited.add(parentId);
    ids.add(parentId);
    final parent = byId[parentId];
    if (parent == null) break;
    parentId = parent.parentId;
  }
  return ids;
}

/// Filters flat accounts for tree display; ancestors always from [allAccounts].
List<ChartAccount> filterAccountsForTree({
  required List<ChartAccount> allAccounts,
  required bool Function(ChartAccount) visiblePredicate,
  String? search,
}) {
  final byId = _accountById(allAccounts);
  final trimmedSearch = search?.trim();
  final hasSearch = trimmedSearch != null && trimmedSearch.isNotEmpty;

  var matches = allAccounts.where(visiblePredicate).toList();
  if (hasSearch) {
    matches = matches
        .where((account) => matchesChartAccountSearch(account, trimmedSearch))
        .toList();
  }

  final includeIds = <String>{};
  for (final account in matches) {
    includeIds.add(account.id);
    includeIds.addAll(_collectAncestorIds(account, byId));
  }

  return allAccounts.where((a) => includeIds.contains(a.id)).toList();
}

Set<String> ancestorIdsToExpand({
  required List<ChartAccount> allAccounts,
  required bool Function(ChartAccount) visiblePredicate,
  String? search,
}) {
  final trimmedSearch = search?.trim();
  if (trimmedSearch == null || trimmedSearch.isEmpty) return const {};

  final byId = _accountById(allAccounts);
  final ids = <String>{};
  for (final account in allAccounts) {
    if (!visiblePredicate(account)) continue;
    if (!matchesChartAccountSearch(account, trimmedSearch)) continue;
    ids.addAll(_collectAncestorIds(account, byId));
  }
  return ids;
}
