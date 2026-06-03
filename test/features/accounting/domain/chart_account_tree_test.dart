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

    test('builds real CoA hierarchy with five roots and nested system leaves', () {
      ChartAccount root({
        required String id,
        required String code,
        required AccountType type,
        required String nameEn,
      }) {
        return ChartAccount(
          id: id,
          tenantId: 't',
          code: code,
          nameAr: 'جذر',
          nameEn: nameEn,
          type: type,
          isSubaccount: false,
          isActive: true,
          isSystem: true,
        );
      }

      ChartAccount leaf({
        required String id,
        required String code,
        required String parentId,
        required AccountType type,
        required String nameEn,
      }) {
        return ChartAccount(
          id: id,
          tenantId: 't',
          code: code,
          nameAr: 'حساب',
          nameEn: nameEn,
          type: type,
          parentId: parentId,
          isSubaccount: false,
          isActive: true,
          isSystem: true,
        );
      }

      final accounts = [
        root(id: 'assets', code: '1000', type: AccountType.asset, nameEn: 'Assets'),
        root(
          id: 'liab',
          code: '2000',
          type: AccountType.liability,
          nameEn: 'Liabilities',
        ),
        root(id: 'equity', code: '3000', type: AccountType.equity, nameEn: 'Equity'),
        root(id: 'rev', code: '4000', type: AccountType.income, nameEn: 'Revenue'),
        root(id: 'exp', code: '5000', type: AccountType.expense, nameEn: 'Expenses'),
        leaf(
          id: 'cash',
          code: '1101',
          parentId: 'assets',
          type: AccountType.asset,
          nameEn: 'Cash on hand',
        ),
        leaf(
          id: 'bank',
          code: '1102',
          parentId: 'assets',
          type: AccountType.asset,
          nameEn: 'Main bank',
        ),
        leaf(
          id: 'ar',
          code: '1201',
          parentId: 'assets',
          type: AccountType.asset,
          nameEn: 'Accounts receivable',
        ),
        leaf(
          id: 'inv',
          code: '1301',
          parentId: 'assets',
          type: AccountType.asset,
          nameEn: 'Inventory',
        ),
        leaf(
          id: 'ap',
          code: '2101',
          parentId: 'liab',
          type: AccountType.liability,
          nameEn: 'Accounts payable',
        ),
        leaf(
          id: 'sales',
          code: '4101',
          parentId: 'rev',
          type: AccountType.income,
          nameEn: 'Sales revenue',
        ),
        leaf(
          id: 'cogs',
          code: '5101',
          parentId: 'exp',
          type: AccountType.expense,
          nameEn: 'Cost of goods sold',
        ),
        leaf(
          id: 'gen',
          code: '6101',
          parentId: 'exp',
          type: AccountType.expense,
          nameEn: 'General expenses',
        ),
      ];

      final tree = buildChartAccountTree(accounts);
      expect(tree, hasLength(5));
      expect(tree.map((n) => n.account.code).toList(),
          ['1000', '2000', '3000', '4000', '5000']);

      final assetsNode = tree.firstWhere((n) => n.account.code == '1000');
      expect(assetsNode.children.map((n) => n.account.code).toList(),
          ['1101', '1102', '1201', '1301']);

      final equityNode = tree.firstWhere((n) => n.account.code == '3000');
      expect(equityNode.children, isEmpty);

      final expensesNode = tree.firstWhere((n) => n.account.code == '5000');
      expect(expensesNode.children.map((n) => n.account.code).toList(),
          ['5101', '6101']);
    });
  });
}
