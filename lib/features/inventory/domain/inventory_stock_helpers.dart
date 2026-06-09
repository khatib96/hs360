import 'package:decimal/decimal.dart';

/// True when total available is at or below [reorderPoint] (null reorder = no warning).
bool isLowStock({required Decimal totalAvailable, Decimal? reorderPoint}) {
  return reorderPoint != null && totalAvailable <= reorderPoint;
}
