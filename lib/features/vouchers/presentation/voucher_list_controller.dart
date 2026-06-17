import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../data/voucher_repository.dart';
import '../domain/voucher_filters.dart';
import '../domain/voucher_permissions.dart';
import '../domain/voucher_status.dart';
import '../domain/voucher_type.dart';
import 'voucher_list_state.dart';

part 'voucher_list_controller.g.dart';

@Riverpod(keepAlive: true)
class VoucherListController extends _$VoucherListController {
  static const pageSize = 50;

  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  VoucherListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const VoucherListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const VoucherListState(isLoading: true);
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
    if (session == null || !canViewVouchers(session)) {
      state = const VoucherListState();
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
          .read(voucherRepositoryProvider)
          .listVouchers(
            session,
            filters: state.filters,
            page: const PaginationCursor(limit: pageSize + 1),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        vouchers: rows.take(pageSize).toList(),
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
    if (session == null || !canViewVouchers(session)) return;

    final refreshId = ++_refreshSerial;
    state = state.copyWith(
      isLoadingMore: true,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final rows = await ref
          .read(voucherRepositoryProvider)
          .listVouchers(
            session,
            filters: state.filters,
            page: PaginationCursor(
              offset: state.vouchers.length,
              limit: pageSize + 1,
            ),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        vouchers: [...state.vouchers, ...rows.take(pageSize)],
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

  void setType(VoucherType? type) {
    state = state.copyWith(
      filters: VoucherFilters(
        type: type,
        status: state.filters.status,
        partyId: state.filters.partyId,
        dateRange: state.filters.dateRange,
        search: state.filters.search,
      ),
    );
    refresh();
  }

  void setStatus(VoucherStatus? status) {
    state = state.copyWith(
      filters: VoucherFilters(
        type: state.filters.type,
        status: status,
        partyId: state.filters.partyId,
        dateRange: state.filters.dateRange,
        search: state.filters.search,
      ),
    );
    refresh();
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    state = state.copyWith(
      filters: VoucherFilters(
        type: state.filters.type,
        status: state.filters.status,
        partyId: state.filters.partyId,
        dateRange: state.filters.dateRange,
        search: trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
    refresh();
  }
}
