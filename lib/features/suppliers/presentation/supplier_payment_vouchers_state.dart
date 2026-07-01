import '../../vouchers/domain/voucher_filters.dart';
import '../../vouchers/domain/voucher_summary.dart';
import '../../vouchers/domain/voucher_type.dart';

class SupplierPaymentVouchersState {
  SupplierPaymentVouchersState({
    this.vouchers = const [],
    this.filters = const VoucherFilters(type: VoucherType.payment),
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

  SupplierPaymentVouchersState copyWith({
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
    return SupplierPaymentVouchersState(
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
