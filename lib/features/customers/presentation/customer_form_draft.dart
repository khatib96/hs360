import 'package:decimal/decimal.dart';

import '../../../core/errors/customer_exception.dart';
import '../domain/customer.dart';
import '../domain/customer_form_state.dart';
import '../domain/customer_type.dart';

/// Mutable string-backed draft for the customer form.
///
/// Parsing is deliberately strict: [validate] reports stable error codes for
/// unparseable numeric/GPS text instead of silently coercing to null/zero.
/// Only call [toFormState] after [validate] returns an empty list.
class CustomerFormDraft {
  const CustomerFormDraft({
    this.customerType = CustomerType.individual,
    this.nameAr = '',
    this.nameEn = '',
    this.contactPersonName = '',
    this.contactPersonTitle = '',
    this.contactPersonPhone = '',
    this.phonePrimary = '',
    this.phoneSecondary = '',
    this.whatsapp = '',
    this.email = '',
    this.addressLine = '',
    this.area = '',
    this.city = '',
    this.country = 'Kuwait',
    this.gpsLat = '',
    this.gpsLng = '',
    this.paymentTermsDays = '',
    this.creditLimit = '',
    this.isVip = false,
    this.notes = '',
  });

  factory CustomerFormDraft.empty() => const CustomerFormDraft();

  factory CustomerFormDraft.fromCustomer(Customer customer) {
    return CustomerFormDraft(
      customerType: customer.customerType,
      nameAr: customer.nameAr,
      nameEn: customer.nameEn ?? '',
      contactPersonName: customer.contactPersonName ?? '',
      contactPersonTitle: customer.contactPersonTitle ?? '',
      contactPersonPhone: customer.contactPersonPhone ?? '',
      phonePrimary: customer.phonePrimary,
      phoneSecondary: customer.phoneSecondary ?? '',
      whatsapp: customer.whatsapp ?? '',
      email: customer.email ?? '',
      addressLine: customer.addressLine ?? '',
      area: customer.area ?? '',
      city: customer.city ?? '',
      country: customer.country ?? '',
      gpsLat: customer.gpsLat?.toString() ?? '',
      gpsLng: customer.gpsLng?.toString() ?? '',
      paymentTermsDays: customer.paymentTermsDays.toString(),
      creditLimit: customer.creditLimit.toString(),
      isVip: customer.isVip,
      notes: customer.notes ?? '',
    );
  }

  /// UI-only error code for unparseable decimal text.
  static const invalidDecimal = 'invalid_decimal';

  /// UI-only error code for unparseable integer text.
  static const invalidInteger = 'invalid_integer';

  final CustomerType customerType;
  final String nameAr;
  final String nameEn;
  final String contactPersonName;
  final String contactPersonTitle;
  final String contactPersonPhone;
  final String phonePrimary;
  final String phoneSecondary;
  final String whatsapp;
  final String email;
  final String addressLine;
  final String area;
  final String city;
  final String country;
  final String gpsLat;
  final String gpsLng;
  final String paymentTermsDays;
  final String creditLimit;
  final bool isVip;
  final String notes;

  CustomerFormDraft copyWith({
    CustomerType? customerType,
    String? nameAr,
    String? nameEn,
    String? contactPersonName,
    String? contactPersonTitle,
    String? contactPersonPhone,
    String? phonePrimary,
    String? phoneSecondary,
    String? whatsapp,
    String? email,
    String? addressLine,
    String? area,
    String? city,
    String? country,
    String? gpsLat,
    String? gpsLng,
    String? paymentTermsDays,
    String? creditLimit,
    bool? isVip,
    String? notes,
  }) {
    return CustomerFormDraft(
      customerType: customerType ?? this.customerType,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      contactPersonTitle: contactPersonTitle ?? this.contactPersonTitle,
      contactPersonPhone: contactPersonPhone ?? this.contactPersonPhone,
      phonePrimary: phonePrimary ?? this.phonePrimary,
      phoneSecondary: phoneSecondary ?? this.phoneSecondary,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      addressLine: addressLine ?? this.addressLine,
      area: area ?? this.area,
      city: city ?? this.city,
      country: country ?? this.country,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      paymentTermsDays: paymentTermsDays ?? this.paymentTermsDays,
      creditLimit: creditLimit ?? this.creditLimit,
      isVip: isVip ?? this.isVip,
      notes: notes ?? this.notes,
    );
  }

  /// Returns stable error codes for any invalid input. Empty list means valid.
  List<String> validate() {
    final codes = <String>[];

    if (nameAr.trim().isEmpty) {
      codes.add(CustomerException.nameArRequired);
    }
    if (phonePrimary.trim().isEmpty) {
      codes.add(CustomerException.phonePrimaryRequired);
    }

    final creditText = creditLimit.trim();
    if (creditText.isNotEmpty) {
      final parsed = Decimal.tryParse(creditText);
      if (parsed == null) {
        codes.add(invalidDecimal);
      } else if (parsed < Decimal.zero) {
        codes.add(CustomerException.negativeCreditLimit);
      }
    }

    final paymentText = paymentTermsDays.trim();
    if (paymentText.isNotEmpty) {
      final parsed = int.tryParse(paymentText);
      if (parsed == null) {
        codes.add(invalidInteger);
      } else if (parsed < 0) {
        codes.add(CustomerException.negativePaymentTerms);
      }
    }

    _validateGps(codes);

    final emailText = email.trim();
    if (emailText.isNotEmpty && !emailText.contains('@')) {
      codes.add(CustomerException.emailInvalid);
    }

    return codes;
  }

  void _validateGps(List<String> codes) {
    final latText = gpsLat.trim();
    final lngText = gpsLng.trim();
    if (latText.isEmpty && lngText.isEmpty) return;
    if (latText.isEmpty || lngText.isEmpty) {
      codes.add(CustomerException.gpsInvalid);
      return;
    }
    final lat = Decimal.tryParse(latText);
    final lng = Decimal.tryParse(lngText);
    if (lat == null || lng == null) {
      codes.add(CustomerException.gpsInvalid);
      return;
    }
    if (lat < Decimal.fromInt(-90) ||
        lat > Decimal.fromInt(90) ||
        lng < Decimal.fromInt(-180) ||
        lng > Decimal.fromInt(180)) {
      codes.add(CustomerException.gpsInvalid);
    }
  }

  /// Builds the repository form state. Assumes [validate] returned no codes.
  CustomerFormState toFormState() {
    return CustomerFormState(
      customerType: customerType,
      nameAr: nameAr.trim(),
      nameEn: _nullIfBlank(nameEn),
      contactPersonName: _nullIfBlank(contactPersonName),
      contactPersonTitle: _nullIfBlank(contactPersonTitle),
      contactPersonPhone: _nullIfBlank(contactPersonPhone),
      phonePrimary: phonePrimary.trim(),
      phoneSecondary: _nullIfBlank(phoneSecondary),
      whatsapp: _nullIfBlank(whatsapp),
      email: _nullIfBlank(email),
      addressLine: _nullIfBlank(addressLine),
      area: _nullIfBlank(area),
      city: _nullIfBlank(city),
      country: _nullIfBlank(country),
      gpsLat: _decimalOrNull(gpsLat),
      gpsLng: _decimalOrNull(gpsLng),
      paymentTermsDays: int.tryParse(paymentTermsDays.trim()) ?? 0,
      creditLimit: Decimal.tryParse(creditLimit.trim()) ?? Decimal.zero,
      isVip: isVip,
      notes: _nullIfBlank(notes),
    );
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Decimal? _decimalOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return Decimal.tryParse(trimmed);
  }
}
