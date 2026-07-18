import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_manual_mutation.dart';
import '../domain/calendar_month_grid.dart';
import '../domain/calendar_permissions.dart';
import 'calendar_clock.dart';
import 'calendar_manual_mutations.dart';
import 'calendar_schedule_mutations.dart';
import 'calendar_section_loader.dart';
import 'calendar_state.dart';

export 'calendar_clock.dart';

part 'calendar_controller.g.dart';

@Riverpod(keepAlive: true)
class CalendarController extends _$CalendarController {
  late CalendarSectionLoader _loader;
  late CalendarManualMutations _mutations;
  late CalendarScheduleMutations _scheduleMutations;
  bool _hasStartedInitialLoad = false;

  @override
  CalendarState build() {
    _loader = CalendarSectionLoader(
      readState: () => state,
      writeState: (next) => state = next,
      readSession: () => ref.read(authControllerProvider).valueOrNull,
      readRepo: () => ref.read(calendarRepositoryProvider),
      reloadAll: _reloadAllSections,
    );
    _mutations = CalendarManualMutations(
      readSession: () => ref.read(authControllerProvider).valueOrNull,
      readRepo: () => ref.read(calendarRepositoryProvider),
      refresh: refresh,
    );
    _scheduleMutations = CalendarScheduleMutations(
      readSession: () => ref.read(authControllerProvider).valueOrNull,
      readRepo: () => ref.read(calendarRepositoryProvider),
      readState: () => state,
      refresh: refresh,
    );
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        _loader.invalidateAll();
        _scheduleMutations.invalidate();
        _hasStartedInitialLoad = false;
        state = calendarInitialState(calendarClock());
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        _scheduleMutations.invalidate();
        _resetForIdentityChange();
        if (state.firstDayOfWeekIndex != null) {
          refresh();
        }
      }
    });
    return calendarInitialState(calendarClock());
  }

  Future<void> _reloadAllSections() => Future.wait([
    _loader.loadSummary(),
    _loader.loadAgenda(),
    _loader.loadOverdueInitial(),
  ]);

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  void _resetForIdentityChange() {
    _loader.invalidateAll();
    _hasStartedInitialLoad = false;
    final weekStart = state.firstDayOfWeekIndex;
    state = calendarInitialState(
      calendarClock(),
    ).copyWith(firstDayOfWeekIndex: weekStart);
    if (weekStart != null) {
      _applyPaddedRangeForFocusedMonth(state.focusedMonth, clearSummary: true);
    }
  }

  DateTime get _authoritativeToday {
    final tenantToday = state.tenantLocalToday;
    if (tenantToday != null) return calendarDateOnly(tenantToday);
    return calendarDateOnly(calendarClock());
  }

  CalendarFilters _sanitizeFiltersForSession(
    CalendarFilters filters,
    AppSession? session,
  ) {
    var next = filters.withoutExactIdFilters();
    if (session == null || !canViewTenantCalendar(session)) {
      next = next.withoutAssignedOnlyForbiddenFields();
    }
    return next;
  }

  void _applyPaddedRangeForFocusedMonth(
    DateTime focused, {
    required bool clearSummary,
    DateTime? selectedDate,
  }) {
    final weekStart = state.firstDayOfWeekIndex;
    if (weekStart == null) return;
    final range = calendarPaddedMonthRange(
      focused,
      firstDayOfWeekIndex: weekStart,
    );
    state = state.copyWith(
      focusedMonth: focusedMonthOnly(focused),
      dateFrom: range.dateFrom,
      dateTo: range.dateTo,
      selectedDate: selectedDate,
      clearLoadedSummaryQuery: clearSummary,
      days: clearSummary ? const [] : null,
      clearOverdueOutsideRangeSummary: clearSummary,
    );
  }

  /// Idempotent week-start configuration from presentation (post-frame).
  Future<void> ensureWeekStart(int firstDayOfWeekIndex) async {
    final index = firstDayOfWeekIndex % 7;
    final previous = state.firstDayOfWeekIndex;
    if (previous == index) {
      if (!_hasStartedInitialLoad) {
        _hasStartedInitialLoad = true;
        await refresh();
      }
      return;
    }

    state = state.copyWith(firstDayOfWeekIndex: index);
    _applyPaddedRangeForFocusedMonth(
      state.focusedMonth,
      clearSummary: true,
      selectedDate: clampDayOfMonth(state.selectedDate, state.focusedMonth),
    );

    _hasStartedInitialLoad = true;
    await refresh();
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null || !canAccessCalendar(session)) {
      _loader.invalidateAll();
      state = calendarInitialState(calendarClock()).copyWith(
        firstDayOfWeekIndex: state.firstDayOfWeekIndex,
        permissionDenied: true,
      );
      return;
    }
    if (state.firstDayOfWeekIndex == null) return;

    final sanitized = _sanitizeFiltersForSession(state.filters, session);
    if (sanitized != state.filters) {
      state = state.copyWith(filters: sanitized);
    }

    final sameQuery = state.isSummaryQueryAligned;
    _loader.invalidatePagination();
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
      clearLoadedSummaryQuery: !sameQuery,
      days: sameQuery ? null : const [],
    );

    await _reloadAllSections();
  }

  Future<void> goToPreviousMonth() => _navigateFocusedMonth(-1);

  Future<void> goToNextMonth() => _navigateFocusedMonth(1);

  /// Jumps to [month], clamping the selected day when the target month is shorter.
  Future<void> goToMonth(DateTime month) async {
    if (state.firstDayOfWeekIndex == null) return;
    final target = focusedMonthOnly(month);
    if (target == state.focusedMonth) return;
    await _reloadAfterMonthChange(
      target,
      selectedDate: clampDayOfMonth(state.selectedDate, target),
    );
  }

  Future<void> _reloadAfterMonthChange(
    DateTime focused, {
    required DateTime selectedDate,
  }) async {
    _loader.invalidatePagination();
    _applyPaddedRangeForFocusedMonth(
      focused,
      clearSummary: true,
      selectedDate: selectedDate,
    );
    state = state.copyWith(
      hasExplicitSelectedDate: true,
      overdueEvents: const [],
      agendaEvents: const [],
      clearNextCursorInRange: true,
      clearNextCursorOverdue: true,
      hasMoreInRange: false,
      hasMoreOverdue: false,
      clearSummaryError: true,
      clearAgendaError: true,
      clearOverdueError: true,
    );
    await _reloadAllSections();
  }

  Future<void> _navigateFocusedMonth(int deltaMonths) async {
    final current = state.focusedMonth;
    final target = DateTime(current.year, current.month + deltaMonths);
    await goToMonth(target);
  }

  Future<void> goToToday() async {
    if (state.firstDayOfWeekIndex == null) return;
    final today = _authoritativeToday;
    await _reloadAfterMonthChange(today, selectedDate: today);
  }

  Future<void> selectGridDate(DateTime date) async {
    final day = calendarDateOnly(date);
    if (focusedMonthOnly(day) != state.focusedMonth) {
      await _reloadAfterMonthChange(day, selectedDate: day);
      return;
    }
    await selectDate(day);
  }

  Future<void> selectDate(DateTime date) async {
    final day = calendarDateOnly(date);
    if (day == state.selectedDate &&
        state.hasExplicitSelectedDate &&
        state.agendaEvents.isNotEmpty) {
      return;
    }
    _loader.inRangePaginationGeneration++;
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
    await _loader.loadAgenda();
  }

  Future<void> setFilters(CalendarFilters filters) async {
    final session = _session;
    final sanitized = _sanitizeFiltersForSession(filters, session);
    if (sanitized == state.filters) return;
    _loader.invalidatePagination();
    state = state.copyWith(
      filters: sanitized,
      clearLoadedSummaryQuery: true,
      days: const [],
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
    await _reloadAllSections();
  }

  Future<void> clearFilters() => setFilters(CalendarFilters.empty);

  Future<void> retrySummary() async {
    if (state.isLoadingSummary) return;
    state = state.copyWith(clearSummaryError: true);
    await _loader.loadSummary();
  }

  Future<void> retryAgenda() async {
    if (state.isLoadingAgenda) return;
    state = state.copyWith(
      clearAgendaError: true,
      clearLoadMoreInRangeError: true,
    );
    await _loader.loadAgenda();
  }

  Future<void> retryOverdue() async {
    if (state.isLoadingOverdue || state.isLoadingMoreOverdue) return;
    state = state.copyWith(clearOverdueError: true);
    await _loader.loadOverdueInitial();
  }

  Future<void> loadMoreInRange() => _loader.loadMoreInRange();

  Future<void> loadMoreOverdue() => _loader.loadMoreOverdue();

  Future<bool> createManualEvent(
    BuildContext context,
    CalendarManualEventData data,
  ) => _mutations.createManualEvent(context, data);

  Future<bool> editManualEvent(BuildContext context, CalendarEvent event) =>
      _mutations.editManualEvent(context, event);

  Future<bool> cancelManualEvent(
    CalendarEvent event, {
    required String reason,
  }) => _mutations.cancelManualEvent(event, reason: reason);

  Future<bool> markManualDone(CalendarEvent event) =>
      _mutations.markManualDone(event);

  Future<bool> assignCalendarEvent(
    BuildContext context,
    CalendarEvent event, {
    required String? assignedAgentId,
  }) => _scheduleMutations.assignEvent(
    context,
    event,
    assignedAgentId: assignedAgentId,
  );

  Future<bool> rescheduleCalendarEvent(
    BuildContext context,
    CalendarEvent event, {
    required DateTime targetDate,
    required String reason,
  }) => _scheduleMutations.rescheduleEvent(
    context,
    event,
    targetDate: targetDate,
    reason: reason,
  );
}
