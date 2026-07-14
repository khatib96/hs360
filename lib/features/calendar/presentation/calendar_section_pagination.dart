import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_permissions.dart';
import 'calendar_state.dart';

/// Owns in-range / overdue "load more" fetches and their generations.
class CalendarSectionPagination {
  CalendarSectionPagination({
    required this.readState,
    required this.writeState,
    required this.readSession,
    required this.readRepo,
  });

  final CalendarState Function() readState;
  final void Function(CalendarState) writeState;
  final AppSession? Function() readSession;
  final CalendarRepository Function() readRepo;

  int inRangePaginationGeneration = 0;
  int overduePaginationGeneration = 0;

  CalendarState get _state => readState();
  set _state(CalendarState value) => writeState(value);

  void invalidate() {
    inRangePaginationGeneration++;
    overduePaginationGeneration++;
  }

  Future<void> loadMoreInRange() async {
    if (_state.isLoadingAgenda ||
        _state.isLoadingMoreInRange ||
        !_state.hasMoreInRange ||
        _state.nextCursorInRange == null) {
      return;
    }

    final session = readSession();
    if (session == null || !canAccessCalendar(session)) return;

    final gen = ++inRangePaginationGeneration;
    _state = _state.copyWith(
      isLoadingMoreInRange: true,
      clearLoadMoreInRangeError: true,
    );

    try {
      final result = await readRepo().listEvents(
        session,
        dateFrom: _state.selectedDate,
        dateTo: _state.selectedDate,
        filters: _state.filters,
        cursorInRange: _state.nextCursorInRange,
        limit: CalendarFilters.defaultPageLimit,
        includeOverdueOutsideRange: false,
      );
      if (gen != inRangePaginationGeneration) return;

      _state = _state.copyWith(
        isLoadingMoreInRange: false,
        agendaEvents: [..._state.agendaEvents, ...result.inRange.rows],
        nextCursorInRange: result.inRange.nextCursor,
        hasMoreInRange: result.inRange.hasMore,
        clearNextCursorInRange: result.inRange.nextCursor == null,
      );
    } on CalendarException catch (e) {
      if (gen != inRangePaginationGeneration) return;
      _state = _state.copyWith(
        isLoadingMoreInRange: false,
        loadMoreInRangeErrorCode: e.code,
      );
    } catch (_) {
      if (gen != inRangePaginationGeneration) return;
      _state = _state.copyWith(
        isLoadingMoreInRange: false,
        loadMoreInRangeErrorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> loadMoreOverdue() async {
    if (_state.isLoadingMoreOverdue ||
        !_state.hasMoreOverdue ||
        _state.nextCursorOverdue == null) {
      return;
    }

    final session = readSession();
    if (session == null || !canAccessCalendar(session)) return;

    final gen = ++overduePaginationGeneration;
    _state = _state.copyWith(
      isLoadingMoreOverdue: true,
      clearLoadMoreOverdueError: true,
    );

    try {
      final result = await readRepo().listEvents(
        session,
        dateFrom: _state.dateFrom,
        dateTo: _state.dateTo,
        filters: _state.filters,
        cursorOverdue: _state.nextCursorOverdue,
        limit: CalendarFilters.defaultPageLimit,
        includeOverdueOutsideRange: true,
      );
      if (gen != overduePaginationGeneration) return;

      _state = _state.copyWith(
        isLoadingMoreOverdue: false,
        overdueEvents: [
          ..._state.overdueEvents,
          ...result.overdueOutsideRange.rows,
        ],
        nextCursorOverdue: result.overdueOutsideRange.nextCursor,
        hasMoreOverdue: result.overdueOutsideRange.hasMore,
        clearNextCursorOverdue: result.overdueOutsideRange.nextCursor == null,
      );
    } on CalendarException catch (e) {
      if (gen != overduePaginationGeneration) return;
      _state = _state.copyWith(
        isLoadingMoreOverdue: false,
        loadMoreOverdueErrorCode: e.code,
      );
    } catch (_) {
      if (gen != overduePaginationGeneration) return;
      _state = _state.copyWith(
        isLoadingMoreOverdue: false,
        loadMoreOverdueErrorCode: CalendarException.unknown,
      );
    }
  }
}
