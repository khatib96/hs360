import '../domain/journal_entry_summary.dart';
import '../domain/journal_filters.dart';

class JournalListState {
  const JournalListState({
    this.entries = const [],
    this.filters = const JournalFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<JournalEntrySummary> entries;
  final JournalFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  bool get hasError => errorCode != null;

  JournalListState copyWith({
    List<JournalEntrySummary>? entries,
    JournalFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorCode,
    String? loadMoreErrorCode,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return JournalListState(
      entries: entries ?? this.entries,
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
