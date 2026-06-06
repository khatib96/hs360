import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/customer_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/google_maps_coordinates.dart';

final googleMapsUrlResolverProvider = Provider<GoogleMapsUrlResolver>((ref) {
  return GoogleMapsUrlResolver(ref.watch(supabaseClientProvider));
});

class GoogleMapsUrlResolver {
  GoogleMapsUrlResolver(this._client);

  final SupabaseClient? _client;

  Future<GoogleMapsCoordinates> resolve(String value) async {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !isSupportedGoogleMapsUri(uri)) {
      throw const CustomerException(
        code: CustomerException.googleMapsLinkInvalid,
      );
    }

    final direct = tryParseGoogleMapsCoordinates(trimmed);
    if (direct != null) return direct;

    final client = _client;
    if (client == null) {
      throw const CustomerException(
        code: CustomerException.googleMapsResolutionFailed,
      );
    }

    try {
      final response = await client.functions.invoke(
        'resolve-google-maps-url',
        body: {'url': trimmed},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final latitude = _parseDouble(data['latitude']);
      final longitude = _parseDouble(data['longitude']);
      final resolvedUrl = data['resolved_url']?.toString();
      if (latitude == null || longitude == null || resolvedUrl == null) {
        throw const CustomerException(
          code: CustomerException.googleMapsCoordinatesNotFound,
        );
      }
      return GoogleMapsCoordinates(
        latitude: latitude,
        longitude: longitude,
        resolvedAt:
            DateTime.tryParse(data['resolved_at']?.toString() ?? '') ??
            DateTime.now(),
        resolvedUrl: resolvedUrl,
      );
    } on CustomerException {
      rethrow;
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('coordinates_not_found')) {
        throw const CustomerException(
          code: CustomerException.googleMapsCoordinatesNotFound,
        );
      }
      if (message.contains('invalid_google_maps_url')) {
        throw const CustomerException(
          code: CustomerException.googleMapsLinkInvalid,
        );
      }
      throw CustomerException(
        code: CustomerException.googleMapsResolutionFailed,
        technicalDetail: error.toString(),
      );
    }
  }

  double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
