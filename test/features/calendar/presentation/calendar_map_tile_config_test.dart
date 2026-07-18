import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_tile_config.dart';

void main() {
  group('CalendarMapTileConfig.validate', () {
    test('missing template', () {
      expect(const CalendarMapTileConfig().validate(), 'missing_template');
      expect(const CalendarMapTileConfig().isConfigured, isFalse);
    });

    test('requires https scheme', () {
      expect(
        const CalendarMapTileConfig(
          urlTemplate: 'http://tiles.example/{z}/{x}/{y}.png',
          attribution: 'Example',
        ).validate(),
        'invalid_scheme',
      );
    });

    test('requires host', () {
      expect(
        const CalendarMapTileConfig(
          urlTemplate: 'https:///{z}/{x}/{y}.png',
          attribution: 'Example',
        ).validate(),
        'invalid_host',
      );
    });

    test('requires z/x/y placeholders', () {
      expect(
        const CalendarMapTileConfig(
          urlTemplate: 'https://tiles.example/{z}/{x}.png',
          attribution: 'Example',
        ).validate(),
        'missing_zxy',
      );
    });

    test('requires api key when {key} present', () {
      expect(
        const CalendarMapTileConfig(
          urlTemplate: 'https://tiles.example/{z}/{x}/{y}.png?key={key}',
          attribution: 'Example',
        ).validate(),
        'missing_key',
      );
    });

    test('requires non-empty attribution', () {
      expect(
        const CalendarMapTileConfig(
          urlTemplate: 'https://tiles.example/{z}/{x}/{y}.png',
          attribution: '  ',
        ).validate(),
        'missing_attribution',
      );
    });

    test('blocks public OSM by default', () {
      expect(
        const CalendarMapTileConfig(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          attribution: '© OpenStreetMap',
        ).validate(),
        'public_osm_blocked',
      );
    });

    test('allows public OSM only with explicit smoke flag', () {
      final config = const CalendarMapTileConfig(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        attribution: '© OpenStreetMap',
        allowPublicOsmSmoke: true,
      );
      expect(config.validate(), isNull);
      expect(config.isConfigured, isTrue);
    });

    test('valid commercial template with key', () {
      final config = const CalendarMapTileConfig(
        urlTemplate:
            'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key={key}',
        apiKey: 'test-key',
        attribution: '© MapTiler © OSM',
      );
      expect(config.validate(), isNull);
      expect(config.resolvedUrlTemplate, contains('key=test-key'));
    });
  });
}
