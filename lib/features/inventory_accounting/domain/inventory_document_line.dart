import 'package:decimal/decimal.dart';

class InventoryDocumentLine {
  const InventoryDocumentLine({
    required this.id,
    required this.lineOrder,
    required this.productId,
    required this.qty,
    this.unitCost,
    this.systemQty,
    this.countedQty,
    this.deltaQty,
  });

  final String id;
  final int lineOrder;
  final String productId;
  final Decimal qty;
  final Decimal? unitCost;
  final Decimal? systemQty;
  final Decimal? countedQty;
  final Decimal? deltaQty;
}
