/// Lightweight warehouse row from [list_transfer_warehouses] RPC.
class TransferWarehouseOption {
  const TransferWarehouseOption({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.type,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String type;

  factory TransferWarehouseOption.fromRow(Map<String, dynamic> row) {
    return TransferWarehouseOption(
      id: row['id'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String,
      type: row['type'] as String,
    );
  }
}
