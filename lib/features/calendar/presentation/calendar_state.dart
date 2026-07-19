import '../domain/calendar_enums.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_month_grid.dart';
import '../domain/calendar_range_summary.dart';
import '../domain/calendar_route_scope.dart';

/// Placeholder for future M7/M8 mutation outcomes (unused in M5/M6).
enum CalendarMutationOutcome { none, success, failure }

/// Immutable snapshot of the last successfully adopted summary query.
class CalendarLoadedSummaryQuery {
  const CalendarLoadedSummaryQuery({
    required this.dateFrom,
    required this.dateTo,
    required this.filtersKey,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final String filtersKey;

  bool matches({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String filtersKey,
  }) {
    return this.dateFrom == dateFrom &&
        this.dateTo == dateTo &&
        this.filtersKey == filtersKey;
  }
}

/// UI / orchestration state for the main Calendar surface.
class CalendarState {
  CalendarState({
    this.isLoadingSummary = false,
    this.isLoadingAgenda = false,
    this.isLoadingOverdue = false,
    this.isLoadingMoreInRange = false,
    this.isLoadingMoreOverdue = false,
    this.permissionDenied = false,
    this.showSetupWarning = false,
    this.hasExplicitSelectedDate = false,
    required this.focusedMonth,
    this.firstDayOfWeekIndex,
    required this.dateFrom,
    required this.dateTo,
    required this.selectedDate,
    CalendarFilters? filters,
    this.loadedSummaryQuery,
    this.tenantLocalToday,
    this.timezoneName,
    this.workingScheduleConfigured = false,
    this.scope,
    this.filtersHash,
    CalendarRouteScope? routeScope,
    List<CalendarDaySummary> days = const [],
    this.overdueOutsideRangeSummary,
    List<CalendarEvent> agendaEvents = const [],
    List<CalendarEvent> overdueEvents = const [],
    this.nextCursorInRange,
    this.nextCursorOverdue,
    this.hasMoreInRange = false,
    this.hasMoreOverdue = false,
    this.summaryErrorCode,
    this.agendaErrorCode,
    this.loadMoreInRangeErrorCode,
    this.loadMoreOverdueErrorCode,
    this.overdueErrorCode,
    this.mutationOutcome = CalendarMutationOutcome.none,
  }) : filters = filters ?? CalendarFilters.empty,
       routeScope = routeScope ?? CalendarRouteScope.empty,
       days = List.unmodifiable(List<CalendarDaySummary>.from(days)),
       agendaEvents = List.unmodifiable(List<CalendarEvent>.from(agendaEvents)),
       overdueEvents = List.unmodifiable(
         List<CalendarEvent>.from(overdueEvents),
       );

  final bool isLoadingSummary;
  final bool isLoadingAgenda;

  /// Initial overdue-bucket load (distinct from [isLoadingMoreOverdue]).
  final bool isLoadingOverdue;
  final bool isLoadingMoreInRange;
  final bool isLoadingMoreOverdue;
  final bool permissionDenied;

  /// Non-blocking setup banner when schedule is unconfigured.
  final bool showSetupWarning;

  /// True after the user explicitly picks a date (survives refresh; resets on
  /// identity change).
  final bool hasExplicitSelectedDate;

  final DateTime focusedMonth;
  final int? firstDayOfWeekIndex;

  final DateTime dateFrom;
  final DateTime dateTo;
  final DateTime selectedDate;
  final CalendarFilters filters;

  final CalendarLoadedSummaryQuery? loadedSummaryQuery;

  final DateTime? tenantLocalToday;
  final String? timezoneName;
  final bool workingScheduleConfigured;
  final CalendarReadScope? scope;
  final String? filtersHash;

  /// Deep-link customer/contract/date scope from the Calendar route's query
  /// parameters. Kept separate from [filters] (see `CalendarRouteScope` doc).
  final CalendarRouteScope routeScope;
  final List<CalendarDaySummary> days;
  final CalendarOverdueOutsideRangeSummary? overdueOutsideRangeSummary;

  final List<CalendarEvent> agendaEvents;
  final List<CalendarEvent> overdueEvents;
  final String? nextCursorInRange;
  final String? nextCursorOverdue;
  final bool hasMoreInRange;
  final bool hasMoreOverdue;

  final String? summaryErrorCode;
  final String? agendaErrorCode;
  final String? loadMoreInRangeErrorCode;
  final String? loadMoreOverdueErrorCode;

  /// Independent error for the overdue-outside-range bucket (initial load).
  final String? overdueErrorCode;
  final CalendarMutationOutcome mutationOutcome;

  bool get isBusy =>
      isLoadingSummary ||
      isLoadingAgenda ||
      isLoadingOverdue ||
      isLoadingMoreInRange ||
      isLoadingMoreOverdue;

  bool get hasAgenda => agendaEvents.isNotEmpty;
  bool get hasOverdue => overdueEvents.isNotEmpty;

  bool get hasActiveFilters => filters != CalendarFilters.empty;

  /// True when the current route carries an unparseable deep-link scope.
  bool get routeScopeInvalid => routeScope.isInvalid;

  bool get isSummaryQueryAligned {
    final loaded = loadedSummaryQuery;
    if (loaded == null || days.isEmpty) return false;
    return loaded.matches(
      dateFrom: dateFrom,
      dateTo: dateTo,
      filtersKey: filters.canonicalQueryKey,
    );
  }

  CalendarDaySummary? get selectedDaySummary {
    if (!isSummaryQueryAligned) return null;
    for (final day in days) {
      if (day.date == selectedDate) return day;
    }
    return null;
  }

  CalendarState copyWith({
    bool? isLoadingSummary,
    bool? isLoadingAgenda,
    bool? isLoadingOverdue,
    bool? isLoadingMoreInRange,
    bool? isLoadingMoreOverdue,
    bool? permissionDenied,
    bool? showSetupWarning,
    bool? hasExplicitSelectedDate,
    DateTime? focusedMonth,
    int? firstDayOfWeekIndex,
    bool clearFirstDayOfWeekIndex = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    DateTime? selectedDate,
    CalendarFilters? filters,
    CalendarLoadedSummaryQuery? loadedSummaryQuery,
    bool clearLoadedSummaryQuery = false,
    DateTime? tenantLocalToday,
    bool clearTenantLocalToday = false,
    String? timezoneName,
    bool clearTimezoneName = false,
    bool? workingScheduleConfigured,
    CalendarReadScope? scope,
    bool clearScope = false,
    String? filtersHash,
    bool clearFiltersHash = false,
    CalendarRouteScope? routeScope,
    List<CalendarDaySummary>? days,
    CalendarOverdueOutsideRangeSummary? overdueOutsideRangeSummary,
    bool clearOverdueOutsideRangeSummary = false,
    List<CalendarEvent>? agendaEvents,
    List<CalendarEvent>? overdueEvents,
    String? nextCursorInRange,
    bool clearNextCursorInRange = false,
    String? nextCursorOverdue,
    bool clearNextCursorOverdue = false,
    bool? hasMoreInRange,
    bool? hasMoreOverdue,
    String? summaryErrorCode,
    bool clearSummaryError = false,
    String? agendaErrorCode,
    bool clearAgendaError = false,
    String? loadMoreInRangeErrorCode,
    bool clearLoadMoreInRangeError = false,
    String? loadMoreOverdueErrorCode,
    bool clearLoadMoreOverdueError = false,
    String? overdueErrorCode,
    bool clearOverdueError = false,
    CalendarMutationOutcome? mutationOutcome,
  }) {
    return CalendarState(
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
      isLoadingAgenda: isLoadingAgenda ?? this.isLoadingAgenda,
      isLoadingOverdue: isLoadingOverdue ?? this.isLoadingOverdue,
      isLoadingMoreInRange: isLoadingMoreInRange ?? this.isLoadingMoreInRange,
      isLoadingMoreOverdue: isLoadingMoreOverdue ?? this.isLoadingMoreOverdue,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      showSetupWarning: showSetupWarning ?? this.showSetupWarning,
      hasExplicitSelectedDate:
          hasExplicitSelectedDate ?? this.hasExplicitSelectedDate,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      firstDayOfWeekIndex: clearFirstDayOfWeekIndex
          ? null
          : (firstDayOfWeekIndex ?? this.firstDayOfWeekIndex),
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      selectedDate: selectedDate ?? this.selectedDate,
      filters: filters ?? this.filters,
      loadedSummaryQuery: clearLoadedSummaryQuery
          ? null
          : (loadedSummaryQuery ?? this.loadedSummaryQuery),
      tenantLocalToday: clearTenantLocalToday
          ? null
          : (tenantLocalToday ?? this.tenantLocalToday),
      timezoneName: clearTimezoneName
          ? null
          : (timezoneName ?? this.timezoneName),
      workingScheduleConfigured:
          workingScheduleConfigured ?? this.workingScheduleConfigured,
      scope: clearScope ? null : (scope ?? this.scope),
      filtersHash: clearFiltersHash ? null : (filtersHash ?? this.filtersHash),
      routeScope: routeScope ?? this.routeScope,
      days: days ?? this.days,
      overdueOutsideRangeSummary: clearOverdueOutsideRangeSummary
          ? null
          : (overdueOutsideRangeSummary ?? this.overdueOutsideRangeSummary),
      agendaEvents: agendaEvents ?? this.agendaEvents,
      overdueEvents: overdueEvents ?? this.overdueEvents,
      nextCursorInRange: clearNextCursorInRange
          ? null
          : (nextCursorInRange ?? this.nextCursorInRange),
      nextCursorOverdue: clearNextCursorOverdue
          ? null
          : (nextCursorOverdue ?? this.nextCursorOverdue),
      hasMoreInRange: hasMoreInRange ?? this.hasMoreInRange,
      hasMoreOverdue: hasMoreOverdue ?? this.hasMoreOverdue,
      summaryErrorCode: clearSummaryError
          ? null
          : (summaryErrorCode ?? this.summaryErrorCode),
      agendaErrorCode: clearAgendaError
          ? null
          : (agendaErrorCode ?? this.agendaErrorCode),
      loadMoreInRangeErrorCode: clearLoadMoreInRangeError
          ? null
          : (loadMoreInRangeErrorCode ?? this.loadMoreInRangeErrorCode),
      loadMoreOverdueErrorCode: clearLoadMoreOverdueError
          ? null
          : (loadMoreOverdueErrorCode ?? this.loadMoreOverdueErrorCode),
      overdueErrorCode: clearOverdueError
          ? null
          : (overdueErrorCode ?? this.overdueErrorCode),
      mutationOutcome: mutationOutcome ?? this.mutationOutcome,
    );
  }
}

/// Convenience: bare-month provisional bounds before week-start is known.
({DateTime dateFrom, DateTime dateTo}) provisionalMonthBounds(DateTime month) {
  final focused = focusedMonthOnly(month);
  return (
    dateFrom: focused,
    dateTo: DateTime(focused.year, focused.month + 1, 0),
  );
}
