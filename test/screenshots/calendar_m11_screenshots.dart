// Phase 7 M11 deep-link / route-scope visual evidence.
// Run: flutter test test/screenshots/calendar_m11_screenshots.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/presentation/calendar_clock.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/features/contracts/presentation/widgets/contract_upcoming_schedule_section.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/presentation/widgets/customer_detail_header.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/calendar/fake_calendar_repository.dart';
import '../features/contracts/fake_contract_repository.dart';
import '../features/customers/fake_customer_repository.dart';
import '../features/customers/fake_customer_service_location_repository.dart';

part 'calendar_m11_screenshot_support.dart';

void main() {
  setUpAll(_loadFonts);

  late CalendarClock previous;
  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });
  tearDown(() => calendarClock = previous);

  testWidgets('01 customer scope mobile 360 EN', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('en'),
      size: _phone360,
      customerId: _customerId,
    );
    expect(find.byKey(const Key('calendar-route-scope-banner')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-scope-customer-chip')), findsOneWidget);
    await _capture(tester, 'm11_01_customer_scope_mobile_360_en_ltr');
  });

  testWidgets('02 customer scope mobile 360 AR', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('ar'),
      size: _phone360,
      customerId: _customerId,
    );
    await _capture(tester, 'm11_02_customer_scope_mobile_360_ar_rtl');
  });

  testWidgets('03 contract scope mobile 412 EN', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('en'),
      size: _phone412,
      customerId: _customerId,
      contractId: _contractId,
    );
    expect(find.byKey(const Key('calendar-route-scope-contract-chip')), findsOneWidget);
    await _capture(tester, 'm11_03_contract_scope_mobile_412_en_ltr');
  });

  testWidgets('04 contract scope mobile 412 AR', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('ar'),
      size: _phone412,
      customerId: _customerId,
      contractId: _contractId,
    );
    await _capture(tester, 'm11_04_contract_scope_mobile_412_ar_rtl');
  });

  testWidgets('05 clear filter desktop EN — before and after', (tester) async {
    final router = await _pumpCalendarRouter(
      tester,
      locale: const Locale('en'),
      size: _desktop,
      customerId: _customerId,
    );
    expect(find.byKey(const Key('calendar-route-scope-clear')), findsOneWidget);
    await _capture(tester, 'm11_05_clear_filter_desktop_en_ltr');

    await tester.tap(find.byKey(const Key('calendar-route-scope-clear')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('calendar-route-scope-banner')), findsNothing);
    expect(router.state.uri.queryParameters.containsKey('customerId'), isFalse);
    await _capture(tester, 'm11_05b_after_clear_desktop_en_ltr');
  });

  testWidgets('06 clear filter desktop AR — before and after', (tester) async {
    final router = await _pumpCalendarRouter(
      tester,
      locale: const Locale('ar'),
      size: _desktop,
      customerId: _customerId,
    );
    await _capture(tester, 'm11_06_clear_filter_desktop_ar_rtl');

    await tester.tap(find.byKey(const Key('calendar-route-scope-clear')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('calendar-route-scope-banner')), findsNothing);
    expect(router.state.uri.queryParameters.containsKey('customerId'), isFalse);
    await _capture(tester, 'm11_06b_after_clear_desktop_ar_rtl');
  });

  testWidgets('07 text scale 2.0 customer scope', (tester) async {
    await _pumpCalendar(
      tester,
      locale: const Locale('en'),
      size: _phone360,
      customerId: _customerId,
      textScale: 2.0,
    );
    await _capture(tester, 'm11_07_customer_scope_text_scale_2_en');
  });

  testWidgets('08 customer entry visible (production header)', (tester) async {
    await _pumpCustomerHeader(
      tester,
      locale: const Locale('en'),
      permissions: const {'customers.view', 'calendar.view'},
    );
    expect(find.byKey(const Key('customer-view-in-calendar')), findsOneWidget);
    await _capture(tester, 'm11_08_customer_entry_visible_en');
  });

  testWidgets('09 customer entry hidden (production header)', (tester) async {
    await _pumpCustomerHeader(
      tester,
      locale: const Locale('en'),
      permissions: const {'customers.view'},
    );
    expect(find.byKey(const Key('customer-view-in-calendar')), findsNothing);
    await _capture(tester, 'm11_09_customer_entry_hidden_en');
  });

  testWidgets('10 contract entry visible (production section)', (tester) async {
    await _pumpContractSchedule(
      tester,
      locale: const Locale('en'),
      permissions: const {'calendar.view'},
    );
    expect(find.byKey(const Key('contract-view-in-calendar')), findsOneWidget);
    await _capture(tester, 'm11_10_contract_entry_visible_en');
  });

  testWidgets('11 contract entry hidden (production section)', (tester) async {
    await _pumpContractSchedule(
      tester,
      locale: const Locale('en'),
      permissions: const {'customers.view'},
    );
    expect(find.byKey(const Key('contract-view-in-calendar')), findsNothing);
    await _capture(tester, 'm11_11_contract_entry_hidden_en');
  });
}
