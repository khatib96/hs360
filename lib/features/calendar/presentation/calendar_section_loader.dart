import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_enums.dart';
import '../domain/calendar_event_list_result.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_month_grid.dart';
import '../domain/calendar_permissions.dart';
import 'calendar_section_pagination.dart';
import 'calendar_state.dart';

/// Owns section load generations and summary / agenda / overdue fetches.
class CalendarSectionLoader {
  CalendarSectionLoader({
    required this.readState,
    required this.writeState,
    required this.readSession,
    required this.readRepo,
    required this.reloadAll,
  }) : _pagination = CalendarSectionPagination(
         readState: readState,
         writeState: writeState,
         readSession: readSession,
         readRepo: readRepo,
       );

  final CalendarState Function() readState;
  final void Function(CalendarState) writeState;
  final AppSession? Function() readSession;
  final CalendarRepository Function() readRepo;

  /// Full triple reload (summary + agenda + overdue), used after assigned-only
  /// filter strip and when adopting tenant today outside the focused month.
  final Future<void> Function() reloadAll;

  final CalendarSectionPagination _pagination;

  int summaryGeneration = 0;
  int agendaGeneration = 0;

  int get inRangePaginationGeneration =>
      _pagination.inRangePaginationGeneration;
  set inRangePaginationGeneration(int value) =>
      _pagination.inRangePaginationGeneration = value;

  int get overduePaginationGeneration =>
      _pagination.overduePaginationGeneration;
  set overduePaginationGeneration(int value) =>
      _pagination.overduePaginationGeneration = value;

  CalendarState get _state => readState();
  set _state(CalendarState value) => writeState(value);

  void invalidateAll() {
    summaryGeneration++;
    agendaGeneration++;
    _pagination.invalidate();
  }

  void invalidatePagination() {
    _pagination.invalidate();
  }

  void _applyPaddedRangeForFocusedMonth(
    DateTime focused, {
    required bool clearSummary,
    DateTime? selectedDate,
  }) {
    final weekStart = _state.firstDayOfWeekIndex;
    if (weekStart == null) return;
    final range = calendarPaddedMonthRange(
      focused,
      firstDayOfWeekIndex: weekStart,
    );
    _state = _state.copyWith(
      focusedMonth: focusedMonthOnly(focused),
      dateFrom: range.dateFrom,
      dateTo: range.dateTo,
      selectedDate: selectedDate,
      clearLoadedSummaryQuery: clearSummary,
      days: clearSummary ? const [] : null,
      clearOverdueOutsideRangeSummary: clearSummary,
    );
  }

  /// Invalid deep links must not fall back to an unfiltered calendar read.
  bool _blockInvalidScopeLoad() {
    if (!_state.routeScope.blocksRepositoryReads) return false;
    _state = _state.copyWith(
      days: const [],
      agendaEvents: const [],
      overdueEvents: const [],
      clearOverdueOutsideRangeSummary: true,
      clearLoadedSummaryQuery: true,
      clearNextCursorInRange: true,
      clearNextCursorOverdue: true,
      hasMoreInRange: false,
      hasMoreOverdue: false,
      isLoadingSummary: false,
      isLoadingAgenda: false,
      isLoadingOverdue: false,
      clearSummaryError: true,
      clearAgendaError: true,
      clearOverdueError: true,
    );
    return true;
  }

