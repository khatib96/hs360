import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/customer_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_repository.dart';
import '../domain/customer_permissions.dart';
import 'customer_detail_state.dart';

part 'customer_detail_controller.g.dart';

@riverpod
class CustomerDetailController extends _$CustomerDetailController {
  @override
  CustomerDetailState build(String customerId) {
    Future.microtask(() => load(customerId));
    return const CustomerDetailState();
  }

  Future<void> load(String customerId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewCustomers(session)) {
      state = const CustomerDetailState(
        isLoading: false,
        errorCode: CustomerException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final customer = await ref
          .read(customerRepositoryProvider)
          .fetchCustomerById(session, customerId);
      state = CustomerDetailState(isLoading: false, customer: customer);
    } on CustomerException catch (e) {
      state = CustomerDetailState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const CustomerDetailState(
        isLoading: false,
        errorCode: CustomerException.unknown,
      );
    }
  }
}
