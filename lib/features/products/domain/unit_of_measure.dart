enum UnitOfMeasure {
  piece('piece'),
  liter('liter'),
  ml('ml'),
  gram('gram'),
  kg('kg'),
  box('box'),
  bottle('bottle'),
  carton('carton'),
  meter('meter'),
  pack('pack');

  const UnitOfMeasure(this.dbValue);

  final String dbValue;

  static UnitOfMeasure fromDb(String? value) {
    if (value == null) {
      throw FormatException('UnitOfMeasure value is null');
    }
    for (final unit in UnitOfMeasure.values) {
      if (unit.dbValue == value) return unit;
    }
    throw FormatException('Unknown UnitOfMeasure: $value');
  }

  String toDb() => dbValue;
}
