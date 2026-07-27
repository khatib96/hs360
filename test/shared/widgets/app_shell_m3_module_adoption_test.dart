import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/app_shell.dart';

void main() {
  AppSession session() => AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'contracts.view', 'contracts.create'},
    ),
  );

  Widget buildShell({
    required List<Widget>? moduleActions,
    Size size = const Size(1024, 768),
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _TestAuth(session())),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: AppShell(
            title: 'Contracts',
            currentRoute: AppRoutes.contracts,
            moduleActions: moduleActions,
            body: const ColoredBox(
              key: Key('module-body'),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('module commands render between context navigation and content', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildShell(
        moduleActions: [
          FilledButton(
            key: const Key('create-command'),
            onPressed: () {},
            child: const Text('Create'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell-module-command-bar')), findsOneWidget);
    expect(find.byKey(const Key('create-command')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('shell-module-command-bar'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('module-body'))).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty command collection does not reserve shell space', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell(moduleActions: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell-module-command-bar')), findsNothing);
  });

  testWidgets('narrow command bar scrolls horizontally without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildShell(
        size: const Size(390, 844),
        moduleActions: [
          for (var index = 0; index < 8; index++)
            OutlinedButton(
              key: Key('command-$index'),
              onPressed: () {},
              child: Text('Command $index'),
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('shell-module-command-bar')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('command-0')), findsOneWidget);
    expect(find.byKey(const Key('command-7')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestAuth extends AuthController {
  _TestAuth(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}
