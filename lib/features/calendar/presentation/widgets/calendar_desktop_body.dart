import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/message_banner.dart';
import '../../domain/calendar_date.dart';
import '../../domain/calendar_range_summary.dart';
import '../calendar_controller.dart';
import '../calendar_labels.dart';
import '../calendar_state.dart';
import 'calendar_agenda_list.dart';
import 'calendar_filter_bar.dart';
import 'calendar_month_grid.dart';
import 'calendar_month_toolbar.dart';
import 'calendar_overdue_panel.dart';
import 'calendar_setup_banner.dart';

/// Desktop Month + Agenda composition (Phase 7 M6).
class CalendarDesktopBody extends StatelessWidget {
  const CalendarDesktopBody({
    required this.state,
    required this.notifier,
    required this.narrow,
    super.key,
  });

  final CalendarState state;
  final CalendarController notifier;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daysByDate = <DateTime, CalendarDaySummary>{
      for (final day in state.days) calendarDateOnly(day.date): day,
    };

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        key: const Key('calendar-desktop-body'),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.showSetupWarning)
            CalendarSetupBanner(message: l10n.calendarSetupWarning),
          if (state.summaryErrorCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MessageBanner(
                    variant: MessageBannerVariant.error,
                    message: calendarErrorMessage(
                      l10n,
                      state.summaryErrorCode!,
                    ),
                  ),
                  TextButton(
                    key: const Key('calendar-retry-summary'),
                    onPressed: notifier.retrySummary,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          CalendarFilterBar(
            applied: state.filters,
            scope: state.scope,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
            collapsed: narrow,
            onApply: notifier.setFilters,
            onClear: notifier.clearFilters,
          ),
          const SizedBox(height: 8),
          CalendarMonthToolbar(
            focusedMonth: state.focusedMonth,
            onPrevious: notifier.goToPreviousMonth,
            onNext: notifier.goToNextMonth,
            onToday: notifier.goToToday,
            onMonthSelected: notifier.goToMonth,
          ),
          if (state.isLoadingSummary && state.isSummaryQueryAligned)
            const LinearProgressIndicator(),
          CalendarMonthGrid(
            focusedMonth: state.focusedMonth,
            firstDayOfWeekIndex: state.firstDayOfWeekIndex!,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
            selectedDate: state.selectedDate,
            tenantLocalToday: state.tenantLocalToday,
            daysByDate: daysByDate,
            isAligned: state.isSummaryQueryAligned,
            isLoading: state.isLoadingSummary,
            onSelectDate: notifier.selectGridDate,
          ),
          const SizedBox(height: 24),
          CalendarAgendaList(
            selectedDate: state.selectedDate,
            workingDay: state.selectedDaySummary?.workingDay,
            daySummary: state.selectedDaySummary,
            events: state.agendaEvents,
            isLoading: state.isLoadingAgenda,
            hasActiveFilters: state.hasActiveFilters,
            errorCode: state.agendaErrorCode,
            loadMoreErrorCode: state.loadMoreInRangeErrorCode,
            hasMore: state.hasMoreInRange,
            isLoadingMore: state.isLoadingMoreInRange,
            onRetry: notifier.retryAgenda,
            onLoadMore: notifier.loadMoreInRange,
            onClearFilters: notifier.clearFilters,
          ),
          const SizedBox(height: 24),
          CalendarOverduePanel(
            summary: state.overdueOutsideRangeSummary,
            events: state.overdueEvents,
            isLoading: state.isLoadingOverdue,
            errorCode: state.overdueErrorCode,
            loadMoreErrorCode: state.loadMoreOverdueErrorCode,
            hasMore: state.hasMoreOverdue,
            isLoadingMore: state.isLoadingMoreOverdue,
            onRetry: notifier.retryOverdue,
            onLoadMore: notifier.loadMoreOverdue,
          ),
        ],
      ),
    );
  }
}
