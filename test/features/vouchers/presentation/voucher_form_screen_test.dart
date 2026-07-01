import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/suppliers/data/supplier_repository.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';
import 'package:hs360/features/vouchers/presentation/voucher_form_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../accounting/fake_chart_account_repository.dart';
import '../../customers/fake_customer_repository.dart';
import '../../suppliers/fake_supplier_repository.dart';
import '../fake_voucher_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({
  Set<String> permissions = const {'vouchers.create_receipt'},
}) {
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

Widget _wrap({required AppSession session}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      voucherRepositoryProvider.overrideWith((ref) => FakeVoucherRepository()),
      chartAccountRepositoryProvider.overrideWith(
        (ref) => FakeChartAccountRepository(),
      ),
      customerRepositoryProvider.overrideWith(
        (ref) => FakeCustomerRepository(),
      ),
      supplierRepositoryProvider.overrideWith(
        (ref) => FakeSupplierRepository(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const VoucherFormScreen(voucherType: VoucherType.receipt),
    ),
  );
}

void main() {
  testWidgets(
    'shows chart view required message once without chart permission',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(session: _session()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('صلاحية شجرة الحسابات مطلوبة'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
