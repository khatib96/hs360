enum ScanResultKind {
  product,
  productUnit;

  static ScanResultKind fromDb(String value) {
    return switch (value) {
      'product' => ScanResultKind.product,
      'product_unit' => ScanResultKind.productUnit,
      _ => ScanResultKind.product,
    };
  }

  String toDb() {
    return switch (this) {
      ScanResultKind.product => 'product',
      ScanResultKind.productUnit => 'product_unit',
    };
  }
}

enum ScanMatchedBy {
  unitBarcode,
  productBarcode,
  serialNumber;

  static ScanMatchedBy fromDb(String value) {
    return switch (value) {
      'unit_barcode' => ScanMatchedBy.unitBarcode,
      'product_barcode' => ScanMatchedBy.productBarcode,
      'serial_number' => ScanMatchedBy.serialNumber,
      _ => ScanMatchedBy.serialNumber,
    };
  }

  String toDb() {
    return switch (this) {
      ScanMatchedBy.unitBarcode => 'unit_barcode',
      ScanMatchedBy.productBarcode => 'product_barcode',
      ScanMatchedBy.serialNumber => 'serial_number',
    };
  }
}

class ScanResult {
  const ScanResult({
    required this.id,
    required this.productId,
    required this.kind,
    required this.matchedBy,
    required this.displayCode,
    required this.isActiveOrAvailable,
  });

  final String id;
  final String productId;
  final ScanResultKind kind;
  final ScanMatchedBy matchedBy;
  final String displayCode;
  final bool isActiveOrAvailable;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      kind: ScanResultKind.fromDb(json['kind'] as String),
      matchedBy: ScanMatchedBy.fromDb(json['matched_by'] as String),
      displayCode: json['display_code'] as String,
      isActiveOrAvailable: json['is_active_or_available'] as bool? ?? false,
    );
  }
}
