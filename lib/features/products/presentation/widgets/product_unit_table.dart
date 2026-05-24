import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/money_formatter.dart';
import '../../domain/product_unit.dart';
import '../../domain/product_unit_edit_policy.dart';
import '../product_unit_display_helpers.dart';
import 'edit_product_unit_dialog.dart';

class ProductUnitTable extends StatelessWidget {
  const ProductUnitTable({
    required this.units,
    required this.languageCode,
    required this.canViewCosts,
    required this.canEdit,
    required this.l10n,
    required this.onEdit,
    super.key,
  });

  final List<ProductUnit> units;
  final String languageCode;
  final bool canViewCosts;
  final bool canEdit;
  final AppLocalizations l10n;
  final Future<String?> Function(
    String unitId,
    ProductUnitSafeEditResult result,
  ) onEdit;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Center(child: Text(l10n.productUnitsEmpty));
    }

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(l10n.productUnitFieldSerial)),
            DataColumn(label: Text(l10n.productUnitFieldBarcode)),
            DataColumn(label: Text(l10n.productUnitFieldStatus)),
            DataColumn(label: Text(l10n.productUnitFieldWarehouse)),
            if (canViewCosts)
              DataColumn(label: Text(l10n.productUnitFieldPurchaseCost)),
            DataColumn(label: Text(l10n.productUnitFieldHealth)),
            DataColumn(label: Text(l10n.productUnitFieldAcquired)),
            DataColumn(label: Text(l10n.productUnitFieldNotes)),
            if (canEdit) const DataColumn(label: Text('')),
          ],
          rows: units.map((unit) => _row(context, unit)).toList(),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, ProductUnit unit) {
    final editable = canEdit && isUnitSafeEditable(unit.status);
    return DataRow(
      cells: [
        DataCell(Text(unit.serialNumber)),
        DataCell(Text(unit.barcode ?? '—')),
        DataCell(Text(unitStatusLabel(l10n, unit.status))),
        DataCell(Text(productUnitWarehouseLabel(unit, languageCode))),
        if (canViewCosts)
          DataCell(
            Text(
              unit.purchaseCost != null
                  ? formatMoney(unit.purchaseCost!)
                  : '—',
            ),
          ),
        DataCell(Text(unitHealthLabel(l10n, unit.healthStatus))),
        DataCell(Text(_formatDate(unit.acquiredAt))),
        DataCell(Text(unit.notes ?? '—')),
        if (canEdit)
          DataCell(
            editable
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.productUnitEdit,
                    onPressed: () async {
                      final result = await showEditProductUnitDialog(
                        context: context,
                        unit: unit,
                        l10n: l10n,
                      );
                      if (result != null && context.mounted) {
                        await onEdit(unit.id, result);
                      }
                    },
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
