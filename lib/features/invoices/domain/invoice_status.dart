/// Mirrors Postgres `invoice_status`.
enum InvoiceStatus {
  draft('draft'),
  confirmed('confirmed'),
  partiallyPaid('partially_paid'),
  paid('paid'),
  cancelled('cancelled');

  const InvoiceStatus(this.dbValue);

  final String dbValue;

  static InvoiceStatus fromDb(String? value) {
    if (value == null) {
      throw FormatException('InvoiceStatus value is null');
    }
    for (final status in InvoiceStatus.values) {
      if (status.dbValue == value) return status;
    }
    throw FormatException('Unknown InvoiceStatus: $value');
  }

  String toDb() => dbValue;

  bool get isDraft => this == draft;
  bool get isCancelled => this == cancelled;
  bool get isPosted => this != draft && this != cancelled;
}
