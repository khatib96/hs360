import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/domain/google_maps_coordinates.dart';

void main() {
  test('parses coordinates from Google Maps viewport URL', () {
    final result = tryParseGoogleMapsCoordinates(
      'https://www.google.com/maps/place/Test/@29.3759,47.9774,17z',
    );

    expect(result?.latitude, 29.3759);
    expect(result?.longitude, 47.9774);
  });

  test('parses coordinates from q query parameter', () {
    final result = tryParseGoogleMapsCoordinates(
      'https://maps.google.com/?q=29.3759,47.9774',
    );

    expect(result?.latitude, 29.3759);
    expect(result?.longitude, 47.9774);
  });

  test('parses coordinates from Google Maps data markers', () {
    final result = tryParseGoogleMapsCoordinates(
      'https://www.google.com/maps/place/Test/data=!3d29.3759!4d47.9774',
    );

    expect(result?.latitude, 29.3759);
    expect(result?.longitude, 47.9774);
  });

  test('prefers exact place coordinates over the map viewport center', () {
    final result = tryParseGoogleMapsCoordinates(
      'https://www.google.com/maps/place/Test/'
      '@25.7856293,55.9607666,2890m/'
      'data=!4m6!3m5!1s0x0!8m2!3d25.7800955!4d55.9693682',
    );

    expect(result?.latitude, 25.7800955);
    expect(result?.longitude, 55.9693682);
  });

  test('rejects unsupported hosts and links without coordinates', () {
    expect(
      tryParseGoogleMapsCoordinates('https://example.com/?q=29.3,48.0'),
      isNull,
    );
    expect(
      tryParseGoogleMapsCoordinates('https://maps.app.goo.gl/short-link'),
      isNull,
    );
  });
}
