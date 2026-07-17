import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/calendar_working_date_exception_repository.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_working_date_exception.dart';
import 'calendar_working_date_exceptions_mutations.dart';
import 'calendar_working_date_exceptions_state.dart';

part 'calendar_working_date_exceptions_controller.g.dart';

@Riverpod(keepAlive: true)
class CalendarWorkingDateExceptionsController
    extends _$CalendarWorkingDateExceptionsController {
  late CalendarWorkingDateExceptionsMutations _mutations;
  var _loadGeneration = 0;
  var _paginationGeneration = 0;
  var _mutationGeneration = 0;

  @override
  CalendarWorkingDateExceptionsState build() {
    _mutations = CalendarWorkingDateExceptionsMutations(
      readSession: () => ref.read(authControllerProvider).valueOrNull,
      readRepo: () => ref.read(calendarWorkingDateExceptionRepositoryProvider),
    );
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        _invalidateRequests();
        state = CalendarWorkingDateExceptionsState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        _invalidateRequests();
        state = CalendarWorkingDateExceptionsState(isLoading: true);
        load(force: true);
      }
    });
    Future.microtask(() => load(force: true));
    return CalendarWorkingDateExceptionsState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  void _invalidateRequests() {
    _loadGeneration++;
    _paginationGeneration++;
    _mutationGeneration++;
  }

  bool _sameSession(AppSession captured) {
    final current = _session;
    return current != null &&
        current.userId == captured.userId &&
        current.tenantId == captured.tenantId &&
        current.accountType == captured.accountType &&
        current.isManager == captured.isManager &&
        current.permissions == captured.permissions;
  }

  DateTime _yearStart(int year) => DateTime(year);
  DateTime _yearEnd(int year) => DateTime(year, 12, 31);

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  bool _matchesLoadedContract(
    WorkingDateExceptionListResult result, {
    required CalendarWorkingDateExceptionStatusFilter status,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? limit,
  }) {
    final applied = result.filtersApplied;
    return applied.status == status &&
        applied.kind == null &&
        _sameDate(applied.dateFrom, dateFrom) &&
        _sameDate(applied.dateTo, dateTo) &&
        (limit == null || applied.limit == limit);
  }

  Future<void> load({bool force = false}) async {
    if (!force && !state.isLoading && state.items.isNotEmpty) return;

    final session = _session;
    if (session == null || !canViewCalendarSettings(session)) {
      _invalidateRequests();
      state = CalendarWorkingDateExceptionsState(
        isLoading: false,
        permissionDenied: true,
      );
      return;
    }

    final generation = ++_loadGeneration;
    _paginationGeneration++;
    final status = state.statusFilter;
    final dateFrom = _yearStart(state.selectedYear);
    final dateTo = _yearEnd(state.selectedYear);

    state = state.copyWith(
      isLoading: true,
      canEdit: canEditCalendarSettings(session),
      clearError: true,
      clearMutationError: true,
      clearMutationSuccess: true,
    );
    try {
      final result = await ref
          .read(calendarWorkingDateExceptionRepositoryProvider)
          .listExceptions(
            session,
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );
      if (generation != _loadGeneration || !_sameSession(session)) return;
      if (!_matchesLoadedContract(
        result,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
      )) {
        throw const CalendarException(
          code: CalendarException.malformedResponse,
          technicalDetail: 'working date exception list contract mismatch',
        );
      }
      state = state.copyWith(
        isLoading: false,
        permissionDenied: false,
        canEdit: canEditCalendarSettings(session),
        items: result.items,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        clearNextCursor: result.nextCursor == null,
        loadedDateFrom: result.filtersApplied.dateFrom,
        loadedDateTo: result.filtersApplied.dateTo,
        loadedLimit: result.filtersApplied.limit,
        clearError: true,
      );
    } on CalendarException catch (e) {
      if (generation != _loadGeneration || !_sameSession(session)) return;
      state = state.copyWith(
        isLoading: false,
        canEdit: canEditCalendarSettings(session),
        errorCode: e.code,
        permissionDenied: e.code == CalendarException.permissionDenied,
      );
    } catch (_) {
      if (generation != _loadGeneration || !_sameSession(session)) return;
      state = state.copyWith(
        isLoading: false,
        canEdit: canEditCalendarSettings(session),
        errorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final session = _session;
    if (session == null || !canViewCalendarSettings(session)) return;
    final dateFrom = state.loadedDateFrom;
    final dateTo = state.loadedDateTo;
    final limit = state.loadedLimit;
    final cursor = state.nextCursor;
    final status = state.statusFilter;
    if (dateFrom == null || dateTo == null || limit == null || cursor == null) {
      await load(force: true);
      return;
    }
    final generation = ++_paginationGeneration;

    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final result = await ref
          .read(calendarWorkingDateExceptionRepositoryProvider)
          .listExceptions(
            session,
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
            cursor: cursor,
            limit: limit,
          );
      if (generation != _paginationGeneration || !_sameSession(session)) return;
      if (!_matchesLoadedContract(
        result,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: limit,
      )) {
        throw const CalendarException(
          code: CalendarException.malformedResponse,
          technicalDetail: 'working date exception page contract mismatch',
        );
      }
      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        clearNextCursor: result.nextCursor == null,
      );
    } on CalendarException catch (e) {
      if (generation != _paginationGeneration || !_sameSession(session)) return;
      state = state.copyWith(isLoadingMore: false, loadMoreErrorCode: e.code);
    } catch (_) {
      if (generation != _paginationGeneration || !_sameSession(session)) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorCode: CalendarException.unknown,
      );
    }
  }

  Future<void> setStatusFilter(
    CalendarWorkingDateExceptionStatusFilter filter,
  ) async {
    if (filter == state.statusFilter) return;
    state = state.copyWith(
      statusFilter: filter,
      items: const [],
      clearNextCursor: true,
      clearLoadedRange: true,
      hasMore: false,
    );
    await load(force: true);
  }

  Future<void> setYear(int year) async {
    if (year == state.selectedYear) return;
    state = state.copyWith(
      selectedYear: year,
      items: const [],
      clearNextCursor: true,
      clearLoadedRange: true,
      hasMore: false,
    );
    await load(force: true);
  }

  Future<void> retry() => load(force: true);

  Future<bool> createException(WorkingDateExceptionData data) async {
    final session = _session;
    if (session == null) return false;
    final generation = ++_mutationGeneration;
    state = state.copyWith(isMutating: true, clearMutationError: true);
    final outcome = await _mutations.create(data);
    if (generation != _mutationGeneration || !_sameSession(session)) {
      return false;
    }
    return _applyMutationOutcome(
      outcome,
      successCode: 'created',
      session: session,
      generation: generation,
    );
  }

  Future<bool> updateException(
    WorkingDateException existing,
    WorkingDateExceptionData data,
  ) async {
    final session = _session;
    if (session == null) return false;
    final generation = ++_mutationGeneration;
    state = state.copyWith(isMutating: true, clearMutationError: true);
    final outcome = await _mutations.update(existing, data);
    if (generation != _mutationGeneration || !_sameSession(session)) {
      return false;
    }
    return _applyMutationOutcome(
      outcome,
      successCode: 'updated',
      session: session,
      generation: generation,
    );
  }

  Future<bool> cancelException(
    WorkingDateException existing, {
    required String reason,
  }) async {
    final session = _session;
    if (session == null) return false;
    final generation = ++_mutationGeneration;
    state = state.copyWith(isMutating: true, clearMutationError: true);
    final outcome = await _mutations.cancel(existing, reason: reason);
    if (generation != _mutationGeneration || !_sameSession(session)) {
      return false;
    }
    return _applyMutationOutcome(
      outcome,
      successCode: 'cancelled',
      session: session,
      generation: generation,
    );
  }

  Future<bool> _applyMutationOutcome(
    CalendarWorkingDateExceptionMutationOutcome outcome, {
    required String successCode,
    required AppSession session,
    required int generation,
  }) async {
    // `load` always clears mutation banners, so it must run before (not
    // after) the outcome is recorded on state.
    if (outcome.ok) {
      await load(force: true);
      if (generation != _mutationGeneration || !_sameSession(session)) {
        return false;
      }
      state = state.copyWith(
        isMutating: false,
        mutationSuccessCode: successCode,
        clearMutationError: true,
      );
      return true;
    }
    if (outcome.errorCode == CalendarException.staleVersion) {
      await load(force: true);
      if (generation != _mutationGeneration || !_sameSession(session)) {
        return false;
      }
    }
    state = state.copyWith(
      isMutating: false,
      mutationErrorCode: outcome.errorCode,
    );
    return false;
  }
}
