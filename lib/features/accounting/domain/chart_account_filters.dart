import 'chart_account.dart';
import 'account_type.dart';

/// Query filters for chart-of-accounts tree (applied locally to [allAccounts]).
class ChartAccountFilters {
  const ChartAccountFilters({this.search, this.type, this.isActive});

  final String? search;
  final AccountType? type;
  final bool? isActive;

  bool get hasActiveFilters =>
      search?.trim().isNotEmpty == true || type != null || isActive != null;

  bool get hasNonDefaultFilters =>
      search?.trim().isNotEmpty == true || type != null || isActive != true;
}

bool matchesVisibleFilters(ChartAccount account, ChartAccountFilters filters) {
  if (filters.type != null && account.type != filters.type) {
    return false;
  }
  if (filters.isActive != null && account.isActive != filters.isActive) {
    return false;
  }
  return true;
}
