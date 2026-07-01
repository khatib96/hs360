import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/journal/data/cash_bank_repository.dart';
import 'package:hs360/features/journal/presentation/cash_bank_activity_controller.dart';

import '../fake_cash_bank_repository.dart';

AppSession _session({Set<String> permissions = const {'cash_bank.view'}}) {
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

Future<void> _waitForIdle(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final state = container.read(cashBankActivityControllerProvider);
    if (!state.isLoading && !state.isLoadingMore) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for cash bank controller');
}

void main() {
  group('CashBankActivityController', () {
    test('uses limit+1 and trims rows; hasMore when extra row returned', () async {
      final repo = FakeCashBankRepository(
        pages: [sampleCashBankPage(rowCount: 51)],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          cashBankRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cashBankActivityControllerProvider.notifier);
      notifier.setAccountId('acct-1');
      await _waitForIdle(container);

      final state = container.read(cashBankActivityControllerProvider);
      expect(repo.lastPage?.limit, CashBankActivityController.pageSize + 1);
      expect(state.page?.rows, hasLength(CashBankActivityController.pageSize));
      expect(state.hasMore, isTrue);
    });

    test('hasMore false when page fits within pageSize', () async {
      final repo = FakeCashBankRepository(
        pages: [sampleCashBankPage(rowCount: 3)],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          cashBankRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cashBankActivityControllerProvider.notifier);
      notifier.setAccountId('acct-1');
      await _waitForIdle(container);

      final state = container.read(cashBankActivityControllerProvider);
      expect(state.page?.rows, hasLength(3));
      expect(state.hasMore, isFalse);
    });
  });
}
