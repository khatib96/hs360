/// Full create/edit supplier form. Repository maps to M2 RPC payloads.
class SupplierFormState {
  const SupplierFormState({
    required this.nameAr,
    this.nameEn,
    this.phone,
    this.email,
    this.address,
  });

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
