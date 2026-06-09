import '../../../core/errors/supplier_exception.dart';
import '../../../core/location/kuwait_locations.dart';
import '../domain/supplier.dart';
import '../domain/supplier_form_state.dart';

class SupplierFormDraft {
  const SupplierFormDraft({
    this.nameAr = '',
    this.nameEn = '',
    this.phone = '',
    this.email = '',
    this.taxNumber = '',
    this.country = kuwaitCountryCanonical,
    this.governorate = '',
    this.area = '',
    this.addressLine = '',
    this.googleMapsUrl = '',
    this.notes = '',
    this.createAccount = false,
    this.useCustomArea = false,
    this.customArea = '',
  });

  factory SupplierFormDraft.empty() => const SupplierFormDraft();

  factory SupplierFormDraft.fromSupplier(Supplier supplier) {
    final gov = supplier.governorate ?? '';
    final area = supplier.area ?? '';
    final catalogAreas = areasForGovernorate(
      gov.isEmpty ? null : gov,
    ).map((a) => a.canonical).toList();
    final inCatalog = catalogAreas.contains(area);
    return SupplierFormDraft(
      nameAr: supplier.nameAr,
      nameEn: supplier.nameEn ?? '',
      phone: supplier.phone ?? '',
      email: supplier.email ?? '',
      taxNumber: supplier.taxNumber ?? '',
      country: supplier.country ?? kuwaitCountryCanonical,
      governorate: gov,
      area: inCatalog ? area : '',
      addressLine: supplier.addressLine ?? '',
      googleMapsUrl: supplier.googleMapsUrl ?? '',
      notes: supplier.notes ?? '',
      useCustomArea: area.isNotEmpty && !inCatalog,
      customArea: inCatalog ? '' : area,
    );
  }

  final String nameAr;
  final String nameEn;
  final String phone;
  final String email;
  final String taxNumber;
  final String country;
  final String governorate;
  final String area;
  final String addressLine;
  final String googleMapsUrl;
  final String notes;
  final bool createAccount;
  final bool useCustomArea;
  final String customArea;

  SupplierFormDraft copyWith({
    String? nameAr,
    String? nameEn,
    String? phone,
    String? email,
    String? taxNumber,
    String? country,
    String? governorate,
    String? area,
    String? addressLine,
    String? googleMapsUrl,
    String? notes,
    bool? createAccount,
    bool? useCustomArea,
    String? customArea,
  }) {
    return SupplierFormDraft(
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      country: country ?? this.country,
      governorate: governorate ?? this.governorate,
      area: area ?? this.area,
      addressLine: addressLine ?? this.addressLine,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      notes: notes ?? this.notes,
      createAccount: createAccount ?? this.createAccount,
      useCustomArea: useCustomArea ?? this.useCustomArea,
      customArea: customArea ?? this.customArea,
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

  SupplierFormState toFormState() {
    return SupplierFormState(
      nameAr: nameAr.trim(),
      nameEn: _nullIfBlank(nameEn),
      phone: _nullIfBlank(phone),
      email: _nullIfBlank(email),
      country: _nullIfBlank(country) ?? kuwaitCountryCanonical,
      governorate: _nullIfBlank(governorate),
      area: resolvedArea(),
      addressLine: _nullIfBlank(addressLine),
      googleMapsUrl: _nullIfBlank(googleMapsUrl),
      taxNumber: _nullIfBlank(taxNumber),
      notes: _nullIfBlank(notes),
      createAccount: createAccount,
    );
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
