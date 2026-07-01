import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/inventory_accounting/domain/inventory_adjustment_reason.dart';
import 'validation_result.dart';

enum InventoryAdjustmentDirection { stockIn, stockOut }

class InventoryAdjustmentDocumentLineInput {
  const InventoryAdjustmentDocumentLineInput({
    required this.productId,
    required this.qty,
    this.unitCost,
    this.avgCost,
    this.isSerialized = false,
    this.unitIds = const [],
    this.serialUnits = const [],
  });

  final String productId;
  final Decimal qty;
  final Decimal? unitCost;
  final Decimal? avgCost;
  final bool isSerialized;
  final List<String> unitIds;
  final List<SerializedUnitInput> serialUnits;
}

class SerializedUnitInput {
  const SerializedUnitInput({required this.serialNumber, this.barcode});

  final String serialNumber;
  final String? barcode;
}

class InventoryAdjustmentDocumentInput {
  const InventoryAdjustmentDocumentInput({
    required this.warehouseId,
    required this.date,
    required this.notes,
    required this.direction,
    required this.lines,
    this.reason,
  });

  final String warehouseId;
  final DateTime date;
  final String notes;
  final InventoryAdjustmentDirection direction;
  final InventoryAdjustmentReason? reason;
  final List<InventoryAdjustmentDocumentLineInput> lines;
}

class InventoryAdjustmentDocumentValidator {
  const InventoryAdjustmentDocumentValidator();

  static bool _isPositiveWholeNumber(Decimal qty) {
    if (qty <= Decimal.zero) return false;
    return qty == Decimal.parse(qty.toBigInt().toString());
  }

  ValidationResult validate(InventoryAdjustmentDocumentInput input) {
    final codes = <String>[];

    if (input.warehouseId.trim().isEmpty) {
      codes.add(FinanceException.validationWarehouseRequired);
    }
    if (input.notes.trim().isEmpty) {
      codes.add(FinanceException.validationNotesRequired);
    }
    if (input.reason == null || input.reason!.code.trim().isEmpty) {
      codes.add(FinanceException.validationReasonRequired);
    }
    if (input.lines.isEmpty) {
      codes.add(FinanceException.validationLinesRequired);
    }

    final reason = input.reason;
    for (final line in input.lines) {
      if (line.productId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
      }
      if (line.qty <= Decimal.zero) {
        codes.add(FinanceException.validationLineQtyInvalid);
      }

      if (input.direction == InventoryAdjustmentDirection.stockIn &&
          reason != null) {
        if (reason.requiresCost &&
            (line.unitCost == null || line.unitCost! < Decimal.zero)) {
          codes.add(FinanceException.validationCostRequired);
        } else if (reason.allowsWacFallback) {
          final avg = line.avgCost ?? Decimal.zero;
          final hasWac = avg > Decimal.zero;
          final hasCost = line.unitCost != null && line.unitCost! >= Decimal.zero;
          if (!hasWac && !hasCost) {
            codes.add(FinanceException.validationCostRequired);
          }
        }
        if (line.isSerialized) {
          if (!_isPositiveWholeNumber(line.qty)) {
            codes.add(FinanceException.validationSerializedQtyIntegerRequired);
          } else if (line.serialUnits.length != line.qty.toBigInt().toInt()) {
            codes.add(FinanceException.validationSerialCountMismatch);
          }
          for (final unit in line.serialUnits) {
            if (unit.serialNumber.trim().isEmpty) {
              codes.add(FinanceException.validationSerializedUnitRequired);
            }
          }
        }
      }

      if (input.direction == InventoryAdjustmentDirection.stockOut &&
          line.isSerialized) {
        if (!_isPositiveWholeNumber(line.qty)) {
          codes.add(FinanceException.validationSerializedQtyIntegerRequired);
        } else {
          final qtyInt = line.qty.toBigInt().toInt();
          if (line.unitIds.length != qtyInt) {
            codes.add(FinanceException.validationSerializedUnitRequired);
          }
        }
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
