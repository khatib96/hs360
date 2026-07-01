/// Server-controlled reason for inventory financial documents.
class InventoryAdjustmentReason {
  const InventoryAdjustmentReason({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.direction,
    required this.requiresCost,
    required this.allowsWacFallback,
    required this.allowedDocumentTypes,
  });

  final String code;
  final String nameAr;
  final String nameEn;
  final String direction;
  final bool requiresCost;
  final bool allowsWacFallback;
  final List<String> allowedDocumentTypes;
}
