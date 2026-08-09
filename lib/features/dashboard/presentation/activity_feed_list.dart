import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../domain/activity_feed.dart';

class ActivityFeedList extends StatelessWidget {
  const ActivityFeedList({
    required this.items,
    required this.onOpen,
    this.currencyCode = '',
    super.key,
  });

  final List<ActivityFeedItem> items;
  final ValueChanged<String> onOpen;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final languageCode = Localizations.localeOf(context).languageCode;
    final timeFormat = DateFormat.jm(locale);
    final amountFormat = NumberFormat.decimalPattern(locale);

    return ListView.separated(
      key: const Key('activity-feed-list'),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final route = item.sourceRoute;
        return Semantics(
          button: route != null,
          child: InkWell(
            onTap: route == null ? null : () => onOpen(route),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadii.controlRadius,
                    ),
                    child: Icon(
                      activityKindIcon(item.kind),
                      color: Theme.of(context).colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.localizedTitle(languageCode),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              item.localTime ??
                                  timeFormat.format(item.occurredAt.toLocal()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xxs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              activityKindLabel(l10n, item.kind),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (item.identifier.isNotEmpty)
                              Text(
                                item.identifier,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (item.status.isNotEmpty)
                              AppStatusBadge(
                                label: _humanize(item.status),
                                tone: _statusTone(item.status),
                              ),
                          ],
                        ),
                        if (item.amount != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${amountFormat.format(item.amount)}${currencyCode.isEmpty ? '' : ' $currencyCode'}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                        if (route == null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            l10n.activityNoSourceRoute,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (route != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Tooltip(
                      message: l10n.activityOpenSource,
                      child: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String activityKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'calendar_event' => l10n.activityKindCalendarEvent,
  'visit_outcome' => l10n.activityKindVisitOutcome,
  'contract_created' => l10n.activityKindContractCreated,
  'contract_lifecycle' => l10n.activityKindContractLifecycle,
  'invoice' => l10n.activityKindInvoice,
  'voucher' => l10n.activityKindVoucher,
  'cash_bank_movement' => l10n.activityKindCashBankMovement,
  'inventory_document' => l10n.activityKindInventoryDocument,
  _ => _humanize(kind),
};

IconData activityKindIcon(String kind) => switch (kind) {
  'calendar_event' => Icons.event_outlined,
  'visit_outcome' => Icons.task_alt_outlined,
  'contract_created' || 'contract_lifecycle' => Icons.assignment_outlined,
  'invoice' => Icons.receipt_long_outlined,
  'voucher' => Icons.payments_outlined,
  'cash_bank_movement' => Icons.account_balance_wallet_outlined,
  'inventory_document' => Icons.inventory_2_outlined,
  _ => Icons.history_rounded,
};

String _humanize(String value) {
  if (value.isEmpty) return value;
  return value.replaceAll('_', ' ');
}

AppStatusTone _statusTone(String status) => switch (status) {
  'done' ||
  'completed' ||
  'confirmed' ||
  'paid' ||
  'active' => AppStatusTone.success,
  'pending' ||
  'partially_paid' ||
  'in_progress' ||
  'trial' => AppStatusTone.warning,
  'cancelled' || 'missed' || 'damaged' || 'lost' => AppStatusTone.error,
  _ => AppStatusTone.neutral,
};
