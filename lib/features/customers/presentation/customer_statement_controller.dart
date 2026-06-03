import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/customer_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_repository.dart';
import '../domain/customer_permissions.dart';
import 'customer_statement_state.dart';

part 'customer_statement_controller.g.dart';

@riverpod
class CustomerStatementController extends _$CustomerStatementController {
  @override
  CustomerStatementState build(String customerId) {
    return CustomerStatementState();
  }

  Future<void> load({bool force = false}) async {
    if (state.isLoading || (state.hasLoaded && !force)) return;

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

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final summary = await repo.fetchCustomerBalanceSummary(
        session,
        customerId,
      );
      final rows = await repo.fetchCustomerStatement(session, customerId);
      state = CustomerStatementState(
        isLoading: false,
        hasLoaded: true,
        summary: summary,
        rows: rows,
      );
    } on CustomerException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorCode: e.code,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: CustomerException.unknown,
      );
    }
  }
}
