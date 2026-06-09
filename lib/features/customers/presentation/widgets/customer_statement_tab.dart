import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../core/documents/domain/document_kind.dart';
import '../../../../core/documents/domain/document_permissions.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../customer_error_messages.dart';
import '../customer_statement_controller.dart';
import '../journal_source_labels.dart';

class CustomerStatementTab extends ConsumerStatefulWidget {
  const CustomerStatementTab({required this.customerId, super.key});

  final String customerId;

  @override
  ConsumerState<CustomerStatementTab> createState() =>
      _CustomerStatementTabState();
}

class _CustomerStatementTabState extends ConsumerState<CustomerStatementTab> {
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = _toDate.subtract(const Duration(days: 364));
  }

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final state = ref.watch(
      customerStatementControllerProvider(widget.customerId),
    );
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canPreview =
        session != null &&
        canPreviewDocument(session, DocumentKind.customerStatement);
    final notifier = ref.read(
      customerStatementControllerProvider(widget.customerId).notifier,
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
        if (canPreview) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('customer-statement-from-date'),
                  onPressed: () => _pickDate(
                    initial: _fromDate,
                    firstDate: DateTime(2000),
                    lastDate: _toDate,
                    onPicked: (value) => setState(() => _fromDate = value),
                  ),
                  child: Text(
                    '${l10n.customerStatementFromDate}: ${dateFormat.format(_fromDate)}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const Key('customer-statement-to-date'),
                  onPressed: () => _pickDate(
                    initial: _toDate,
                    firstDate: _fromDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onPicked: (value) => setState(() => _toDate = value),
                  ),
                  child: Text(
                    '${l10n.customerStatementToDate}: ${dateFormat.format(_toDate)}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: const Key('customer-statement-preview'),
              onPressed: () {
                context.push(
                  AppRoutes.documentPreviewPath(
                    kind: DocumentKind.customerStatement.documentType,
                    entityId: widget.customerId,
                    from: _fromDate,
                    to: _toDate,
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l10n.documentPreviewAction),
            ),
          ),
          const SizedBox(height: 16),
        ],
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
