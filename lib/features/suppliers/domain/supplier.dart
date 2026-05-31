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
    this.address,
    required this.accountId,
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
  final String? address;
  final String accountId;
  final bool isActive;
  final DateTime? createdAt;

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
      address: row['address'] as String?,
      accountId: row['account_id'] as String,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }
}

/// Explicit column list for [suppliers] (no updated_at column).
abstract final class SupplierColumns {
  static const list = '''
id, tenant_id, code, name_ar, name_en, phone, email, address,
account_id, is_active, created_at
''';
}
