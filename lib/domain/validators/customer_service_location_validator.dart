import '../../core/errors/customer_exception.dart';
import '../../features/customers/domain/customer_service_location_form_state.dart';
import '../../features/customers/domain/service_location_coordinates.dart';
import 'validation_result.dart';

class CustomerServiceLocationValidator {
  const CustomerServiceLocationValidator();

  ValidationResult validate(CustomerServiceLocationFormState input) {
    final codes = <String>[];

    if (input.name.trim().isEmpty) {
      codes.add(CustomerException.serviceLocationNameRequired);
    }
    _validateEmail(input.contactPersonEmail, codes);
    _validateCoordinates(input, codes);

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  void _validateEmail(String? email, List<String> codes) {
    final trimmed = email?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (!trimmed.contains('@')) {
      codes.add(CustomerException.emailInvalid);
    }
  }

  void _validateCoordinates(
    CustomerServiceLocationFormState input,
    List<String> codes,
  ) {
    final hasLatitude = input.latitude != null;
    final hasLongitude = input.longitude != null;

    if (hasLatitude != hasLongitude) {
      codes.add(CustomerException.serviceLocationCoordinatePairRequired);
      return;
    }

    if (!hasLatitude) {
      if (input.resolutionSource != null ||
          input.resolvedAt != null ||
          input.coordinateAccuracyM != null ||
          input.resolutionStatus != null ||
          input.resolutionError?.trim().isNotEmpty == true) {
        codes.add(CustomerException.serviceLocationCoordinateMetadataInvalid);
      }
      return;
    }

    if (input.latitude! < -90 || input.latitude! > 90) {
      codes.add(CustomerException.serviceLocationLatitudeInvalid);
    }
    if (input.longitude! < -180 || input.longitude! > 180) {
      codes.add(CustomerException.serviceLocationLongitudeInvalid);
    }
    if (input.resolutionSource == null ||
        input.resolvedAt == null ||
        input.resolutionStatus != CoordinateResolutionStatus.resolved ||
        (input.coordinateAccuracyM != null && input.coordinateAccuracyM! < 0)) {
      codes.add(CustomerException.serviceLocationCoordinateMetadataInvalid);
    }
  }
}
