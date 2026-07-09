import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/presentation/voucher_list_controller.dart';
import 'package:hs360/features/vouchers/presentation/voucher_list_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_voucher_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({Set<String> permissions = const {'vouchers.view'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'ar',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

Widget _wrap({
  required AppSession session,
  required FakeVoucherRepository repo,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      voucherRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const VoucherListScreen(),
    ),
  );
}

void main() {
  testWidgets('keeps filters visible when filtered results are empty', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(session: _session(), repo: FakeVoucherRepository()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VoucherListScreen)),
    );
    container
        .read(voucherListControllerProvider.notifier)
        .setSearch('no-match');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voucher-filters-bar')), findsOneWidget);
    expect(find.text('لا توجد سندات مطابقة للفلاتر.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
