import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/products/domain/product_stock_label.dart';

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

void main() {
  group('FakeProductRepository.fetchProductsByIdsForStockLabels', () {
    test('returns empty map without products.view', () async {
      final repo = FakeProductRepository(
        stockLabelsById: {
          'p-1': const ProductStockLabel(
            id: 'p-1',
            sku: 'SKU',
            nameAr: 'ع',
            nameEn: 'Product',
          ),
        },
      );

      final result = await repo.fetchProductsByIdsForStockLabels(
        _session(permissions: {}),
        {'p-1'},
      );

      expect(result, isEmpty);
    });

    test('returns empty map for empty product ids', () async {
      final repo = FakeProductRepository(
        stockLabelsById: {
          'p-1': const ProductStockLabel(
            id: 'p-1',
            sku: 'SKU',
            nameAr: 'ع',
            nameEn: 'Product',
          ),
        },
      );

      final result = await repo.fetchProductsByIdsForStockLabels(
        _session(),
        {},
      );

      expect(result, isEmpty);
    });

    test('returns only found ids without throwing on partial data', () async {
      final repo = FakeProductRepository(
        stockLabelsById: {
          'p-1': const ProductStockLabel(
            id: 'p-1',
            sku: 'SKU',
            nameAr: 'ع',
            nameEn: 'Product',
          ),
        },
      );

      final result = await repo.fetchProductsByIdsForStockLabels(
        _session(),
        {'p-1', 'p-missing'},
      );

      expect(result, hasLength(1));
      expect(result['p-1']?.sku, 'SKU');
      expect(result.containsKey('p-missing'), isFalse);
    });
  });
}
