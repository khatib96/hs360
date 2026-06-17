/// Mirrors Postgres `voucher_type`.
enum VoucherType {
  receipt('receipt'),
  payment('payment');

  const VoucherType(this.dbValue);

  final String dbValue;

  static VoucherType fromDb(String? value) {
    if (value == null) {
      throw FormatException('VoucherType value is null');
    }
    for (final type in VoucherType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown VoucherType: $value');
  }

  String toDb() => dbValue;
}
