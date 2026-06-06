import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/domain/validators/customer_service_location_validator.dart';
import 'package:hs360/features/customers/domain/customer_service_location_form_state.dart';
import 'package:hs360/features/customers/domain/service_location_coordinates.dart';

void main() {
  const validator = CustomerServiceLocationValidator();

  test('requires name', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(name: '  '),
    );
    expect(result.isValid, isFalse);
    expect(
      result.codes,
      contains(CustomerException.serviceLocationNameRequired),
    );
  });

  test('accepts valid form', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(name: 'Branch'),
    );
    expect(result.isValid, isTrue);
  });

  test('requires latitude and longitude together', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(name: 'Branch', latitude: 29.3),
    );
    expect(
      result.codes,
      contains(CustomerException.serviceLocationCoordinatePairRequired),
    );
  });

  test('rejects coordinate values outside valid ranges', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(
        name: 'Branch',
        latitude: 91,
        longitude: 181,
        resolutionSource: CoordinateResolutionSource.manual,
        resolvedAt: DateTime.utc(2026, 6, 6),
        resolutionStatus: CoordinateResolutionStatus.resolved,
      ),
    );
    expect(
      result.codes,
      contains(CustomerException.serviceLocationLatitudeInvalid),
    );
    expect(
      result.codes,
      contains(CustomerException.serviceLocationLongitudeInvalid),
    );
  });

  test('requires auditable metadata for stored coordinates', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(
        name: 'Branch',
        latitude: 29.3,
        longitude: 48,
      ),
    );
    expect(
      result.codes,
      contains(CustomerException.serviceLocationCoordinateMetadataInvalid),
    );
  });

  test('accepts resolved device GPS coordinates', () {
    final result = validator.validate(
      CustomerServiceLocationFormState(
        name: 'Branch',
        latitude: 29.3,
        longitude: 48,
        resolutionSource: CoordinateResolutionSource.deviceGps,
        resolvedAt: DateTime.utc(2026, 6, 6),
        coordinateAccuracyM: 4.5,
        resolutionStatus: CoordinateResolutionStatus.resolved,
      ),
    );
    expect(result.isValid, isTrue);
  });
}
