/// Phase 7 M12 Gate F — live Open-with device acceptance on real [App].
///
/// Device smoke: `P7M12_GATE_F_DRY_LAUNCH=false` (required).
/// Contract-only dry URI recording is for unit tests, not Gate F device proof.
///
/// Run via: `bash scripts/test/p7m12_gate_f_device_acceptance.sh`
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/app.dart';
import 'package:hs360/core/config/env.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/network/supabase_client.dart';
import 'package:hs360/features/calendar/presentation/calendar_directions_providers.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_app_option.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'p7m12_gate_f_flows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final localeCode = const String.fromEnvironment(
    'P7M12_LOCALE',
    defaultValue: 'en',
  );
  final platformLabel = const String.fromEnvironment(
    'P7M12_GATE_F_PLATFORM',
    defaultValue: 'unknown',
  );
  final tag = localeCode == 'ar' ? 'ar' : 'en';
  final prefix = platformLabel == 'ios'
      ? 'gf_ios'
      : platformLabel == 'android_emulator'
      ? 'gf_and'
      : 'gf_$platformLabel';

  testWidgets('P7M12 Gate F open-with ($platformLabel / $localeCode)', (
    tester,
  ) async {
    if (Env.supabaseAnonKey.isEmpty) {
      fail('SUPABASE_ANON_KEY is required for Gate F device acceptance');
    }
    // Device Gate F must not use dry-launch as acceptance proof.
    expect(
      gateFDryLaunch,
      isFalse,
      reason:
          'Gate F device smoke requires P7M12_GATE_F_DRY_LAUNCH=false '
          '(URI recording alone is not external-launch proof)',
    );

    gateFLaunchedUris.clear();
    gateFLaunchResults.clear();
    gateFSurfaceConverted = false;
    SharedPreferences.setMockInitialValues({preferredLocaleKey: localeCode});
    await SupabaseClientProvider.initialize();

    // Use the device's natural viewport — do not fake setSurfaceSize.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDirectionsLauncherProvider.overrideWithValue(
            gateFInstrumentedLauncher(),
          ),
        ],
        child: const App(),
      ),
    );
    await gateFPumpFrames(tester, frames: 24);

    final l10n = lookupAppLocalizations(Locale(localeCode));
    await gateFSignIn(tester, l10n);
    await gateFPumpFrames(tester, frames: 16);

    await gateFCapture(tester, '${prefix}_f01_or_f09_app_launch_$tag');

    await gateFOpenRouteForFieldAgent(tester, l10n);
    await gateFCapture(tester, '${prefix}_route_day_loaded_$tag');

    final mappedNeedle = localeCode == 'ar'
        ? 'بإحداثيات'
        : 'Mapped Route Visit';
    final unmappedNeedle = localeCode == 'ar'
        ? 'بلا إحداثيات'
        : 'Unmapped Route Visit';
    final urlOnlyNeedle = localeCode == 'ar'
        ? 'رابط فقط'
        : 'UrlOnly Route Visit';

    // ListView.builder only builds visible children — scroll before assert.
    await gateFEnsureVisibleNeedle(tester, mappedNeedle);
    await gateFEnsureVisibleNeedle(tester, unmappedNeedle);
    await gateFEnsureVisibleNeedle(tester, urlOnlyNeedle);
    expect(
      find.textContaining(urlOnlyNeedle),
      findsWidgets,
      reason: 'url_only fixture must be present (not skippable)',
    );

    // Re-scroll Mapped into view after UrlOnly (builder unmounts off-screen).
    await gateFEnsureVisibleNeedle(tester, mappedNeedle);
    final mappedDir = gateFDirectionsButtonForTitle(mappedNeedle);
    expect(mappedDir, findsOneWidget);
    await gateFCapture(tester, '${prefix}_f02_or_f10_mapped_directions_$tag');

    final launchesBeforeSheet = gateFLaunchedUris.length;
    await gateFTapDirectionsForMapped(tester, mappedNeedle: mappedNeedle);
    expect(
      gateFLaunchedUris.length,
      launchesBeforeSheet,
      reason: 'no auto-launch before user chooses an app',
    );
    expect(find.text(l10n.calendarOpenWithTitle), findsOneWidget);
    await gateFCapture(tester, '${prefix}_f03_or_f11_open_with_sheet_$tag');

    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.iOS) {
      await gateFAssertOpenWithOptions(
        platform: platform,
        mustInclude: const [
          CalendarMapAppKind.appleMaps,
          CalendarMapAppKind.browser,
        ],
        mustExclude: const [],
      );
      await gateFCapture(tester, '${prefix}_f05_apple_maps_listed_$tag');
    } else if (platform == TargetPlatform.android) {
      expect(
        find.byKey(const Key('calendar-open-with-googleMaps')),
        findsOneWidget,
        reason: 'Google Maps must be installed/available on Gate F emulator',
      );
      expect(
        find.byKey(const Key('calendar-open-with-browser')),
        findsOneWidget,
      );
      // ignore: avoid_print
      print('P7M12_GATE_F_GOOGLE_MAPS_ROW=present');
      await gateFCapture(tester, '${prefix}_f13_google_maps_availability_$tag');
    }

    await gateFCapture(tester, '${prefix}_f07_or_availability_$tag');

    if (localeCode == 'ar') {
      expect(find.text('فتح باستخدام'), findsOneWidget);
      await gateFCapture(tester, '${prefix}_f08_or_f15_open_with_ar_rtl');
    }

    await gateFCancelOpenWith(tester);
    await gateFCapture(tester, '${prefix}_f04_or_f12_cancel_no_launch_$tag');

    // Real external launch — mapped destination.
    await gateFTapDirectionsForMapped(tester, mappedNeedle: mappedNeedle);
    if (platform == TargetPlatform.iOS) {
      await gateFLaunchOption(
        tester,
        CalendarMapAppKind.appleMaps,
        expectedUriSubstring: 'maps.apple.com',
        awaitExternalToken: 'ios.apple_maps',
      );
      final uri = gateFLaunchedUris.last.toString();
      expect(uri, contains('daddr='));
      expect(
        uri.contains('$gateFMappedLat') || uri.contains('29.339'),
        isTrue,
        reason: 'Apple Maps daddr must target mapped fixture coords',
      );
      await gateFCapture(tester, '${prefix}_f06_apple_maps_after_launch_$tag');
    } else if (platform == TargetPlatform.android) {
      await gateFLaunchOption(
        tester,
        CalendarMapAppKind.googleMaps,
        expectedUriSubstring: 'google.navigation:q=',
        awaitExternalToken: 'android.google_maps',
      );
      final uri = gateFLaunchedUris.last.toString();
      expect(
        uri.contains('$gateFMappedLat') || uri.contains('29.339'),
        isTrue,
        reason: 'Google Maps navigation URI must include mapped coords',
      );
      await gateFCapture(tester, '${prefix}_f14_google_maps_after_launch_$tag');
    }

    // Re-enter route after external app.
    if (find.byKey(const Key('calendar-route-point-list')).evaluate().isEmpty) {
      await gateFOpenRouteForFieldAgent(tester, l10n);
    }

    await gateFAssertNoDirectionsForNeedle(tester, unmappedNeedle);
    // ignore: avoid_print
    print(
      'P7M12_GATE_F_NOTE=invalid location_state not device-seedable under '
      'CSL CHECK; covered by SQL calendar_location_state contract only',
    );
    await gateFCapture(tester, '${prefix}_f16_missing_$tag');

    await gateFOpenUrlOnlySheet(tester, urlOnlyNeedle: urlOnlyNeedle);
    await gateFCapture(tester, '${prefix}_f16_url_only_browser_only_$tag');

    // Real Browser launch for url_only.
    // Android: Chrome navigate URI (avoids Maps App Links stealing google.com/maps).
    // iOS: plain HTTPS opens in Safari/Browser.
    await gateFLaunchOption(
      tester,
      CalendarMapAppKind.browser,
      expectedUriSubstring: platform == TargetPlatform.android
          ? 'googlechrome://navigate'
          : 'google.com/maps',
      awaitExternalToken: platform == TargetPlatform.iOS
          ? 'ios.browser'
          : 'android.browser',
    );
    await gateFCapture(tester, '${prefix}_f16_url_only_browser_launched_$tag');

    // ignore: avoid_print
    print(
      'P7M12_GATE_F_DONE platform=$platformLabel locale=$localeCode '
      'launches=${gateFLaunchedUris.length} dry=$gateFDryLaunch',
    );
  });
}
