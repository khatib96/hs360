import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/product_unit.dart';
import '../../domain/product_unit_edit_policy.dart';
import '../product_unit_display_helpers.dart';
import 'edit_product_unit_dialog.dart';

class ProductUnitTable extends StatefulWidget {
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
  )
  onEdit;

  @override
  State<ProductUnitTable> createState() => _ProductUnitTableState();
}

class _ProductUnitTableState extends State<ProductUnitTable> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.units.isEmpty) {
      return Center(child: Text(widget.l10n.productUnitsEmpty));
    }

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(widget.l10n.productUnitFieldSerial)),
            DataColumn(label: Text(widget.l10n.productUnitFieldBarcode)),
            DataColumn(label: Text(widget.l10n.productUnitFieldStatus)),
            DataColumn(label: Text(widget.l10n.productUnitFieldWarehouse)),
            if (widget.canViewCosts)
              DataColumn(label: Text(widget.l10n.productUnitFieldPurchaseCost)),
            DataColumn(label: Text(widget.l10n.productUnitFieldHealth)),
            DataColumn(label: Text(widget.l10n.productUnitFieldAcquired)),
            DataColumn(label: Text(widget.l10n.productUnitFieldNotes)),
            if (widget.canEdit) const DataColumn(label: Text('')),
          ],
          rows: widget.units.map((unit) => _row(context, unit)).toList(),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, ProductUnit unit) {
    final editable = widget.canEdit && isUnitSafeEditable(unit.status);
    return DataRow(
      onSelectChanged: (_) =>
          context.go(AppRoutes.productUnitDetailPath(unit.id)),
      cells: [
        DataCell(Text(unit.serialNumber)),
        DataCell(Text(unit.barcode ?? '-')),
        DataCell(Text(unitStatusLabel(widget.l10n, unit.status))),
        DataCell(Text(productUnitWarehouseLabel(unit, widget.languageCode))),
        if (widget.canViewCosts)
          DataCell(
            Text(
              unit.purchaseCost != null ? formatMoney(unit.purchaseCost!) : '-',
            ),
          ),
        DataCell(Text(unitHealthLabel(widget.l10n, unit.healthStatus))),
        DataCell(Text(_formatDate(unit.acquiredAt))),
        DataCell(Text(unit.notes ?? '-')),
        if (widget.canEdit)
          DataCell(
            editable
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: widget.l10n.productUnitEdit,
                    onPressed: () async {
                      final result = await showEditProductUnitDialog(
                        context: context,
                        unit: unit,
                        l10n: widget.l10n,
                      );
                      if (result != null && context.mounted) {
                        await widget.onEdit(unit.id, result);
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
