import '../domain/calendar_working_date_exception.dart';

/// UI / orchestration state for the M7B date-exceptions settings section.
class CalendarWorkingDateExceptionsState {
  CalendarWorkingDateExceptionsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isMutating = false,
    this.permissionDenied = false,
    this.canEdit = false,
    int? selectedYear,
    this.statusFilter = CalendarWorkingDateExceptionStatusFilter.active,
    List<WorkingDateException> items = const [],
    this.hasMore = false,
    this.nextCursor,
    this.loadedDateFrom,
    this.loadedDateTo,
    this.loadedLimit,
    this.errorCode,
    this.loadMoreErrorCode,
    this.mutationErrorCode,
    this.mutationSuccessCode,
  }) : selectedYear = selectedYear ?? DateTime.now().year,
       items = List.unmodifiable(items);

  final bool isLoading;
  final bool isLoadingMore;
  final bool isMutating;
  final bool permissionDenied;
  final bool canEdit;
  final int selectedYear;
  final CalendarWorkingDateExceptionStatusFilter statusFilter;
  final List<WorkingDateException> items;
  final bool hasMore;
  final String? nextCursor;
  final DateTime? loadedDateFrom;
  final DateTime? loadedDateTo;
  final int? loadedLimit;
  final String? errorCode;
  final String? loadMoreErrorCode;

  /// Last create/update/cancel failure, shown as a persistent banner above
  /// the list (never a transient snackbar, so it survives screenshot capture
  /// and reload races).
  final String? mutationErrorCode;

  /// Last create/update/cancel success code, cleared on any new load/filter.
  final String? mutationSuccessCode;

  bool get isEmpty => !isLoading && errorCode == null && items.isEmpty;

  CalendarWorkingDateExceptionsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMutating,
    bool? permissionDenied,
    bool? canEdit,
    int? selectedYear,
    CalendarWorkingDateExceptionStatusFilter? statusFilter,
    List<WorkingDateException>? items,
    bool? hasMore,
    String? nextCursor,
    bool clearNextCursor = false,
    DateTime? loadedDateFrom,
    DateTime? loadedDateTo,
    int? loadedLimit,
    bool clearLoadedRange = false,
    String? errorCode,
    bool clearError = false,
    String? loadMoreErrorCode,
    bool clearLoadMoreError = false,
    String? mutationErrorCode,
    bool clearMutationError = false,
    String? mutationSuccessCode,
    bool clearMutationSuccess = false,
  }) {
    return CalendarWorkingDateExceptionsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMutating: isMutating ?? this.isMutating,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      canEdit: canEdit ?? this.canEdit,
      selectedYear: selectedYear ?? this.selectedYear,
      statusFilter: statusFilter ?? this.statusFilter,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      loadedDateFrom: clearLoadedRange
          ? null
          : (loadedDateFrom ?? this.loadedDateFrom),
      loadedDateTo: clearLoadedRange
          ? null
          : (loadedDateTo ?? this.loadedDateTo),
      loadedLimit: clearLoadedRange ? null : (loadedLimit ?? this.loadedLimit),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
      mutationErrorCode: clearMutationError
          ? null
          : (mutationErrorCode ?? this.mutationErrorCode),
      mutationSuccessCode: clearMutationSuccess
          ? null
          : (mutationSuccessCode ?? this.mutationSuccessCode),
    );
  }
}
