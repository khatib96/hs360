import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/message_banner.dart';
import '../../domain/calendar_enums.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_range_summary.dart';
import '../calendar_labels.dart';
import 'calendar_agenda_event_card.dart';

class CalendarOverduePanel extends StatelessWidget {
  const CalendarOverduePanel({
    required this.summary,
    required this.events,
    required this.isLoading,
    required this.errorCode,
    required this.loadMoreErrorCode,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onRetry,
    required this.onLoadMore,
    this.collapsible = false,
    this.initiallyExpanded = true,
    super.key,
  });

  final CalendarOverdueOutsideRangeSummary? summary;
  final List<CalendarEvent> events;
  final bool isLoading;
  final String? errorCode;
  final String? loadMoreErrorCode;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  /// When true (mobile), the section is secondary and starts collapsed.
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unconfigured =
        summary?.state == CalendarOverdueOutsideRangeState.scheduleUnconfigured;
    final body = _buildBody(context, l10n, unconfigured);

    if (!collapsible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.calendarOverdueSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          body,
        ],
      );
    }

    return ExpansionTile(
      key: const Key('calendar-overdue-expansion'),
      initiallyExpanded: initiallyExpanded,
      title: Text(l10n.calendarOverdueSectionTitle),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: body),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    bool unconfigured,
  ) {
    if (unconfigured) {
      return MessageBanner(
        key: const Key('calendar-overdue-unavailable'),
        variant: MessageBannerVariant.info,
        message: l10n.calendarOverdueUnavailable,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorCode != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MessageBanner(
                variant: MessageBannerVariant.error,
                message: calendarErrorMessage(l10n, errorCode!),
              ),
              TextButton(
                key: const Key('calendar-retry-overdue'),
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(l10n.calendarOverdueLoading),
              ],
            ),
          )
        else if (events.isEmpty && errorCode == null)
          Text(
            key: const Key('calendar-overdue-empty'),
            l10n.calendarOverdueEmpty,
          )
        else
          ...events.map((e) => CalendarAgendaEventCard(event: e)),
        if (loadMoreErrorCode != null)
          MessageBanner(
            variant: MessageBannerVariant.error,
            message: calendarErrorMessage(l10n, loadMoreErrorCode!),
          ),
        if (hasMore)
          TextButton(
            key: const Key('calendar-load-more-overdue'),
            onPressed: isLoadingMore ? null : onLoadMore,
            child: Text(l10n.calendarLoadMore),
          ),
      ],
    );
  }
}
