import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/date_range.dart';
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
      filters: _copyFilters(
        type: type,
        clearType: type == null,
        clearStatus: true,
      ),
    );
    refresh();
  }

  void setStatus(VoucherStatus? status) {
    state = state.copyWith(
      filters: _copyFilters(status: status, clearStatus: status == null),
    );
    refresh();
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    state = state.copyWith(
      filters: _copyFilters(
        search: trimmed == null || trimmed.isEmpty ? null : trimmed,
        clearSearch: trimmed == null || trimmed.isEmpty,
      ),
    );
    refresh();
  }

  void setPartyId(String? partyId) {
    final trimmed = partyId?.trim();
    state = state.copyWith(
      filters: _copyFilters(
        partyId: trimmed == null || trimmed.isEmpty ? null : trimmed,
        clearPartyId: trimmed == null || trimmed.isEmpty,
      ),
    );
    refresh();
  }

  void setDateFrom(DateTime? from) {
    state = state.copyWith(
      filters: _copyFilters(
        dateRange: state.filters.dateRange.copyWith(from: from),
      ),
    );
    refresh();
  }

  void setDateTo(DateTime? to) {
    state = state.copyWith(
      filters: _copyFilters(
        dateRange: state.filters.dateRange.copyWith(to: to),
      ),
    );
    refresh();
  }

  VoucherFilters _copyFilters({
    VoucherType? type,
    VoucherStatus? status,
    String? partyId,
    String? search,
    DateRange? dateRange,
    bool clearType = false,
    bool clearStatus = false,
    bool clearPartyId = false,
    bool clearSearch = false,
  }) {
    final current = state.filters;
    return current.copyWith(
      type: clearType ? null : (type ?? current.type),
      status: clearStatus ? null : (status ?? current.status),
      partyId: clearPartyId ? null : (partyId ?? current.partyId),
      dateRange: dateRange ?? current.dateRange,
      search: clearSearch ? null : (search ?? current.search),
      clearType: clearType,
      clearStatus: clearStatus,
      clearPartyId: clearPartyId,
      clearSearch: clearSearch,
    );
  }
}
