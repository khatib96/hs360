import 'supplier.dart';

/// Full create/edit supplier form. Repository maps to M2 RPC payloads.
class SupplierFormState {
  const SupplierFormState({
    required this.nameAr,
    this.nameEn,
    this.phone,
    this.email,
    this.address,
  });

  /// Maps an existing [Supplier] to a form state for editing.
  /// Excludes generated code/account.
  factory SupplierFormState.fromSupplier(Supplier supplier) {
    return SupplierFormState(
      nameAr: supplier.nameAr,
      nameEn: supplier.nameEn,
      phone: supplier.phone,
      email: supplier.email,
      address: supplier.address,
    );
  }

  final String nameAr;
  final String? nameEn;
  final String? phone;
  final String? email;
  final String? address;

  Map<String, dynamic> toCreatePayload() {
    return {
      'name_ar': nameAr.trim(),
      if (nameEn?.trim().isNotEmpty == true) 'name_en': nameEn!.trim(),
      if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
      if (address?.trim().isNotEmpty == true) 'address': address!.trim(),
    };
  }

  Map<String, dynamic> toUpdatePayload() => toCreatePayload();
}
