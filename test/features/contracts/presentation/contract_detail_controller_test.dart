import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/presentation/contract_detail_controller.dart';

import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({Set<String> permissions = const {'contracts.view'}}) {
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
  await container.read(contractDetailControllerProvider(id).notifier).load(id);
  for (var i = 0; i < 50; i++) {
    final state = container.read(contractDetailControllerProvider(id));
    if (!state.isLoading) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for contract detail');
}

void main() {
  group('ContractDetailController', () {
    test('loads detail for permitted user', () async {
      final repo = FakeContractRepository(
        detailById: {'c-1': sampleContractDetail(id: 'c-1')},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'c-1');

      final state = container.read(contractDetailControllerProvider('c-1'));
      expect(state.detail?.id, 'c-1');
      expect(state.errorCode, isNull);
    });

    test('maps validation_failed to not-found state', () async {
      final repo = FakeContractRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'missing');

      final state = container.read(contractDetailControllerProvider('missing'));
      expect(state.detail, isNull);
      expect(state.isNotFound, isTrue);
      expect(state.errorCode, isNull);
    });

    test('denies load without contracts.view', () async {
      final repo = FakeContractRepository(
        detailById: {'c-1': sampleContractDetail(id: 'c-1')},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session(permissions: {})),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'c-1');

      final state = container.read(contractDetailControllerProvider('c-1'));
      expect(state.errorCode, FinanceException.permissionDenied);
    });
  });
}
