import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/message_banner.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_range_summary.dart';
import '../../domain/calendar_working_day.dart';
import '../calendar_labels.dart';
import 'calendar_agenda_event_card.dart';
import 'calendar_agenda_header.dart';

class CalendarAgendaList extends StatelessWidget {
  const CalendarAgendaList({
    required this.selectedDate,
    required this.workingDay,
    required this.daySummary,
    required this.events,
    required this.isLoading,
    required this.hasActiveFilters,
    required this.errorCode,
    required this.loadMoreErrorCode,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onRetry,
    required this.onLoadMore,
    required this.onClearFilters,
    super.key,
  });

  final DateTime selectedDate;
  final CalendarWorkingDay? workingDay;
  final CalendarDaySummary? daySummary;
  final List<CalendarEvent> events;
  final bool isLoading;
  final bool hasActiveFilters;
  final String? errorCode;
  final String? loadMoreErrorCode;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarAgendaHeader(
          selectedDate: selectedDate,
          workingDay: workingDay,
          daySummary: daySummary,
        ),
        const SizedBox(height: 12),
        if (errorCode != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MessageBanner(
                  variant: MessageBannerVariant.error,
                  message: calendarErrorMessage(l10n, errorCode!),
                ),
                TextButton(
                  key: const Key('calendar-retry-agenda'),
                  onPressed: onRetry,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(l10n.calendarAgendaLoading),
              ],
            ),
          )
        else if (events.isEmpty && errorCode == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              key: const Key('calendar-agenda-empty'),
              children: [
                Text(
                  hasActiveFilters
                      ? l10n.calendarAgendaFilteredEmpty
                      : l10n.calendarAgendaEmpty,
                ),
                if (hasActiveFilters)
                  TextButton(
                    onPressed: onClearFilters,
                    child: Text(l10n.calendarFilterClear),
                  ),
              ],
            ),
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
            key: const Key('calendar-load-more-agenda'),
            onPressed: isLoadingMore ? null : onLoadMore,
            child: Text(l10n.calendarLoadMore),
          ),
      ],
    );
  }
}
