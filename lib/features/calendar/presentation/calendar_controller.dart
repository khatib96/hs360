import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_enums.dart';
import '../domain/calendar_event_list_result.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_permissions.dart';
import 'calendar_state.dart';

part 'calendar_controller.g.dart';

/// Injectable clock for selectable “today”; overridden in tests.
typedef CalendarClock = DateTime Function();

CalendarClock calendarClock = DateTime.now;

DateTime _defaultMonthStart(DateTime today) =>
    DateTime(today.year, today.month);

DateTime _defaultMonthEnd(DateTime today) =>
    DateTime(today.year, today.month + 1, 0);

CalendarState _initialState(DateTime today) {
  final day = calendarDateOnly(today);
  return CalendarState(
    isLoadingSummary: true,
    isLoadingAgenda: true,
    dateFrom: _defaultMonthStart(day),
    dateTo: _defaultMonthEnd(day),
    selectedDate: day,
  );
}

@Riverpod(keepAlive: true)
class CalendarController extends _$CalendarController {
  int _summaryGeneration = 0;
  int _agendaGeneration = 0;
  int _inRangePaginationGeneration = 0;
  int _overduePaginationGeneration = 0;
  bool _hasStartedInitialLoad = false;

  @override
  CalendarState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        _invalidateAllGenerations();
        state = _initialState(
          calendarClock(),
        ).copyWith(isLoadingSummary: false, isLoadingAgenda: false);
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        _resetForIdentityChange();
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) {
        _hasStartedInitialLoad = true;
        refresh();
      }
    });
    return _initialState(calendarClock());
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  void _invalidateAllGenerations() {
    _summaryGeneration++;
    _agendaGeneration++;
    _inRangePaginationGeneration++;
    _overduePaginationGeneration++;
  }

  void _invalidatePaginationGenerations() {
    _inRangePaginationGeneration++;
    _overduePaginationGeneration++;
  }

  void _resetForIdentityChange() {
    _invalidateAllGenerations();
    state = _initialState(calendarClock());
  }

  DateTime get _authoritativeToday {
    final tenantToday = state.tenantLocalToday;
    if (tenantToday != null) return calendarDateOnly(tenantToday);
    return calendarDateOnly(calendarClock());
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null || !canAccessCalendar(session)) {
      _invalidateAllGenerations();
      state = _initialState(calendarClock()).copyWith(
        isLoadingSummary: false,
        isLoadingAgenda: false,
        permissionDenied: true,
      );
      return;
    }

    _invalidatePaginationGenerations();
    state = state.copyWith(
      permissionDenied: false,
      clearSummaryError: true,
      clearAgendaError: true,
      clearLoadMoreInRangeError: true,
      clearLoadMoreOverdueError: true,
      clearOverdueError: true,
      clearNextCursorInRange: true,
      clearNextCursorOverdue: true,
      hasMoreInRange: false,
      hasMoreOverdue: false,
      isLoadingMoreInRange: false,
      isLoadingMoreOverdue: false,
      overdueEvents: const [],
      agendaEvents: const [],
    );

    await Future.wait([_loadSummary(), _loadAgenda(), _loadOverdueInitial()]);
  }

  Future<void> setVisibleRange(DateTime from, DateTime to) async {
    final start = calendarDateOnly(from);
    final end = calendarDateOnly(to);
    final span = inclusiveDaySpan(start, end);
    if (span < CalendarFilters.minRangeDays ||
        span > CalendarFilters.maxRangeDays) {
      state = state.copyWith(
        summaryErrorCode: CalendarException.validationFailed,
      );
      return;
    }

    var selected = calendarDateOnly(state.selectedDate);
    if (selected.isBefore(start) || selected.isAfter(end)) {
      selected = start;
    }

    _invalidatePaginationGenerations();
    state = state.copyWith(
      dateFrom: start,
      dateTo: end,
      selectedDate: selected,
      clearNextCursorInRange: true,
      clearNextCursorOverdue: true,
      hasMoreInRange: false,
      hasMoreOverdue: false,
      isLoadingMoreInRange: false,
      isLoadingMoreOverdue: false,
      overdueEvents: const [],
      agendaEvents: const [],
      clearSummaryError: true,
      clearAgendaError: true,
      clearLoadMoreInRangeError: true,
      clearLoadMoreOverdueError: true,
      clearOverdueError: true,
    );

    await Future.wait([_loadSummary(), _loadAgenda(), _loadOverdueInitial()]);
  }

  Future<void> selectDate(DateTime date) async {
    final day = calendarDateOnly(date);
    if (day == state.selectedDate &&
        state.hasExplicitSelectedDate &&
        state.agendaEvents.isNotEmpty) {
      return;
    }
    _inRangePaginationGeneration++;
    state = state.copyWith(
      selectedDate: day,
      hasExplicitSelectedDate: true,
      clearNextCursorInRange: true,
      hasMoreInRange: false,
      isLoadingMoreInRange: false,
      agendaEvents: const [],
      clearAgendaError: true,
      clearLoadMoreInRangeError: true,
    );
    await _loadAgenda();
  }

  Future<void> setFilters(CalendarFilters filters) async {
    _invalidatePaginationGenerations();
    state = state.copyWith(
      filters: filters,
      clearNextCursorInRange: true,
      clearNextCursorOverdue: true,
      hasMoreInRange: false,
      hasMoreOverdue: false,
      isLoadingMoreInRange: false,
      isLoadingMoreOverdue: false,
      overdueEvents: const [],
      agendaEvents: const [],
      clearSummaryError: true,
      clearAgendaError: true,
      clearLoadMoreInRangeError: true,
      clearLoadMoreOverdueError: true,
      clearOverdueError: true,
    );
    await Future.wait([_loadSummary(), _loadAgenda(), _loadOverdueInitial()]);
  }

  Future<void> clearFilters() => setFilters(CalendarFilters.empty);

  void goToToday() {
    selectDate(_authoritativeToday);
  }

  Future<void> loadMoreInRange() async {
    if (state.isLoadingAgenda ||
        state.isLoadingMoreInRange ||
        !state.hasMoreInRange ||
        state.nextCursorInRange == null) {
      return;
    }

    final session = _session;
    if (session == null || !canAccessCalendar(session)) return;

    final gen = ++_inRangePaginationGeneration;
    state = state.copyWith(
      isLoadingMoreInRange: true,
      clearLoadMoreInRangeError: true,
    );

    try {
      final result = await ref
          .read(calendarRepositoryProvider)
          .listEvents(
            session,
            dateFrom: state.selectedDate,
            dateTo: state.selectedDate,
            filters: state.filters,
            cursorInRange: state.nextCursorInRange,
            limit: CalendarFilters.defaultPageLimit,
            includeOverdueOutsideRange: false,
          );
      if (gen != _inRangePaginationGeneration) return;

      state = state.copyWith(
        isLoadingMoreInRange: false,
        agendaEvents: [...state.agendaEvents, ...result.inRange.rows],
        nextCursorInRange: result.inRange.nextCursor,
        hasMoreInRange: result.inRange.hasMore,
        clearNextCursorInRange: result.inRange.nextCursor == null,
      );
    } on CalendarException catch (e) {
      if (gen != _inRangePaginationGeneration) return;
      state = state.copyWith(
        isLoadingMoreInRange: false,
        loadMoreInRangeErrorCode: e.code,
      );
    } catch (_) {
      if (gen != _inRangePaginationGeneration) return;
      state = state.copyWith(
        isLoadingMoreInRange: false,
        loadMoreInRangeErrorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> loadMoreOverdue() async {
    if (state.isLoadingMoreOverdue ||
        !state.hasMoreOverdue ||
        state.nextCursorOverdue == null) {
      return;
    }

    final session = _session;
    if (session == null || !canAccessCalendar(session)) return;

    final gen = ++_overduePaginationGeneration;
    state = state.copyWith(
      isLoadingMoreOverdue: true,
      clearLoadMoreOverdueError: true,
    );

    try {
      final result = await ref
          .read(calendarRepositoryProvider)
          .listEvents(
            session,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
            filters: state.filters,
            cursorOverdue: state.nextCursorOverdue,
            limit: CalendarFilters.defaultPageLimit,
            includeOverdueOutsideRange: true,
          );
      if (gen != _overduePaginationGeneration) return;

      state = state.copyWith(
        isLoadingMoreOverdue: false,
        overdueEvents: [
          ...state.overdueEvents,
          ...result.overdueOutsideRange.rows,
        ],
        nextCursorOverdue: result.overdueOutsideRange.nextCursor,
        hasMoreOverdue: result.overdueOutsideRange.hasMore,
        clearNextCursorOverdue: result.overdueOutsideRange.nextCursor == null,
      );
    } on CalendarException catch (e) {
      if (gen != _overduePaginationGeneration) return;
      state = state.copyWith(
        isLoadingMoreOverdue: false,
        loadMoreOverdueErrorCode: e.code,
      );
    } catch (_) {
      if (gen != _overduePaginationGeneration) return;
      state = state.copyWith(
        isLoadingMoreOverdue: false,
        loadMoreOverdueErrorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> _loadSummary() async {
    final session = _session;
    if (session == null || !canAccessCalendar(session)) return;

    final gen = ++_summaryGeneration;
    final requestedFrom = state.dateFrom;
    final requestedTo = state.dateTo;
    state = state.copyWith(isLoadingSummary: true, clearSummaryError: true);

    try {
      final result = await ref
          .read(calendarRepositoryProvider)
          .getRangeSummary(
            session,
            dateFrom: requestedFrom,
            dateTo: requestedTo,
            filters: state.filters,
          );
      if (gen != _summaryGeneration) return;

      final setupWarning =
          !result.workingScheduleConfigured ||
          result.overdueOutsideRange.state ==
              CalendarOverdueOutsideRangeState.scheduleUnconfigured ||
          result.tenantLocalToday == null;

      final today = result.tenantLocalToday == null
          ? null
          : calendarDateOnly(result.tenantLocalToday!);

      state = state.copyWith(
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
        clearSummaryError: true,
      );

      if (today != null && !state.hasExplicitSelectedDate) {
        await _adoptTenantLocalToday(today, summaryGeneration: gen);
      }
    } on CalendarException catch (e) {
      if (gen != _summaryGeneration) return;
      state = state.copyWith(
        isLoadingSummary: false,
        summaryErrorCode: e.code,
        permissionDenied: e.code == CalendarException.permissionDenied,
      );
    } catch (_) {
      if (gen != _summaryGeneration) return;
      state = state.copyWith(
        isLoadingSummary: false,
        summaryErrorCode: CalendarException.unknown,
      );
    }
  }

  /// First hydration: select tenant-local today and shift the visible range if
  /// needed. No-ops once the user has explicitly selected a date.
  Future<void> _adoptTenantLocalToday(
    DateTime today, {
    required int summaryGeneration,
  }) async {
    if (summaryGeneration != _summaryGeneration) return;
    if (state.hasExplicitSelectedDate) return;

    final alreadySelected = state.selectedDate == today;
    final inRange =
        !today.isBefore(state.dateFrom) && !today.isAfter(state.dateTo);

    if (alreadySelected && inRange) return;

    if (!inRange) {
      final monthFrom = _defaultMonthStart(today);
      final monthTo = _defaultMonthEnd(today);
      _invalidatePaginationGenerations();
      state = state.copyWith(
        dateFrom: monthFrom,
        dateTo: monthTo,
        selectedDate: today,
        clearNextCursorInRange: true,
        clearNextCursorOverdue: true,
        hasMoreInRange: false,
        hasMoreOverdue: false,
        isLoadingMoreInRange: false,
        isLoadingMoreOverdue: false,
        overdueEvents: const [],
        agendaEvents: const [],
      );
      if (summaryGeneration != _summaryGeneration) return;
      await Future.wait([_loadSummary(), _loadAgenda(), _loadOverdueInitial()]);
      return;
    }

    state = state.copyWith(selectedDate: today);
    await _loadAgenda();
  }

  Future<void> _loadAgenda() async {
    final session = _session;
    if (session == null || !canAccessCalendar(session)) return;

    final gen = ++_agendaGeneration;
    final selected = state.selectedDate;
    state = state.copyWith(isLoadingAgenda: true, clearAgendaError: true);

    try {
      final result = await ref
          .read(calendarRepositoryProvider)
          .listEvents(
            session,
            dateFrom: selected,
            dateTo: selected,
            filters: state.filters,
            limit: CalendarFilters.defaultPageLimit,
            includeOverdueOutsideRange: false,
          );
      if (gen != _agendaGeneration) return;

      _applyTenantTodayFromList(result);

      state = state.copyWith(
        isLoadingAgenda: false,
        agendaEvents: result.inRange.rows,
        nextCursorInRange: result.inRange.nextCursor,
        hasMoreInRange: result.inRange.hasMore,
        clearNextCursorInRange: result.inRange.nextCursor == null,
        clearAgendaError: true,
      );
    } on CalendarException catch (e) {
      if (gen != _agendaGeneration) return;
      state = state.copyWith(
        isLoadingAgenda: false,
        agendaErrorCode: e.code,
        permissionDenied: e.code == CalendarException.permissionDenied,
      );
    } catch (_) {
      if (gen != _agendaGeneration) return;
      state = state.copyWith(
        isLoadingAgenda: false,
        agendaErrorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> _loadOverdueInitial() async {
    final session = _session;
    if (session == null || !canAccessCalendar(session)) return;

    final gen = ++_overduePaginationGeneration;
    state = state.copyWith(clearOverdueError: true);
    try {
      final result = await ref
          .read(calendarRepositoryProvider)
          .listEvents(
            session,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
            filters: state.filters,
            limit: CalendarFilters.defaultPageLimit,
            includeOverdueOutsideRange: true,
          );
      if (gen != _overduePaginationGeneration) return;

      _applyTenantTodayFromList(result);

      state = state.copyWith(
        overdueEvents: result.overdueOutsideRange.rows,
        nextCursorOverdue: result.overdueOutsideRange.nextCursor,
        hasMoreOverdue: result.overdueOutsideRange.hasMore,
        clearNextCursorOverdue: result.overdueOutsideRange.nextCursor == null,
        isLoadingMoreOverdue: false,
        clearOverdueError: true,
      );
    } on CalendarException catch (e) {
      if (gen != _overduePaginationGeneration) return;
      state = state.copyWith(
        isLoadingMoreOverdue: false,
        overdueErrorCode: e.code,
        overdueEvents: const [],
        clearNextCursorOverdue: true,
        hasMoreOverdue: false,
      );
    } catch (_) {
      if (gen != _overduePaginationGeneration) return;
      state = state.copyWith(
        isLoadingMoreOverdue: false,
        overdueErrorCode: CalendarException.unknown,
        overdueEvents: const [],
        clearNextCursorOverdue: true,
        hasMoreOverdue: false,
      );
    }
  }

  void _applyTenantTodayFromList(CalendarEventListResult result) {
    final today = result.tenantLocalToday;
    if (today == null) return;
    final todayOnly = calendarDateOnly(today);
    if (state.tenantLocalToday == null) {
      state = state.copyWith(tenantLocalToday: todayOnly);
    }
  }
}
