import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../accounting/domain/journal_source.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../data/journal_repository.dart';
import '../domain/journal_filters.dart';
import '../domain/journal_permissions.dart';
import 'journal_list_state.dart';

part 'journal_list_controller.g.dart';

@Riverpod(keepAlive: true)
class JournalListController extends _$JournalListController {
  static const pageSize = JournalRepository.maxListEntries;

  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  JournalListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const JournalListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const JournalListState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  Future<void> refresh() async {
    _hasStartedInitialLoad = true;
    final session = _session;
    if (session == null || !canViewJournal(session)) {
      state = const JournalListState();
      return;
    }

    final refreshId = ++_refreshSerial;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final rows = await ref
          .read(journalRepositoryProvider)
          .listJournalEntries(
            session,
            filters: state.filters,
            page: const PaginationCursor(limit: pageSize + 1),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        entries: rows.take(pageSize).toList(),
        isLoading: false,
        isLoadingMore: false,
        hasMore: rows.length > pageSize,
        clearError: true,
      );
    } on FinanceException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorCode: e.code,
      );
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final session = _session;
    if (session == null || !canViewJournal(session)) return;

    final refreshId = ++_refreshSerial;
    state = state.copyWith(
      isLoadingMore: true,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final rows = await ref
          .read(journalRepositoryProvider)
          .listJournalEntries(
            session,
            filters: state.filters,
            page: PaginationCursor(
              offset: state.entries.length,
              limit: pageSize + 1,
            ),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        entries: [...state.entries, ...rows.take(pageSize)],
        isLoadingMore: false,
        hasMore: rows.length > pageSize,
        clearLoadMoreError: true,
      );
    } on FinanceException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(isLoadingMore: false, loadMoreErrorCode: e.code);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorCode: FinanceException.unknown,
      );
    }
  }

  void setSource(JournalSource? source) {
    state = state.copyWith(
      filters: JournalFilters(
        dateRange: state.filters.dateRange,
        source: source,
        search: state.filters.search,
      ),
    );
    refresh();
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    state = state.copyWith(
      filters: JournalFilters(
        dateRange: state.filters.dateRange,
        source: state.filters.source,
        search: trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
    refresh();
  }
}
