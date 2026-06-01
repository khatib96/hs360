import '../../../core/errors/customer_exception.dart';
import '../../../core/location/kuwait_locations.dart';
import '../domain/customer.dart';
import '../domain/customer_form_state.dart';
import '../domain/customer_type.dart';

/// Mutable string-backed draft for the customer form.
class CustomerFormDraft {
  const CustomerFormDraft({
    this.customerType = CustomerType.individual,
    this.nameAr = '',
    this.nameEn = '',
    this.contactPersonName = '',
    this.contactPersonPhone = '',
    this.phonePrimary = '',
    this.email = '',
    this.taxNumber = '',
    this.addressLine = '',
    this.area = '',
    this.governorate = '',
    this.country = kuwaitCountryCanonical,
    this.googleMapsUrl = '',
    this.isVip = false,
    this.notes = '',
    this.createAccount = false,
    this.useCustomArea = false,
    this.customArea = '',
  });

  factory CustomerFormDraft.empty() => const CustomerFormDraft();

  factory CustomerFormDraft.fromCustomer(Customer customer) {
    final gov = customer.governorate ?? '';
    final area = customer.area ?? '';
    final catalogAreas = areasForGovernorate(gov.isEmpty ? null : gov)
        .map((a) => a.canonical)
        .toList();
    final inCatalog = catalogAreas.contains(area);
    return CustomerFormDraft(
      customerType: customer.customerType,
      nameAr: customer.nameAr,
      nameEn: customer.nameEn ?? '',
      contactPersonName: customer.contactPersonName ?? '',
      contactPersonPhone: customer.contactPersonPhone ?? '',
      phonePrimary: customer.phonePrimary,
      email: customer.email ?? '',
      taxNumber: customer.taxNumber ?? '',
      addressLine: customer.addressLine ?? '',
      area: inCatalog ? area : '',
      governorate: gov,
      country: customer.country ?? kuwaitCountryCanonical,
      googleMapsUrl: customer.googleMapsUrl ?? '',
      isVip: customer.isVip,
      notes: customer.notes ?? '',
      useCustomArea: area.isNotEmpty && !inCatalog,
      customArea: inCatalog ? '' : area,
    );
  }

  final CustomerType customerType;
  final String nameAr;
  final String nameEn;
  final String contactPersonName;
  final String contactPersonPhone;
  final String phonePrimary;
  final String email;
  final String taxNumber;
  final String addressLine;
  final String area;
  final String governorate;
  final String country;
  final String googleMapsUrl;
  final bool isVip;
  final String notes;
  final bool createAccount;
  final bool useCustomArea;
  final String customArea;

  CustomerFormDraft copyWith({
    CustomerType? customerType,
    String? nameAr,
    String? nameEn,
    String? contactPersonName,
    String? contactPersonPhone,
    String? phonePrimary,
    String? email,
    String? taxNumber,
    String? addressLine,
    String? area,
    String? governorate,
    String? country,
    String? googleMapsUrl,
    bool? isVip,
    String? notes,
    bool? createAccount,
    bool? useCustomArea,
    String? customArea,
  }) {
    return CustomerFormDraft(
      customerType: customerType ?? this.customerType,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      contactPersonPhone: contactPersonPhone ?? this.contactPersonPhone,
      phonePrimary: phonePrimary ?? this.phonePrimary,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      addressLine: addressLine ?? this.addressLine,
      area: area ?? this.area,
      governorate: governorate ?? this.governorate,
      country: country ?? this.country,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      isVip: isVip ?? this.isVip,
      notes: notes ?? this.notes,
      createAccount: createAccount ?? this.createAccount,
      useCustomArea: useCustomArea ?? this.useCustomArea,
      customArea: customArea ?? this.customArea,
    );
  }

  List<String> validate() {
    final codes = <String>[];

    if (nameAr.trim().isEmpty) {
      codes.add(CustomerException.nameArRequired);
    }
    if (phonePrimary.trim().isEmpty) {
      codes.add(CustomerException.phonePrimaryRequired);
    }

    final emailText = email.trim();
    if (emailText.isNotEmpty && !emailText.contains('@')) {
      codes.add(CustomerException.emailInvalid);
    }

    return codes;
  }

  String? resolvedArea() {
    if (useCustomArea) {
      final custom = customArea.trim();
      return custom.isEmpty ? null : custom;
    }
    final selected = area.trim();
    if (selected.isEmpty || selected == kuwaitAreaOtherCanonical) {
      return null;
    }
    return selected;
  }

  CustomerFormState toFormState() {
    return CustomerFormState(
      customerType: customerType,
      nameAr: nameAr.trim(),
      nameEn: _nullIfBlank(nameEn),
      contactPersonName: customerType == CustomerType.company
          ? _nullIfBlank(contactPersonName)
          : null,
      contactPersonPhone: customerType == CustomerType.company
          ? _nullIfBlank(contactPersonPhone)
          : null,
      phonePrimary: phonePrimary.trim(),
      email: _nullIfBlank(email),
      addressLine: _nullIfBlank(addressLine),
      area: resolvedArea(),
      governorate: _nullIfBlank(governorate),
      country: _nullIfBlank(country) ?? kuwaitCountryCanonical,
      googleMapsUrl: _nullIfBlank(googleMapsUrl),
      taxNumber: customerType == CustomerType.company
          ? _nullIfBlank(taxNumber)
          : null,
      isVip: isVip,
      notes: _nullIfBlank(notes),
      createAccount: createAccount,
    );
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
