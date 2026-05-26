import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/inventory/domain/inventory_movement.dart';
import 'package:hs360/features/inventory/domain/inventory_movement_row.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';
import 'package:hs360/features/inventory/presentation/widgets/inventory_movements_table.dart';
import 'package:hs360/l10n/app_localizations.dart';

InventoryMovementRow _rowWithCost() {
  return InventoryMovementRow(
    movement: InventoryMovement(
      id: 'm-1',
      tenantId: 't',
      movementType: MovementType.adjustmentIn,
      warehouseId: 'wh-1',
      productId: 'p-1',
      qty: Decimal.fromInt(10),
      unitCost: Decimal.parse('99.500'),
      notes: 'Long note that should not appear when cost is hidden',
      occurredAt: DateTime.utc(2026, 5, 1),
    ),
    productId: 'p-1',
    warehouseId: 'wh-1',
    productSku: 'SKU',
  );
}

Widget _wrap(Widget child, {required double width}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('wide table hides unit cost when showUnitCost is false', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InventoryMovementsTable(
          rows: [_rowWithCost()],
          languageCode: 'en',
          inactiveWarehouseSuffix: 'Inactive',
          showUnitCost: false,
        ),
        width: 1200,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unit cost'), findsNothing);
    expect(find.textContaining('99.5'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });

  testWidgets('wide table shows unit cost when showUnitCost is true', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InventoryMovementsTable(
          rows: [_rowWithCost()],
          languageCode: 'en',
          inactiveWarehouseSuffix: 'Inactive',
          showUnitCost: true,
        ),
        width: 1200,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unit cost'), findsOneWidget);
    expect(find.textContaining('99.5'), findsOneWidget);
  });

  testWidgets('narrow card hides unit cost when showUnitCost is false', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InventoryMovementsTable(
          rows: [_rowWithCost()],
          languageCode: 'en',
          inactiveWarehouseSuffix: 'Inactive',
          showUnitCost: false,
        ),
        width: 600,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('99.5'), findsNothing);
    expect(find.textContaining('Unit cost'), findsNothing);
  });
}
