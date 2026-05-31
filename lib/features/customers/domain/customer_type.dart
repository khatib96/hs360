enum CustomerType {
  individual('individual'),
  company('company');

  const CustomerType(this.dbValue);

  final String dbValue;

  static CustomerType fromDb(String? value) {
    if (value == null) {
      throw FormatException('CustomerType value is null');
    }
    for (final type in CustomerType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown CustomerType: $value');
  }

  String toDb() => dbValue;
}
