import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_render_result.dart';
import 'package:hs360/core/documents/presentation/document_preview_controller.dart';
import 'package:hs360/core/documents/presentation/document_preview_screen.dart';
import 'package:hs360/core/documents/presentation/document_preview_state.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

AppSession _session({Set<String> permissions = const {}}) {
  return AppSession(
    userId: 'u1',
    email: 't@example.com',
    tenantId: 't1',
    tenantUserId: 'tu1',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

Widget buildApp({
  required AppSession session,
  required DocumentPreviewState previewState,
  required DocumentPreviewArgs args,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _TestAuthController(session)),
      documentPreviewControllerProvider(
        args,
      ).overrideWith(() => _StaticPreviewController(previewState)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DocumentPreviewScreen(args: args),
    ),
  );
}

class _StaticPreviewController extends DocumentPreviewController {
  _StaticPreviewController(this._state);
  final DocumentPreviewState _state;

  @override
  DocumentPreviewState build(DocumentPreviewArgs args) => _state;
}

void main() {
  const args = DocumentPreviewArgs(
    kind: DocumentKind.customerStatement,
    entityId: 'cust-1',
  );

  testWidgets('shows permission denied banner', (tester) async {
    await tester.pumpWidget(
      buildApp(
        session: _session(),
        previewState: const DocumentPreviewState(permissionDenied: true),
        args: args,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-preview-denied')), findsOneWidget);
  });

  testWidgets('sales invoice without print shows permission denied', (
    tester,
  ) async {
    const salesArgs = DocumentPreviewArgs(
      kind: DocumentKind.salesInvoice,
      entityId: 'inv-1',
    );
    await tester.pumpWidget(
      buildApp(
        session: _session(permissions: {'invoices.view_sales'}),
        previewState: const DocumentPreviewState(permissionDenied: true),
        args: salesArgs,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-preview-denied')), findsOneWidget);
  });

  testWidgets('renders pdf preview when data is ready', (tester) async {
    await tester.pumpWidget(
      buildApp(
        session: _session(permissions: {'customers.view_ledger'}),
        previewState: DocumentPreviewState(
          renderResult: DocumentRenderResult(
            bytes: const [0x25, 0x50, 0x44, 0x46],
            pageCount: 1,
            paperKind: PaperKind.a4,
            title: 'Test',
          ),
          canExport: true,
        ),
        args: args,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('document-preview-pdf')), findsOneWidget);
  });
}
