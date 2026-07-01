import '../domain/inventory_document_filters.dart';
import '../domain/inventory_document_summary.dart';

class InventoryDocumentListState {
  const InventoryDocumentListState({
    this.documents = const [],
    this.filters = const InventoryDocumentFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<InventoryDocumentSummary> documents;
  final InventoryDocumentFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  bool get hasError => errorCode != null;

  InventoryDocumentListState copyWith({
    List<InventoryDocumentSummary>? documents,
    InventoryDocumentFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorCode,
    String? loadMoreErrorCode,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return InventoryDocumentListState(
      documents: documents ?? this.documents,
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
