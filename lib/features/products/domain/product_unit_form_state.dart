import 'package:decimal/decimal.dart';

import 'product_unit_health_status.dart';

class ProductUnitCreateInput {
  const ProductUnitCreateInput({
    required this.serialNumber,
    this.barcode,
    this.purchaseCost,
    this.acquiredAt,
    this.notes,
    this.healthStatus = ProductUnitHealthStatus.good,
  });

  final String serialNumber;
  final String? barcode;
  final Decimal? purchaseCost;
  final DateTime? acquiredAt;
  final String? notes;
  final ProductUnitHealthStatus healthStatus;
}

class ProductUnitSafeEditInput {
  const ProductUnitSafeEditInput({
    required this.barcode,
    required this.notes,
    this.healthStatus,
  });

  /// Always sent to RPC (empty string clears after trim).
  final String? barcode;
  final String? notes;

  /// Null means do not change health_status in RPC.
  final ProductUnitHealthStatus? healthStatus;
}
