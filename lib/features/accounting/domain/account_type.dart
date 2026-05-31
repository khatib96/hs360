enum AccountType {
  asset('asset'),
  liability('liability'),
  equity('equity'),
  income('income'),
  expense('expense');

  const AccountType(this.dbValue);

  final String dbValue;

  static AccountType fromDb(String? value) {
    if (value == null) {
      throw FormatException('AccountType value is null');
    }
    for (final type in AccountType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown AccountType: $value');
  }

  String toDb() => dbValue;
}
