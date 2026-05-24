/// Allowed [product_units.health_status] values (M6 RPC allowlist).
enum ProductUnitHealthStatus {
  good('good'),
  needsService('needs_service'),
  damaged('damaged'),
  lost('lost');

  const ProductUnitHealthStatus(this.dbValue);

  final String dbValue;

  static ProductUnitHealthStatus fromDb(String? value) {
    if (value == null || value.isEmpty) {
      return ProductUnitHealthStatus.good;
    }
    for (final status in ProductUnitHealthStatus.values) {
      if (status.dbValue == value) return status;
    }
    throw FormatException('Unknown ProductUnitHealthStatus: $value');
  }

  String toDb() => dbValue;
}
