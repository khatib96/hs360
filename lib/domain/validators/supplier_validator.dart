import '../../core/errors/supplier_exception.dart';
import '../../features/suppliers/domain/supplier_form_state.dart';
import 'validation_result.dart';

class SupplierValidator {
  const SupplierValidator();

  ValidationResult validate(SupplierFormState input) {
    final codes = <String>[];

    if (input.nameAr.trim().isEmpty) {
      codes.add(SupplierException.nameArRequired);
    }

    final email = input.email?.trim();
    if (email != null && email.isNotEmpty && !email.contains('@')) {
      codes.add(SupplierException.emailInvalid);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
