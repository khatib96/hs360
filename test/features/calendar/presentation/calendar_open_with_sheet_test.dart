import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_directions_target.dart';
import 'package:hs360/features/calendar/domain/calendar_route_location_state.dart';
import 'package:hs360/features/calendar/presentation/calendar_directions_flow.dart';
import 'package:hs360/features/calendar/presentation/calendar_directions_launcher.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_app_resolver.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

const _mapped = CalendarDirectionsTarget(
  eventId: 'e1',
  locationState: CalendarRouteLocationState.mapped,
  latitude: 29.3759,
  longitude: 47.9774,
  mapsUrl: 'https://www.google.com/maps/dir/?api=1&destination=29.3759,47.9774',
);

void main() {
  Future<void> prepareSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Open-with sheet appears before launch; cancel launches nothing', (
    tester,
  ) async {
    await prepareSurface(tester);
    var launched = false;
    final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
    final launcher = CalendarDirectionsLauncher(
      launcher: (uri, {mode = LaunchMode.platformDefault}) async {
        launched = true;
        return true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const Key('open-chooser'),
                onPressed: () {
                  presentCalendarDirectionsChooser(
                    context: context,
                    target: _mapped,
                    resolver: resolver,
                    launcher: launcher,
                    platform: TargetPlatform.iOS,
                  );
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-chooser')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-open-with-title')), findsOneWidget);
    expect(find.text('Open with'), findsOneWidget);
    expect(launched, isFalse);

    expect(find.byKey(const Key('calendar-open-with-appleMaps')), findsOneWidget);
    expect(find.byKey(const Key('calendar-open-with-googleMaps')), findsOneWidget);
    expect(find.byKey(const Key('calendar-open-with-waze')), findsOneWidget);
    expect(find.byKey(const Key('calendar-open-with-browser')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('calendar-open-with-cancel')));
    await tester.tap(find.byKey(const Key('calendar-open-with-cancel')));
    await tester.pumpAndSettle();
    expect(launched, isFalse);
    expect(find.byKey(const Key('calendar-open-with-title')), findsNothing);
  });

  testWidgets('selecting an option launches that URI', (tester) async {
    await prepareSurface(tester);
    Uri? launched;
    final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
    final launcher = CalendarDirectionsLauncher(
      launcher: (uri, {mode = LaunchMode.platformDefault}) async {
        launched = uri;
        return true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const Key('open-chooser'),
                onPressed: () {
                  presentCalendarDirectionsChooser(
                    context: context,
                    target: _mapped,
                    resolver: resolver,
                    launcher: launcher,
                    platform: TargetPlatform.iOS,
                  );
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-chooser')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-open-with-appleMaps')));
    await tester.pumpAndSettle();

    expect(launched, isNotNull);
    expect(launched!.scheme, 'https');
    expect(launched!.host, 'maps.apple.com');
  });

  testWidgets('launch failure shows translated snackbar', (tester) async {
    await prepareSurface(tester);
    final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
    final launcher = CalendarDirectionsLauncher(
      launcher: (uri, {mode = LaunchMode.platformDefault}) async => false,
    );
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const Key('open-chooser'),
                onPressed: () {
                  presentCalendarDirectionsChooser(
                    context: context,
                    target: _mapped,
                    resolver: resolver,
                    launcher: launcher,
                    platform: TargetPlatform.macOS,
                  );
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-chooser')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-open-with-browser')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendarDirectionsFailed), findsOneWidget);
  });

  testWidgets('Arabic Open-with title uses فتح باستخدام', (tester) async {
    await prepareSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const Key('open-chooser'),
                onPressed: () {
                  presentCalendarDirectionsChooser(
                    context: context,
                    target: _mapped,
                    resolver: CalendarMapAppResolver(
                      canLaunch: (_) async => false,
                    ),
                    launcher: const CalendarDirectionsLauncher(),
                    platform: TargetPlatform.macOS,
                  );
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-chooser')));
    await tester.pumpAndSettle();
    expect(find.text('فتح باستخدام'), findsOneWidget);
  });
}
