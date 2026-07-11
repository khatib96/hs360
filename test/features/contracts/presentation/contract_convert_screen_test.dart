import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_pricing_preview.dart';
import 'package:hs360/features/contracts/presentation/contract_convert_draft_builder.dart';
import 'package:hs360/features/contracts/presentation/contract_convert_screen.dart';
import 'package:hs360/features/contracts/presentation/contract_display_helpers.dart';
import 'package:hs360/features/invoices/presentation/widgets/invoice_sheet.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({
  Set<String> permissions = const {'contracts.convert_trial'},
}) {
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
  required AppSession session,
  required FakeContractRepository repo,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      contractRepositoryProvider.overrideWith((ref) => repo),
      localeProvider.overrideWithValue(const Locale('en')),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1280, 800)),
        child: ContractConvertScreen(contractId: 'trial-old'),
      ),
    ),
  );
}

void main() {
  testWidgets('shows conversion start date and unified products table', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final today = normalizeConversionStartDate();
    final repo = FakeContractRepository(
      detailById: {
        'trial-old': sampleTrialDetail(
          id: 'trial-old',
          startDate: DateTime(2023, 6, 1),
        ),
      },
    );

    await tester.pumpWidget(_wrap(session: _session(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.contractFieldConversionStartDate), findsOneWidget);
    expect(find.text(formatContractDate(today)), findsWidgets);
    expect(find.text(formatContractDate(DateTime(2023, 6, 1))), findsNothing);
    expect(find.byKey(const Key('contract-products-table')), findsOneWidget);
    expect(find.text('Device A'), findsOneWidget);
    expect(find.text('Oil A'), findsOneWidget);
    expect(find.textContaining('DEV-001'), findsOneWidget);
    expect(find.textContaining('Devices'), findsOneWidget);
  });

  testWidgets('hides financial details without cost permissions', (
    tester,
  ) async {
    final repo = FakeContractRepository(
      detailById: {'trial-old': sampleTrialDetail(id: 'trial-old')},
      pricingPreview: ContractPricingPreview(
        monthlyRentalValue: Decimal.fromInt(120),
        totalMonthlyCost: Decimal.fromInt(25),
        expectedMonthlyProfit: Decimal.fromInt(95),
        assetLines: [
          ContractPreviewAssetLine(
            productId: 'prod-1',
            sourceUnitCost: Decimal.fromInt(60),
            monthlyCost: Decimal.fromInt(25),
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(session: _session(), repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contract-convert-monthly-rental')),
      '120',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('contract-convert-financial-details')),
      findsNothing,
    );
  });

  testWidgets('shows permission-gated cost breakdown for authorized user', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeContractRepository(
      detailById: {'trial-old': sampleTrialDetail(id: 'trial-old')},
      pricingPreview: ContractPricingPreview(
        monthlyRentalValue: Decimal.fromInt(120),
        totalMonthlyCost: Decimal.fromInt(25),
        expectedMonthlyProfit: Decimal.fromInt(95),
        assetLines: [
          ContractPreviewAssetLine(
            productId: 'prod-1',
            sourceUnitCost: Decimal.fromInt(60),
            monthlyCost: Decimal.fromInt(25),
          ),
        ],
        consumableLines: [
          ContractPreviewConsumableLine(
            productId: 'oil-1',
            qtyPerRefill: Decimal.fromInt(500),
            sourceUnitCost: Decimal.parse('0.02'),
            monthlyCost: Decimal.fromInt(10),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(
          permissions: const {
            'contracts.convert_trial',
            'contracts.field.snapshot_device_cost',
            'contracts.field.snapshot_oil_cost',
            'contracts.field.snapshot_total_cost',
            'contracts.field.snapshot_profit',
          },
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('contract-convert-monthly-rental')),
      '120',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final sheet = find.byType(InvoiceSheet);
    await tester.drag(
      find.descendant(of: sheet, matching: find.byType(ListView)),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.contractFinancialDetails));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('contract-convert-cost-breakdown')),
      findsOneWidget,
    );
    expect(find.text(l10n.contractFieldNetMonthlyProfit), findsOneWidget);
    expect(find.text(l10n.contractFieldTotalMonthlyCost), findsOneWidget);
  });
}
