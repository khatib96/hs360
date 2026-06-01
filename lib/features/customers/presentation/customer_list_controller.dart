import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/customer_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_repository.dart';
import '../domain/customer_filters.dart';
import '../domain/customer_form_state.dart';
import '../domain/customer_permissions.dart';
import '../domain/customer_type.dart';
import 'customer_list_state.dart';

part 'customer_list_controller.g.dart';

@Riverpod(keepAlive: true)
class CustomerListController extends _$CustomerListController {
  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  CustomerListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const CustomerListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const CustomerListState(isLoading: true);
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
    if (session == null || !canViewCustomers(session)) {
      state = const CustomerListState();
      return;
    }

    final refreshId = ++_refreshSerial;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final customers = await ref
          .read(customerRepositoryProvider)
          .fetchCustomers(session, state.filters);
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        customers: customers,
        isLoading: false,
        clearError: true,
      );
    } on CustomerException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: CustomerException.unknown,
      );
    }
  }

  void _applyFilters(CustomerFilters filters) {
    state = state.copyWith(filters: filters);
    refresh();
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    _applyFilters(
      _copyFilters(
        search: trimmed == null || trimmed.isEmpty ? null : trimmed,
        clearSearch: trimmed == null || trimmed.isEmpty,
      ),
    );
  }

  void setIsActive(bool? isActive) {
    _applyFilters(_copyFilters(isActive: isActive, clearIsActive: isActive == null));
  }

  void setIsVip(bool? isVip) {
    _applyFilters(_copyFilters(isVip: isVip, clearIsVip: isVip == null));
  }

  void setCustomerType(CustomerType? customerType) {
    _applyFilters(
      _copyFilters(
        customerType: customerType,
        clearCustomerType: customerType == null,
      ),
    );
  }

  void setArea(String? area) {
    final trimmed = area?.trim();
    _applyFilters(
      _copyFilters(
        area: trimmed == null || trimmed.isEmpty ? null : trimmed,
        clearArea: trimmed == null || trimmed.isEmpty,
      ),
    );
  }

  void setGovernorate(String? governorate) {
    final trimmed = governorate?.trim();
    _applyFilters(
      _copyFilters(
        governorate: trimmed == null || trimmed.isEmpty ? null : trimmed,
        clearGovernorate: trimmed == null || trimmed.isEmpty,
        clearArea: true,
      ),
    );
  }

  Future<String?> ensureAccount(String id) async {
    final session = _session;
    if (session == null ||
        !canViewCustomers(session) ||
        !canEditCustomer(session)) {
      return CustomerException.permissionDenied;
    }
    return _mutate(() => ref
        .read(customerRepositoryProvider)
        .ensureCustomerAccount(session, id));
  }

  void clearFilters() {
    state = state.copyWith(filters: const CustomerFilters(isActive: true));
    refresh();
  }

  CustomerFilters _copyFilters({
    String? search,
    bool clearSearch = false,
    bool? isActive,
    bool clearIsActive = false,
    bool? isVip,
    bool clearIsVip = false,
    CustomerType? customerType,
    bool clearCustomerType = false,
    String? governorate,
    bool clearGovernorate = false,
    String? area,
    bool clearArea = false,
  }) {
    final current = state.filters;
    return CustomerFilters(
      search: clearSearch ? null : (search ?? current.search),
      isActive: clearIsActive ? null : (isActive ?? current.isActive),
      isVip: clearIsVip ? null : (isVip ?? current.isVip),
      customerType:
          clearCustomerType ? null : (customerType ?? current.customerType),
      governorate:
          clearGovernorate ? null : (governorate ?? current.governorate),
      area: clearArea ? null : (area ?? current.area),
    );
  }

  Future<String?> createCustomer(CustomerFormState input) async {
    final session = _session;
    if (session == null ||
        !canViewCustomers(session) ||
        !canCreateCustomer(session)) {
      return CustomerException.permissionDenied;
    }
    return _mutate(() => ref
        .read(customerRepositoryProvider)
        .createCustomer(session, input));
  }

  Future<String?> updateCustomer(String id, CustomerFormState input) async {
    final session = _session;
    if (session == null ||
        !canViewCustomers(session) ||
        !canEditCustomer(session)) {
      return CustomerException.permissionDenied;
    }
    return _mutate(() => ref
        .read(customerRepositoryProvider)
        .updateCustomer(session, id, input));
  }

  Future<String?> deactivateCustomer(String id) async {
    final session = _session;
    if (session == null ||
        !canViewCustomers(session) ||
        !canDeactivateCustomer(session)) {
      return CustomerException.permissionDenied;
    }
    return _mutate(() =>
        ref.read(customerRepositoryProvider).deactivateCustomer(session, id));
  }

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } on CustomerException catch (e) {
      return e.code;
    } catch (_) {
      return CustomerException.unknown;
    }
  }
}
