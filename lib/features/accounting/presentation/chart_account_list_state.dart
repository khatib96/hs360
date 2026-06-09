import '../domain/chart_account.dart';
import '../domain/chart_account_filters.dart';
import '../domain/chart_account_setup.dart';
import '../domain/chart_account_tree.dart';
import '../domain/chart_account_tree_filter.dart';

/// Immutable UI state for the chart-of-accounts tree.
class ChartAccountListState {
  const ChartAccountListState({
    this.allAccounts = const [],
    this.filters = const ChartAccountFilters(isActive: true),
    this.expandedIds = const {},
    this.setupIssues = const ChartAccountSetupIssues(
      missingArParent: false,
      missingApParent: false,
    ),
    this.isLoading = false,
    this.errorCode,
  });

  final List<ChartAccount> allAccounts;
  final ChartAccountFilters filters;
  final Set<String> expandedIds;
  final ChartAccountSetupIssues setupIssues;
  final bool isLoading;
  final String? errorCode;

  bool get hasError => errorCode != null;

  List<ChartAccount> get visibleAccounts =>
      allAccounts.where((a) => matchesVisibleFilters(a, filters)).toList();

  List<ChartAccountTreeNode> get treeNodes {
    bool predicate(ChartAccount account) =>
        matchesVisibleFilters(account, filters);
    final filtered = filterAccountsForTree(
      allAccounts: allAccounts,
      visiblePredicate: predicate,
      search: filters.search,
    );
    return buildChartAccountTree(filtered);
  }

  Set<String> get searchAncestorIds => ancestorIdsToExpand(
    allAccounts: allAccounts,
    visiblePredicate: (a) => matchesVisibleFilters(a, filters),
    search: filters.search,
  );

  Set<String> get effectiveExpandedIds => {
    ...expandedIds,
    ...searchAncestorIds,
  };

  ChartAccountListState copyWith({
    List<ChartAccount>? allAccounts,
    ChartAccountFilters? filters,
    Set<String>? expandedIds,
    ChartAccountSetupIssues? setupIssues,
    bool? isLoading,
    String? errorCode,
    bool clearError = false,
  }) {
    return ChartAccountListState(
      allAccounts: allAccounts ?? this.allAccounts,
      filters: filters ?? this.filters,
      expandedIds: expandedIds ?? this.expandedIds,
      setupIssues: setupIssues ?? this.setupIssues,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
