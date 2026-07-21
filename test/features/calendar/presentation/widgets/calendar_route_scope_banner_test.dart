import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_route_scope.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_route_scope_banner.dart';
import 'package:hs360/l10n/app_localizations.dart';

const _customerId = '11111111-1111-1111-1111-111111111111';
const _contractId = '22222222-2222-2222-2222-222222222222';

Future<void> _pump(
  WidgetTester tester, {
  required CalendarRouteScope scope,
  required VoidCallback onClear,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CalendarRouteScopeBanner(scope: scope, onClear: onClear),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing for an empty scope', (tester) async {
    await _pump(tester, scope: CalendarRouteScope.empty, onClear: () {});
    expect(find.byKey(const Key('calendar-route-scope-banner')), findsNothing);
  });

  testWidgets('renders nothing for a date-only scope (focus only)', (
    tester,
  ) async {
    final scope = CalendarRouteScope.fromQueryParameters(const {
      'date': '2026-08-20',
    });
    await _pump(tester, scope: scope, onClear: () {});
    expect(scope.showsBanner, isFalse);
    expect(find.byKey(const Key('calendar-route-scope-banner')), findsNothing);
  });

  testWidgets('shows a customer chip only when scoped to a customer', (
    tester,
  ) async {
    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': _customerId,
    });
    await _pump(tester, scope: scope, onClear: () {});

    expect(
      find.byKey(const Key('calendar-route-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-route-scope-customer-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-route-scope-contract-chip')),
      findsNothing,
    );
  });

  testWidgets('shows both chips when scoped to customer and contract', (
    tester,
  ) async {
    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': _customerId,
      'contractId': _contractId,
    });
    await _pump(tester, scope: scope, onClear: () {});

    expect(
      find.byKey(const Key('calendar-route-scope-customer-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-route-scope-contract-chip')),
      findsOneWidget,
    );
  });

  testWidgets('never renders the raw customerId/contractId text', (
    tester,
  ) async {
    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': _customerId,
      'contractId': _contractId,
    });
    await _pump(tester, scope: scope, onClear: () {});

    // The banner must show generic labels only — never the untrusted IDs.
    expect(find.text(_customerId), findsNothing);
    expect(find.text(_contractId), findsNothing);
  });

  testWidgets('tapping Clear invokes onClear', (tester) async {
    var cleared = false;
    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': _customerId,
    });
    await _pump(tester, scope: scope, onClear: () => cleared = true);

    await tester.tap(find.byKey(const Key('calendar-route-scope-clear')));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });

  testWidgets('shows an invalid-link message with no chips when malformed', (
    tester,
  ) async {
    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': 'not-a-uuid',
    });
    await _pump(tester, scope: scope, onClear: () {});

    expect(
      find.byKey(const Key('calendar-route-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-route-scope-customer-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('calendar-route-scope-contract-chip')),
      findsNothing,
    );
    // Invalid state still offers a way back to plain calendar navigation.
    expect(find.byKey(const Key('calendar-route-scope-clear')), findsOneWidget);
  });

  testWidgets('renders Arabic translations under the ar locale', (
    tester,
  ) async {
    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': _customerId,
    });
    await _pump(
      tester,
      scope: scope,
      onClear: () {},
      locale: const Locale('ar'),
    );

    expect(
      find.byKey(const Key('calendar-route-scope-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-route-scope-customer-chip')),
      findsOneWidget,
    );
  });
}
