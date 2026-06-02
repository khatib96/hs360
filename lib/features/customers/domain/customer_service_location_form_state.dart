import '../../../core/location/kuwait_locations.dart';
import 'customer_service_location.dart';
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
  final String? contactPersonName;
  final String? contactPersonPhone;
  final String? contactPersonEmail;
  final String? notes;

  Map<String, dynamic> toPayload() {
    return {
      'name': name.trim(),
      'location_type': locationType.toDb(),
      'is_primary': isPrimary,
      if (country?.trim().isNotEmpty == true) 'country': country!.trim(),
      if (governorate?.trim().isNotEmpty == true)
        'governorate': governorate!.trim(),
      if (area?.trim().isNotEmpty == true) 'area': area!.trim(),
      if (addressLine?.trim().isNotEmpty == true)
        'address_line': addressLine!.trim(),
      if (googleMapsUrl?.trim().isNotEmpty == true)
        'google_maps_url': googleMapsUrl!.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (contactPersonName?.trim().isNotEmpty == true)
        'contact_person_name': contactPersonName!.trim(),
      if (contactPersonPhone?.trim().isNotEmpty == true)
        'contact_person_phone': contactPersonPhone!.trim(),
      if (contactPersonEmail?.trim().isNotEmpty == true)
        'contact_person_email': contactPersonEmail!.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
    };
  }
}
