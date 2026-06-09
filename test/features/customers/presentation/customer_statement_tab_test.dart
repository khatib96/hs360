import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/domain/customer_balance_summary.dart';
import 'package:hs360/features/customers/domain/customer_statement_row.dart';
import 'package:hs360/features/customers/presentation/customer_statement_controller.dart';
import 'package:hs360/features/customers/presentation/widgets/customer_statement_tab.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../fake_customer_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

Future<void> _loadStatement(WidgetTester tester) async {
  final element = tester.element(find.byType(CustomerStatementTab));
  final container = ProviderScope.containerOf(element);
  await container
      .read(customerStatementControllerProvider('cust-1').notifier)
      .load();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

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

  CustomerStatementRow sampleRow() {
    return CustomerStatementRow(
      entryDate: DateTime(2025, 6, 1),
      entryNumber: 'JE-001',
      source: JournalSource.manual,
      description: 'Opening',
      debit: Decimal.parse('100'),
      credit: Decimal.zero,
      runningBalance: Decimal.parse('100'),
    );
  }

  Widget buildTab({
    required AppSession appSession,
    required FakeCustomerRepository repo,
    String? pushedRoute,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(appSession),
        ),
        customerRepositoryProvider.overrideWith((ref) => repo),
        localeProvider.overrideWithValue(const Locale('en')),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const CustomerStatementTab(customerId: 'cust-1'),
            ),
            GoRoute(
              path: AppRoutes.documentPreview,
              builder: (context, state) {
                pushedRoute ??= state.uri.toString();
                return const Scaffold(body: Text('preview'));
              },
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('shows from and to date pickers with defaults', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCustomerRepository(
      statementRows: [sampleRow()],
      balanceSummary: CustomerBalanceSummary(
        debitTotal: Decimal.parse('100'),
        creditTotal: Decimal.zero,
        balance: Decimal.parse('100'),
      ),
    );

    await tester.pumpWidget(
      buildTab(
        appSession: session(permissions: {'customers.view_ledger'}),
        repo: repo,
      ),
    );
    await _loadStatement(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-statement-from-date')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-statement-to-date')), findsOneWidget);

    final fromButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('customer-statement-from-date')),
    );
    final toButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('customer-statement-to-date')),
    );
    final fromLabel = (fromButton.child as Text).data!;
    final toLabel = (toButton.child as Text).data!;
    expect(fromLabel, startsWith('${l10n.customerStatementFromDate}:'));
    expect(toLabel, startsWith('${l10n.customerStatementToDate}:'));

    final now = DateTime.now();
    final expectedFrom = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 364));
    final expectedTo = DateTime(now.year, now.month, now.day);
    final dateFormat = DateFormat.yMMMd('en');
    expect(fromLabel, contains(dateFormat.format(expectedFrom)));
    expect(toLabel, contains(dateFormat.format(expectedTo)));
  });

  testWidgets('preview navigates with selected date range', (tester) async {
    String? pushedRoute;
    final repo = FakeCustomerRepository(
      statementRows: [sampleRow()],
      balanceSummary: CustomerBalanceSummary(
        debitTotal: Decimal.parse('100'),
        creditTotal: Decimal.zero,
        balance: Decimal.parse('100'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(
              session(permissions: {'customers.view_ledger'}),
            ),
          ),
          customerRepositoryProvider.overrideWith((ref) => repo),
          localeProvider.overrideWithValue(const Locale('en')),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const CustomerStatementTab(customerId: 'cust-1'),
              ),
              GoRoute(
                path: AppRoutes.documentPreview,
                builder: (context, state) {
                  pushedRoute = state.uri.toString();
                  return const Scaffold(body: Text('preview'));
                },
              ),
            ],
          ),
        ),
      ),
    );
    await _loadStatement(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('customer-statement-preview')));
    await tester.pumpAndSettle();

    expect(pushedRoute, isNotNull);
    expect(
      pushedRoute!,
      contains('kind=${DocumentKind.customerStatement.documentType}'),
    );
    expect(pushedRoute!, contains('entityId=cust-1'));
    expect(pushedRoute!, contains('from='));
    expect(pushedRoute!, contains('to='));
    expect(find.text('preview'), findsOneWidget);
  });
}
