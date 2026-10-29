import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/finance_exception.dart';
import '../../../../shared/widgets/app_lifecycle_action_dialog.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../../auth/domain/app_session.dart';
import '../../../finance_shared/domain/finance_idempotency.dart';
import '../../../finance_shared/presentation/finance_error_messages.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../data/rental_billing_repository.dart';
import '../../domain/rental_billing.dart';
import 'contract_detail_panel.dart';

/// Payment-confirmed collections of a rental contract, with full cancel.
class ContractRentalCollectionsSection extends ConsumerWidget {
  const ContractRentalCollectionsSection({
    required this.contractId,
    required this.session,
    this.onChanged,
    super.key,
  });

  final String contractId;
  final AppSession session;

  /// Called after a cancellation so the page can refresh contract data.
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collections = ref.watch(
      contractRentalCollectionsProvider(contractId),
    );

    return ContractDetailPanel(
      key: const Key('contract-rental-collections'),
      title: l10n.rentalCollectionsTitle,
      child: collections.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Text(l10n.rentalCollectionsLoadError),
        data: (entries) => entries.isEmpty
            ? Text(l10n.rentalCollectionsEmpty)
            : Column(
                children: [
                  for (final entry in entries)
                    _CollectionRow(
                      entry: entry,
                      canCancel:
                          !entry.isCancelled &&
                          canCancelRentalCollection(session),
                      onCancel: () => _cancel(context, ref, entry),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    RentalCollectionEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showAppLifecycleActionDialog(
      context: context,
      title: '${l10n.rentalCollectionCancelAction} — ${entry.invoiceNumber}',
      consequence: l10n.rentalCollectionCancelConsequence,
      confirmLabel: l10n.rentalCollectionCancelAction,
      reasonRequired: true,
    );
    if (reason == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(rentalBillingRepositoryProvider)
          .cancelCollection(
            invoiceId: entry.invoiceId,
            reason: reason,
            idempotencyKey: FinanceIdempotencySession().key,
          );
      ref.invalidate(contractRentalCollectionsProvider(contractId));
      ref.invalidate(rentalArrearsProvider);
      await onChanged?.call();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rentalCollectionCancelled)),
      );
    } on FinanceException catch (error) {
      final otherPayments =
          error.technicalDetail?.contains('invoice_has_payments') ?? false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            otherPayments
                ? l10n.rentalCollectionHasOtherPayments
                : financeErrorMessage(l10n, error.code),
          ),
        ),
      );
    }
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.entry,
    required this.canCancel,
    required this.onCancel,
  });

  final RentalCollectionEntry entry;
  final bool canCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final months = entry.coverageMonths
        .map(DateFormat.yMMM(locale).format)
        .join('، ');

    return Padding(
      key: Key('rental-collection-${entry.invoiceId}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      entry.invoiceNumber,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(DateFormat.yMd(locale).format(entry.date)),
                    AppStatusBadge(
                      label: entry.isCancelled
                          ? l10n.rentalCollectionStatusCancelled
                          : l10n.rentalCollectionStatusCollected,
                      tone: entry.isCancelled
                          ? AppStatusTone.error
                          : AppStatusTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.rentalCollectionMonthsLabel}: $months'
                  '${entry.voucherNumber == null ? '' : ' · ${l10n.rentalCollectionVoucherLabel}: ${entry.voucherNumber}'}',
                  style: theme.textTheme.bodySmall,
                ),
                if (entry.isCancelled &&
                    (entry.cancellationReason?.isNotEmpty ?? false))
                  Text(
                    entry.cancellationReason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          MoneyDisplay(amount: entry.total, style: theme.textTheme.titleSmall),
          if (canCancel) ...[
            const SizedBox(width: 8),
            TextButton(
              key: Key('rental-collection-cancel-${entry.invoiceId}'),
              onPressed: onCancel,
              child: Text(l10n.rentalCollectionCancelAction),
            ),
          ],
        ],
      ),
    );
  }
}
