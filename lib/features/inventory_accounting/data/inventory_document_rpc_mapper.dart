import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../finance_shared/domain/date_range.dart';
import '../domain/inventory_adjustment_reason.dart';
import '../domain/inventory_document_detail.dart';
import '../domain/inventory_document_line.dart';
import '../domain/inventory_document_movement.dart';
import '../domain/inventory_document_summary.dart';
import '../domain/stock_count_draft.dart';
import '../../../domain/validators/inventory_adjustment_document_validator.dart';
import '../../../domain/validators/opening_stock_validator.dart';

InventoryDocumentSummary mapInventoryDocumentSummary(Map<String, dynamic> json) {
  return InventoryDocumentSummary(
    id: json['id'] as String,
    documentNumber: json['document_number'] as String?,
    kind: InventoryDocumentKind.fromDb(json['document_type'] as String?),
    status: InventoryDocumentStatus.fromDb(json['status'] as String?),
    date: DateTime.parse(json['date'] as String),
    warehouseId: json['warehouse_id'] as String,
    warehouseNameAr: json['warehouse_name_ar'] as String?,
    warehouseNameEn: json['warehouse_name_en'] as String?,
    journalEntryId: json['journal_entry_id'] as String?,
  );
}

InventoryDocumentDetail mapInventoryDocumentDetail(Map<String, dynamic> json) {
  final summary = InventoryDocumentSummary(
    id: json['id'] as String,
    documentNumber: json['document_number'] as String?,
    kind: InventoryDocumentKind.fromDb(json['document_type'] as String?),
    status: InventoryDocumentStatus.fromDb(json['status'] as String?),
    date: DateTime.parse(json['date'] as String),
    warehouseId: json['warehouse_id'] as String,
    journalEntryId: json['journal_entry_id'] as String?,
  );

  final linesRaw = json['lines'];
  final movementsRaw = json['movements'];

  return InventoryDocumentDetail(
    summary: summary,
    reasonCode: json['reason_code'] as String?,
    gainReasonCode: json['gain_reason_code'] as String?,
    lossReasonCode: json['loss_reason_code'] as String?,
    notes: json['notes'] as String?,
    importKey: json['import_key'] as String?,
    journalEntryId: json['journal_entry_id'] as String?,
    reversalJournalEntryId: json['reversal_journal_entry_id'] as String?,
    lines: linesRaw is List
        ? linesRaw
              .map(
                (line) => _mapLine(Map<String, dynamic>.from(line as Map)),
              )
              .toList()
        : const [],
    movements: movementsRaw is List
        ? movementsRaw
              .map(
                (m) => _mapMovement(Map<String, dynamic>.from(m as Map)),
              )
              .toList()
        : const [],
  );
}

InventoryDocumentLine _mapLine(Map<String, dynamic> json) {
  final unitIdsRaw = json['product_unit_ids'];
  List<String> unitIds = const [];
  if (unitIdsRaw is List) {
    unitIds = unitIdsRaw.map((id) => id.toString()).toList();
  }

  final inputQty = json['input_qty'];
  final deltaQty = json['delta_qty'];
  final systemQty = json['system_qty'];

  return InventoryDocumentLine(
    id: json['id'] as String,
    lineOrder: json['line_order'] as int? ?? 0,
    productId: json['product_id'] as String,
    qty: parseDecimal(inputQty ?? deltaQty ?? 0),
    unitCost: json['unit_cost_snapshot'] != null
        ? parseDecimal(json['unit_cost_snapshot'])
        : null,
    totalValue: json['total_value'] != null
        ? parseDecimal(json['total_value'])
        : null,
    systemQty: systemQty != null ? parseDecimal(systemQty) : null,
    countedQty: inputQty != null ? parseDecimal(inputQty) : null,
    deltaQty: deltaQty != null ? parseDecimal(deltaQty) : null,
    reasonCode: json['reason_code'] as String?,
    productUnitIds: unitIds,
  );
}

