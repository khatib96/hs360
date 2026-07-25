import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/app_shell.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('M2 shell supports ${locale.languageCode} at 200% text scale', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        locale: locale,
        textScale: 2,
        size: const Size(1024, 768),
      );

      expect(find.byKey(const Key('app-sidebar')), findsOneWidget);
      expect(
        find.byKey(const Key('shell-contextual-navigation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell-user-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('audit-only profile leaks no unavailable module', (tester) async {
    await _pumpShell(
      tester,
      locale: const Locale('en'),
      permissions: {'audit_log.view'},
    );

    expect(find.byKey(const Key('shell-module-dashboard')), findsNothing);
    expect(find.byKey(const Key('shell-module-settings')), findsNothing);
    expect(find.byKey(const Key('shell-user-card')), findsOneWidget);
  });

  testWidgets('keyboard traversal establishes focus in the shell', (
    tester,
  ) async {
    await _pumpShell(tester, locale: const Locale('en'));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(tester.binding.focusManager.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Locale locale,
  Size size = const Size(1024, 768),
  double textScale = 1,
  Set<String>? permissions,
}) async {
  final appSession = AppSession(
    userId: 'user-1',
    email: 'user@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: permissions == null ? 'manager' : 'user',
    displayName: locale.languageCode == 'ar' ? 'مدير النظام' : 'System Manager',
    preferredLocale: locale.languageCode,
    permissions: AppPermissions(
      isManager: permissions == null,
      permissions: permissions ?? const {},
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(appSession),
        ),
        localeProvider.overrideWithValue(locale),
      ],
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.light(locale: locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: const AppShell(
              title: 'Invoice workspace',
              currentRoute: AppRoutes.invoices,
              body: Center(child: Text('Body')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}
