import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Minimal product fields for inventory balance label hydration.
class ProductStockLabel {
  const ProductStockLabel({
    required this.id,
    required this.sku,
    required this.nameAr,
    required this.nameEn,
    this.reorderPoint,
  });

  final String id;
  final String sku;
  final String nameAr;
  final String nameEn;
  final Decimal? reorderPoint;

  factory ProductStockLabel.fromRow(Map<String, dynamic> row) {
    return ProductStockLabel(
      id: row['id'] as String,
      sku: row['sku'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String,
      reorderPoint: tryParseDecimal(row['reorder_point']),
    );
  }
}
