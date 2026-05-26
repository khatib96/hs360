import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/inventory_movement_row.dart';
import '../inventory_movement_display_helpers.dart';
import '../inventory_movement_format_helpers.dart';

class InventoryMovementsWideTable extends StatelessWidget {
  const InventoryMovementsWideTable({
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
    final l10n = AppLocalizations.of(context)!;

    final columns = <DataColumn>[
      DataColumn(label: Text(l10n.inventoryMovementOccurredAt)),
      DataColumn(label: Text(l10n.inventoryMovementType)),
      DataColumn(label: Text(l10n.inventoryMovementProduct)),
      DataColumn(label: Text(l10n.inventoryMovementWarehouse)),
      DataColumn(
        label: Text(l10n.inventoryMovementQuantity),
        numeric: true,
      ),
      DataColumn(label: Text(l10n.inventoryMovementReference)),
      DataColumn(label: Text(l10n.inventoryMovementCreatedBy)),
      DataColumn(label: Text(l10n.inventoryMovementNotes)),
      if (showUnitCost)
        DataColumn(
          label: Text(l10n.inventoryMovementUnitCost),
          numeric: true,
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.neutral50),
          columns: columns,
          rows: [
            for (final row in rows) _dataRow(context, l10n, row),
          ],
        ),
      ),
    );
  }

  DataRow _dataRow(
    BuildContext context,
    AppLocalizations l10n,
    InventoryMovementRow row,
  ) {
    final notesFull = row.notes?.trim() ?? '';
    final notesDisplay = movementNotesForTable(row.notes, l10n);
    final notesTruncated = truncateMovementNotes(row.notes) != notesFull &&
        notesFull.isNotEmpty;

    Widget notesCell = Text(notesDisplay);
    if (notesTruncated) {
      notesCell = Tooltip(
        message: notesFull,
        child: notesCell,
      );
    }

    return DataRow(
      cells: [
        DataCell(Text(formatMovementDateTime(row.occurredAt))),
        DataCell(Text(movementTypeLabel(row.movementType, l10n))),
        DataCell(Text(inventoryMovementProductLabel(row, languageCode, l10n))),
        DataCell(
          Text(
            inventoryMovementWarehouseLabel(
              row,
              languageCode,
              l10n,
              inactiveSuffix: inactiveWarehouseSuffix,
            ),
          ),
        ),
        DataCell(Text(formatMovementQuantity(row.qty))),
        DataCell(Text(referenceLabel(row, l10n))),
        DataCell(Text(createdByLabel(row.createdBy, l10n))),
        DataCell(notesCell),
        if (showUnitCost)
          DataCell(
            Text(
              row.unitCost != null
                  ? formatMovementUnitCost(row.unitCost!, languageCode)
                  : l10n.inventoryMovementNotesNone,
            ),
          ),
      ],
    );
  }
}
