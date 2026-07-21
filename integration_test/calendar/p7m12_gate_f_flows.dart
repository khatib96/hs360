/// Gate F live Open-with flows on real App() + local/test Supabase.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/features/calendar/presentation/calendar_directions_launcher.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_app_option.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:integration_test/integration_test.dart';
import 'package:url_launcher/url_launcher.dart';

/// Seeded mapped destination (P7M12 Mapped Branch).
const gateFMappedLat = 29.3390;
const gateFMappedLng = 48.0750;

final List<Uri> gateFLaunchedUris = <Uri>[];
final List<bool> gateFLaunchResults = <bool>[];
bool gateFSurfaceConverted = false;

/// When true (default for unit/contract only), URI is recorded but not opened.
/// Device Gate F smoke must pass `--dart-define=P7M12_GATE_F_DRY_LAUNCH=false`.
const gateFDryLaunch = bool.fromEnvironment(
  'P7M12_GATE_F_DRY_LAUNCH',
  defaultValue: true,
);

Future<bool> gateFRecordingLaunch(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  gateFLaunchedUris.add(uri);
  // ignore: avoid_print
  print('P7M12_GATE_F_LAUNCH_URI=$uri');
  if (gateFDryLaunch) {
    // Contract-only path — not proof of external app open.
    gateFLaunchResults.add(true);
    // ignore: avoid_print
    print('P7M12_GATE_F_DRY_LAUNCH=true');
    return true;
  }
  try {
    final ok = await launchUrl(uri, mode: mode);
    gateFLaunchResults.add(ok);
    // ignore: avoid_print
    print('P7M12_GATE_F_LAUNCH_RESULT=$ok');
    return ok;
  } catch (e) {
    gateFLaunchResults.add(false);
    // ignore: avoid_print
    print('P7M12_GATE_F_LAUNCH_RESULT=false error=$e');
    return false;
  }
}

CalendarDirectionsLauncher gateFInstrumentedLauncher() =>
    CalendarDirectionsLauncher(launcher: gateFRecordingLaunch);

