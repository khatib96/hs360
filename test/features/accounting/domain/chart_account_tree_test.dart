import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account.dart';
import 'package:hs360/features/accounting/domain/chart_account_tree.dart';

ChartAccount _account({
  required String id,
  required String code,
  String? parentId,
  String nameEn = 'Account',
}) {
  return ChartAccount(
    id: id,
    tenantId: 't',
    code: code,
    nameAr: 'حساب',
    nameEn: nameEn,
    type: AccountType.asset,
    parentId: parentId,
    isSubaccount: parentId != null,
    isActive: true,
    isSystem: false,
  );
}

void main() {
  group('buildChartAccountTree', () {
    test('orders siblings by code', () {
      final accounts = [
        _account(id: 'b', code: '1202'),
        _account(id: 'a', code: '1201'),
      ];

      final tree = buildChartAccountTree(accounts);
      expect(tree, hasLength(2));
      expect(tree.first.account.id, 'a');
      expect(tree[1].account.id, 'b');
    });

    test('nests children under parent', () {
      final accounts = [
        _account(id: 'parent', code: '1201'),
        _account(id: 'child', code: '1201.0001', parentId: 'parent'),
      ];

      final tree = buildChartAccountTree(accounts);
      expect(tree, hasLength(1));
      expect(tree.first.children, hasLength(1));
      expect(tree.first.children.first.account.id, 'child');
    });

    test('promotes accounts with missing parents to roots', () {
      final accounts = [
        _account(id: 'orphan', code: '9999', parentId: 'missing'),
      ];

      final tree = buildChartAccountTree(accounts);
      expect(tree, hasLength(1));
      expect(tree.first.account.id, 'orphan');
    });

    test('does not recurse forever when data contains a cycle', () {
      final accounts = [
        _account(id: 'a', code: '1201', parentId: 'b'),
        _account(id: 'b', code: '1202', parentId: 'a'),
      ];

      final tree = buildChartAccountTree(accounts);
      expect(tree, hasLength(1));
      expect(tree.first.account.id, 'a');
      expect(tree.first.children.single.account.id, 'b');
      expect(tree.first.children.single.children, isEmpty);
    });
  });
}
