// Supporting screenshot harness for Phase 7 M10 Route View (corrective pass).
// Run: flutter test test/screenshots/calendar_m10_screenshots.dart
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
import 'package:hs360/features/calendar/domain/calendar_route_employee.dart';
import 'package:hs360/features/calendar/domain/calendar_route_location_state.dart';
import 'package:hs360/features/calendar/domain/calendar_route_point.dart';
import 'package:hs360/features/calendar/domain/calendar_route_result.dart';
import 'package:hs360/features/calendar/presentation/calendar_directions_providers.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_app_resolver.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_surface.dart';
import 'package:hs360/features/calendar/presentation/calendar_route_screen.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_route_map_panel.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/calendar/fake_calendar_repository.dart';
import '../features/calendar/fake_calendar_route_repository.dart';

part 'calendar_m10_screenshot_support.dart';

void main() {
  setUpAll(_loadFonts);

  testWidgets('01 assigned mobile 360 EN', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone360,
    );
    await _capture(tester, 'm10_01_assigned_mobile_360_en_ltr');
  });

  testWidgets('02 assigned mobile 360 AR', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('ar'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone360,
    );
    expect(find.byKey(const Key('calendar-route-prev-day')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-next-day')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-prev-day-icon')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-next-day-icon')), findsOneWidget);
    await _capture(tester, 'm10_02_assigned_mobile_360_ar_rtl');
  });

  testWidgets('03 assigned mobile 412 EN', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone412,
    );
    await _capture(tester, 'm10_03_assigned_mobile_412_en_ltr');
  });

  testWidgets('04 assigned mobile 412 AR', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('ar'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone412,
    );
    expect(find.byKey(const Key('calendar-route-prev-day')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-next-day')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-prev-day-icon')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-next-day-icon')), findsOneWidget);
    await _capture(tester, 'm10_04_assigned_mobile_412_ar_rtl');
  });

  testWidgets('05 assigned desktop EN', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
    );
    await _capture(tester, 'm10_05_assigned_desktop_en_ltr');
  });

  testWidgets('06 assigned desktop AR', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('ar'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
    );
    await _capture(tester, 'm10_06_assigned_desktop_ar_rtl');
  });

  testWidgets('07 mixed mapped + url_only + missing/invalid', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _mixedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
    );
    expect(find.byKey(const Key('calendar-route-point-mapped-a')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-point-url-only-b')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-point-missing-c')), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-point-invalid-d')), findsOneWidget);
    await _capture(tester, 'm10_07_assigned_mixed_location_states_en_ltr');
  });

  testWidgets('08 tenant-wide before employee selection', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _officeRouteRepo(),
      session: _officeSession(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
    );
    expect(
      find.byKey(const Key('calendar-route-select-employee-prompt')),
      findsOneWidget,
    );
    await _capture(tester, 'm10_08_tenant_wide_before_employee_en_ltr');
  });

  testWidgets('09 tenant-wide after employee selection', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _officeRouteRepo(),
      session: _officeSession(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
    );
    await tester.tap(find.byKey(const Key('calendar-route-employee-emp-1')));
    await tester.pumpAndSettle();
    await _capture(tester, 'm10_09_tenant_wide_after_employee_en_ltr');
  });

  testWidgets('10 selected marker syncs with list row', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
    );
    await tester.tap(find.byKey(const Key('calendar-route-point-ink-route-mapped-1')));
    await tester.pumpAndSettle();
    await _capture(tester, 'm10_10_selected_marker_list_sync_en_ltr');
  });

  testWidgets('11 Open with sheet EN', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone360,
    );
    await tester.tap(
      find.byKey(const Key('calendar-route-directions-route-mapped-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-open-with-title')), findsOneWidget);
    await _capture(tester, 'm10_11_open_with_sheet_en_ltr');
  });

  testWidgets('12 Open with sheet AR', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('ar'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone360,
    );
    await tester.tap(
      find.byKey(const Key('calendar-route-directions-route-mapped-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('فتح باستخدام'), findsOneWidget);
    await _capture(tester, 'm10_12_open_with_sheet_ar_rtl');
  });

  testWidgets('13 Directions inside actions dialog', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone360,
    );
    await tester.tap(
      find.byKey(const Key('calendar-route-point-actions-route-mapped-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-directions-action-route-mapped-1')),
      findsOneWidget,
    );
    await _capture(tester, 'm10_13_directions_in_actions_dialog_en_ltr');
  });

  testWidgets('14 tile failure + Retry with list visible', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
      mapSurfaceBuilder: _failingMapSurfaceBuilder,
    );
    expect(find.byKey(const Key('calendar-route-tile-failure')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-route-point-route-mapped-1')),
      findsOneWidget,
    );
    final scheme = Theme.of(
      tester.element(find.byKey(const Key('calendar-route-tile-failure'))),
    ).colorScheme;
    final retryText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('calendar-route-tile-retry')),
        matching: find.byType(Text),
      ),
    );
    expect(retryText.style?.color, scheme.onErrorContainer);
    await _capture(tester, 'm10_14_tile_failure_retry_list_visible_en_ltr');
  });

  testWidgets('15 truncation warning', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _truncatedRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _phone360,
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.calendarRouteTruncatedWarning), findsOneWidget);
    await _capture(tester, 'm10_15_truncation_warning_en_ltr');
  });

  testWidgets('16 invalid date', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _assignedRouteRepo(),
      dateQueryParam: 'not-a-date',
      size: _phone360,
    );
    expect(find.byKey(const Key('calendar-route-invalid-date')), findsOneWidget);
    await _capture(tester, 'm10_16_invalid_date_en_ltr');
  });

  testWidgets('17 same-coordinate cluster', (tester) async {
    await _pumpRoute(
      tester,
      locale: const Locale('en'),
      repo: _clusterRouteRepo(),
      dateQueryParam: '2026-07-14',
      size: _desktop,
    );
    expect(find.byKey(const Key('calendar-map-marker-cluster-1')), findsOneWidget);
    await _capture(tester, 'm10_17_same_coordinate_cluster_en_ltr');
  });
}
