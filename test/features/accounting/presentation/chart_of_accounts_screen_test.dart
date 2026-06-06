import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/presentation/chart_of_accounts_screen.dart';
import 'package:hs360/features/accounting/presentation/widgets/chart_account_form_dialog.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_chart_account_repository.dart';

AppSession _session({
  Set<String> permissions = const {'chart_of_accounts.view'},
}) {
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

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}

Widget buildScreen({
  required AppSession appSession,
  required FakeChartAccountRepository repo,
  Locale locale = const Locale('en'),
  Size size = const Size(1600, 900),
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(appSession)),
      chartAccountRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(size: size),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const ChartOfAccountsScreen(),
    ),
  );
}

void main() {
  testWidgets('tree screen renders hierarchy', (tester) async {
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(
          id: 'ar',
          code: '1201',
          type: AccountType.asset,
          nameEn: 'Accounts Receivable',
          isSystem: true,
        ),
        sampleChartAccount(
          id: 'cust',
          code: '1201.0001',
          parentId: 'ar',
          type: AccountType.asset,
          nameEn: 'Customer A',
          relatedEntityId: 'c1',
          relatedEntityTable: 'customers',
        ),
        sampleChartAccount(
          id: '2101',
          code: '2101',
          type: AccountType.liability,
          nameEn: 'Accounts Payable',
          isSystem: true,
        ),
      ],
    );

    await tester.pumpWidget(buildScreen(appSession: _session(), repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expand all'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart-of-accounts-screen')), findsOneWidget);
    expect(find.text('1201'), findsOneWidget);
    expect(find.text('1201.0001'), findsOneWidget);
  });

  testWidgets('setup banner shows only missing AP when AR valid', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(
          id: 'ar',
          code: '1201',
          type: AccountType.asset,
          nameEn: 'AR',
          isSystem: true,
        ),
      ],
    );

    await tester.pumpWidget(buildScreen(appSession: _session(), repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chart-account-setup-ar-missing')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('chart-account-setup-ap-missing')),
      findsOneWidget,
    );
    expect(find.text(l10n.chartAccountSetupApMissing), findsOneWidget);
  });

  testWidgets('setup banner stable when type filter applied', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(
          id: 'ar',
          code: '1201',
          type: AccountType.asset,
          nameEn: 'AR',
          isSystem: true,
        ),
      ],
    );

    await tester.pumpWidget(buildScreen(appSession: _session(), repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AccountType?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asset').last);
    await tester.pumpAndSettle();

    expect(find.text(l10n.chartAccountSetupApMissing), findsOneWidget);
    expect(
      find.byKey(const Key('chart-account-setup-ar-missing')),
      findsNothing,
    );
  });

  testWidgets('create button hidden without create permission', (tester) async {
    final repo = FakeChartAccountRepository(accounts: [sampleChartAccount()]);
    await tester.pumpWidget(buildScreen(appSession: _session(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart-account-create-button')), findsNothing);
  });

  testWidgets('create button visible with create permission', (tester) async {
    final repo = FakeChartAccountRepository(accounts: [sampleChartAccount()]);
    await tester.pumpWidget(
      buildScreen(
        appSession: _session(
          permissions: {'chart_of_accounts.view', 'chart_of_accounts.create'},
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chart-account-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('protected accounts have no action menu', (tester) async {
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(
          id: 'sys',
          code: '1201',
          type: AccountType.asset,
          isSystem: true,
          nameEn: 'System',
        ),
        sampleChartAccount(
          id: 'cust',
          code: '1201.0001',
          parentId: 'sys',
          type: AccountType.asset,
          relatedEntityId: 'c1',
          relatedEntityTable: 'customers',
          nameEn: 'Customer',
        ),
      ],
    );

    await tester.pumpWidget(
      buildScreen(
        appSession: _session(
          permissions: {
            'chart_of_accounts.view',
            'chart_of_accounts.edit',
            'chart_of_accounts.delete',
          },
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart-account-actions-sys')), findsNothing);
    expect(find.byKey(const Key('chart-account-actions-cust')), findsNothing);
  });

  testWidgets('manual account shows edit menu when permitted', (tester) async {
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(id: 'manual', code: '5000', nameEn: 'Manual'),
      ],
    );

    await tester.pumpWidget(
      buildScreen(
        appSession: _session(
          permissions: {'chart_of_accounts.view', 'chart_of_accounts.edit'},
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chart-account-actions-manual')),
      findsOneWidget,
    );
  });

  testWidgets('edit form has read-only code and no parent field', (
    tester,
  ) async {
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(id: 'manual', code: '5000', nameEn: 'Manual'),
      ],
    );

    await tester.pumpWidget(
      buildScreen(
        appSession: _session(
          permissions: {'chart_of_accounts.view', 'chart_of_accounts.edit'},
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chart-account-actions-manual')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit account'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chart-account-code-readonly')),
      findsOneWidget,
    );
    expect(find.text('Parent account'), findsNothing);
  });

  testWidgets('dialog stays open on validation failure', (tester) async {
    final repo = FakeChartAccountRepository(accounts: const []);

    await tester.pumpWidget(
      buildScreen(
        appSession: _session(
          permissions: {'chart_of_accounts.view', 'chart_of_accounts.create'},
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chart-account-create-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(ChartAccountFormDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChartAccountFormDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('category roots auto-expand and nest children with indentation', (
    tester,
  ) async {
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(
          id: 'assets',
          code: '1000',
          type: AccountType.asset,
          nameEn: 'Assets',
          isSystem: true,
        ),
        sampleChartAccount(
          id: 'cash',
          code: '1101',
          parentId: 'assets',
          type: AccountType.asset,
          nameEn: 'Cash on hand',
          isSystem: true,
        ),
        sampleChartAccount(
          id: 'liab',
          code: '2000',
          type: AccountType.liability,
          nameEn: 'Liabilities',
          isSystem: true,
        ),
        sampleChartAccount(
          id: 'ap',
          code: '2101',
          parentId: 'liab',
          type: AccountType.liability,
          nameEn: 'Accounts Payable',
          isSystem: true,
        ),
        sampleChartAccount(
          id: 'equity',
          code: '3000',
          type: AccountType.equity,
          nameEn: 'Equity',
          isSystem: true,
        ),
      ],
    );

    await tester.pumpWidget(buildScreen(appSession: _session(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart-account-tree-view')), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('1101'), findsOneWidget);
    expect(find.text('2101'), findsOneWidget);

    final rootTile = tester.widget<ListTile>(
      find.byKey(const Key('chart-account-tile-assets')),
    );
    final childTile = tester.widget<ListTile>(
      find.byKey(const Key('chart-account-tile-cash')),
    );
    final rootStart = rootTile.contentPadding!.resolve(TextDirection.ltr).left;
    final childStart = childTile.contentPadding!
        .resolve(TextDirection.ltr)
        .left;
    expect(childStart, greaterThan(rootStart));

    final collapseLiab = find.descendant(
      of: find.byKey(const Key('chart-account-tile-liab')),
      matching: find.byType(IconButton),
    );
    await tester.tap(collapseLiab);
    await tester.pumpAndSettle();
    expect(find.text('2101'), findsNothing);
  });

  testWidgets('chart tree fits a narrow Arabic viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeChartAccountRepository(
      accounts: [
        sampleChartAccount(
          id: 'assets',
          code: '1000',
          type: AccountType.asset,
          nameAr: 'الأصول',
          isSystem: true,
        ),
      ],
    );

    await tester.pumpWidget(
      buildScreen(
        appSession: _session(
          permissions: {'chart_of_accounts.view', 'chart_of_accounts.create'},
        ),
        repo: repo,
        locale: const Locale('ar'),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('chart-account-create-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chart-account-tree-view')), findsOneWidget);
  });
}
