import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../domain/inventory_balance_row.dart';
import '../../domain/inventory_stock_helpers.dart';
import '../inventory_balance_display_helpers.dart';

class InventoryBalanceTable extends StatelessWidget {
  const InventoryBalanceTable({
    required this.rows,
    required this.languageCode,
    super.key,
  });

  final List<InventoryBalanceRow> rows;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width > 900;
    final totalsByProduct = _totalsByProduct(rows);

    if (isWide) {
      return SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.neutral50),
          columns: [
            DataColumn(label: Text(l10n.inventoryBalanceProduct)),
            DataColumn(label: Text(l10n.inventoryBalanceWarehouse)),
            DataColumn(
              label: Text(l10n.inventoryBalanceAvailable),
              numeric: true,
            ),
            DataColumn(
              label: Text(l10n.inventoryBalanceRented),
              numeric: true,
            ),
            DataColumn(
              label: Text(l10n.inventoryBalanceTrial),
              numeric: true,
            ),
            DataColumn(
              label: Text(l10n.inventoryBalanceMaintenance),
              numeric: true,
            ),
            DataColumn(
              label: Text(l10n.inventoryBalanceDamaged),
              numeric: true,
            ),
          ],
          rows: [
            for (final row in rows)
              _dataRow(
                context,
                l10n,
                row,
                totalsByProduct[row.productId] ?? Decimal.zero,
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        final total = totalsByProduct[row.productId] ?? Decimal.zero;
        final low = isLowStock(
          totalAvailable: total,
          reorderPoint: row.reorderPoint,
        );
        return ListTile(
          title: Text(
            inventoryBalanceProductLabel(row, languageCode, l10n),
            style: low
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.warning,
                    )
                : null,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inventoryBalanceWarehouseLabel(row, languageCode, l10n)),
              const SizedBox(height: 4),
              Text(
                '${l10n.inventoryBalanceAvailable}: ${formatQuantity(row.qtyAvailable)}',
              ),
            ],
          ),
          isThreeLine: true,
        );
      },
    );
  }

  DataRow _dataRow(
    BuildContext context,
    AppLocalizations l10n,
    InventoryBalanceRow row,
    Decimal productTotalAvailable,
  ) {
    final low = isLowStock(
      totalAvailable: productTotalAvailable,
      reorderPoint: row.reorderPoint,
    );
    return DataRow(
      cells: [
        DataCell(
          Text(
            inventoryBalanceProductLabel(row, languageCode, l10n),
            style: low
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.warning,
                    )
                : null,
          ),
        ),
        DataCell(Text(inventoryBalanceWarehouseLabel(row, languageCode, l10n))),
        DataCell(Text(formatQuantity(row.qtyAvailable))),
        DataCell(Text(formatQuantity(row.qtyRented))),
        DataCell(Text(formatQuantity(row.qtyTrial))),
        DataCell(Text(formatQuantity(row.qtyMaintenance))),
        DataCell(Text(formatQuantity(row.qtyDamaged))),
      ],
    );
  }

  static Map<String, Decimal> _totalsByProduct(List<InventoryBalanceRow> rows) {
    final totals = <String, Decimal>{};
    for (final row in rows) {
      totals[row.productId] =
          (totals[row.productId] ?? Decimal.zero) + row.qtyAvailable;
    }
    return totals;
  }
}
