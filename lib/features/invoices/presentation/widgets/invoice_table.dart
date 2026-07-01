import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../domain/invoice_summary.dart';
import '../invoice_display_helpers.dart';
import 'invoice_design.dart';
import 'invoice_shared_widgets.dart';

/// Dense, full-width ERP-style invoice table (desktop).
class InvoiceTable extends StatelessWidget {
  const InvoiceTable({
    required this.invoices,
    required this.languageCode,
    super.key,
  });

  final List<InvoiceSummary> invoices;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 28,
              horizontalMargin: 16,
              headingRowHeight: 42,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              dividerThickness: 0.6,
              headingRowColor: WidgetStatePropertyAll(InvoiceDesign.headerFill),
              headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
              dataTextStyle: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
              ),
              columns: [
                DataColumn(label: Text(l10n.invoiceColumnNumber)),
                DataColumn(label: Text(l10n.invoiceFilterType)),
                DataColumn(label: Text(l10n.invoiceColumnParty)),
                DataColumn(label: Text(l10n.invoiceColumnDate)),
                DataColumn(label: Text(l10n.invoiceColumnDueDate)),
                DataColumn(label: Text(l10n.invoiceColumnTotal), numeric: true),
                DataColumn(label: Text(l10n.invoiceColumnPaid), numeric: true),
                DataColumn(
                  label: Text(l10n.invoiceColumnOutstanding),
                  numeric: true,
                ),
                DataColumn(label: Text(l10n.financeColumnStatus)),
              ],
              rows: [
                for (final invoice in invoices)
                  DataRow(
                    onSelectChanged: (_) => context.go(
                      AppRoutes.invoiceDetailPath(
                        invoice.id,
                        type: invoice.type,
                      ),
                    ),
                    cells: [
                      DataCell(
                        Text(
                          invoice.invoiceNumber ?? '—',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(Text(invoiceTypeLabel(l10n, invoice.type))),
                      DataCell(Text(_partyName(invoice))),
                      DataCell(Text(_formatDate(context, invoice.date))),
                      DataCell(
                        Text(
                          invoice.dueDate == null
                              ? '—'
                              : _formatDate(context, invoice.dueDate!),
                        ),
                      ),
                      DataCell(MoneyDisplay(amount: invoice.total)),
                      DataCell(
                        invoice.paidAmount == null
                            ? const Text('—')
                            : MoneyDisplay(amount: invoice.paidAmount!),
                      ),
                      DataCell(
                        invoice.outstanding == null
                            ? const Text('—')
                            : MoneyDisplay(amount: invoice.outstanding!),
                      ),
                      DataCell(_statusCell(context, l10n, invoice)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _partyName(InvoiceSummary invoice) {
    final party = invoice.party;
    if (party == null) return '—';
    return party.displayName(languageCode);
  }
}

/// Compact mobile row list (no oversized cards).
class InvoiceCardList extends StatelessWidget {
  const InvoiceCardList({
    required this.invoices,
    required this.languageCode,
    super.key,
  });

  final List<InvoiceSummary> invoices;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView.separated(
      itemCount: invoices.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: InvoiceDesign.borderColor),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return InkWell(
          onTap: () => context.go(
            AppRoutes.invoiceDetailPath(invoice.id, type: invoice.type),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.invoiceNumber ?? '—',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _statusCell(context, l10n, invoice),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${invoiceTypeLabel(l10n, invoice.type)} · '
                        '${invoice.party?.displayName(languageCode) ?? '—'}',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDate(context, invoice.date),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${l10n.invoiceColumnTotal}: ',
                      style: theme.textTheme.bodySmall,
                    ),
                    MoneyDisplay(
                      amount: invoice.total,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (invoice.outstanding != null) ...[
                      const Spacer(),
                      Text(
                        '${l10n.invoiceColumnOutstanding}: ',
                        style: theme.textTheme.bodySmall,
                      ),
                      MoneyDisplay(amount: invoice.outstanding!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _statusCell(
  BuildContext context,
  AppLocalizations l10n,
  InvoiceSummary invoice,
) {
  final overdue = isInvoiceOverdue(invoice);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      invoiceStatusChip(
        context,
        invoiceStatusLabel(l10n, invoice.status),
        cancelled: invoice.status.isCancelled,
      ),
      if (overdue) ...[
        const SizedBox(width: 6),
        invoiceStatusChip(context, l10n.invoiceOverdueBadge, overdue: true),
      ],
    ],
  );
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date);
}
