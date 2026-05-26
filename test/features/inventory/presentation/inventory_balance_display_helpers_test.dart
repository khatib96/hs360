import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/domain/inventory_balance_row.dart';
import 'package:hs360/features/inventory/presentation/inventory_balance_display_helpers.dart';
import 'package:hs360/l10n/app_localizations.dart';

InventoryBalanceRow _row({
  String? sku,
  String? nameAr,
  String? nameEn,
}) {
  return InventoryBalanceRow(
    balance: InventoryBalance(
      id: 'b-1',
      tenantId: 't',
      warehouseId: 'wh-1',
      productId: 'p-1',
      qtyAvailable: Decimal.one,
      qtyRented: Decimal.zero,
      qtyTrial: Decimal.zero,
      qtyMaintenance: Decimal.zero,
      qtyDamaged: Decimal.zero,
    ),
    productId: 'p-1',
    warehouseId: 'wh-1',
    productSku: sku,
    productNameAr: nameAr,
    productNameEn: nameEn,
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  test('product label uses localized name when present', () {
    final label = inventoryBalanceProductLabel(
      _row(sku: 'SKU', nameAr: 'عربي', nameEn: 'English'),
      'en',
      l10n,
    );
    expect(label, 'English');
  });

  test('product label falls back to sku', () {
    final label = inventoryBalanceProductLabel(
      _row(sku: 'SKU-99'),
      'en',
      l10n,
    );
    expect(label, 'SKU-99');
  });

  test('product label falls back to unavailable with short id', () {
    final label = inventoryBalanceProductLabel(_row(), 'en', l10n);
    expect(label, contains(l10n.inventoryBalanceNameUnavailable));
    expect(label, contains('p-1'));
  });
}
