import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/presentation/contract_detail_screen.dart';
import 'package:hs360/features/invoices/presentation/widgets/invoice_sheet.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _managerSession() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: true,
      permissions: {
        'contracts.view',
        'contracts.field.snapshot_device_cost',
        'contracts.field.snapshot_oil_cost',
        'contracts.field.snapshot_total_cost',
        'contracts.field.snapshot_profit',
      },
    ),
  );
}

Widget _wrap({
  required Locale locale,
  required AppSession session,
  required FakeContractRepository repo,
  required String contractId,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      contractRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1280, 800)),
        child: ContractDetailScreen(contractId: contractId),
      ),
    ),
  );
}

void main() {
  testWidgets('shows not-found copy for missing contract', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('en'),
        session: _managerSession(),
        repo: FakeContractRepository(),
        contractId: 'missing',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.financeErrorNotFound), findsOneWidget);
    expect(find.textContaining('validation'), findsNothing);
  });

  testWidgets('manager detail shows an authorized financial details section', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeContractRepository(
      detailById: {
        'c-1': sampleContractDetail(
          id: 'c-1',
          totalContractValue: Decimal.parse('1440.000'),
          billingDay: 5,
          refillDay: 10,
        ),
      },
    );

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('en'),
        session: _managerSession(),
        repo: repo,
        contractId: 'c-1',
      ),
    );
    await tester.pumpAndSettle();

    final sheet = find.byType(InvoiceSheet);
    expect(find.byKey(const Key('contract-products-table')), findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.contractSectionProducts),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.contractSectionValueSummary),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.contractSectionUpcomingSchedule),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.contractSectionHistory),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.contractFieldMonthlyRentalValue), findsWidgets);
    expect(find.text(l10n.contractFieldTotalContractValue), findsWidgets);
    expect(find.text('Device A'), findsOneWidget);
    expect(find.text('Oil A'), findsOneWidget);
    expect(find.textContaining('DEV-001'), findsOneWidget);
    expect(find.textContaining('Devices'), findsOneWidget);
    expect(find.textContaining('Oils'), findsOneWidget);

    expect(find.text(l10n.contractSectionLifecycle), findsNothing);
    expect(find.text(l10n.contractSectionPricingSnapshot), findsNothing);
    expect(
      find.byKey(const Key('contract-detail-financial-details')),
      findsOneWidget,
    );
    await tester.drag(
      find.descendant(of: sheet, matching: find.byType(ListView)),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.contractFinancialDetails));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contract-cost-breakdown')), findsOneWidget);
    expect(find.text(l10n.contractFieldUnitCost), findsNWidgets(2));
    expect(find.text(l10n.contractFieldMonthlyCost), findsNWidgets(2));
    expect(find.text(l10n.contractFieldTotalMonthlyCost), findsOneWidget);
    expect(find.text(l10n.contractFieldNetMonthlyProfit), findsOneWidget);
    expect(find.text(l10n.contractFieldDeviceMonthlyCost), findsNothing);
    expect(find.text(l10n.contractFieldOilMonthlyCost), findsNothing);
    expect(find.text('Device A'), findsNWidgets(2));
    expect(find.text('Oil A'), findsNWidgets(2));
    expect(find.text(l10n.contractScheduleEmpty), findsOneWidget);
    expect(find.text(l10n.contractNextVisit), findsNothing);
    expect(find.text(l10n.contractNextPayment), findsNothing);
  });

  testWidgets('arabic detail uses schedule and history labels', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final repo = FakeContractRepository(
      detailById: {'c-1': sampleContractDetail(id: 'c-1')},
    );

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('ar'),
        session: _managerSession(),
        repo: repo,
        contractId: 'c-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.contractSectionUpcomingSchedule), findsOneWidget);
    expect(find.text(l10n.contractSectionHistory), findsOneWidget);
    expect(find.text('دورة الحياة'), findsNothing);
  });
}
