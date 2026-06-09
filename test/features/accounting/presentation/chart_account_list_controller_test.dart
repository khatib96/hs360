import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/accounting_exception.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account_form_state.dart';
import 'package:hs360/features/accounting/presentation/chart_account_list_controller.dart';
import 'package:hs360/features/accounting/presentation/chart_account_submit_result.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';

import '../fake_chart_account_repository.dart';

AppSession _session({
  Set<String> permissions = const {'chart_of_accounts.view'},
}) {
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

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}

ProviderContainer _container(
  FakeChartAccountRepository repo, {
  Set<String> permissions = const {'chart_of_accounts.view'},
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => TestAuthController(_session(permissions: permissions)),
      ),
      chartAccountRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

void main() {
  group('ChartAccountListController', () {
    test('single fetch on refresh', () async {
      final repo = FakeChartAccountRepository(accounts: [sampleChartAccount()]);
      final container = _container(repo);
      addTearDown(container.dispose);

      await container
          .read(chartAccountListControllerProvider.notifier)
          .refresh();

      expect(repo.fetchCount, 1);
      expect(
        container.read(chartAccountListControllerProvider).allAccounts,
        hasLength(1),
      );
    });

    test('setup issues from unfiltered allAccounts', () async {
      final repo = FakeChartAccountRepository(
        accounts: [
          sampleChartAccount(
            id: 'ar',
            code: '1201',
            type: AccountType.asset,
            nameEn: 'AR',
          ),
        ],
      );
      final container = _container(repo);
      addTearDown(container.dispose);

      await container
          .read(chartAccountListControllerProvider.notifier)
          .refresh();
      container
          .read(chartAccountListControllerProvider.notifier)
          .setType(AccountType.asset);

      final state = container.read(chartAccountListControllerProvider);
      expect(state.setupIssues.missingArParent, isFalse);
      expect(state.setupIssues.missingApParent, isTrue);
      expect(repo.fetchCount, 1);
    });

    test('submitCreate returns validation failure without mutation', () async {
      final repo = FakeChartAccountRepository(accounts: const []);
      final container = _container(
        repo,
        permissions: {'chart_of_accounts.view', 'chart_of_accounts.create'},
      );
      addTearDown(container.dispose);

      await container
          .read(chartAccountListControllerProvider.notifier)
          .refresh();

      final result = await container
          .read(chartAccountListControllerProvider.notifier)
          .submitCreate(
            const ChartAccountFormState(
              code: '',
              nameAr: '',
              nameEn: '',
              type: AccountType.expense,
            ),
          );

      expect(result, isA<ChartAccountSubmitFailure>());
      final failure = result as ChartAccountSubmitFailure;
      expect(failure.errorCodes.length, greaterThan(1));
      expect(repo.lastCreateInput, isNull);
    });

    test('submitCreate success refreshes list', () async {
      final repo = FakeChartAccountRepository(accounts: const []);
      final container = _container(
        repo,
        permissions: {'chart_of_accounts.view', 'chart_of_accounts.create'},
      );
      addTearDown(container.dispose);

      await container
          .read(chartAccountListControllerProvider.notifier)
          .refresh();

      final result = await container
          .read(chartAccountListControllerProvider.notifier)
          .submitCreate(
            const ChartAccountFormState(
              code: '4000',
              nameAr: 'مصروف',
              nameEn: 'Expense',
              type: AccountType.expense,
            ),
          );

      expect(result, isA<ChartAccountSubmitSuccess>());
      expect(repo.lastCreateInput?.code, '4000');
      expect(repo.fetchCount, 2);
    });

    test('deactivate denied without permission', () async {
      final repo = FakeChartAccountRepository(accounts: [sampleChartAccount()]);
      final container = _container(repo);
      addTearDown(container.dispose);

      await container
          .read(chartAccountListControllerProvider.notifier)
          .refresh();

      final code = await container
          .read(chartAccountListControllerProvider.notifier)
          .deactivateAccount('acct-1');

      expect(code, AccountingException.permissionDenied);
    });
  });
}
