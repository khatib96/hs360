import '../../core/errors/customer_exception.dart';
import '../../features/customers/domain/customer_form_state.dart';
import 'validation_result.dart';

class CustomerValidator {
  const CustomerValidator();

  ValidationResult validate(CustomerFormState input) {
    final codes = <String>[];

    if (input.nameAr.trim().isEmpty) {
      codes.add(CustomerException.nameArRequired);
    }
    if (input.phonePrimary.trim().isEmpty) {
      codes.add(CustomerException.phonePrimaryRequired);
    }
    _validateEmail(input.email, codes);

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
