import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/warehouse.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/presentation/invoice_form_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_invoice_repository.dart';

AppSession _session({required Set<String> permissions}) {
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

class FakeWarehouseRepository extends WarehouseRepository {
  FakeWarehouseRepository() : super(null);

  @override
  Future<List<Warehouse>> fetchWarehouses({bool activeOnly = true}) async =>
      const [];
}

Widget _wrap({
  required AppSession session,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      invoiceRepositoryProvider.overrideWith((ref) => FakeInvoiceRepository()),
      warehouseRepositoryProvider.overrideWith((ref) => FakeWarehouseRepository()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: widget ?? const SizedBox.shrink(),
      ),
      home: child,
    ),
  );
}

void main() {
  testWidgets('purchase draft edit shows save but not confirm without create', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'invoices.edit_draft'}),
        child: const InvoiceFormScreen(
          invoiceType: InvoiceType.purchase,
          draftId: 'draft-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Confirm invoice'), findsNothing);
  });

  testWidgets('new purchase with create only shows confirm but not save draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'invoices.create_purchase'}),
        child: const InvoiceFormScreen(invoiceType: InvoiceType.purchase),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirm invoice'), findsOneWidget);
    expect(find.text('Save draft'), findsNothing);
  });

  testWidgets('purchase draft with create and edit shows both actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {
          'invoices.create_purchase',
          'invoices.edit_draft',
        }),
        child: const InvoiceFormScreen(
          invoiceType: InvoiceType.purchase,
          draftId: 'draft-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Confirm invoice'), findsOneWidget);
  });
}
