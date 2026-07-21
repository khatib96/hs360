/// Gate E live story flows (manual create, WDE lifecycle, route degrade).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/l10n/app_localizations.dart';

import 'p7m12_gate_e_helpers.dart';

Future<void> gateECreateUntimedTask(
  WidgetTester tester,
  AppLocalizations l10n,
  String tag,
) async {
  final evidenceDir = const String.fromEnvironment(
    'P7M12_EVIDENCE_DIR',
    defaultValue: '/tmp/p7m12_gate_e',
  );
  await gateEOpenCreateManual(tester);
  await gateECapture(tester, evidenceDir, 'ge_${tag}_07_create_manual_dialog');
  await gateEPickDropdown(
    tester,
    fieldKey: const Key('calendar-manual-type'),
    optionText: l10n.calendarEventTypeInternalTask,
  );
  await gateEFillBothTitles(
    tester,
    titleAr: 'مهمة بدون وقت P7M12',
    titleEn: 'P7M12 Untimed Task',
  );
  final setTime = tester.widget<SwitchListTile>(
    find.byKey(const Key('calendar-manual-set-time')),
  );
  expect(setTime.value, isFalse);
  await gateESubmitManualCreate(tester);
  await gateEAckNonWorkingDayIfPresent(tester, l10n);
  expect(find.byKey(const Key('calendar-create-event-dialog')), findsNothing);
}

Future<void> gateECreateTimedMeeting(
  WidgetTester tester,
  AppLocalizations l10n,
  String tag,
) async {
  final evidenceDir = const String.fromEnvironment(
    'P7M12_EVIDENCE_DIR',
    defaultValue: '/tmp/p7m12_gate_e',
  );
  await gateEOpenCreateManual(tester);
  await gateEPickDropdown(
    tester,
    fieldKey: const Key('calendar-manual-type'),
    optionText: l10n.calendarEventTypeInternalMeeting,
  );
  await gateEFillBothTitles(
    tester,
    titleAr: 'اجتماع موقوت P7M12',
    titleEn: 'P7M12 Timed Meeting',
  );
  final setTimeTile = find.byKey(const Key('calendar-manual-set-time'));
  await tester.ensureVisible(setTimeTile);
  await tester.tap(setTimeTile);
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const Key('calendar-manual-meeting-location')),
  );
  await tester.enterText(
    find.byKey(const Key('calendar-manual-meeting-location')),
    'P7M12 Meeting Room',
  );
  await gateESelectParticipantNamed(
    tester,
    nameEn: 'Warehouse Sara',
    nameAr: 'سارة',
  );
  await gateECapture(tester, evidenceDir, 'ge_${tag}_08_meeting_form');
  await gateESubmitManualCreate(tester);
  await gateEAckNonWorkingDayIfPresent(tester, l10n);
  expect(find.byKey(const Key('calendar-create-event-dialog')), findsNothing);
}

