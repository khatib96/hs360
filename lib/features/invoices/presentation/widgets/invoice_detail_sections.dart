import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../domain/invoice_detail.dart';
import '../../domain/invoice_line.dart';
import 'invoice_design.dart';
import 'invoice_sheet.dart';
import 'invoice_totals_panel.dart';

/// Party / dates / warehouse / notes summary block for a posted invoice.
class InvoiceDetailSummary extends StatelessWidget {
  const InvoiceDetailSummary({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final InvoiceDetail detail;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final isDesktop = InvoiceDesign.isDesktop(context);

    final party = detail.party;
    final customerId = detail.customer?.customerId;
    final supplierId = detail.supplier?.supplierId;

    final cells = <Widget>[
      _cell(
        context,
        l10n.invoiceColumnParty,
        child: party == null
            ? const Text('—')
            : _PartyValue(
                name: party.displayName(languageCode),
                onTap: customerId != null
                    ? () => context.go(AppRoutes.customerDetailPath(customerId))
                    : supplierId != null
                    ? () => context.go(AppRoutes.supplierDetailPath(supplierId))
                    : null,
              ),
      ),
      _cell(
        context,
        l10n.invoiceFormDate,
        value: material.formatMediumDate(detail.date),
      ),
      if (detail.dueDate != null)
        _cell(
          context,
          l10n.invoiceColumnDueDate,
          value: material.formatMediumDate(detail.dueDate!),
        ),
      if (detail.warehouse != null)
        _cell(
          context,
          l10n.invoiceFormWarehouse,
          value: languageCode.startsWith('ar')
              ? detail.warehouse!.nameAr
              : detail.warehouse!.nameEn,
        ),
    ];

    return InvoiceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop)
            _grid(cells, columns: 3)
          else
            for (final c in cells)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: c,
              ),
          if (detail.notes != null && detail.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            _cell(context, l10n.invoiceFormNotes, value: detail.notes!),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<Widget> children, {required int columns}) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final end = (i + columns) > children.length
          ? children.length
          : i + columns;
      final slice = children.sublist(i, end);
      rows.add(
        Padding(
          padding: EdgeInsetsDirectional.only(
            bottom: end < children.length ? 14 : 0,
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

  Widget _cell(
    BuildContext context,
    String label, {
    String? value,
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: InvoiceDesign.fieldLabelStyle(context)),
        const SizedBox(height: 2),
        child ??
            Text(value ?? '—', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _PartyValue extends StatelessWidget {
  const _PartyValue({required this.name, this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    if (onTap == null) return Text(name, style: style);
    return InkWell(
      onTap: onTap,
      child: Text(
        name,
        style: style?.copyWith(
          color: AppColors.gold,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.gold,
        ),
      ),
    );
  }
}

/// Posted invoice lines as a dense accounting table.
class InvoiceDetailLinesTable extends StatelessWidget {
  const InvoiceDetailLinesTable({
    required this.lines,
    required this.isWide,
    super.key,
  });

  final List<InvoiceLine> lines;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (lines.isEmpty) {
      return InvoiceSectionCard(
        title: l10n.invoiceDetailLines,
        child: Text(l10n.invoiceListEmpty),
      );
    }

    final theme = Theme.of(context);

    final body = isWide
        ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 28,
                  horizontalMargin: 16,
                  headingRowHeight: 40,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 64,
                  dividerThickness: 0.6,
                  headingRowColor: WidgetStatePropertyAll(
                    InvoiceDesign.headerFill,
                  ),
                  headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
                  columns: [
                    DataColumn(label: Text(l10n.invoiceColumnDescription)),
                    DataColumn(label: Text(l10n.invoiceFormQty), numeric: true),
                    DataColumn(
                      label: Text(l10n.invoiceFormUnitPrice),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(l10n.invoiceFormDiscount),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(l10n.invoiceColumnLineTotal),
                      numeric: true,
                    ),
                  ],
                  rows: [
                    for (final line in lines)
                      DataRow(
                        cells: [
                          DataCell(_descriptionCell(context, line)),
                          DataCell(Text(formatQuantity(line.qty))),
                          DataCell(
                            MoneyDisplay(
                              amount: line.unitPrice,
                              includeSymbol: false,
                            ),
                          ),
                          DataCell(Text('${line.discountPct}%')),
                          DataCell(MoneyDisplay(amount: line.lineTotal)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: InvoiceDesign.borderColor),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _descriptionCell(context, lines[i])),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyDisplay(
                            amount: lines[i].lineTotal,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${formatQuantity(lines[i].qty)} × ',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );

    return InvoiceSectionCard(
      title: l10n.invoiceDetailLines,
      padding: isWide ? EdgeInsets.zero : InvoiceDesign.sectionPadding,
      child: body,
    );
  }

  Widget _descriptionCell(BuildContext context, InvoiceLine line) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[
      Text(
        line.description ?? line.productId,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ];
    if (line.serialNumber != null && line.serialNumber!.trim().isNotEmpty) {
      children.add(
        Text(
          '${l10n.productUnitFieldSerial}: ${line.serialNumber}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final unitId = line.productUnitId;
    if (unitId != null && unitId.isNotEmpty) {
      children.add(
        InkWell(
          onTap: () => context.go(AppRoutes.productUnitDetailPath(unitId)),
          child: Text(
            l10n.productUnitDetailTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.gold,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.gold,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Totals + payment summary for a posted invoice.
class InvoiceDetailTotals extends StatelessWidget {
  const InvoiceDetailTotals({required this.detail, super.key});

  final InvoiceDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InvoiceTotalsBlock(
      rows: [
        InvoiceTotalsRow(l10n.invoiceTotalsSubtotal, detail.subtotal),
        InvoiceTotalsRow(l10n.invoiceTotalsDiscount, detail.discountAmount),
        InvoiceTotalsRow(l10n.invoiceTotalsTax, detail.taxAmount),
        InvoiceTotalsRow(
          l10n.invoiceTotalsTotal,
          detail.total,
          emphasized: true,
        ),
        InvoiceTotalsRow(l10n.invoiceColumnPaid, detail.paidAmount),
        InvoiceTotalsRow(l10n.invoiceColumnOutstanding, detail.outstanding),
      ],
    );
  }
}

/// Compact credit allocations list (returns), shown when present.
class InvoiceCreditAllocations extends StatelessWidget {
  const InvoiceCreditAllocations({required this.detail, super.key});

  final InvoiceDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (detail.creditAllocations.isEmpty) return const SizedBox.shrink();
    return InvoiceSectionCard(
      title: l10n.invoiceCreditAllocations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final alloc in detail.creditAllocations)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(alloc.allocationKind)),
                  MoneyDisplay(amount: alloc.allocatedAmount),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class InvoiceDetailActions extends StatelessWidget {
  const InvoiceDetailActions({
    required this.canEditDraft,
    required this.canConfirmDraft,
    required this.canCancel,
    required this.canReturn,
    required this.canPreview,
    required this.isSubmitting,
    required this.onEditDraft,
    required this.onConfirmDraft,
    required this.onCancel,
    required this.onReturn,
    required this.onPreview,
    super.key,
  });

  final bool canEditDraft;
  final bool canConfirmDraft;
  final bool canCancel;
  final bool canReturn;
  final bool canPreview;
  final bool isSubmitting;
  final VoidCallback onEditDraft;
  final VoidCallback onConfirmDraft;
  final VoidCallback onCancel;
  final VoidCallback onReturn;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canPreview)
          OutlinedButton.icon(
            key: const Key('invoice-detail-preview'),
            onPressed: isSubmitting ? null : onPreview,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(l10n.documentPreviewAction),
          ),
        if (canEditDraft)
          OutlinedButton(
            onPressed: isSubmitting ? null : onEditDraft,
            child: Text(l10n.invoiceActionEditDraft),
          ),
        if (canConfirmDraft)
          FilledButton(
            onPressed: isSubmitting ? null : onConfirmDraft,
            child: Text(l10n.invoiceActionConfirmDraft),
          ),
        if (canReturn)
          OutlinedButton(
            onPressed: isSubmitting ? null : onReturn,
            child: Text(l10n.invoiceActionReturn),
          ),
        if (canCancel)
          OutlinedButton(
            onPressed: isSubmitting ? null : onCancel,
            child: Text(l10n.invoiceActionCancel),
          ),
      ],
    );
  }
}

class InvoiceJournalLinks extends StatelessWidget {
  const InvoiceJournalLinks({required this.detail, super.key});

  final InvoiceDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (detail.journalEntryId == null &&
        detail.reversalJournalEntryId == null) {
      return const SizedBox.shrink();
    }
    return InvoiceSectionCard(
      title: l10n.invoiceJournalEntry,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (detail.journalEntryId != null)
            OutlinedButton.icon(
              onPressed: () => context.go(
                AppRoutes.journalDetailPath(detail.journalEntryId!),
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(l10n.invoiceJournalEntry),
            ),
          if (detail.reversalJournalEntryId != null)
            OutlinedButton.icon(
              onPressed: () => context.go(
                AppRoutes.journalDetailPath(detail.reversalJournalEntryId!),
              ),
              icon: const Icon(Icons.undo, size: 18),
              label: Text(l10n.inventoryDocumentReversalJournal),
            ),
        ],
      ),
    );
  }
}
