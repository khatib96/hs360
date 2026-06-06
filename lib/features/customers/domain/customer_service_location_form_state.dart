import '../../../core/location/kuwait_locations.dart';
import 'customer_service_location.dart';
import 'service_location_coordinates.dart';
import 'service_location_type.dart';

/// Form payload for service-location RPCs.
class CustomerServiceLocationFormState {
  CustomerServiceLocationFormState({
    required this.name,
    this.locationType = ServiceLocationType.branch,
    this.isPrimary = false,
    this.country = kuwaitCountryCanonical,
    this.governorate,
    this.area,
    this.addressLine,
    this.googleMapsUrl,
    this.latitude,
    this.longitude,
    this.resolutionSource,
    this.resolvedAt,
    this.coordinateAccuracyM,
    this.resolutionStatus,
    this.resolutionError,
    this.contactPersonName,
    this.contactPersonPhone,
    this.contactPersonEmail,
    this.notes,
  });

  factory CustomerServiceLocationFormState.fromLocation(
    CustomerServiceLocation location,
  ) {
    return CustomerServiceLocationFormState(
      name: location.name,
      locationType: location.locationType,
      isPrimary: location.isPrimary,
      country: location.country ?? kuwaitCountryCanonical,
      governorate: location.governorate,
      area: location.area,
      addressLine: location.addressLine,
      googleMapsUrl: location.googleMapsUrl,
      latitude: location.latitude,
      longitude: location.longitude,
      resolutionSource: location.resolutionSource,
      resolvedAt: location.resolvedAt,
      coordinateAccuracyM: location.coordinateAccuracyM,
      resolutionStatus: location.resolutionStatus,
      resolutionError: location.resolutionError,
      contactPersonName: location.contactPersonName,
      contactPersonPhone: location.contactPersonPhone,
      contactPersonEmail: location.contactPersonEmail,
      notes: location.notes,
    );
  }

  final String name;
  final ServiceLocationType locationType;
  final bool isPrimary;
  final String? country;
  final String? governorate;
  final String? area;
  final String? addressLine;
  final String? googleMapsUrl;
  final double? latitude;
  final double? longitude;
  final CoordinateResolutionSource? resolutionSource;
  final DateTime? resolvedAt;
  final double? coordinateAccuracyM;
  final CoordinateResolutionStatus? resolutionStatus;
  final String? resolutionError;
  final String? contactPersonName;
  final String? contactPersonPhone;
  final String? contactPersonEmail;
  final String? notes;

  Map<String, dynamic> toPayload() {
    return {
      'name': name.trim(),
      'location_type': locationType.toDb(),
      'is_primary': isPrimary,
      'country': _trimmedOrNull(country),
      'governorate': _trimmedOrNull(governorate),
      'area': _trimmedOrNull(area),
      'address_line': _trimmedOrNull(addressLine),
      'google_maps_url': _trimmedOrNull(googleMapsUrl),
      'latitude': latitude,
      'longitude': longitude,
      'resolution_source': resolutionSource?.toDb(),
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
      'coordinate_accuracy_m': coordinateAccuracyM,
      'resolution_status': resolutionStatus?.toDb(),
      'resolution_error': _trimmedOrNull(resolutionError),
      'contact_person_name': _trimmedOrNull(contactPersonName),
      'contact_person_phone': _trimmedOrNull(contactPersonPhone),
      'contact_person_email': _trimmedOrNull(contactPersonEmail),
      'notes': _trimmedOrNull(notes),
    };
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
