import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/app_lifecycle_action_dialog.dart';

void main() {
  testWidgets('shows consequence and requires a trimmed reason', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppLifecycleActionDialog(
                  context: context,
                  title: 'Cancel invoice',
                  consequence: 'The accounting effect will be reversed.',
                  confirmLabel: 'Cancel invoice',
                  reasonRequired: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.text('The accounting effect will be reversed.'),
      findsOneWidget,
    );

    final confirm = find.widgetWithText(FilledButton, 'Cancel invoice');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('lifecycle-action-reason')),
      '  Customer request  ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, 'Customer request');
  });

  testWidgets('returns an empty confirmation for actions without a reason', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppLifecycleActionDialog(
                  context: context,
                  title: 'Deactivate customer',
                  consequence: 'The customer will leave the active list.',
                  confirmLabel: 'Deactivate',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lifecycle-action-reason')), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();
    expect(result, '');
  });
}
