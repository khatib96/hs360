import '../domain/customer_balance_summary.dart';
import '../domain/customer_statement_row.dart';

class CustomerStatementState {
  CustomerStatementState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.permissionDenied = false,
    this.errorCode,
    this.loadMoreErrorCode,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.rows = const [],
    CustomerBalanceSummary? summary,
  }) : summary = summary ?? CustomerBalanceSummary.zero();

  final bool isLoading;
  final bool hasLoaded;
  final bool permissionDenied;
  final String? errorCode;
  final String? loadMoreErrorCode;
  final bool isLoadingMore;
  final bool hasMore;
  final List<CustomerStatementRow> rows;
  final CustomerBalanceSummary summary;

  CustomerStatementState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    bool? permissionDenied,
    String? errorCode,
    bool clearError = false,
    String? loadMoreErrorCode,
    bool clearLoadMoreError = false,
    bool? isLoadingMore,
    bool? hasMore,
    List<CustomerStatementRow>? rows,
    CustomerBalanceSummary? summary,
  }) {
    return CustomerStatementState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      rows: rows ?? this.rows,
      summary: summary ?? this.summary,
    );
  }
}
