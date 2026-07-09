import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/chart_account.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/journal/data/cash_bank_repository.dart';
import 'package:hs360/features/journal/presentation/cash_bank_activity_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../accounting/fake_chart_account_repository.dart';
import '../fake_cash_bank_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({
  Set<String> permissions = const {'cash_bank.view', 'chart_of_accounts.view'},
}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'ar',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

Widget _wrap({
  required AppSession session,
  required FakeCashBankRepository cashRepo,
  List<ChartAccount> accounts = const [],
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      cashBankRepositoryProvider.overrideWith((ref) => cashRepo),
      chartAccountRepositoryProvider.overrideWith(
        (ref) => FakeChartAccountRepository(accounts: accounts),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const CashBankActivityScreen(),
    ),
  );
}

void main() {
  testWidgets('prompts to select account before activity loads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        session: _session(),
        cashRepo: FakeCashBankRepository(),
        accounts: [
          sampleChartAccount(
            id: 'parent',
            code: '1000',
            type: AccountType.asset,
            nameEn: 'Assets',
          ),
          sampleChartAccount(
            id: 'cash-1',
            code: '1100',
            parentId: 'parent',
            type: AccountType.asset,
            nameEn: 'Cash',
            nameAr: 'نقد',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر حساب نقد أو بنك'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
