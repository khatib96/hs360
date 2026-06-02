import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/domain/customer_service_location.dart';
import 'package:hs360/features/customers/domain/service_location_type.dart';

void main() {
  test('fromRow parses service location fields', () {
    final location = CustomerServiceLocation.fromRow({
      'id': 'loc-1',
      'tenant_id': 'tenant-1',
      'customer_id': 'cust-1',
      'code': 'LOC-0001',
      'name': 'Salmiya branch',
      'location_type': 'installation_site',
      'is_primary': true,
      'is_active': true,
      'governorate': 'Hawalli',
      'area': 'Salmiya',
      'address_line': 'Street 1',
      'google_maps_url': 'https://maps.example',
      'latitude': 29.3,
      'longitude': 48.0,
      'contact_person_name': 'Ali',
      'contact_person_phone': '+96550000000',
      'created_at': '2026-06-02T10:00:00Z',
    });

    expect(location.code, 'LOC-0001');
    expect(location.locationType, ServiceLocationType.installationSite);
    expect(location.isPrimary, isTrue);
    expect(location.latitude, 29.3);
    expect(location.locationSummary(), contains('Hawalli'));
  });
}
