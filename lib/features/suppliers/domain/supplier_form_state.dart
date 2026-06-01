import '../../../core/location/kuwait_locations.dart';
import 'supplier.dart';

/// Full create/edit supplier form. Repository maps to M5.5 RPC payloads.
class SupplierFormState {
  const SupplierFormState({
    required this.nameAr,
    this.nameEn,
    this.phone,
    this.email,
    this.country = kuwaitCountryCanonical,
    this.governorate,
    this.area,
    this.addressLine,
    this.googleMapsUrl,
    this.taxNumber,
    this.notes,
    this.createAccount = false,
  });

  factory SupplierFormState.fromSupplier(Supplier supplier) {
    return SupplierFormState(
      nameAr: supplier.nameAr,
      nameEn: supplier.nameEn,
      phone: supplier.phone,
      email: supplier.email,
      country: supplier.country ?? kuwaitCountryCanonical,
      governorate: supplier.governorate,
      area: supplier.area,
      addressLine: supplier.addressLine,
      googleMapsUrl: supplier.googleMapsUrl,
      taxNumber: supplier.taxNumber,
      notes: supplier.notes,
    );
  }

  final String nameAr;
  final String? nameEn;
  final String? phone;
  final String? email;
  final String? country;
  final String? governorate;
  final String? area;
  final String? addressLine;
  final String? googleMapsUrl;
  final String? taxNumber;
  final String? notes;
  final bool createAccount;

  Map<String, dynamic> toCreatePayload() {
    return {
      'name_ar': nameAr.trim(),
      if (nameEn?.trim().isNotEmpty == true) 'name_en': nameEn!.trim(),
      if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
      if (country?.trim().isNotEmpty == true) 'country': country!.trim(),
      if (governorate?.trim().isNotEmpty == true)
        'governorate': governorate!.trim(),
      if (area?.trim().isNotEmpty == true) 'area': area!.trim(),
      if (addressLine?.trim().isNotEmpty == true)
        'address_line': addressLine!.trim(),
      if (googleMapsUrl?.trim().isNotEmpty == true)
        'google_maps_url': googleMapsUrl!.trim(),
      if (taxNumber?.trim().isNotEmpty == true) 'tax_number': taxNumber!.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      'create_account': createAccount,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'name_ar': nameAr.trim(),
      'name_en': nameEn?.trim(),
      'phone': phone?.trim(),
      'email': email?.trim(),
      'country': country?.trim(),
      'governorate': governorate?.trim(),
      'area': area?.trim(),
      'address_line': addressLine?.trim(),
      'google_maps_url': googleMapsUrl?.trim(),
      'tax_number': taxNumber?.trim(),
      'notes': notes?.trim(),
    };
  }
}
