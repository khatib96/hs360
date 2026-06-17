import '../domain/voucher_filters.dart';
import '../domain/voucher_summary.dart';

class VoucherListState {
  const VoucherListState({
    this.vouchers = const [],
    this.filters = const VoucherFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<VoucherSummary> vouchers;
  final VoucherFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  bool get hasError => errorCode != null;

  VoucherListState copyWith({
    List<VoucherSummary>? vouchers,
    VoucherFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorCode,
    String? loadMoreErrorCode,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return VoucherListState(
      vouchers: vouchers ?? this.vouchers,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
    );
  }
}
