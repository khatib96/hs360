enum MovementType {
  purchase('purchase'),
  sale('sale'),
  rentalOut('rental_out'),
  rentalReturn('rental_return'),
  refill('refill'),
  transferOut('transfer_out'),
  transferIn('transfer_in'),
  adjustmentIn('adjustment_in'),
  adjustmentOut('adjustment_out'),
  saleReturn('sale_return'),
  purchaseReturn('purchase_return'),
  maintenanceIn('maintenance_in'),
  maintenanceOut('maintenance_out');

  const MovementType(this.dbValue);

  final String dbValue;

  static MovementType fromDb(String? value) {
    if (value == null) {
      throw FormatException('MovementType value is null');
    }
    for (final type in MovementType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown MovementType: $value');
  }

  String toDb() => dbValue;

  bool get isManualAdjustment =>
      this == MovementType.adjustmentIn || this == MovementType.adjustmentOut;
}
