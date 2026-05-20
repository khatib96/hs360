import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/domain/product_group.dart';
import 'package:hs360/features/products/domain/product_group_tree.dart';

void main() {
  group('buildProductGroupTree', () {
    test('orders siblings by sortOrder', () {
      final groups = [
        ProductGroup(
          id: 'b',
          tenantId: 't',
          nameAr: 'B',
          nameEn: 'B',
          sortOrder: 2,
          isActive: true,
        ),
        ProductGroup(
          id: 'a',
          tenantId: 't',
          nameAr: 'A',
          nameEn: 'A',
          sortOrder: 1,
          isActive: true,
        ),
      ];

      final tree = buildProductGroupTree(groups);
      expect(tree, hasLength(2));
      expect(tree.first.group.id, 'a');
      expect(tree[1].group.id, 'b');
    });

    test('nests children under parent', () {
      final groups = [
        ProductGroup(
          id: 'parent',
          tenantId: 't',
          nameAr: 'P',
          nameEn: 'P',
          isActive: true,
        ),
        ProductGroup(
          id: 'child',
          tenantId: 't',
          nameAr: 'C',
          nameEn: 'C',
          parentId: 'parent',
          isActive: true,
        ),
      ];

      final tree = buildProductGroupTree(groups);
      expect(tree, hasLength(1));
      expect(tree.first.children, hasLength(1));
      expect(tree.first.children.first.group.id, 'child');
    });

    test('promotes groups with missing parents to roots', () {
      final groups = [
        ProductGroup(
          id: 'orphan',
          tenantId: 't',
          nameAr: 'O',
          nameEn: 'O',
          parentId: 'missing',
          isActive: true,
        ),
      ];

      final tree = buildProductGroupTree(groups);
      expect(tree, hasLength(1));
      expect(tree.first.group.id, 'orphan');
    });

    test('does not recurse forever when data contains a cycle', () {
      final groups = [
        ProductGroup(
          id: 'a',
          tenantId: 't',
          nameAr: 'A',
          nameEn: 'A',
          parentId: 'b',
          isActive: true,
        ),
        ProductGroup(
          id: 'b',
          tenantId: 't',
          nameAr: 'B',
          nameEn: 'B',
          parentId: 'a',
          isActive: true,
        ),
      ];

      final tree = buildProductGroupTree(groups);
      expect(tree, hasLength(1));
      expect(tree.first.group.id, 'a');
      expect(tree.first.children.single.group.id, 'b');
      expect(tree.first.children.single.children, isEmpty);
    });
  });
}