Future<void> gateERunWdeLifecycle(
  WidgetTester tester,
  AppLocalizations l10n,
  String evidenceDir,
  String tag,
  DateTime holidayDay,
) async {
  await gateEOpenCalendarSettings(tester, l10n);
  await gateEScrollSettingsToWde(tester);
  await gateECapture(tester, evidenceDir, 'ge_${tag}_11_wde_section');

  await tester.tap(find.byKey(const Key('calendar-wde-add')));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.byKey(const Key('calendar-wde-create-dialog')), findsOneWidget);

  await gateEPickDropdown(
    tester,
    fieldKey: const Key('calendar-wde-kind'),
    optionText: l10n.calendarWorkingDateExceptionKindOfficialHoliday,
  );
  await tester.tap(find.byKey(const Key('calendar-wde-start-date')));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await gateEPickMaterialDate(tester, holidayDay);
  await tester.tap(find.byKey(const Key('calendar-wde-end-date')));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await gateEPickMaterialDate(tester, holidayDay);
  await tester.enterText(
    find.byKey(const Key('calendar-wde-title-ar')),
    'عطلة P7M12',
  );
  await tester.enterText(
    find.byKey(const Key('calendar-wde-title-en')),
    'P7M12 Holiday',
  );
  await gateECapture(tester, evidenceDir, 'ge_${tag}_12_wde_create_dialog');
  await tester.tap(find.byKey(const Key('calendar-wde-submit')));
  await tester.pumpAndSettle(const Duration(seconds: 8));
  expect(find.byKey(const Key('calendar-wde-create-dialog')), findsNothing);
  expect(
    find.textContaining('P7M12 Holiday').evaluate().isNotEmpty ||
        find.textContaining('عطلة P7M12').evaluate().isNotEmpty,
    isTrue,
  );
  await gateECapture(tester, evidenceDir, 'ge_${tag}_12b_wde_list_active');

  await gateEGoCalendar(tester, l10n);
  await tester.pumpAndSettle(const Duration(seconds: 4));
  // Calendar does not auto-subscribe to WDE mutations; bounce the month
  // so range summary reloads with date_exception.
  await gateEForceCalendarReload(tester);
  await gateESelectDay(tester, holidayDay);
  await tester.pumpAndSettle(const Duration(seconds: 4));
  await gateECapture(tester, evidenceDir, 'ge_${tag}_12c_holiday_day_label');
  expect(
    find.byKey(const Key('calendar-agenda-exception-title')),
    findsOneWidget,
    reason: 'item 9: holiday must show as day exception label, not event card',
  );
  expect(
    find.textContaining('P7M12 Holiday').evaluate().isNotEmpty ||
        find.textContaining('عطلة P7M12').evaluate().isNotEmpty ||
        find
            .textContaining(
              l10n.calendarWorkingDateExceptionKindOfficialHoliday,
            )
            .evaluate()
            .isNotEmpty,
    isTrue,
  );
  final statusFinder = find.byKey(const Key('calendar-agenda-working-status'));
  expect(statusFinder, findsOneWidget);
  expect(tester.widget<Text>(statusFinder).data, l10n.calendarDayModeDayOff);

  await gateEOpenCreateManual(tester);
  await gateEPickDropdown(
    tester,
    fieldKey: const Key('calendar-manual-type'),
    optionText: l10n.calendarEventTypeInternalTask,
  );
  await gateEFillBothTitles(
    tester,
    titleAr: 'حدث على عطلة P7M12',
    titleEn: 'P7M12 Holiday Override Event',
  );
  await gateESubmitManualCreate(tester);
  expect(
    find.byKey(const Key('calendar-conflict-confirm-dialog')),
    findsOneWidget,
  );
  await gateECapture(tester, evidenceDir, 'ge_${tag}_12d_soft_conflict');
  await gateEAckNonWorkingDayIfPresent(tester, l10n);
  await gateESelectDay(tester, holidayDay);
  expect(
    find.textContaining('P7M12 Holiday Override Event').evaluate().isNotEmpty ||
        find.textContaining('حدث على عطلة P7M12').evaluate().isNotEmpty,
    isTrue,
  );
  await gateECapture(tester, evidenceDir, 'ge_${tag}_12e_override_on_holiday');

  await gateEOpenCalendarSettings(tester, l10n);
  await gateEScrollSettingsToWde(tester);
  final cancelBtn = find.byWidgetPredicate((w) {
    final key = w.key;
    if (key is! ValueKey) return false;
    return key.value.toString().startsWith('calendar-wde-cancel-');
  });
  expect(cancelBtn, findsWidgets);
  await tester.tap(cancelBtn.first);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.byKey(const Key('calendar-wde-cancel-dialog')), findsOneWidget);
  await tester.enterText(
    find.byKey(const Key('calendar-wde-cancel-reason-field')),
    'P7M12 Gate E cancel holiday',
  );
  await tester.tap(find.byKey(const Key('calendar-wde-cancel-submit')));
  await tester.pumpAndSettle(const Duration(seconds: 8));
  await gateECapture(tester, evidenceDir, 'ge_${tag}_12f_wde_cancelled');

  await gateEGoCalendar(tester, l10n);
  await tester.pumpAndSettle(const Duration(seconds: 4));
  await gateEForceCalendarReload(tester);
  await gateESelectDay(tester, holidayDay);
  await tester.pumpAndSettle(const Duration(seconds: 4));
  expect(
    find.byKey(const Key('calendar-agenda-exception-title')),
    findsNothing,
    reason: 'item 9: cancelled WDE must restore weekly resolution',
  );
  final restoredStatus = find.byKey(
    const Key('calendar-agenda-working-status'),
  );
  expect(restoredStatus, findsOneWidget);
  expect(
    tester.widget<Text>(restoredStatus).data,
    isNot(equals(l10n.calendarDayModeDayOff)),
  );
  await gateECapture(tester, evidenceDir, 'ge_${tag}_12g_weekly_restored');
}

Future<void> gateECaptureRouteMissingCoords(
  WidgetTester tester,
  AppLocalizations l10n,
  String evidenceDir,
  String tag,
) async {
  // Seeded visits are on the next Friday (away from Monday manuals).
  final now = DateTime.now();
  final routeDay = _nextIsoWeekdayLocal(now, DateTime.friday);
  await gateEGoCalendar(tester, l10n);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await gateESelectDay(tester, routeDay);
  await tester.pumpAndSettle(const Duration(seconds: 3));

  final routeBtn = find.byKey(const Key('calendar-open-route-view'));
  expect(routeBtn, findsWidgets);
  await tester.ensureVisible(routeBtn.first);
  await tester.tap(routeBtn.first);
  await tester.pumpAndSettle(const Duration(seconds: 8));

  const fieldAgentKey = Key(
    'calendar-route-employee-00000000-0000-0000-0000-000000000602',
  );
  expect(find.byKey(fieldAgentKey), findsOneWidget);
  await tester.ensureVisible(find.byKey(fieldAgentKey));
  await tester.tap(find.byKey(fieldAgentKey));
  await tester.pumpAndSettle(const Duration(seconds: 10));

  expect(
    find.byKey(const Key('calendar-route-day-error')),
    findsNothing,
    reason: 'item 20: route day must load without day-error banner',
  );
  expect(
    find.byKey(const Key('calendar-route-day-error-retry')),
    findsNothing,
    reason: 'item 20: Retry is only for real load failures',
  );

  expect(
    find.text(l10n.calendarRouteLocationUnavailable),
    findsWidgets,
    reason: 'item 20: Location unavailable must appear for missing coords',
  );

  final unmappedNeedle = tag.contains('ar')
      ? 'بلا إحداثيات'
      : 'Unmapped Route Visit';
  final mappedNeedle = tag.contains('ar') ? 'بإحداثيات' : 'Mapped Route Visit';
  expect(find.textContaining(unmappedNeedle), findsWidgets);
  expect(
    find.textContaining(mappedNeedle),
    findsWidgets,
    reason: 'item 20: mapped companion must still appear beside missing',
  );

  await gateECapture(tester, evidenceDir, 'ge_${tag}_15_route_missing_coords');

  expect(
    find.byKey(const Key('calendar-route-employee-list')),
    findsOneWidget,
    reason: 'item 20: employee list must remain usable (no crash)',
  );
}

DateTime _nextIsoWeekdayLocal(DateTime from, int weekday) {
  var d = DateTime(from.year, from.month, from.day);
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}
