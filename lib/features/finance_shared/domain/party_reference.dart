/// Customer, supplier, or direct account party on a finance document.
class PartyReference {
  const PartyReference({
    this.customerId,
    this.supplierId,
    this.accountId,
    this.code,
    required this.nameAr,
    required this.nameEn,
  });

  final String? customerId;
  final String? supplierId;
  final String? accountId;
  final String? code;
  final String nameAr;
  final String nameEn;

  String displayName(String languageCode) {
    if (languageCode.startsWith('ar')) {
      return nameAr.isNotEmpty ? nameAr : nameEn;
    }
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  factory PartyReference.fromCustomerJson(Map<String, dynamic> json) {
    return PartyReference(
      customerId: json['id'] as String?,
      code: json['code'] as String?,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      accountId: json['account_id'] as String?,
    );
  }

  factory PartyReference.fromSupplierJson(Map<String, dynamic> json) {
    return PartyReference(
      supplierId: json['id'] as String?,
      code: json['code'] as String?,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      accountId: json['account_id'] as String?,
    );
  }
}
