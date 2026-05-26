import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/inventory_movement_row.dart';
import '../inventory_movement_display_helpers.dart';
import '../inventory_movement_format_helpers.dart';

class InventoryMovementCard extends StatelessWidget {
  const InventoryMovementCard({
    required this.row,
    required this.languageCode,
    required this.inactiveWarehouseSuffix,
    required this.showUnitCost,
    super.key,
  });

  final InventoryMovementRow row;
  final String languageCode;
  final String inactiveWarehouseSuffix;
  final bool showUnitCost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        '${movementTypeLabel(row.movementType, l10n)} - '
        '${inventoryMovementProductLabel(row, languageCode, l10n)}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inventoryMovementWarehouseLabel(
              row,
              languageCode,
              l10n,
              inactiveSuffix: inactiveWarehouseSuffix,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.inventoryMovementQuantity}: '
            '${formatMovementQuantity(row.qty)} - '
            '${formatMovementDateTime(row.occurredAt)}',
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.inventoryMovementReference}: ${referenceLabel(row, l10n)}',
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.inventoryMovementCreatedBy}: '
            '${createdByLabel(row.createdBy, l10n)}',
          ),
          if (row.notes != null && row.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${l10n.inventoryMovementNotes}: ${row.notes!.trim()}'),
          ],
          if (showUnitCost && row.unitCost != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.inventoryMovementUnitCost}: '
              '${formatMovementUnitCost(row.unitCost!, languageCode)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      isThreeLine: true,
    );
  }
}
