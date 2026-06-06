import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/domain/customer_service_location.dart';
import 'package:hs360/features/customers/domain/customer_service_location_form_state.dart';
import 'package:hs360/features/customers/domain/service_location_coordinates.dart';

void main() {
  test('parses coordinate resolution metadata from database rows', () {
    final location = CustomerServiceLocation.fromRow({
      'id': 'location-1',
      'tenant_id': 'tenant-1',
      'customer_id': 'customer-1',
      'code': 'LOC-0001',
      'name': 'Main site',
      'location_type': 'branch',
      'is_primary': true,
      'is_active': true,
      'latitude': '29.3759000',
      'longitude': 47.9774,
      'resolution_source': 'url',
      'resolved_at': '2026-06-06T08:30:00Z',
      'coordinate_accuracy_m': '4.25',
      'resolution_status': 'resolved',
    });

    expect(location.hasCoordinates, isTrue);
    expect(location.latitude, 29.3759);
    expect(location.longitude, 47.9774);
    expect(location.resolutionSource, CoordinateResolutionSource.url);
    expect(location.resolvedAt, DateTime.utc(2026, 6, 6, 8, 30));
    expect(location.coordinateAccuracyM, 4.25);
    expect(location.resolutionStatus, CoordinateResolutionStatus.resolved);
  });

  test('form payload carries metadata and explicit nulls for clearing', () {
    final resolved = CustomerServiceLocationFormState(
      name: 'Main site',
      latitude: 29.3759,
      longitude: 47.9774,
      resolutionSource: CoordinateResolutionSource.url,
      resolvedAt: DateTime.utc(2026, 6, 6, 8, 30),
      coordinateAccuracyM: 4.25,
      resolutionStatus: CoordinateResolutionStatus.resolved,
    ).toPayload();

    expect(resolved['resolution_source'], 'url');
    expect(resolved['resolved_at'], '2026-06-06T08:30:00.000Z');
    expect(resolved['coordinate_accuracy_m'], 4.25);
    expect(resolved['resolution_status'], 'resolved');

    final cleared = CustomerServiceLocationFormState(
      name: 'Main site',
    ).toPayload();
    expect(cleared, containsPair('latitude', null));
    expect(cleared, containsPair('longitude', null));
    expect(cleared, containsPair('resolution_source', null));
    expect(cleared, containsPair('resolved_at', null));
    expect(cleared, containsPair('coordinate_accuracy_m', null));
    expect(cleared, containsPair('resolution_status', null));
  });
}
