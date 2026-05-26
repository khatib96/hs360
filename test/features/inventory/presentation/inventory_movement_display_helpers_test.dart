import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/inventory/domain/inventory_movement.dart';
import 'package:hs360/features/inventory/domain/inventory_movement_row.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';
import 'package:hs360/features/inventory/presentation/inventory_movement_display_helpers.dart';
import 'package:hs360/l10n/app_localizations.dart';

InventoryMovementRow _row({
  String? createdBy,
  String? referenceTable,
  String? referenceId,
}) {
  return InventoryMovementRow(
    movement: InventoryMovement(
      id: 'm-1',
      tenantId: 't',
      movementType: MovementType.purchase,
      warehouseId: 'wh-1',
      productId: 'p-1',
      qty: Decimal.one,
      referenceTable: referenceTable,
      referenceId: referenceId,
      createdBy: createdBy,
      occurredAt: DateTime.utc(2026, 1, 1),
    ),
    productId: 'p-1',
    warehouseId: 'wh-1',
    productSku: 'SKU-1',
    productNameAr: 'عربي',
    productNameEn: 'English',
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  test('product label uses localized name', () {
    final label = inventoryMovementProductLabel(_row(), 'en', l10n);
    expect(label, 'English');
  });

  test('created_by null shows not recorded', () {
    expect(createdByLabel(null, l10n), l10n.inventoryMovementCreatedByNotRecorded);
  });

  test('created_by shows short id', () {
    expect(
      createdByLabel('abcdef12-3456-7890-abcd-ef1234567890', l10n),
      'abcdef12',
    );
  });

  test('reference uses raw table fallback', () {
    final label = referenceLabel(
      _row(referenceTable: 'future_invoice', referenceId: 'inv-uuid-long'),
      l10n,
    );
    expect(label, contains('future_invoice'));
    expect(label, contains('inv-uuid'));
  });

  test('every movement type has a label', () {
    for (final type in MovementType.values) {
      expect(movementTypeLabel(type, l10n), isNotEmpty);
    }
  });
}
