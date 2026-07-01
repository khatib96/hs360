import '../../invoices/domain/invoice_filters.dart';
import '../../invoices/domain/invoice_summary.dart';
import '../../invoices/domain/invoice_type.dart';

class SupplierPurchaseInvoicesState {
  SupplierPurchaseInvoicesState({
    this.invoices = const [],
    this.filters = const InvoiceFilters(type: InvoiceType.purchase),
    this.isLoading = false,
    this.hasLoaded = false,
    this.permissionDenied = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<InvoiceSummary> invoices;
  final InvoiceFilters filters;
  final bool isLoading;
  final bool hasLoaded;
  final bool permissionDenied;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  SupplierPurchaseInvoicesState copyWith({
    List<InvoiceSummary>? invoices,
    InvoiceFilters? filters,
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
    return SupplierPurchaseInvoicesState(
      invoices: invoices ?? this.invoices,
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
