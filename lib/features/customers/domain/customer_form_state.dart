import '../../../core/location/kuwait_locations.dart';
import 'customer.dart';
import 'customer_type.dart';

/// Full create/edit customer form. Repository maps to M5.5 RPC payloads.
class CustomerFormState {
  CustomerFormState({
    this.customerType = CustomerType.individual,
    required this.nameAr,
    this.nameEn,
    this.contactPersonName,
    this.contactPersonPhone,
    required this.phonePrimary,
    this.email,
    this.addressLine,
    this.area,
    this.governorate,
    this.country = kuwaitCountryCanonical,
    this.googleMapsUrl,
    this.taxNumber,
    this.isVip = false,
    this.notes,
    this.createAccount = false,
    this.acquiredBy,
    this.acquiredAt,
  });

  factory CustomerFormState.fromCustomer(Customer customer) {
    return CustomerFormState(
      customerType: customer.customerType,
      nameAr: customer.nameAr,
      nameEn: customer.nameEn,
      contactPersonName: customer.contactPersonName,
      contactPersonPhone: customer.contactPersonPhone,
      phonePrimary: customer.phonePrimary,
      email: customer.email,
      addressLine: customer.addressLine,
      area: customer.area,
      governorate: customer.governorate,
      country: customer.country ?? kuwaitCountryCanonical,
      googleMapsUrl: customer.googleMapsUrl,
      taxNumber: customer.taxNumber,
      isVip: customer.isVip,
      notes: customer.notes,
    );
  }

  final CustomerType customerType;
  final String nameAr;
  final String? nameEn;
  final String? contactPersonName;
  final String? contactPersonPhone;
  final String phonePrimary;
  final String? email;
  final String? addressLine;
  final String? area;
  final String? governorate;
  final String? country;
  final String? googleMapsUrl;
  final String? taxNumber;
  final bool isVip;
  final String? notes;
  final bool createAccount;
  final String? acquiredBy;
  final DateTime? acquiredAt;

  Map<String, dynamic> toCreatePayload() {
    return {
      'customer_type': customerType.toDb(),
      'name_ar': nameAr.trim(),
      if (nameEn?.trim().isNotEmpty == true) 'name_en': nameEn!.trim(),
      if (customerType == CustomerType.company) ...{
        if (contactPersonName?.trim().isNotEmpty == true)
          'contact_person_name': contactPersonName!.trim(),
        if (contactPersonPhone?.trim().isNotEmpty == true)
          'contact_person_phone': contactPersonPhone!.trim(),
        if (taxNumber?.trim().isNotEmpty == true) 'tax_number': taxNumber!.trim(),
      },
      'phone_primary': phonePrimary.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
      if (addressLine?.trim().isNotEmpty == true)
        'address_line': addressLine!.trim(),
      if (area?.trim().isNotEmpty == true) 'area': area!.trim(),
      if (governorate?.trim().isNotEmpty == true)
        'governorate': governorate!.trim(),
      if (country?.trim().isNotEmpty == true) 'country': country!.trim(),
      if (googleMapsUrl?.trim().isNotEmpty == true)
        'google_maps_url': googleMapsUrl!.trim(),
      'is_vip': isVip,
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      'create_account': createAccount,
      if (acquiredBy != null) 'acquired_by': acquiredBy,
      if (acquiredAt != null)
        'acquired_at': acquiredAt!.toIso8601String().split('T').first,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'customer_type': customerType.toDb(),
      'name_ar': nameAr.trim(),
      'name_en': nameEn?.trim(),
      'contact_person_name': customerType == CustomerType.company
          ? contactPersonName?.trim()
          : null,
      'contact_person_phone': customerType == CustomerType.company
          ? contactPersonPhone?.trim()
          : null,
      'phone_primary': phonePrimary.trim(),
      'email': email?.trim(),
      'address_line': addressLine?.trim(),
      'area': area?.trim(),
      'governorate': governorate?.trim(),
      'country': country?.trim(),
      'google_maps_url': googleMapsUrl?.trim(),
      'tax_number':
          customerType == CustomerType.company ? taxNumber?.trim() : null,
      'is_vip': isVip,
      'notes': notes?.trim(),
    };
  }
}
