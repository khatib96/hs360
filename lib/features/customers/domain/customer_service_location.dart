import 'service_location_coordinates.dart';
import 'service_location_type.dart';

/// Row from [customer_service_locations].
class CustomerServiceLocation {
  const CustomerServiceLocation({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.code,
    required this.name,
    required this.locationType,
    required this.isPrimary,
    required this.isActive,
    this.country,
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
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String customerId;
  final String code;
  final String name;
  final ServiceLocationType locationType;
  final bool isPrimary;
  final bool isActive;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String locationSummary() {
    final parts = <String>[
      if (governorate?.trim().isNotEmpty == true) governorate!.trim(),
      if (area?.trim().isNotEmpty == true) area!.trim(),
      if (addressLine?.trim().isNotEmpty == true) addressLine!.trim(),
    ];
    return parts.join(' · ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  factory CustomerServiceLocation.fromRow(Map<String, dynamic> row) {
    return CustomerServiceLocation(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      customerId: row['customer_id'] as String,
      code: row['code'] as String,
      name: row['name'] as String,
      locationType: ServiceLocationType.fromDb(row['location_type'] as String?),
      isPrimary: row['is_primary'] as bool? ?? false,
      isActive: row['is_active'] as bool? ?? true,
      country: row['country'] as String?,
      governorate: row['governorate'] as String?,
      area: row['area'] as String?,
      addressLine: row['address_line'] as String?,
      googleMapsUrl: row['google_maps_url'] as String?,
      latitude: _parseDouble(row['latitude']),
      longitude: _parseDouble(row['longitude']),
      resolutionSource: CoordinateResolutionSource.fromDb(
        row['resolution_source'] as String?,
      ),
      resolvedAt: _parseDateTime(row['resolved_at']),
      coordinateAccuracyM: _parseDouble(row['coordinate_accuracy_m']),
      resolutionStatus: CoordinateResolutionStatus.fromDb(
        row['resolution_status'] as String?,
      ),
      resolutionError: row['resolution_error'] as String?,
      contactPersonName: row['contact_person_name'] as String?,
      contactPersonPhone: row['contact_person_phone'] as String?,
      contactPersonEmail: row['contact_person_email'] as String?,
      notes: row['notes'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  static double? _parseDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