  Future<void> loadSummary() async {
    final session = readSession();
    if (session == null || !canAccessCalendar(session)) return;
    if (_state.firstDayOfWeekIndex == null) return;
    if (_blockInvalidScopeLoad()) return;

    final gen = ++summaryGeneration;
    final requestedFrom = _state.dateFrom;
    final requestedTo = _state.dateTo;
    final requestedFilters = _state.filters;
    final requestedKey = requestedFilters.canonicalQueryKey;
    // Route scope (customer/contract deep link) is merged into the RPC
    // payload only; requestedFilters (UI-facing) stays untouched.
    final requestFilters = _state.routeScope.mergeIntoFilters(requestedFilters);
    _state = _state.copyWith(isLoadingSummary: true, clearSummaryError: true);

    try {
      final result = await readRepo().getRangeSummary(
        session,
        dateFrom: requestedFrom,
        dateTo: requestedTo,
        filters: requestFilters,
      );
      if (gen != summaryGeneration) return;

      if (result.dateFrom != requestedFrom ||
          result.dateTo != requestedTo ||
          result.filtersApplied.canonicalQueryKey !=
              requestFilters.canonicalQueryKey) {
        _state = _state.copyWith(
          isLoadingSummary: false,
          summaryErrorCode: CalendarException.malformedResponse,
          clearLoadedSummaryQuery: true,
          days: const [],
        );
        return;
      }

      final setupWarning =
          !result.workingScheduleConfigured ||
          result.overdueOutsideRange.state ==
              CalendarOverdueOutsideRangeState.scheduleUnconfigured ||
          result.tenantLocalToday == null;

      final today = result.tenantLocalToday == null
          ? null
          : calendarDateOnly(result.tenantLocalToday!);

      var nextFilters = _state.filters;
      if (result.scope == CalendarReadScope.assignedOnly ||
          !canViewTenantCalendar(session)) {
        nextFilters = nextFilters.withoutAssignedOnlyForbiddenFields();
      }

      _state = _state.copyWith(
        isLoadingSummary: false,
        timezoneName: result.timezoneName,
        workingScheduleConfigured: result.workingScheduleConfigured,
        tenantLocalToday: today,
        clearTenantLocalToday: today == null,
        scope: result.scope,
        filtersHash: result.filtersHash,
        days: result.days,
        overdueOutsideRangeSummary: result.overdueOutsideRange,
        showSetupWarning: setupWarning,
        loadedSummaryQuery: CalendarLoadedSummaryQuery(
          dateFrom: requestedFrom,
          dateTo: requestedTo,
          filtersKey: requestedKey,
        ),
        clearSummaryError: true,
      );

      if (nextFilters != requestedFilters) {
        invalidatePagination();
        _state = _state.copyWith(
          filters: nextFilters,
          clearLoadedSummaryQuery: true,
          days: const [],
          overdueEvents: const [],
          agendaEvents: const [],
          clearNextCursorInRange: true,
          clearNextCursorOverdue: true,
          hasMoreInRange: false,
          hasMoreOverdue: false,
        );
        await reloadAll();
        return;
      }

      if (today != null && !_state.hasExplicitSelectedDate) {
        await adoptTenantLocalToday(today, summaryGeneration: gen);
      }
    } on CalendarException catch (e) {
      if (gen != summaryGeneration) return;
      _state = _state.copyWith(
        isLoadingSummary: false,
        summaryErrorCode: e.code,
        permissionDenied: e.code == CalendarException.permissionDenied,
      );
    } catch (_) {
      if (gen != summaryGeneration) return;
      _state = _state.copyWith(
        isLoadingSummary: false,
        summaryErrorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> adoptTenantLocalToday(
    DateTime today, {
    required int summaryGeneration,
  }) async {
    if (summaryGeneration != this.summaryGeneration) return;
    if (_state.hasExplicitSelectedDate) return;
    if (_state.firstDayOfWeekIndex == null) return;

    final alreadySelected = _state.selectedDate == today;
    final inFocusedMonth = focusedMonthOnly(today) == _state.focusedMonth;

    if (alreadySelected && inFocusedMonth) return;

    if (!inFocusedMonth) {
      invalidatePagination();
      _applyPaddedRangeForFocusedMonth(
        today,
        clearSummary: true,
        selectedDate: today,
      );
      _state = _state.copyWith(
        overdueEvents: const [],
        agendaEvents: const [],
        clearNextCursorInRange: true,
        clearNextCursorOverdue: true,
        hasMoreInRange: false,
        hasMoreOverdue: false,
      );
      if (summaryGeneration != this.summaryGeneration) return;
      await reloadAll();
      return;
    }

    _state = _state.copyWith(selectedDate: today);
    await loadAgenda();
  }

  Future<void> loadAgenda() async {
    final session = readSession();
    if (session == null || !canAccessCalendar(session)) return;
    if (_blockInvalidScopeLoad()) return;

    final gen = ++agendaGeneration;
    final selected = _state.selectedDate;
    final requestFilters = _state.routeScope.mergeIntoFilters(_state.filters);
    _state = _state.copyWith(isLoadingAgenda: true, clearAgendaError: true);

    try {
      final result = await readRepo().listEvents(
        session,
        dateFrom: selected,
        dateTo: selected,
        filters: requestFilters,
        limit: CalendarFilters.defaultPageLimit,
        includeOverdueOutsideRange: false,
      );
      if (gen != agendaGeneration) return;

      applyTenantTodayFromList(result);

      _state = _state.copyWith(
        isLoadingAgenda: false,
        agendaEvents: result.inRange.rows,
        nextCursorInRange: result.inRange.nextCursor,
        hasMoreInRange: result.inRange.hasMore,
        clearNextCursorInRange: result.inRange.nextCursor == null,
        clearAgendaError: true,
      );
    } on CalendarException catch (e) {
      if (gen != agendaGeneration) return;
      _state = _state.copyWith(
        isLoadingAgenda: false,
        agendaErrorCode: e.code,
        permissionDenied: e.code == CalendarException.permissionDenied,
      );
    } catch (_) {
      if (gen != agendaGeneration) return;
      _state = _state.copyWith(
        isLoadingAgenda: false,
        agendaErrorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> loadOverdueInitial() async {
    final session = readSession();
    if (session == null || !canAccessCalendar(session)) return;
    if (_blockInvalidScopeLoad()) return;

    final gen = ++_pagination.overduePaginationGeneration;
    final requestFilters = _state.routeScope.mergeIntoFilters(_state.filters);
    _state = _state.copyWith(isLoadingOverdue: true, clearOverdueError: true);
    try {
      final result = await readRepo().listEvents(
        session,
        dateFrom: _state.dateFrom,
        dateTo: _state.dateTo,
        filters: requestFilters,
        limit: CalendarFilters.defaultPageLimit,
        includeOverdueOutsideRange: true,
      );
      if (gen != _pagination.overduePaginationGeneration) return;

      applyTenantTodayFromList(result);

      _state = _state.copyWith(
        isLoadingOverdue: false,
        overdueEvents: result.overdueOutsideRange.rows,
        nextCursorOverdue: result.overdueOutsideRange.nextCursor,
        hasMoreOverdue: result.overdueOutsideRange.hasMore,
        clearNextCursorOverdue: result.overdueOutsideRange.nextCursor == null,
        isLoadingMoreOverdue: false,
        clearOverdueError: true,
      );
    } on CalendarException catch (e) {
      if (gen != _pagination.overduePaginationGeneration) return;
      _state = _state.copyWith(
        isLoadingOverdue: false,
        isLoadingMoreOverdue: false,
        overdueErrorCode: e.code,
        overdueEvents: const [],
        clearNextCursorOverdue: true,
        hasMoreOverdue: false,
      );
    } catch (_) {
      if (gen != _pagination.overduePaginationGeneration) return;
      _state = _state.copyWith(
        isLoadingOverdue: false,
        isLoadingMoreOverdue: false,
        overdueErrorCode: CalendarException.unknown,
        overdueEvents: const [],
        clearNextCursorOverdue: true,
        hasMoreOverdue: false,
      );
    }
  }

  Future<void> loadMoreInRange() => _pagination.loadMoreInRange();

  Future<void> loadMoreOverdue() => _pagination.loadMoreOverdue();

  void applyTenantTodayFromList(CalendarEventListResult result) {
    final today = result.tenantLocalToday;
    if (today == null) return;
    final todayOnly = calendarDateOnly(today);
    if (_state.tenantLocalToday == null) {
      _state = _state.copyWith(tenantLocalToday: todayOnly);
    }
  }
}
