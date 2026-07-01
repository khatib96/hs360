import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory_accounting/data/inventory_document_repository.dart';
import 'package:hs360/features/inventory_accounting/presentation/inventory_document_list_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_inventory_document_repository.dart';

AppSession _session({Set<String> permissions = const {}}) {
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
  required FakeInventoryDocumentRepository repo,
  Locale locale = const Locale('ar'),
  Size size = const Size(360, 800),
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      inventoryDocumentRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(size: size),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const InventoryDocumentListScreen(),
    ),
  );
}

void main() {
  testWidgets('list screen shows create buttons based on permissions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeInventoryDocumentRepository(
      documents: [sampleInventoryDocumentSummary()],
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {
          'inventory_documents.view',
          'inventory_documents.create_opening',
          'inventory_documents.create_adjustment',
        }),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    final menuItem = find.byType(PopupMenuItem<String>);
    expect(
      find.descendant(of: menuItem, matching: find.text('رصيد افتتاحي')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menuItem, matching: find.text('إدخال مخزون')),
      findsOneWidget,
    );
  });

  testWidgets('list screen has no overflow on narrow Arabic viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeInventoryDocumentRepository(
      documents: [sampleInventoryDocumentSummary()],
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'inventory_documents.view'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
