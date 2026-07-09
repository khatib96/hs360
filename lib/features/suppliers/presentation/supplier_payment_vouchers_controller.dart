import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../../vouchers/data/voucher_repository.dart';
import '../../vouchers/domain/voucher_filters.dart';
import '../../vouchers/domain/voucher_party_scope.dart';
import '../../vouchers/domain/voucher_permissions.dart';
import '../../vouchers/domain/voucher_status.dart';
import '../../vouchers/domain/voucher_type.dart';
import 'supplier_payment_vouchers_state.dart';

part 'supplier_payment_vouchers_controller.g.dart';

@riverpod
class SupplierPaymentVouchersController
    extends _$SupplierPaymentVouchersController {
  static const pageSize = 50;
  int _rpcOffset = 0;

  @override
  SupplierPaymentVouchersState build(String supplierId) {
    return SupplierPaymentVouchersState(
      filters: VoucherFilters(partyId: supplierId, type: VoucherType.payment),
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

    if (!canViewVouchers(session)) {
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
      final raw = await ref
          .read(voucherRepositoryProvider)
          .listVouchers(
            session,
            filters: state.filters,
            page: const PaginationCursor(limit: pageSize + 1),
          );
      _rpcOffset = raw.length;
      final rows = scopeSupplierPaymentVouchers(raw, supplierId);
      state = SupplierPaymentVouchersState(
        filters: state.filters,
        isLoading: false,
        hasLoaded: true,
        vouchers: rows.take(pageSize).toList(),
        hasMore: raw.length > pageSize,
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
    if (session == null || !canViewVouchers(session)) return;

    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final raw = await ref
          .read(voucherRepositoryProvider)
          .listVouchers(
            session,
            filters: state.filters,
            page: PaginationCursor(offset: _rpcOffset, limit: pageSize + 1),
          );
      _rpcOffset += raw.length;
      final rows = scopeSupplierPaymentVouchers(raw, supplierId);
      state = state.copyWith(
        vouchers: [...state.vouchers, ...rows.take(pageSize)],
        isLoadingMore: false,
        hasMore: raw.length > pageSize,
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

  void setStatus(VoucherStatus? status) {
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
    _rpcOffset = 0;
    state = state.copyWith(hasLoaded: false);
    await load(force: true);
  }
}
