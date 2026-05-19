enum UnitStatus {
  availableNew('available_new'),
  availableUsed('available_used'),
  rented('rented'),
  trial('trial'),
  maintenance('maintenance'),
  sold('sold'),
  damaged('damaged'),
  lost('lost'),
  retired('retired');

  const UnitStatus(this.dbValue);

  final String dbValue;

  static UnitStatus fromDb(String? value) {
    if (value == null) {
      throw FormatException('UnitStatus value is null');
    }
    for (final status in UnitStatus.values) {
      if (status.dbValue == value) return status;
    }
    throw FormatException('Unknown UnitStatus: $value');
  }

  String toDb() => dbValue;
}
