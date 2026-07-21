import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/app.dart';
import 'package:hs360/core/config/env.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/presentation/document_preview_controller.dart';
import 'package:hs360/core/documents/presentation/document_preview_state.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/network/supabase_client.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/contracts/domain/contract_document_payload_allowlist.dart';
import 'package:hs360/features/contracts/domain/contract_document_payload_mapper.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/message_banner.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final localeCode = const String.fromEnvironment(
    'P6M13_LOCALE',
    defaultValue: 'en',
  );
  final tag = const String.fromEnvironment('P6M13_TAG', defaultValue: 'EN');
  // Phase 7 M12: stop after contract→calendar handoff (before PDF/finance close).
  final calendarOnly = const bool.fromEnvironment(
    'P7M12_CALENDAR_ONLY',
    defaultValue: false,
  );

  testWidgets(
    calendarOnly
        ? 'P7M12 calendar-only acceptance ($localeCode)'
        : 'P6M13 manual acceptance ($localeCode)',
    (tester) async {
      if (Env.supabaseAnonKey.isEmpty) {
        fail('SUPABASE_ANON_KEY is required for P6M13 manual acceptance');
      }

      final serial = 'P6M13-$tag-SN001';

      SharedPreferences.setMockInitialValues({preferredLocaleKey: localeCode});

      await SupabaseClientProvider.initialize();
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ProviderScope(child: App()));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final l10n = lookupAppLocalizations(Locale(localeCode));

      await _signIn(tester, l10n);
      await _openContractsNew(tester, l10n);
      await _createTrial(tester, l10n, tag: tag, serial: serial);
      final context = await _convertTrial(tester, l10n);
      final scheduleEvents = await _assertUpcomingScheduleFromServer(
        tester,
        l10n,
        contractId: context.contractId,
        expectPendingEvents: true,
      );

      if (calendarOnly) {
        final first = scheduleEvents.first;
        await _assertCalendarHandoffInApp(
          tester,
          l10n,
          customerId: context.customerId,
          contractId: context.contractId,
          eventId: first['id'] as String,
          scheduledDate: DateTime.parse(first['scheduled_date'] as String),
        );
        return;
      }

      final collectedMonthKey = await _collectRental(tester, l10n);
      await _assertContractPdfPreview(tester, l10n, context.contractId);
      await _assertUpcomingScheduleFromServer(
        tester,
        l10n,
        contractId: context.contractId,
        expectPendingEvents: false,
        collectedMonthKey: collectedMonthKey,
      );
      await _assertCustomerStatement(
        tester,
        l10n,
        customerId: context.customerId,
        contractId: context.contractId,
        collectedMonthKey: collectedMonthKey,
      );
      await _navigateToContractDetail(tester, context.contractId);
      await _closeRental(tester, l10n);
      await _assertCollectedInvoicePaid(context.contractId);
    },
  );
}

class _P6M13ContractContext {
  const _P6M13ContractContext({
    required this.contractId,
    required this.customerId,
  });

  final String contractId;
  final String customerId;
}

Future<void> _signIn(WidgetTester tester, AppLocalizations l10n) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'owner@hayat-secret.test',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
  await tester.tap(find.widgetWithText(FilledButton, l10n.signIn));
  await tester.pumpAndSettle(const Duration(seconds: 10));
  expect(find.text(l10n.navContracts), findsOneWidget);
}

Future<void> _openContractsNew(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await tester.tap(find.text(l10n.navContracts));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('contract-create-submit')), findsOneWidget);
}

Future<void> _createTrial(
  WidgetTester tester,
  AppLocalizations l10n, {
  required String tag,
  required String serial,
}) async {
  await tester.enterText(
    find.byKey(const Key('contract-customer-search')),
    'P6M13',
  );
  await tester.pumpAndSettle(const Duration(seconds: 3));
  final customerTile = find.descendant(
    of: find.byType(Card),
    matching: find.byType(ListTile),
  );
  expect(customerTile, findsWidgets);
  await tester.tap(customerTile.first);
  await tester.pumpAndSettle(const Duration(seconds: 2));

  final serialField = find.byKey(const Key('contract-rental-code'));
  await tester.ensureVisible(serialField);
  await tester.enterText(serialField, serial);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle(const Duration(seconds: 4));

  expect(find.textContaining(serial), findsWidgets);

  await tester.ensureVisible(find.byKey(const Key('contract-create-submit')));
  await tester.tap(find.byKey(const Key('contract-create-submit')));
  await tester.pumpAndSettle();

  final confirmDialog = find.byType(AlertDialog);
  expect(confirmDialog, findsOneWidget);
  await tester.tap(
    find.descendant(
      of: confirmDialog,
      matching: find.widgetWithText(FilledButton, l10n.contractCreateTrial),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 10));

  if (find.byKey(const Key('contract-create-submit')).evaluate().isNotEmpty) {
    final banner = find.byType(MessageBanner);
    if (banner.evaluate().isNotEmpty) {
      fail(
        'trial create did not leave the create screen: '
        '${tester.widget<MessageBanner>(banner.first).message}',
      );
    }
    fail('trial create did not leave the create screen');
  }
  expect(find.text(l10n.contractConvertLink), findsOneWidget);
}

