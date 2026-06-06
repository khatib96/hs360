import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/customer_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_repository.dart';
import '../domain/customer_permissions.dart';
import 'customer_statement_state.dart';

part 'customer_statement_controller.g.dart';

@riverpod
class CustomerStatementController extends _$CustomerStatementController {
  static const pageSize = 100;

  @override
  CustomerStatementState build(String customerId) {
    return CustomerStatementState();
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

    if (!canViewCustomerLedger(session)) {
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
      final repo = ref.read(customerRepositoryProvider);
      final summary = await repo.fetchCustomerBalanceSummary(
        session,
        customerId,
      );
      final rows = await repo.fetchCustomerStatement(
        session,
        customerId,
        limit: pageSize + 1,
      );
      state = CustomerStatementState(
        isLoading: false,
        hasLoaded: true,
        summary: summary,
        rows: rows.take(pageSize).toList(),
        hasMore: rows.length > pageSize,
      );
    } on CustomerException catch (e) {
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: CustomerException.unknown,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewCustomerLedger(session)) return;

    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final rows = await ref
          .read(customerRepositoryProvider)
          .fetchCustomerStatement(
            session,
            customerId,
            offset: state.rows.length,
            limit: pageSize + 1,
          );
      state = state.copyWith(
        rows: [...state.rows, ...rows.take(pageSize)],
        isLoadingMore: false,
        hasMore: rows.length > pageSize,
        clearLoadMoreError: true,
      );
    } on CustomerException catch (e) {
      state = state.copyWith(isLoadingMore: false, loadMoreErrorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorCode: CustomerException.unknown,
      );
    }
  }
}
