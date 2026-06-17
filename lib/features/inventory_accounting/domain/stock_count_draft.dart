import 'package:decimal/decimal.dart';

/// Stock count draft input (stub domain).
class StockCountDraft {
  const StockCountDraft({
    required this.warehouseId,
    required this.date,
    required this.lines,
    this.notes,
  });

  final String warehouseId;
  final DateTime date;
  final String? notes;
  final List<StockCountDraftLine> lines;
}

class StockCountDraftLine {
  const StockCountDraftLine({
    required this.productId,
    required this.countedQty,
    this.systemQty,
  });

  final String productId;
  final Decimal countedQty;
  final Decimal? systemQty;

  Decimal get deltaQty {
    final system = systemQty ?? Decimal.zero;
    return countedQty - system;
  }
}
