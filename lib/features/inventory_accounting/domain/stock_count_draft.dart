import 'package:decimal/decimal.dart';

class StockCountDraft {
  const StockCountDraft({
    required this.warehouseId,
    required this.date,
    required this.notes,
    required this.gainReasonCode,
    required this.lossReasonCode,
    required this.lines,
  });

  final String warehouseId;
  final DateTime date;
  final String notes;
  final String gainReasonCode;
  final String lossReasonCode;
  final List<StockCountDraftLine> lines;
}

class StockCountDraftLine {
  const StockCountDraftLine({
    required this.productId,
    required this.countedQty,
    this.systemQty,
    this.isSerialized = false,
  });

  final String productId;
  final Decimal countedQty;
  final Decimal? systemQty;
  final bool isSerialized;

  Decimal get deltaQty {
    final system = systemQty ?? Decimal.zero;
    return countedQty - system;
  }
}
