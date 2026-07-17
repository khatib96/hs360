import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/domain/calendar_time_window.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_reschedule_dialog.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_repository.dart';

CalendarRescheduleInput? _lastInput;
var _dialogClosed = false;

Future<void> _pumpAndOpen(
  WidgetTester tester, {
  required CalendarEvent event,
}) async {
  _lastInput = null;
  _dialogClosed = false;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              _lastInput = await showCalendarRescheduleDialog(
                context: context,
                event: event,
              );
              _dialogClosed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _pickDay(WidgetTester tester, int day) async {
  await tester.tap(find.byKey(const Key('calendar-reschedule-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.pumpAndSettle();
  final okLabel = MaterialLocalizations.of(
    tester.element(find.byType(AlertDialog).first),
  ).okButtonLabel;
  await tester.tap(find.text(okLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows current date context and disables unchanged submit', (
    tester,
  ) async {
    await _pumpAndOpen(
      tester,
      event: sampleCalendarEvent(scheduledDate: DateTime(2026, 7, 14)),
    );

    expect(find.byKey(const Key('calendar-reschedule-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-reschedule-current-date')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-reschedule-unchanged')),
      findsOneWidget,
    );
    final submit = find.byKey(const Key('calendar-reschedule-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('requires a new date AND a reason before submitting', (
    tester,
  ) async {
    await _pumpAndOpen(
      tester,
      event: sampleCalendarEvent(scheduledDate: DateTime(2026, 7, 14)),
    );
    final submit = find.byKey(const Key('calendar-reschedule-submit'));

    // Reason without a date change: still disabled.
    await tester.enterText(
      find.byKey(const Key('calendar-reschedule-reason')),
      'customer request',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Date change too: enabled, and returns the validated input.
    await _pickDay(tester, 20);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(_dialogClosed, isTrue);
    expect(_lastInput, isNotNull);
    expect(_lastInput!.targetDate, DateTime(2026, 7, 20));
    expect(_lastInput!.reason, 'customer request');
  });

  testWidgets('date change without a reason stays disabled', (tester) async {
    await _pumpAndOpen(
      tester,
      event: sampleCalendarEvent(scheduledDate: DateTime(2026, 7, 14)),
    );
    await _pickDay(tester, 20);
    final submit = find.byKey(const Key('calendar-reschedule-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('shows the timed-window summary for timed events only', (
    tester,
  ) async {
    await _pumpAndOpen(
      tester,
      event: sampleCalendarEvent(
        scheduledDate: DateTime(2026, 7, 14),
        timeWindow: const CalendarTimeWindow(
          startLocal: '09:00',
          endLocal: '10:30',
          timezoneName: 'Asia/Kuwait',
        ),
      ),
    );
    expect(
      find.byKey(const Key('calendar-reschedule-time-window')),
      findsOneWidget,
    );
    expect(
      find.text('Time window 09:00–10:30 is kept on the new date.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await _pumpAndOpen(
      tester,
      event: sampleCalendarEvent(scheduledDate: DateTime(2026, 7, 14)),
    );
    expect(
      find.byKey(const Key('calendar-reschedule-time-window')),
      findsNothing,
    );
  });

  testWidgets('cancel returns null', (tester) async {
    await _pumpAndOpen(
      tester,
      event: sampleCalendarEvent(scheduledDate: DateTime(2026, 7, 14)),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_dialogClosed, isTrue);
    expect(_lastInput, isNull);
  });
}
