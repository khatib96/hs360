import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/products_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/warehouse_repository.dart';
import '../domain/warehouse_form_state.dart';
import '../domain/warehouse_permissions.dart';
import 'warehouses_state.dart';

part 'warehouses_controller.g.dart';

@Riverpod(keepAlive: true)
class WarehousesController extends _$WarehousesController {
  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  WarehousesState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const WarehousesState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const WarehousesState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(
    AppSession? previous,
    AppSession next,
  ) {
    if (previous == null) return true;
    return previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  Future<void> refresh() async {
    _hasStartedInitialLoad = true;
    final session = _session;
    if (session == null || !canViewWarehouses(session)) {
      state = const WarehousesState();
      return;
    }

    final refreshId = ++_refreshSerial;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = ref.read(warehouseRepositoryProvider);
      final warehouses = await repo.fetchWarehouses();
      if (refreshId != _refreshSerial) return;

      var employees = state.employees;
      try {
        employees = await repo.fetchAssignableEmployees();
      } catch (_) {
        employees = const [];
      }
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        warehouses: warehouses,
        employees: employees,
        isLoading: false,
        clearError: true,
      );
    } on ProductsException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: ProductsException.unknown,
      );
    }
  }

  Future<String?> createWarehouse(WarehouseFormState input) async {
    final session = _session;
    if (session == null || !canCreateWarehouse(session)) return null;

    try {
      await ref.read(warehouseRepositoryProvider).createWarehouse(
            session,
            input,
            existingWarehouses: state.warehouses,
          );
      await refresh();
      return null;
    } on ProductsException catch (e) {
      return e.code;
    } catch (_) {
      return ProductsException.unknown;
    }
  }

  Future<String?> updateWarehouse(String id, WarehouseFormState input) async {
    final session = _session;
    if (session == null || !canEditWarehouse(session)) return null;

    try {
      await ref.read(warehouseRepositoryProvider).updateWarehouse(
            session,
            id,
            input,
            existingWarehouses: state.warehouses,
          );
      await refresh();
      return null;
    } on ProductsException catch (e) {
      return e.code;
    } catch (_) {
      return ProductsException.unknown;
    }
  }

  Future<String?> deactivateWarehouse(String id) async {
    final session = _session;
    if (session == null || !canDeactivateWarehouse(session)) return null;

    try {
      await ref.read(warehouseRepositoryProvider).deactivateWarehouse(
            session,
            id,
          );
      await refresh();
      return null;
    } on ProductsException catch (e) {
      return e.code;
    } catch (_) {
      return ProductsException.unknown;
    }
  }
}
