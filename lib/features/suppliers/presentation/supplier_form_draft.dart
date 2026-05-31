import '../../../core/errors/supplier_exception.dart';
import '../domain/supplier.dart';
import '../domain/supplier_form_state.dart';

/// Mutable string-backed draft for the supplier form.
///
/// [validate] reports stable error codes; only call [toFormState] when it
/// returns an empty list.
class SupplierFormDraft {
  const SupplierFormDraft({
    this.nameAr = '',
    this.nameEn = '',
    this.phone = '',
    this.email = '',
    this.address = '',
  });

  factory SupplierFormDraft.empty() => const SupplierFormDraft();

  factory SupplierFormDraft.fromSupplier(Supplier supplier) {
    return SupplierFormDraft(
      nameAr: supplier.nameAr,
      nameEn: supplier.nameEn ?? '',
      phone: supplier.phone ?? '',
      email: supplier.email ?? '',
      address: supplier.address ?? '',
    );
  }

  final String nameAr;
  final String nameEn;
  final String phone;
  final String email;
  final String address;

  SupplierFormDraft copyWith({
    String? nameAr,
    String? nameEn,
    String? phone,
    String? email,
    String? address,
  }) {
    return SupplierFormDraft(
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
    );
  }

  List<String> validate() {
    final codes = <String>[];
    if (nameAr.trim().isEmpty) {
      codes.add(SupplierException.nameArRequired);
    }
    final emailText = email.trim();
    if (emailText.isNotEmpty && !emailText.contains('@')) {
      codes.add(SupplierException.emailInvalid);
    }
    return codes;
  }

  /// Builds the repository form state. Assumes [validate] returned no codes.
  SupplierFormState toFormState() {
    return SupplierFormState(
      nameAr: nameAr.trim(),
      nameEn: _nullIfBlank(nameEn),
      phone: _nullIfBlank(phone),
      email: _nullIfBlank(email),
      address: _nullIfBlank(address),
    );
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
