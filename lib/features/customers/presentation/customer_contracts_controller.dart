import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contracts/data/contract_repository.dart';
import '../../contracts/domain/contract_filters.dart';
import '../../contracts/domain/contract_permissions.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import 'customer_contracts_state.dart';

part 'customer_contracts_controller.g.dart';

@riverpod
class CustomerContractsController extends _$CustomerContractsController {
  static const pageSize = ContractRepository.defaultPageSize;

  @override
  CustomerContractsState build(String customerId) {
    return CustomerContractsState(
      filters: ContractFilters(customerId: customerId),
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

    if (!canViewContracts(session)) {
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
      listUnavailable: false,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final rows = await ref
          .read(contractRepositoryProvider)
          .listContracts(
            session,
            filters: state.filters,
            page: const PaginationCursor(limit: pageSize + 1),
          );
      state = CustomerContractsState(
        filters: state.filters,
        isLoading: false,
        hasLoaded: true,
        contracts: rows.take(pageSize).toList(),
        hasMore: rows.length > pageSize,
      );
    } on FinanceException catch (e) {
      if (e.code == FinanceException.notAvailable) {
        state = state.copyWith(
          isLoading: false,
          hasLoaded: true,
          listUnavailable: true,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewContracts(session)) return;

    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final rows = await ref
          .read(contractRepositoryProvider)
          .listContracts(
            session,
            filters: state.filters,
            page: PaginationCursor(
              offset: state.contracts.length,
              limit: pageSize + 1,
            ),
          );
      final next = rows.take(pageSize).toList();
      state = state.copyWith(
        isLoadingMore: false,
        contracts: [...state.contracts, ...next],
        hasMore: rows.length > pageSize,
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
}
