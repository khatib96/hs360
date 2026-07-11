import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/closure_draft.dart';
import 'package:hs360/features/contracts/domain/contract_return_condition.dart';
import 'package:hs360/features/contracts/presentation/contract_lifecycle_controller.dart';

import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'contracts.close'},
    ),
  );
}

void main() {
  test('lifecycle submit reuses idempotency key until cleared', () async {
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

    final notifier = container.read(
      contractLifecycleControllerProvider.notifier,
    );
    final draft = ClosureDraft(
      contractId: 'rental-1',
      closeDate: DateTime(2026, 7, 12),
      closureType: ContractClosureType.normal,
      returnCondition: ContractReturnCondition.availableUsed,
      closeReason: 'Completed',
    );
    final detail = sampleContractDetail(id: 'rental-1');

    final first = await notifier.closeContract(draft: draft, detail: detail);
    final firstKey = repo.lastIdempotencyKey;
    expect(first, isNull);
    expect(firstKey, isNotNull);

    final second = await notifier.closeContract(draft: draft, detail: detail);
    expect(second, isNull);
    expect(repo.lastIdempotencyKey, firstKey);

    notifier.clearTransientState();
    await notifier.closeContract(draft: draft, detail: detail);
    expect(repo.lastIdempotencyKey, isNot(firstKey));
  });
}
