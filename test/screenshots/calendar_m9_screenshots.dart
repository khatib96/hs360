// Supporting screenshot harness for Phase 7 M9 Mobile Calendar.
// Run: flutter test test/screenshots/calendar_m9_screenshots.dart
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
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_time_window.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';
import 'package:hs360/features/calendar/presentation/calendar_clock.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/calendar/fake_calendar_repository.dart';

part 'calendar_m9_screenshot_support.dart';

void main() {
  setUpAll(_loadFonts);

  late CalendarClock previous;
  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });
  tearDown(() => calendarClock = previous);

  testWidgets('1. mobile Arabic RTL today agenda', (tester) async {
    await _pumpMobile(tester, locale: const Locale('ar'), repo: _repo());
    expect(find.byKey(const Key('calendar-mobile-body')), findsOneWidget);
    expect(find.byKey(const Key('calendar-event-evt-gen')), findsOneWidget);
    expect(find.byKey(const Key('calendar-event-evt-timed')), findsOneWidget);
    await _capture(tester, 'm9_01_mobile_today_agenda_ar_rtl');
  });

  testWidgets('2. mobile English LTR today agenda', (tester) async {
    await _pumpMobile(tester, locale: const Locale('en'), repo: _repo());
    await _capture(tester, 'm9_02_mobile_today_agenda_en_ltr');
  });

  testWidgets('3. another selected date', (tester) async {
    await _pumpMobile(tester, locale: const Locale('en'), repo: _repo());
    await tester.tap(find.byKey(const Key('calendar-mobile-day-2026-7-15')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-event-evt-other-day')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('calendar-event-evt-gen')), findsNothing);
    await _capture(tester, 'm9_03_selected_other_date_en_ltr');
  });

  testWidgets('4. timed manual appointment', (tester) async {
    await _pumpMobile(tester, locale: const Locale('en'), repo: _repo());
    expect(find.textContaining('09:00'), findsWidgets);
    await _capture(tester, 'm9_04_timed_manual_en_ltr');
  });

  testWidgets('5. generated untimed event', (tester) async {
    await _pumpMobile(tester, locale: const Locale('ar'), repo: _repo());
    expect(find.byKey(const Key('calendar-event-evt-gen')), findsOneWidget);
    await _capture(tester, 'm9_05_generated_untimed_ar_rtl');
  });

  testWidgets('6. day-off conflict', (tester) async {
    await _pumpMobile(
      tester,
      locale: const Locale('en'),
      repo: _conflictRepo(),
    );
    expect(
      find.byKey(const Key('calendar-agenda-working-status')),
      findsOneWidget,
    );
    expect(find.textContaining('08:00'), findsNothing);
    expect(find.textContaining('17:00'), findsNothing);
    await _capture(tester, 'm9_06_day_off_conflict_en_ltr');
  });

  testWidgets('7. exceptional working day header', (tester) async {
    await _pumpMobile(
      tester,
      locale: const Locale('en'),
      repo: _exceptionalRepo(),
    );
    expect(
      find.byKey(const Key('calendar-agenda-exception-title')),
      findsOneWidget,
    );
    expect(find.textContaining('Inventory special hours'), findsOneWidget);
    await _capture(tester, 'm9_07_exceptional_working_day_en_ltr');
  });

  testWidgets('8. assigned-only employee', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await _pumpMobile(
      tester,
      locale: const Locale('en'),
      repo: _assignedOnlyRepo(),
      session: _assignedSession(),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const Key('calendar-create-event')), findsNothing);
    expect(find.textContaining(l10n.calendarLabelAssigned), findsWidgets);
    expect(find.textContaining('Field User'), findsOneWidget);
    expect(find.text(l10n.calendarLabelUnassigned), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-filter-funnel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-filter-sheet')), findsOneWidget);
    expect(find.byKey(const Key('calendar-filter-unassigned')), findsNothing);
    expect(find.text(l10n.calendarFilterAssigned), findsNothing);
    // Dismiss sheet so the capture shows the assigned agenda (not the sheet).
    Navigator.of(
      tester.element(find.byKey(const Key('calendar-filter-sheet'))),
    ).pop();
    await tester.pumpAndSettle();

    await _capture(tester, 'm9_08_assigned_only_en_ltr');
  });

  testWidgets('9. mobile filters sheet', (tester) async {
    await _pumpMobile(tester, locale: const Locale('ar'), repo: _repo());
    await tester.tap(find.byKey(const Key('calendar-filter-funnel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-filter-sheet')), findsOneWidget);
    await _capture(tester, 'm9_09_mobile_filters_ar_rtl');
  });

  testWidgets('10. event actions with permission', (tester) async {
    await _pumpMobile(
      tester,
      locale: const Locale('en'),
      repo: _repo(),
      session: _editSession(),
    );
    await tester.tap(find.byKey(const Key('calendar-event-ink-evt-gen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-assign-evt-gen')), findsOneWidget);
    await _capture(tester, 'm9_10_event_actions_with_perms_en_ltr');
  });

  testWidgets('11. event actions without office mutations', (tester) async {
    await _pumpMobile(
      tester,
      locale: const Locale('en'),
      repo: _lockedRepo(),
      session: _assignedSession(),
    );
    await tester.tap(find.byKey(const Key('calendar-event-ink-evt-locked')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-assign-evt-locked')), findsNothing);
    await _capture(tester, 'm9_11_event_actions_no_office_en_ltr');
  });

  testWidgets('12. loading empty and tiny Android width', (tester) async {
    await _pumpMobile(
      tester,
      locale: const Locale('en'),
      repo: _emptyRepo(),
      size: const Size(320, 640),
    );
    expect(find.byKey(const Key('calendar-agenda-empty')), findsOneWidget);
    await _capture(tester, 'm9_12_empty_tiny_android_en_ltr');
  });
}
