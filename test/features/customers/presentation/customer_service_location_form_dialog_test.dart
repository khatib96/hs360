import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/features/customers/data/google_maps_url_resolver.dart';
import 'package:hs360/features/customers/domain/customer_service_location_form_state.dart';
import 'package:hs360/features/customers/domain/google_maps_coordinates.dart';
import 'package:hs360/features/customers/domain/service_location_coordinates.dart';
import 'package:hs360/features/customers/presentation/widgets/customer_service_location_form_dialog.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required GoogleMapsUrlResolver resolver,
    required ValueChanged<CustomerServiceLocationFormState?> onResult,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [googleMapsUrlResolverProvider.overrideWithValue(resolver)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  onResult(
                    await showCustomerServiceLocationFormDialog(context),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('pasted Google Maps link supplies URL coordinates', (
    tester,
  ) async {
    CustomerServiceLocationFormState? result;
    await pumpHost(
      tester,
      resolver: _FakeGoogleMapsUrlResolver(),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('google-maps-link-field')),
      'https://maps.app.goo.gl/example',
    );
    await tester.pump();
    expect(find.byKey(const Key('service-location-latitude')), findsNothing);
    expect(
      find.byKey(const Key('service-location-use-current-location')),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.latitude, 29.3759);
    expect(result?.longitude, 47.9774);
    expect(result?.resolutionSource, CoordinateResolutionSource.url);
    expect(result?.resolutionStatus, CoordinateResolutionStatus.resolved);
    expect(result?.coordinateAccuracyM, isNull);
  });

  testWidgets('unresolvable Google Maps link keeps dialog open', (
    tester,
  ) async {
    CustomerServiceLocationFormState? result;
    await pumpHost(
      tester,
      resolver: _FailingGoogleMapsUrlResolver(),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('google-maps-link-field')),
      'https://maps.app.goo.gl/missing',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Coordinates could not be extracted from this Google Maps link.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CustomerServiceLocationFormDialog), findsOneWidget);
    expect(result, isNull);
  });
}

class _FakeGoogleMapsUrlResolver extends GoogleMapsUrlResolver {
  _FakeGoogleMapsUrlResolver() : super(null);

  @override
  Future<GoogleMapsCoordinates> resolve(String value) async {
    return GoogleMapsCoordinates(
      latitude: 29.3759,
      longitude: 47.9774,
      resolvedAt: DateTime.utc(2026, 6, 6, 8, 30),
      resolvedUrl: value,
    );
  }
}

class _FailingGoogleMapsUrlResolver extends GoogleMapsUrlResolver {
  _FailingGoogleMapsUrlResolver() : super(null);

  @override
  Future<GoogleMapsCoordinates> resolve(String value) {
    throw const CustomerException(
      code: CustomerException.googleMapsCoordinatesNotFound,
    );
  }
}
