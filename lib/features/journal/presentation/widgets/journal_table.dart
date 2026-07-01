import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../domain/journal_entry_summary.dart';
import '../journal_display_helpers.dart';
import '../journal_source_navigation.dart';
import 'journal_shared_widgets.dart';

class JournalTable extends StatelessWidget {
  const JournalTable({
    required this.entries,
    required this.languageCode,
    super.key,
  });

  final List<JournalEntrySummary> entries;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.voucherColumnNumber)),
          DataColumn(label: Text(l10n.journalFilterSource)),
          DataColumn(label: Text(l10n.financeColumnDate)),
          DataColumn(label: Text(l10n.financeColumnDescription)),
          DataColumn(label: Text(l10n.financeColumnDebit)),
          DataColumn(label: Text(l10n.financeColumnCredit)),
          DataColumn(label: Text(l10n.financeColumnStatus)),
        ],
        rows: [
          for (final entry in entries)
            DataRow(
              onSelectChanged: (_) =>
                  context.go(AppRoutes.journalDetailPath(entry.id)),
              cells: [
                DataCell(Text(entry.entryNumber)),
                DataCell(_sourceCell(context, l10n, entry)),
                DataCell(Text(_formatDate(context, entry.date))),
                DataCell(
                  Text(
                    journalEntryDescription(
                      languageCode,
                      descriptionAr: entry.descriptionAr,
                      descriptionEn: entry.descriptionEn,
                    ),
                  ),
                ),
                DataCell(MoneyDisplay(amount: entry.totalDebit)),
                DataCell(MoneyDisplay(amount: entry.totalCredit)),
                DataCell(_statusCell(context, l10n, entry)),
              ],
            ),
        ],
      ),
    );
  }
}

class JournalCardList extends StatelessWidget {
  const JournalCardList({
    required this.entries,
    required this.languageCode,
    super.key,
  });

  final List<JournalEntrySummary> entries;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: InkWell(
            onTap: () => context.go(AppRoutes.journalDetailPath(entry.id)),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.entryNumber,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _statusCell(context, l10n, entry),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _sourceCell(context, l10n, entry),
                  const SizedBox(height: 4),
                  Text(_formatDate(context, entry.date)),
                  const SizedBox(height: 4),
                  Text(
                    journalEntryDescription(
                      languageCode,
                      descriptionAr: entry.descriptionAr,
                      descriptionEn: entry.descriptionEn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${l10n.financeColumnDebit}: '),
                      MoneyDisplay(amount: entry.totalDebit),
                      const SizedBox(width: 16),
                      Text('${l10n.financeColumnCredit}: '),
                      MoneyDisplay(amount: entry.totalCredit),
                    ],
                  ),
                ],
              ),
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
  JournalEntrySummary entry,
) {
  final label = journalSourceLabel(l10n, entry.source);
  final route = routeForJournalSource(entry.source, entry.sourceId);
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

Widget _statusCell(
  BuildContext context,
  AppLocalizations l10n,
  JournalEntrySummary entry,
) {
  return Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      if (entry.isPosted) journalPostedBadge(context, l10n),
      if (entry.reversalOfEntryId != null ||
          journalEntryIsReversal(entry.source))
        journalReversalBadge(context, l10n),
    ],
  );
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date);
}
