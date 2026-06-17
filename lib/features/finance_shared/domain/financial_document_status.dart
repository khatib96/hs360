/// Shared lifecycle status for finance documents (invoices, vouchers, inventory docs).
enum FinancialDocumentStatus {
  draft('draft'),
  confirmed('confirmed'),
  partiallyPaid('partially_paid'),
  paid('paid'),
  cancelled('cancelled');

  const FinancialDocumentStatus(this.dbValue);

  final String dbValue;

  static FinancialDocumentStatus fromDb(String? value) {
    if (value == null) {
      throw FormatException('FinancialDocumentStatus value is null');
    }
    for (final status in FinancialDocumentStatus.values) {
      if (status.dbValue == value) return status;
    }
    throw FormatException('Unknown FinancialDocumentStatus: $value');
  }

  String toDb() => dbValue;

  bool get isDraft => this == draft;
  bool get isCancelled => this == cancelled;
  bool get isPosted => this != draft && this != cancelled;
}
