import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../domain/journal_entry_detail.dart';
import '../../domain/journal_line.dart';
import '../journal_display_helpers.dart';
import '../journal_source_navigation.dart';
import 'journal_shared_widgets.dart';

class JournalDetailHeader extends StatelessWidget {
  const JournalDetailHeader({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final JournalEntryDetail detail;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = detail.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              summary.entryNumber,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (summary.isPosted) journalPostedBadge(context, l10n),
            if (summary.reversalOfEntryId != null ||
                journalEntryIsReversal(summary.source))
              journalReversalBadge(context, l10n),
          ],
        ),
        const SizedBox(height: 8),
        Text(journalSourceLabel(l10n, summary.source)),
        const SizedBox(height: 4),
        Text(MaterialLocalizations.of(context).formatMediumDate(summary.date)),
        const SizedBox(height: 4),
        Text(
          journalEntryDescription(
            languageCode,
            descriptionAr: summary.descriptionAr,
            descriptionEn: summary.descriptionEn,
          ),
        ),
      ],
    );
  }
}

class JournalDetailTotals extends StatelessWidget {
  const JournalDetailTotals({required this.detail, super.key});

  final JournalEntryDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lines = detail.lines;
    final totalDebit = lines.fold(
      Decimal.zero,
      (sum, line) => sum + line.debit,
    );
    final totalCredit = lines.fold(
      Decimal.zero,
      (sum, line) => sum + line.credit,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.financeTotalsGrandTotal,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _amountRow(context, l10n.financeColumnDebit, totalDebit),
        _amountRow(context, l10n.financeColumnCredit, totalCredit),
      ],
    );
  }

  Widget _amountRow(BuildContext context, String label, Decimal amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          MoneyDisplay(amount: amount),
        ],
      ),
    );
  }
}

class JournalDetailLinesTable extends StatelessWidget {
  const JournalDetailLinesTable({
    required this.lines,
    required this.languageCode,
    required this.isWide,
    super.key,
  });

  final List<JournalLine> lines;
  final String languageCode;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (lines.isEmpty) {
      return Text(l10n.journalListEmpty);
    }

    if (isWide) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(l10n.journalLineAccount)),
            DataColumn(label: Text(l10n.financeColumnDescription)),
            DataColumn(label: Text(l10n.financeColumnDebit)),
            DataColumn(label: Text(l10n.financeColumnCredit)),
          ],
          rows: [
            for (final line in lines)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      journalAccountDisplayName(
                        languageCode,
                        nameAr: line.accountNameAr,
                        nameEn: line.accountNameEn,
                        code: line.accountCode,
                      ),
                    ),
                  ),
                  DataCell(Text(line.description ?? '—')),
                  DataCell(MoneyDisplay(amount: line.debit)),
                  DataCell(MoneyDisplay(amount: line.credit)),
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final line in lines)
          ListTile(
            title: Text(
              journalAccountDisplayName(
                languageCode,
                nameAr: line.accountNameAr,
                nameEn: line.accountNameEn,
                code: line.accountCode,
              ),
            ),
            subtitle: line.description == null ? null : Text(line.description!),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (line.debit > Decimal.zero) MoneyDisplay(amount: line.debit),
                if (line.credit > Decimal.zero)
                  MoneyDisplay(amount: line.credit),
              ],
            ),
          ),
      ],
    );
  }
}

class JournalSourceDocumentLink extends StatelessWidget {
  const JournalSourceDocumentLink({required this.detail, super.key});

  final JournalEntryDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = detail.summary;
    final route = routeForJournalSource(summary.source, summary.sourceId);
    if (route == null) return const SizedBox.shrink();

    return TextButton(
      onPressed: () => context.go(route),
      child: Text(l10n.journalSourceDocument),
    );
  }
}

class JournalReversalLinks extends StatelessWidget {
  const JournalReversalLinks({required this.detail, super.key});

  final JournalEntryDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = detail.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.reversalOfEntryId != null)
          TextButton(
            onPressed: () => context.go(
              AppRoutes.journalDetailPath(summary.reversalOfEntryId!),
            ),
            child: Text(l10n.journalReversalEntry),
          ),
        if (summary.reversedByEntryId != null)
          TextButton(
            onPressed: () => context.go(
              AppRoutes.journalDetailPath(summary.reversedByEntryId!),
            ),
            child: Text(l10n.financeReversalLabel),
          ),
      ],
    );
  }
}
