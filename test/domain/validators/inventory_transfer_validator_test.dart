import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/domain/validators/inventory_transfer_validator.dart';
import 'package:hs360/features/inventory/domain/inventory_transfer_form_state.dart';

void main() {
  const validator = InventoryTransferValidator();

  InventoryTransferFormState validForm({
    Decimal? sourceQty,
  }) {
    return InventoryTransferFormState(
      fromWarehouseId: 'wh-from',
      toWarehouseId: 'wh-to',
      productId: 'p',
      qty: Decimal.fromInt(2),
      notes: 'transfer notes',
      sourceQtyAvailable: sourceQty ?? Decimal.fromInt(10),
    );
  }

  test('valid transfer passes', () {
    expect(validator.validate(validForm()).isValid, isTrue);
  });

  test('rejects empty source warehouse', () {
    final result = validator.validate(
      InventoryTransferFormState(
        fromWarehouseId: '   ',
        toWarehouseId: 'wh-to',
        productId: 'p',
        qty: Decimal.one,
        notes: 'notes',
        sourceQtyAvailable: Decimal.fromInt(5),
      ),
    );
    expect(result.codes, contains(InventoryException.sourceWarehouseRequired));
  });

  test('rejects empty destination warehouse', () {
    final result = validator.validate(
      InventoryTransferFormState(
        fromWarehouseId: 'wh-from',
        toWarehouseId: '',
        productId: 'p',
        qty: Decimal.one,
        notes: 'notes',
        sourceQtyAvailable: Decimal.fromInt(5),
      ),
    );
    expect(
      result.codes,
      contains(InventoryException.destinationWarehouseRequired),
    );
  });

  test('rejects empty product', () {
    final result = validator.validate(
      InventoryTransferFormState(
        fromWarehouseId: 'wh-from',
        toWarehouseId: 'wh-to',
        productId: '',
        qty: Decimal.one,
        notes: 'notes',
        sourceQtyAvailable: Decimal.fromInt(5),
      ),
    );
    expect(result.codes, contains(InventoryException.productRequired));
  });

  test('rejects same warehouse', () {
    final result = validator.validate(
      InventoryTransferFormState(
        fromWarehouseId: 'wh-1',
        toWarehouseId: 'wh-1',
        productId: 'p',
        qty: Decimal.one,
        notes: 'notes',
        sourceQtyAvailable: Decimal.fromInt(5),
      ),
    );
    expect(result.codes, contains(InventoryException.transferSameWarehouse));
  });

  test('rejects empty notes', () {
    final result = validator.validate(
      validForm().copyWithNotes('   '),
    );
    expect(result.isValid, isFalse);
  });

  test('rejects serialized product', () {
    final result = validator.validate(
      InventoryTransferFormState(
        fromWarehouseId: 'wh-from',
        toWarehouseId: 'wh-to',
        productId: 'p',
        qty: Decimal.one,
        notes: 'notes',
        isSerialized: true,
        sourceQtyAvailable: Decimal.fromInt(5),
      ),
    );
    expect(
      result.codes,
      contains(InventoryException.serializedTransferNotSupported),
    );
  });

  test('rejects insufficient stock', () {
    final result = validator.validate(
      validForm(sourceQty: Decimal.one),
    );
    expect(result.codes, contains(InventoryException.insufficientStock));
  });
}

extension on InventoryTransferFormState {
  InventoryTransferFormState copyWithNotes(String notes) {
    return InventoryTransferFormState(
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      productId: productId,
      qty: qty,
      notes: notes,
      isSerialized: isSerialized,
      sourceQtyAvailable: sourceQtyAvailable,
    );
  }
}