InventoryDocumentMovement _mapMovement(Map<String, dynamic> json) {
  return InventoryDocumentMovement(
    id: json['id'] as String,
    movementType: json['movement_type'] as String? ?? '',
    productId: json['product_id'] as String,
    qty: parseDecimal(json['qty']),
    unitCost: json['unit_cost'] != null
        ? parseDecimal(json['unit_cost'])
        : null,
  );
}

InventoryAdjustmentReason mapInventoryAdjustmentReason(
  Map<String, dynamic> json,
) {
  final typesRaw = json['allowed_document_types'];
  return InventoryAdjustmentReason(
    code: json['code'] as String,
    nameAr: json['name_ar'] as String? ?? '',
    nameEn: json['name_en'] as String? ?? '',
    direction: json['direction'] as String? ?? '',
    requiresCost: json['requires_cost'] as bool? ?? false,
    allowsWacFallback: json['allows_wac_fallback'] as bool? ?? false,
    allowedDocumentTypes: typesRaw is List
        ? typesRaw.map((t) => t.toString()).toList()
        : const [],
  );
}

Map<String, dynamic> openingStockPayload(OpeningStockInput input) {
  return {
    'warehouse_id': input.warehouseId,
    'date': dateRangeToIsoDate(input.date),
    'notes': input.notes.trim(),
    'lines': [
      for (var i = 0; i < input.lines.length; i++)
        {
          'product_id': input.lines[i].productId,
          'qty': input.lines[i].qty.toString(),
          'unit_cost': input.lines[i].unitCost?.toString(),
          'line_order': i + 1,
        },
    ],
  };
}

Map<String, dynamic> inventoryDocumentPayload(
  InventoryAdjustmentDocumentInput input,
) {
  final documentType = input.direction == InventoryAdjustmentDirection.stockIn
      ? 'stock_in'
      : 'stock_out';

  return {
    'document_type': documentType,
    'warehouse_id': input.warehouseId,
    'date': dateRangeToIsoDate(input.date),
    'notes': input.notes.trim(),
    'reason_code': input.reason?.code,
    'lines': [
      for (var i = 0; i < input.lines.length; i++) _adjustmentLineJson(
        input.lines[i],
        input.direction,
        input.reason,
        i + 1,
      ),
    ],
  };
}

Map<String, dynamic> _adjustmentLineJson(
  InventoryAdjustmentDocumentLineInput line,
  InventoryAdjustmentDirection direction,
  InventoryAdjustmentReason? reason,
  int lineOrder,
) {
  final map = <String, dynamic>{
    'product_id': line.productId,
    'qty': line.qty.toString(),
    'line_order': lineOrder,
  };

  if (direction == InventoryAdjustmentDirection.stockIn) {
    final omitCost =
        reason != null &&
        reason.allowsWacFallback &&
        (line.avgCost ?? Decimal.zero) > Decimal.zero &&
        line.unitCost == null;
    if (!omitCost && line.unitCost != null) {
      map['unit_cost'] = line.unitCost.toString();
    }
    if (line.isSerialized) {
      map['units'] = [
        for (final unit in line.serialUnits)
          {
            'serial_number': unit.serialNumber.trim(),
            if (unit.barcode != null && unit.barcode!.trim().isNotEmpty)
              'barcode': unit.barcode!.trim(),
          },
      ];
    }
  } else if (line.isSerialized) {
    map['unit_ids'] = line.unitIds;
  }

  return map;
}

Map<String, dynamic> stockCountPayload(StockCountDraft draft) {
  return {
    'warehouse_id': draft.warehouseId,
    'date': dateRangeToIsoDate(draft.date),
    'notes': draft.notes.trim(),
    'gain_reason_code': draft.gainReasonCode,
    'loss_reason_code': draft.lossReasonCode,
    'lines': [
      for (var i = 0; i < draft.lines.length; i++)
        {
          'product_id': draft.lines[i].productId,
          'counted_qty': draft.lines[i].countedQty.toString(),
          'line_order': i + 1,
        },
    ],
  };
}

Map<String, dynamic> cancelInventoryDocumentParams({
  required String documentId,
  required String reason,
  required String idempotencyKey,
}) {
  return {
    'p_document_id': documentId,
    'p_reason': reason.trim(),
    'p_idempotency_key': idempotencyKey,
  };
}
