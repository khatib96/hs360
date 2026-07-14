import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../domain/calendar_date.dart';
import 'calendar_controller.dart';
import 'calendar_labels.dart';
import 'calendar_state.dart';
import 'widgets/calendar_setup_banner.dart';

/// Minimal Calendar reachability shell for M5 (full Month+Agenda UI is M6).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(calendarControllerProvider);
    final notifier = ref.read(calendarControllerProvider.notifier);

    return AppShell(
      title: l10n.calendarTitle,
      currentRoute: AppRoutes.calendar,
      body: _buildBody(context, l10n, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CalendarState state,
    CalendarController notifier,
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

    if (state.isLoadingSummary &&
        state.isLoadingAgenda &&
        state.days.isEmpty &&
        state.agendaEvents.isEmpty) {
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
              child: MessageBanner(
                variant: MessageBannerVariant.error,
                message: _errorMessage(l10n, state.summaryErrorCode!),
              ),
            ),
          if (state.agendaErrorCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MessageBanner(
                variant: MessageBannerVariant.error,
                message: _errorMessage(l10n, state.agendaErrorCode!),
              ),
            ),
          Text(
            l10n.calendarVisibleRange(
              formatCalendarDateOnly(state.dateFrom),
              formatCalendarDateOnly(state.dateTo),
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.calendarSelectedDate(
              formatCalendarDateOnly(state.selectedDate),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (state.isLoadingAgenda)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.agendaEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                key: const Key('calendar-agenda-empty'),
                child: Text(l10n.calendarAgendaEmpty),
              ),
            )
          else
            ...state.agendaEvents.map(
              (event) => ListTile(
                key: Key('calendar-event-${event.id}'),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? event.titleAr
                      : (event.titleEn ?? event.titleAr),
                ),
                subtitle: Text(
                  '${calendarEventTypeLabel(l10n, event.type)} · '
                  '${calendarEventStatusLabel(l10n, event.status)} · '
                  '${calendarScheduleStateLabel(l10n, event.scheduleState)}',
                ),
              ),
            ),
          if (state.hasMoreInRange)
            TextButton(
              key: const Key('calendar-load-more-agenda'),
              onPressed: state.isLoadingMoreInRange
                  ? null
                  : notifier.loadMoreInRange,
              child: Text(l10n.calendarLoadMore),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonal(
              key: const Key('calendar-retry'),
              onPressed: notifier.refresh,
              child: Text(l10n.retry),
            ),
          ),
        ],
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, String code) {
    return switch (code) {
      CalendarException.permissionDenied => l10n.calendarPermissionDenied,
      CalendarException.validationFailed => l10n.calendarErrorValidation,
      CalendarException.invalidCursor => l10n.calendarErrorInvalidCursor,
      CalendarException.tenantNotFound => l10n.calendarErrorTenantNotFound,
      CalendarException.malformedResponse => l10n.calendarErrorMalformed,
      CalendarException.notAvailable => l10n.calendarErrorUnavailable,
      CalendarException.supabaseNotConfigured => l10n.calendarErrorUnavailable,
      _ => l10n.calendarErrorUnknown,
    };
  }
}
