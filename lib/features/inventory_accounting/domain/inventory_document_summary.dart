/// Pre-M4.5 inventory financial document kinds (stub domain).
enum InventoryDocumentKind {
  openingStock('opening_stock'),
  stockIn('stock_in'),
  stockOut('stock_out'),
  stockCount('stock_count');

  const InventoryDocumentKind(this.dbValue);

  final String dbValue;

  static InventoryDocumentKind fromDb(String? value) {
    if (value == null) {
      throw FormatException('InventoryDocumentKind value is null');
    }
    for (final kind in InventoryDocumentKind.values) {
      if (kind.dbValue == value) return kind;
    }
    throw FormatException('Unknown InventoryDocumentKind: $value');
  }

  String toDb() => dbValue;
}

enum InventoryDocumentStatus {
  draft('draft'),
  confirmed('confirmed'),
  cancelled('cancelled');

  const InventoryDocumentStatus(this.dbValue);

  final String dbValue;

  static InventoryDocumentStatus fromDb(String? value) {
    if (value == null) {
      throw FormatException('InventoryDocumentStatus value is null');
    }
    for (final status in InventoryDocumentStatus.values) {
      if (status.dbValue == value) return status;
    }
    throw FormatException('Unknown InventoryDocumentStatus: $value');
  }

  String toDb() => dbValue;
}

class InventoryDocumentSummary {
  const InventoryDocumentSummary({
    required this.id,
    this.documentNumber,
    required this.kind,
    required this.status,
    required this.date,
    required this.warehouseId,
    this.warehouseNameAr,
    this.warehouseNameEn,
    this.journalEntryId,
  });

  final String id;
  final String? documentNumber;
  final InventoryDocumentKind kind;
  final InventoryDocumentStatus status;
  final DateTime date;
  final String warehouseId;
  final String? warehouseNameAr;
  final String? warehouseNameEn;
  final String? journalEntryId;
}
