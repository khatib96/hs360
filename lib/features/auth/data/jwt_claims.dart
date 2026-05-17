import 'dart:convert';

/// Best-effort JWT payload decode. Never throws; returns empty map on failure.
Map<String, dynamic> decodeJwtClaims(String accessToken) {
  try {
    final parts = accessToken.split('.');
    if (parts.length < 2) return const {};

    var payload = parts[1];
    final mod = payload.length % 4;
    if (mod > 0) {
      payload += '=' * (4 - mod);
    }

    final decoded = utf8.decode(base64Url.decode(payload));
    final map = jsonDecode(decoded);
    if (map is Map<String, dynamic>) return map;
    if (map is Map) return Map<String, dynamic>.from(map);
    return const {};
  } catch (_) {
    return const {};
  }
}
