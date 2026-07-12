import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/domain/rental_collection_draft.dart';
import 'package:hs360/features/contracts/presentation/widgets/contract_rental_collection_dialog.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../accounting/fake_chart_account_repository.dart';
import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session(Set<String> permissions) {
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

Widget _wrap({
  required Locale locale,
  required AppSession session,
  required FakeContractRepository repo,
  required ContractDetail detail,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      contractRepositoryProvider.overrideWith((ref) => repo),
      chartAccountRepositoryProvider.overrideWith(
        (ref) => FakeChartAccountRepository(
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
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer(
        builder: (context, ref, _) {
          return ElevatedButton(
            onPressed: () => showContractRentalCollectionDialog(
              context,
              ref,
              detail: detail,
            ),
            child: const Text('open'),
          );
        },
      ),
    ),
  );
}

Set<String> _fullCollectPerms() => {
  'invoices.create_sales',
  'vouchers.create_receipt',
  'chart_of_accounts.view',
};

void main() {
  testWidgets('excludes covered months from eligible chips', (tester) async {
    final detail = sampleContractDetail(id: 'rental-1');
    final repo = FakeContractRepository(
      coveredMonthKeys: const ['2026-07-01'],
      collectionPreview: RentalCollectionPreview(
        contractId: 'rental-1',
        coverageMonths: const ['2026-08-01'],
        expectedCollectedAmount: Decimal.parse('120.000'),
      ),
    );

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('en'),
        session: _session(_fullCollectPerms()),
        repo: repo,
        detail: detail,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collect-month-2026-07-01')), findsNothing);
    expect(find.byKey(const Key('collect-month-2026-08-01')), findsOneWidget);
  });

  testWidgets('preview-only session hides confirm button', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final detail = sampleContractDetail(id: 'rental-1');
    final repo = FakeContractRepository(
      collectionPreview: RentalCollectionPreview(
        contractId: 'rental-1',
        coverageMonths: const ['2026-07-01'],
        expectedCollectedAmount: Decimal.parse('120.000'),
      ),
    );

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('en'),
        session: _session({'invoices.create_sales', 'chart_of_accounts.view'}),
        repo: repo,
        detail: detail,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.contractCollectConfirmAction), findsNothing);
    expect(find.byKey(const Key('collect-rental-submit')), findsNothing);
  });

  testWidgets(
    'success shows view invoice and receipt actions without uuid labels',
    (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final detail = sampleContractDetail(id: 'rental-1');
      final repo = FakeContractRepository(
        collectionPreview: RentalCollectionPreview(
          contractId: 'rental-1',
          coverageMonths: const ['2026-07-01'],
          expectedCollectedAmount: Decimal.parse('120.000'),
        ),
        collectionResult: RentalCollectionResult(
          invoiceId: 'inv-hidden',
          voucherId: 'vch-hidden',
          coverageMonths: const ['2026-07-01'],
          collectedAmount: Decimal.parse('120.000'),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          locale: const Locale('en'),
          session: _session(_fullCollectPerms()),
          repo: repo,
          detail: detail,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('collect-rental-submit')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.contractCollectSuccess), findsOneWidget);
      expect(find.text(l10n.contractCollectViewInvoice), findsOneWidget);
      expect(find.text(l10n.contractCollectViewReceipt), findsOneWidget);
      expect(find.text('inv-hidden'), findsNothing);
      expect(find.text('vch-hidden'), findsNothing);
    },
  );

  testWidgets('arabic collection dialog uses localized labels', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final detail = sampleContractDetail(id: 'rental-1');

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('ar'),
        session: _session(_fullCollectPerms()),
        repo: FakeContractRepository(
          collectionPreview: RentalCollectionPreview(
            contractId: 'rental-1',
            coverageMonths: const ['2026-07-01'],
            expectedCollectedAmount: Decimal.parse('120.000'),
          ),
        ),
        detail: detail,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.contractCollectRentalTitle), findsOneWidget);
    expect(find.text(l10n.contractCollectCoverageMonths), findsOneWidget);
  });

  testWidgets(
    'completed rental still offers collect action for in-range month',
    (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final detail = ContractDetail(
        id: 'closed-rental',
        type: ContractType.rental,
        status: ContractStatus.completed,
        startDate: DateTime(2026, 1, 1),
        closedAt: DateTime(2026, 3, 20),
        monthlyRentalValue: Decimal.parse('100'),
      );

      await tester.pumpWidget(
        _wrap(
          locale: const Locale('en'),
          session: _session(_fullCollectPerms()),
          repo: FakeContractRepository(
            collectionPreview: RentalCollectionPreview(
              contractId: 'closed-rental',
              coverageMonths: const ['2026-03-01'],
              expectedCollectedAmount: Decimal.parse('100.000'),
            ),
          ),
          detail: detail,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collect-month-2026-03-01')), findsOneWidget);
      expect(find.byKey(const Key('collect-month-2026-04-01')), findsNothing);
      expect(find.text(l10n.contractCollectNoEligibleMonths), findsNothing);
    },
  );
}
