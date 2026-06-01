/// Supplier row from [suppliers].
class Supplier {
  const Supplier({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.nameAr,
    this.nameEn,
    this.phone,
    this.email,
    this.country,
    this.governorate,
    this.area,
    this.addressLine,
    this.googleMapsUrl,
    this.taxNumber,
    this.notes,
    this.accountId,
    required this.isActive,
    this.createdAt,
  });

  static final _codePattern = RegExp(r'^SUP-\d{4,}$');

  final String id;
  final String tenantId;
  final String code;
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
  final String? accountId;
  final bool isActive;
  final DateTime? createdAt;

  bool get hasLinkedAccount => accountId != null && accountId!.isNotEmpty;

  static bool isStandardCodeFormat(String code) => _codePattern.hasMatch(code);

  String displayName(String locale) {
    if (locale == 'ar') return nameAr;
    final en = nameEn?.trim();
    if (en != null && en.isNotEmpty) return en;
    return nameAr;
  }

  factory Supplier.fromRow(Map<String, dynamic> row) {
    return Supplier(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      code: row['code'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String?,
      phone: row['phone'] as String?,
      email: row['email'] as String?,
      country: row['country'] as String?,
      governorate: row['governorate'] as String?,
      area: row['area'] as String?,
      addressLine: row['address_line'] as String?,
      googleMapsUrl: row['google_maps_url'] as String?,
      taxNumber: row['tax_number'] as String?,
      notes: row['notes'] as String?,
      accountId: row['account_id'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }
}

abstract final class SupplierColumns {
  static const list = '''
id, tenant_id, code, name_ar, name_en, phone, email,
country, governorate, area, address_line, google_maps_url,
tax_number, notes, account_id, is_active, created_at
''';
}
