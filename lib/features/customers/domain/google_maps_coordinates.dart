class GoogleMapsCoordinates {
  const GoogleMapsCoordinates({
    required this.latitude,
    required this.longitude,
    required this.resolvedAt,
    required this.resolvedUrl,
  });

  final double latitude;
  final double longitude;
  final DateTime resolvedAt;
  final String resolvedUrl;
}

GoogleMapsCoordinates? tryParseGoogleMapsCoordinates(
  String value, {
  DateTime? resolvedAt,
}) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !isSupportedGoogleMapsUri(uri)) return null;

  final candidates = <String>[
    trimmed,
    uri.path,
    uri.fragment,
    for (final key in const [
      'query',
      'q',
      'll',
      'destination',
      'daddr',
      'center',
    ])
      ?uri.queryParameters[key],
  ];

  for (final candidate in candidates) {
    final pair = _parseCoordinatePair(candidate);
    if (pair != null) {
      return GoogleMapsCoordinates(
        latitude: pair.$1,
        longitude: pair.$2,
        resolvedAt: resolvedAt ?? DateTime.now(),
        resolvedUrl: trimmed,
      );
    }
  }
  return null;
}

bool isSupportedGoogleMapsUri(Uri uri) {
  if (uri.scheme != 'https' && uri.scheme != 'http') return false;
  final host = uri.host.toLowerCase();
  if (host == 'maps.app.goo.gl' ||
      host == 'goo.gl' ||
      host == 'google.com' ||
      host == 'www.google.com' ||
      host == 'maps.google.com') {
    return true;
  }
  return RegExp(
    r'^(www|maps)\.google\.[a-z]{2,3}(\.[a-z]{2})?$',
  ).hasMatch(host);
}

(double, double)? _parseCoordinatePair(String value) {
  final decoded = Uri.decodeComponent(value);
  for (final pattern in [
    RegExp(r'!3d(-?\d{1,3}(?:\.\d+)?)[^!]*!4d(-?\d{1,3}(?:\.\d+)?)'),
    RegExp(r'@(-?\d{1,3}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)'),
    RegExp(
      r'(?:^|[^0-9.-])(-?\d{1,3}(?:\.\d+)?)\s*,\s*'
      r'(-?\d{1,3}(?:\.\d+)?)(?:$|[^0-9.-])',
    ),
  ]) {
    final match = pattern.firstMatch(decoded);
    if (match == null) continue;
    final latitude = double.tryParse(match.group(1)!);
    final longitude = double.tryParse(match.group(2)!);
    if (latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180) {
      return (latitude, longitude);
    }
  }
  return null;
}
