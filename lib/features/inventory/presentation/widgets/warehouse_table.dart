import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/warehouse.dart';
import '../../domain/warehouse_assignable_employee.dart';
import '../../domain/warehouse_type.dart';
import '../warehouse_display_helpers.dart';

class WarehouseTable extends StatelessWidget {
  const WarehouseTable({
    required this.warehouses,
    required this.languageCode,
    required this.employeesById,
    required this.inactiveEmployeeHint,
    required this.canEdit,
    required this.canViewStock,
    required this.onViewStock,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final List<Warehouse> warehouses;
  final String languageCode;
  final Map<String, WarehouseAssignableEmployee> employeesById;
  final String inactiveEmployeeHint;
  final bool canEdit;
  final bool canViewStock;
  final ValueChanged<Warehouse> onViewStock;
  final ValueChanged<Warehouse> onEdit;
  final ValueChanged<Warehouse> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.neutral50),
        columns: [
          DataColumn(label: Text(l10n.warehouseColumnName)),
          DataColumn(label: Text(l10n.warehouseColumnType)),
          DataColumn(label: Text(l10n.warehouseColumnEmployee)),
          DataColumn(label: Text(l10n.warehouseColumnAddress)),
          DataColumn(label: Text(l10n.warehouseColumnStatus)),
          if (canViewStock || canEdit)
            const DataColumn(label: SizedBox(width: 112)),
        ],
        rows: warehouses.map((warehouse) {
          final employeeLabel = employeeLabelForAgentId(
            agentId: warehouse.agentId,
            employeesById: employeesById,
            languageCode: languageCode,
            inactiveHint: inactiveEmployeeHint,
          );

          return DataRow(
            color: warehouse.isActive
                ? null
                : WidgetStateProperty.all(
                    AppColors.neutral50.withValues(alpha: 0.6),
                  ),
            cells: [
              DataCell(
                Text(
                  localizedWarehouseName(warehouse, languageCode),
                  style: warehouse.isActive
                      ? null
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.neutral400,
                        ),
                ),
              ),
              DataCell(_WarehouseTypeBadge(type: warehouse.type, l10n: l10n)),
              DataCell(Text(employeeLabel ?? l10n.productsNotAvailable)),
              DataCell(
                Text(
                  warehouse.locationAddress?.trim().isNotEmpty == true
                      ? warehouse.locationAddress!
                      : l10n.productsNotAvailable,
                ),
              ),
              DataCell(
                Text(
                  warehouse.isActive
                      ? l10n.warehouseActive
                      : l10n.warehouseInactive,
                ),
              ),
              if (canViewStock || canEdit)
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canViewStock)
                        IconButton(
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                          ),
                          tooltip: l10n.inventory,
                          onPressed: () => onViewStock(warehouse),
                        ),
                      if (canEdit) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: l10n.warehouseEdit,
                          onPressed: () => onEdit(warehouse),
                        ),
                        if (warehouse.isActive)
                          IconButton(
                            icon: const Icon(Icons.block, size: 20),
                            tooltip: l10n.warehouseDeactivate,
                            onPressed: () => onDeactivate(warehouse),
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _WarehouseTypeBadge extends StatelessWidget {
  const _WarehouseTypeBadge({required this.type, required this.l10n});

  final WarehouseType type;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = localizedWarehouseTypeLabel(
      type,
      (key) => switch (key) {
        'main' => l10n.warehouseTypeMain,
        'branch' => l10n.warehouseTypeBranch,
        'van' => l10n.warehouseTypeVan,
        _ => key,
      },
    );

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
