// Supporting (NOT live-app) screenshot harness for Phase 7 M8 assignment and
// rescheduling: the event actions dialog with Assign/Reschedule, the
// assignment dialog (candidates, capability warnings, unassign), the
// reschedule dialog (timed window, mandatory reason), the soft-conflict
// confirmation, and the stale-version error. Renders with
// FakeCalendarRepository sample data and writes PNGs to build/screenshots/.
//
// These are supporting renders only. Visual acceptance still requires live
// macOS app screenshots from an authenticated session when the owner prefers.
//
// Run: flutter test test/screenshots/calendar_m8_screenshots.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_schedule_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_time_window.dart';
import 'package:hs360/features/calendar/presentation/calendar_clock.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/calendar/fake_calendar_repository.dart';

part 'calendar_m8_screenshot_support.dart';

void main() {
  setUpAll(_loadFonts);

  late CalendarClock previous;
  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });
  tearDown(() => calendarClock = previous);

  testWidgets('1. event actions with assign/reschedule', (tester) async {
    await _pumpCalendar(tester, locale: const Locale('en'), repo: _repo());
    await _openActionsDialog(tester, _assignableEventId);
    expect(
      find.byKey(const Key('calendar-assign-$_assignableEventId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-reschedule-$_assignableEventId')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_01_event_actions_assign_reschedule_en_ltr');
  });

  testWidgets('2. assignment dialog with capability warnings', (tester) async {
    await _pumpCalendar(tester, locale: const Locale('ar'), repo: _repo());
    await _openAssignmentDialog(tester);
    expect(find.byKey(const Key('calendar-assign-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-assign-candidate-emp-no-cal')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_02_assignment_dialog_warnings_ar_rtl');
  });

  testWidgets('3. assignment dialog with unassign selected', (tester) async {
    await _pumpCalendar(tester, locale: const Locale('en'), repo: _repo());
    await _openAssignmentDialog(tester);
    await tester.tap(find.byKey(const Key('calendar-assign-unassign')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-assign-current-option')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_03_assignment_unassign_selected_en_ltr');
  });

  testWidgets('4. reschedule dialog with timed window', (tester) async {
    await _pumpCalendar(tester, locale: const Locale('en'), repo: _repo());
    await _openRescheduleDialog(tester);
    await _pickRescheduleDay(tester, 20);
    await tester.enterText(
      find.byKey(const Key('calendar-reschedule-reason')),
      'Customer asked to move the delivery to next week',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-reschedule-time-window')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_04_reschedule_dialog_timed_en_ltr');
  });

  testWidgets('5. reschedule soft-conflict confirmation', (tester) async {
    final repo = _repo();
    repo.rescheduleResultsQueue.add(
      const CalendarScheduleMutationConfirmationRequired(_dayOffConflict),
    );
    await _pumpCalendar(tester, locale: const Locale('ar'), repo: repo);
    await _submitReschedule(tester, day: 20, reason: 'طلب العميل تغيير الموعد');
    expect(
      find.byKey(const Key('calendar-conflict-confirm-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_05_reschedule_conflict_confirm_ar_rtl');
  });

  testWidgets('6. reschedule stale-version error', (tester) async {
    final repo = _repo()
      ..rescheduleError = const CalendarException(
        code: CalendarException.staleVersion,
      );
    await _pumpCalendar(tester, locale: const Locale('en'), repo: repo);
    await _submitReschedule(tester, day: 20, reason: 'Move to next week');
    expect(
      find.text('This event changed on another screen. Refresh and try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_06_reschedule_stale_error_en_ltr');
    // Let the snackbar timer expire before the test ends.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('7. assignment dialog narrow Arabic', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('ar'),
      repo: _repo(),
      size: _narrow,
    );
    await _openAssignmentDialog(tester);
    expect(find.byKey(const Key('calendar-assign-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_07_assignment_dialog_narrow_ar_rtl');
  });

  testWidgets('8. reschedule dialog narrow English', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('en'),
      repo: _repo(),
      size: _narrow,
    );
    await _openRescheduleDialog(tester);
    expect(find.byKey(const Key('calendar-reschedule-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_08_reschedule_dialog_narrow_en_ltr');
  });

  testWidgets('9. internal meeting: Assign hidden, Reschedule shown', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('ar'),
      repo: _repoWith([_meetingEvent()]),
    );
    await _openActionsDialog(tester, _meetingEventId);
    expect(
      find.byKey(const Key('calendar-assign-$_meetingEventId')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('calendar-reschedule-$_meetingEventId')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_09_meeting_actions_no_assign_ar_rtl');
  });

  testWidgets('10. cancelled event: Assign and Reschedule hidden', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('en'),
      repo: _repoWith([_cancelledEvent()]),
    );
    await _openActionsDialog(tester, _cancelledEventId);
    expect(
      find.byKey(const Key('calendar-assign-$_cancelledEventId')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('calendar-reschedule-$_cancelledEventId')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_10_cancelled_actions_no_mutations_en_ltr');
  });

  testWidgets('11. assigned-only disappearance after reassignment', (
    tester,
  ) async {
    final repo = _repo();
    await _pumpCalendar(tester, locale: const Locale('en'), repo: repo);
    await _openAssignmentDialog(tester);
    await tester.tap(
      find.byKey(const Key('calendar-assign-candidate-emp-ahmad')),
    );
    await tester.pumpAndSettle();
    // The refresh after the successful reassignment no longer returns the
    // event: BOTH read contracts (agenda list and range summary) must agree
    // so the agenda, header count, and day-cell marker stay consistent.
    repo.listResult = sampleEventList(
      inRangeRows: const [],
      overdueRows: const [],
    );
    repo.eventCountForDate = (_) => 0;
    await tester.tap(find.byKey(const Key('calendar-assign-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Assignment saved. This event is no longer visible in your view.',
      ),
      findsOneWidget,
    );
    // No agenda card, zero events in the header, no day-cell count marker,
    // selected date preserved.
    expect(
      find.byKey(const Key('calendar-event-ink-$_assignableEventId')),
      findsNothing,
    );
    expect(find.text('0 events'), findsOneWidget);
    expect(find.text('No events on this day.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('calendar-day-2026-7-14')),
        matching: find.text('1'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm8_11_assigned_only_disappearance_en_ltr');
    // Let the snackbar timer expire before the test ends.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
