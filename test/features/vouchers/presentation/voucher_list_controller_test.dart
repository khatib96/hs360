import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/presentation/voucher_list_controller.dart';

import '../fake_voucher_repository.dart';

AppSession _session({Set<String> permissions = const {'vouchers.view'}}) {
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

void main() {
  group('VoucherListController', () {
    test('loads vouchers for permitted user', () async {
      final repo = FakeVoucherRepository(vouchers: [sampleVoucherSummary()]);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          voucherRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(voucherListControllerProvider.notifier).refresh();

      final state = container.read(voucherListControllerProvider);
      expect(state.vouchers, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(repo.lastFilters, isNotNull);
    });

    test('fetch error sets error code', () async {
      final repo = FakeVoucherRepository(
        fetchError: const FinanceException(code: FinanceException.unknown),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          voucherRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(voucherListControllerProvider.notifier).refresh();

      expect(
        container.read(voucherListControllerProvider).errorCode,
        FinanceException.unknown,
      );
    });
  });
}
