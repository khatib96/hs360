// Supporting (NOT live-app) screenshot harness for Phase 7 M6/M7A calendar UI.
// Renders CalendarScreen with FakeCalendarRepository sample data (including a
// timed internal meeting for Timed vs Day-tasks agenda headers), then writes
// PNGs to build/screenshots/.
//
// These are supporting renders only. Visual acceptance still requires live
// macOS app screenshots from an authenticated session when the owner prefers.
//
// Run: flutter test test/screenshots/calendar_m6_screenshots.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_event_participant.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_meeting_mode.dart';
import 'package:hs360/features/calendar/domain/calendar_time_window.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_conflict_confirm_dialog.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/domain/customer.dart';
import 'package:hs360/features/customers/domain/customer_service_location.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';
import 'package:hs360/features/customers/domain/service_location_type.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/calendar/fake_calendar_repository.dart';
import '../features/contracts/fake_contract_repository.dart';
import '../features/customers/fake_customer_repository.dart';
import '../features/customers/fake_customer_service_location_repository.dart';

part 'calendar_m6_screenshot_support.dart';

void main() {
  setUpAll(_loadFonts);

  late CalendarClock previous;

  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() => calendarClock = previous);

  testWidgets('calendar mixed timed/date-only (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await _revealAgenda(tester);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_calendar_mixed_ar_rtl');
  });

  testWidgets('calendar mixed timed/date-only (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await _revealAgenda(tester);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_calendar_mixed_en_ltr');
  });

  testWidgets('create manual event dialog (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await tester.tap(find.byKey(const Key('calendar-create-event')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-create-event-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-manual-scheduled-date')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_create_manual_dialog_ar_rtl');
  });

  testWidgets('create manual event dialog (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await tester.tap(find.byKey(const Key('calendar-create-event')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-create-event-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-manual-scheduled-date')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_create_manual_dialog_en_ltr');
  });

  testWidgets('internal meeting online mode/link (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await tester.tap(find.byKey(const Key('calendar-create-event')));
    await tester.pumpAndSettle();
    await _selectManualType(tester, CalendarEventType.internalMeeting);
    await _selectMeetingModeOnline(tester);
    await tester.enterText(
      find.byKey(const Key('calendar-manual-meeting-url')),
      'https://meet.example.com/hs360-standup',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-manual-meeting-url')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_meeting_online_ar_rtl');
  });

  testWidgets('internal meeting online mode/link (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await tester.tap(find.byKey(const Key('calendar-create-event')));
    await tester.pumpAndSettle();
    await _selectManualType(tester, CalendarEventType.internalMeeting);
    await _selectMeetingModeOnline(tester);
    await tester.enterText(
      find.byKey(const Key('calendar-manual-meeting-url')),
      'https://meet.example.com/hs360-standup',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_meeting_online_en_ltr');
  });

  testWidgets('participant selection with selected (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await tester.tap(find.byKey(const Key('calendar-create-event')));
    await tester.pumpAndSettle();
    await _scrollDialogTo(tester, const Key('calendar-manual-participant-search'));
    final search = find.byKey(const Key('calendar-manual-participant-search'));
    await tester.enterText(search, 'أحمد');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_participant_selection_ar_rtl');
  });

  testWidgets('participant selection with selected (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await tester.tap(find.byKey(const Key('calendar-create-event')));
    await tester.pumpAndSettle();
    await _scrollDialogTo(tester, const Key('calendar-manual-participant-search'));
    final search = find.byKey(const Key('calendar-manual-participant-search'));
    await tester.enterText(search, 'Ahmad');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_participant_selection_en_ltr');
  });

  testWidgets('customer visit with customer/location/contract (AR RTL)', (
    tester,
  ) async {
    await _pumpCustomerVisitDialog(tester, locale: const Locale('ar'));
    expect(find.byKey(const Key('calendar-manual-location')), findsOneWidget);
    expect(find.byKey(const Key('calendar-manual-contract')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_customer_visit_ar_rtl');
  });

  testWidgets('customer visit with customer/location/contract (EN LTR)', (
    tester,
  ) async {
    await _pumpCustomerVisitDialog(tester, locale: const Locale('en'));
    expect(find.byKey(const Key('calendar-manual-location')), findsOneWidget);
    expect(find.byKey(const Key('calendar-manual-contract')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_customer_visit_en_ltr');
  });

  testWidgets('edit dialog (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    await tester.tap(find.byKey(const Key('calendar-edit-manual-evt-meeting')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-edit-event-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-manual-scheduled-date')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_edit_dialog_ar_rtl');
  });

  testWidgets('edit dialog (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    await tester.tap(find.byKey(const Key('calendar-edit-manual-evt-meeting')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-edit-event-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-manual-scheduled-date')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_edit_dialog_en_ltr');
  });

  testWidgets('event action dialog (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    expect(
      find.byKey(const Key('calendar-event-actions-evt-meeting')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_event_actions_ar_rtl');
  });

  testWidgets('event action dialog (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    expect(
      find.byKey(const Key('calendar-event-actions-evt-meeting')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_event_actions_en_ltr');
  });

  testWidgets('event action dialog narrow (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _narrow,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    expect(
      find.byKey(const Key('calendar-event-actions-evt-meeting')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_event_actions_narrow_ar_rtl');
  });

  testWidgets('event action dialog narrow (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _narrow,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    expect(
      find.byKey(const Key('calendar-event-actions-evt-meeting')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_event_actions_narrow_en_ltr');
  });

  testWidgets('cancellation confirmation (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    await tester.tap(find.byKey(const Key('calendar-cancel-manual-evt-meeting')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-cancel-event-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_cancel_confirm_ar_rtl');
  });

  testWidgets('cancellation confirmation (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    await _openMeetingActions(tester);
    await tester.tap(find.byKey(const Key('calendar-cancel-manual-evt-meeting')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-cancel-event-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_cancel_confirm_en_ltr');
  });

  testWidgets('participant overlap confirmation (AR RTL)', (tester) async {
    await _pumpConflictDialog(
      tester,
      locale: const Locale('ar'),
      conflicts: const CalendarManualConflictInfo(
        scheduleWarnings: [],
        overlapWarnings: [
          {'code': 'participant_overlap', 'employee_id': 'emp-1'},
        ],
        overlapTotalCount: 2,
      ),
    );
    expect(find.byKey(const Key('calendar-ack-overlap')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_overlap_confirm_ar_rtl');
  });

  testWidgets('participant overlap confirmation (EN LTR)', (tester) async {
    await _pumpConflictDialog(
      tester,
      locale: const Locale('en'),
      conflicts: const CalendarManualConflictInfo(
        scheduleWarnings: [],
        overlapWarnings: [
          {'code': 'participant_overlap', 'employee_id': 'emp-1'},
        ],
        overlapTotalCount: 2,
      ),
    );
    expect(find.byKey(const Key('calendar-ack-overlap')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_overlap_confirm_en_ltr');
  });

  testWidgets('non-working-day override confirmation (AR RTL)', (tester) async {
    await _pumpConflictDialog(
      tester,
      locale: const Locale('ar'),
      conflicts: const CalendarManualConflictInfo(
        scheduleWarnings: [
          {'code': 'non_working_day'},
        ],
        overlapWarnings: [],
        overlapTotalCount: 0,
      ),
    );
    expect(find.byKey(const Key('calendar-ack-non-working')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-day-off-override-reason')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_non_working_day_confirm_ar_rtl');
  });

  testWidgets('non-working-day override confirmation (EN LTR)', (tester) async {
    await _pumpConflictDialog(
      tester,
      locale: const Locale('en'),
      conflicts: const CalendarManualConflictInfo(
        scheduleWarnings: [
          {'code': 'non_working_day'},
        ],
        overlapWarnings: [],
        overlapTotalCount: 0,
      ),
    );
    expect(find.byKey(const Key('calendar-ack-non-working')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-day-off-override-reason')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_non_working_day_confirm_en_ltr');
  });

  testWidgets('narrow-window layout (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _narrow,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_narrow_ar_rtl');
  });

  testWidgets('narrow-window layout (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _narrow,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7a_narrow_en_ltr');
  });
}
