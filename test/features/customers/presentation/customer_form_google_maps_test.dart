import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/data/google_maps_url_resolver.dart';
import 'package:hs360/features/customers/domain/customer_form_state.dart';
import 'package:hs360/features/customers/domain/google_maps_coordinates.dart';
import 'package:hs360/features/customers/presentation/customer_form_draft.dart';
import 'package:hs360/features/customers/presentation/widgets/customer_form.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  testWidgets('customer form resolves map link before submit', (tester) async {
    CustomerFormState? submitted;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleMapsUrlResolverProvider.overrideWithValue(
            _FakeGoogleMapsUrlResolver(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CustomerForm(
                initialDraft: const CustomerFormDraft(
                  nameAr: 'Customer',
                  phonePrimary: '+96550000000',
                ),
                isEdit: false,
                isSubmitting: false,
                submitLabel: 'Create',
                onSubmit: (value) => submitted = value,
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('google-maps-link-field')),
      'https://maps.app.goo.gl/customer',
    );
    final submit = find.byKey(const Key('customer-form-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(submitted?.googleMapsUrl, 'https://maps.app.goo.gl/customer');
    expect(submitted?.latitude, 29.3759);
    expect(submitted?.longitude, 47.9774);
    expect(submitted?.coordinatesResolvedAt, DateTime.utc(2026, 6, 6, 8, 30));
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
