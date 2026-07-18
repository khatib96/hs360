/// Route View raster tile provider configuration (Phase 7 M10).
///
/// Read from `--dart-define` values only. Public OSM tile hosts are never the
/// production default; they require an explicit non-production smoke flag.
class CalendarMapTileConfig {
  const CalendarMapTileConfig({
    this.urlTemplate,
    this.apiKey,
    this.attribution,
    this.userAgentPackageName = defaultUserAgentPackageName,
    this.allowPublicOsmSmoke = false,
  });

  static const defaultUserAgentPackageName = 'com.hs360.app';

  static const _envUrlTemplate = String.fromEnvironment(
    'HS360_MAP_TILE_URL_TEMPLATE',
  );
  static const _envApiKey = String.fromEnvironment('HS360_MAP_TILE_API_KEY');
  static const _envAttribution = String.fromEnvironment(
    'HS360_MAP_ATTRIBUTION',
  );
  static const _envAllowPublicOsmSmoke = bool.fromEnvironment(
    'HS360_MAP_ALLOW_PUBLIC_OSM_SMOKE',
    defaultValue: false,
  );

  final String? urlTemplate;
  final String? apiKey;
  final String? attribution;
  final String userAgentPackageName;

  /// Dev-only: when true, `tile.openstreetmap.org` may pass validation.
  /// Must never be shipped as a production build default.
  final bool allowPublicOsmSmoke;

  factory CalendarMapTileConfig.fromEnvironment() {
    return CalendarMapTileConfig(
      urlTemplate: _envUrlTemplate.trim().isEmpty ? null : _envUrlTemplate,
      apiKey: _envApiKey.trim().isEmpty ? null : _envApiKey,
      attribution: _envAttribution.trim().isEmpty ? null : _envAttribution,
      allowPublicOsmSmoke: _envAllowPublicOsmSmoke,
    );
  }

  /// True when the template is present **and** passes [validate].
  bool get isConfigured => validate() == null;

  /// Returns a machine-readable validation error code, or null when valid.
  ///
  /// Codes: `missing_template`, `invalid_scheme`, `invalid_host`,
  /// `missing_zxy`, `missing_key`, `missing_attribution`, `public_osm_blocked`.
  String? validate() {
    final template = urlTemplate?.trim() ?? '';
    if (template.isEmpty) return 'missing_template';

    final uri = Uri.tryParse(template.replaceAll('{key}', 'x'));
    if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
      return 'invalid_scheme';
    }
    if (uri.host.isEmpty) return 'invalid_host';

    if (!template.contains('{z}') ||
        !template.contains('{x}') ||
        !template.contains('{y}')) {
      return 'missing_zxy';
    }

    if (template.contains('{key}') && (apiKey == null || apiKey!.trim().isEmpty)) {
      return 'missing_key';
    }

    final attr = attribution?.trim() ?? '';
    if (attr.isEmpty) return 'missing_attribution';

    if (_isPublicOsmHost(uri.host) && !allowPublicOsmSmoke) {
      return 'public_osm_blocked';
    }

    return null;
  }

  /// [urlTemplate] with `{key}` substituted. Null when [isConfigured] is false.
  String? get resolvedUrlTemplate {
    if (!isConfigured) return null;
    final template = urlTemplate!;
    return template.replaceAll('{key}', apiKey ?? '');
  }

  static bool _isPublicOsmHost(String host) {
    final h = host.toLowerCase();
    return h == 'tile.openstreetmap.org' ||
        h.endsWith('.tile.openstreetmap.org');
  }
}
