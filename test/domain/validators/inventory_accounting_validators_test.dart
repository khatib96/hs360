import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/domain/validators/inventory_adjustment_document_validator.dart';
import 'package:hs360/domain/validators/opening_stock_validator.dart';
import 'package:hs360/domain/validators/stock_count_validator.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_adjustment_reason.dart';
import 'package:hs360/features/inventory_accounting/domain/stock_count_draft.dart';

void main() {
  group('StockCountValidator', () {
    test('requires gain and loss reasons even when deltas are zero', () {
      final result = const StockCountValidator().validate(
        StockCountDraft(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Count notes',
          gainReasonCode: '',
          lossReasonCode: '',
          lines: [
            StockCountDraftLine(
              productId: 'p1',
              countedQty: Decimal.fromInt(5),
              systemQty: Decimal.fromInt(5),
            ),
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.codes,
        contains(FinanceException.validationGainReasonRequired),
      );
      expect(
        result.codes,
        contains(FinanceException.validationLossReasonRequired),
      );
    });

    test('rejects serialized products', () {
      final result = const StockCountValidator().validate(
        StockCountDraft(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Count notes',
          gainReasonCode: 'gain',
          lossReasonCode: 'loss',
          lines: [
            StockCountDraftLine(
              productId: 'p1',
              countedQty: Decimal.one,
              isSerialized: true,
            ),
          ],
        ),
      );

      expect(
        result.codes,
        contains(FinanceException.validationSerializedNotSupported),
      );
    });
  });

  group('InventoryAdjustmentDocumentValidator', () {
    const wacReason = InventoryAdjustmentReason(
      code: 'wac',
      nameAr: 'WAC',
      nameEn: 'WAC',
      direction: 'stock_in',
      requiresCost: false,
      allowsWacFallback: true,
      allowedDocumentTypes: ['stock_in'],
    );

    test('stock-in WAC fallback requires unit_cost when avg_cost is zero', () {
      final result = const InventoryAdjustmentDocumentValidator().validate(
        InventoryAdjustmentDocumentInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Adjustment',
          direction: InventoryAdjustmentDirection.stockIn,
          reason: wacReason,
          lines: [
            InventoryAdjustmentDocumentLineInput(
              productId: 'p1',
              qty: Decimal.one,
              avgCost: Decimal.zero,
            ),
          ],
        ),
      );

      expect(result.codes, contains(FinanceException.validationCostRequired));
    });

    test('stock-in WAC fallback passes when avg_cost is positive', () {
      final result = const InventoryAdjustmentDocumentValidator().validate(
        InventoryAdjustmentDocumentInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Adjustment',
          direction: InventoryAdjustmentDirection.stockIn,
          reason: wacReason,
          lines: [
            InventoryAdjustmentDocumentLineInput(
              productId: 'p1',
              qty: Decimal.one,
              avgCost: Decimal.parse('12.50'),
            ),
          ],
        ),
      );

      expect(result.isValid, isTrue);
    });

    const costReason = InventoryAdjustmentReason(
      code: 'purchase',
      nameAr: 'شراء',
      nameEn: 'Purchase',
      direction: 'stock_in',
      requiresCost: true,
      allowsWacFallback: false,
      allowedDocumentTypes: ['stock_in'],
    );

    test('serialized stock-in rejects decimal qty', () {
      final result = const InventoryAdjustmentDocumentValidator().validate(
        InventoryAdjustmentDocumentInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Adjustment',
          direction: InventoryAdjustmentDirection.stockIn,
          reason: costReason,
          lines: [
            InventoryAdjustmentDocumentLineInput(
              productId: 'p1',
              qty: Decimal.parse('1.5'),
              unitCost: Decimal.one,
              isSerialized: true,
              serialUnits: [SerializedUnitInput(serialNumber: 'SN-1')],
            ),
          ],
        ),
      );

      expect(
        result.codes,
        contains(FinanceException.validationSerializedQtyIntegerRequired),
      );
    });

    test('serialized stock-out rejects decimal qty', () {
      final result = const InventoryAdjustmentDocumentValidator().validate(
        InventoryAdjustmentDocumentInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Adjustment',
          direction: InventoryAdjustmentDirection.stockOut,
          reason: costReason,
          lines: [
            InventoryAdjustmentDocumentLineInput(
              productId: 'p1',
              qty: Decimal.parse('1.5'),
              isSerialized: true,
              unitIds: const ['unit-1'],
            ),
          ],
        ),
      );

      expect(
        result.codes,
        contains(FinanceException.validationSerializedQtyIntegerRequired),
      );
    });

    test(
      'serialized stock-in passes with matching integer qty and serials',
      () {
        final result = const InventoryAdjustmentDocumentValidator().validate(
          InventoryAdjustmentDocumentInput(
            warehouseId: 'wh-1',
            date: DateTime(2026, 6, 1),
            notes: 'Adjustment',
            direction: InventoryAdjustmentDirection.stockIn,
            reason: costReason,
            lines: [
              InventoryAdjustmentDocumentLineInput(
                productId: 'p1',
                qty: Decimal.fromInt(2),
                unitCost: Decimal.one,
                isSerialized: true,
                serialUnits: const [
                  SerializedUnitInput(serialNumber: 'SN-1'),
                  SerializedUnitInput(serialNumber: 'SN-2'),
                ],
              ),
            ],
          ),
        );

        expect(result.isValid, isTrue);
      },
    );

    test(
      'serialized stock-out passes with matching integer qty and unit ids',
      () {
        final result = const InventoryAdjustmentDocumentValidator().validate(
          InventoryAdjustmentDocumentInput(
            warehouseId: 'wh-1',
            date: DateTime(2026, 6, 1),
            notes: 'Adjustment',
            direction: InventoryAdjustmentDirection.stockOut,
            reason: costReason,
            lines: [
              InventoryAdjustmentDocumentLineInput(
                productId: 'p1',
                qty: Decimal.fromInt(2),
                isSerialized: true,
                unitIds: const ['unit-1', 'unit-2'],
              ),
            ],
          ),
        );

        expect(result.isValid, isTrue);
      },
    );
  });

  group('OpeningStockValidator', () {
    test('rejects serialized products', () {
      final result = const OpeningStockValidator().validate(
        OpeningStockInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: 'Opening',
          lines: [
            OpeningStockLineInput(
              productId: 'p1',
              qty: Decimal.one,
              unitCost: Decimal.one,
              isSerialized: true,
            ),
          ],
        ),
      );

      expect(
        result.codes,
        contains(FinanceException.validationSerializedNotSupported),
      );
    });
  });
}
