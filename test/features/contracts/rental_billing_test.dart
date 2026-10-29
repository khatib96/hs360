import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/rental_billing_repository.dart';
import 'package:hs360/features/contracts/domain/rental_billing.dart';
import 'package:hs360/features/contracts/presentation/rental_arrears_screen.dart';
import 'package:hs360/features/contracts/presentation/widgets/contract_rental_collections_section.dart';
import 'package:hs360/l10n/app_localizations.dart';

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({
  bool isManager = true,
  Set<String> permissions = const {},
}) {
  return AppSession(
    userId: 'u-1',
    email: 'u@company.local',
    tenantId: 't-1',
    tenantUserId: 'tu-1',
    accountType: isManager ? 'manager' : 'user',
    displayName: 'User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
  );
}

const _arrearsJson = {
  'as_of': '2026-10-31',
  'currency_code': 'KWD',
  'total_amount': '75.000',
  'total_months': 3,
  'contracts_count': 1,
  'items': [
    {
      'contract_id': 'c-1',
      'contract_number': 'CON-001',
      'status': 'active',
      'customer_id': 'cu-1',
      'customer_name_ar': 'فندق الواحة',
      'customer_name_en': 'Oasis Hotel',
      'monthly_rental_value': '25.000',
      'months': ['2026-08-01', '2026-09-01', '2026-10-01'],
      'months_count': 3,
      'amount': '75.000',
      'oldest_due_date': '2026-08-05',
    },
  ],
};

List<Map<String, dynamic>> _collectionsJson({String status = 'confirmed'}) => [
  {
    'invoice_id': 'inv-1',
    'invoice_number': 'SI-000010',
    'date': '2026-10-05',
    'total': 25,
    'status': status,
    'voucher_id': 'v-1',
    'voucher_number': 'RV-000004',
    'voucher_status': status,
    'coverage_months': ['2026-10-01'],
    'cancelled_at': null,
    'cancellation_reason': status == 'cancelled' ? 'Wrong contract' : null,
  },
];

Widget _app(
  Widget home,
  AppSession session,
  RentalBillingRepository repository,
) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _TestAuth(session)),
      rentalBillingRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  group('domain and repository', () {
    test('parses the arrears report exactly', () {
      final report = RentalArrearsReport.fromJson(_arrearsJson);
      expect(report.totalAmount, Decimal.parse('75'));
      expect(report.totalMonths, 3);
      expect(report.items.single.months, hasLength(3));
      expect(report.items.single.customerName('ar'), 'فندق الواحة');
      expect(report.items.single.oldestDueDate, DateTime(2026, 8, 5));
    });

    test('cancel needs both invoice and voucher cancel permissions', () {
      expect(
        canCancelRentalCollection(
          _session(isManager: false, permissions: {'invoices.cancel'}),
        ),
        isFalse,
      );
      expect(
        canCancelRentalCollection(
          _session(
            isManager: false,
            permissions: {'invoices.cancel', 'vouchers.cancel'},
          ),
        ),
        isTrue,
      );
      expect(
        canViewRentalArrears(
          _session(isManager: false, permissions: {'contracts.view'}),
        ),
        isFalse,
      );
    });

    test('sends cancel parameters and a date-only as-of', () async {
      final calls = <String, Map<String, dynamic>>{};
      final repository = RentalBillingRepository(
        null,
        rpcInvoker: (name, params) async {
          calls[name] = params;
          return name == 'list_rental_arrears' ? _arrearsJson : null;
        },
      );

      await repository.cancelCollection(
        invoiceId: 'inv-1',
        reason: '  Wrong contract ',
        idempotencyKey: 'key-1',
      );
      await repository.listArrears(asOf: DateTime(2026, 3, 7, 22, 30));

      expect(calls['cancel_rental_collection'], {
        'p_invoice_id': 'inv-1',
        'p_reason': 'Wrong contract',
        'p_idempotency_key': 'key-1',
      });
      expect(calls['list_rental_arrears'], {'p_as_of': '2026-03-07'});
    });

    test('maps database errors to finance codes', () async {
      final repository = RentalBillingRepository(
        null,
        rpcInvoker: (_, _) async => throw Exception('books_locked'),
      );
      await expectLater(
        repository.listCollections('c-1'),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.booksLocked,
          ),
        ),
      );
    });
  });

  group('screens', () {
    testWidgets('arrears screen lists contracts with months and total', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = RentalBillingRepository(
        null,
        rpcInvoker: (_, _) async => _arrearsJson,
      );

      await tester.pumpWidget(
        _app(const RentalArrearsScreen(), _session(), repository),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rental-arrears-c-1')), findsOneWidget);
      expect(find.text('1 contracts · 3 months'), findsOneWidget);
      expect(find.textContaining('CON-001 · Oasis Hotel'), findsOneWidget);
    });

    testWidgets('collections section cancels with a reason', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var cancelled = false;
      final repository = RentalBillingRepository(
        null,
        rpcInvoker: (name, params) async {
          if (name == 'cancel_rental_collection') {
            expect(params['p_reason'], 'Wrong contract');
            cancelled = true;
            return {'invoice_id': 'inv-1'};
          }
          return _collectionsJson(
            status: cancelled ? 'cancelled' : 'confirmed',
          );
        },
      );

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ContractRentalCollectionsSection(
              contractId: 'c-1',
              session: _session(),
            ),
          ),
          _session(),
          repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rental-collection-cancel-inv-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('lifecycle-action-reason')),
        'Wrong contract',
      );
      await tester.pump();
      await tester.tap(find.text('Cancel collection').last);
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(
        find.byKey(const Key('rental-collection-cancel-inv-1')),
        findsNothing,
      );
    });

    testWidgets('no cancel action without cancel permissions', (tester) async {
      final viewer = _session(
        isManager: false,
        permissions: {'invoices.view_sales'},
      );
      final repository = RentalBillingRepository(
        null,
        rpcInvoker: (_, _) async => _collectionsJson(),
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ContractRentalCollectionsSection(
              contractId: 'c-1',
              session: viewer,
            ),
          ),
          viewer,
          repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rental-collection-inv-1')), findsOneWidget);
      expect(
        find.byKey(const Key('rental-collection-cancel-inv-1')),
        findsNothing,
      );
    });
  });
}
