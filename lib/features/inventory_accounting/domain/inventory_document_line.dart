import 'package:decimal/decimal.dart';

class InventoryDocumentLine {
  const InventoryDocumentLine({
    required this.id,
    required this.lineOrder,
    required this.productId,
    required this.qty,
    this.unitCost,
    this.totalValue,
    this.systemQty,
    this.countedQty,
    this.deltaQty,
    this.reasonCode,
    this.productUnitIds = const [],
  });

  final String id;
  final int lineOrder;
  final String productId;
  final Decimal qty;
  final Decimal? unitCost;
  final Decimal? totalValue;
  final Decimal? systemQty;
  final Decimal? countedQty;
  final Decimal? deltaQty;
  final String? reasonCode;
  final List<String> productUnitIds;
}
