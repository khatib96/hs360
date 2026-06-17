/// Mirrors Postgres `voucher_status`.
enum VoucherStatus {
  confirmed('confirmed'),
  cancelled('cancelled');

  const VoucherStatus(this.dbValue);

  final String dbValue;

  static VoucherStatus fromDb(String? value) {
    if (value == null) {
      throw FormatException('VoucherStatus value is null');
    }
    for (final status in VoucherStatus.values) {
      if (status.dbValue == value) return status;
    }
    throw FormatException('Unknown VoucherStatus: $value');
  }

  String toDb() => dbValue;

  bool get isCancelled => this == cancelled;
}
