import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_range_summary.dart';
import 'calendar_controller.dart';
import 'calendar_desktop_layout.dart';
import 'calendar_labels.dart';
import 'calendar_state.dart';
import 'widgets/calendar_agenda_list.dart';
import 'widgets/calendar_filter_bar.dart';
import 'widgets/calendar_month_grid.dart';
import 'widgets/calendar_month_toolbar.dart';
import 'widgets/calendar_overdue_panel.dart';
import 'widgets/calendar_setup_banner.dart';

/// Desktop Month + selected-day Agenda calendar surface (Phase 7 M6).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int? _scheduledWeekStart;
  int? _appliedWeekStart;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    if (_scheduledWeekStart == index && _appliedWeekStart == index) return;
    _scheduledWeekStart = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_appliedWeekStart == index) return;
      _appliedWeekStart = index;
      ref.read(calendarControllerProvider.notifier).ensureWeekStart(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(calendarControllerProvider);
    final notifier = ref.read(calendarControllerProvider.notifier);
    final narrow =
        MediaQuery.sizeOf(context).width <
        CalendarDesktopLayout.narrowBreakpoint;

    return AppShell(
      title: l10n.calendarTitle,
      currentRoute: AppRoutes.calendar,
      body: _buildBody(context, l10n, state, notifier, narrow),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CalendarState state,
    CalendarController notifier,
    bool narrow,
  ) {
    if (state.permissionDenied) {
      return Center(
        key: const Key('calendar-permission-denied'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.calendarPermissionDenied),
        ),
      );
    }

    if (state.firstDayOfWeekIndex == null ||
        (state.isLoadingSummary &&
            state.isLoadingAgenda &&
            !state.isSummaryQueryAligned &&
            state.agendaEvents.isEmpty)) {
      return Center(
        key: const Key('calendar-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.calendarLoading),
          ],
        ),
      );
    }

    final daysByDate = <DateTime, CalendarDaySummary>{
      for (final day in state.days) calendarDateOnly(day.date): day,
    };

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
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
