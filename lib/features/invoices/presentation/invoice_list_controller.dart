import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice_filters.dart';
import '../domain/invoice_permissions.dart';
import '../domain/invoice_status.dart';
import '../domain/invoice_type.dart';
import '../domain/invoice_summary.dart';
import 'invoice_list_state.dart';

part 'invoice_list_controller.g.dart';

@Riverpod(keepAlive: true)
class InvoiceListController extends _$InvoiceListController {
  static const pageSize = InvoiceRepository.defaultPageSize;

  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  InvoiceListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const InvoiceListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return InvoiceListState(
      isLoading: true,
      filters: InvoiceFilters(type: _defaultType()),
    );
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  InvoiceType? _defaultType() {
    final session = _session;
    if (session == null) return null;
    if (canViewSalesInvoices(session)) return InvoiceType.sales;
    if (canViewPurchaseInvoices(session)) return InvoiceType.purchase;
    if (canViewReturnInvoices(session)) return InvoiceType.salesReturn;
    return null;
  }

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
    final type = state.filters.type ?? _defaultType();
    if (session == null || type == null || !_canViewType(session, type)) {
      state = const InvoiceListState();
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
      final rows = await _fetchPage(
        session,
        type,
        state.filters,
        const PaginationCursor(limit: pageSize + 1),
      );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        invoices: rows.take(pageSize).toList(),
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
    final type = state.filters.type ?? _defaultType();
    if (session == null || type == null || !_canViewType(session, type)) return;

    final refreshId = ++_refreshSerial;
    state = state.copyWith(
      isLoadingMore: true,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final rows = await _fetchPage(
        session,
        type,
        state.filters,
        PaginationCursor(offset: state.invoices.length, limit: pageSize + 1),
      );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        invoices: [...state.invoices, ...rows.take(pageSize)],
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

  void setType(InvoiceType? type) {
    state = state.copyWith(filters: _copyFilters(type: type));
    refresh();
  }

  void setStatus(InvoiceStatus? status) {
    state = state.copyWith(filters: _copyFilters(status: status));
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

  InvoiceFilters _copyFilters({
    InvoiceType? type,
    InvoiceStatus? status,
    String? search,
    bool clearSearch = false,
    String? partyId,
    bool clearPartyId = false,
  }) {
    final current = state.filters;
    return InvoiceFilters(
      type: type ?? current.type,
      status: status ?? current.status,
      partyId: clearPartyId ? null : (partyId ?? current.partyId),
      dateRange: current.dateRange,
      search: clearSearch ? null : (search ?? current.search),
    );
  }

  Future<List<InvoiceSummary>> _fetchPage(
    AppSession session,
    InvoiceType type,
    InvoiceFilters filters,
    PaginationCursor page,
  ) {
    final repo = ref.read(invoiceRepositoryProvider);
    final returnFilters = type.isReturn
        ? InvoiceFilters(
            type: type,
            status: filters.status,
            partyId: filters.partyId,
            dateRange: filters.dateRange,
            search: filters.search,
          )
        : filters;
    return switch (type) {
      InvoiceType.sales => repo.listSalesInvoices(
        session,
        filters: filters,
        page: page,
      ),
      InvoiceType.purchase => repo.listPurchaseInvoices(
        session,
        filters: filters,
        page: page,
      ),
      InvoiceType.salesReturn || InvoiceType.purchaseReturn =>
        repo.listReturnInvoices(session, filters: returnFilters, page: page),
    };
  }

  bool _canViewType(AppSession session, InvoiceType type) {
    return switch (type) {
      InvoiceType.sales => canViewSalesInvoices(session),
      InvoiceType.purchase => canViewPurchaseInvoices(session),
      InvoiceType.salesReturn ||
      InvoiceType.purchaseReturn => canViewReturnInvoices(session),
    };
  }
}
