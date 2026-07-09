import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/presentation/contract_list_controller.dart';
import 'package:hs360/features/contracts/presentation/contract_list_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({Set<String> permissions = const {'contracts.view'}}) {
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

Widget _wrap({
  required AppSession session,
  required FakeContractRepository repo,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      contractRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(size: Size(1280, 800)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const ContractListScreen(),
    ),
  );
}

void main() {
  testWidgets('shows populated contract table', (tester) async {
    await tester.pumpWidget(
      _wrap(
        session: _session(),
        repo: FakeContractRepository(
          summaries: [sampleContractSummary(id: 'contract-1')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contract-table')), findsOneWidget);
    expect(find.text('CON-001'), findsOneWidget);
  });

  testWidgets('shows empty state when filtered results are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(session: _session(), repo: FakeContractRepository()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContractListScreen)),
    );
    container.read(contractListControllerProvider.notifier).setSearch('none');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contract-filters-bar')), findsOneWidget);
    expect(find.text('No contracts match your filters.'), findsOneWidget);
  });
}
