import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/products/data/product_group_repository.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/domain/product_filters.dart';
import 'package:hs360/features/products/presentation/product_list_controller.dart';
import 'package:hs360/features/products/presentation/product_list_state.dart';

import '../fake_product_repositories.dart';

AppSession _session({Set<String> permissions = const {'products.view'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: permissions,
    ),
  );
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

void main() {
  group('effectiveProductFilters', () {
    test('clears stockFilter when stock not allowed', () {
      const filters = ProductFilters(stockFilter: ProductStockFilter.inStock);
      final effective = effectiveProductFilters(
        filters,
        canViewStock: false,
        canViewGroups: true,
      );
      expect(effective.stockFilter, isNull);
    });

    test('clears groupId when group access is not allowed', () {
      const filters = ProductFilters(groupId: 'g-1');
      final effective = effectiveProductFilters(
        filters,
        canViewStock: true,
        canViewGroups: false,
      );
      expect(effective.groupId, isNull);
    });
  });

  group('ProductListController', () {
    test('loads products without stock when inventory.view missing', () async {
      final product = sampleProduct();
      final productRepository = FakeProductRepository(products: [product]);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'products.view'}),
            ),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => productRepository,
          ),
          productGroupRepositoryProvider.overrideWith(
            (ref) => FakeProductGroupRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(productListControllerProvider.notifier).refresh();

      final state = container.read(productListControllerProvider);
      expect(state.products, hasLength(1));
      expect(state.stockByProductId, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.errorCode, isNull);
      expect(productRepository.stockFetchCount, 0);
    });

    test('products load succeeds when stock fetch throws', () async {
      final product = sampleProduct();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {'products.view', 'inventory.view'},
              ),
            ),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(
              products: [product],
              stockThrows: true,
            ),
          ),
          productGroupRepositoryProvider.overrideWith(
            (ref) => FakeProductGroupRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(productListControllerProvider.notifier).refresh();

      final state = container.read(productListControllerProvider);
      expect(state.products, hasLength(1));
      expect(state.stockByProductId, isEmpty);
      expect(state.errorCode, isNull);
    });

    test('products load succeeds when group fetch throws', () async {
      final product = sampleProduct();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(
                permissions: {'products.view', 'product_groups.view'},
              ),
            ),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(products: [product]),
          ),
          productGroupRepositoryProvider.overrideWith(
            (ref) => FakeProductGroupRepository(fetchThrows: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(productListControllerProvider.notifier).refresh();

      final state = container.read(productListControllerProvider);
      expect(state.products, hasLength(1));
      expect(state.groups, isEmpty);
      expect(state.errorCode, isNull);
    });

    test('setStockFilter ignored without inventory.view', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session(permissions: {'products.view'})),
          ),
          productRepositoryProvider.overrideWith(
            (ref) => FakeProductRepository(products: [sampleProduct()]),
          ),
          productGroupRepositoryProvider.overrideWith(
            (ref) => FakeProductGroupRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(productListControllerProvider.notifier);
      notifier.setStockFilter(ProductStockFilter.inStock);

      final state = container.read(productListControllerProvider);
      expect(state.filters.stockFilter, isNull);
    });
  });
}
