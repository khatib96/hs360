import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/presentation/contract_list_controller.dart';

import '../fake_contract_repository.dart';

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

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

void main() {
  group('ContractListController', () {
    test('loads contracts for permitted user', () async {
      final repo = FakeContractRepository(summaries: [sampleContractSummary()]);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          contractRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(contractListControllerProvider.notifier).refresh();

      final state = container.read(contractListControllerProvider);
      expect(state.contracts, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(repo.listCallCount, greaterThan(0));
    });

    test('fetch error sets error code', () async {
      final repo = FakeContractRepository(
        fetchError: const FinanceException(code: FinanceException.unknown),
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

      await container.read(contractListControllerProvider.notifier).refresh();

      expect(
        container.read(contractListControllerProvider).errorCode,
        FinanceException.unknown,
      );
    });
  });
}
