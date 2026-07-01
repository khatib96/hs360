import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/domain/voucher_status.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';
import 'package:hs360/features/vouchers/presentation/voucher_detail_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_voucher_repository.dart';

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
  required FakeVoucherRepository repo,
  String voucherId = 'v-1',
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      voucherRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: VoucherDetailScreen(voucherId: voucherId),
    ),
  );
}

void main() {
  testWidgets('shows preview button with vouchers.print on receipt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeVoucherRepository(
      detailById: {'v-1': sampleVoucherDetail()},
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'vouchers.view', 'vouchers.print'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voucher-detail-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides preview without vouchers.print', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeVoucherRepository(
      detailById: {'v-1': sampleVoucherDetail()},
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'vouchers.view'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voucher-detail-preview')), findsNothing);
  });

  testWidgets('hides preview for payment voucher', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeVoucherRepository(
      detailById: {'v-1': sampleVoucherDetail(type: VoucherType.payment)},
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'vouchers.view', 'vouchers.print'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voucher-detail-preview')), findsNothing);
  });

  testWidgets('hides preview for cancelled receipt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeVoucherRepository(
      detailById: {'v-1': sampleVoucherDetail(status: VoucherStatus.cancelled)},
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'vouchers.view', 'vouchers.print'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voucher-detail-preview')), findsNothing);
  });

  testWidgets('cancel dialog requires a reason before submitting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeVoucherRepository(
      detailById: {'v-1': sampleVoucherDetail(status: VoucherStatus.confirmed)},
    );

    await tester.pumpWidget(
      _wrap(
        session: _session(permissions: {'vouchers.view', 'vouchers.cancel'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel voucher'));
    await tester.pumpAndSettle();

    final disabledCancel = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Cancel voucher'),
    );
    expect(disabledCancel.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Wrong entry');
    await tester.pump();

    final enabledCancel = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Cancel voucher'),
    );
    expect(enabledCancel.onPressed, isNotNull);
  });
}
