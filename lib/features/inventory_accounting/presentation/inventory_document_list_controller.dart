import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../data/inventory_document_repository.dart';
import '../domain/inventory_document_filters.dart';
import '../domain/inventory_document_permissions.dart';
import 'inventory_document_list_state.dart';

part 'inventory_document_list_controller.g.dart';

@Riverpod(keepAlive: true)
class InventoryDocumentListController
    extends _$InventoryDocumentListController {
  static const pageSize = InventoryDocumentRepository.defaultPageSize;

  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  InventoryDocumentListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const InventoryDocumentListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const InventoryDocumentListState(isLoading: true);
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
    if (session == null || !canViewInventoryDocuments(session)) {
      state = const InventoryDocumentListState();
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
          .read(inventoryDocumentRepositoryProvider)
          .listDocuments(
            session,
            filters: state.filters,
            page: const PaginationCursor(limit: pageSize + 1),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        documents: rows.take(pageSize).toList(),
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
    if (session == null || !canViewInventoryDocuments(session)) return;

    final refreshId = ++_refreshSerial;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final rows = await ref
          .read(inventoryDocumentRepositoryProvider)
          .listDocuments(
            session,
            filters: state.filters,
            page: PaginationCursor(
              offset: state.documents.length,
              limit: pageSize + 1,
            ),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        documents: [...state.documents, ...rows.take(pageSize)],
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

  Future<void> setFilters(InventoryDocumentFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }
}
