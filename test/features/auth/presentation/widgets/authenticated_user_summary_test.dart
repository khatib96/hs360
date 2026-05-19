import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/auth/presentation/widgets/authenticated_user_summary.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  AppSession mockSession({
    String displayName = 'Test User',
    String accountType = 'manager',
    String email = 'owner@hayat-secret.test',
    String tenantId = '00000000-0000-0000-0000-000000000101',
  }) {
    return AppSession(
      userId: 'user-1',
      email: email,
      tenantId: tenantId,
      tenantUserId: 'tu-1',
      accountType: accountType,
      displayName: displayName,
      preferredLocale: 'ar',
      permissions: AppPermissions(
        isManager: accountType == 'manager',
        permissions: const {},
      ),
    );
  }

  Widget buildTestApp(AppSession session) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => TestAuthController(session)),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AuthenticatedUserSummary()),
      ),
    );
  }

  testWidgets('shows display name, account type, email, and tenant id', (
    WidgetTester tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final session = mockSession();

    await tester.pumpWidget(buildTestApp(session));
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text(l10n.accountTypeManager), findsOneWidget);
    expect(find.text('owner@hayat-secret.test'), findsOneWidget);
    expect(find.text('00000000-0000-0000-0000-000000000101'), findsOneWidget);
    expect(find.text(l10n.sessionDisplayNameLabel), findsOneWidget);
    expect(find.text(l10n.sessionTenantLabel), findsOneWidget);
  });

  testWidgets('hides display name row when display name is empty', (
    WidgetTester tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final session = mockSession(displayName: '   ');

    await tester.pumpWidget(buildTestApp(session));
    await tester.pumpAndSettle();

    expect(find.text(l10n.sessionDisplayNameLabel), findsNothing);
    expect(find.text(l10n.accountTypeManager), findsOneWidget);
  });
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
