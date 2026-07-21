/// Phase 7 M12 Gate E — live authenticated calendar acceptance captures.
/// Uses real [App] against local Supabase. Writes PNGs under
/// `--dart-define=P7M12_EVIDENCE_DIR=...` (macOS sandbox-aware).
///
/// Run via: `bash scripts/test/p7m12_gate_e_acceptance.sh`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/app.dart';
import 'package:hs360/core/config/env.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/network/supabase_client.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p7m12_gate_e_flows.dart';
import 'p7m12_gate_e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final localeCode = const String.fromEnvironment(
    'P7M12_LOCALE',
    defaultValue: 'en',
  );
  final evidenceDir = const String.fromEnvironment(
    'P7M12_EVIDENCE_DIR',
    defaultValue: '/tmp/p7m12_gate_e',
  );
  final setupOnly = const bool.fromEnvironment(
    'P7M12_SETUP_ONLY',
    defaultValue: false,
  );
  final tag = localeCode == 'ar' ? 'ar_rtl' : 'en_ltr';

  testWidgets('P7M12 Gate E live acceptance ($localeCode)', (tester) async {
    if (Env.supabaseAnonKey.isEmpty) {
      fail('SUPABASE_ANON_KEY is required for Gate E live acceptance');
    }

    SharedPreferences.setMockInitialValues({preferredLocaleKey: localeCode});
    await SupabaseClientProvider.initialize();
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(key: gateERootKey, child: const App()),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final l10n = lookupAppLocalizations(Locale(localeCode));
    await gateESignIn(tester, l10n);
    await gateEGoCalendar(tester, l10n);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final banner = find.byKey(const Key('calendar-settings-setup-banner'));
    if (setupOnly) {
      expect(banner, findsOneWidget);
      await gateECapture(tester, evidenceDir, 'ge_${tag}_01b_setup_banner');
      await gateEOpenCalendarSettings(tester, l10n);
      await gateECapture(
        tester,
        evidenceDir,
        'ge_${tag}_02_settings_unconfigured',
      );
      return;
    }

    expect(banner, findsNothing);
    await gateEOpenCalendarSettings(tester, l10n);
    await gateECapture(
      tester,
      evidenceDir,
      'ge_${tag}_03_settings_seven_modes',
    );

    await gateEGoCalendar(tester, l10n);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await gateECapture(
      tester,
      evidenceDir,
      'ge_${tag}_05_calendar_split_layout',
    );

    final now = DateTime.now();
    final manualDay = _nextIsoWeekday(now, DateTime.monday);
    await gateESelectDay(tester, manualDay);
    await gateECapture(tester, evidenceDir, 'ge_${tag}_06_multidate_agenda');

    await gateECreateUntimedTask(tester, l10n, tag);
    await gateECreateTimedMeeting(tester, l10n, tag);

    await gateESelectDay(tester, manualDay);
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(
      find.byKey(const Key('calendar-create-event-dialog')),
      findsNothing,
      reason: 'create dialog must close after successful creates',
    );
    final taskLabel = localeCode == 'ar'
        ? 'مهمة بدون وقت P7M12'
        : 'P7M12 Untimed Task';
    final meetingLabel = localeCode == 'ar'
        ? 'اجتماع موقوت P7M12'
        : 'P7M12 Timed Meeting';
    expect(find.textContaining(taskLabel), findsWidgets);
    expect(find.textContaining(meetingLabel), findsWidgets);
    await gateECapture(
      tester,
      evidenceDir,
      'ge_${tag}_10_agenda_after_manuals',
    );
    await gateECapture(
      tester,
      evidenceDir,
      'ge_${tag}_10b_month_counts_after_manuals',
    );

    final holidayDay = _nextIsoWeekday(
      manualDay.add(const Duration(days: 1)),
      DateTime.wednesday,
    );
    await gateERunWdeLifecycle(tester, l10n, evidenceDir, tag, holidayDay);

    await gateEGoCalendar(tester, l10n);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    final overdueTitle = find.textContaining(
      localeCode == 'ar' ? 'متأخرة P7M12' : 'P7M12 Overdue Pending',
    );
    expect(
      overdueTitle,
      findsWidgets,
      reason: 'item 15: overdue pending event must appear in overdue UI',
    );
    await tester.ensureVisible(overdueTitle.first);
    await gateECapture(tester, evidenceDir, 'ge_${tag}_17_overdue_panel');

    await gateECaptureRouteMissingCoords(tester, l10n, evidenceDir, tag);

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await gateEGoCalendar(tester, l10n);
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await gateECapture(tester, evidenceDir, 'ge_${tag}_16_narrow_calendar');
  });
}

DateTime _nextIsoWeekday(DateTime from, int weekday) {
  var d = DateTime(from.year, from.month, from.day);
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}
