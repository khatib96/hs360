import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/domain/voucher_status.dart';
import 'package:hs360/features/vouchers/presentation/voucher_detail_controller.dart';

import '../fake_voucher_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

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

Future<void> _waitForDetail(ProviderContainer container, String id) async {
  await container.read(authControllerProvider.future);
  await container.read(voucherDetailControllerProvider(id).notifier).load(id);
  for (var i = 0; i < 50; i++) {
    final state = container.read(voucherDetailControllerProvider(id));
    if (!state.isLoading) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for voucher detail');
}

void main() {
  group('VoucherDetailController', () {
    test('loads detail for permitted user', () async {
      final repo = FakeVoucherRepository(
        detailById: {'v-1': sampleVoucherDetail()},
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

      await _waitForDetail(container, 'v-1');

      final state = container.read(voucherDetailControllerProvider('v-1'));
      expect(state.detail?.id, 'v-1');
      expect(state.errorCode, isNull);
    });

    test('denies load without vouchers.view', () async {
      final repo = FakeVoucherRepository(
        detailById: {'v-1': sampleVoucherDetail()},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session(permissions: {})),
          ),
          voucherRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'v-1');

      expect(
        container.read(voucherDetailControllerProvider('v-1')).errorCode,
        FinanceException.permissionDenied,
      );
    });

    test('cancel requires vouchers.cancel permission', () async {
      final repo = FakeVoucherRepository(
        detailById: {
          'v-1': sampleVoucherDetail(status: VoucherStatus.confirmed),
        },
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

      await _waitForDetail(container, 'v-1');

      final code = await container
          .read(voucherDetailControllerProvider('v-1').notifier)
          .cancel('Customer dispute');

      expect(code, FinanceException.permissionDenied);
      expect(repo.lastCancelReason, isNull);
    });

    test('cancel requires non-empty reason', () async {
      final repo = FakeVoucherRepository(
        detailById: {
          'v-1': sampleVoucherDetail(status: VoucherStatus.confirmed),
        },
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'vouchers.view', 'vouchers.cancel'}),
            ),
          ),
          voucherRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'v-1');

      final code = await container
          .read(voucherDetailControllerProvider('v-1').notifier)
          .cancel('   ');

      expect(code, FinanceException.validationCancellationReasonRequired);
      expect(repo.lastCancelReason, isNull);
    });

    test('cancel succeeds with permission and valid reason', () async {
      final repo = FakeVoucherRepository(
        detailById: {
          'v-1': sampleVoucherDetail(status: VoucherStatus.confirmed),
        },
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'vouchers.view', 'vouchers.cancel'}),
            ),
          ),
          voucherRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'v-1');

      final code = await container
          .read(voucherDetailControllerProvider('v-1').notifier)
          .cancel('Customer dispute');

      expect(code, isNull);
      expect(repo.lastCancelVoucherId, 'v-1');
      expect(repo.lastCancelReason, 'Customer dispute');
    });
  });
}
