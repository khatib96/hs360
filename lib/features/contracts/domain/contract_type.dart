/// Mirrors Postgres `contract_type`.
enum ContractType {
  trial('trial'),
  rental('rental');

  const ContractType(this.dbValue);

  final String dbValue;

  static ContractType fromDb(String? value) {
    if (value == null) {
      throw FormatException('ContractType value is null');
    }
    for (final type in ContractType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown ContractType: $value');
  }

  String toDb() => dbValue;

  bool get isTrial => this == trial;
  bool get isRental => this == rental;
}
