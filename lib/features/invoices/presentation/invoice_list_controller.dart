import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/date_range.dart';
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
    return InvoiceListState(isLoading: true, filters: const InvoiceFilters());
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
    final type = state.filters.type;
    if (session == null ||
        !canViewAnyInvoices(session) ||
        (type != null && !_canViewType(session, type))) {
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
    final type = state.filters.type;
    if (session == null ||
        !canViewAnyInvoices(session) ||
        (type != null && !_canViewType(session, type))) {
      return;
    }

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
    state = state.copyWith(
      filters: _copyFilters(
        type: type,
        clearType: type == null,
        clearStatus: true,
      ),
    );
    refresh();
  }

  void setStatus(InvoiceStatus? status) {
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

  void setDateRange(DateRange dateRange) {
    state = state.copyWith(filters: _copyFilters(dateRange: dateRange));
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

  InvoiceFilters _copyFilters({
    InvoiceType? type,
    InvoiceStatus? status,
    String? search,
    bool clearSearch = false,
    String? partyId,
    bool clearPartyId = false,
    DateRange? dateRange,
    bool clearType = false,
    bool clearStatus = false,
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

  Future<List<InvoiceSummary>> _fetchPage(
    AppSession session,
    InvoiceType? type,
    InvoiceFilters filters,
    PaginationCursor page,
  ) {
    final repo = ref.read(invoiceRepositoryProvider);
    if (type == null) {
      return _fetchAllTypesPage(session, filters, page);
    }
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

  Future<List<InvoiceSummary>> _fetchAllTypesPage(
    AppSession session,
    InvoiceFilters filters,
    PaginationCursor page,
  ) async {
    final repo = ref.read(invoiceRepositoryProvider);
    final fetchLimit = page.offset + page.limit;
    final merged = <InvoiceSummary>[];
    final basePage = PaginationCursor(limit: fetchLimit, offset: 0);

    if (canViewSalesInvoices(session)) {
      merged.addAll(
        await repo.listSalesInvoices(session, filters: filters, page: basePage),
      );
    }
    if (canViewPurchaseInvoices(session)) {
      merged.addAll(
        await repo.listPurchaseInvoices(
          session,
          filters: filters,
          page: basePage,
        ),
      );
    }
    if (canViewReturnInvoices(session)) {
      merged.addAll(
        await repo.listReturnInvoices(
          session,
          filters: filters.copyWith(clearType: true),
          page: basePage,
        ),
      );
    }

    merged.sort(_compareNewestFirst);
    if (page.offset >= merged.length) return const [];
    final end = page.offset + page.limit;
    return merged.sublist(
      page.offset,
      end > merged.length ? merged.length : end,
    );
  }

  int _compareNewestFirst(InvoiceSummary a, InvoiceSummary b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    final byNumber = (b.invoiceNumber ?? '').compareTo(a.invoiceNumber ?? '');
    if (byNumber != 0) return byNumber;
    return b.id.compareTo(a.id);
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
