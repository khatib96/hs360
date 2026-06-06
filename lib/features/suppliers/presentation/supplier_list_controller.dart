import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/supplier_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier_filters.dart';
import '../domain/supplier_form_state.dart';
import '../domain/supplier_permissions.dart';
import 'supplier_list_state.dart';

part 'supplier_list_controller.g.dart';

@Riverpod(keepAlive: true)
class SupplierListController extends _$SupplierListController {
  static const pageSize = 100;

  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  SupplierListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const SupplierListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const SupplierListState(isLoading: true);
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
    if (session == null || !canViewSuppliers(session)) {
      state = const SupplierListState();
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
      final rows = await ref
          .read(supplierRepositoryProvider)
          .fetchSuppliers(session, state.filters, limit: pageSize + 1);
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        suppliers: rows.take(pageSize).toList(),
        isLoading: false,
        isLoadingMore: false,
        hasMore: rows.length > pageSize,
        clearError: true,
      );
    } on SupplierException catch (e) {
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
        errorCode: SupplierException.unknown,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final session = _session;
    if (session == null || !canViewSuppliers(session)) return;

    final refreshId = ++_refreshSerial;
    state = state.copyWith(
      isLoadingMore: true,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final rows = await ref
          .read(supplierRepositoryProvider)
          .fetchSuppliers(
            session,
            state.filters,
            offset: state.suppliers.length,
            limit: pageSize + 1,
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        suppliers: [...state.suppliers, ...rows.take(pageSize)],
        isLoadingMore: false,
        hasMore: rows.length > pageSize,
        clearError: true,
        clearLoadMoreError: true,
      );
    } on SupplierException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(isLoadingMore: false, loadMoreErrorCode: e.code);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorCode: SupplierException.unknown,
      );
    }
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    final value = trimmed == null || trimmed.isEmpty ? null : trimmed;
    state = state.copyWith(
      filters: SupplierFilters(search: value, isActive: state.filters.isActive),
    );
    refresh();
  }

  void setIsActive(bool? isActive) {
    state = state.copyWith(
      filters: SupplierFilters(
        search: state.filters.search,
        isActive: isActive,
      ),
    );
    refresh();
  }

  void clearFilters() {
    state = state.copyWith(filters: const SupplierFilters(isActive: true));
    refresh();
  }

  Future<String?> createSupplier(SupplierFormState input) async {
    final session = _session;
    if (session == null ||
        !canViewSuppliers(session) ||
        !canCreateSupplier(session)) {
      return SupplierException.permissionDenied;
    }
    return _mutate(
      () => ref.read(supplierRepositoryProvider).createSupplier(session, input),
    );
  }

  Future<String?> updateSupplier(String id, SupplierFormState input) async {
    final session = _session;
    if (session == null ||
        !canViewSuppliers(session) ||
        !canEditSupplier(session)) {
      return SupplierException.permissionDenied;
    }
    return _mutate(
      () => ref
          .read(supplierRepositoryProvider)
          .updateSupplier(session, id, input),
    );
  }

  Future<String?> ensureAccount(String id) async {
    final session = _session;
    if (session == null ||
        !canViewSuppliers(session) ||
        !canEditSupplier(session)) {
      return SupplierException.permissionDenied;
    }
    return _mutate(
      () => ref
          .read(supplierRepositoryProvider)
          .ensureSupplierAccount(session, id),
    );
  }

  Future<String?> deactivateSupplier(String id) async {
    final session = _session;
    if (session == null ||
        !canViewSuppliers(session) ||
        !canDeactivateSupplier(session)) {
      return SupplierException.permissionDenied;
    }
    return _mutate(
      () =>
          ref.read(supplierRepositoryProvider).deactivateSupplier(session, id),
    );
  }

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } on SupplierException catch (e) {
      return e.code;
    } catch (_) {
      return SupplierException.unknown;
    }
  }
}
