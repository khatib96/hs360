/// Mirrors Postgres `payment_method` enum.
enum PaymentMethod {
  cash('cash'),
  knet('knet'),
  bankTransfer('bank_transfer'),
  cheque('cheque'),
  other('other');

  const PaymentMethod(this.dbValue);

  final String dbValue;

  static PaymentMethod fromDb(String? value) {
    if (value == null) {
      throw FormatException('PaymentMethod value is null');
    }
    for (final method in PaymentMethod.values) {
      if (method.dbValue == value) return method;
    }
    throw FormatException('Unknown PaymentMethod: $value');
  }

  String toDb() => dbValue;
}
