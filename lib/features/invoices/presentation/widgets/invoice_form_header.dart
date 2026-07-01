import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../inventory/domain/warehouse.dart';
import '../../domain/invoice_type.dart';
import 'invoice_design.dart';
import 'invoice_party_picker.dart';

/// Compact 2-3 column header grid for the invoice form.
///
/// Folds the party picker in as the first cell so customer/supplier, warehouse,
/// dates and notes read as a single accounting document header.
class InvoiceFormHeader extends StatelessWidget {
  const InvoiceFormHeader({
    required this.invoiceType,
    required this.languageCode,
    required this.warehouses,
    required this.warehouseId,
    required this.date,
    required this.notes,
    required this.onWarehouseChanged,
    required this.onDateChanged,
    required this.onNotesChanged,
    super.key,
  });

  final InvoiceType invoiceType;
  final String languageCode;
  final List<Warehouse> warehouses;
  final String? warehouseId;
  final DateTime? date;
  final String notes;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onNotesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = InvoiceDesign.isDesktop(context);

    final party = _Labeled(
      label: invoiceType.isSalesDirection
          ? l10n.invoiceFormCustomer
          : l10n.invoiceFormSupplier,
      child: InvoicePartyPicker(
        invoiceType: invoiceType,
        languageCode: languageCode,
      ),
    );

    final warehouse = _Labeled(
      label: l10n.invoiceFormWarehouse,
      child: DropdownButtonFormField<String>(
        key: ValueKey('invoice-warehouse-$warehouseId'),
        initialValue: warehouseId,
        isDense: true,
        decoration: InvoiceDesign.denseField(context),
        items: warehouses
            .map(
              (w) => DropdownMenuItem(
                value: w.id,
                child: Text(
                  languageCode.startsWith('ar') ? w.nameAr : w.nameEn,
                ),
              ),
            )
            .toList(),
        onChanged: onWarehouseChanged,
      ),
    );

    final dateField = _Labeled(
      label: l10n.invoiceFormDate,
      child: _DateField(value: date, onPick: onDateChanged),
    );

    final notesField = _Labeled(
      label: l10n.invoiceFormNotes,
      child: TextFormField(
        initialValue: notes,
        decoration: InvoiceDesign.denseField(context),
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 2,
        onChanged: onNotesChanged,
      ),
    );

    final fields = <Widget>[party, warehouse, dateField];

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in fields)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: field,
            ),
          notesField,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grid(columns: 3, children: fields),
        const SizedBox(height: 14),
        notesField,
      ],
    );
  }
}

/// Simple responsive grid that lays children into [columns] equal columns.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
        i,
        (i + columns) > children.length ? children.length : i + columns,
      );
      rows.add(
        Padding(
          padding: EdgeInsetsDirectional.only(
            bottom: (i + columns) < children.length ? 14 : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 14),
                Expanded(
                  child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// A small field label above its control (dense document style).
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 4),
          child: Text(label, style: InvoiceDesign.fieldLabelStyle(context)),
        ),
        child,
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onPick});

  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final text = value == null ? '' : material.formatMediumDate(value!);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(
          context,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          text.isEmpty ? '—' : text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
