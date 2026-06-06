import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../customer_error_messages.dart';
import '../customer_statement_controller.dart';
import '../journal_source_labels.dart';

class CustomerStatementTab extends ConsumerWidget {
  const CustomerStatementTab({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final state = ref.watch(customerStatementControllerProvider(customerId));
    final notifier = ref.read(
      customerStatementControllerProvider(customerId).notifier,
    );

    if (state.permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            key: const Key('customer-statement-denied'),
            variant: MessageBannerVariant.info,
            message: l10n.customerLedgerPermissionDenied,
          ),
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorCode != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MessageBanner(
                variant: MessageBannerVariant.error,
                message: customerErrorMessage(l10n, state.errorCode!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('customer-statement-retry'),
                onPressed: () => notifier.load(force: true),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasLoaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Text(
            l10n.customerStatementNotLoaded,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final dateFormat = DateFormat.yMMMd(languageCode);

    return ListView(
      key: const Key('customer-statement-loaded'),
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(
          l10n.customerStatementSummaryTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          label: l10n.customerStatementDebit,
          value: formatMoney(state.summary.debitTotal, locale: languageCode),
        ),
        _SummaryRow(
          label: l10n.customerStatementCredit,
          value: formatMoney(state.summary.creditTotal, locale: languageCode),
        ),
        _SummaryRow(
          label: l10n.customerStatementBalance,
          value: formatMoney(state.summary.balance, locale: languageCode),
        ),
        const SizedBox(height: 24),
        if (state.rows.isEmpty)
          Text(
            l10n.customerStatementEmpty,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          )
        else
          ...state.rows.map((row) {
            return Card(
              margin: const EdgeInsetsDirectional.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dateFormat.format(row.entryDate)} · ${row.entryNumber}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      journalSourceLabel(l10n, row.source),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (row.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(row.description!.trim()),
                    ],
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: l10n.customerStatementDebit,
                      value: formatMoney(row.debit, locale: languageCode),
                    ),
                    _SummaryRow(
                      label: l10n.customerStatementCredit,
                      value: formatMoney(row.credit, locale: languageCode),
                    ),
                    _SummaryRow(
                      label: l10n.customerStatementBalance,
                      value: formatMoney(
                        row.runningBalance,
                        locale: languageCode,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        if (state.loadMoreErrorCode != null) ...[
          const SizedBox(height: 4),
          MessageBanner(
            variant: MessageBannerVariant.error,
            message: customerErrorMessage(l10n, state.loadMoreErrorCode!),
          ),
        ],
        if (state.hasMore ||
            state.isLoadingMore ||
            state.loadMoreErrorCode != null) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              key: const Key('customer-statement-load-more'),
              onPressed: state.isLoadingMore ? null : notifier.loadMore,
              icon: state.isLoadingMore
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                state.loadMoreErrorCode == null ? l10n.loadMore : l10n.retry,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
