import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/products_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/product_group_repository.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../domain/product_filters.dart';
import '../domain/product_group.dart';
import '../domain/product_stock_summary.dart';
import '../domain/product_type.dart';
import 'product_list_permissions.dart';
import 'product_list_state.dart';

part 'product_list_controller.g.dart';

@Riverpod(keepAlive: true)
class ProductListController extends _$ProductListController {
  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;

  @override
  ProductListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const ProductListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const ProductListState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool get _canViewStock {
    final session = _session;
    return session != null && canViewProductStock(session);
  }

  bool get _canViewGroups {
    final session = _session;
    return session != null && canViewProductGroups(session);
  }

  Future<void> refresh() async {
    _hasStartedInitialLoad = true;
    final session = _session;
    if (session == null) {
      state = const ProductListState();
      return;
    }

    final refreshId = ++_refreshSerial;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final productRepo = ref.read(productRepositoryProvider);
      final groupRepo = ref.read(productGroupRepositoryProvider);

      final filters = effectiveProductFilters(
        state.filters,
        canViewStock: _canViewStock,
        canViewGroups: _canViewGroups,
      );

      final products = await productRepo.fetchProducts(filters, session);
      if (refreshId != _refreshSerial) return;

      final groups = await _loadGroups(groupRepo);
      if (refreshId != _refreshSerial) return;

      var stockByProductId = state.stockByProductId;
      if (_canViewStock) {
        stockByProductId = await _loadStockSummaries(productRepo, products);
      } else {
        stockByProductId = const {};
      }
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        products: products,
        groups: groups,
        stockByProductId: stockByProductId,
        filters: filters,
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

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.permissions.isManager != next.permissions.isManager ||
        !_samePermissionSet(
          previous.permissions.permissions,
          next.permissions.permissions,
        );
  }

  bool _samePermissionSet(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  Future<List<ProductGroup>> _loadGroups(ProductGroupRepository groupRepo) async {
    if (!_canViewGroups) return const [];
    try {
      return await groupRepo.fetchProductGroups(activeOnly: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, ProductStockSummary>> _loadStockSummaries(
    ProductRepository productRepo,
    List<Product> products,
  ) async {
    final map = <String, ProductStockSummary>{};
    await Future.wait(
      products.map((product) async {
        try {
          final summary = await productRepo.fetchProductStock(product.id);
          map[product.id] = summary;
        } catch (_) {
          // Stock is secondary; ignore per-product failures.
        }
      }),
    );
    return map;
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    final value = trimmed == null || trimmed.isEmpty ? null : trimmed;
    state = state.copyWith(
      filters: ProductFilters(
        search: value,
        groupId: state.filters.groupId,
        productType: state.filters.productType,
        isActive: state.filters.isActive,
        stockFilter: state.filters.stockFilter,
      ),
    );
    refresh();
  }

  void setGroupId(String? groupId) {
    state = state.copyWith(
      filters: ProductFilters(
        search: state.filters.search,
        groupId: groupId,
        productType: state.filters.productType,
        isActive: state.filters.isActive,
        stockFilter: state.filters.stockFilter,
      ),
    );
    refresh();
  }

  void setProductType(ProductType? productType) {
    state = state.copyWith(
      filters: ProductFilters(
        search: state.filters.search,
        groupId: state.filters.groupId,
        productType: productType,
        isActive: state.filters.isActive,
        stockFilter: state.filters.stockFilter,
      ),
    );
    refresh();
  }

  void setIsActive(bool? isActive) {
    state = state.copyWith(
      filters: ProductFilters(
        search: state.filters.search,
        groupId: state.filters.groupId,
        productType: state.filters.productType,
        isActive: isActive,
        stockFilter: state.filters.stockFilter,
      ),
    );
    refresh();
  }

  void setStockFilter(ProductStockFilter? stockFilter) {
    if (!_canViewStock) {
      state = state.copyWith(
        filters: ProductFilters(
          search: state.filters.search,
          groupId: state.filters.groupId,
          productType: state.filters.productType,
          isActive: state.filters.isActive,
          stockFilter: null,
        ),
      );
      return;
    }
    state = state.copyWith(
      filters: ProductFilters(
        search: state.filters.search,
        groupId: state.filters.groupId,
        productType: state.filters.productType,
        isActive: state.filters.isActive,
        stockFilter: stockFilter,
      ),
    );
    refresh();
  }

  void clearFilters() {
    state = state.copyWith(filters: const ProductFilters());
    refresh();
  }

  Future<void> createGroup(ProductGroupFormState input) async {
    final session = _session;
    if (session == null || !canCreateProductGroup(session)) return;

    final group = await ref
        .read(productGroupRepositoryProvider)
        .createProductGroup(session, input);
    state = state.copyWith(groups: [...state.groups, group]);
    await refresh();
  }

  Future<void> updateGroup(String id, ProductGroupFormState input) async {
    final session = _session;
    if (session == null || !canEditProductGroup(session)) return;

    await ref
        .read(productGroupRepositoryProvider)
        .updateProductGroup(session, id, input);
    await refresh();
  }

  Future<void> deactivateGroup(String id) async {
    final session = _session;
    if (session == null || !canEditProductGroup(session)) return;

    await ref.read(productGroupRepositoryProvider).deactivateProductGroup(
          session,
          id,
        );
    await refresh();
  }
}