/// Bounded pumps — map tile retry / shimmer can make pumpAndSettle hang forever.
Future<void> gateFPumpFrames(
  WidgetTester tester, {
  int frames = 40,
  Duration step = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

Future<void> gateFSignIn(WidgetTester tester, AppLocalizations l10n) async {
  expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'owner@hayat-secret.test',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
  await tester.tap(find.widgetWithText(FilledButton, l10n.signIn));
  await gateFPumpFrames(tester, frames: 80);
  // Physical iOS may show Local Network permission first; wait longer.
  for (var i = 0; i < 60; i++) {
    if (find.widgetWithText(FilledButton, l10n.signIn).evaluate().isEmpty) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  expect(
    find.widgetWithText(FilledButton, l10n.signIn),
    findsNothing,
    reason:
        'sign-in must succeed — on physical iOS allow Local Network for HS360 '
        'and confirm MAC_LAN_IP:54321 is reachable',
  );

  final openDrawer = find.byTooltip('Open navigation menu');
  if (openDrawer.evaluate().isNotEmpty) {
    await tester.tap(openDrawer);
    await gateFPumpFrames(tester, frames: 12);
  }
  final calendarNav = find.text(l10n.navCalendar);
  if (calendarNav.evaluate().isNotEmpty) {
    await tester.tap(calendarNav.first);
  } else {
    final element = tester.element(find.byType(Scaffold).first);
    GoRouter.of(element).go(AppRoutes.calendar);
  }
  await gateFPumpFrames(tester, frames: 40);
  expect(
    find.byKey(const Key('calendar-layout-body')),
    findsOneWidget,
    reason: 'calendar body must load after Gate F sign-in',
  );
}

Future<void> gateFOpenRouteForFieldAgent(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final now = DateTime.now();
  final routeDay = _nextIsoWeekdayLocal(now, DateTime.friday);
  final element = tester.element(find.byType(Scaffold).first);
  GoRouter.of(element).go(AppRoutes.calendarRoutePath(date: routeDay));
  await gateFPumpFrames(tester, frames: 40);

  const fieldAgentKey = Key(
    'calendar-route-employee-00000000-0000-0000-0000-000000000602',
  );
  expect(find.byKey(fieldAgentKey), findsOneWidget);
  await tester.ensureVisible(find.byKey(fieldAgentKey));
  await tester.tap(find.byKey(fieldAgentKey));
  await gateFPumpFrames(tester, frames: 50);
  expect(find.byKey(const Key('calendar-route-day-error')), findsNothing);
}

/// Host harvest via extended driver `onScreenshot` (Mac filesystem).
Future<void> gateFCapture(WidgetTester tester, String name) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  if (defaultTargetPlatform == TargetPlatform.android &&
      !gateFSurfaceConverted) {
    await binding.convertFlutterSurfaceToImage();
    gateFSurfaceConverted = true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump(const Duration(milliseconds: 300));
  final bytes = await binding.takeScreenshot(name);
  expect(
    bytes.length,
    greaterThanOrEqualTo(2048),
    reason: 'screenshot $name must be a non-trivial PNG',
  );
  // ignore: avoid_print
  print('P7M12_GATE_F_SCREENSHOT=$name bytes=${bytes.length}');
}

Finder gateFDirectionsButtonForTitle(String needle) {
  // Caller should ensureVisible; re-check because ListView.builder unmounts.
  final title = find.textContaining(needle);
  expect(title, findsWidgets, reason: 'route point title containing $needle');
  final byKey = find.descendant(
    of: find.ancestor(of: title.first, matching: find.byType(Card)),
    matching: find.byWidgetPredicate(
      (w) =>
          w.key is Key &&
          (w.key as Key).toString().contains('calendar-route-directions-'),
    ),
  );
  expect(
    byKey,
    findsOneWidget,
    reason:
        'Directions for "$needle" must be under that card (no global fallback)',
  );
  return byKey.first;
}

Future<void> gateFTapDirectionsForMapped(
  WidgetTester tester, {
  required String mappedNeedle,
}) async {
  await gateFEnsureVisibleNeedle(tester, mappedNeedle);
  final btn = gateFDirectionsButtonForTitle(mappedNeedle);
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await gateFPumpFrames(tester, frames: 24);
  expect(
    find.byKey(const Key('calendar-open-with-title')),
    findsOneWidget,
    reason: 'Open-with sheet must appear before any map launch',
  );
}

Future<void> gateFAssertOpenWithOptions({
  required TargetPlatform platform,
  required List<CalendarMapAppKind> mustInclude,
  required List<CalendarMapAppKind> mustExclude,
}) async {
  for (final kind in mustInclude) {
    expect(
      find.byKey(Key('calendar-open-with-${kind.name}')),
      findsOneWidget,
      reason: '${kind.name} must be listed on $platform',
    );
  }
  for (final kind in mustExclude) {
    expect(
      find.byKey(Key('calendar-open-with-${kind.name}')),
      findsNothing,
      reason: '${kind.name} must not be listed',
    );
  }
}

Future<void> gateFCancelOpenWith(WidgetTester tester) async {
  final before = List<Uri>.from(gateFLaunchedUris);
  await tester.tap(find.byKey(const Key('calendar-open-with-cancel')));
  await gateFPumpFrames(tester, frames: 12);
  expect(find.byKey(const Key('calendar-open-with-title')), findsNothing);
  expect(
    gateFLaunchedUris.length,
    before.length,
    reason: 'Cancel must not launch a map app',
  );
  expect(find.byKey(const Key('calendar-route-point-list')), findsOneWidget);
}

/// Selects an Open-with option. Real smoke requires launchUrl==true.
Future<void> gateFLaunchOption(
  WidgetTester tester,
  CalendarMapAppKind kind, {
  required String expectedUriSubstring,
  required String awaitExternalToken,
}) async {
  gateFLaunchedUris.clear();
  gateFLaunchResults.clear();
  final option = find.byKey(Key('calendar-open-with-${kind.name}'));
  expect(option, findsOneWidget);
  await tester.tap(option);
  // Never pumpAndSettle after external launch — backgrounding freezes frames
  // and settle never completes (hangs before AWAIT_EXTERNAL / host proof).
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (gateFLaunchedUris.isNotEmpty && gateFLaunchResults.isNotEmpty) {
      break;
    }
  }

  expect(gateFLaunchedUris, isNotEmpty, reason: '${kind.name} must launch');
  final uri = gateFLaunchedUris.last;
  expect(uri.toString(), contains(expectedUriSubstring));

  if (!gateFDryLaunch) {
    expect(
      gateFLaunchResults,
      isNotEmpty,
      reason: 'real launch must record launchUrl result',
    );
    expect(
      gateFLaunchResults.last,
      isTrue,
      reason: 'launchUrl must return true for ${kind.name} (got false)',
    );
    // Host watcher polls this token, verifies foreground, captures device shot,
    // then am-starts com.hs360.hs360 back to foreground.
    // ignore: avoid_print
    print('P7M12_GATE_F_AWAIT_EXTERNAL=$awaitExternalToken');
    // ignore: avoid_print
    print('P7M12_GATE_F_AWAIT_URI=$uri');
    // Wall-clock wait only — do NOT tester.pump while backgrounded (hangs).
    await Future<void>.delayed(const Duration(seconds: 18));
    // ignore: avoid_print
    print('P7M12_GATE_F_EXTERNAL_WAIT_DONE=$awaitExternalToken');
    // One short pump burst after host restore — avoid long pump loops on stale surface.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  } else {
    // ignore: avoid_print
    print('P7M12_GATE_F_LAUNCH_OK kind=${kind.name} uri=$uri (dry)');
  }
}

Future<void> gateFAssertNoDirectionsForNeedle(
  WidgetTester tester,
  String needle,
) async {
  await gateFEnsureVisibleNeedle(tester, needle);
  final title = find.textContaining(needle);
  expect(title, findsWidgets, reason: 'expected route point $needle');
  final directionsUnder = find.descendant(
    of: find.ancestor(of: title.first, matching: find.byType(Card)),
    matching: find.byWidgetPredicate(
      (w) =>
          w.key is Key &&
          (w.key as Key).toString().contains('calendar-route-directions-'),
    ),
  );
  expect(
    directionsUnder,
    findsNothing,
    reason: '$needle must not show Directions',
  );
}

Future<void> gateFEnsureVisibleNeedle(
  WidgetTester tester,
  String needle,
) async {
  if (find.textContaining(needle).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.textContaining(needle).first);
    await gateFPumpFrames(tester, frames: 4);
    return;
  }
  final routeList = find.byKey(const Key('calendar-route-point-list'));
  expect(routeList, findsOneWidget);
  // Scroll down then up — Unmapped may sit below Mapped/UrlOnly.
  for (var i = 0; i < 10; i++) {
    await tester.drag(routeList, const Offset(0, -280));
    await gateFPumpFrames(tester, frames: 4);
    if (find.textContaining(needle).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.textContaining(needle).first);
      await gateFPumpFrames(tester, frames: 4);
      return;
    }
  }
  for (var i = 0; i < 10; i++) {
    await tester.drag(routeList, const Offset(0, 280));
    await gateFPumpFrames(tester, frames: 4);
    if (find.textContaining(needle).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.textContaining(needle).first);
      await gateFPumpFrames(tester, frames: 4);
      return;
    }
  }
  fail('Could not scroll to route point containing "$needle"');
}

