import '../../core/errors/customer_exception.dart';
import '../../features/customers/domain/customer_service_location_form_state.dart';
import 'validation_result.dart';

class CustomerServiceLocationValidator {
  const CustomerServiceLocationValidator();

  ValidationResult validate(CustomerServiceLocationFormState input) {
    final codes = <String>[];

    if (input.name.trim().isEmpty) {
      codes.add(CustomerException.serviceLocationNameRequired);
    }
    _validateEmail(input.contactPersonEmail, codes);

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
}
