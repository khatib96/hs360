/// Shared helpers for Phase 7 M12 Gate E live acceptance driver.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/l10n/app_localizations.dart';

final gateERootKey = GlobalKey();

Future<void> gateESignIn(WidgetTester tester, AppLocalizations l10n) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'owner@hayat-secret.test',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
  await tester.tap(find.widgetWithText(FilledButton, l10n.signIn));
  await tester.pumpAndSettle(const Duration(seconds: 12));
  expect(find.text(l10n.navCalendar), findsWidgets);
}

Future<void> gateEGoCalendar(WidgetTester tester, AppLocalizations l10n) async {
  final nav = find.text(l10n.navCalendar);
  if (nav.evaluate().isNotEmpty) {
    await tester.tap(nav.first);
  } else {
    final element = tester.element(find.byType(Scaffold).first);
    GoRouter.of(element).go(AppRoutes.calendar);
  }
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> gateEOpenCalendarSettings(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final nav = find.text(l10n.navCalendarSettings);
  if (nav.evaluate().isNotEmpty) {
    await tester.tap(nav.first);
  } else {
    final element = tester.element(find.text(l10n.navCalendar).first);
    GoRouter.of(element).go(AppRoutes.calendarSettings);
  }
  await tester.pumpAndSettle(const Duration(seconds: 6));
  expect(find.byKey(const Key('calendar-settings-list')), findsOneWidget);
}

Future<void> gateEForceCalendarReload(WidgetTester tester) async {
  final next = find.byKey(const Key('calendar-next-month'));
  final prev = find.byKey(const Key('calendar-prev-month'));
  expect(next, findsOneWidget);
  expect(prev, findsOneWidget);
  await tester.tap(next);
  await tester.pumpAndSettle(const Duration(seconds: 4));
  await tester.tap(prev);
  await tester.pumpAndSettle(const Duration(seconds: 4));
}

Future<void> gateEScrollSettingsToWde(WidgetTester tester) async {
  final list = find.byKey(const Key('calendar-settings-list'));
  expect(list, findsOneWidget);
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    find.byKey(const Key('calendar-wde-section')),
    400,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.byKey(const Key('calendar-wde-section')), findsOneWidget);
}

Future<void> gateESelectDay(WidgetTester tester, DateTime day) async {
  final key = Key('calendar-day-${day.year}-${day.month}-${day.day}');
  final finder = find.byKey(key);
  expect(finder, findsWidgets, reason: 'day cell $day must be visible');
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> gateEOpenCreateManual(WidgetTester tester) async {
  final fab = find.byKey(const Key('calendar-create-event'));
  expect(fab, findsWidgets);
  await tester.ensureVisible(fab.first);
  await tester.tap(fab.first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(find.byKey(const Key('calendar-create-event-dialog')), findsOneWidget);
}

Future<void> gateEPickDropdown(
  WidgetTester tester, {
  required Key fieldKey,
  required String optionText,
}) async {
  await tester.ensureVisible(find.byKey(fieldKey));
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  final option = find.text(optionText).last;
  expect(option, findsOneWidget, reason: 'dropdown option "$optionText"');
  await tester.tap(option);
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> gateEFillBothTitles(
  WidgetTester tester, {
  required String titleAr,
  required String titleEn,
}) async {
  await tester.enterText(
    find.byKey(const Key('calendar-manual-title-ar')),
    titleAr,
  );
  await tester.enterText(
    find.byKey(const Key('calendar-manual-title-en')),
    titleEn,
  );
  await tester.pumpAndSettle();
}

Future<void> gateESelectParticipantNamed(
  WidgetTester tester, {
  required String nameEn,
  required String nameAr,
}) async {
  final en = find.textContaining(nameEn);
  final ar = find.textContaining(nameAr);
  final target = en.evaluate().isNotEmpty ? en.first : ar.first;
  expect(
    en.evaluate().isNotEmpty || ar.evaluate().isNotEmpty,
    isTrue,
    reason: 'participant $nameEn / $nameAr required',
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> gateESubmitManualCreate(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('calendar-manual-event-submit')),
  );
  await tester.tap(find.byKey(const Key('calendar-manual-event-submit')));
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

Future<void> gateEAckNonWorkingDayIfPresent(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final dialog = find.byKey(const Key('calendar-conflict-confirm-dialog'));
  if (dialog.evaluate().isEmpty) return;

  final ack = find.byKey(const Key('calendar-ack-non-working'));
  if (ack.evaluate().isNotEmpty) {
    await tester.tap(ack);
    await tester.pumpAndSettle();
  }
  final reason = find.byKey(const Key('calendar-day-off-override-reason'));
  if (reason.evaluate().isNotEmpty) {
    await tester.enterText(reason, 'P7M12 Gate E soft-conflict override');
    await tester.pumpAndSettle();
  }
  final overlap = find.byKey(const Key('calendar-ack-overlap'));
  if (overlap.evaluate().isNotEmpty) {
    await tester.tap(overlap);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('calendar-conflict-confirm-submit')));
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

Future<void> gateEPickMaterialDate(WidgetTester tester, DateTime day) async {
  // Material date picker: select day number then confirm.
  final dayText = find.text('${day.day}');
  expect(dayText, findsWidgets, reason: 'date picker day ${day.day}');
  await tester.tap(dayText.last);
  await tester.pumpAndSettle();
  Finder? confirm;
  // Flutter Material ar uses حسنًا for okButtonLabel (not موافق).
  for (final label in const [
    'OK',
    'حسنًا',
    'حسناً',
    'موافق',
    'Done',
    'تم',
    'تأكيد',
  ]) {
    final f = find.text(label);
    if (f.evaluate().isNotEmpty) {
      confirm = f;
      break;
    }
  }
  if (confirm == null) {
    final buttons = find.byType(TextButton);
    expect(
      buttons,
      findsWidgets,
      reason: 'date picker confirm TextButton fallback',
    );
    confirm = buttons;
  }
  expect(confirm, isNotNull, reason: 'date picker confirm action');
  await tester.tap(confirm.last);
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> gateECapture(
  WidgetTester tester,
  String evidenceDir,
  String name,
) async {
  final boundary =
      gateERootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late final Uint8List pngBytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    pngBytes = byteData!.buffer.asUint8List();
  });

  Directory dir;
  try {
    dir = Directory(evidenceDir)..createSync(recursive: true);
    final probe = File('${dir.path}/.write_probe');
    probe.writeAsBytesSync(const [1]);
    probe.deleteSync();
  } on FileSystemException {
    final tmp = Directory.systemTemp.createTempSync('p7m12_gate_e_');
    dir = Directory('${tmp.path}/${evidenceDir.split('/').last}')
      ..createSync(recursive: true);
    // ignore: avoid_print
    print('P7M12_EVIDENCE_FALLBACK_DIR=${dir.path}');
  }

  final out = File('${dir.path}/$name.png');
  out.writeAsBytesSync(pngBytes);
  expect(out.existsSync(), isTrue, reason: 'screenshot must be written: $name');
  // ignore: avoid_print
  print('P7M12_EVIDENCE_PNG=${out.path}');
}
