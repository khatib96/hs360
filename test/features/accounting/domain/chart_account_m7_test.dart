import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account_policy.dart';
import 'package:hs360/features/accounting/domain/chart_account_setup.dart';
import 'package:hs360/features/accounting/domain/chart_account_tree_filter.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

import '../fake_chart_account_repository.dart';

AppSession _session({Set<String> permissions = const {'chart_of_accounts.view'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

void main() {
  group('detectAccountingSetupIssues', () {
    test('missing both when empty', () {
      final issues = detectAccountingSetupIssues(const []);
      expect(issues.missingArParent, isTrue);
      expect(issues.missingApParent, isTrue);
    });

    test('valid 1201 asset active clears AR only', () {
      final issues = detectAccountingSetupIssues([
        sampleChartAccount(
          id: 'ar',
          code: '1201',
          type: AccountType.asset,
          nameEn: 'AR',
        ),
      ]);
      expect(issues.missingArParent, isFalse);
      expect(issues.missingApParent, isTrue);
    });

    test('1201 wrong type counts as missing AR', () {
      final issues = detectAccountingSetupIssues([
        sampleChartAccount(
          id: 'ar',
          code: '1201',
          type: AccountType.liability,
          nameEn: 'Wrong',
        ),
      ]);
      expect(issues.missingArParent, isTrue);
    });

    test('1201 inactive counts as missing AR', () {
      final issues = detectAccountingSetupIssues([
        sampleChartAccount(
          id: 'ar',
          code: '1201',
          type: AccountType.asset,
          isActive: false,
          nameEn: 'Inactive AR',
        ),
      ]);
      expect(issues.missingArParent, isTrue);
    });
  });

  group('deriveAccountBadges', () {
    test('manual and inactive badges', () {
      final badges = deriveAccountBadges(
        sampleChartAccount(isActive: false),
      );
      expect(badges, [
        ChartAccountBadgeKind.manual,
        ChartAccountBadgeKind.inactive,
      ]);
    });

    test('customer linked badge', () {
      final badges = deriveAccountBadges(
        sampleChartAccount(
          code: '1201.0001',
          relatedEntityId: 'c1',
          relatedEntityTable: 'customers',
          type: AccountType.asset,
        ),
      );
      expect(badges, [ChartAccountBadgeKind.customer]);
    });
  });

  group('deriveAllowedActions', () {
    test('manual account with edit permission', () {
      final actions = deriveAllowedActions(
        sampleChartAccount(),
        _session(permissions: {
          'chart_of_accounts.view',
          'chart_of_accounts.edit',
        }),
      );
      expect(actions.canEdit, isTrue);
      expect(actions.canDeactivate, isFalse);
    });

    test('system account has no edit or deactivate', () {
      final actions = deriveAllowedActions(
        sampleChartAccount(isSystem: true),
        _session(permissions: {
          'chart_of_accounts.view',
          'chart_of_accounts.edit',
          'chart_of_accounts.delete',
        }),
      );
      expect(actions.canEdit, isFalse);
      expect(actions.canDeactivate, isFalse);
    });

    test('customer linked account has no actions', () {
      final actions = deriveAllowedActions(
        sampleChartAccount(
          relatedEntityId: 'c1',
          relatedEntityTable: 'customers',
        ),
        _session(permissions: {
          'chart_of_accounts.view',
          'chart_of_accounts.edit',
          'chart_of_accounts.delete',
        }),
      );
      expect(actions.canEdit, isFalse);
      expect(actions.canDeactivate, isFalse);
    });
  });

  group('filterAccountsForTree', () {
    test('includes ancestor from allAccounts when child matches search', () {
      final parent = sampleChartAccount(
        id: 'p',
        code: '1201',
        type: AccountType.asset,
        nameEn: 'Parent',
      );
      final child = sampleChartAccount(
        id: 'c',
        code: '1201.0001',
        parentId: 'p',
        type: AccountType.asset,
        nameEn: 'Customer Child',
        relatedEntityId: 'cust',
        relatedEntityTable: 'customers',
      );
      final all = [parent, child];

      final filtered = filterAccountsForTree(
        allAccounts: all,
        visiblePredicate: (_) => true,
        search: 'Customer',
      );

      expect(filtered.map((a) => a.id), containsAll(['p', 'c']));
    });

    test('inactive-only filter includes active parent via ancestor walk', () {
      final parent = sampleChartAccount(
        id: 'p',
        code: '9000',
        nameEn: 'Active Parent',
      );
      final child = sampleChartAccount(
        id: 'c',
        code: '9001',
        parentId: 'p',
        nameEn: 'Inactive Child',
        isActive: false,
      );
      final all = [parent, child];

      final filtered = filterAccountsForTree(
        allAccounts: all,
        visiblePredicate: (a) => !a.isActive,
        search: null,
      );

      expect(filtered.map((a) => a.id), containsAll(['p', 'c']));
    });
  });
}
