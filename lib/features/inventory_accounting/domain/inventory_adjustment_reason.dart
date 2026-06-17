/// Server-controlled reason for stock-in/out documents (stub until M4.5 SQL).
class InventoryAdjustmentReason {
  const InventoryAdjustmentReason({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.requiresCost,
  });

  final String code;
  final String nameAr;
  final String nameEn;
  final bool requiresCost;
}
