import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/location/kuwait_locations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/supplier.dart';

/// Renders the supplier list as a dense desktop table or mobile cards.
class SupplierTable extends StatelessWidget {
  const SupplierTable({
    required this.suppliers,
    required this.languageCode,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final List<Supplier> suppliers;
  final String languageCode;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Supplier> onView;
  final ValueChanged<Supplier> onEdit;
  final ValueChanged<Supplier> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 768;
    if (isWide) {
      return _DesktopSupplierTable(
        suppliers: suppliers,
        languageCode: languageCode,
        canEdit: canEdit,
        canDeactivate: canDeactivate,
        onView: onView,
        onEdit: onEdit,
        onDeactivate: onDeactivate,
      );
    }
    return _MobileSupplierList(
      suppliers: suppliers,
      languageCode: languageCode,
      canEdit: canEdit,
      canDeactivate: canDeactivate,
      onView: onView,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class _DesktopSupplierTable extends StatefulWidget {
  const _DesktopSupplierTable({
    required this.suppliers,
    required this.languageCode,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Supplier> suppliers;
  final String languageCode;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Supplier> onView;
  final ValueChanged<Supplier> onEdit;
  final ValueChanged<Supplier> onDeactivate;

  @override
  State<_DesktopSupplierTable> createState() => _DesktopSupplierTableState();
}

class _DesktopSupplierTableState extends State<_DesktopSupplierTable> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.neutral50),
              columns: [
                DataColumn(label: Text(l10n.supplierColumnCode)),
                DataColumn(label: Text(l10n.supplierColumnName)),
                DataColumn(label: Text(l10n.supplierColumnPhone)),
                DataColumn(label: Text(l10n.supplierColumnEmail)),
                DataColumn(label: Text(l10n.supplierColumnLocation)),
                DataColumn(label: Text(l10n.supplierColumnStatus)),
                const DataColumn(label: SizedBox(width: 120)),
              ],
              rows: widget.suppliers.map((supplier) {
                final location = _locationLabel(supplier, widget.languageCode);
                return DataRow(
                  cells: [
                    DataCell(Text(supplier.code)),
                    DataCell(Text(supplier.displayName(widget.languageCode))),
                    DataCell(Text(supplier.phone ?? l10n.productsNotAvailable)),
                    DataCell(Text(supplier.email ?? l10n.productsNotAvailable)),
                    DataCell(
                      Text(
                        location.isEmpty
                            ? l10n.productsNotAvailable
                            : location,
                      ),
                    ),
                    DataCell(
                      Text(
                        supplier.isActive
                            ? l10n.supplierStatusActive
                            : l10n.supplierStatusInactive,
                        style: supplier.isActive
                            ? null
                            : theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.neutral400),
                      ),
                    ),
                    DataCell(
                      _RowActions(
                        supplier: supplier,
                        canEdit: widget.canEdit,
                        canDeactivate: widget.canDeactivate,
                        onView: widget.onView,
                        onEdit: widget.onEdit,
                        onDeactivate: widget.onDeactivate,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

String _locationLabel(Supplier supplier, String languageCode) {
  final parts = <String>[];
  final gov = supplier.governorate;
  if (gov != null && gov.isNotEmpty) {
    parts.add(governorateLabel(gov, languageCode));
  }
  final ar = supplier.area;
  if (ar != null && ar.isNotEmpty) {
    parts.add(areaLabel(gov, ar, languageCode));
  }
  return parts.join(' / ');
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.supplier,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Supplier supplier;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Supplier> onView;
  final ValueChanged<Supplier> onEdit;
  final ValueChanged<Supplier> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          tooltip: l10n.supplierActionView,
          onPressed: () => onView(supplier),
        ),
        if (canEdit)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: l10n.supplierActionEdit,
            onPressed: () => onEdit(supplier),
          ),
        if (canDeactivate && supplier.isActive)
          IconButton(
            icon: const Icon(Icons.block, size: 20),
            tooltip: l10n.supplierActionDeactivate,
            onPressed: () => onDeactivate(supplier),
          ),
      ],
    );
  }
}

class _MobileSupplierList extends StatelessWidget {
  const _MobileSupplierList({
    required this.suppliers,
    required this.languageCode,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Supplier> suppliers;
  final String languageCode;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Supplier> onView;
  final ValueChanged<Supplier> onEdit;
  final ValueChanged<Supplier> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        final location = _locationLabel(supplier, languageCode);
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => onView(supplier),
            title: Text(supplier.displayName(languageCode)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${supplier.code} · ${supplier.phone ?? l10n.productsNotAvailable}'),
                if (location.isNotEmpty) Text(location),
                Text(
                  supplier.isActive
                      ? l10n.supplierStatusActive
                      : l10n.supplierStatusInactive,
                ),
              ],
            ),
            trailing: _RowActions(
              supplier: supplier,
              canEdit: canEdit,
              canDeactivate: canDeactivate,
              onView: onView,
              onEdit: onEdit,
              onDeactivate: onDeactivate,
            ),
          ),
        );
      },
    );
  }
}