Future<void> gateFOpenUrlOnlySheet(
  WidgetTester tester, {
  required String urlOnlyNeedle,
}) async {
  await gateFEnsureVisibleNeedle(tester, urlOnlyNeedle);
  final title = find.textContaining(urlOnlyNeedle);
  expect(
    title,
    findsWidgets,
    reason: 'url_only visit "$urlOnlyNeedle" must be visible (not skippable)',
  );

  final directionsUnder = find.descendant(
    of: find.ancestor(of: title.first, matching: find.byType(Card)),
    matching: find.byWidgetPredicate(
      (w) =>
          w.key is Key &&
          (w.key as Key).toString().contains('calendar-route-directions-'),
    ),
  );

  if (directionsUnder.evaluate().isNotEmpty) {
    await tester.ensureVisible(directionsUnder.first);
    await tester.tap(directionsUnder.first);
  } else {
    final actions = find.descendant(
      of: find.ancestor(of: title.first, matching: find.byType(Card)),
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is Key &&
            (w.key as Key).toString().contains('calendar-route-point-actions-'),
      ),
    );
    expect(actions, findsOneWidget);
    await tester.tap(actions.first);
    await gateFPumpFrames(tester, frames: 16);
    final dirAction = find.byWidgetPredicate(
      (w) =>
          w.key is Key &&
          (w.key as Key).toString().contains('calendar-directions-action-'),
    );
    expect(dirAction, findsOneWidget);
    await tester.tap(dirAction.first);
  }

  await gateFPumpFrames(tester, frames: 24);
  expect(find.byKey(const Key('calendar-open-with-title')), findsOneWidget);
  expect(find.byKey(const Key('calendar-open-with-browser')), findsOneWidget);
  expect(find.byKey(const Key('calendar-open-with-googleMaps')), findsNothing);
  expect(find.byKey(const Key('calendar-open-with-appleMaps')), findsNothing);
}

DateTime _nextIsoWeekdayLocal(DateTime from, int weekday) {
  var d = DateTime(from.year, from.month, from.day);
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}
