import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../finance_shared/presentation/money_display.dart';
import '../../domain/cash_bank_activity_row.dart';
import '../journal_display_helpers.dart';
import '../journal_source_navigation.dart';

class CashBankActivityTable extends StatelessWidget {
  const CashBankActivityTable({required this.rows, super.key});

  final List<CashBankActivityRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.financeColumnDate)),
          DataColumn(label: Text(l10n.voucherColumnNumber)),
          DataColumn(label: Text(l10n.journalFilterSource)),
          DataColumn(label: Text(l10n.financeColumnDescription)),
          DataColumn(label: Text(l10n.financeColumnDebit)),
          DataColumn(label: Text(l10n.financeColumnCredit)),
          DataColumn(label: Text(l10n.cashBankRunningBalance)),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(Text(_formatDate(context, row.entryDate))),
                DataCell(Text(row.entryNumber)),
                DataCell(_sourceCell(context, l10n, row)),
                DataCell(Text(row.description ?? '—')),
                DataCell(MoneyDisplay(amount: row.debit)),
                DataCell(MoneyDisplay(amount: row.credit)),
                DataCell(MoneyDisplay(amount: row.runningBalance)),
              ],
            ),
        ],
      ),
    );
  }
}

class CashBankActivityCardList extends StatelessWidget {
  const CashBankActivityCardList({required this.rows, super.key});

  final List<CashBankActivityRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.entryNumber,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                _sourceCell(context, l10n, row),
                const SizedBox(height: 4),
                Text(_formatDate(context, row.entryDate)),
                if (row.description != null &&
                    row.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(row.description!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${l10n.financeColumnDebit}: '),
                    MoneyDisplay(amount: row.debit),
                    const SizedBox(width: 12),
                    Text('${l10n.financeColumnCredit}: '),
                    MoneyDisplay(amount: row.credit),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${l10n.cashBankRunningBalance}: '),
                    MoneyDisplay(amount: row.runningBalance),
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

Widget _sourceCell(
  BuildContext context,
  AppLocalizations l10n,
  CashBankActivityRow row,
) {
  final label = journalSourceLabel(l10n, row.source);
  final route = routeForJournalSource(row.source, row.sourceId);
  if (route == null) return Text(label);
  return TextButton(
    onPressed: () => context.go(route),
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label),
  );
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date);
}
