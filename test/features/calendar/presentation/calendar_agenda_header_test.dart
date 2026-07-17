import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_range_summary.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_agenda_header.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_repository.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  required int eventCount,
  int? unassignedCount,
}) async {
  final date = DateTime(2026, 7, 14);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CalendarAgendaHeader(
          selectedDate: date,
          workingDay: sampleCalendarWorkingDay(date: date),
          daySummary: CalendarDaySummary(
            date: date,
            isoWeekday: date.weekday,
            eventCount: eventCount,
            unassignedCount: unassignedCount,
            overdueCount: 0,
            workingDay: sampleCalendarWorkingDay(date: date),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('English event counts use singular/plural forms', (tester) async {
    await _pump(tester, locale: const Locale('en'), eventCount: 0);
    expect(find.text('0 events'), findsOneWidget);

    await _pump(tester, locale: const Locale('en'), eventCount: 1);
    expect(find.text('1 event'), findsOneWidget);
    expect(find.text('1 events'), findsNothing);

    await _pump(tester, locale: const Locale('en'), eventCount: 5);
    expect(find.text('5 events'), findsOneWidget);
  });

  testWidgets('Arabic event counts use grammatical plural categories', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('ar'), eventCount: 0);
    expect(find.text('لا مواعيد'), findsOneWidget);

    await _pump(tester, locale: const Locale('ar'), eventCount: 1);
    expect(find.text('موعد واحد'), findsOneWidget);
    expect(find.text('1 مواعيد'), findsNothing);

    await _pump(tester, locale: const Locale('ar'), eventCount: 2);
    expect(find.text('موعدان'), findsOneWidget);

    await _pump(tester, locale: const Locale('ar'), eventCount: 3);
    expect(find.text('3 مواعيد'), findsOneWidget);

    await _pump(tester, locale: const Locale('ar'), eventCount: 11);
    expect(find.text('11 موعدًا'), findsOneWidget);

    await _pump(tester, locale: const Locale('ar'), eventCount: 100);
    expect(find.text('100 موعد'), findsOneWidget);
  });

  testWidgets('unassigned count label renders alongside the event count', (
    tester,
  ) async {
    await _pump(
      tester,
      locale: const Locale('en'),
      eventCount: 1,
      unassignedCount: 1,
    );
    expect(find.text('1 unassigned'), findsOneWidget);

    // Assigned-only scope masks the unassigned count entirely.
    await _pump(tester, locale: const Locale('en'), eventCount: 1);
    expect(find.textContaining('unassigned'), findsNothing);
  });
}
