import '../domain/calendar_enums.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_range_summary.dart';

/// Placeholder for future M7/M8 mutation outcomes (unused in M5).
enum CalendarMutationOutcome { none, success, failure }

/// UI / orchestration state for the main Calendar surface.
class CalendarState {
  CalendarState({
    this.isLoadingSummary = false,
    this.isLoadingAgenda = false,
    this.isLoadingMoreInRange = false,
    this.isLoadingMoreOverdue = false,
    this.permissionDenied = false,
    this.showSetupWarning = false,
    this.hasExplicitSelectedDate = false,
    required this.dateFrom,
    required this.dateTo,
    required this.selectedDate,
    CalendarFilters? filters,
    this.tenantLocalToday,
    this.timezoneName,
    this.workingScheduleConfigured = false,
    this.scope,
    this.filtersHash,
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
       days = List.unmodifiable(List<CalendarDaySummary>.from(days)),
       agendaEvents = List.unmodifiable(List<CalendarEvent>.from(agendaEvents)),
       overdueEvents = List.unmodifiable(
         List<CalendarEvent>.from(overdueEvents),
       );

  final bool isLoadingSummary;
  final bool isLoadingAgenda;
  final bool isLoadingMoreInRange;
  final bool isLoadingMoreOverdue;
  final bool permissionDenied;

  /// Non-blocking setup banner when schedule is unconfigured.
  final bool showSetupWarning;

  /// True after the user explicitly picks a date (survives refresh; resets on
  /// identity change).
  final bool hasExplicitSelectedDate;

  final DateTime dateFrom;
  final DateTime dateTo;
  final DateTime selectedDate;
  final CalendarFilters filters;

  final DateTime? tenantLocalToday;
  final String? timezoneName;
  final bool workingScheduleConfigured;
  final CalendarReadScope? scope;
  final String? filtersHash;
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
      isLoadingMoreInRange ||
      isLoadingMoreOverdue;

  bool get hasAgenda => agendaEvents.isNotEmpty;
  bool get hasOverdue => overdueEvents.isNotEmpty;

  CalendarState copyWith({
    bool? isLoadingSummary,
    bool? isLoadingAgenda,
    bool? isLoadingMoreInRange,
    bool? isLoadingMoreOverdue,
    bool? permissionDenied,
    bool? showSetupWarning,
    bool? hasExplicitSelectedDate,
    DateTime? dateFrom,
    DateTime? dateTo,
    DateTime? selectedDate,
    CalendarFilters? filters,
    DateTime? tenantLocalToday,
    bool clearTenantLocalToday = false,
    String? timezoneName,
    bool clearTimezoneName = false,
    bool? workingScheduleConfigured,
    CalendarReadScope? scope,
    bool clearScope = false,
    String? filtersHash,
    bool clearFiltersHash = false,
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
      isLoadingMoreInRange: isLoadingMoreInRange ?? this.isLoadingMoreInRange,
      isLoadingMoreOverdue: isLoadingMoreOverdue ?? this.isLoadingMoreOverdue,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      showSetupWarning: showSetupWarning ?? this.showSetupWarning,
      hasExplicitSelectedDate:
          hasExplicitSelectedDate ?? this.hasExplicitSelectedDate,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      selectedDate: selectedDate ?? this.selectedDate,
      filters: filters ?? this.filters,
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
