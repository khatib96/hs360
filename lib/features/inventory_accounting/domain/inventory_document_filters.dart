import '../../finance_shared/domain/date_range.dart';
import 'inventory_document_summary.dart';

class InventoryDocumentFilters {
  const InventoryDocumentFilters({
    this.kind,
    this.warehouseId,
    this.dateRange = const DateRange(),
  });

  final InventoryDocumentKind? kind;
  final String? warehouseId;
  final DateRange dateRange;

  InventoryDocumentFilters copyWith({
    InventoryDocumentKind? kind,
    String? warehouseId,
    DateRange? dateRange,
    bool clearKind = false,
    bool clearWarehouse = false,
  }) {
    return InventoryDocumentFilters(
      kind: clearKind ? null : (kind ?? this.kind),
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      dateRange: dateRange ?? this.dateRange,
    );
  }

  bool get hasActiveFilters =>
      kind != null || warehouseId != null || !dateRange.isEmpty;
}
