/// Mirrors Postgres `contract_status`.
enum ContractStatus {
  draft('draft'),
  active('active'),
  suspended('suspended'),
  completed('completed'),
  terminatedEarly('terminated_early'),
  expired('expired');

  const ContractStatus(this.dbValue);

  final String dbValue;

  static ContractStatus fromDb(String? value) {
    if (value == null) {
      throw FormatException('ContractStatus value is null');
    }
    for (final status in ContractStatus.values) {
      if (status.dbValue == value) return status;
    }
    throw FormatException('Unknown ContractStatus: $value');
  }

  String toDb() => dbValue;

  bool get isDraft => this == draft;
  bool get isActive => this == active;
  bool get isClosed =>
      this == completed || this == terminatedEarly || this == expired;
}
