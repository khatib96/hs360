import '../domain/calendar_month_grid.dart';
import '../domain/calendar_route_scope.dart';
import 'calendar_section_loader.dart';
import 'calendar_state.dart';

/// Applies/clears the Calendar route's deep-link scope (Phase 7 M11).
///
/// Mirrors [CalendarSectionLoader]/`CalendarManualMutations`: a focused
/// helper owned by `CalendarController`, not UI or repository logic.
class CalendarRouteScopeHandler {
  CalendarRouteScopeHandler({
    required this.readState,
    required this.writeState,
    required this.loader,
    required this.reloadAfterMonthChange,
    required this.refresh,
  });

  final CalendarState Function() readState;
  final void Function(CalendarState) writeState;
  final CalendarSectionLoader loader;

  /// Reloads the padded month range + all sections after a focused-month
  /// change (mirrors `CalendarController._reloadAfterMonthChange`).
  final Future<void> Function(
    DateTime focused, {
    required DateTime selectedDate,
  })
  reloadAfterMonthChange;

  /// Full triple reload (summary + agenda + overdue).
  final Future<void> Function() refresh;

  CalendarState get _state => readState();
  set _state(CalendarState value) => writeState(value);

  /// Applies a deep-link [scope] parsed from the Calendar route's query
  /// parameters. Stores it separately from [CalendarState.filters] (see
  /// `CalendarRouteScope` doc) and reloads sections so the merged
  /// customer/contract IDs reach the repository request boundary.
  ///
  /// Invalid scopes clear visible rows/counts and never trigger unfiltered
  /// repository reads (see [CalendarRouteScope.blocksRepositoryReads]).
  Future<void> apply(CalendarRouteScope scope) async {
    if (scope == _state.routeScope) return;
    final previous = _state.routeScope;
    final idsChanged =
        previous.customerId != scope.customerId ||
        previous.contractId != scope.contractId ||
        previous.isInvalid != scope.isInvalid;

    if (scope.isInvalid) {
      loader.invalidateAll();
      _state = _state.copyWith(
        routeScope: scope,
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
      return;
    }

    _state = _state.copyWith(routeScope: scope);

    final date = scope.date;
    if (_state.firstDayOfWeekIndex == null) {
      // Week start not configured yet; the initial load (after
      // `ensureWeekStart`) will merge this scope automatically.
      if (date != null) {
        _state = _state.copyWith(
          focusedMonth: focusedMonthOnly(date),
          selectedDate: date,
          hasExplicitSelectedDate: true,
        );
      }
      return;
    }

    if (date != null && focusedMonthOnly(date) != _state.focusedMonth) {
      await reloadAfterMonthChange(focusedMonthOnly(date), selectedDate: date);
      return;
    }
    if (date != null && date != _state.selectedDate) {
      _state = _state.copyWith(
        selectedDate: date,
        hasExplicitSelectedDate: true,
      );
      if (idsChanged) {
        await refresh();
      } else {
        loader.inRangePaginationGeneration++;
        _state = _state.copyWith(
          clearNextCursorInRange: true,
          hasMoreInRange: false,
          agendaEvents: const [],
          clearAgendaError: true,
        );
        await loader.loadAgenda();
      }
      return;
    }
    if (idsChanged) {
      await refresh();
    }
  }

  /// Clears any active deep-link scope and reloads without the merged IDs.
  Future<void> clear() async {
    if (_state.routeScope.isEmpty) return;
    await apply(CalendarRouteScope.empty);
  }
}
