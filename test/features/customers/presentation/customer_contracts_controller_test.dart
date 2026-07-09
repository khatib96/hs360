import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_summary.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/customers/presentation/customer_contracts_controller.dart';

import '../../contracts/fake_contract_repository.dart';

void main() {
  AppSession session({Set<String> permissions = const {}}) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: 'user',
      displayName: 'Test User',
      preferredLocale: 'en',
      permissions: AppPermissions(isManager: false, permissions: permissions),
    );
  }

  ProviderContainer container({
    required FakeContractRepository repo,
    required AppSession appSession,
  }) {
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(appSession),
        ),
        contractRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
  }

  test('load marks prepared when list stub is unavailable', () async {
    final repo = FakeContractRepository(
      fetchError: const FinanceException(code: FinanceException.notAvailable),
    );
    final c = container(
      repo: repo,
      appSession: session(permissions: {'contracts.view'}),
    );
    addTearDown(c.dispose);

    await c.read(customerContractsControllerProvider('cust-1').notifier).load();

    final state = c.read(customerContractsControllerProvider('cust-1'));
    expect(state.listUnavailable, isTrue);
    expect(state.hasLoaded, isTrue);
    expect(state.permissionDenied, isFalse);
  });

  test('load returns customer-scoped rows from fake repository', () async {
    final repo = FakeContractRepository(
      summaries: [
        sampleContractSummary(id: 'c-1'),
        ContractSummary(
          id: 'c-2',
          contractNumber: 'CON-002',
          type: ContractType.rental,
          status: ContractStatus.active,
          startDate: DateTime(2026, 7, 1),
          customerId: 'cust-2',
        ),
      ],
    );
    final c = container(
      repo: repo,
      appSession: session(permissions: {'contracts.view'}),
    );
    addTearDown(c.dispose);

    await c.read(customerContractsControllerProvider('cust-1').notifier).load();

    final state = c.read(customerContractsControllerProvider('cust-1'));
    expect(state.contracts, hasLength(1));
    expect(state.contracts.first.id, 'c-1');
    expect(repo.listCallCount, 1);
  });

  test('permission denied without contracts.view', () async {
    final repo = FakeContractRepository();
    final c = container(repo: repo, appSession: session());
    addTearDown(c.dispose);

    await c.read(customerContractsControllerProvider('cust-1').notifier).load();

    final state = c.read(customerContractsControllerProvider('cust-1'));
    expect(state.permissionDenied, isTrue);
    expect(repo.listCallCount, 0);
  });
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
