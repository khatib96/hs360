import 'package:flutter/material.dart';

import '../../domain/inventory_movement_row.dart';
import 'inventory_movement_card.dart';
import 'inventory_movements_wide_table.dart';

class InventoryMovementsTable extends StatelessWidget {
  const InventoryMovementsTable({
    required this.rows,
    required this.languageCode,
    required this.inactiveWarehouseSuffix,
    required this.showUnitCost,
    super.key,
  });

  final List<InventoryMovementRow> rows;
  final String languageCode;
  final String inactiveWarehouseSuffix;
  final bool showUnitCost;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 900;

    if (isWide) {
      return InventoryMovementsWideTable(
        rows: rows,
        languageCode: languageCode,
        inactiveWarehouseSuffix: inactiveWarehouseSuffix,
        showUnitCost: showUnitCost,
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => InventoryMovementCard(
        row: rows[index],
        languageCode: languageCode,
        inactiveWarehouseSuffix: inactiveWarehouseSuffix,
        showUnitCost: showUnitCost,
      ),
    );
  }
}
