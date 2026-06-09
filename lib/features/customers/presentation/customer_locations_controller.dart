import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/customer_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_service_location_repository.dart';
import '../domain/customer_permissions.dart';
import '../domain/customer_service_location_form_state.dart';
import 'customer_locations_state.dart';

part 'customer_locations_controller.g.dart';

@riverpod
class CustomerLocationsController extends _$CustomerLocationsController {
  @override
  CustomerLocationsState build(String customerId) {
    Future.microtask(refresh);
    return const CustomerLocationsState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  Future<void> refresh() async {
    final session = _session;
    if (session == null || !canViewCustomers(session)) {
      state = const CustomerLocationsState();
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final locations = await ref
          .read(customerServiceLocationRepositoryProvider)
          .listLocations(session, customerId);
      state = state.copyWith(
        locations: locations,
        isLoading: false,
        clearError: true,
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

  Future<String?> createLocation(CustomerServiceLocationFormState input) async {
    final session = _session;
    if (session == null || !canEditCustomer(session)) {
      return CustomerException.permissionDenied;
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await ref
          .read(customerServiceLocationRepositoryProvider)
          .createLocation(session, customerId, input);
      await refresh();
      state = state.copyWith(isMutating: false);
      return null;
    } on CustomerException catch (e) {
      state = state.copyWith(isMutating: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isMutating: false,
        errorCode: CustomerException.unknown,
      );
      return CustomerException.unknown;
    }
  }

  Future<String?> updateLocation(
    String locationId,
    CustomerServiceLocationFormState input,
  ) async {
    final session = _session;
    if (session == null || !canEditCustomer(session)) {
      return CustomerException.permissionDenied;
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await ref
          .read(customerServiceLocationRepositoryProvider)
          .updateLocation(session, customerId, locationId, input);
      await refresh();
      state = state.copyWith(isMutating: false);
      return null;
    } on CustomerException catch (e) {
      state = state.copyWith(isMutating: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isMutating: false,
        errorCode: CustomerException.unknown,
      );
      return CustomerException.unknown;
    }
  }

  Future<String?> deactivateLocation(String locationId) async {
    final session = _session;
    if (session == null || !canEditCustomer(session)) {
      return CustomerException.permissionDenied;
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await ref
          .read(customerServiceLocationRepositoryProvider)
          .deactivateLocation(session, locationId);
      await refresh();
      state = state.copyWith(isMutating: false);
      return null;
    } on CustomerException catch (e) {
      state = state.copyWith(isMutating: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isMutating: false,
        errorCode: CustomerException.unknown,
      );
      return CustomerException.unknown;
    }
  }

  Future<String?> setPrimary(String locationId) async {
    final session = _session;
    if (session == null || !canEditCustomer(session)) {
      return CustomerException.permissionDenied;
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await ref
          .read(customerServiceLocationRepositoryProvider)
          .setPrimary(session, locationId);
      await refresh();
      state = state.copyWith(isMutating: false);
      return null;
    } on CustomerException catch (e) {
      state = state.copyWith(isMutating: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isMutating: false,
        errorCode: CustomerException.unknown,
      );
      return CustomerException.unknown;
    }
  }
}
