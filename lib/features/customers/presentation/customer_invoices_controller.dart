import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../invoices/domain/invoice_filters.dart';
import '../../invoices/domain/invoice_status.dart';
import '../../invoices/domain/invoice_type.dart';
import 'customer_invoices_state.dart';

part 'customer_invoices_controller.g.dart';

@riverpod
class CustomerInvoicesController extends _$CustomerInvoicesController {
  static const pageSize = InvoiceRepository.defaultPageSize;

  @override
  CustomerInvoicesState build(String customerId) {
    return CustomerInvoicesState(
      filters: InvoiceFilters(partyId: customerId, type: InvoiceType.sales),
    );
  }

  Future<void> load({bool force = false}) async {
    if (state.isLoading || state.isLoadingMore || (state.hasLoaded && !force)) {
      return;
    }

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        permissionDenied: true,
      );
      return;
    }

    if (!canViewSalesInvoices(session)) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        permissionDenied: true,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final rows = await ref
          .read(invoiceRepositoryProvider)
          .listSalesInvoices(
            session,
            filters: state.filters,
            page: const PaginationCursor(limit: pageSize + 1),
          );
      state = CustomerInvoicesState(
        filters: state.filters,
        isLoading: false,
        hasLoaded: true,
        invoices: rows.take(pageSize).toList(),
        hasMore: rows.length > pageSize,
      );
    } on FinanceException catch (e) {
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewSalesInvoices(session)) return;

    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final rows = await ref
          .read(invoiceRepositoryProvider)
          .listSalesInvoices(
            session,
            filters: state.filters,
            page: PaginationCursor(
              offset: state.invoices.length,
              limit: pageSize + 1,
            ),
          );
      state = state.copyWith(
        invoices: [...state.invoices, ...rows.take(pageSize)],
        isLoadingMore: false,
        hasMore: rows.length > pageSize,
        clearLoadMoreError: true,
      );
    } on FinanceException catch (e) {
      state = state.copyWith(isLoadingMore: false, loadMoreErrorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorCode: FinanceException.unknown,
      );
    }
  }

  void setStatus(InvoiceStatus? status) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        status: status,
        clearStatus: status == null,
      ),
    );
    _reload();
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    state = state.copyWith(
      filters: state.filters.copyWith(
        search: trimmed == null || trimmed.isEmpty ? null : trimmed,
        clearSearch: trimmed == null || trimmed.isEmpty,
      ),
    );
    _reload();
  }

  void setDateFrom(DateTime? from) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        dateRange: state.filters.dateRange.copyWith(from: from),
      ),
    );
    _reload();
  }

  void setDateTo(DateTime? to) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        dateRange: state.filters.dateRange.copyWith(to: to),
      ),
    );
    _reload();
  }

  Future<void> _reload() async {
    state = state.copyWith(hasLoaded: false);
    await load(force: true);
  }
}
