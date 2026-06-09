import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/data/document_providers.dart';
import 'package:hs360/core/documents/data/document_template_repository.dart';
import 'package:hs360/core/documents/data/logo_loader.dart';
import 'package:hs360/core/errors/document_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/settings/presentation/template_settings_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_document_template_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

class _FakeLogoLoader implements LogoLoader {
  _FakeLogoLoader({this.error});

  final LogoLoadException? error;

  @override
  Future<Uint8List?> loadValidated(String? url) async {
    if (error != null) throw error!;
    return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
  }
}

Finder fieldKey(String name) => find.byKey(Key(name), skipOffstage: false);

Finder get _settingsListView => find.byKey(const Key('template-settings-list'));

Future<void> scrollToField(WidgetTester tester, String keyName) async {
  final target = fieldKey(keyName);
  for (var attempt = 0; attempt < 30; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(_settingsListView, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll to $keyName');
}

void main() {
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

  Widget buildApp({
    required AppSession appSession,
    required FakeDocumentTemplateRepository repo,
    LogoLoader? logoLoader,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(appSession),
        ),
        documentTemplateRepositoryProvider.overrideWith((ref) => repo),
        if (logoLoader != null)
          logoLoaderProvider.overrideWithValue(logoLoader),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TemplateSettingsScreen(),
      ),
    );
  }

  testWidgets('shows permission denied without template permission', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      buildApp(appSession: session(), repo: FakeDocumentTemplateRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.templateSettingsPermissionDenied), findsOneWidget);
  });

  testWidgets('renders all template settings fields', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeDocumentTemplateRepository();
    await tester.pumpWidget(
      buildApp(
        appSession: session(permissions: {'settings.templates.view'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(fieldKey('template-settings-logo-url'), findsOneWidget);
    expect(fieldKey('template-settings-primary-color'), findsOneWidget);
    expect(fieldKey('template-settings-secondary-color'), findsOneWidget);
    expect(fieldKey('template-settings-default-language'), findsOneWidget);
    expect(fieldKey('template-settings-invoice-paper'), findsOneWidget);
    expect(fieldKey('template-settings-voucher-paper'), findsOneWidget);
    expect(fieldKey('template-settings-asset-label-paper'), findsOneWidget);
    expect(find.text(l10n.templateSettingsPaperLabel), findsOneWidget);
    await scrollToField(tester, 'template-settings-header-ar');
    expect(fieldKey('template-settings-header-ar'), findsOneWidget);
    await scrollToField(tester, 'template-settings-header-en');
    expect(fieldKey('template-settings-header-en'), findsOneWidget);
    await scrollToField(tester, 'template-settings-footer-ar');
    expect(fieldKey('template-settings-footer-ar'), findsOneWidget);
    await scrollToField(tester, 'template-settings-footer-en');
    expect(fieldKey('template-settings-footer-en'), findsOneWidget);
    await scrollToField(
      tester,
      'template-settings-optional-sales_invoice-line.qty',
    );
    expect(
      fieldKey('template-settings-optional-sales_invoice-line.qty'),
      findsOneWidget,
    );
    final toggle = tester.widget<SwitchListTile>(
      fieldKey('template-settings-optional-sales_invoice-line.unit_price'),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('shows logo validation error on save', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeDocumentTemplateRepository();
    await tester.pumpWidget(
      buildApp(
        appSession: session(permissions: {'settings.templates.edit'}),
        repo: repo,
        logoLoader: _FakeLogoLoader(
          error: const LogoLoadException(NetworkLogoLoader.invalidUrl),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollToField(tester, 'template-settings-save');
    await tester.tap(fieldKey('template-settings-save'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.documentErrorLogoInvalidUrl), findsOneWidget);
    expect(repo.saveCount, 0);
  });

  testWidgets('saves settings when logo validates', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeDocumentTemplateRepository();
    await tester.pumpWidget(
      buildApp(
        appSession: session(permissions: {'settings.templates.edit'}),
        repo: repo,
        logoLoader: _FakeLogoLoader(),
      ),
    );
    await tester.pumpAndSettle();

    await scrollToField(tester, 'template-settings-save');
    await tester.tap(fieldKey('template-settings-save'));
    await tester.pumpAndSettle();

    expect(repo.saveCount, 1);
    expect(find.text(l10n.templateSettingsSaved), findsOneWidget);
  });

  testWidgets('shows fetch error banner', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeDocumentTemplateRepository(
      fetchError: const DocumentException(code: DocumentException.unknown),
    );
    await tester.pumpWidget(
      buildApp(
        appSession: session(permissions: {'settings.templates.view'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.documentErrorUnknown), findsOneWidget);
  });
}
