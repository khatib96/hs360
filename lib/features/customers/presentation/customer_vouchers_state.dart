import '../../vouchers/domain/voucher_filters.dart';
import '../../vouchers/domain/voucher_summary.dart';

class CustomerVouchersState {
  CustomerVouchersState({
    this.vouchers = const [],
    this.filters = const VoucherFilters(),
    this.isLoading = false,
    this.hasLoaded = false,
    this.permissionDenied = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<VoucherSummary> vouchers;
  final VoucherFilters filters;
  final bool isLoading;
  final bool hasLoaded;
  final bool permissionDenied;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  CustomerVouchersState copyWith({
    List<VoucherSummary>? vouchers,
    VoucherFilters? filters,
    bool? isLoading,
    bool? hasLoaded,
    bool? permissionDenied,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorCode,
    bool clearError = false,
    String? loadMoreErrorCode,
    bool clearLoadMoreError = false,
  }) {
    return CustomerVouchersState(
      vouchers: vouchers ?? this.vouchers,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
    );
  }
}
