import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/presentation/invoice_list_controller.dart';
import 'package:hs360/features/invoices/presentation/invoice_list_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_invoice_repository.dart';

AppSession _session({Set<String> permissions = const {'invoices.view_sales'}}) {
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

Widget _wrap({
  required AppSession session,
  required FakeInvoiceRepository repo,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      invoiceRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const InvoiceListScreen(),
    ),
  );
}

void main() {
  testWidgets('keeps filters visible when filtered results are empty', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeInvoiceRepository(salesInvoices: []);
    await tester.pumpWidget(_wrap(session: _session(), repo: repo));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(InvoiceListScreen)),
    );
    container.read(invoiceListControllerProvider.notifier).setSearch('no-match');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invoice-filters-bar')), findsOneWidget);
    expect(find.text('No invoices match your filters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
