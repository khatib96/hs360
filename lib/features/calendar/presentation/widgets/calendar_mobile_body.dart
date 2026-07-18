import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/calendar_date.dart';
import '../../domain/calendar_range_summary.dart';
import '../calendar_controller.dart';
import '../calendar_labels.dart';
import '../calendar_state.dart';
import 'calendar_agenda_list.dart';
import 'calendar_filter_bar.dart';
import 'calendar_mobile_date_nav.dart';
import 'calendar_overdue_panel.dart';
import 'calendar_setup_banner.dart';

/// Touch-first mobile calendar: week strip + agenda (+ collapsible overdue).
class CalendarMobileBody extends StatelessWidget {
  const CalendarMobileBody({
    required this.state,
    required this.notifier,
    super.key,
  });

  final CalendarState state;
  final CalendarController notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daysByDate = <DateTime, CalendarDaySummary>{
      for (final day in state.days) calendarDateOnly(day.date): day,
    };

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        key: const Key('calendar-mobile-body'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
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
            useSheet: true,
            onApply: notifier.setFilters,
            onClear: notifier.clearFilters,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const Key('calendar-open-route-view'),
              onPressed: () => context.push(
                AppRoutes.calendarRoutePath(date: state.selectedDate),
              ),
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.calendarRouteViewButton),
            ),
          ),
          CalendarMobileDateNav(
            focusedMonth: state.focusedMonth,
            selectedDate: state.selectedDate,
            firstDayOfWeekIndex: state.firstDayOfWeekIndex!,
            tenantLocalToday: state.tenantLocalToday,
            daysByDate: daysByDate,
            onSelectDate: notifier.selectGridDate,
            onPreviousMonth: notifier.goToPreviousMonth,
            onNextMonth: notifier.goToNextMonth,
            onToday: notifier.goToToday,
            onMonthSelected: notifier.goToMonth,
          ),
          if (state.isLoadingSummary && state.isSummaryQueryAligned)
            const LinearProgressIndicator(),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
            collapsible: true,
            initiallyExpanded: false,
          ),
        ],
      ),
    );
  }
}
