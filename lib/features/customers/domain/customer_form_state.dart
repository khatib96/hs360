import 'package:decimal/decimal.dart';

import 'customer.dart';
import 'customer_type.dart';

/// Full create/edit customer form. Repository maps to M2 RPC payloads.
class CustomerFormState {
  CustomerFormState({
    this.customerType = CustomerType.individual,
    required this.nameAr,
    this.nameEn,
    this.contactPersonName,
    this.contactPersonTitle,
    this.contactPersonPhone,
    required this.phonePrimary,
    this.phoneSecondary,
    this.whatsapp,
    this.email,
    this.addressLine,
    this.area,
    this.city,
    this.country = 'Kuwait',
    this.gpsLat,
    this.gpsLng,
    this.paymentTermsDays = 0,
    Decimal? creditLimit,
    this.isVip = false,
    this.notes,
    this.acquiredBy,
    this.acquiredAt,
  }) : creditLimit = creditLimit ?? Decimal.zero;

  /// Maps an existing [Customer] to a form state for editing.
  /// Excludes generated code/account and acquired_by/acquired_at (M2 update scope).
  factory CustomerFormState.fromCustomer(Customer customer) {
    return CustomerFormState(
      customerType: customer.customerType,
      nameAr: customer.nameAr,
      nameEn: customer.nameEn,
      contactPersonName: customer.contactPersonName,
      contactPersonTitle: customer.contactPersonTitle,
      contactPersonPhone: customer.contactPersonPhone,
      phonePrimary: customer.phonePrimary,
      phoneSecondary: customer.phoneSecondary,
      whatsapp: customer.whatsapp,
      email: customer.email,
      addressLine: customer.addressLine,
      area: customer.area,
      city: customer.city,
      country: customer.country,
      gpsLat: customer.gpsLat,
      gpsLng: customer.gpsLng,
      paymentTermsDays: customer.paymentTermsDays,
      creditLimit: customer.creditLimit,
      isVip: customer.isVip,
      notes: customer.notes,
    );
  }

  final CustomerType customerType;
  final String nameAr;
  final String? nameEn;
  final String? contactPersonName;
  final String? contactPersonTitle;
  final String? contactPersonPhone;
  final String phonePrimary;
  final String? phoneSecondary;
  final String? whatsapp;
  final String? email;
  final String? addressLine;
  final String? area;
  final String? city;
  final String? country;
  final Decimal? gpsLat;
  final Decimal? gpsLng;
  final int paymentTermsDays;
  final Decimal creditLimit;
  final bool isVip;
  final String? notes;
  final String? acquiredBy;
  final DateTime? acquiredAt;

  Map<String, dynamic> toCreatePayload() {
    return {
      'customer_type': customerType.toDb(),
      'name_ar': nameAr.trim(),
      if (nameEn?.trim().isNotEmpty == true) 'name_en': nameEn!.trim(),
      if (contactPersonName?.trim().isNotEmpty == true)
        'contact_person_name': contactPersonName!.trim(),
      if (contactPersonTitle?.trim().isNotEmpty == true)
        'contact_person_title': contactPersonTitle!.trim(),
      if (contactPersonPhone?.trim().isNotEmpty == true)
        'contact_person_phone': contactPersonPhone!.trim(),
      'phone_primary': phonePrimary.trim(),
      if (phoneSecondary?.trim().isNotEmpty == true)
        'phone_secondary': phoneSecondary!.trim(),
      if (whatsapp?.trim().isNotEmpty == true) 'whatsapp': whatsapp!.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
      if (addressLine?.trim().isNotEmpty == true)
        'address_line': addressLine!.trim(),
      if (area?.trim().isNotEmpty == true) 'area': area!.trim(),
      if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
      if (country?.trim().isNotEmpty == true) 'country': country!.trim(),
      if (gpsLat != null) 'gps_lat': gpsLat.toString(),
      if (gpsLng != null) 'gps_lng': gpsLng.toString(),
      'payment_terms_days': paymentTermsDays,
      'credit_limit': creditLimit.toString(),
      'is_vip': isVip,
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      if (acquiredBy != null) 'acquired_by': acquiredBy,
      if (acquiredAt != null)
        'acquired_at': acquiredAt!.toIso8601String().split('T').first,
    };
  }

  /// Only fields handled by M2 [update_customer]. Excludes acquired_by/acquired_at.
  Map<String, dynamic> toUpdatePayload() {
    return {
      'customer_type': customerType.toDb(),
      'name_ar': nameAr.trim(),
      'name_en': nameEn?.trim(),
      'contact_person_name': contactPersonName?.trim(),
      'contact_person_title': contactPersonTitle?.trim(),
      'contact_person_phone': contactPersonPhone?.trim(),
      'phone_primary': phonePrimary.trim(),
      'phone_secondary': phoneSecondary?.trim(),
      'whatsapp': whatsapp?.trim(),
      'email': email?.trim(),
      'address_line': addressLine?.trim(),
      'area': area?.trim(),
      'city': city?.trim(),
      'country': country?.trim(),
      'gps_lat': gpsLat?.toString(),
      'gps_lng': gpsLng?.toString(),
      'payment_terms_days': paymentTermsDays,
      'credit_limit': creditLimit.toString(),
      'is_vip': isVip,
      'notes': notes?.trim(),
    };
  }
}
