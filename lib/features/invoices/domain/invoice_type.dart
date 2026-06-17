/// Mirrors Postgres `invoice_type` values used in Phase 5 finance flows.
enum InvoiceType {
  sales('sales'),
  purchase('purchase'),
  salesReturn('sales_return'),
  purchaseReturn('purchase_return');

  const InvoiceType(this.dbValue);

  final String dbValue;

  static InvoiceType fromDb(String? value) {
    if (value == null) {
      throw FormatException('InvoiceType value is null');
    }
    for (final type in InvoiceType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown InvoiceType: $value');
  }

  String toDb() => dbValue;

  bool get isReturn => this == salesReturn || this == purchaseReturn;

  bool get isSalesDirection => this == sales || this == salesReturn;

  bool get isPurchaseDirection => this == purchase || this == purchaseReturn;
}
