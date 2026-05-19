enum ProductType {
  saleOnly('sale_only'),
  assetRental('asset_rental'),
  consumableRental('consumable_rental');

  const ProductType(this.dbValue);

  final String dbValue;

  static ProductType fromDb(String? value) {
    if (value == null) {
      throw FormatException('ProductType value is null');
    }
    for (final type in ProductType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown ProductType: $value');
  }

  String toDb() => dbValue;
}
