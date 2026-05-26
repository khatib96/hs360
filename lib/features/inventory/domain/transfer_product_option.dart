/// Lightweight product row from [search_transfer_products] RPC (no cost fields).
class TransferProductOption {
  const TransferProductOption({
    required this.id,
    required this.sku,
    required this.nameAr,
    required this.nameEn,
    required this.isSerialized,
    required this.unitPrimary,
  });

  final String id;
  final String sku;
  final String nameAr;
  final String nameEn;
  final bool isSerialized;
  final String unitPrimary;

  factory TransferProductOption.fromRow(Map<String, dynamic> row) {
    return TransferProductOption(
      id: row['id'] as String,
      sku: row['sku'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String,
      isSerialized: row['is_serialized'] as bool,
      unitPrimary: row['unit_primary'] as String,
    );
  }
}