Future<_P6M13ContractContext> _convertTrial(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await tester.tap(find.text(l10n.contractConvertLink));
  await tester.pumpAndSettle(const Duration(seconds: 3));

  await tester.enterText(
    find.byKey(const Key('contract-convert-monthly-rental')),
    '120',
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('contract-convert-submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.contractConvertAction).last);
  await tester.pumpAndSettle(const Duration(seconds: 8));

  expect(
    find.byKey(const Key('contract-detail-collect-rental')),
    findsOneWidget,
  );
  final element = tester.element(
    find.byKey(const Key('contract-detail-collect-rental')),
  );
  final path = GoRouter.of(element).state.uri.path;
  final contractId = path.split('/').last;
  final customerId = await _fetchContractCustomerId(contractId);
  return _P6M13ContractContext(contractId: contractId, customerId: customerId);
}

Future<String> _collectRental(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final collectButton = find.byKey(const Key('contract-detail-collect-rental'));
  await tester.ensureVisible(collectButton);
  await tester.pumpAndSettle();
  await tester.tap(collectButton);
  await tester.pumpAndSettle(const Duration(seconds: 4));

  expect(find.text(l10n.contractCollectRentalTitle), findsOneWidget);

  final selectedMonth = find.byWidgetPredicate(
    (widget) => widget is FilterChip && widget.selected,
  );
  expect(selectedMonth, findsOneWidget);
  final monthKey =
      (tester.widget<FilterChip>(selectedMonth).label as Text).data!;
  expect(monthKey, isNotEmpty);

  await tester.tap(find.byKey(const Key('collect-rental-submit')));
  await tester.pumpAndSettle(const Duration(seconds: 8));

  expect(find.text(l10n.contractCollectSuccess), findsOneWidget);
  expect(find.text(l10n.contractCollectViewInvoice), findsOneWidget);
  expect(find.text(l10n.contractCollectViewReceipt), findsOneWidget);

  final dialog = find.byType(AlertDialog);
  final material = MaterialLocalizations.of(tester.element(dialog));
  await tester.tap(
    find.descendant(of: dialog, matching: find.text(material.closeButtonLabel)),
  );
  await tester.pumpAndSettle(const Duration(seconds: 3));

  return monthKey;
}

Future<void> _assertContractPdfPreview(
  WidgetTester tester,
  AppLocalizations l10n,
  String contractId,
) async {
  expect(find.byKey(const Key('contract-detail-preview')), findsOneWidget);
  await tester.tap(find.byKey(const Key('contract-detail-preview')));
  await tester.pumpAndSettle(const Duration(seconds: 12));

  expect(find.byKey(const Key('document-preview-pdf')), findsOneWidget);
  expect(find.byKey(const Key('document-preview-denied')), findsNothing);
  expect(find.byKey(const Key('document-preview-retry')), findsNothing);

  final previewElement = tester.element(
    find.byKey(const Key('document-preview-pdf')),
  );
  final container = ProviderScope.containerOf(previewElement);
  final args = DocumentPreviewArgs(
    kind: DocumentKind.contract,
    entityId: contractId,
  );
  final state = container.read(documentPreviewControllerProvider(args));
  final bytes = state.renderResult?.bytes;
  expect(bytes, isNotNull);
  expect(bytes, isNotEmpty);
  _assertPdfBytesExcludeSensitiveFields(bytes!, l10n);

  final session = container.read(authControllerProvider).valueOrNull;
  expect(session, isNotNull);
  final detail = await container
      .read(contractRepositoryProvider)
      .fetchContractDetail(session!, contractId);
  final payload = mapContractDetailToCustomerPayload(detail);
  assertContractPayloadAllowlist({
    'document': payload.document,
    'party': payload.party,
    'location': payload.location,
    'lines': payload.lines,
    'totals': payload.totals,
  });

  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(
    find.byKey(const Key('contract-detail-collect-rental')),
    findsOneWidget,
  );
}

/// Schedule truth for authenticated clients comes through security-definer
/// `get_contract_detail.upcoming_schedule` (and the Contract Detail UI that
/// renders it) — not direct `calendar_events` SELECT or revoked list RPC EXECUTE.
Future<List<Map<String, dynamic>>> _assertUpcomingScheduleFromServer(
  WidgetTester tester,
  AppLocalizations l10n, {
  required String contractId,
  required bool expectPendingEvents,
  String? collectedMonthKey,
}) async {
  final serverEvents = await _fetchUpcomingScheduleViaContractDetail(
    contractId,
  );

  await tester.ensureVisible(
    find.byKey(const Key('contract-upcoming-schedule-section')),
  );
  await tester.pumpAndSettle();

  expect(
    find.byKey(const Key('contract-upcoming-schedule-section')),
    findsOneWidget,
  );

  if (expectPendingEvents) {
    expect(
      serverEvents,
      isNotEmpty,
      reason: 'get_contract_detail must return pending schedule rows',
    );
    expect(
      find.byKey(const Key('contract-upcoming-schedule-empty')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('contract-upcoming-schedule-event-0')),
      findsOneWidget,
    );
    expect(find.text(l10n.contractScheduleEventBillingDue), findsWidgets);
    final hasBillingDue = serverEvents.any(
      (row) => row['type'] == 'billing_due',
    );
    expect(
      hasBillingDue,
      isTrue,
      reason:
          'generated schedule must include a real billing_due calendar event',
    );
    return serverEvents;
  }

  if (collectedMonthKey != null) {
    final stillPending = serverEvents.any(
      (row) => row['coverage_month_key'] == collectedMonthKey,
    );
    expect(
      stillPending,
      isFalse,
      reason:
          'collected month must not remain pending in get_contract_detail '
          'upcoming_schedule (authorized substitute for done calendar_events)',
    );
  }

  if (serverEvents.isEmpty) {
    expect(
      find.byKey(const Key('contract-upcoming-schedule-empty')),
      findsOneWidget,
    );
    return serverEvents;
  }

  expect(
    find.byKey(const Key('contract-upcoming-schedule-empty')),
    findsNothing,
  );
  expect(
    find.byKey(const Key('contract-upcoming-schedule-event-0')),
    findsOneWidget,
  );
  return serverEvents;
}

Future<List<Map<String, dynamic>>> _fetchUpcomingScheduleViaContractDetail(
  String contractId,
) async {
  final raw = await Supabase.instance.client.rpc(
    'get_contract_detail',
    params: {'p_contract_id': contractId},
  );
  final detail = Map<String, dynamic>.from(raw as Map);
  final schedule = detail['upcoming_schedule'];
  if (schedule is! List) return const [];
  return schedule.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}

Future<void> _assertCalendarHandoffInApp(
  WidgetTester tester,
  AppLocalizations l10n, {
  required String customerId,
  required String contractId,
  required String eventId,
  required DateTime scheduledDate,
}) async {
  final viewInCalendar = find.byKey(const Key('contract-view-in-calendar'));
  expect(viewInCalendar, findsOneWidget);
  await tester.ensureVisible(viewInCalendar);
  await tester.tap(viewInCalendar);
  await tester.pumpAndSettle(const Duration(seconds: 10));

  expect(
    find.byKey(const Key('calendar-route-scope-banner')),
    findsOneWidget,
    reason: 'calendar must open with contract route scope from detail handoff',
  );
  expect(
    find.byKey(const Key('calendar-route-scope-contract-chip')),
    findsOneWidget,
  );

  // Focus the generated event day so agenda cards mount (detail link omits date).
  final scopeElement = tester.element(
    find.byKey(const Key('calendar-route-scope-banner')),
  );
  GoRouter.of(scopeElement).go(
    AppRoutes.calendarPath(
      customerId: customerId,
      contractId: contractId,
      date: scheduledDate,
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 10));

  expect(
    find.byKey(Key('calendar-event-$eventId')),
    findsOneWidget,
    reason: 'scoped calendar must show the generated contract event',
  );

  // Stop after contract→calendar handoff — before PDF / statement / payment / close.
  expect(find.text(l10n.navCalendar), findsWidgets);
  expect(find.byKey(const Key('contract-detail-preview')), findsNothing);
}

Future<void> _assertCustomerStatement(
  WidgetTester tester,
  AppLocalizations l10n, {
  required String customerId,
  required String contractId,
  required String collectedMonthKey,
}) async {
  final statementRows = await _fetchCustomerStatementRows(customerId);
  final rentalRows = statementRows
      .where((row) => row['source'] == 'rental_invoice')
      .toList();
  final receiptRows = statementRows
      .where((row) => row['source'] == 'receipt_voucher')
      .toList();
  expect(rentalRows, isNotEmpty);
  expect(receiptRows, isNotEmpty);

  final routerElement = tester.element(
    find.byKey(const Key('contract-detail-collect-rental')),
  );
  GoRouter.of(routerElement).go(AppRoutes.customerDetailPath(customerId));
  await tester.pumpAndSettle(const Duration(seconds: 5));

  await tester.tap(find.byKey(const Key('customer-tab-statement')));
  await tester.pumpAndSettle(const Duration(seconds: 8));

  expect(find.byKey(const Key('customer-statement-loaded')), findsOneWidget);
  expect(find.byKey(const Key('customer-statement-denied')), findsNothing);
  expect(find.text(l10n.journalSourceRentalInvoice), findsWidgets);
  expect(find.text(l10n.journalSourceReceiptVoucher), findsWidgets);
  expect(
    find.textContaining(rentalRows.first['entry_number'] as String),
    findsWidgets,
    reason: 'statement UI must show collected rental journal entry',
  );
  expect(
    find.textContaining(receiptRows.first['entry_number'] as String),
    findsWidgets,
    reason: 'statement UI must show collected receipt journal entry',
  );

  final rentalDebit = _parseAmount(rentalRows.first['debit']);
  final receiptCredit = _parseAmount(receiptRows.first['credit']);
  expect(rentalDebit, greaterThan(0));
  expect(receiptCredit, greaterThan(0));
  expect(
    receiptCredit,
    greaterThanOrEqualTo(rentalDebit),
    reason: 'receipt credit must cover collected rental debit',
  );

  final coverageRows = await Supabase.instance.client
      .from('rental_invoice_coverages')
      .select('coverage_month_key, invoice_id')
      .eq('contract_id', contractId)
      .eq('coverage_month_key', collectedMonthKey);
  expect(coverageRows, isNotEmpty);
}

Future<void> _navigateToContractDetail(
  WidgetTester tester,
  String contractId,
) async {
  final element = tester.element(
    find.byKey(const Key('customer-statement-loaded')),
  );
  GoRouter.of(element).go(AppRoutes.contractDetailPath(contractId));
  await tester.pumpAndSettle(const Duration(seconds: 5));
  expect(
    find.byKey(const Key('contract-detail-collect-rental')),
    findsOneWidget,
  );
}

Future<void> _closeRental(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(
    find.widgetWithText(TextButton, l10n.contractCloseRentalAction).first,
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).last, 'P6M13 manual close');
  await tester.tap(
    find.widgetWithText(FilledButton, l10n.contractCloseRentalAction),
  );
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

Future<void> _assertCollectedInvoicePaid(String contractId) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from('invoices')
      .select('total,paid_amount,type,contract_id')
      .eq('contract_id', contractId)
      .eq('type', 'rental_monthly');

  expect(rows, isNotEmpty);
  final invoice = Map<String, dynamic>.from(rows.first as Map);
  expect(invoice['paid_amount'], invoice['total']);
}

Future<String> _fetchContractCustomerId(String contractId) async {
  final row = await Supabase.instance.client
      .from('contracts')
      .select('customer_id')
      .eq('id', contractId)
      .single();
  return row['customer_id'] as String;
}

Future<List<Map<String, dynamic>>> _fetchCustomerStatementRows(
  String customerId,
) async {
  final now = DateTime.now();
  final to = DateTime(now.year, now.month, now.day);
  final from = to.subtract(const Duration(days: 364));
  final rows = await Supabase.instance.client.rpc(
    'get_customer_statement',
    params: {
      'p_customer_id': customerId,
      'p_from': _dateOnly(from),
      'p_to': _dateOnly(to),
    },
  );
  return (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}

String _dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

double _parseAmount(Object? value) {
  if (value == null) return 0;
  return double.parse(value.toString());
}

void _assertPdfBytesExcludeSensitiveFields(
  List<int> bytes,
  AppLocalizations l10n,
) {
  final haystack = String.fromCharCodes(bytes);
  final forbidden = <String>[
    l10n.contractFieldMonthlyProfit,
    l10n.contractFieldMonthlyCost,
    l10n.contractFieldTotalMonthlyCost,
    l10n.contractFieldDeviceMonthlyCost,
    l10n.contractFieldOilMonthlyCost,
    l10n.contractFieldNetMonthlyProfit,
    l10n.contractFinancialDetails,
    'snapshot_monthly_profit',
    'snapshot_total_monthly_cost',
    'snapshot_device_monthly_cost',
    'snapshot_oil_monthly_cost',
  ];
  for (final needle in forbidden) {
    if (needle.trim().isEmpty) continue;
    expect(
      haystack.contains(needle),
      isFalse,
      reason: 'contract PDF must not contain sensitive field: $needle',
    );
  }
}
