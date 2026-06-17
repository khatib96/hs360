import '../domain/invoice_filters.dart';
import '../domain/invoice_summary.dart';

class InvoiceListState {
  const InvoiceListState({
    this.invoices = const [],
    this.filters = const InvoiceFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<InvoiceSummary> invoices;
  final InvoiceFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  bool get hasError => errorCode != null;

  InvoiceListState copyWith({
    List<InvoiceSummary>? invoices,
    InvoiceFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorCode,
    String? loadMoreErrorCode,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return InvoiceListState(
      invoices: invoices ?? this.invoices,
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
