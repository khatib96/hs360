enum WarehouseType {
  main('main'),
  branch('branch'),
  van('van');

  const WarehouseType(this.dbValue);

  final String dbValue;

  static WarehouseType fromDb(String? value) {
    if (value == null) {
      throw FormatException('WarehouseType value is null');
    }
    for (final type in WarehouseType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown WarehouseType: $value');
  }

  String toDb() => dbValue;
}
