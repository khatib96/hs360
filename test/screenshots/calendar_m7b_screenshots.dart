// Supporting (NOT live-app) screenshot harness for Phase 7 M7B working-date
// exceptions: the calendar-settings section (list/create/edit/cancel/overlap)
// plus the month-grid marker and selected-day closure conflict. Renders with
// Fake*Repository sample data and writes PNGs to build/screenshots/.
//
// These are supporting renders only. Visual acceptance still requires live
// macOS app screenshots from an authenticated session when the owner prefers.
//
// Run: flutter test test/screenshots/calendar_m7b_screenshots.dart
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
import 'package:hs360/features/calendar/data/calendar_settings_repository.dart';
import 'package:hs360/features/calendar/data/calendar_working_date_exception_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';
import 'package:hs360/features/calendar/domain/calendar_working_day.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_labels.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/features/calendar/presentation/calendar_settings_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/calendar/fake_calendar_repository.dart';
import '../features/calendar/fake_calendar_settings_repository.dart';
import '../features/calendar/fake_working_date_exception_repository.dart';

part 'calendar_m7b_screenshot_support.dart';

void main() {
  setUpAll(_loadFonts);

  late CalendarClock previous;
  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });
  tearDown(() => calendarClock = previous);

  testWidgets('1. exception list', (tester) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      wdeRepo: _wdeRepo(),
    );
    expect(find.byKey(const Key('calendar-wde-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_01_exception_list_en_ltr');
  });

  testWidgets('2. create official holiday', (tester) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      wdeRepo: _wdeRepo(),
    );
    await _openCreateDialog(tester);
    await _fillCreateForm(
      tester,
      kind: CalendarWorkingDateExceptionKind.officialHoliday,
      startDay: 10,
      endDay: 10,
      titleAr: 'عيد الأضحى',
      titleEn: 'Eid al-Adha',
    );
    expect(find.byKey(const Key('calendar-wde-create-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_02_create_official_holiday_ar_rtl');
  });

  testWidgets('3. create company closure range', (tester) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      wdeRepo: _wdeRepo(),
    );
    await _openCreateDialog(tester);
    await _fillCreateForm(
      tester,
      kind: CalendarWorkingDateExceptionKind.companyClosure,
      startDay: 10,
      endDay: 13,
      titleAr: 'إغلاق الشركة - الصيانة السنوية',
      titleEn: 'Company closure — annual maintenance',
    );
    expect(find.byKey(const Key('calendar-wde-create-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_03_create_company_closure_range_en_ltr');
  });

  testWidgets('4. exceptional working day with limited hours', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      wdeRepo: _wdeRepo(),
    );
    await _openCreateDialog(tester);
    await _fillCreateForm(
      tester,
      kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
      startDay: 10,
      endDay: 10,
      titleAr: 'يوم عمل استثنائي - جرد',
      titleEn: 'Exceptional working day — inventory count',
      dayMode: TenantWorkingDayMode.workingHours,
      workStart: '08:00',
      workEnd: '13:00',
    );
    expect(find.byKey(const Key('calendar-wde-day-mode')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_04_exceptional_limited_hours_ar_rtl');
  });

  testWidgets('5. exceptional 24-hour day', (tester) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      wdeRepo: _wdeRepo(),
    );
    await _openCreateDialog(tester);
    await _fillCreateForm(
      tester,
      kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
      startDay: 10,
      endDay: 10,
      titleAr: 'تشغيل على مدار الساعة',
      titleEn: '24-hour operation',
      dayMode: TenantWorkingDayMode.hours24,
    );
    expect(find.byKey(const Key('calendar-wde-day-mode')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_05_exceptional_24h_en_ltr');
  });

  testWidgets('6. edit dialog', (tester) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      wdeRepo: _wdeRepo(),
    );
    await _openEditDialog(tester, 'wde-holiday');
    expect(find.byKey(const Key('calendar-wde-edit-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_06_edit_dialog_ar_rtl');
  });

  testWidgets('7. cancel confirmation', (tester) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      wdeRepo: _wdeRepo(),
    );
    await _openCancelDialog(tester, 'wde-closure');
    await tester.enterText(
      find.byKey(const Key('calendar-wde-cancel-reason-field')),
      'No longer required — the maintenance window moved',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-wde-cancel-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_07_cancel_confirmation_en_ltr');
  });

  testWidgets('8. overlap validation', (tester) async {
    await _pumpSettings(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      wdeRepo: _wdeRepo(
        createError: const CalendarException(
          code: CalendarException.workingDateExceptionOverlap,
        ),
      ),
    );
    await _openCreateDialog(tester);
    await _fillCreateForm(
      tester,
      kind: CalendarWorkingDateExceptionKind.officialHoliday,
      startDay: 10,
      endDay: 10,
      titleAr: 'عطلة تجريبية',
      titleEn: 'Sample holiday',
    );
    await tester.tap(find.byKey(const Key('calendar-wde-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-wde-mutation-error')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_08_overlap_validation_ar_rtl');
  });

  testWidgets('9. month calendar holiday marker', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('en'),
      repo: _calendarRepoWithExceptions(),
    );
    expect(find.byKey(const Key('calendar-day-2026-7-20')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_09_month_holiday_marker_en_ltr');
  });

  testWidgets('10. selected-day closure conflict', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('ar'),
      repo: _calendarRepoWithExceptions(),
    );
    await _selectDay(tester, _closureConflictDate);
    expect(
      find.byKey(const Key('calendar-agenda-exception-title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-agenda-working-status')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_10_selected_day_closure_conflict_ar_rtl');
  });

  testWidgets('11. narrow Arabic', (tester) async {
    await _pumpSettings(
      tester,
      size: _settingsNarrow,
      locale: const Locale('ar'),
      wdeRepo: _wdeRepo(),
    );
    expect(find.byKey(const Key('calendar-wde-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_11_narrow_ar_rtl');
  });

  testWidgets('12. narrow English', (tester) async {
    await _pumpSettings(
      tester,
      size: _settingsNarrow,
      locale: const Locale('en'),
      wdeRepo: _wdeRepo(),
    );
    expect(find.byKey(const Key('calendar-wde-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'm7b_12_narrow_en_ltr');
  });
}
