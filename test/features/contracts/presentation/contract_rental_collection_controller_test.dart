import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/rental_collection_draft.dart';
import 'package:hs360/features/contracts/presentation/contract_rental_collection_controller.dart';

import '../../accounting/fake_chart_account_repository.dart';
import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _collectSession({Set<String> permissions = const {}}) {
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

Set<String> _fullCollectPerms() => {
  'invoices.create_sales',
  'vouchers.create_receipt',
  'chart_of_accounts.view',
};

ProviderContainer _container({
  required AppSession session,
  required FakeContractRepository repo,
  FakeChartAccountRepository? chartRepo,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      contractRepositoryProvider.overrideWith((ref) => repo),
      chartAccountRepositoryProvider.overrideWith(
        (ref) =>
            chartRepo ??
            FakeChartAccountRepository(
              accounts: [
                sampleChartAccount(
                  id: 'cash-1101',
                  code: '1101',
                  type: AccountType.asset,
                  nameEn: 'Main Cash',
                ),
              ],
            ),
      ),
    ],
  );
}

void main() {
  test(
    'collection submit reuses idempotency key on retriable failure',
    () async {
      final repo = _RetryCollectRepository();
      final container = _container(
        session: _collectSession(permissions: _fullCollectPerms()),
        repo: repo,
      );
      addTearDown(container.dispose);

      final detail = sampleContractDetail(id: 'rental-1');
      final notifier = container.read(
        contractRentalCollectionControllerProvider('rental-1').notifier,
      );

      await notifier.initialize(detail);
      await notifier.submit(detail);
      final firstKey = repo.lastIdempotencyKey;
      expect(firstKey, isNotNull);

      await notifier.submit(detail);
      expect(repo.lastIdempotencyKey, firstKey);
      expect(repo.collectAttempts, 2);
    },
  );

  test(
    'collection rotates idempotency key when month selection changes',
    () async {
      final repo = FakeContractRepository();
      final container = _container(
        session: _collectSession(permissions: _fullCollectPerms()),
        repo: repo,
      );
      addTearDown(container.dispose);

      final detail = sampleContractDetail(
        id: 'rental-1',
        endDate: DateTime(2027, 7, 9),
      );
      final notifier = container.read(
        contractRentalCollectionControllerProvider('rental-1').notifier,
      );

      await notifier.initialize(detail);
      await notifier.submit(detail);
      final firstKey = repo.lastIdempotencyKey;

      final secondMonth = container
          .read(contractRentalCollectionControllerProvider('rental-1'))
          .eligibleMonthKeys
          .elementAt(1);
      notifier.toggleMonth(secondMonth, detail);
      await notifier.refreshPreview(detail);
      await notifier.submit(detail);

      expect(repo.lastIdempotencyKey, isNot(firstKey));
    },
  );

  test('preview-only session cannot submit collection', () async {
    final repo = FakeContractRepository(
      collectionPreview: RentalCollectionPreview(
        contractId: 'rental-1',
        coverageMonths: const ['2026-07-01'],
        expectedCollectedAmount: Decimal.parse('120.000'),
      ),
    );
    final container = _container(
      session: _collectSession(
        permissions: {'invoices.create_sales', 'chart_of_accounts.view'},
      ),
      repo: repo,
    );
    addTearDown(container.dispose);

    final detail = sampleContractDetail(id: 'rental-1');
    final notifier = container.read(
      contractRentalCollectionControllerProvider('rental-1').notifier,
    );

    await notifier.initialize(detail);
    final result = await notifier.submit(detail);

    expect(result, isNull);
    expect(repo.lastIdempotencyKey, isNull);
    expect(
      container
          .read(contractRentalCollectionControllerProvider('rental-1'))
          .errorCode,
      isNotNull,
    );
  });
}

class _RetryCollectRepository extends FakeContractRepository {
  int collectAttempts = 0;

  @override
  Future<RentalCollectionResult> collectRentalPayment(
    AppSession session,
    RentalCollectionDraft draft,
    String idempotencyKey,
  ) async {
    collectAttempts++;
    lastCollectionDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    if (collectAttempts == 1) {
      throw const FinanceException(code: FinanceException.unknown);
    }
    return collectionResult ??
        RentalCollectionResult(
          invoiceId: 'invoice-1',
          voucherId: 'voucher-1',
          coverageMonths: draft.coverageMonths,
          invoiceTotal: draft.amount,
          collectedAmount: draft.amount,
        );
  }
}
