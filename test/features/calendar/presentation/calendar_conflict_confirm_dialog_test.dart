import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_conflict_confirm_dialog.dart';
import 'package:hs360/l10n/app_localizations.dart';

Widget _buildApp({
  required CalendarManualConflictInfo conflicts,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showCalendarConflictConfirmDialog(context: context, conflicts: conflicts),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'shows safe kind+title from date_exception for non_working_day',
    (tester) async {
      final conflicts = CalendarManualConflictInfo(
        scheduleWarnings: [
          {
            'code': 'non_working_day',
            // Mirrors the server's `safe_date_exception_json` projection:
            // kind/title_ar/title_en only, notes is never included.
            'date_exception': {
              'kind': 'official_holiday',
              'title_ar': 'عيد الفطر',
              'title_en': 'Eid al-Fitr',
            },
          },
        ],
        overlapWarnings: const [],
        overlapTotalCount: 0,
      );

      await tester.pumpWidget(_buildApp(conflicts: conflicts));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calendar-conflict-exception-label')),
        findsOneWidget,
      );
      expect(find.textContaining('Eid al-Fitr'), findsOneWidget);
    },
  );

  testWidgets(
    'treats an unexpected non-safe key (e.g. notes) in date_exception as a '
    'malformed response rather than rendering it',
    (tester) async {
      final conflicts = CalendarManualConflictInfo(
        scheduleWarnings: [
          {
            'code': 'non_working_day',
            'date_exception': {
              'kind': 'official_holiday',
              'title_ar': 'عيد الفطر',
              'title_en': 'Eid al-Fitr',
              'notes': 'must never be rendered',
            },
          },
        ],
        overlapWarnings: const [],
        overlapTotalCount: 0,
      );

      await tester.pumpWidget(_buildApp(conflicts: conflicts));
      await tester.tap(find.text('open'));
      await tester.pump();

      expect(tester.takeException(), isA<CalendarException>());
    },
  );

  testWidgets(
    'omits the exception subtitle when non_working_day has no date_exception',
    (tester) async {
      final conflicts = CalendarManualConflictInfo(
        scheduleWarnings: const [
          {'code': 'non_working_day'},
        ],
        overlapWarnings: const [],
        overlapTotalCount: 0,
      );

      await tester.pumpWidget(_buildApp(conflicts: conflicts));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-ack-non-working')), findsOneWidget);
      expect(
        find.byKey(const Key('calendar-conflict-exception-label')),
        findsNothing,
      );
    },
  );

  testWidgets('overlap-only conflicts require the overlap acknowledgement', (
    tester,
  ) async {
    final conflicts = CalendarManualConflictInfo(
      scheduleWarnings: const [],
      overlapWarnings: const [
        {'code': 'overlap'},
      ],
      overlapTotalCount: 1,
    );

    await tester.pumpWidget(_buildApp(conflicts: conflicts));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-ack-overlap')), findsOneWidget);
    final submit = find.byKey(const Key('calendar-conflict-confirm-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.byKey(const Key('calendar-ack-overlap')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });
}
