import 'customer_type.dart';

/// Customer row from [customers].
class Customer {
  const Customer({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.customerType,
    required this.nameAr,
    this.nameEn,
    this.contactPersonName,
    this.contactPersonPhone,
    required this.phonePrimary,
    this.email,
    this.addressLine,
    this.area,
    this.governorate,
    this.country,
    this.googleMapsUrl,
    this.taxNumber,
    this.accountId,
    required this.isActive,
    required this.isVip,
    this.notes,
    this.acquiredBy,
    this.acquiredAt,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  static final _codePattern = RegExp(r'^CUST-\d{4,}$');

  final String id;
  final String tenantId;
  final String code;
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
  final String? accountId;
  final bool isActive;
  final bool isVip;
  final String? notes;
  final String? acquiredBy;
  final DateTime? acquiredAt;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  bool get hasLinkedAccount => accountId != null && accountId!.isNotEmpty;

  static bool isStandardCodeFormat(String code) => _codePattern.hasMatch(code);

  String displayName(String locale) {
    if (locale == 'ar') return nameAr;
    final en = nameEn?.trim();
    if (en != null && en.isNotEmpty) return en;
    return nameAr;
  }

  factory Customer.fromRow(Map<String, dynamic> row) {
    return Customer(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      code: row['code'] as String,
      customerType: CustomerType.fromDb(row['customer_type'] as String?),
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String?,
      contactPersonName: row['contact_person_name'] as String?,
      contactPersonPhone: row['contact_person_phone'] as String?,
      phonePrimary: row['phone_primary'] as String,
      email: row['email'] as String?,
      addressLine: row['address_line'] as String?,
      area: row['area'] as String?,
      governorate: row['governorate'] as String?,
      country: row['country'] as String?,
      googleMapsUrl: row['google_maps_url'] as String?,
      taxNumber: row['tax_number'] as String?,
      accountId: row['account_id'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      isVip: row['is_vip'] as bool? ?? false,
      notes: row['notes'] as String?,
      acquiredBy: row['acquired_by'] as String?,
      acquiredAt: row['acquired_at'] != null
          ? DateTime.parse(row['acquired_at'] as String)
          : null,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      createdBy: row['created_by'] as String?,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      updatedBy: row['updated_by'] as String?,
    );
  }
}

/// Explicit column list for [customers] (never use *).
abstract final class CustomerColumns {
  static const list = '''
id, tenant_id, code, customer_type,
name_ar, name_en,
contact_person_name, contact_person_phone,
phone_primary, email,
address_line, area, governorate, country, google_maps_url,
tax_number, account_id,
is_active, is_vip, notes, acquired_by, acquired_at,
created_at, created_by, updated_at, updated_by
''';
}
