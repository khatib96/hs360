import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/domain/validators/inventory_adjustment_document_validator.dart';
import 'package:hs360/domain/validators/opening_stock_validator.dart';
import 'package:hs360/features/inventory_accounting/data/inventory_document_rpc_mapper.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_adjustment_reason.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_document_summary.dart';
import 'package:hs360/features/inventory_accounting/domain/stock_count_draft.dart';

void main() {
  group('inventory_document_rpc_mapper', () {
    test('openingStockPayload excludes reason_code', () {
      final payload = openingStockPayload(
        OpeningStockInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Opening notes',
          lines: [
            OpeningStockLineInput(
              productId: 'prod-1',
              qty: Decimal.parse('10'),
              unitCost: Decimal.parse('5'),
            ),
          ],
        ),
      );

      expect(payload.containsKey('reason_code'), isFalse);
      expect(payload['notes'], 'Opening notes');
      expect(payload['lines'], hasLength(1));
    });

    test('stockCountPayload always includes gain and loss reasons', () {
      final payload = stockCountPayload(
        StockCountDraft(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Count notes',
          gainReasonCode: 'found_surplus',
          lossReasonCode: 'damage',
          lines: [
            StockCountDraftLine(
              productId: 'prod-1',
              countedQty: Decimal.parse('5'),
            ),
          ],
        ),
      );

      expect(payload['gain_reason_code'], 'found_surplus');
      expect(payload['loss_reason_code'], 'damage');
    });

    test('inventoryDocumentPayload omits unit_cost for WAC fallback', () {
      final payload = inventoryDocumentPayload(
        InventoryAdjustmentDocumentInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Stock in',
          direction: InventoryAdjustmentDirection.stockIn,
          reason: const InventoryAdjustmentReason(
            code: 'found_surplus',
            nameAr: 'فائض',
            nameEn: 'Surplus',
            direction: 'stock_in',
            requiresCost: false,
            allowsWacFallback: true,
            allowedDocumentTypes: ['stock_in'],
          ),
          lines: [
            InventoryAdjustmentDocumentLineInput(
              productId: 'prod-1',
              qty: Decimal.one,
              avgCost: Decimal.parse('3'),
            ),
          ],
        ),
      );

      final line = (payload['lines'] as List).first as Map<String, dynamic>;
      expect(line.containsKey('unit_cost'), isFalse);
    });

    test('mapInventoryDocumentDetail parses lines and movements', () {
      final detail = mapInventoryDocumentDetail({
        'id': 'doc-1',
        'document_number': 'OS-001',
        'document_type': 'opening_stock',
        'status': 'confirmed',
        'date': '2026-06-01',
        'warehouse_id': 'wh-1',
        'notes': 'Notes',
        'journal_entry_id': 'je-1',
        'lines': [
          {
            'id': 'line-1',
            'product_id': 'prod-1',
            'input_qty': '2.000',
            'unit_cost_snapshot': '5.000',
            'total_value': '10.000',
            'product_unit_ids': [],
            'line_order': 1,
          },
        ],
        'movements': [
          {
            'id': 'mov-1',
            'movement_type': 'adjustment_in',
            'product_id': 'prod-1',
            'qty': '2.000',
            'unit_cost': '5.000',
          },
        ],
      });

      expect(detail.summary.kind, InventoryDocumentKind.openingStock);
      expect(detail.lines, hasLength(1));
      expect(detail.movements, hasLength(1));
      expect(detail.isSerialized, isFalse);
    });
  });
}
